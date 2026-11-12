-- Cooldown groups step 2a: moving the tracker's saved settings into CastbornDB.cooldowns.groups.
-- Logins go through Core's real ADDON_LOADED handler (InitDB, position migration, INIT).

require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
_G.UnitRace = function() return "Human", "Human" end
_G.GetSpellInfo = function() return nil end
_G.GetSpellTexture = function() return nil end
_G.GetSpellCooldown = function() return 0, 0 end
_G.GetInventoryItemID = function() return nil end

dofile("Core.lua")
dofile("Systems/Anchoring.lua")
dofile("Systems/Profiles.lua")
dofile("Data/SpellData.lua")
dofile("Modules/CooldownGroup.lua")
dofile("Modules/CooldownTracker.lua")
dofile("Systems/Config.lua")

-- Anchoring's position helpers are real; its drag handles need the theme and real font
-- metrics, and dragging is not under test here
Castborn.Anchoring.MakeDraggable = function() end

local CT = Castborn.CooldownTracker

local LAYOUT_KEYS = {
    "iconSize", "spacing", "iconsPerRow", "orientation", "growDirection",
    "anchored", "anchorPosition", "point", "x", "y", "xPct", "yPct", "verticalLayout",
}

local chat = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) chat[#chat + 1] = msg end }

local function migrationLines()
    local n = 0
    for _, msg in ipairs(chat) do
        if msg:find("Cooldowns moved to the new groups format", 1, true) then n = n + 1 end
    end
    return n
end

-- A login as far as INIT: InitDB, pixel-to-percentage migration, INIT callbacks
local function login(db)
    _G.CastbornDB = db
    local mainFrame = _G.CastbornMain
    mainFrame.scripts.OnEvent(mainFrame, "ADDON_LOADED", "Castborn")
end

local function copy(t)
    return Castborn:DeepCopy(t)
end

-- Saved settings as Castborn 8.1.1 left them
local function oldShape()
    return {
        enabled = true,
        showTime = true,
        showReadyGlow = false,
        trackTrinkets = false,
        loadedForClass = "MAGE",
        defaultsLoaded = "8.1.1",
        iconSize = 40,
        spacing = 6,
        iconsPerRow = 5,
        orientation = "VERTICAL",
        verticalLayout = true,
        growDirection = "RIGHT",
        anchored = false,
        anchorPosition = "LEFT",
        point = "TOPLEFT",
        x = 96,
        y = -200,
        xPct = 0.05,
        yPct = -0.185,
        trackedSpells = {
            { spellId = 12472, name = "Icy Veins", enabled = true },
            { spellId = 99999, name = "Custom Thing", enabled = true, custom = true },
            { spellId = 11958, name = "Cold Snap", enabled = false },
        },
    }
end

local function assertNoTopLevelLayout(db)
    for _, key in ipairs(LAYOUT_KEYS) do
        assert.is_nil(db[key], "top-level " .. key .. " still present")
    end
    assert.is_nil(db.trackedSpells, "top-level trackedSpells still present")
end

before_each(function()
    for i = #chat, 1, -1 do chat[i] = nil end
end)

describe("Cooldown groups defaults", function()
    it("never puts groups in a defaults table", function()
        assert.is_nil(Castborn.defaults.cooldowns.groups)
        assert.is_nil(CT.groupDefaults.groups)
    end)

    it("keeps only module-wide keys in Core's cooldown defaults", function()
        for _, key in ipairs(LAYOUT_KEYS) do
            assert.is_nil(Castborn.defaults.cooldowns[key], "Core default still has " .. key)
        end
        assert.is_true(Castborn.defaults.cooldowns.enabled)
        assert.is_true(Castborn.defaults.cooldowns.showReadyGlow)
    end)
end)

describe("Fresh install", function()
    it("creates one main group with default layout and nothing at the top level", function()
        login(nil)
        local db = CastbornDB.cooldowns

        assert.are.equal(1, #db.groups)
        local main = db.groups[1]
        assert.are.equal("main", main.id)
        assert.are.equal("Main", main.name)
        assert.are.equal(36, main.iconSize)
        assert.are.equal(4, main.spacing)
        assert.are.equal(10, main.iconsPerRow)
        assert.are.equal("HORIZONTAL", main.orientation)
        assert.are.equal("LEFT", main.growDirection)
        assert.is_true(main.anchored)
        assert.are.equal("LEFT", main.anchorPosition)
        assert.are.equal("CENTER", main.point)
        assert.are.equal(-450, main.x)
        assert.are.equal(-300, main.y)
        assert.are.equal(-0.234, main.xPct)
        assert.are.equal(-0.278, main.yPct)
        assert.are.same({}, main.spells)

        assertNoTopLevelLayout(db)
        assert.is_true(db.enabled)
        assert.is_true(db.showTime)
        assert.is_true(db.showReadyGlow)
        assert.is_true(db.trackTrinkets)
    end)

    it("does not write a legacy backup or announce a migration", function()
        login(nil)
        assert.is_nil(CastbornDB.cooldowns.legacyBackup)
        assert.are.equal(0, migrationLines())
    end)
end)

describe("Migrating old data", function()
    it("moves every layout key and the spell list into main unchanged", function()
        local old = oldShape()
        login({ cooldowns = old })
        local db = CastbornDB.cooldowns
        local main = db.groups[1]

        assert.are.equal(1, #db.groups)
        assert.are.equal("main", main.id)
        assert.are.equal(40, main.iconSize)
        assert.are.equal(6, main.spacing)
        assert.are.equal(5, main.iconsPerRow)
        assert.are.equal("VERTICAL", main.orientation)
        assert.is_true(main.verticalLayout)
        assert.are.equal("RIGHT", main.growDirection)
        assert.is_false(main.anchored)
        assert.are.equal("LEFT", main.anchorPosition)
        assert.are.equal("TOPLEFT", main.point)
        assert.are.equal(96, main.x)
        assert.are.equal(-200, main.y)
        assert.are.equal(0.05, main.xPct)
        assert.are.equal(-0.185, main.yPct)

        assert.are.same(oldShape().trackedSpells, main.spells)
        assert.is_true(main.spells[2].custom)
        assert.is_false(main.spells[3].enabled)

        assertNoTopLevelLayout(db)
        assert.is_false(db.showReadyGlow)
        assert.is_false(db.trackTrinkets)
        assert.are.equal("MAGE", db.loadedForClass)
        assert.are.equal("8.1.1", db.defaultsLoaded)
    end)

    it("moves the spell list rather than copying it", function()
        local db = oldShape()
        local spells = db.trackedSpells
        CT.MigrateToGroups(db)
        assert.are.equal(spells, db.groups[1].spells)
    end)

    it("keeps a deep copy of the old keys in legacyBackup", function()
        login({ cooldowns = oldShape() })
        local db = CastbornDB.cooldowns
        local backup = db.legacyBackup
        local before = oldShape()

        assert.is_table(backup)
        for _, key in ipairs(LAYOUT_KEYS) do
            assert.are.same(before[key], backup[key], "backup of " .. key)
        end
        assert.are.same(before.trackedSpells, backup.trackedSpells)
        assert.are_not.equal(db.groups[1].spells, backup.trackedSpells)
    end)

    it("announces the migration once", function()
        login({ cooldowns = oldShape() })
        assert.are.equal(1, migrationLines())
    end)

    it("returns whether it migrated and changes nothing the second time", function()
        local db = oldShape()
        assert.is_true(CT.MigrateToGroups(db))
        local backup = db.legacyBackup
        local snapshot = copy(db)

        assert.is_false(CT.MigrateToGroups(db))
        assert.are.same(snapshot, db)
        assert.are.equal(backup, db.legacyBackup)
    end)

    it("does not overwrite an existing legacyBackup", function()
        local db = oldShape()
        local earlier = { iconSize = 99 }
        db.legacyBackup = earlier
        CT.MigrateToGroups(db)
        assert.are.equal(earlier, db.legacyBackup)
    end)

    it("fills keys missing from old data from the group defaults", function()
        local db = { enabled = true, iconSize = 44, trackedSpells = {} }
        CT.MigrateToGroups(db)
        local main = db.groups[1]
        assert.are.equal(44, main.iconSize)
        assert.are.equal(4, main.spacing)
        assert.are.equal("LEFT", main.growDirection)
        assert.is_true(main.anchored)
    end)

    it("keeps a pixel-only position instead of filling default percentages", function()
        login({ cooldowns = { enabled = true, point = "TOPLEFT", x = 192, y = -108, trackedSpells = {} } })
        local main = CastbornDB.cooldowns.groups[1]
        assert.are.equal("TOPLEFT", main.point)
        assert.are.equal(192, main.x)
        assert.are.equal(-108, main.y)
        -- Core's pixel-to-percentage pass converts these before INIT migrates them
        assert.are.equal(0.1, main.xPct)
        assert.are.equal(-0.1, main.yPct)
    end)

    it("does not recreate top-level keys on a second login", function()
        login({ cooldowns = oldShape() })
        local afterFirst = copy(CastbornDB.cooldowns.groups)

        login(CastbornDB)
        local db = CastbornDB.cooldowns
        assertNoTopLevelLayout(db)
        assert.are.same(afterFirst, db.groups)
        assert.are.equal(1, migrationLines())
    end)
end)

describe("Profiles", function()
    it("migrates an old-shape profile when it is applied", function()
        login(nil)
        CastbornDB.profiles.Old = { cooldowns = oldShape() }
        Castborn.Profiles:ApplyProfile("Old")

        local db = CastbornDB.cooldowns
        assertNoTopLevelLayout(db)
        assert.are.equal(1, #db.groups)
        assert.are.equal(40, db.groups[1].iconSize)
        assert.are.same(oldShape().trackedSpells, db.groups[1].spells)
        assert.are.equal(1, migrationLines())
    end)

    it("leaves a new-shape profile alone", function()
        login({ cooldowns = oldShape() })
        Castborn.Profiles:SaveCurrentToProfile("New")
        local stored = copy(CastbornDB.profiles.New.cooldowns)
        for i = #chat, 1, -1 do chat[i] = nil end

        Castborn.Profiles:ApplyProfile("New")
        assert.are.same(stored, CastbornDB.cooldowns)
        assert.are.equal(0, migrationLines())
    end)

    it("migrates on access if the old shape appears without an event", function()
        login(nil)
        CastbornDB.cooldowns = oldShape()
        local main
        assert.has_no.errors(function() main = CT:GetMainGroup() end)
        assert.are.equal("main", main.id)
        assert.are.equal(40, main.iconSize)
        assertNoTopLevelLayout(CastbornDB.cooldowns)
    end)
end)

describe("Group accessors", function()
    it("finds the main group by id, not position", function()
        login(nil)
        local groups = CastbornDB.cooldowns.groups
        local main = groups[1]
        table.insert(groups, 1, { id = "other", name = "Other", spells = {} })
        assert.are.equal(main, CT:GetMainGroup())
        assert.are.equal(main, CT:GetGroup("main"))
        assert.are.equal(groups[1], CT:GetGroup("other"))
        assert.is_nil(CT:GetGroup("missing"))
        assert.are.equal(groups, CT:GetGroups())
    end)

    it("recreates a missing main group with defaults and no spells", function()
        login(nil)
        local other = { id = "other", name = "Other", spells = {} }
        CastbornDB.cooldowns.groups = { other }

        local main = CT:GetMainGroup()
        assert.are.equal("main", main.id)
        assert.are.equal(36, main.iconSize)
        assert.are.same({}, main.spells)
        assert.are.same({ main, other }, CastbornDB.cooldowns.groups)
        assert.are.equal(main, CT:GetMainGroup())
    end)
end)

describe("Default spell loading on the main group", function()
    local function classSpellIds()
        local ids = {}
        for _, spell in ipairs(Castborn.SpellData:GetClassCooldowns("MAGE")) do ids[#ids + 1] = spell.spellId end
        for _, spell in ipairs(Castborn.SpellData:GetRacialCooldowns("Human")) do ids[#ids + 1] = spell.spellId end
        return ids
    end

    before_each(function()
        -- Default loading appends into SpellData's own lists, so start each spec clean
        dofile("Data/SpellData.lua")
    end)

    it("reloads class defaults on a class change and keeps custom spells", function()
        local old = oldShape()
        old.loadedForClass = "WARRIOR"
        login({ cooldowns = old })
        local expected = classSpellIds()
        Castborn:FireCallback("READY")

        local db = CastbornDB.cooldowns
        local spells = db.groups[1].spells
        assert.are.equal(#expected + 1, #spells)
        for i, id in ipairs(expected) do
            assert.are.equal(id, spells[i].spellId)
        end
        assert.are.equal(99999, spells[#spells].spellId)
        assert.is_true(spells[#spells].custom)
        assert.are.equal("MAGE", db.loadedForClass)
        assertNoTopLevelLayout(db)
    end)

    it("merges new defaults on a version change and counts them", function()
        local expected = classSpellIds()
        local first = Castborn.SpellData:GetClassCooldowns("MAGE")[1]
        login({ cooldowns = {
            enabled = true,
            loadedForClass = "MAGE",
            defaultsLoaded = "0.0.1",
            trackedSpells = { { spellId = first.spellId, name = first.name, enabled = true } },
        } })
        Castborn:FireCallback("READY")

        local db = CastbornDB.cooldowns
        assert.are.equal(#expected, #db.groups[1].spells)
        assert.are.equal(Castborn.version, db.defaultsLoaded)
        local counted = false
        for _, msg in ipairs(chat) do
            if msg:find((#expected - 1) .. " new cooldown(s) added from defaults", 1, true) then counted = true end
        end
        assert.is_true(counted, "no count of new defaults printed")
    end)
end)

describe("Reset Positions", function()
    it("writes the defaults to the main group and reattaches it", function()
        login({ cooldowns = oldShape() })
        Castborn:FireCallback("READY")
        local reattached = 0
        Castborn:RegisterCallback("REATTACH_COOLDOWNS", function() reattached = reattached + 1 end)

        Castborn:ResetPositions()

        local main = CT:GetMainGroup()
        assert.are.equal("CENTER", main.point)
        assert.are.equal(-0.234, main.xPct)
        assert.are.equal(-0.278, main.yPct)
        assert.are.equal(-0.234 * 1920, main.x)
        assert.are.equal(-0.278 * 1080, main.y)
        assert.are.equal(36, main.iconSize)
        assert.is_true(main.anchored)
        assert.are.equal(1, reattached)
        assertNoTopLevelLayout(CastbornDB.cooldowns)
    end)
end)

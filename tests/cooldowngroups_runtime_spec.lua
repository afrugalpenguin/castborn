-- Cooldown groups step 2b: several groups at runtime, the group API, centred groups,
-- default loading with other groups present, profile switches, Masque and Reset Positions.

require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}

--------------------------------------------------------------------------------
-- World state
--------------------------------------------------------------------------------

local known = {}
_G.IsSpellKnown = function(id) return known[id] == true end
_G.GetSpellInfo = function() return nil end
_G.GetSpellTexture = function(v) return "Interface\\Icons\\" .. tostring(v) end
_G.GetSpellCooldown = function() return 0, 0 end
_G.GetInventoryItemID = function() return nil end
_G.GetCursorPosition = function() return 0, 0 end
_G.UnitRace = function() return "Human", "Human" end
_G.UIParent.GetEffectiveScale = function() return 1 end

-- Masque, recording the groups it is asked for
local masqueGroups = {}
local MSQ = {
    Group = function(_, addon, name, staticId)
        local g = { addon = addon, name = name, staticId = staticId, buttons = {} }
        function g:AddButton(button) self.buttons[#self.buttons + 1] = button end
        function g:Delete() self.deleted = true end
        function g:SetName(newName) self.name = newName end
        function g:ReSkin() end
        masqueGroups[#masqueGroups + 1] = g
        return g
    end,
}
_G.LibStub = function(lib) if lib == "Masque" then return MSQ end end

local function masqueGroupNamed(name)
    for _, g in ipairs(masqueGroups) do
        if g.name == name and not g.deleted then return g end
    end
end

-- As in the game, a field nobody set is nil; only methods (CapitalCase) fall back to no-ops
local function augment(f)
    setmetatable(f, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
    f.shown = true
    f.Show = function(self) self.shown = true end
    f.Hide = function(self) self.shown = false end
    f.IsShown = function(self) return self.shown end
    f.SetTexture = function(self, t) self.texture = t end
    f.GetTexture = function(self) return self.texture end
    f.SetAlpha = function(self, a) self.alpha = a end
    f.SetDesaturated = function(self, d) self.desaturated = d end
    f.GetPoint = function(self)
        local p = self.points[1]
        if p then return unpack(p) end
    end
    f.GetFrameLevel = function(self) return self.level or 1 end
    f.SetFrameLevel = function(self, level) self.level = level end
    -- A centre but no edges, so stacking a new group uses its fallback position
    f.GetCenter = function() return 0, 0 end
    local createTexture = f.CreateTexture
    f.CreateTexture = function(...) return augment(createTexture(...)) end
    return f
end

local realCreateFrame = _G.CreateFrame
_G.CreateFrame = function(...) return augment(realCreateFrame(...)) end

dofile("Core.lua")
dofile("Systems/Anchoring.lua")
dofile("Systems/Profiles.lua")
dofile("Systems/Masque.lua")
dofile("Data/SpellData.lua")
dofile("Modules/CooldownGroup.lua")
dofile("Modules/CooldownTracker.lua")
dofile("Systems/Config.lua")

-- Drag handles need the theme and real font metrics; record what each group passes instead
Castborn.Anchoring.MakeDraggable = function(_, frame, db, onDragStop, label)
    frame.dragDb = db
    frame.onDragStop = onDragStop
    frame.dragLabel = label
end

local CT = Castborn.CooldownTracker

local framesCreated = 0
Castborn:RegisterCallback("COOLDOWN_FRAME_CREATED", function() framesCreated = framesCreated + 1 end)

local chat = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) chat[#chat + 1] = msg end }

-- One login for the whole file: INIT, then READY builds the frames
_G.CastbornDB = nil
local mainFrame = _G.CastbornMain
mainFrame.scripts.OnEvent(mainFrame, "ADDON_LOADED", "Castborn")
Castborn:FireCallback("READY")

local function container(id)
    if id == "main" then return _G.Castborn_CooldownTracker end
    return _G["Castborn_CooldownGroup_" .. id]
end

local function icon(id, i)
    if id == "main" then return _G["Castborn_CD" .. i] end
    return _G["Castborn_CooldownGroup_" .. id .. "_CD" .. i]
end

local function spell(id, opts)
    known[id] = true
    local s = { spellId = id, name = "Spell" .. id, enabled = true }
    for k, v in pairs(opts or {}) do s[k] = v end
    return s
end

local function ids(groupId)
    local out = {}
    for i, s in ipairs(CT:GetGroup(groupId).spells) do out[i] = s.spellId end
    return out
end

local function snapshot()
    return Castborn:DeepCopy(CastbornDB.cooldowns.groups)
end

-- Back to one main group holding spells 101..105, and no others
local function reset()
    Castborn:EndTestCooldowns()
    local main = CT:GetMainGroup()
    main.spells = { spell(101), spell(102), spell(103), spell(104), spell(105) }
    main.growDirection = "LEFT"
    CastbornDB.cooldowns.groups = { main }
    CastbornDB.cooldowns.nextGroupId = 1
    CT:SyncGroups()
    for i = #chat, 1, -1 do chat[i] = nil end
end

--------------------------------------------------------------------------------

describe("Group API", function()
    before_each(reset)

    it("adds a free group with defaults and a new id", function()
        local id = CT:AddGroup("Defensives")
        assert.are.equal("g1", id)
        local g = CT:GetGroup("g1")
        assert.are.equal("Defensives", g.name)
        assert.is_false(g.anchored)
        assert.are.equal(36, g.iconSize)
        assert.are.equal("LEFT", g.growDirection)
        assert.are.same({}, g.spells)
        assert.are.equal(g, CT:GetGroups()[2])
        assert.are.equal(2, CastbornDB.cooldowns.nextGroupId)
    end)

    it("trims the name", function()
        local id = CT:AddGroup("  Utility  ")
        assert.are.equal("Utility", CT:GetGroup(id).name)
    end)

    it("refuses an empty name and changes nothing", function()
        local before = snapshot()
        local id, reason = CT:AddGroup("   ")
        assert.is_nil(id)
        assert.is_string(reason)
        id = CT:AddGroup(nil)
        assert.is_nil(id)
        assert.are.same(before, snapshot())
        assert.are.equal(1, CastbornDB.cooldowns.nextGroupId)
    end)

    it("allows eight groups including main, and refuses a ninth", function()
        for i = 1, 7 do assert.is_string(CT:AddGroup("Group " .. i)) end
        assert.are.equal(8, #CT:GetGroups())
        local id, reason = CT:AddGroup("One too many")
        assert.is_nil(id)
        assert.is_string(reason)
        assert.are.equal(8, #CT:GetGroups())
    end)

    it("never reuses an id", function()
        CT:AddGroup("First")
        assert.is_true(CT:RemoveGroup("g1"))
        assert.are.equal("g2", CT:AddGroup("Second"))
    end)

    it("removes a group and returns its spells to the end of main in order", function()
        CT:AddGroup("Test")
        CT:MoveSpell(102, "g1")
        CT:MoveSpell(104, "g1")
        assert.is_true(CT:RemoveGroup("g1"))
        assert.is_nil(CT:GetGroup("g1"))
        assert.are.same({ 101, 103, 105, 102, 104 }, ids("main"))
    end)

    it("refuses to remove main or an unknown group", function()
        local before = snapshot()
        local ok, reason = CT:RemoveGroup("main")
        assert.is_false(ok)
        assert.is_string(reason)
        ok, reason = CT:RemoveGroup("nope")
        assert.is_false(ok)
        assert.is_string(reason)
        assert.are.same(before, snapshot())
    end)

    it("refuses to remove a group when main has no room for its spells", function()
        local main = CT:GetMainGroup()
        for id = 201, 216 do main.spells[#main.spells + 1] = spell(id) end  -- 21 total
        CT:AddGroup("Test")
        CT:MoveSpell(201, "g1")
        CT:MoveSpell(202, "g1")  -- main 19, g1 2
        local before = snapshot()
        local ok, reason = CT:RemoveGroup("g1")
        assert.is_false(ok)
        assert.is_string(reason)
        assert.are.same(before, snapshot())
    end)

    it("renames a group, and refuses an empty name", function()
        CT:AddGroup("Old")
        assert.is_true(CT:RenameGroup("g1", " New "))
        assert.are.equal("New", CT:GetGroup("g1").name)
        local ok, reason = CT:RenameGroup("g1", "")
        assert.is_false(ok)
        assert.is_string(reason)
        assert.are.equal("New", CT:GetGroup("g1").name)
        assert.is_true(CT:RenameGroup("main", "Top Row"))
        assert.are.equal("main", CT:GetMainGroup().id)
    end)

    it("reorders groups, clamping the position", function()
        CT:AddGroup("A")
        CT:AddGroup("B")
        assert.is_true(CT:MoveGroup("g2", 1))
        local order = {}
        for i, g in ipairs(CT:GetGroups()) do order[i] = g.id end
        assert.are.same({ "g2", "main", "g1" }, order)
        assert.is_true(CT:MoveGroup("g2", 99))
        assert.are.equal("g2", CT:GetGroups()[3].id)
        assert.is_false(CT:MoveGroup("nope", 1))
    end)

    it("moves a spell between groups, at the end or at a position", function()
        CT:AddGroup("Test")
        assert.is_true(CT:MoveSpell(102, "g1"))
        assert.is_true(CT:MoveSpell(104, "g1", 1))
        assert.are.same({ 101, 103, 105 }, ids("main"))
        assert.are.same({ 104, 102 }, ids("g1"))
    end)

    it("moves a spell within its own group", function()
        assert.is_true(CT:MoveSpell(104, "main", 1))
        assert.are.same({ 104, 101, 102, 103, 105 }, ids("main"))
        assert.is_true(CT:MoveSpell(104, "main", 99))
        assert.are.same({ 101, 102, 103, 105, 104 }, ids("main"))
    end)

    it("refuses an unknown spell or group, and a full group", function()
        CT:AddGroup("Test")
        local g = CT:GetGroup("g1")
        for id = 301, 320 do g.spells[#g.spells + 1] = spell(id) end
        local before = snapshot()
        local ok, reason = CT:MoveSpell(999, "g1")
        assert.is_false(ok)
        assert.is_string(reason)
        ok = CT:MoveSpell(101, "nope")
        assert.is_false(ok)
        ok, reason = CT:MoveSpell(101, "g1")
        assert.is_false(ok)
        assert.is_string(reason)
        assert.are.same(before, snapshot())
    end)

    it("finds which group holds a spell", function()
        CT:AddGroup("Test")
        CT:MoveSpell(103, "g1")
        local g, index = CT:FindSpell(103)
        assert.are.equal("g1", g.id)
        assert.are.equal(1, index)
        g, index = CT:FindSpell(105)
        assert.are.equal("main", g.id)
        assert.are.equal(4, index)
        assert.is_nil(CT:FindSpell(999))
    end)
end)

describe("Runtime groups", function()
    before_each(reset)
    after_each(function() Castborn:EndTestCooldowns() end)

    it("builds frames for a new group under its own names", function()
        -- An id no earlier spec has used, so its frames are built here
        CastbornDB.cooldowns.nextGroupId = 50
        local before = framesCreated
        assert.are.equal("g50", CT:AddGroup("Fresh"))
        assert.is_table(container("g50"))
        assert.is_table(icon("g50", 1))
        assert.is_table(icon("g50", 20))
        assert.are.equal(before + 20, framesCreated)
        assert.are.equal("Cooldowns: Fresh", container("g50").dragLabel)
        assert.are.equal("Cooldowns", container("main").dragLabel)
    end)

    it("shows each group's own spells", function()
        CT:AddGroup("Test")
        CT:MoveSpell(103, "g1")
        CT:MoveSpell(104, "g1")
        CT:UpdateAll()

        assert.are.equal("Interface\\Icons\\Spell101", icon("main", 1).icon.texture)
        assert.are.equal("Interface\\Icons\\Spell102", icon("main", 2).icon.texture)
        assert.are.equal("Interface\\Icons\\Spell105", icon("main", 3).icon.texture)
        assert.is_false(icon("main", 4).shown)
        assert.are.equal("Interface\\Icons\\Spell103", icon("g1", 1).icon.texture)
        assert.are.equal("Interface\\Icons\\Spell104", icon("g1", 2).icon.texture)
        assert.is_true(container("g1").shown)
    end)

    it("hides a removed group's strip", function()
        CT:AddGroup("Test")
        CT:MoveSpell(103, "g1")
        CT:UpdateAll()
        assert.is_true(container("g1").shown)
        CT:RemoveGroup("g1")
        CT:UpdateAll()
        assert.is_false(container("g1").shown)
    end)

    it("keeps a removed group's strip out of unlock mode until it returns", function()
        CT:AddGroup("Test")
        local frame = container("g1")
        CT:RemoveGroup("g1")
        assert.is_true(frame.dragDisabled)

        frame.dragIndicator = augment(realCreateFrame("Frame"))
        local saved = Castborn.Anchoring.draggableFrames
        Castborn.Anchoring.draggableFrames = { frame }
        Castborn.Anchoring:ShowDragIndicators(true)
        Castborn.Anchoring.draggableFrames = saved
        assert.is_false(frame.shown)

        CastbornDB.cooldowns.nextGroupId = 1
        CT:AddGroup("Back")
        assert.is_nil(frame.dragDisabled)
    end)

    it("reuses a group's frames when its id returns", function()
        CT:AddGroup("Test")
        local frame = container("g1")
        CT:RemoveGroup("g1")
        CastbornDB.cooldowns.nextGroupId = 1
        CT:AddGroup("Again")
        assert.are.equal(frame, container("g1"))
    end)

    it("shows every group in test mode and reorders within one", function()
        CT:AddGroup("Test")
        CT:MoveSpell(103, "g1")
        CT:MoveSpell(104, "g1")
        local g1 = CT:GetGroup("g1")
        g1.iconSize, g1.spacing, g1.growDirection = 30, 2, "RIGHT"
        Castborn:TestCooldowns()

        assert.is_true(container("main").shown)
        assert.is_true(container("g1").shown)
        assert.are.equal("Interface\\Icons\\104", icon("g1", 2).icon.texture)

        local frame = container("g1")
        frame.GetLeft = function() return 0 end
        frame.GetRight = function() return 300 end
        frame.GetTop = function() return 100 end
        frame.GetBottom = function() return 66 end
        local dragged = icon("g1", 1)
        dragged.scripts.OnDragStart(dragged)
        _G.GetCursorPosition = function() return 32, 90 end
        dragged.scripts.OnUpdate(dragged, 0.016)
        dragged.scripts.OnDragStop(dragged)
        _G.GetCursorPosition = function() return 0, 0 end

        assert.are.same({ 104, 103 }, ids("g1"))
        assert.are.same({ 101, 102, 105 }, ids("main"))
    end)

    it("starts test mode on a group added while testing", function()
        Castborn:TestCooldowns()
        CT:AddGroup("Late")
        assert.is_true(container("g1").shown)
        assert.is_true(icon("g1", 1).shown)
    end)

    it("saves a drag into the group's current table after a profile switch", function()
        CT:AddGroup("Test")
        Castborn.Profiles:SaveCurrentToProfile("Copy")
        Castborn.Profiles:ApplyProfile("Copy")
        container("g1").dragDb.point = "TOPLEFT"
        assert.are.equal("TOPLEFT", CT:GetGroup("g1").point)
    end)
end)

describe("Centred groups", function()
    before_each(reset)

    local function centred()
        CT:AddGroup("Centre")
        local g = CT:GetGroup("g1")
        g.iconSize, g.spacing, g.iconsPerRow, g.growDirection = 30, 2, 3, "CENTER"
        for id = 401, 405 do g.spells[#g.spells + 1] = spell(id) end
        return g
    end

    it("centres each row in a live update", function()
        centred()
        CT:UpdateAll()
        local want = { { -32, 0 }, { 0, 0 }, { 32, 0 }, { -16, -32 }, { 16, -32 } }
        for i, xy in ipairs(want) do
            assert.are.same({ "TOP", container("g1"), "TOP", xy[1], xy[2] }, icon("g1", i).points[1])
        end
        assert.are.same({ 94, 66 }, container("g1").size)
    end)

    it("re-saves a dragged centred group by its centre", function()
        local g = centred()
        local frame = container("g1")
        frame.GetCenter = function() return 1000, 500 end
        g.point, g.x, g.y = "TOPLEFT", 1, 2  -- what the drag itself saved
        frame.onDragStop(frame)
        assert.are.equal("CENTER", g.point)
        assert.are.equal(40, g.x)
        assert.are.equal(-40, g.y)
        assert.are.equal(40 / 1920, g.xPct)
        assert.are.same({ "CENTER", UIParent, "CENTER", 40, -40 }, frame.points[1])
    end)

    it("leaves other directions' drag position alone", function()
        CT:AddGroup("Left")
        local g = CT:GetGroup("g1")
        local frame = container("g1")
        frame.GetCenter = function() return 1000, 500 end
        g.point, g.x, g.y = "TOPLEFT", 1, 2
        frame.onDragStop(frame)
        assert.are.equal("TOPLEFT", g.point)
        assert.are.equal(1, g.x)
    end)
end)

describe("Loading settings", function()
    it("turns a saved Grow Down into Grow Right", function()
        reset()
        CT:GetMainGroup().growDirection = "DOWN"
        Castborn:FireCallback("INIT")
        assert.are.equal("RIGHT", CT:GetMainGroup().growDirection)
    end)
end)

describe("Default loading with other groups", function()
    local function classIds()
        local out = {}
        for _, s in ipairs(Castborn.SpellData:GetClassCooldowns("MAGE")) do out[#out + 1] = s.spellId end
        for _, s in ipairs(Castborn.SpellData:GetRacialCooldowns("Human")) do out[#out + 1] = s.spellId end
        return out
    end

    before_each(function()
        reset()
        dofile("Data/SpellData.lua")
    end)

    it("keeps other groups on a class change and skips their spells", function()
        local expected = classIds()
        local first = Castborn.SpellData:GetClassCooldowns("MAGE")[1]
        CT:AddGroup("Mine")
        local g1 = CT:GetGroup("g1")
        g1.spells = { { spellId = first.spellId, name = first.name, enabled = true }, spell(555) }
        CT:GetMainGroup().spells = { spell(99999, { custom = true }) }
        CastbornDB.cooldowns.loadedForClass = "WARRIOR"

        CT:LoadDefaultSpells()

        local main = ids("main")
        assert.are.equal(#expected, #main)  -- every default but the one in g1, plus the custom spell
        for i = 2, #expected do assert.are.equal(expected[i], main[i - 1]) end
        assert.are.equal(99999, main[#main])
        assert.are.same({ first.spellId, 555 }, ids("g1"))
        assert.are.equal("MAGE", CastbornDB.cooldowns.loadedForClass)
    end)

    it("copies default spells instead of storing SpellData's own lists", function()
        local classList = Castborn.SpellData:GetClassCooldowns("MAGE")
        local length = #classList
        CastbornDB.cooldowns.loadedForClass = "WARRIOR"
        CT:LoadDefaultSpells()
        assert.are.equal(length, #Castborn.SpellData:GetClassCooldowns("MAGE"))
        assert.are_not.equal(classList[1], CT:GetMainGroup().spells[1])
        CT:MoveSpell(classList[1].spellId, "main", 99)
        assert.are.equal(length, #Castborn.SpellData:GetClassCooldowns("MAGE"))
    end)

    it("skips spells in other groups on a version change", function()
        local expected = classIds()
        local list = Castborn.SpellData:GetClassCooldowns("MAGE")
        CT:AddGroup("Mine")
        CT:GetMainGroup().spells = { { spellId = list[1].spellId, name = list[1].name, enabled = true } }
        CT:GetGroup("g1").spells = { { spellId = list[2].spellId, name = list[2].name, enabled = true } }
        CastbornDB.cooldowns.loadedForClass = "MAGE"
        CastbornDB.cooldowns.defaultsLoaded = "0.0.1"

        CT:LoadDefaultSpells()

        assert.are.equal(#expected - 1, #CT:GetMainGroup().spells)
        assert.are.same({ list[2].spellId }, ids("g1"))
        local counted = false
        for _, msg in ipairs(chat) do
            if msg:find((#expected - 2) .. " new cooldown(s) added from defaults", 1, true) then counted = true end
        end
        assert.is_true(counted)
    end)
end)

describe("Profile switch", function()
    before_each(reset)

    it("hides groups the new profile does not have and builds the ones it does", function()
        CT:AddGroup("Test")
        CT:MoveSpell(103, "g1")
        CT:UpdateAll()
        assert.is_true(container("g1").shown)

        local onlyMain = Castborn:DeepCopy(CastbornDB.cooldowns)
        onlyMain.groups = { Castborn:DeepCopy(CT:GetMainGroup()) }
        local withG2 = Castborn:DeepCopy(CastbornDB.cooldowns)
        withG2.groups = { Castborn:DeepCopy(CT:GetMainGroup()),
            { id = "g2", name = "Other", spells = { spell(104) } } }
        CastbornDB.profiles.OnlyMain = { cooldowns = onlyMain }
        CastbornDB.profiles.WithG2 = { cooldowns = withG2 }

        Castborn.Profiles:ApplyProfile("OnlyMain")
        CT:UpdateAll()
        assert.is_false(container("g1").shown)

        Castborn.Profiles:ApplyProfile("WithG2")
        CT:UpdateAll()
        assert.is_table(container("g2"))
        assert.is_true(container("g2").shown)
        assert.are.equal("Interface\\Icons\\Spell104", icon("g2", 1).icon.texture)
        assert.are.equal(36, CT:GetGroup("g2").iconSize)
    end)
end)

describe("Masque", function()
    before_each(reset)

    it("keeps Cooldown Icons for main", function()
        assert.are.equal("Cooldown Icons", Castborn.Masque.groups.cooldowns.name)
    end)

    it("gives each group its own Masque group, keyed by id", function()
        -- g1's Masque group may exist from earlier specs under another name; it follows the
        -- group's current name
        CT:AddGroup("Test")
        local g = masqueGroupNamed("Cooldowns: Test")
        assert.is_table(g)
        assert.are.equal("Castborn", g.addon)
        assert.are.equal("Cooldowns_g1", g.staticId)
        assert.are.equal(20, #g.buttons)
    end)

    it("renames and deletes the Masque group with the group", function()
        CT:AddGroup("Test")
        local g = masqueGroupNamed("Cooldowns: Test")
        CT:RenameGroup("g1", "Renamed")
        assert.are.equal("Cooldowns: Renamed", g.name)
        CT:RemoveGroup("g1")
        assert.is_true(g.deleted)
    end)
end)

describe("Reset Positions", function()
    before_each(reset)

    it("puts other groups back below main", function()
        CT:AddGroup("Test")
        local g = CT:GetGroup("g1")
        g.point, g.x, g.y, g.xPct, g.yPct, g.anchored = "TOPLEFT", 500, 500, 0.3, 0.4, true

        Castborn:ResetPositions()

        assert.is_false(g.anchored)
        assert.are.equal("CENTER", g.point)
        assert.are.equal(-450, g.x)
        assert.are.equal(-348, g.y)
        assert.are.equal(-450 / 1920, g.xPct)
        assert.are.equal(-348 / 1080, g.yPct)
    end)
end)

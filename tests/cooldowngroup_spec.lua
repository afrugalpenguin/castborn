-- Characterisation specs for the cooldown strip's layout and test mode.
-- They pin what the tracker does today, quirks included, so the move into a group object
-- (cooldown groups, step 1) can be checked to change nothing.

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

-- Frames also remember whether they are shown, their texture, alpha and desaturation
local function augment(f)
    -- As in the game, a field nobody set is nil; only methods (CapitalCase) fall back to
    -- no-ops. The shared mock answers every key with a function, which makes unset fields
    -- such as ghost or dragIndicator look set.
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
    f.GetCenter = function() return 0, 0 end
    local createTexture = f.CreateTexture
    f.CreateTexture = function(...) return augment(createTexture(...)) end
    return f
end

local created = {}
local realCreateFrame = _G.CreateFrame
_G.CreateFrame = function(...)
    local f = augment(realCreateFrame(...))
    created[#created + 1] = f
    return f
end

dofile("Core.lua")
-- Load the tracker files in the order the TOC lists them, so this spec runs unchanged
-- whether or not the group object has been split out yet
for line in io.lines("Castborn.toc") do
    line = line:gsub("\r$", ""):gsub("\\", "/")
    if line == "Modules/CooldownGroup.lua" or line == "Modules/CooldownTracker.lua" then
        dofile(line)
    end
end

local cooldownFramesCreated = 0
Castborn:RegisterCallback("COOLDOWN_FRAME_CREATED", function()
    cooldownFramesCreated = cooldownFramesCreated + 1
end)

CastbornDB.cooldowns = {}
Castborn:FireCallback("INIT")
Castborn:FireCallback("READY")

local function copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

local function icon(i) return _G["Castborn_CD" .. i] end

local container = _G.Castborn_CooldownTracker
local trinketContainer = _G.Castborn_TrinketTracker

-- What READY left behind, before any update tick moves things
local atReady = {
    containerSize = copy(container.size),
    containerPoint = copy(container.points[1]),
    trinketSize = copy(trinketContainer.size),
    trinketPoint = copy(trinketContainer.points[1]),
    iconPoints = {},
    iconSizes = {},
}
for i = 1, 20 do
    atReady.iconPoints[i] = icon(i).points[1] and copy(icon(i).points[1])
    atReady.iconSizes[i] = copy(icon(i).size)
end

local updateFrame
for _, f in ipairs(created) do
    if f.scripts.OnUpdate then
        assert(not updateFrame, "more than one update loop")
        updateFrame = f
    end
end

local function tick()
    updateFrame.scripts.OnUpdate(updateFrame, 0.1)
end

local function mainGroup() return Castborn.CooldownTracker:GetMainGroup() end

local function configure(orientation, grow, perRow)
    local db = CastbornDB.cooldowns
    db.enabled = true
    db.showReadyGlow = true
    db.trackTrinkets = true
    local group = mainGroup()
    group.iconSize = 30
    group.spacing = 2
    group.iconsPerRow = perRow
    group.orientation = orientation
    group.growDirection = grow
end

-- Spells 1..n, all enabled and known unless listed otherwise
local function track(ids, opts)
    opts = opts or {}
    local spells = {}
    for _, id in ipairs(ids) do
        spells[#spells + 1] = { spellId = id, name = "Spell" .. id, enabled = not (opts.disabled and opts.disabled[id]) }
        known[id] = not (opts.unknown and opts.unknown[id])
    end
    mainGroup().spells = spells
    return spells
end

local function trackedIds()
    local ids = {}
    for i, spell in ipairs(mainGroup().spells) do ids[i] = spell.spellId end
    return ids
end

local function assertPoint(f, point, relativeTo, relativePoint, x, y)
    local p = f.points[1]
    assert.is_not_nil(p, "no point set")
    assert.are.equal(1, #f.points)
    assert.are.equal(point, p[1])
    assert.are.equal(relativeTo, p[2])
    assert.are.equal(relativePoint, p[3])
    assert.are.equal(x, p[4])
    assert.are.equal(y, p[5])
end

--------------------------------------------------------------------------------
-- Expected placement: 30px icons, 2px spacing, 3 per row, 5 icons.
-- Slots checked: first (1), mid-row (2), first wrapped (4) and last (5).
--------------------------------------------------------------------------------

local SLOTS = { 1, 2, 4, 5 }

local EXPECTED = {
    HORIZONTAL = {
        LEFT  = { "TOPRIGHT",   { [1] = { 0, 0 }, [2] = { -32, 0 }, [4] = { 0, -32 }, [5] = { -32, -32 } } },
        RIGHT = { "TOPLEFT",    { [1] = { 0, 0 }, [2] = { 32, 0 },  [4] = { 0, -32 }, [5] = { 32, -32 } } },
        UP    = { "BOTTOMLEFT", { [1] = { 0, 0 }, [2] = { 32, 0 },  [4] = { 0, 32 },  [5] = { 32, 32 } } },
        DOWN  = { "TOPLEFT",    { [1] = { 0, 0 }, [2] = { 32, 0 },  [4] = { 0, -32 }, [5] = { 32, -32 } } },
    },
    VERTICAL = {
        LEFT  = { "TOPRIGHT",   { [1] = { 0, 0 }, [2] = { 0, -32 }, [4] = { -32, 0 }, [5] = { -32, -32 } } },
        RIGHT = { "TOPLEFT",    { [1] = { 0, 0 }, [2] = { 0, -32 }, [4] = { 32, 0 },  [5] = { 32, -32 } } },
        UP    = { "BOTTOMLEFT", { [1] = { 0, 0 }, [2] = { 0, 32 },  [4] = { 32, 0 },  [5] = { 32, 32 } } },
        DOWN  = { "TOPLEFT",    { [1] = { 0, 0 }, [2] = { 0, -32 }, [4] = { 32, 0 },  [5] = { 32, -32 } } },
    },
}

-- Container for 5 icons: 3 x 2 horizontally, 2 x 3 vertically, plus 4px of height
local CONTAINER = {
    HORIZONTAL = { 94, 66 },
    VERTICAL = { 62, 98 },
}

local ORIENTATIONS = { "HORIZONTAL", "VERTICAL" }
local DIRECTIONS = { "LEFT", "RIGHT", "UP", "DOWN" }

--------------------------------------------------------------------------------

describe("Cooldown strip at READY", function()
    it("fires COOLDOWN_FRAME_CREATED for 20 icons and 2 trinkets", function()
        assert.are.equal(22, cooldownFramesCreated)
    end)

    it("sizes the container for all 20 icons with the default layout", function()
        -- 10 x 2 icons of 36px with 4px spacing, plus 4px of height
        assert.are.same({ 396, 80 }, atReady.containerSize)
        assert.are.same({ "CENTER", UIParent, "CENTER", -450, -300 }, atReady.containerPoint)
    end)

    it("places the trinket pair above the strip's right edge", function()
        assert.are.same({ 76, 40 }, atReady.trinketSize)
        assert.are.same({ "BOTTOMRIGHT", container, "TOPRIGHT", 0, 4 }, atReady.trinketPoint)
    end)

    it("lays out all 20 icons growing left", function()
        assert.are.same({ "TOPRIGHT", container, "TOPRIGHT", 0, 0 }, atReady.iconPoints[1])
        assert.are.same({ "TOPRIGHT", container, "TOPRIGHT", -360, 0 }, atReady.iconPoints[10])
        assert.are.same({ "TOPRIGHT", container, "TOPRIGHT", 0, -40 }, atReady.iconPoints[11])
        assert.are.same({ "TOPRIGHT", container, "TOPRIGHT", -360, -40 }, atReady.iconPoints[20])
        for i = 1, 20 do
            assert.are.same({ 36, 36 }, atReady.iconSizes[i])
        end
    end)
end)

describe("Live layout", function()
    for _, orientation in ipairs(ORIENTATIONS) do
        for _, grow in ipairs(DIRECTIONS) do
            it(orientation .. " growing " .. grow, function()
                configure(orientation, grow, 3)
                track({ 101, 102, 103, 104, 105 })
                tick()

                local point, offsets = EXPECTED[orientation][grow][1], EXPECTED[orientation][grow][2]
                for _, slot in ipairs(SLOTS) do
                    assertPoint(icon(slot), point, container, point, offsets[slot][1], offsets[slot][2])
                end
                for i = 1, 5 do assert.is_true(icon(i).shown) end
                for i = 6, 20 do assert.is_false(icon(i).shown) end
                assert.are.same(CONTAINER[orientation], container.size)
                assert.is_true(container.shown)
                -- Live updates size the icons from the current icon size
                for i = 1, 5 do assert.are.same({ 30, 30 }, icon(i).size) end
            end)
        end
    end

    it("hides the container when nothing is visible", function()
        configure("HORIZONTAL", "LEFT", 3)
        track({ 101 }, { unknown = { [101] = true } })
        tick()
        assert.is_false(container.shown)
    end)

    it("skips disabled and unknown spells and gives the slot to the next known one", function()
        configure("HORIZONTAL", "RIGHT", 3)
        track({ 1, 2, 3, 4 }, { disabled = { [2] = true }, unknown = { [3] = true } })
        tick()

        assert.are.equal("Interface\\Icons\\Spell1", icon(1).icon.texture)
        assertPoint(icon(1), "TOPLEFT", container, "TOPLEFT", 0, 0)
        assert.are.equal("Interface\\Icons\\Spell4", icon(2).icon.texture)
        assertPoint(icon(2), "TOPLEFT", container, "TOPLEFT", 32, 0)
        assert.is_true(icon(2).shown)
        assert.is_false(icon(3).shown)
        assert.are.same({ 62, 34 }, container.size)
    end)

    it("glows a spell back from a long cooldown until the glow is switched off", function()
        configure("HORIZONTAL", "LEFT", 3)
        track({ 900 })

        _G.GetSpellCooldown = function() return 100, 30 end
        tick()
        assert.is_true(icon(1).icon.desaturated)
        assert.are.equal(0, icon(1).glow.alpha)

        _G.GetSpellCooldown = function() return 0, 0 end
        tick()
        assert.is_false(icon(1).icon.desaturated)
        assert.are.equal(0.3, icon(1).glow.alpha)

        Castborn:FireCallback("COOLDOWNS_GLOW_OFF")
        assert.are.equal(0, icon(1).glow.alpha)
    end)
end)

describe("Test mode layout", function()
    after_each(function() Castborn:EndTestCooldowns() end)

    for _, orientation in ipairs(ORIENTATIONS) do
        for _, grow in ipairs(DIRECTIONS) do
            it(orientation .. " growing " .. grow, function()
                configure(orientation, grow, 3)
                track({ 101, 102, 103, 104, 105 })
                Castborn:TestCooldowns()

                local point, offsets = EXPECTED[orientation][grow][1], EXPECTED[orientation][grow][2]
                for _, slot in ipairs(SLOTS) do
                    assertPoint(icon(slot), point, container, point, offsets[slot][1], offsets[slot][2])
                end
                for i = 1, 5 do
                    assert.is_true(icon(i).shown)
                    assert.are.same({ 30, 30 }, icon(i).size)
                end
                for i = 6, 20 do assert.is_false(icon(i).shown) end
                assert.is_true(container.shown)
                -- Test mode fits the container to the test icons, like the live update
                assert.are.same(CONTAINER[orientation], container.size)
                -- The second icon is the sample cooldown
                assert.is_true(icon(2).icon.desaturated)
                assert.is_false(icon(1).icon.desaturated)
            end)
        end
    end

    it("shows unknown spells but skips disabled ones", function()
        configure("HORIZONTAL", "RIGHT", 3)
        track({ 1, 2, 3, 4 }, { disabled = { [2] = true }, unknown = { [3] = true } })
        Castborn:TestCooldowns()

        assert.are.equal("Interface\\Icons\\1", icon(1).icon.texture)
        assert.are.equal("Interface\\Icons\\3", icon(2).icon.texture)
        assert.are.equal("Interface\\Icons\\4", icon(3).icon.texture)
        assertPoint(icon(3), "TOPLEFT", container, "TOPLEFT", 64, 0)
        assert.is_false(icon(4).shown)
        -- Sized for the three test icons, though only two are known
        assert.are.same({ 94, 34 }, container.size)
    end)

    it("shows sample trinkets until test mode ends", function()
        configure("HORIZONTAL", "LEFT", 3)
        track({ 101 })
        Castborn:TestCooldowns()

        local t1, t2 = _G.Castborn_Trinket1, _G.Castborn_Trinket2
        assertPoint(t1, "RIGHT", trinketContainer, "RIGHT", 0, 0)
        assertPoint(t2, "RIGHT", trinketContainer, "RIGHT", -32, 0)
        assert.are.same({ 30, 30 }, t1.size)
        assert.is_true(t1.icon.desaturated)
        assert.is_false(t2.icon.desaturated)
        assert.are.same({ 62, 34 }, trinketContainer.size)
        assert.is_true(trinketContainer.shown)

        -- The live loop leaves the samples alone during test mode
        tick()
        assert.is_true(trinketContainer.shown)
        assert.is_true(t1.icon.desaturated)

        -- and takes over again afterwards; with none equipped the trinkets hide
        Castborn:EndTestCooldowns()
        tick()
        assert.is_false(trinketContainer.shown)
    end)

    it("cleans up when test mode ends", function()
        configure("HORIZONTAL", "LEFT", 3)
        track({ 101, 102 })
        Castborn:TestCooldowns()
        assert.is_function(icon(1).scripts.OnDragStart)

        Castborn:EndTestCooldowns()
        assert.is_nil(icon(1).scripts.OnDragStart)
        assert.is_nil(icon(1).scripts.OnDragStop)
        assert.is_nil(icon(1).scripts.OnUpdate)
        assert.is_false(icon(1).shown)
        assert.is_false(container.shown)
    end)
end)

describe("Test mode drag to reorder", function()
    -- Drag slot 1 onto slot 3, in one row of 30px icons with 2px spacing.
    -- Columns count from the container's right edge when growing left, else from its left.
    local CURSOR_X = { LEFT = 300 - 64, RIGHT = 64, UP = 64, DOWN = 64 }

    -- The marker straddles the target slot's leading edge: 2px past its right edge when
    -- growing left (mirroring the others), 2px before its left edge otherwise
    local DRAG = {
        LEFT  = { point = "TOPRIGHT",   marker = -62, highlight = -64, third = -32 },
        RIGHT = { point = "TOPLEFT",    marker = 62,  highlight = 64,  third = 32 },
        UP    = { point = "BOTTOMLEFT", marker = 62,  highlight = 64,  third = 32 },
        DOWN  = { point = "TOPLEFT",    marker = 62,  highlight = 64,  third = 32 },
    }

    before_each(function()
        container.GetLeft = function() return 0 end
        container.GetRight = function() return 300 end
        container.GetTop = function() return 100 end
        container.GetBottom = function() return 66 end
    end)

    after_each(function()
        Castborn:EndTestCooldowns()
        _G.GetCursorPosition = function() return 0, 0 end
    end)

    local function runAnimation(f)
        for _ = 1, 100 do
            local script = f.animFrame and f.animFrame.scripts.OnUpdate
            if not script then return end
            script(f.animFrame, 0.016)
        end
        error("animation did not settle")
    end

    for _, grow in ipairs(DIRECTIONS) do
        it("growing " .. grow, function()
            local want = DRAG[grow]
            configure("HORIZONTAL", grow, 10)
            track({ 1, 2, 3, 4, 5 })
            Castborn:TestCooldowns()

            local dragged = icon(1)
            dragged.scripts.OnDragStart(dragged)

            -- The ghost stays in the original slot
            assertPoint(dragged.ghost, want.point, container, want.point, 0, 0)
            assert.are.same({ 30, 30 }, dragged.ghost.size)
            assert.is_true(dragged.ghost.shown)

            _G.GetCursorPosition = function() return CURSOR_X[grow], 90 end
            dragged.scripts.OnUpdate(dragged, 0.016)

            assertPoint(container.insertMarker, want.point, container, want.point, want.marker, 0)
            assert.are.same({ 4, 30 }, container.insertMarker.size)
            assertPoint(container.insertMarkerGlow, "CENTER", container.insertMarker, "CENTER", 0, 0)
            assert.are.same({ 8, 30 }, container.insertMarkerGlow.size)
            assertPoint(container.slotHighlight, want.point, container, want.point, want.highlight, 0)
            assert.are.same({ 30, 30 }, container.slotHighlight.size)

            -- Icons 2 and 3 slide back one slot to make room
            assert.are.equal(0, icon(2).targetX)
            assert.are.equal(0, icon(2).targetY)
            assert.are.equal(want.third, icon(3).targetX)
            assert.are.equal(0, icon(3).targetY)
            runAnimation(icon(3))
            assertPoint(icon(3), want.point, container, want.point, want.third, 0)

            dragged.scripts.OnDragStop(dragged)

            -- The dragged spell lands in the slot it was dropped on, as the preview showed
            assert.are.same({ 2, 3, 1, 4, 5 }, trackedIds())
            assert.is_false(dragged.ghost.shown)
            assert.is_false(container.insertMarker.shown)
            assert.is_false(container.insertMarkerGlow.shown)
            assert.is_false(container.slotHighlight.shown)
            assert.are.equal("Interface\\Icons\\2", icon(1).icon.texture)
            assert.are.equal("Interface\\Icons\\3", icon(2).icon.texture)
            assert.are.equal("Interface\\Icons\\1", icon(3).icon.texture)
        end)
    end

    -- Drag the icon in slot `from` and drop it with the cursor over slot `to`, in one row
    -- growing right (columns from the left edge, 32px apart)
    local function dragAndDrop(from, to)
        local dragged = icon(from)
        dragged.scripts.OnDragStart(dragged)
        _G.GetCursorPosition = function() return (to - 1) * 32, 90 end
        dragged.scripts.OnUpdate(dragged, 0.016)
        dragged.scripts.OnDragStop(dragged)
    end

    it("drops a backwards drag into the slot it was dropped on", function()
        configure("HORIZONTAL", "RIGHT", 10)
        track({ 1, 2, 3, 4, 5 })
        Castborn:TestCooldowns()
        dragAndDrop(4, 2)
        assert.are.same({ 1, 4, 2, 3, 5 }, trackedIds())
    end)

    it("keeps a disabled spell in place when dragging past it", function()
        configure("HORIZONTAL", "RIGHT", 10)
        -- Test mode shows 1, 3, 4 and 5; spell 2 is disabled and hidden
        track({ 1, 2, 3, 4, 5 }, { disabled = { [2] = true } })
        Castborn:TestCooldowns()
        dragAndDrop(1, 3)
        assert.are.same({ 2, 3, 4, 1, 5 }, trackedIds())
        assert.are.equal("Interface\\Icons\\3", icon(1).icon.texture)
        assert.are.equal("Interface\\Icons\\4", icon(2).icon.texture)
        assert.are.equal("Interface\\Icons\\1", icon(3).icon.texture)
    end)

    -- Start dragging slot 1 and hover the cursor at (x, y)
    local function hover(x, y)
        local dragged = icon(1)
        dragged.scripts.OnDragStart(dragged)
        _G.GetCursorPosition = function() return x, y end
        dragged.scripts.OnUpdate(dragged, 0.016)
    end

    it("targets the slot under the cursor in a vertical layout", function()
        -- Two per column: slots 1 and 2 in the first column, 3 and 4 in the second
        configure("VERTICAL", "RIGHT", 2)
        track({ 1, 2, 3, 4, 5 })
        Castborn:TestCooldowns()

        hover(47, 85)  -- middle of slot 3: second column, top
        assertPoint(container.slotHighlight, "TOPLEFT", container, "TOPLEFT", 32, 0)

        icon(1).scripts.OnDragStop(icon(1))
        Castborn:TestCooldowns()
        hover(15, 53)  -- middle of slot 2: first column, second row
        assertPoint(container.slotHighlight, "TOPLEFT", container, "TOPLEFT", 0, -32)
    end)

    it("counts rows from the bottom when growing up", function()
        -- Three per row, rows stacking upwards from the container's bottom edge
        configure("HORIZONTAL", "UP", 3)
        track({ 1, 2, 3, 4, 5 })
        Castborn:TestCooldowns()
        container.GetRight = function() return 94 end
        container.GetTop = function() return 66 end
        container.GetBottom = function() return 0 end

        hover(15, 47)  -- middle of slot 4: second row up, first column
        assertPoint(container.slotHighlight, "BOTTOMLEFT", container, "BOTTOMLEFT", 0, 32)
    end)
end)

describe("Castbar anchoring", function()
    local db
    local iconFrame = augment(realCreateFrame("Frame"))
    local castbar = augment(realCreateFrame("Frame"))
    castbar.iconFrame = iconFrame

    before_each(function()
        db = mainGroup()
        db.anchored = true
    end)

    after_each(function()
        db.anchored = true
        iconFrame.shown = true
    end)

    it("anchors to the left of the castbar icon when the castbar is created", function()
        Castborn:FireCallback("PLAYER_CASTBAR_CREATED", castbar)
        assertPoint(container, "RIGHT", iconFrame, "LEFT", -4, 0)
        assert.is_true(container.isAnchored)
        assert.are.equal(iconFrame, container.anchorParent)
    end)

    it("reattaches to the castbar itself when its icon is hidden", function()
        iconFrame.shown = false
        Castborn:FireCallback("REATTACH_COOLDOWNS")
        assertPoint(container, "RIGHT", castbar, "LEFT", -4, 0)
        assert.is_true(db.anchored)
        assert.are.equal(castbar, container.anchorParent)
    end)

    it("records the detach", function()
        Castborn:FireCallback("DETACH_COOLDOWNS")
        assert.is_false(db.anchored)
    end)
end)

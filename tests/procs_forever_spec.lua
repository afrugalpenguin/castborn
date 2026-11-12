-- Forever proc tracker: Blizzard's AuraContainer draws the procs; Castborn only configures it.
require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}

-- Any capitalised method is a no-op unless set; Create* calls return further mocks
local function mock(fields)
    local t = fields or {}
    t.calls = t.calls or {}
    setmetatable(t, { __index = function(self, k)
        if type(k) ~= "string" or not k:match("^%u") then return nil end
        if k:match("^Create") then
            return function(_, ...)
                local child = mock()
                self.calls[#self.calls + 1] = { k, ... }
                return child
            end
        end
        return function(_, ...) self.calls[#self.calls + 1] = { k, ... } end
    end })
    return t
end

local function called(obj, name)
    local out = {}
    for _, c in ipairs(obj.calls) do
        if c[1] == name then out[#out + 1] = c end
    end
    return out
end

_G.AnchorUtil = {
    FlowLayoutAxis = { Horizontal = 0, Vertical = 1 },
    FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 },
}

-- The mock AuraContainer: records the group and builds three buttons through initializeFrame,
-- as Blizzard pre-creates a batch
local container, containerError
local function newContainer()
    local c = mock()
    c.groups = {}
    function c:AddAuraGroup(key, filter, opts)
        self.groups[key] = { filter = filter, opts = opts, frames = {}, enabled = true }
        for i = 1, 3 do
            local b = mock()
            self.groups[key].frames[i] = b
            opts.initializeFrame(b)
        end
    end
    function c:GetAuraGroupFrameCount(key) return #self.groups[key].frames end
    function c:GetAuraGroupFrame(key, i) return self.groups[key].frames[i] end
    function c:SetAuraGroupCandidateFilters(key, f) self.groups[key].opts.candidateFilters = f end
    function c:SetAuraGroupEnabled(key, on) self.groups[key].enabled = on end
    function c:SetAuraGroupLayout(key, l) self.groups[key].opts.layout = l end
    return c
end

local realCreateFrame = _G.CreateFrame
_G.CreateFrame = function(frameType, name, parent, template)
    if frameType == "AuraContainer" then
        if containerError then error(containerError) end
        assert(template == "CustomAuraContainerTemplate")
        container = newContainer()
        container.parent = parent
        return container
    end
    return realCreateFrame(frameType, name, parent, template)
end

-- Aura reads: allowed out of combat, a test failure in combat
local inCombat = false
local buffs = {}
_G.InCombatLockdown = function() return inCombat end
_G.UnitAffectingCombat = function() return inCombat end
_G.C_UnitAuras = {
    GetAuraDataByIndex = function(_, i)
        assert(not inCombat, "read an aura in combat")
        return buffs[i]
    end,
}
_G.UnitClass = function() return "Paladin", "PALADIN" end
_G.GetSpellTexture = function(id) return "Interface\\Icons\\" .. tostring(id) end

dofile("Core.lua")
dofile("Modules/ProcTracker_Forever.lua")

local PT = Castborn.ProcTracker

-- One login for the whole file
_G.CastbornDB = nil
local mainFrame = _G.CastbornMain
mainFrame.scripts.OnEvent(mainFrame, "ADDON_LOADED", "Castborn")
Castborn:FireCallback("READY")

local function group() return container.groups.procs end
local function filterIds() return group().opts.candidateFilters.includeSpellIDs end

describe("Forever proc tracker", function()
    before_each(function()
        inCombat = false
        buffs = {}
    end)

    describe("on login", function()
        it("loads the Forever class list", function()
            local names = {}
            for _, s in ipairs(CastbornDB.procs.trackedSpells) do names[s.name] = s.spellId end
            assert.are.equal(20050, names["Vengeance"])
        end)

        it("drops a saved entry that has left the class list, such as Seal of Command", function()
            table.insert(CastbornDB.procs.trackedSpells, { spellId = 20375, name = "Seal of Command" })
            Castborn:FireCallback("INIT")
            for _, s in ipairs(CastbornDB.procs.trackedSpells) do
                assert.are_not.equal("Seal of Command", s.name)
            end
            assert.is_nil(PT:GetFilterIds()[20375])
        end)

        it("builds a player container inside the strip", function()
            assert.are.equal(_G.Castborn_ProcTracker, container.parent)
            assert.are.same({ "SetUnit", "player" }, called(container, "SetUnit")[1])
            assert.is_true(#called(container, "SetEnabled") > 0)
            assert.are.equal("ok", PT.status)
        end)

        it("filters a helpful group to the tracked IDs, as a lookup table", function()
            assert.are.equal("HELPFUL", group().filter)
            assert.are.equal(8, group().opts.maxFrameCount)
            assert.is_true(filterIds()[20050])
            for k, v in pairs(filterIds()) do
                assert.are.equal("number", type(k))
                assert.is_true(v)
            end
        end)

        it("gives each button its icon, timer, stack count and glow", function()
            local b = group().frames[1]
            assert.are.equal(1, #called(b, "SetIcon"))
            assert.are.equal(1, #called(b, "SetDurationText"))
            assert.are.equal(1, #called(b, "SetApplicationCount"))
            assert.are.equal(1, #called(b, "AddAuraShownAnimation"))
        end)
    end)

    describe("layout", function()
        local function layoutFor(settings)
            local db = { iconSize = 28, spacing = 4, iconsPerRow = 3, orientation = "HORIZONTAL" }
            for k, v in pairs(settings) do db[k] = v end
            return PT.GetLayout(db)
        end

        it("grows right in one row by default", function()
            local l = layoutFor({ growDirection = "RIGHT" })
            assert.are.equal(0, l.axis)
            assert.are.equal(1, l.horizontal)
            assert.are.equal("LEFT", l.point)
            assert.are.equal(math.huge, l.maxLineSize)
        end)

        it("grows left from the right edge", function()
            local l = layoutFor({ growDirection = "LEFT" })
            assert.are.equal(-1, l.horizontal)
            assert.are.equal("RIGHT", l.point)
        end)

        it("centres the row on the strip", function()
            assert.are.equal("CENTER", layoutFor({ growDirection = "CENTRE" }).point)
        end)

        it("treats Up and Down as Right while horizontal, as the TBC tracker does", function()
            assert.are.equal("LEFT", layoutFor({ growDirection = "UP" }).point)
            assert.are.equal(1, layoutFor({ growDirection = "DOWN" }).horizontal)
        end)

        it("stacks vertically, wrapping every icons-per-row", function()
            local down = layoutFor({ orientation = "VERTICAL", growDirection = "DOWN" })
            assert.are.equal(1, down.axis)
            assert.are.equal(-1, down.vertical)
            assert.are.equal("TOPLEFT", down.point)
            assert.are.equal(3 * 28 + 2 * 4, down.maxLineSize)
            local up = layoutFor({ orientation = "VERTICAL", growDirection = "UP" })
            assert.are.equal(1, up.vertical)
            assert.are.equal("BOTTOMLEFT", up.point)
        end)

        it("sizes and spaces the icons from the settings", function()
            local l = layoutFor({})
            assert.are.equal(28, l.elementWidth)
            assert.are.equal(28, l.elementHeight)
            assert.are.equal(4, l.elementSpacing)
            assert.are.equal(4, l.lineSpacing)
        end)
    end)

    describe("settings", function()
        after_each(function()
            CastbornDB.procs.showDuration = true
            CastbornDB.procs.showGlow = true
            PT:RefreshOptions()
        end)

        it("drops the timer from every button when Show Timers is off", function()
            CastbornDB.procs.showDuration = false
            PT:RefreshOptions()
            for _, b in ipairs(group().frames) do
                assert.is_true(#called(b, "ClearDurationText") > 0)
            end
        end)

        it("drops the glow when Show Proc Glow is off", function()
            CastbornDB.procs.showGlow = false
            PT:RefreshOptions()
            assert.is_true(#called(group().frames[1], "RemoveAuraShownAnimation") > 0)
        end)

        it("re-applies the layout on UpdateLayout", function()
            CastbornDB.procs.iconSize = 40
            PT:UpdateLayout()
            assert.are.equal(40, group().opts.layout.elementWidth)
            CastbornDB.procs.iconSize = 28
            PT:UpdateLayout()
        end)
    end)

    describe("learning spell IDs out of combat", function()
        after_each(function() CastbornDB.procs.learnedIds = {} PT:RefreshFilter() end)

        it("adds a tracked buff's real ID from an aura update", function()
            PT:OnEvent("UNIT_AURA", "player", { addedAuras = { { name = "Vengeance", spellId = 9999001 } } })
            assert.is_true(filterIds()[9999001])
        end)

        it("ignores buffs it does not track", function()
            PT:OnEvent("UNIT_AURA", "player", { addedAuras = { { name = "Mark of the Wild", spellId = 9999002 } } })
            assert.is_nil(filterIds()[9999002])
        end)

        it("scans every buff on a full update", function()
            buffs = { { name = "Blessing of Might", spellId = 27140 }, { name = "Vengeance", spellId = 9999003 } }
            PT:OnEvent("UNIT_AURA", "player", { isFullUpdate = true })
            assert.is_true(filterIds()[9999003])
        end)

        it("survives a blocked read, as in a dungeon", function()
            _G.C_UnitAuras.GetAuraDataByIndex = function() error("Auras cannot be accessed when secret") end
            assert.has_no.errors(function()
                PT:OnEvent("UNIT_AURA", "player", { isFullUpdate = true })
            end)
            _G.C_UnitAuras.GetAuraDataByIndex = function(_, i)
                assert(not inCombat, "read an aura in combat")
                return buffs[i]
            end
        end)

        it("never reads auras or the payload in combat", function()
            inCombat = true
            local payload = setmetatable({}, { __index = function() error("indexed the payload in combat") end })
            assert.has_no.errors(function() PT:OnEvent("UNIT_AURA", "player", payload) end)
        end)
    end)

    -- Forever has no trinket procs of its own yet, so these use a stand-in
    local function withTrinket()
        PT.sharedProcs = { { spellId = 33370, name = "Spell Haste" } }
        PT:SetTrinketProcs(true)
    end
    local function withoutTrinket()
        PT:SetTrinketProcs(false)
        PT.sharedProcs = {}
    end

    describe("filter changes in combat", function()
        before_each(withTrinket)
        after_each(function()
            inCombat = false
            withoutTrinket()
        end)

        it("waits until combat ends", function()
            inCombat = true
            PT:SetTrinketProcs(false)
            assert.is_true(filterIds()[33370])
            inCombat = false
            PT:OnEvent("PLAYER_REGEN_ENABLED")
            assert.is_nil(filterIds()[33370])
        end)
    end)

    describe("trinket procs", function()
        before_each(withTrinket)
        after_each(withoutTrinket)

        it("adds and removes the shared trinket procs", function()
            assert.is_true(filterIds()[33370])
            PT:SetTrinketProcs(false)
            assert.is_nil(filterIds()[33370])
            PT:SetTrinketProcs(true)
            assert.is_true(filterIds()[33370])
        end)
    end)

    describe("test mode", function()
        it("swaps the real group for sample icons, and back", function()
            Castborn:TestProcs()
            assert.is_false(group().enabled)
            assert.is_true(_G.Castborn_Proc1 ~= nil)
            Castborn:EndTestProcs()
            assert.is_true(group().enabled)
        end)
    end)

    describe("Masque", function()
        it("falls back to Castborn's border when Masque refuses a button", function()
            local saved = Castborn.Masque
            Castborn.Masque = { enabled = true, AddButton = function() error("forbidden") end }
            local b = mock()
            assert.has_no.errors(function() PT.InitButton(b) end)
            Castborn.Masque = saved
            assert.matches("forbidden", PT.masqueStatus)
        end)
    end)
end)

describe("Forever proc tracker without AuraContainer", function()
    it("records why and does not error", function()
        containerError = "Unknown frame type 'AuraContainer'"
        assert.has_no.errors(function() PT:BuildContainer() end)
        assert.matches("^unavailable: .*Unknown frame type", PT.status)
        containerError = nil
    end)
end)

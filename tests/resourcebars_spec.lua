require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
dofile("Core.lua")
dofile("Modules/ResourceBars.lua")

describe("Resource bars (TBC behaviour)", function()
    local RB = Castborn.ResourceBars
    local db

    -- A font string that remembers what it was given
    local function spyText()
        local fs = { calls = {} }
        function fs:SetText(text) self.text = text end
        function fs:SetFormattedText(...) self.calls[#self.calls + 1] = { ... } end
        return fs
    end

    before_each(function()
        db = Castborn:MergeDefaults({}, RB.defaults)
        Castborn.db = Castborn.db or {}
        Castborn.db.resources = db
        RB.inCombat = false
        RB.testModeActive = false
        _G.PowerBarColor = nil
    end)

    after_each(function()
        _G.PowerBarColor = nil
        _G.UnitPowerType = nil
        _G.UnitPower = nil
        _G.UnitPowerMax = nil
        _G.UnitHealth = nil
        _G.UnitHealthMax = nil
    end)

    describe("ShortNumber", function()
        it("leaves numbers under a thousand whole", function()
            assert.are.equal("0", RB:ShortNumber(0))
            assert.are.equal("999", RB:ShortNumber(999))
        end)

        it("switches to thousands at 1000", function()
            assert.are.equal("1k", RB:ShortNumber(1000))
            assert.are.equal("12.3k", RB:ShortNumber(12345))
            assert.are.equal("999.9k", RB:ShortNumber(999949))
        end)

        it("switches to millions where thousands would round up to 1000k", function()
            assert.are.equal("1m", RB:ShortNumber(999950))
            assert.are.equal("1m", RB:ShortNumber(1000000))
            assert.are.equal("1.2m", RB:ShortNumber(1234567))
        end)
    end)

    describe("BuildText", function()
        it("shows nothing for NONE", function()
            assert.are.equal("", RB:BuildText("NONE", 12345, 20000))
        end)

        it("shows the current value for CURRENT", function()
            assert.are.equal("12.3k", RB:BuildText("CURRENT", 12345, 20000))
        end)

        it("shows current and max for CURRENT_MAX", function()
            assert.are.equal("12.3k / 20k", RB:BuildText("CURRENT_MAX", 12345, 20000))
        end)

        it("shows a rounded percentage for PERCENT", function()
            assert.are.equal("62%", RB:BuildText("PERCENT", 12345, 20000))
        end)

        it("shows both for CURRENT_PERCENT", function()
            assert.are.equal("12.3k (62%)", RB:BuildText("CURRENT_PERCENT", 12345, 20000))
        end)

        it("copes with a max of 0", function()
            assert.are.equal("0", RB:BuildText("CURRENT", 0, 0))
            assert.are.equal("0 / 0", RB:BuildText("CURRENT_MAX", 0, 0))
            assert.are.equal("0%", RB:BuildText("PERCENT", 0, 0))
            assert.are.equal("0 (0%)", RB:BuildText("CURRENT_PERCENT", 0, 0))
        end)

        it("falls back to CURRENT_MAX for an unknown format", function()
            assert.are.equal("5 / 10", RB:BuildText("NONSENSE", 5, 10))
        end)
    end)

    describe("FormatText", function()
        it("uses the saved text format and plain SetText", function()
            db.textFormat = "PERCENT"
            local fs = spyText()
            RB:FormatText(fs, 50, 200, "player", "health")
            assert.are.equal("25%", fs.text)
            assert.are.equal(0, #fs.calls)
        end)

        it("supports every format on TBC", function()
            assert.is_true(RB:SupportsPercent())
        end)
    end)

    describe("SetBarValues", function()
        it("sets the range and value", function()
            local bar = {}
            function bar:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
            function bar:SetValue(v) self.value = v end
            RB:SetBarValues(bar, 40, 80)
            assert.are.same({ 0, 80, 40 }, { bar.min, bar.max, bar.value })
        end)

        it("clamps max to at least 1, so an empty bar never divides by zero", function()
            local bar = {}
            function bar:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
            function bar:SetValue(v) self.value = v end
            RB:SetBarValues(bar, 0, 0)
            assert.are.equal(1, bar.max)
        end)
    end)

    describe("ShouldHidePower", function()
        it("hides the power bar when the player has no power", function()
            assert.is_true(RB:ShouldHidePower(0))
        end)

        it("shows it otherwise", function()
            assert.is_false(RB:ShouldHidePower(100))
        end)
    end)

    describe("GetPowerColor", function()
        it("uses PowerBarColor by token when the client has it", function()
            _G.PowerBarColor = { RAGE = { r = 0.9, g = 0.1, b = 0.1 } }
            assert.are.same({ 0.9, 0.1, 0.1 }, { RB:GetPowerColor(1, "RAGE") })
        end)

        it("falls back to PowerBarColor by index when the token is missing", function()
            _G.PowerBarColor = { [3] = { r = 0.8, g = 0.8, b = 0.2 } }
            assert.are.same({ 0.8, 0.8, 0.2 }, { RB:GetPowerColor(3, "ENERGY") })
        end)

        it("uses its own table when the client has no PowerBarColor", function()
            assert.are.same({ 0, 0, 1 }, { RB:GetPowerColor(0, "MANA") })
            assert.are.same({ 1, 0, 0 }, { RB:GetPowerColor(1, "RAGE") })
            assert.are.same({ 1, 1, 0 }, { RB:GetPowerColor(3, "ENERGY") })
        end)

        it("uses its own table when PowerBarColor lacks the type", function()
            _G.PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
            assert.are.same({ 1, 0, 0 }, { RB:GetPowerColor(1, "RAGE") })
        end)

        it("falls back to the mana colour for an unknown type", function()
            assert.are.same({ 0, 0, 1 }, { RB:GetPowerColor(99, "WEIRD") })
            assert.are.same({ 0, 0, 1 }, { RB:GetPowerColor(nil, nil) })
        end)
    end)

    describe("GetHealthColor", function()
        it("uses the class colour in CLASS mode", function()
            assert.are.same({ 0.25, 0.78, 0.92 }, { RB:GetHealthColor(db) })
        end)

        it("uses the saved colour in CUSTOM mode", function()
            db.healthColorMode = "CUSTOM"
            db.healthColor = { 0.1, 0.2, 0.3, 1 }
            assert.are.same({ 0.1, 0.2, 0.3 }, { RB:GetHealthColor(db) })
        end)
    end)

    describe("UNIT_DISPLAYPOWER", function()
        local colour, powerType, powerToken

        before_each(function()
            powerType, powerToken = 0, "MANA"
            _G.UnitPowerType = function() return powerType, powerToken end
            _G.UnitPower = function() return 50 end
            _G.UnitPowerMax = function() return 100 end
            _G.UnitHealth = function() return 50 end
            _G.UnitHealthMax = function() return 100 end
            RB:CreateFrames()
            RB.frame.power.bar.SetStatusBarColor = function(_, r, g, b) colour = { r, g, b } end
        end)

        it("recolours the power bar when the power type changes", function()
            powerType, powerToken = 3, "ENERGY"
            RB:OnEvent("UNIT_DISPLAYPOWER", "player")
            assert.are.same({ 1, 1, 0 }, colour)
            powerType, powerToken = 1, "RAGE"
            RB:OnEvent("UNIT_DISPLAYPOWER", "player")
            assert.are.same({ 1, 0, 0 }, colour)
        end)

        it("keeps the custom colour in CUSTOM mode", function()
            db.powerColorMode = "CUSTOM"
            db.powerColor = { 0.5, 0.4, 0.3, 1 }
            powerType, powerToken = 1, "RAGE"
            RB:OnEvent("UNIT_DISPLAYPOWER", "player")
            assert.are.same({ 0.5, 0.4, 0.3 }, colour)
        end)

        it("refreshes the power values", function()
            local value
            RB.frame.power.bar.SetValue = function(_, v) value = v end
            _G.UnitPower = function() return 77 end
            RB:OnEvent("UNIT_DISPLAYPOWER", "player")
            assert.are.equal(77, value)
        end)
    end)

    describe("visibility", function()
        local function visibility()
            return { RB:GetVisibility(db) }
        end

        it("always shows in ALWAYS mode", function()
            assert.are.same({ true, 1 }, visibility())
            RB:OnEvent("PLAYER_REGEN_DISABLED")
            assert.are.same({ true, 1 }, visibility())
        end)

        it("shows only in combat in COMBAT mode", function()
            db.visibility = "COMBAT"
            assert.are.same({ false, 1 }, visibility())
            RB:OnEvent("PLAYER_REGEN_DISABLED")
            assert.are.same({ true, 1 }, visibility())
            RB:OnEvent("PLAYER_REGEN_ENABLED")
            assert.are.same({ false, 1 }, visibility())
        end)

        it("fades out of combat in FADE mode", function()
            db.visibility = "FADE"
            db.fadeAlpha = 0.4
            assert.are.same({ true, 0.4 }, visibility())
            RB:OnEvent("PLAYER_REGEN_DISABLED")
            assert.are.same({ true, 1 }, visibility())
            RB:OnEvent("PLAYER_REGEN_ENABLED")
            assert.are.same({ true, 0.4 }, visibility())
        end)

        it("hides when disabled", function()
            db.enabled = false
            assert.is_false((RB:GetVisibility(db)))
        end)

        it("hides when both bars are turned off", function()
            db.showHealth, db.showPower = false, false
            assert.is_false((RB:GetVisibility(db)))
        end)

        it("shows fully in test mode, whatever the combat state", function()
            db.visibility = "COMBAT"
            RB.testModeActive = true
            assert.are.same({ true, 1 }, visibility())
        end)
    end)

    describe("frame placement and locking", function()
        local originalApplyPosition

        before_each(function()
            _G.UnitPowerType = function() return 0, "MANA" end
            _G.UnitPower = function() return 50 end
            _G.UnitPowerMax = function() return 100 end
            _G.UnitHealth = function() return 50 end
            _G.UnitHealthMax = function() return 100 end
            originalApplyPosition = Castborn.ApplyPosition
        end)

        after_each(function()
            Castborn.ApplyPosition = originalApplyPosition
        end)

        it("applies the saved position even when anchored, in case the castbar never appears", function()
            local positioned
            Castborn.ApplyPosition = function(_, _, key) positioned = key end
            db.anchored = true
            RB:CreateFrames()
            assert.are.equal("resources", positioned)
        end)

        it("re-applies its visibility once frames are locked", function()
            RB:CreateFrames()
            local shown = false
            RB.frame.Show = function() shown = true end
            Castborn:LockFrames()
            assert.is_true(shown)
        end)
    end)

    describe("RegisterEvents", function()
        local function eventFrame(rejected)
            local f = { plain = {}, unit = {} }
            function f:RegisterEvent(event)
                if rejected[event] then error("unknown event " .. event) end
                self.plain[event] = true
            end
            function f:RegisterUnitEvent(event, unit)
                if rejected[event] then error("unknown event " .. event) end
                self.unit[event] = unit
            end
            return f
        end

        it("registers unit events for the player only", function()
            local f = eventFrame({})
            RB:RegisterEvents(f)
            assert.are.equal("player", f.unit.UNIT_HEALTH)
            assert.are.equal("player", f.unit.UNIT_DISPLAYPOWER)
            assert.is_true(f.plain.PLAYER_REGEN_DISABLED)
            assert.are.same({}, RB.skippedEvents)
        end)

        it("never registers UNIT_HEALTH_FREQUENT", function()
            local f = eventFrame({})
            RB:RegisterEvents(f)
            assert.is_nil(f.unit.UNIT_HEALTH_FREQUENT)
            assert.is_nil(f.plain.UNIT_HEALTH_FREQUENT)
        end)

        it("skips and records events the client rejects", function()
            local f = eventFrame({ UNIT_POWER_FREQUENT = true })
            assert.has_no.errors(function() RB:RegisterEvents(f) end)
            assert.are.same({ "UNIT_POWER_FREQUENT" }, RB.skippedEvents)
            assert.are.equal("player", f.unit.UNIT_MAXPOWER)
        end)
    end)
end)

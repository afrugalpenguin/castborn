require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
dofile("Core.lua")
dofile("Modules/ResourceBars.lua")
dofile("Modules/ResourceBars_Forever.lua")

describe("Resource bars on Forever", function()
    local RB = Castborn.ResourceBars
    local db

    -- A secret value: any maths, comparison or concatenation on it raises an error
    local function forbidden(op)
        return function() error("arithmetic or comparison on a secret value (" .. op .. ")") end
    end
    local secretMeta = {}
    for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm",
            "__lt", "__le", "__eq", "__concat" }) do
        secretMeta[op] = forbidden(op)
    end
    local function secret(label)
        return setmetatable({ label = label }, secretMeta)
    end

    -- A font string that records each call
    local function spyText()
        local fs = { formatted = {}, plain = {} }
        function fs:SetText(text) self.plain[#self.plain + 1] = text end
        function fs:SetFormattedText(...) self.formatted[#self.formatted + 1] = { ... } end
        return fs
    end

    local curve

    before_each(function()
        db = Castborn:MergeDefaults({}, RB.defaults)
        Castborn.db = Castborn.db or {}
        Castborn.db.resources = db
        RB.percentFailed = nil
        _G.issecretvalue = function() return true end
        curve = { name = "ScaleTo100" }
        _G.CurveConstants = { ScaleTo100 = curve }
        _G.UnitHealthPercent = function(unit, usePredicted, c)
            return secret("health% " .. unit .. " " .. tostring(usePredicted) .. " " .. tostring(c == curve))
        end
        _G.UnitPowerPercent = function(unit, powerType, unmodified, c)
            return secret("power% " .. unit .. " " .. tostring(powerType) .. " " .. tostring(unmodified) .. " " .. tostring(c == curve))
        end
        _G.UnitPowerType = function() return 0, "MANA" end
        _G.AbbreviateNumbers = nil
    end)

    after_each(function()
        _G.issecretvalue = nil
        _G.CurveConstants = nil
        _G.UnitHealthPercent = nil
        _G.UnitPowerPercent = nil
        _G.UnitPowerType = nil
        _G.AbbreviateNumbers = nil
        _G.UnitHealth = nil
        _G.UnitHealthMax = nil
        _G.UnitPower = nil
        _G.UnitPowerMax = nil
    end)

    describe("FormatText", function()
        local cur, max

        before_each(function()
            cur, max = secret("cur"), secret("max")
        end)

        it("passes the current value straight through for CURRENT", function()
            db.textFormat = "CURRENT"
            local fs = spyText()
            assert.has_no.errors(function() RB:FormatText(fs, cur, max, "player", "health") end)
            assert.are.equal("%s", fs.formatted[1][1])
            assert.are.equal(cur, fs.formatted[1][2])
        end)

        it("passes both values straight through for CURRENT_MAX", function()
            db.textFormat = "CURRENT_MAX"
            local fs = spyText()
            assert.has_no.errors(function() RB:FormatText(fs, cur, max, "player", "health") end)
            assert.are.same({ "%s / %s", cur, max }, fs.formatted[1])
        end)

        it("abbreviates through AbbreviateNumbers when the client has it", function()
            _G.AbbreviateNumbers = function(v) return { abbreviated = v } end
            db.textFormat = "CURRENT_MAX"
            local fs = spyText()
            RB:FormatText(fs, cur, max, "player", "health")
            assert.are.equal(cur, fs.formatted[1][2].abbreviated)
            assert.are.equal(max, fs.formatted[1][3].abbreviated)
        end)

        it("reads the health percentage scaled to 0-100 for PERCENT", function()
            db.textFormat = "PERCENT"
            local fs = spyText()
            assert.has_no.errors(function() RB:FormatText(fs, cur, max, "player", "health") end)
            assert.are.equal("%.0f%%", fs.formatted[1][1])
            assert.are.equal("health% player true true", fs.formatted[1][2].label)
        end)

        it("reads the power percentage for the current power type", function()
            _G.UnitPowerType = function() return 3, "ENERGY" end
            db.textFormat = "PERCENT"
            local fs = spyText()
            RB:FormatText(fs, cur, max, "player", "power")
            assert.are.equal("power% player 3 false true", fs.formatted[1][2].label)
        end)

        it("shows current and percentage for CURRENT_PERCENT", function()
            db.textFormat = "CURRENT_PERCENT"
            local fs = spyText()
            assert.has_no.errors(function() RB:FormatText(fs, cur, max, "player", "health") end)
            assert.are.equal("%s (%.0f%%)", fs.formatted[1][1])
            assert.are.equal(cur, fs.formatted[1][2])
        end)

        it("clears the text for NONE without touching the values", function()
            db.textFormat = "NONE"
            local fs = spyText()
            assert.has_no.errors(function() RB:FormatText(fs, cur, max, "player", "health") end)
            assert.are.same({ "" }, fs.plain)
        end)

        it("never hands a value to SetText", function()
            for _, format in ipairs({ "CURRENT", "CURRENT_MAX", "PERCENT", "CURRENT_PERCENT" }) do
                db.textFormat = format
                local fs = spyText()
                RB:FormatText(fs, cur, max, "player", "health")
                assert.are.equal(0, #fs.plain, format .. " used SetText")
                assert.are.equal(1, #fs.formatted, format .. " did not use SetFormattedText")
            end
        end)

        it("falls back to CURRENT_MAX when the percentage APIs are missing", function()
            _G.CurveConstants = nil
            assert.is_false(RB:SupportsPercent())
            db.textFormat = "PERCENT"
            local fs = spyText()
            RB:FormatText(fs, cur, max, "player", "health")
            assert.are.same({ "%s / %s", cur, max }, fs.formatted[1])
        end)

        it("falls back to CURRENT_MAX for good if formatting a percentage errors", function()
            db.textFormat = "PERCENT"
            local fs = spyText()
            function fs:SetFormattedText(format, ...)
                if format:find("%%%%") then error("secret not allowed") end
                self.formatted[#self.formatted + 1] = { format, ... }
            end
            assert.has_no.errors(function() RB:FormatText(fs, cur, max, "player", "health") end)
            assert.are.same({ "%s / %s", cur, max }, fs.formatted[1])
            assert.is_false(RB:SupportsPercent())
        end)
    end)

    describe("SetBarValues", function()
        it("passes secrets straight to the status bar without clamping", function()
            local bar = {}
            function bar:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
            function bar:SetValue(v) self.value = v end
            local cur, max = secret("cur"), secret("max")
            assert.has_no.errors(function() RB:SetBarValues(bar, cur, max) end)
            assert.are.equal(0, bar.min)
            assert.are.equal(max, bar.max)
            assert.are.equal(cur, bar.value)
        end)
    end)

    describe("ShouldHidePower", function()
        it("never inspects the value and leaves the bar shown", function()
            assert.has_no.errors(function() RB:ShouldHidePower(secret("max")) end)
            assert.is_false(RB:ShouldHidePower(secret("max")))
            assert.is_false(RB:ShouldHidePower(0))
        end)
    end)

    describe("updating from secret unit values", function()
        it("fills both bars and writes their text without errors", function()
            _G.UnitHealth = function() return secret("hp") end
            _G.UnitHealthMax = function() return secret("hpmax") end
            _G.UnitPower = function() return secret("pp") end
            _G.UnitPowerMax = function() return secret("ppmax") end
            RB:CreateFrames()
            for _, format in ipairs({ "NONE", "CURRENT", "CURRENT_MAX", "PERCENT", "CURRENT_PERCENT" }) do
                db.textFormat = format
                assert.has_no.errors(function()
                    RB:UpdateHealth()
                    RB:UpdatePower()
                end, format)
            end
        end)
    end)
end)

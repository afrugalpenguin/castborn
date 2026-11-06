require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/GCDIndicator.lua")

describe("GCD seams (TBC behaviour)", function()
    local CB = Castborn
    local cfg
    local originalGetTime, originalUnitClass

    local function fakeFrame()
        local f = { bar = {}, spark = {} }
        f.bar.SetWidth = function(_, w) f.barWidth = w end
        f.bar.SetVertexColor = function() end
        f.spark.SetPoint = function() end
        f.spark.Show = function() end
        f.spark.Hide = function() end
        f.pulse = { SetAlpha = function() end }
        f.GetWidth = function() return 102 end
        f.Show = function() f.shown = true end
        f.Hide = function() f.shown = false end
        return f
    end

    before_each(function()
        originalGetTime = _G.GetTime
        originalUnitClass = _G.UnitClass
        cfg = { enabled = true, barColor = { 1, 1, 1, 1 }, readyColor = { 0, 1, 0, 1 } }
        CB.db = { gcd = cfg }
        CB.gcdFrame = fakeFrame()
        _G.UnitClass = function() return "Paladin", "PALADIN" end
        _G.GetTime = function() return 100 end
    end)

    after_each(function()
        _G.GetSpellCooldown = nil
        _G.GetTime = originalGetTime
        _G.UnitClass = originalUnitClass
    end)

    it("lists a GCD test spell per class", function()
        assert.are.equal("Holy Light", CB.GCDIndicator.testSpells.PALADIN)
    end)

    it("starts the sweep from the spell cooldown and draws progress", function()
        _G.GetSpellCooldown = function() return 99.5, 1.5 end
        CB:CheckGCD()
        CB:UpdateGCDBar(CB.gcdFrame, cfg)
        assert.is_true(CB.gcdFrame.shown)
        assert.is_near(100 * (0.5 / 1.5), CB.gcdFrame.barWidth, 1e-9)
    end)

    it("ignores a cooldown that has already run out", function()
        -- The module keeps GCD state in file locals, so move time past any earlier sweep
        _G.GetTime = function() return 200 end
        _G.GetSpellCooldown = function() return 190, 1.5 end
        CB:CheckGCD()
        CB:UpdateGCDBar(CB.gcdFrame, cfg)
        assert.is_not_true(CB.gcdFrame.shown)
    end)
end)

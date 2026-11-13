require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/FiveSecondRule.lua")

-- Pins the TBC mana-spend detection behind the seam the Forever build overrides
describe("Five second rule on TBC", function()
    local FSR = Castborn.FiveSecondRule
    local realMark = FSR.MarkManaSpent
    local mana, registered, marked

    local function fakeFrame()
        return { RegisterEvent = function(_, event) registered[#registered + 1] = event end }
    end

    before_each(function()
        mana, registered, marked = 1000, {}, 0
        _G.UnitPower = function() return mana end
        FSR.MarkManaSpent = function() marked = marked + 1 end
        FSR:RegisterEvents(fakeFrame())
    end)

    after_each(function()
        _G.UnitPower = nil
        FSR.MarkManaSpent = realMark
    end)

    it("listens for mana changes", function()
        assert.are.same({ "UNIT_POWER_UPDATE", "UNIT_SPELLCAST_SUCCEEDED" }, registered)
    end)

    it("starts the timer when mana falls", function()
        mana = 900
        FSR:OnPlayerEvent("UNIT_POWER_UPDATE", "MANA")
        assert.are.equal(1, marked)
    end)

    it("ignores mana rising", function()
        mana = 1100
        FSR:OnPlayerEvent("UNIT_POWER_UPDATE", "MANA")
        assert.are.equal(0, marked)
    end)

    it("ignores a one-point drop", function()
        mana = 999
        FSR:OnPlayerEvent("UNIT_POWER_UPDATE", "MANA")
        assert.are.equal(0, marked)
    end)

    it("ignores other power types", function()
        mana = 900
        FSR:OnPlayerEvent("UNIT_POWER_UPDATE", "RAGE")
        assert.are.equal(0, marked)
    end)
end)

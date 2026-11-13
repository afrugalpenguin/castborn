require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Systems/ClassDefaults.lua")
dofile("Modules/FiveSecondRule.lua")

describe("Five-second rule anchor by class", function()
    local FSR = Castborn.FiveSecondRule
    local realDB, realInfo

    local function as(class)
        Castborn.playerInfo = { class = class }
    end

    before_each(function()
        realDB, realInfo = _G.CastbornDB, Castborn.playerInfo
        _G.CastbornDB = { fsr = { anchored = true } }
    end)

    after_each(function()
        _G.CastbornDB, Castborn.playerInfo = realDB, realInfo
    end)

    it("defaults a paladin to the swing timer", function()
        as("PALADIN")
        assert.is_true(FSR:AnchorsToSwing())
    end)

    it("defaults casters to the castbar", function()
        for _, class in ipairs({ "MAGE", "PRIEST", "WARLOCK", "DRUID", "SHAMAN", "HUNTER" }) do
            as(class)
            assert.is_false(FSR:AnchorsToSwing(), class)
        end
    end)

    it("does not save the default, so other classes keep theirs", function()
        as("PALADIN")
        FSR:AnchorsToSwing()
        assert.is_nil(CastbornDB.fsr.anchorToSwingByClass)
        as("MAGE")
        assert.is_false(FSR:AnchorsToSwing())
    end)

    it("keeps a paladin's choice to their class", function()
        as("PALADIN")
        FSR:SetAnchorsToSwing(false)
        assert.is_false(FSR:AnchorsToSwing())
        as("MAGE")
        FSR:SetAnchorsToSwing(true)
        as("PALADIN")
        assert.is_false(FSR:AnchorsToSwing())
        as("PRIEST")
        assert.is_false(FSR:AnchorsToSwing())
    end)

    it("copes with no saved five-second rule settings", function()
        as("PALADIN")
        CastbornDB.fsr = nil
        assert.is_true(FSR:AnchorsToSwing())
    end)
end)

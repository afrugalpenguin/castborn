require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Systems/ClassDefaults.lua")

describe("Class defaults: five-second rule anchor", function()
    local CD = Castborn.ClassDefaults
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

    it("puts a paladin's bar above the swing timer", function()
        as("PALADIN")
        CD:ApplyFSRAnchorDefault()
        assert.is_true(CastbornDB.fsr.anchorToSwing)
    end)

    it("keeps a caster's bar on the castbar", function()
        as("MAGE")
        CD:ApplyFSRAnchorDefault()
        assert.is_false(CastbornDB.fsr.anchorToSwing)
    end)

    it("keeps a choice the player already made", function()
        as("PALADIN")
        CastbornDB.fsr.anchorToSwing = false
        CD:ApplyFSRAnchorDefault()
        assert.is_false(CastbornDB.fsr.anchorToSwing)
    end)

    it("copes with no saved five-second rule settings", function()
        as("PALADIN")
        CastbornDB.fsr = nil
        CD:ApplyFSRAnchorDefault()
        assert.is_true(CastbornDB.fsr.anchorToSwing)
    end)
end)

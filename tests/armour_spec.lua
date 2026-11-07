require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/ArmorTracker.lua")

describe("Armour reminder seams (TBC behaviour)", function()
    local AT = Castborn.ArmorTracker

    after_each(function() _G.UnitBuff = nil end)

    it("can always read auras", function()
        assert.is_true(AT:CanReadAuras())
    end)

    it("finds a tracked buff by spell ID", function()
        local buffs = { { "Mark of the Wild", 1126 }, { "Ice Armor", 7302 } }
        _G.UnitBuff = function(_, i)
            local b = buffs[i]
            if b then return b[1], nil, nil, nil, nil, nil, nil, nil, nil, b[2] end
        end
        assert.are.equal(7302, AT:FindPlayerBuff({ [7302] = true }))
    end)

    it("returns nil when no tracked buff is up", function()
        _G.UnitBuff = function() return nil end
        assert.is_nil(AT:FindPlayerBuff({ [7302] = true }))
    end)
end)

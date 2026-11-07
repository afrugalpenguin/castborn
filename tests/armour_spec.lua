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

    describe("GetSelectedBlessing", function()
        after_each(function() Castborn.unavailableOptions = nil end)

        it("returns the saved blessing", function()
            assert.are.equal("sanctuary", AT:GetSelectedBlessing({ selectedBlessing = "sanctuary" }))
        end)

        it("defaults to Might", function()
            assert.are.equal("might", AT:GetSelectedBlessing({}))
        end)

        it("falls back to Might when the build lacks the saved blessing", function()
            Castborn.unavailableOptions = { ["armortracker.sanctuary"] = true }
            assert.are.equal("might", AT:GetSelectedBlessing({ selectedBlessing = "sanctuary" }))
        end)
    end)

    describe("HasTalent", function()
        after_each(function() _G.GetTalentInfo = nil end)

        it("is true when the talent has points", function()
            _G.GetTalentInfo = function(tab, index)
                if tab == 2 and index == 7 then return "Improved Righteous Fury", nil, 1, 2, 2, 3 end
            end
            assert.is_true(AT:HasTalent(2, 7))
        end)

        it("is false with no points spent", function()
            _G.GetTalentInfo = function() return "Improved Righteous Fury", nil, 1, 2, 0, 3 end
            assert.is_false(AT:HasTalent(2, 7))
        end)
    end)
end)

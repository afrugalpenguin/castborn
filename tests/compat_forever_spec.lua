require("tests.mocks.wow_api")

describe("Compat_Forever", function()
    before_each(function()
        _G.GetSpellInfo = nil
        _G.GetSpellSubtext = nil
        _G.C_Spell = {
            GetSpellInfo = function(id)
                if id == 133 then
                    return { name = "Fireball", iconID = 135812, castTime = 1500,
                             minRange = 0, maxRange = 35, spellID = 133, originalIconID = 135812 }
                end
            end,
            GetSpellSubtext = function(id)
                if id == 133 then return "Rank 1" end
            end,
        }
        dofile("Systems/Compat_Forever.lua")
    end)

    after_each(function()
        _G.C_Spell = nil
        _G.GetSpellInfo = nil
        _G.GetSpellSubtext = nil
    end)

    it("recreates GetSpellInfo with the TBC return order", function()
        local name, rank, icon, castTime, minRange, maxRange, spellID = GetSpellInfo(133)
        assert.are.equal("Fireball", name)
        assert.is_nil(rank)
        assert.are.equal(135812, icon)
        assert.are.equal(1500, castTime)
        assert.are.equal(0, minRange)
        assert.are.equal(35, maxRange)
        assert.are.equal(133, spellID)
    end)

    it("returns nothing for an unknown spell", function()
        assert.is_nil(GetSpellInfo(999999))
    end)

    it("recreates GetSpellSubtext", function()
        assert.are.equal("Rank 1", GetSpellSubtext(133))
    end)

    it("keeps an existing global", function()
        local original = function() return "original" end
        _G.GetSpellInfo = original
        dofile("Systems/Compat_Forever.lua")
        assert.are.equal(original, _G.GetSpellInfo)
    end)

    it("lists option pages for modules not in the Forever build", function()
        assert.is_true(Castborn.unavailableOptions.swing)
        assert.is_nil(Castborn.unavailableOptions.castbars)
    end)
end)

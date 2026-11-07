require("tests.mocks.wow_api")

describe("Compat_Forever", function()
    before_each(function()
        _G.GetSpellInfo = nil
        _G.GetSpellSubtext = nil
        _G.GetSpellTexture = nil
        _G.GetItemSpell = nil
        _G.GetItemInfo = nil
        _G.GetItemCount = nil
        _G.C_Item = {
            GetItemInfo = function(id)
                if id == 13444 then
                    return "Major Mana Potion", "link", 1, 59, 49, "Consumable", "Potion", 5, "", 134854
                end
            end,
            GetItemCount = function(id, includeBank, includeUses)
                if id == 13444 then return includeUses and 9 or 3 end
                return 0
            end,
            GetItemSpell = function(id)
                if id == 19950 then return "Zandalarian Hero Charm", 24658 end
            end,
        }
        _G.C_Spell = {
            GetSpellTexture = function(id)
                if id == 133 then return 135812 end
            end,
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
        _G.C_Item = nil
        _G.GetSpellTexture = nil
        _G.GetItemSpell = nil
        _G.GetItemInfo = nil
        _G.GetItemCount = nil
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

    it("recreates GetSpellTexture", function()
        assert.are.equal(135812, GetSpellTexture(133))
    end)

    it("recreates GetItemSpell", function()
        local name, id = GetItemSpell(19950)
        assert.are.equal("Zandalarian Hero Charm", name)
        assert.are.equal(24658, id)
    end)

    it("recreates GetItemInfo with the icon in tenth place", function()
        local name, _, _, _, _, _, _, _, _, texture = GetItemInfo(13444)
        assert.are.equal("Major Mana Potion", name)
        assert.are.equal(134854, texture)
    end)

    it("recreates GetItemCount with the TBC arguments", function()
        assert.are.equal(3, GetItemCount(13444))
        assert.are.equal(9, GetItemCount(13444, false, true))
    end)

    it("does not recreate GetSpellCooldown, whose times can be secret", function()
        assert.is_nil(_G.GetSpellCooldown)
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

    it("shows the item tracker page", function()
        assert.is_nil(Castborn.unavailableOptions.itemtracker)
    end)

    it("shows the armour reminder page", function()
        assert.is_nil(Castborn.unavailableOptions.armortracker)
    end)

    it("hides Blessing of Sanctuary, which Forever does not have", function()
        assert.is_true(Castborn.unavailableOptions["armortracker.sanctuary"])
    end)

    it("shows the interrupt page but hides its lockout option", function()
        assert.is_nil(Castborn.unavailableOptions.interrupt)
        assert.is_true(Castborn.unavailableOptions["interrupt.lockout"])
    end)
end)

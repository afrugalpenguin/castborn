--[[
    Castborn - Forever compatibility layer
    Recreates TBC globals missing from the Forever client, and lists the option
    pages for modules the Forever build does not load.
    Loaded only by Castborn_Camelot.toc, straight after Core.lua.
]]

-- GetSpellInfo with the TBC return order: name, rank, icon, castTime, minRange, maxRange, spellID
if not GetSpellInfo and C_Spell and C_Spell.GetSpellInfo then
    function GetSpellInfo(spell)
        local info = C_Spell.GetSpellInfo(spell)
        if not info then return nil end
        return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID
    end
end

if not GetSpellSubtext and C_Spell and C_Spell.GetSpellSubtext then
    GetSpellSubtext = C_Spell.GetSpellSubtext
end

if not GetSpellTexture and C_Spell and C_Spell.GetSpellTexture then
    GetSpellTexture = C_Spell.GetSpellTexture
end

if not GetItemSpell and C_Item and C_Item.GetItemSpell then
    GetItemSpell = C_Item.GetItemSpell
end

-- C_Item keeps the TBC return order and arguments
if not GetItemInfo and C_Item and C_Item.GetItemInfo then
    GetItemInfo = C_Item.GetItemInfo
end

if not GetItemCount and C_Item and C_Item.GetItemCount then
    GetItemCount = C_Item.GetItemCount
end

-- GetSpellCooldown is deliberately not recreated: in combat its times are secret, and the
-- TBC code compares them. The GCD and cooldown modules read C_Spell through their _Forever files.

-- Option pages (and module checkboxes) hidden on Forever, keyed by Options.lua category id.
-- Remove an entry when its module is ported and added to Castborn_Camelot.toc.
Castborn.unavailableOptions = {
    fsr = true,  -- mana is a secret value on Forever, so the bar cannot compare it
    swing = true,
    dots = true,
    multidot = true,
    buffs = true,
    ["interrupt.lockout"] = true,  -- the lockout needs the combat log, which Forever blocks
    totems = true,
    absorbs = true,
}

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

-- Option pages (and module checkboxes) hidden on Forever, keyed by Options.lua category id.
-- Remove an entry when its module is ported and added to Castborn_Camelot.toc.
Castborn.unavailableOptions = {
    gcd = true,
    fsr = true,  -- mana is a secret value on Forever, so the bar cannot compare it
    swing = true,
    dots = true,
    multidot = true,
    buffs = true,
    cooldowns = true,
    itemtracker = true,
    interrupt = true,
    totems = true,
    absorbs = true,
    armortracker = true,
}

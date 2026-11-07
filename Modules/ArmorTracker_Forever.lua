--[[
    Castborn - armour reminder on Forever
    UnitBuff is gone, and in combat every aura read is blocked (the UNIT_AURA payload is secret
    too), so buffs are only checked out of combat and the reminder holds its state in a fight.
    Loaded only by Castborn_Camelot.toc, after ArmorTracker.lua.
]]

local ArmorTracker = Castborn.ArmorTracker

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

-- GetTalentInfo is missing on Forever, so ask IsPlayerSpell about the talent's rank spell IDs.
-- Unverified in game: if IsPlayerSpell cannot see talents, the slot simply stays hidden.
function ArmorTracker:HasTalent(entry)
    if not IsPlayerSpell or not entry.talentSpellIds then return false end
    for _, id in ipairs(entry.talentSpellIds) do
        if IsPlayerSpell(id) then return true end
    end
    return false
end

function ArmorTracker:CanReadAuras()
    return not (InCombatLockdown() or UnitAffectingCombat("player"))
end

function ArmorTracker:FindPlayerBuff(spellIds)
    if not self:CanReadAuras() then return nil end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        local spellId = aura.spellId
        if not isSecret(spellId) and spellId and spellIds[spellId] then
            return spellId
        end
    end
    return nil
end

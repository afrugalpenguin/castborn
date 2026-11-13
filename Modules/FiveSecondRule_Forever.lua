--[[
    Castborn - five-second rule on Forever
    Mana is a secret value on Forever, even out of combat, so the TBC way of spotting a
    spend (mana falling between two UNIT_POWER_UPDATEs) would error. The player's
    UNIT_SPELLCAST_SUCCEEDED spell ID stays plain, and a spell's listed cost is not secret,
    so a successful cast that costs mana starts the timer instead. A free cast (Clearcasting)
    still starts it, because only the listed cost is known.
    Loaded only by Castborn_Camelot.toc, after FiveSecondRule.lua.
]]

local FiveSecondRule = Castborn.FiveSecondRule

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

local function positive(v)
    return not isSecret(v) and v ~= nil and v > 0
end

function FiveSecondRule:RegisterEvents(eventFrame)
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end

function FiveSecondRule:CostsMana(spellId)
    if not (C_Spell and C_Spell.GetSpellPowerCost) then return false end
    local costs = C_Spell.GetSpellPowerCost(spellId)
    if type(costs) ~= "table" then return false end
    local mana = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
    for _, c in ipairs(costs) do
        -- Secret first: comparing a secret value errors
        local readable = not (isSecret(c.type) or isSecret(c.requiredAuraID) or isSecret(c.hasRequiredAura))
        if readable and c.type == mana
            and (c.requiredAuraID == nil or c.requiredAuraID == 0 or c.hasRequiredAura == true)
            and (positive(c.cost) or positive(c.costPercent) or positive(c.costPerSec)) then
            return true
        end
    end
    return false
end

function FiveSecondRule:OnPlayerEvent(event, castGUID, spellId)
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end
    if isSecret(spellId) or spellId == nil then return end
    if self:CostsMana(spellId) then self:MarkManaSpent() end
end

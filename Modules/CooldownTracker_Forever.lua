--[[
    Castborn - cooldown tracker on Forever
    GetSpellCooldown is gone. C_Spell.GetSpellCooldown keeps isActive/isOnGCD readable in
    combat while the times are secret, so secret cooldowns are drawn from duration objects.
    Loaded only by Castborn_Camelot.toc, after CooldownTracker.lua.
]]

local CooldownTracker = Castborn.CooldownTracker

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

function CooldownTracker:GetSpellCooldownState(spellName)
    local info = C_Spell.GetSpellCooldown(spellName)
    if not info then return false end
    local duration = info.duration
    if isSecret(duration) then
        if isSecret(info.isActive) or isSecret(info.isOnGCD) then return false end
        -- Secret times: trust the flags, and count any real cooldown as glow-worthy
        if info.isActive and not info.isOnGCD then
            return true, true, info.startTime, duration
        end
        return false
    end
    if duration and duration > 1.5 then
        return true, duration > 3, info.startTime, duration
    end
    return false
end

-- Several TBC spell IDs are different spells on Forever (12472 is Cold Snap, 11958 Ice Block,
-- 12292/12328 swap Sweeping Strikes and Death Wish), so name each entry after what its ID is
-- on this client. Unknown IDs (custom entries) keep their stored name.
function CooldownTracker:GetTrackedSpellName(spell)
    return GetSpellInfo(spell.spellId) or spell.name
end

function CooldownTracker:SetIconCooldown(cooldown, spellName, start, duration)
    if isSecret(start) or isSecret(duration) then
        local durationObject = C_Spell.GetSpellCooldownDuration(spellName)
        if durationObject then
            cooldown:SetCooldownFromDurationObject(durationObject)
        end
        return
    end
    cooldown:SetCooldown(start, duration)
end

-- The creature type is secret in combat, so treat a secret answer as unreadable rather than
-- compare it
function CooldownTracker:GetTargetCreatureType()
    local exists = UnitExists("target")
    if isSecret(exists) then return nil end
    if not exists then return false end
    local creatureType = UnitCreatureType("target")
    if isSecret(creatureType) then return nil end
    return creatureType
end

-- When the creature type is secret (in combat), ask the range check instead. It stays plain
-- in combat and answers nil when the spell cannot be cast on the target at all (a humanoid
-- for Exorcism), and true or false, in or out of range, when it can.
local baseGetTargetFit = CooldownTracker.GetTargetFit

function CooldownTracker:GetTargetFit(spell)
    local fit = baseGetTargetFit(self, spell)
    if fit ~= nil then return fit end
    local limited = Castborn.SpellData and Castborn.SpellData.targetCreatureTypes[spell.spellId]
    if not limited then return nil end
    local inRange = C_Spell.IsSpellInRange(self:GetTrackedSpellName(spell), "target")
    if isSecret(inRange) then return nil end
    return inRange ~= nil
end

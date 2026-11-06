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

--[[
    Castborn - seal tracker on Forever
    Aura reads are blocked in combat and the UNIT_AURA payload is secret, but the player's
    UNIT_SPELLCAST_SUCCEEDED spell ID stays plain. So out of combat the seal buff is read as
    on TBC, and in combat the tracker follows casts: a seal starts its timer, Judgement
    consumes it. Leaving combat re-reads the buff to correct any drift.
    Loaded only by Castborn_Camelot.toc, after SealTracker.lua.
]]

local SealTracker = Castborn.SealTracker

local DEFAULT_DURATION = 30

-- Real durations seen out of combat, keyed by seal name
SealTracker.knownDurations = SealTracker.knownDurations or {}

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

function SealTracker:CanReadAuras()
    return not (InCombatLockdown() or UnitAffectingCombat("player"))
end

function SealTracker:FindActiveSeal()
    if not self:CanReadAuras() then return nil end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        local name = aura.name
        if not isSecret(name) and self:IsSeal(name) then
            local duration, expirationTime = aura.duration, aura.expirationTime
            if isSecret(duration) or isSecret(expirationTime) then
                duration, expirationTime = nil, nil
            elseif duration and duration > 0 then
                self.knownDurations[name] = duration
            end
            local spellId = aura.spellId
            if isSecret(spellId) then spellId = nil end
            return spellId, expirationTime, duration
        end
    end
    return nil
end

function SealTracker:OnPlayerCast(spellId)
    if self:CanReadAuras() then return end  -- the buff read is exact out of combat
    -- Secret first: comparing a secret value errors
    if isSecret(spellId) or spellId == nil or self:IsIgnoredSpell(spellId) then return end
    local name = GetSpellInfo(spellId)
    if self:IsSeal(name) then
        local duration = self.knownDurations[name] or DEFAULT_DURATION
        self:SetState(spellId, GetTime() + duration, duration)
    elseif self:IsJudgement(name) then
        self:SetState(nil)
    end
end

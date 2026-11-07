--[[
    Castborn - interrupt tracker on Forever
    Cooldown only. The lockout needs the combat log, and registering it on Forever blocks
    UI actions. In combat the cooldown's times are secret but isActive/isOnGCD are not, so
    secret cooldowns are drawn from duration objects.
    Loaded only by Castborn_Camelot.toc, after InterruptTracker.lua.
]]

local InterruptTracker = Castborn.InterruptTracker

-- Feral Charge is a Feral talent with a new ID on Forever; the TBC ID 16979 does not exist
local interrupts = Castborn.SpellData and Castborn.SpellData.interrupts
if interrupts and interrupts.DRUID then
    interrupts.DRUID.spellId = 1238122
end

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

function InterruptTracker:RegisterLockoutEvents()
end

function InterruptTracker:GetCooldownState(spellId)
    local info = C_Spell.GetSpellCooldown(spellId)
    if not info then return false end
    local duration = info.duration
    if isSecret(duration) then
        if isSecret(info.isActive) or isSecret(info.isOnGCD) then return false end
        if info.isActive and not info.isOnGCD then
            return true, info.startTime, duration
        end
        return false
    end
    if duration and duration > 1.5 then
        return true, info.startTime, duration
    end
    return false
end

function InterruptTracker:SetIconCooldown(cooldown, spellId, start, duration)
    if isSecret(start) or isSecret(duration) then
        local durationObject = C_Spell.GetSpellCooldownDuration(spellId)
        if durationObject then
            cooldown:SetCooldownFromDurationObject(durationObject)
        end
        return
    end
    cooldown:SetCooldown(start, duration)
end

-- Whether a secret cast can be interrupted is unknown, so any cast counts as an opportunity;
-- the castbar's shield still shows the truth.
local function CastIsOpportunity(name, notInterruptible)
    if isSecret(name) or isSecret(notInterruptible) then return true end
    return name ~= nil and not notInterruptible
end

function InterruptTracker:IsUnitCastingInterruptible(unit)
    if not UnitExists(unit) then return false end
    local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    if CastIsOpportunity(name, notInterruptible) then return true end
    name, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
    return CastIsOpportunity(name, notInterruptible)
end

-- Timer bar laid over the normal bar, so the plain path never fights a running timer
local function EnsureTimerBar(frame)
    if frame.timerBar then return frame.timerBar end
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetAllPoints(frame.bar)
    bar:SetStatusBarTexture(Castborn:GetBarTexture())
    bar:SetStatusBarColor(0.8, 0.3, 0.3, 1)
    Castborn:RegisterBarFrame(bar)
    bar:Hide()
    frame.timerBar = bar
    return bar
end

local function StopTimer(frame)
    frame.timerDuration = nil
    if frame.timerBar then frame.timerBar:Hide() end
end

local baseShowCooldownProgress = InterruptTracker.ShowCooldownProgress
function InterruptTracker:ShowCooldownProgress(frame, start, duration)
    if not (isSecret(start) or isSecret(duration)) then
        StopTimer(frame)
        return baseShowCooldownProgress(self, frame, start, duration)
    end
    if not frame.timerDuration then
        local durationObject = C_Spell.GetSpellCooldownDuration(frame.interruptInfo.spellId)
        if durationObject and frame.bar and frame.bar.SetTimerDuration then
            local dirs = Enum and Enum.StatusBarTimerDirection
            local interp = Enum and Enum.StatusBarInterpolation
            local timerBar = EnsureTimerBar(frame)
            timerBar:SetTimerDuration(durationObject, interp and interp.Immediate, dirs and dirs.RemainingTime)
            timerBar:Show()
        end
        frame.timerDuration = durationObject
    end
    if frame.bar then
        frame.bar:SetMinMaxValues(0, 1)
        frame.bar:SetValue(0)
    end
    local remaining = frame.timerDuration and frame.timerDuration.GetRemainingDuration
        and frame.timerDuration:GetRemainingDuration()
    -- Secret first: comparing a secret value errors
    if (isSecret(remaining) or remaining ~= nil) and frame.time.SetFormattedText then
        frame.time:SetFormattedText("%.1f", remaining)
        frame.time:Show()
    else
        frame.time:Hide()
    end
    frame.ready:Hide()
    frame.icon:SetDesaturated(true)
end

local baseShowReadyState = InterruptTracker.ShowReadyState
function InterruptTracker:ShowReadyState(frame, hasInterruptOpportunity)
    StopTimer(frame)
    return baseShowReadyState(self, frame, hasInterruptOpportunity)
end

-- Test mode paints the ready state straight onto the bar, so clear any running timer first
local baseTestInterrupt = Castborn.TestInterrupt
function Castborn:TestInterrupt()
    local f = _G["Castborn_Interrupt"]
    if f then StopTimer(f) end
    return baseTestInterrupt(self)
end

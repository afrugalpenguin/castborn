--[[
    Castborn - Forever castbar overrides
    Loaded only by Castborn_Camelot.toc, after Modules/CastBars.lua.
]]
local CB = Castborn

-- Target and focus castbars already hooked, so repeat calls don't stack hooks
local hookedSpellBars = {}

-- Unregistering events on Blizzard's castbar taints it on the Mainline UI, so detach it from
-- the player instead. The Blizzard bar then has no unit to show and stays hidden.
-- The target and focus bars can't be detached: their target-change handler reads
-- UnitCastingInfo(self.unit). Their showTargetCastbar CVar can't turn them off either, as
-- Blizzard reads it with GetCVar and "0" is truthy. Hide them whenever Blizzard shows them.
function CB:HideBlizzardCastBar(silent)
    local frame = PlayerCastingBarFrame
    if frame and frame.SetUnit then
        frame:SetUnit(nil)
    end
    for _, name in ipairs({ "TargetFrameSpellBar", "FocusFrameSpellBar" }) do
        local bar = _G[name]
        if bar and not hookedSpellBars[bar] then
            hookedSpellBars[bar] = true
            bar:HookScript("OnShow", bar.Hide)
            bar:Hide()
        end
    end
    if not silent then
        CB:Print("Default Blizzard castbars hidden")
    end
end

-- Restoring needs Blizzard's own setup to run again
function CB:ShowBlizzardCastBar()
    CB:Print("Reload UI to fully restore Blizzard castbar (/reload)")
end

-- Cast data can arrive as secret values on Forever (other units' casts, restricted maps).
-- Each override falls back to the shared TBC method when its inputs are plain.

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

-- Interpolation and direction for StatusBar:SetTimerDuration: casts count up, channels down
local function TimerArgs(isChannel)
    local dirs = Enum and Enum.StatusBarTimerDirection
    local interp = Enum and Enum.StatusBarInterpolation
    return interp and interp.Immediate, dirs and (isChannel and dirs.RemainingTime or dirs.ElapsedTime)
end

local baseSetCastTiming = CB.SetCastTiming
function CB:SetCastTiming(frame, unit, isChannel, startMS, endMS)
    frame.secretTiming = nil
    frame.timerDuration = nil
    if not (isSecret(startMS) or isSecret(endMS)) then
        return baseSetCastTiming(self, frame, unit, isChannel, startMS, endMS)
    end
    frame.secretTiming = true
    local getDuration = isChannel and UnitChannelDuration or UnitCastingDuration
    local duration = getDuration and getDuration(unit)
    if duration and frame.bar.SetTimerDuration then
        frame.timerDuration = duration
        frame.bar:SetTimerDuration(duration, TimerArgs(isChannel))
    end
end

local baseStartCastBar = CB.StartCastBar
function CB:StartCastBar(frame, isChannel)
    if frame.secretTiming then return end  -- the timer already drives the bar
    return baseStartCastBar(self, frame, isChannel)
end

local baseUpdateCastProgress = CB.UpdateCastProgress
function CB:UpdateCastProgress(frame, currentTime, cfg)
    if not frame.secretTiming then
        return baseUpdateCastProgress(self, frame, currentTime, cfg)
    end
    -- No arithmetic on secret times: no spark, and the STOP events end the cast
    frame.spark:Hide()
    local dur = frame.timerDuration
    if frame.timeText then
        if cfg.showTime and dur and dur.GetRemainingDuration then
            frame.timeText:SetText(string.format("%.1f", dur:GetRemainingDuration()))
            frame.timeText:Show()
        else
            frame.timeText:Hide()
        end
    end
    return false
end

local baseGetLatencyWidth = CB.GetLatencyWidth
function CB:GetLatencyWidth(frame)
    if frame.secretTiming then return nil end
    return baseGetLatencyWidth(self, frame)
end

local baseApplyInterruptShield = CB.ApplyInterruptShield
function CB:ApplyInterruptShield(frame, notInterruptible, barColor)
    if not frame.shield then return end
    frame.shield:SetAlpha(1)
    if not isSecret(notInterruptible) then
        return baseApplyInterruptShield(self, frame, notInterruptible, barColor)
    end
    if frame.shield.SetAlphaFromBoolean then
        frame.shield:Show()
        frame.shield:SetAlphaFromBoolean(notInterruptible)
    else
        frame.shield:Hide()
    end
end

local baseIsHiddenTradeSkill = CB.IsHiddenTradeSkill
function CB:IsHiddenTradeSkill(isTradeSkill, cfg)
    if isSecret(isTradeSkill) then return false end
    return baseIsHiddenTradeSkill(self, isTradeSkill, cfg)
end

-- UnitIsUnit can be secret for units outside the player's control (a party member's target).
-- Treat that as a different unit, so the bar shows rather than erroring.
local baseIsSameUnit = CB.IsSameUnit
function CB:IsSameUnit(a, b)
    local same = baseIsSameUnit(self, a, b)
    if isSecret(same) then return false end
    return same
end

local baseGetCastDisplayName = CB.GetCastDisplayName
function CB:GetCastDisplayName(name, text, spellID, cfg)
    if isSecret(spellID) or isSecret(name) or isSecret(text) then
        return text or name
    end
    return baseGetCastDisplayName(self, name, text, spellID, cfg)
end

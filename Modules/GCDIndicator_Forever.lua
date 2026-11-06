--[[
    Castborn - GCD indicator on Forever
    In combat the GCD's start and length are secret, but isOnGCD is not. The sweep is a
    StatusBar timer fed a duration object, and a hidden Cooldown signals the end.
    Loaded only by Castborn_Camelot.toc, after GCDIndicator.lua.
]]

local CB = Castborn

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

local function TestSpell()
    local _, class = UnitClass("player")
    return CB.GCDIndicator.testSpells[class]
end

local function EndGCD(frame)
    if not frame.foreverGCD then return end
    frame.foreverGCD = false
    if frame.timerBar then frame.timerBar:Hide() end
    frame.pulseAlpha = 1
    frame.pulse:SetAlpha(0.5)
    if not CB.db.gcd.alwaysShow then frame:Hide() end
end

-- Timer bar over the frame, plus a hidden Cooldown whose OnCooldownDone ends the sweep
local function EnsureTimerParts(frame)
    if frame.timerBar then return end
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(frame.bar:GetTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
    bar:Hide()
    frame.timerBar = bar

    local watcher = CreateFrame("Cooldown", nil, frame)
    watcher:SetSize(1, 1)
    watcher:SetPoint("CENTER")
    watcher:SetDrawSwipe(false)
    watcher:SetDrawEdge(false)
    watcher:SetDrawBling(false)
    watcher:SetScript("OnCooldownDone", function() EndGCD(frame) end)
    frame.doneWatcher = watcher
end

function CB:CheckGCD()
    local frame = CB.gcdFrame
    local spell = TestSpell()
    if not frame or not spell then return end
    local info = C_Spell.GetSpellCooldown(spell)
    if not info or isSecret(info.isOnGCD) then return end
    if not info.isOnGCD then
        EndGCD(frame)
        return
    end
    local duration = C_Spell.GetSpellCooldownDuration(spell)
    if not duration then return end
    EnsureTimerParts(frame)
    local cfg = CB.db.gcd
    local dirs = Enum and Enum.StatusBarTimerDirection
    local interp = Enum and Enum.StatusBarInterpolation
    frame.bar:SetWidth(0)
    frame.spark:Hide()
    frame.timerBar:SetStatusBarColor(cfg.barColor[1], cfg.barColor[2], cfg.barColor[3], cfg.barColor[4])
    frame.timerBar:SetTimerDuration(duration, interp and interp.Immediate, dirs and dirs.ElapsedTime)
    frame.timerBar:Show()
    frame.doneWatcher:SetCooldownFromDurationObject(duration)
    frame.foreverGCD = true
end

local baseUpdateGCDBar = CB.UpdateGCDBar
function CB:UpdateGCDBar(frame, cfg)
    if frame.foreverGCD then
        frame:Show()
        return
    end
    return baseUpdateGCDBar(self, frame, cfg)
end

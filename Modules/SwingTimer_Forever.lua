--[[
    Castborn - Swing timer on Forever
    Forever blocks the combat log, so swings come from the client's PLAYER_SWING event,
    which carries each swing's length. Range comes from C_SwingTimer.
    Loaded only by Castborn_Camelot.toc, after SwingTimer.lua.
]]

local CB = Castborn
local SwingTimer = CB.SwingTimer

local ORDER = { "mainhand", "offhand", "ranged" }
local OUT_OF_RANGE_ALPHA = 0.4
local FLASH_ALPHA = 0.6
local FLASH_TIME = 0.25
local FADE_TIME = 0.3

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

-- Enum.PlayerSwingType value for each bar
local function SwingEnums()
    local e = Enum and Enum.PlayerSwingType
    if e then return { mainhand = e.MainHand, offhand = e.OffHand, ranged = e.Ranged } end
    return { mainhand = 0, offhand = 1, ranged = 2 }
end

function SwingTimer:KeyFor(swingType)
    if swingType == nil or isSecret(swingType) then return nil end
    for key, value in pairs(SwingEnums()) do
        if value == swingType then return key end
    end
end

-- Running swings by bar key: { start, duration }, or { start, untimed = true } when the
-- game hid the swing's length
SwingTimer.swings = {}
SwingTimer.outOfRange = {}

function SwingTimer:OnSwing(duration, swingType)
    local key = self:KeyFor(swingType)
    if not key then return end
    if isSecret(duration) then
        self.swings[key] = { start = GetTime(), untimed = true }
    elseif type(duration) == "number" and duration > 0 then
        self.swings[key] = { start = GetTime(), duration = duration }
    else
        return
    end
    self:OnSwingStarted(key)
end

-- Seconds left on a timed swing, or nil when there is none
function SwingTimer:Remaining(key)
    local s = self.swings[key]
    if not s or not s.duration then return nil end
    return s.start + s.duration - GetTime()
end

-- Haste changed mid-swing: keep the fraction done and stretch the rest to the new speed
function SwingTimer:OnAttackSpeedChanged()
    local speeds = { UnitAttackSpeed("player") }
    local now = GetTime()
    for i, key in ipairs(ORDER) do
        local s, speed = self.swings[key], speeds[i]
        if s and s.duration and not isSecret(speed) and type(speed) == "number" and speed > 0 then
            local done = (now - s.start) / s.duration
            if done < 1 then
                s.duration = speed
                s.start = now - done * speed
            end
        end
    end
end

-- A weapon swap restarts the running swing at the new weapon's speed, as Blizzard's bar does
function SwingTimer:OnWeaponChanged()
    local speeds = { UnitAttackSpeed("player") }
    for i, key in ipairs(ORDER) do
        if self.swings[key] then
            local speed = speeds[i]
            if not isSecret(speed) and type(speed) == "number" and speed > 0 then
                self.swings[key] = { start = GetTime(), duration = speed }
            else
                self.swings[key] = nil
            end
        end
    end
end

-- An untimed swing has no end of its own, so it ends with combat
function SwingTimer:OnCombatEnded()
    for _, key in ipairs(ORDER) do
        local s = self.swings[key]
        if s and s.untimed then self.swings[key] = nil end
    end
end

function SwingTimer:SetOutOfRange(key, outOfRange)
    if isSecret(outOfRange) then return end
    outOfRange = outOfRange and true or nil
    if self.outOfRange[key] == outOfRange then return end
    self.outOfRange[key] = outOfRange
    self:ApplyRange(key)
end

-- C_SwingTimer returns nil when it cannot check, which must not count as out of range
function SwingTimer:RefreshRange()
    if not (C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange) then return end
    local enums = SwingEnums()
    for _, key in ipairs(ORDER) do
        local inRange = C_SwingTimer.IsTargetWithinSwingRange(enums[key])
        if not isSecret(inRange) then
            self:SetOutOfRange(key, inRange == false)
        end
    end
end

-- Display -------------------------------------------------------------------

local function BarColor(key)
    local cfg = CB.db.swing
    if key == "mainhand" then return cfg.mainColor end
    if key == "offhand" then return cfg.offColor end
    return cfg.rangedColor
end

-- Adds the spark glow, landing flash and end fade to a bar from CreateSwingBar
local function Decorate(frame, key)
    local bar = frame.bar
    local color = BarColor(key)

    local glow = bar:CreateTexture(nil, "OVERLAY", nil, -1)
    glow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(color[1], color[2], color[3], 0.7)
    glow:SetSize(36, CB.db.swing.barHeight * 3)
    glow:SetPoint("CENTER", frame.spark, "CENTER")
    glow:Hide()
    frame.sparkGlow = glow

    local flash = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    flash:SetAllPoints()
    flash:SetTexture("Interface\\Buttons\\WHITE8X8")
    flash:SetBlendMode("ADD")
    flash:SetAlpha(0)
    local flashAnim = flash:CreateAnimationGroup()
    local flashFade = flashAnim:CreateAnimation("Alpha")
    flashFade:SetFromAlpha(FLASH_ALPHA)
    flashFade:SetToAlpha(0)
    flashFade:SetDuration(FLASH_TIME)
    flashFade:SetSmoothing("OUT")
    frame.flashAnim = flashAnim

    local fadeOut = frame:CreateAnimationGroup()
    local fade = fadeOut:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(FADE_TIME)
    fade:SetSmoothing("IN")
    fadeOut:SetScript("OnFinished", function()
        frame:Hide()
        frame:SetAlpha(1)
    end)
    frame.fadeOut = fadeOut
end

local function SetSpark(frame, progress)
    frame.spark:SetPoint("CENTER", frame.bar, "LEFT", progress * frame.bar:GetWidth(), 0)
    frame.spark:Show()
    frame.sparkGlow:Show()
end

local function HideSpark(frame)
    frame.spark:Hide()
    frame.sparkGlow:Hide()
end

function SwingTimer:OnSwingStarted(key)
    local frame = CB.swingTimers[key]
    if not frame or not frame.flashAnim or self.testing or not CB.db.swing.enabled then return end
    frame.fadeOut:Stop()
    frame:SetAlpha(1)
    frame.bar:SetValue(0)
    frame.flashAnim:Stop()
    frame.flashAnim:Play()
    frame:Show()
    CB.swingTimers.container:Show()
end

function SwingTimer:ApplyRange(key)
    local frame = CB.swingTimers[key]
    if not frame or not frame.bar then return end
    local out = self.outOfRange[key]
    frame.bar:SetAlpha(out and OUT_OF_RANGE_ALPHA or 1)
    local r, g, b = 1, 1, 1
    if out then r, g, b = 1, 0.2, 0.2 end
    frame.label:SetTextColor(r, g, b)
    frame.timeText:SetTextColor(r, g, b)
end

local function EndSwing(frame, key)
    SwingTimer.swings[key] = nil
    frame.bar:SetValue(1)
    HideSpark(frame)
    frame.timeText:SetText("")
end

local function UpdateBar(frame, key)
    if not CB.db.swing.enabled then
        frame.fadeOut:Stop()
        frame:Hide()
        return
    end
    local s = SwingTimer.swings[key]
    if not s then
        -- Swing ended or was cleared: fade the bar out once
        if frame:IsShown() and not frame.fadeOut:IsPlaying() then frame.fadeOut:Play() end
        return
    end
    if s.untimed then
        -- The game hid this swing's length, so show a full bar without a countdown
        frame.bar:SetValue(1)
        HideSpark(frame)
        frame.timeText:SetText("")
        return
    end
    local remaining = SwingTimer:Remaining(key)
    if remaining <= 0 then
        EndSwing(frame, key)
        return
    end
    local progress = math.max(0, math.min(1, 1 - remaining / s.duration))
    frame.bar:SetValue(progress)
    SetSpark(frame, progress)
    frame.timeText:SetFormattedText("%.1f", remaining)
end

function CB:InitSwingTimers()
    local cfg = CB.db.swing
    local container = SwingTimer.CreateSwingContainer()
    CB.swingTimers.container = container

    local previous
    for _, key in ipairs(ORDER) do
        local frame = SwingTimer.CreateSwingBar(key, "swing")
        frame:SetParent(container)
        frame:ClearAllPoints()
        if previous then
            frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -cfg.spacing)
        else
            frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        end
        Decorate(frame, key)
        CB.swingTimers[key] = frame
        previous = frame
    end

    if C_SwingTimer and C_SwingTimer.EnableRangeCheck then
        local enums = SwingEnums()
        for _, key in ipairs(ORDER) do
            C_SwingTimer.EnableRangeCheck(enums[key], true)
        end
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_SWING")
    eventFrame:RegisterEvent("PLAYER_SWING_RANGE_UPDATE")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("WEAPON_SLOT_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterUnitEvent("UNIT_ATTACK_SPEED", "player")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_SWING" then
            SwingTimer:OnSwing(...)
        elseif event == "PLAYER_SWING_RANGE_UPDATE" then
            local swingType, isInRange, checksRange = ...
            local key = SwingTimer:KeyFor(swingType)
            if key and not isSecret(checksRange) and not isSecret(isInRange) then
                SwingTimer:SetOutOfRange(key, checksRange and not isInRange)
            end
        elseif event == "PLAYER_TARGET_CHANGED" then
            SwingTimer:RefreshRange()
        elseif event == "WEAPON_SLOT_CHANGED" then
            SwingTimer:OnWeaponChanged()
        elseif event == "UNIT_ATTACK_SPEED" then
            SwingTimer:OnAttackSpeedChanged()
        elseif event == "PLAYER_REGEN_ENABLED" then
            SwingTimer:OnCombatEnded()
        end
    end)

    CB:CreateThrottledUpdater(0.02, function()
        if SwingTimer.testing then return end
        local anyShown = false
        for _, key in ipairs(ORDER) do
            local frame = CB.swingTimers[key]
            UpdateBar(frame, key)
            anyShown = anyShown or frame:IsShown()
        end
        container:SetShown(anyShown)
    end)
end

-- Test mode shows static bars from SwingTimer.lua; live swings must not draw over them
local baseTest, baseEndTest = CB.TestSwingTimers, CB.EndTestSwingTimers

function CB:TestSwingTimers()
    SwingTimer.testing = true
    for _, key in ipairs(ORDER) do
        local frame = CB.swingTimers[key]
        if frame and frame.fadeOut then
            frame.fadeOut:Stop()
            frame:SetAlpha(1)
        end
    end
    baseTest(self)
    for _, key in ipairs(ORDER) do
        local frame = CB.swingTimers[key]
        if frame and frame.sparkGlow then frame.sparkGlow:Show() end
    end
end

function CB:EndTestSwingTimers()
    SwingTimer.testing = false
    wipe(SwingTimer.swings)
    baseEndTest(self)
end

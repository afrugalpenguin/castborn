--[[
    Castborn - Absorb Tracker Module
    Tracks absorb shield remaining amount (Ice Barrier MVP)
]]

local AbsorbTracker = {}
Castborn.AbsorbTracker = AbsorbTracker

local CB = Castborn

-- State
local absorbFrame = nil
local absorbState = {
    active = false,
    spellId = nil,
    spellName = nil,
    maxAbsorb = 0,
    remaining = 0,
    startTime = 0,
    duration = 0,
}
local testModeActive = false
local playerGUID = nil

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function FadeIn(frame, duration)
    if frame:IsShown() and frame:GetAlpha() >= 1 then
        return
    end
    frame:SetAlpha(0)
    frame:Show()
    local elapsed = 0
    local fadeDuration = duration or 0.3
    frame.fadeFrame = frame.fadeFrame or CreateFrame("Frame")
    frame.fadeFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local progress = math.min(1, elapsed / fadeDuration)
        frame:SetAlpha(progress)
        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function FadeOut(frame, duration)
    local startAlpha = frame:GetAlpha()
    local elapsed = 0
    local fadeDuration = duration or 0.3
    frame.fadeFrame = frame.fadeFrame or CreateFrame("Frame")
    frame.fadeFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local progress = math.min(1, elapsed / fadeDuration)
        frame:SetAlpha(startAlpha * (1 - progress))
        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
            frame:Hide()
            frame:SetAlpha(1)
        end
    end)
end

local function FormatNumber(num)
    if num >= 1000 then
        return string.format("%d,%03d", math.floor(num / 1000), num % 1000)
    end
    return tostring(num)
end

--------------------------------------------------------------------------------
-- Frame Creation
--------------------------------------------------------------------------------

local function CreateAbsorbBar()
    local cfg = CB.db.absorbs

    local frame = CreateFrame("Frame", "Castborn_AbsorbTracker", UIParent)
    frame:SetSize(cfg.width, cfg.barHeight)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)

    CB:CreateBackdrop(frame, cfg.bgColor, cfg.borderColor)

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetStatusBarColor(cfg.barColor[1], cfg.barColor[2], cfg.barColor[3], cfg.barColor[4])
    frame.bar = bar

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    barBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(16, cfg.barHeight * 2)
    spark:Hide()
    frame.spark = spark

    -- Left text: spell name
    local label = bar:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\ARIALN.TTF", math.max(8, cfg.barHeight - 6), "OUTLINE")
    label:SetPoint("LEFT", bar, "LEFT", 4, 0)
    label:SetText("")
    frame.label = label

    -- Right text: absorb remaining + timer
    local valueText = bar:CreateFontString(nil, "OVERLAY")
    valueText:SetFont("Fonts\\ARIALN.TTF", math.max(8, cfg.barHeight - 6), "OUTLINE")
    valueText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    frame.valueText = valueText

    -- Make draggable via Anchoring system
    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, CB.db.absorbs, nil, "Absorb Tracker")
    else
        CB:MakeMoveable(frame, "absorbs")
    end
    CB:ApplyPosition(frame, "absorbs")

    frame:Hide()
    return frame
end

--------------------------------------------------------------------------------
-- Tooltip Scanning
--------------------------------------------------------------------------------

local scanTooltip = CreateFrame("GameTooltip", "CastbornAbsorbScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function ScanAbsorbTooltip(spellId)
    scanTooltip:ClearLines()
    scanTooltip:SetSpellByID(spellId)
    for i = 1, scanTooltip:NumLines() do
        local text = _G["CastbornAbsorbScanTooltipTextLeft" .. i]:GetText()
        if text then
            -- Match patterns like "Absorbs 2847 damage" or "absorbs up to 2847 damage"
            local amount = text:match("(%d[%d,]+)%s+damage")
            if amount then
                amount = amount:gsub(",", "")
                return tonumber(amount)
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Show / Hide / Update
--------------------------------------------------------------------------------

local function ShowAbsorb(spellId, spellName, absorbAmount, duration)
    absorbState.active = true
    absorbState.spellId = spellId
    absorbState.spellName = spellName
    absorbState.maxAbsorb = absorbAmount
    absorbState.remaining = absorbAmount
    absorbState.startTime = GetTime()
    absorbState.duration = duration

    if absorbFrame then
        absorbFrame.label:SetText(spellName)
        FadeIn(absorbFrame, 0.3)
    end
end

local function HideAbsorb()
    absorbState.active = false
    if absorbFrame and absorbFrame:IsShown() then
        FadeOut(absorbFrame, 0.3)
    end
end

local function UpdateAbsorbBar()
    if not absorbFrame or not absorbState.active then return end
    if not CB.db.absorbs.enabled then absorbFrame:Hide() return end

    local remaining = absorbState.remaining
    local max = absorbState.maxAbsorb

    if max > 0 then
        absorbFrame.bar:SetValue(remaining / max)
        local sparkPos = (remaining / max) * absorbFrame.bar:GetWidth()
        absorbFrame.spark:SetPoint("CENTER", absorbFrame.bar, "LEFT", sparkPos, 0)
        absorbFrame.spark:Show()
    end

    -- Time remaining
    local timeLeft = (absorbState.startTime + absorbState.duration) - GetTime()
    if timeLeft <= 0 then
        HideAbsorb()
        return
    end

    absorbFrame.valueText:SetText(FormatNumber(math.floor(remaining)) .. " | " .. string.format("%.0f", timeLeft) .. "s")
end

--------------------------------------------------------------------------------
-- Combat Log Handler
--------------------------------------------------------------------------------

local function OnCombatLogEvent()
    local _, subevent, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()

    -- Check for absorb buff applied (self-cast)
    if (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH") and sourceGUID == playerGUID and destGUID == playerGUID then
        local spellId, spellName = select(12, CombatLogGetCurrentEventInfo())
        local absorbInfo = Castborn.SpellData:GetAbsorbInfo(spellId)
        if absorbInfo then
            local absorbAmount = ScanAbsorbTooltip(spellId)
            if absorbAmount and absorbAmount > 0 then
                ShowAbsorb(spellId, absorbInfo.name, absorbAmount, absorbInfo.duration)
            end
        end
    end

    -- Check for absorb buff removed
    if subevent == "SPELL_AURA_REMOVED" and destGUID == playerGUID then
        local spellId = select(12, CombatLogGetCurrentEventInfo())
        if absorbState.active and absorbState.spellId == spellId then
            HideAbsorb()
        end
    end

    -- Track damage absorbed while shield is active
    if absorbState.active and destGUID == playerGUID then
        if subevent == "SWING_DAMAGE" then
            -- SWING_DAMAGE: amount(12), overkill(13), school(14), resisted(15), blocked(16), absorbed(17)
            local absorbed = select(17, CombatLogGetCurrentEventInfo())
            if absorbed and absorbed > 0 then
                absorbState.remaining = math.max(0, absorbState.remaining - absorbed)
            end
        elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
            -- SPELL_DAMAGE: spellId(12), spellName(13), spellSchool(14), amount(15), overkill(16), school(17), resisted(18), blocked(19), absorbed(20)
            local absorbed = select(20, CombatLogGetCurrentEventInfo())
            if absorbed and absorbed > 0 then
                absorbState.remaining = math.max(0, absorbState.remaining - absorbed)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Defaults and Lifecycle
--------------------------------------------------------------------------------

local defaults = {
    enabled = true,
    width = 250,
    barHeight = 20,
    barColor = {0.4, 0.7, 1.0, 1.0},
    bgColor = {0.1, 0.1, 0.1, 0.8},
    borderColor = {0.3, 0.3, 0.3, 1},
    point = "CENTER",
    xPct = 0,
    yPct = -0.185,
}

CB:RegisterCallback("INIT", function()
    CastbornDB.absorbs = CB:MergeDefaults(CastbornDB.absorbs or {}, defaults)

    -- Only enable for mages by default
    local _, class = UnitClass("player")
    if class ~= "MAGE" then
        CastbornDB.absorbs.enabled = false
    end
end)

CB:RegisterCallback("READY", function()
    local _, class = UnitClass("player")
    if class ~= "MAGE" then return end
    if not CastbornDB.absorbs.enabled then return end

    playerGUID = UnitGUID("player")
    absorbFrame = CreateAbsorbBar()

    -- Event frame for combat log
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            OnCombatLogEvent()
        end
    end)

    -- Update loop
    CB:CreateThrottledUpdater(0.05, function()
        if testModeActive then return end
        UpdateAbsorbBar()
    end)

    -- Register with TestManager
    CB.TestManager:Register("AbsorbTracker",
        function() CB:TestAbsorbTracker() end,
        function() CB:EndTestAbsorbTracker() end
    )
end)

--------------------------------------------------------------------------------
-- Test Mode
--------------------------------------------------------------------------------

function CB:TestAbsorbTracker()
    if not absorbFrame then return end
    testModeActive = true

    absorbFrame.label:SetText("Ice Barrier")
    absorbFrame.bar:SetValue(0.65)
    local sparkPos = 0.65 * absorbFrame.bar:GetWidth()
    absorbFrame.spark:SetPoint("CENTER", absorbFrame.bar, "LEFT", sparkPos, 0)
    absorbFrame.spark:Show()
    absorbFrame.valueText:SetText("1,847 | 42s")
    absorbFrame:SetAlpha(1)
    absorbFrame:Show()
end

function CB:EndTestAbsorbTracker()
    testModeActive = false
    if absorbFrame then absorbFrame:Hide() end
end

Castborn:RegisterModule("AbsorbTracker", AbsorbTracker)

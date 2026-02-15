--[[
    Castborn - Absorb Tracker Module
    Tracks absorb shield remaining amount (Ice Barrier MVP)
    Displays as a circular shield icon with radial sweep drain
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
-- Frame Creation — Shield Style
--------------------------------------------------------------------------------

local function CreateAbsorbShield()
    local cfg = CB.db.absorbs
    local size = cfg.size or 64

    local frame = CreateFrame("Frame", "Castborn_AbsorbTracker", UIParent)
    frame:SetSize(size, size)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)

    -- Dark circular background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    bg:SetVertexColor(0.05, 0.05, 0.05, 0.7)
    frame.bg = bg

    -- Shield icon texture (Ice Barrier spell icon)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\Spell_Ice_Lament")
    frame.icon = icon

    -- Cooldown sweep overlay (drains as absorb is consumed)
    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetDrawEdge(true)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetReverse(true)
    cooldown:SetHideCountdownNumbers(true)
    frame.cooldown = cooldown

    -- Simple colored edge border (1px)
    local borderSize = 1
    local borderColor = {0.4, 0.7, 1.0, 0.8}

    local borderTop = frame:CreateTexture(nil, "OVERLAY")
    borderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    borderTop:SetPoint("TOPLEFT", -borderSize, borderSize)
    borderTop:SetPoint("TOPRIGHT", borderSize, borderSize)
    borderTop:SetHeight(borderSize)

    local borderBottom = frame:CreateTexture(nil, "OVERLAY")
    borderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    borderBottom:SetPoint("BOTTOMLEFT", -borderSize, -borderSize)
    borderBottom:SetPoint("BOTTOMRIGHT", borderSize, -borderSize)
    borderBottom:SetHeight(borderSize)

    local borderLeft = frame:CreateTexture(nil, "OVERLAY")
    borderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    borderLeft:SetPoint("TOPLEFT", -borderSize, borderSize)
    borderLeft:SetPoint("BOTTOMLEFT", -borderSize, -borderSize)
    borderLeft:SetWidth(borderSize)

    local borderRight = frame:CreateTexture(nil, "OVERLAY")
    borderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    borderRight:SetPoint("TOPRIGHT", borderSize, borderSize)
    borderRight:SetPoint("BOTTOMRIGHT", borderSize, -borderSize)
    borderRight:SetWidth(borderSize)

    frame.borderTextures = {borderTop, borderBottom, borderLeft, borderRight}

    -- Absorb amount text (centered on icon)
    local valueText = frame:CreateFontString(nil, "OVERLAY")
    valueText:SetFont("Fonts\\FRIZQT__.TTF", math.max(10, math.floor(size * 0.2)), "OUTLINE")
    valueText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    valueText:SetTextColor(1, 1, 1, 1)
    frame.valueText = valueText

    -- Timer text (below the icon)
    local timerText = frame:CreateFontString(nil, "OVERLAY")
    timerText:SetFont("Fonts\\FRIZQT__.TTF", math.max(9, math.floor(size * 0.16)), "OUTLINE")
    timerText:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    timerText:SetTextColor(0.7, 0.9, 1.0, 1)
    frame.timerText = timerText

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
        -- Reset icon to full brightness
        absorbFrame.icon:SetVertexColor(1, 1, 1, 1)
        for _, tex in ipairs(absorbFrame.borderTextures) do
            tex:SetColorTexture(0.4, 0.7, 1.0, 0.8)
        end
        -- Reset cooldown sweep
        absorbFrame.cooldown:SetCooldown(0, 0)
        FadeIn(absorbFrame, 0.3)
    end
end

local function HideAbsorb()
    absorbState.active = false
    if absorbFrame and absorbFrame:IsShown() then
        FadeOut(absorbFrame, 0.3)
    end
end

local function UpdateAbsorbShield()
    if not absorbFrame or not absorbState.active then return end
    if not CB.db.absorbs.enabled then absorbFrame:Hide() return end

    local remaining = absorbState.remaining
    local max = absorbState.maxAbsorb
    local pct = max > 0 and (remaining / max) or 0

    -- Time remaining
    local timeLeft = (absorbState.startTime + absorbState.duration) - GetTime()
    if timeLeft <= 0 then
        HideAbsorb()
        return
    end

    -- Update cooldown sweep to show absorb consumed (reverse sweep)
    -- We use the ratio of absorb consumed to drive the sweep
    local consumed = 1 - pct
    if consumed > 0 then
        -- SetCooldown with a fake duration so the sweep shows the consumed portion
        absorbFrame.cooldown:SetCooldown(GetTime() - consumed, 1)
    else
        absorbFrame.cooldown:SetCooldown(0, 0)
    end

    -- Dim the icon as absorb drains (full brightness at 100%, dimmer as it drains)
    local brightness = 0.4 + (0.6 * pct)  -- Range: 0.4 (depleted) to 1.0 (full)
    absorbFrame.icon:SetVertexColor(brightness, brightness, brightness, 1)

    -- Shift border color from bright blue to dull red as shield weakens
    local r = 0.4 + (0.6 * (1 - pct))  -- 0.4 -> 1.0
    local g = 0.7 * pct                 -- 0.7 -> 0.0
    local b = 1.0 * pct                 -- 1.0 -> 0.0
    for _, tex in ipairs(absorbFrame.borderTextures) do
        tex:SetColorTexture(r, g, b, 0.8)
    end

    -- Update text
    absorbFrame.valueText:SetText(FormatNumber(math.floor(remaining)))
    absorbFrame.timerText:SetText(string.format("%.0f", timeLeft) .. "s")
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
        local absorbed = 0

        if subevent == "SWING_DAMAGE" then
            -- SWING_DAMAGE suffix: amount, overkill, school, resisted, blocked, absorbed, ...
            -- Search params 12-20 for the absorbed value (position varies by client)
            local p12, p13, p14, p15, p16, p17, p18, p19, p20 = select(12, CombatLogGetCurrentEventInfo())
            -- absorbed is typically at position 17 (index 6 in suffix), but try known positions
            absorbed = (type(p17) == "number" and p17) or 0
            -- If p17 is 0/1 (looks like a boolean for critical), try p16 instead
            if absorbed <= 1 and type(p16) == "number" and p16 > 1 then
                absorbed = p16
            end

        elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
            -- SPELL_DAMAGE suffix: spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, ...
            local p12, p13, p14, p15, p16, p17, p18, p19, p20, p21, p22, p23 = select(12, CombatLogGetCurrentEventInfo())
            absorbed = (type(p20) == "number" and p20) or 0
            -- Fallback: try p19 if p20 looks like a boolean
            if absorbed <= 1 and type(p19) == "number" and p19 > 1 then
                absorbed = p19
            end

        elseif subevent == "SWING_MISSED" then
            -- SWING_MISSED with missType ABSORB: missType(12), isOffHand(13), amountMissed(14)
            local missType, _, amountMissed = select(12, CombatLogGetCurrentEventInfo())
            if missType == "ABSORB" and amountMissed and amountMissed > 0 then
                absorbed = amountMissed
            end

        elseif subevent == "SPELL_MISSED" or subevent == "RANGE_MISSED" or subevent == "SPELL_PERIODIC_MISSED" then
            -- SPELL_MISSED with missType ABSORB: spellId(12), spellName(13), spellSchool(14), missType(15), isOffHand(16), amountMissed(17)
            local _, _, _, missType, _, amountMissed = select(12, CombatLogGetCurrentEventInfo())
            if missType == "ABSORB" and amountMissed and amountMissed > 0 then
                absorbed = amountMissed
            end
        end

        if absorbed > 0 then
            absorbState.remaining = math.max(0, absorbState.remaining - absorbed)
        end
    end
end

--------------------------------------------------------------------------------
-- Defaults and Lifecycle
--------------------------------------------------------------------------------

local defaults = {
    enabled = true,
    size = 64,
    point = "CENTER",
    xPct = 0,
    yPct = -0.185,
}

CB:RegisterCallback("INIT", function()
    CastbornDB.absorbs = CB:MergeDefaults(CastbornDB.absorbs or {}, defaults)

    -- Clean up stale bar-style settings from v1
    CastbornDB.absorbs.width = nil
    CastbornDB.absorbs.barHeight = nil
    CastbornDB.absorbs.barColor = nil
    CastbornDB.absorbs.bgColor = nil
    CastbornDB.absorbs.borderColor = nil

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
    absorbFrame = CreateAbsorbShield()

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
        UpdateAbsorbShield()
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

    absorbFrame.icon:SetVertexColor(0.8, 0.8, 0.8, 1)
    for _, tex in ipairs(absorbFrame.borderTextures) do
        tex:SetColorTexture(0.4, 0.5, 0.7, 0.8)
    end
    absorbFrame.cooldown:SetCooldown(GetTime() - 0.35, 1)
    absorbFrame.valueText:SetText("1,847")
    absorbFrame.timerText:SetText("42s")
    absorbFrame:SetAlpha(1)
    absorbFrame:Show()
end

function CB:EndTestAbsorbTracker()
    testModeActive = false
    if absorbFrame then
        absorbFrame:Hide()
        absorbFrame.shownForPositioning = nil
    end
end

Castborn:RegisterModule("AbsorbTracker", AbsorbTracker)

--[[
    Castborn - Absorb Tracker Module
    Tracks absorb shield remaining amounts across all TBC absorb spells.
    Displays as circular shield icons with radial sweep drain.
    Supports multiple simultaneous absorbs with configurable grow direction.
]]

local AbsorbTracker = {}
Castborn.AbsorbTracker = AbsorbTracker

local CB = Castborn

-- State
local containerFrame = nil
local activeAbsorbs = {}   -- ordered array of { spellId, spellName, maxAbsorb, remaining, startTime, duration, school, frame }
local iconPool = {}        -- recycled icon frames
local MAX_ABSORBS = 6
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

local function GetAbsorbBorderColor(school)
    if school then
        local color = Castborn.SpellData:GetSchoolColor(school)
        return color[1], color[2], color[3], 0.8
    end
    -- Default frost-blue for general absorbs
    return 0.4, 0.7, 1.0, 0.8
end

--------------------------------------------------------------------------------
-- Frame Creation — Icon Pool
--------------------------------------------------------------------------------

local function CreateAbsorbIcon()
    local cfg = CB.db.absorbs
    local size = cfg.size or 48

    local frame = CreateFrame("Frame", nil, containerFrame)
    frame:SetSize(size, size)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)

    -- Dark circular background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    bg:SetVertexColor(0.05, 0.05, 0.05, 0.7)
    frame.bg = bg

    -- Spell icon texture (set dynamically)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
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

    local borderTop = frame:CreateTexture(nil, "OVERLAY")
    borderTop:SetColorTexture(0.4, 0.7, 1.0, 0.8)
    borderTop:SetPoint("TOPLEFT", -borderSize, borderSize)
    borderTop:SetPoint("TOPRIGHT", borderSize, borderSize)
    borderTop:SetHeight(borderSize)

    local borderBottom = frame:CreateTexture(nil, "OVERLAY")
    borderBottom:SetColorTexture(0.4, 0.7, 1.0, 0.8)
    borderBottom:SetPoint("BOTTOMLEFT", -borderSize, -borderSize)
    borderBottom:SetPoint("BOTTOMRIGHT", borderSize, -borderSize)
    borderBottom:SetHeight(borderSize)

    local borderLeft = frame:CreateTexture(nil, "OVERLAY")
    borderLeft:SetColorTexture(0.4, 0.7, 1.0, 0.8)
    borderLeft:SetPoint("TOPLEFT", -borderSize, borderSize)
    borderLeft:SetPoint("BOTTOMLEFT", -borderSize, -borderSize)
    borderLeft:SetWidth(borderSize)

    local borderRight = frame:CreateTexture(nil, "OVERLAY")
    borderRight:SetColorTexture(0.4, 0.7, 1.0, 0.8)
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

    frame:Hide()
    return frame
end

local function AcquireIcon()
    local icon = tremove(iconPool)
    if not icon then
        icon = CreateAbsorbIcon()
    end
    return icon
end

local function ReleaseIcon(icon)
    icon:Hide()
    icon.cooldown:SetCooldown(0, 0)
    icon.lastConsumed = nil
    icon.valueText:SetText("")
    icon.timerText:SetText("")
    icon:ClearAllPoints()
    tinsert(iconPool, icon)
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

local function LayoutIcons()
    local db = CB.db.absorbs
    local size = db.size or 48
    local spacing = db.spacing or 4

    for i, absorb in ipairs(activeAbsorbs) do
        local icon = absorb.frame
        if icon then
            icon:ClearAllPoints()
            icon:SetSize(size, size)

            -- Update font sizes when size changes
            icon.valueText:SetFont("Fonts\\FRIZQT__.TTF", math.max(10, math.floor(size * 0.2)), "OUTLINE")
            icon.timerText:SetFont("Fonts\\FRIZQT__.TTF", math.max(9, math.floor(size * 0.16)), "OUTLINE")

            if db.growDirection == "RIGHT" then
                icon:SetPoint("LEFT", containerFrame, "LEFT", (i - 1) * (size + spacing), 0)
            else
                icon:SetPoint("RIGHT", containerFrame, "RIGHT", -((i - 1) * (size + spacing)), 0)
            end
        end
    end
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
-- Absorb Management
--------------------------------------------------------------------------------

local function FindAbsorbBySpellId(spellId)
    for i, absorb in ipairs(activeAbsorbs) do
        if absorb.spellId == spellId then
            return i, absorb
        end
    end
    return nil, nil
end

local function FindAbsorbByName(name)
    for i, absorb in ipairs(activeAbsorbs) do
        if absorb.spellName == name then
            return i, absorb
        end
    end
    return nil, nil
end

local function SetupIconVisuals(icon, spellId, school)
    -- Set spell icon texture
    local texture = GetSpellTexture(spellId)
    if texture then
        icon.icon:SetTexture(texture)
    end

    -- Set border color based on spell school
    local r, g, b, a = GetAbsorbBorderColor(school)
    for _, tex in ipairs(icon.borderTextures) do
        tex:SetColorTexture(r, g, b, a)
    end

    -- Store base border color for drain effect
    icon.baseBorderR = r
    icon.baseBorderG = g
    icon.baseBorderB = b
end

local function AddAbsorb(spellId, spellName, absorbAmount, duration, school)
    if #activeAbsorbs >= MAX_ABSORBS then return end

    -- Check if this spell is already tracked (refresh case handled separately)
    local _, existing = FindAbsorbBySpellId(spellId)
    if existing then return end

    -- Also check by name since different ranks have different spellIds
    local existIdx, existByName = FindAbsorbByName(spellName)
    if existByName then
        -- Replace existing with new rank
        existByName.spellId = spellId
        existByName.maxAbsorb = absorbAmount
        existByName.remaining = absorbAmount
        existByName.startTime = GetTime()
        existByName.duration = duration
        existByName.school = school
        SetupIconVisuals(existByName.frame, spellId, school)
        existByName.frame.icon:SetVertexColor(1, 1, 1, 1)
        existByName.frame.cooldown:SetCooldown(0, 0)
        FadeIn(existByName.frame, 0.3)
        return
    end

    local icon = AcquireIcon()
    SetupIconVisuals(icon, spellId, school)
    icon.icon:SetVertexColor(1, 1, 1, 1)
    icon.cooldown:SetCooldown(0, 0)

    local entry = {
        spellId = spellId,
        spellName = spellName,
        maxAbsorb = absorbAmount,
        remaining = absorbAmount,
        startTime = GetTime(),
        duration = duration,
        school = school,
        frame = icon,
    }
    tinsert(activeAbsorbs, entry)

    LayoutIcons()
    FadeIn(icon, 0.3)
end

local function RefreshAbsorb(spellId, absorbAmount, duration)
    local _, absorb = FindAbsorbBySpellId(spellId)
    if not absorb then return end

    absorb.maxAbsorb = absorbAmount
    absorb.remaining = absorbAmount
    absorb.startTime = GetTime()
    absorb.duration = duration
    absorb.frame.icon:SetVertexColor(1, 1, 1, 1)
    absorb.frame.cooldown:SetCooldown(0, 0)
    absorb.frame.lastConsumed = nil

    local r, g, b, a = GetAbsorbBorderColor(absorb.school)
    for _, tex in ipairs(absorb.frame.borderTextures) do
        tex:SetColorTexture(r, g, b, a)
    end
end

local function RemoveAbsorb(spellId)
    local idx, absorb = FindAbsorbBySpellId(spellId)
    if not absorb then return end

    ReleaseIcon(absorb.frame)
    tremove(activeAbsorbs, idx)
    LayoutIcons()
end

local function RemoveAbsorbByName(name)
    local idx, absorb = FindAbsorbByName(name)
    if not absorb then return end

    ReleaseIcon(absorb.frame)
    tremove(activeAbsorbs, idx)
    LayoutIcons()
end

local function ClearAllAbsorbs()
    for i = #activeAbsorbs, 1, -1 do
        ReleaseIcon(activeAbsorbs[i].frame)
        tremove(activeAbsorbs, i)
    end
end

--------------------------------------------------------------------------------
-- Damage Attribution
--------------------------------------------------------------------------------

local function ApplyAbsorbedDamage(absorbed, damageSchool)
    if absorbed <= 0 then return end

    local remaining = absorbed

    -- First pass: school-specific absorbs that match the damage school
    for _, absorb in ipairs(activeAbsorbs) do
        if remaining <= 0 then break end
        if absorb.school and absorb.school == damageSchool then
            local applied = math.min(remaining, absorb.remaining)
            absorb.remaining = absorb.remaining - applied
            remaining = remaining - applied
        end
    end

    -- Second pass: general absorbs (no school restriction), oldest first
    for _, absorb in ipairs(activeAbsorbs) do
        if remaining <= 0 then break end
        if not absorb.school then
            local applied = math.min(remaining, absorb.remaining)
            absorb.remaining = absorb.remaining - applied
            remaining = remaining - applied
        end
    end
end

--------------------------------------------------------------------------------
-- Update Loop
--------------------------------------------------------------------------------

local function UpdateAbsorbIcons()
    if not containerFrame then return end
    if not CB.db.absorbs.enabled then
        containerFrame:Hide()
        return
    end

    local now = GetTime()

    -- Update each active absorb icon
    for i = #activeAbsorbs, 1, -1 do
        local absorb = activeAbsorbs[i]
        local icon = absorb.frame

        local timeLeft = (absorb.startTime + absorb.duration) - now
        if timeLeft <= 0 then
            -- Expired
            ReleaseIcon(icon)
            tremove(activeAbsorbs, i)
        elseif icon then
            local pct = absorb.maxAbsorb > 0 and (absorb.remaining / absorb.maxAbsorb) or 0

            -- Update cooldown sweep only when consumed % changes (avoids flicker)
            local consumed = 1 - pct
            local lastConsumed = icon.lastConsumed or 0
            if math.abs(consumed - lastConsumed) > 0.005 then
                icon.lastConsumed = consumed
                if consumed > 0 then
                    icon.cooldown:SetCooldown(now - consumed, 1)
                else
                    icon.cooldown:SetCooldown(0, 0)
                end
            end

            -- Dim icon as absorb drains
            local brightness = 0.4 + (0.6 * pct)
            icon.icon:SetVertexColor(brightness, brightness, brightness, 1)

            -- Shift border color towards red as shield weakens
            local baseR = icon.baseBorderR or 0.4
            local baseG = icon.baseBorderG or 0.7
            local baseB = icon.baseBorderB or 1.0
            local r = baseR + ((1.0 - baseR) * (1 - pct))
            local g = baseG * pct
            local b = baseB * pct
            for _, tex in ipairs(icon.borderTextures) do
                tex:SetColorTexture(r, g, b, 0.8)
            end

            -- Update text
            icon.valueText:SetText(FormatNumber(math.floor(absorb.remaining)))
            icon.timerText:SetText(string.format("%.0f", timeLeft) .. "s")
        end
    end

    -- Re-layout after removing expired absorbs
    LayoutIcons()

    -- Show/hide container based on active absorbs
    if #activeAbsorbs > 0 then
        if not containerFrame:IsShown() then
            containerFrame:Show()
        end
    else
        containerFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- Combat Log Handler
--------------------------------------------------------------------------------

local function OnCombatLogEvent()
    local _, subevent, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()

    -- Check for absorb buff applied (any source, on player)
    if (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH") and destGUID == playerGUID then
        local spellId, spellName = select(12, CombatLogGetCurrentEventInfo())
        local absorbInfo = Castborn.SpellData:GetAbsorbInfo(spellId)
        if absorbInfo then
            local absorbAmount = ScanAbsorbTooltip(spellId)
            if absorbAmount and absorbAmount > 0 then
                if subevent == "SPELL_AURA_REFRESH" then
                    -- Try refresh first, fall back to add
                    local _, existing = FindAbsorbBySpellId(spellId)
                    if existing then
                        RefreshAbsorb(spellId, absorbAmount, absorbInfo.duration)
                    else
                        AddAbsorb(spellId, absorbInfo.name, absorbAmount, absorbInfo.duration, absorbInfo.school)
                    end
                else
                    AddAbsorb(spellId, absorbInfo.name, absorbAmount, absorbInfo.duration, absorbInfo.school)
                end
            end
        end
    end

    -- Check for absorb buff removed
    if subevent == "SPELL_AURA_REMOVED" and destGUID == playerGUID then
        local spellId = select(12, CombatLogGetCurrentEventInfo())
        local absorbInfo = Castborn.SpellData:GetAbsorbInfo(spellId)
        if absorbInfo then
            -- Try by spellId first, then by name (handles rank differences)
            local idx = FindAbsorbBySpellId(spellId)
            if idx then
                RemoveAbsorb(spellId)
            else
                RemoveAbsorbByName(absorbInfo.name)
            end
        end
    end

    -- Track damage absorbed while any shields are active
    if #activeAbsorbs > 0 and destGUID == playerGUID then
        local absorbed = 0
        local damageSchool = 1  -- default physical

        if subevent == "SWING_DAMAGE" then
            damageSchool = 1
            local p12, p13, p14, p15, p16, p17 = select(12, CombatLogGetCurrentEventInfo())
            absorbed = (type(p17) == "number" and p17) or 0
            if absorbed <= 1 and type(p16) == "number" and p16 > 1 then
                absorbed = p16
            end

        elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
            local p12, p13, p14, p15, p16, p17, p18, p19, p20 = select(12, CombatLogGetCurrentEventInfo())
            damageSchool = p14 or 1  -- spellSchool is param 14 (3rd in spell prefix)
            absorbed = (type(p20) == "number" and p20) or 0
            if absorbed <= 1 and type(p19) == "number" and p19 > 1 then
                absorbed = p19
            end

        elseif subevent == "SWING_MISSED" then
            damageSchool = 1
            local missType, _, amountMissed = select(12, CombatLogGetCurrentEventInfo())
            if missType == "ABSORB" and amountMissed and amountMissed > 0 then
                absorbed = amountMissed
            end

        elseif subevent == "SPELL_MISSED" or subevent == "RANGE_MISSED" or subevent == "SPELL_PERIODIC_MISSED" then
            local _, _, spellSchool, missType, _, amountMissed = select(12, CombatLogGetCurrentEventInfo())
            damageSchool = spellSchool or 1
            if missType == "ABSORB" and amountMissed and amountMissed > 0 then
                absorbed = amountMissed
            end
        end

        if absorbed > 0 then
            ApplyAbsorbedDamage(absorbed, damageSchool)
        end
    end
end

--------------------------------------------------------------------------------
-- Defaults and Lifecycle
--------------------------------------------------------------------------------

local defaults = {
    enabled = true,
    size = 48,
    spacing = 4,
    growDirection = "LEFT",
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
end)

CB:RegisterCallback("READY", function()
    if not CastbornDB.absorbs.enabled then return end

    playerGUID = UnitGUID("player")

    -- Create container frame (draggable, positionable)
    containerFrame = CreateFrame("Frame", "Castborn_AbsorbTracker", UIParent)
    local size = CB.db.absorbs.size or 48
    containerFrame:SetSize(size, size)
    containerFrame:SetFrameStrata("MEDIUM")

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(containerFrame, CB.db.absorbs, nil, "Absorb Tracker")
    else
        CB:MakeMoveable(containerFrame, "absorbs")
    end
    CB:ApplyPosition(containerFrame, "absorbs")
    containerFrame:Hide()

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
        UpdateAbsorbIcons()
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
    if not containerFrame then return end
    testModeActive = true

    ClearAllAbsorbs()

    -- Show 2 test absorb icons to demonstrate multi-absorb layout
    local testAbsorbs = {
        { spellId = 11426, name = "Ice Barrier", amount = 1847, duration = 60, school = nil },
        { spellId = 17,    name = "Power Word: Shield", amount = 942, duration = 30, school = nil },
    }

    for i, test in ipairs(testAbsorbs) do
        local icon = AcquireIcon()
        SetupIconVisuals(icon, test.spellId, test.school)

        -- Simulate partial drain on first icon
        local pct = (i == 1) and 0.65 or 1.0
        local brightness = 0.4 + (0.6 * pct)
        icon.icon:SetVertexColor(brightness, brightness, brightness, 1)

        if i == 1 then
            icon.cooldown:SetCooldown(GetTime() - 0.35, 1)
        end

        icon.valueText:SetText(FormatNumber(test.amount))
        icon.timerText:SetText("42s")

        local entry = {
            spellId = test.spellId,
            spellName = test.name,
            maxAbsorb = test.amount,
            remaining = test.amount,
            startTime = GetTime(),
            duration = test.duration,
            school = test.school,
            frame = icon,
        }
        tinsert(activeAbsorbs, entry)

        icon:SetAlpha(1)
        icon:Show()
    end

    LayoutIcons()
    containerFrame:Show()
end

function CB:EndTestAbsorbTracker()
    testModeActive = false
    ClearAllAbsorbs()
    if containerFrame then
        containerFrame:Hide()
    end
end

Castborn:RegisterModule("AbsorbTracker", AbsorbTracker)

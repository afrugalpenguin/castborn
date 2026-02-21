--[[
    Castborn - Totem Tracker Module
    Tracks active totems with duration bars (Shaman only)
    Mouseover shows party members NOT affected by the totem
]]

local TotemTracker = {}
Castborn.TotemTracker = TotemTracker

local CB = Castborn
CB.totemTracker = nil

local totemBars = {}
local MAX_TOTEMS = 4

-- Totem slot constants
local FIRE_TOTEM_SLOT = 1
local EARTH_TOTEM_SLOT = 2
local WATER_TOTEM_SLOT = 3
local AIR_TOTEM_SLOT = 4

-- Totem element colours
local totemColors = {
    [FIRE_TOTEM_SLOT] = { 0.9, 0.3, 0.1 },   -- Fire - orange/red
    [EARTH_TOTEM_SLOT] = { 0.6, 0.4, 0.2 },  -- Earth - brown
    [WATER_TOTEM_SLOT] = { 0.2, 0.5, 0.9 },  -- Water - blue
    [AIR_TOTEM_SLOT] = { 0.7, 0.7, 0.9 },    -- Air - light purple/white
}

-- Totem element names for display
local totemSlotNames = {
    [FIRE_TOTEM_SLOT] = "Fire",
    [EARTH_TOTEM_SLOT] = "Earth",
    [WATER_TOTEM_SLOT] = "Water",
    [AIR_TOTEM_SLOT] = "Air",
}

-- Totem range (most totems are 20-30 yards, we'll use 30 as default)
local TOTEM_RANGE = 30

-- Test mode data
local testModeActive = false
local testPartyMembers = {
    { name = "Healbot", class = "PRIEST" },
    { name = "Tankadin", class = "PALADIN" },
    { name = "Stabsworth", class = "ROGUE" },
    { name = "Pyroblaster", class = "MAGE" },
    { name = "Furylolz", class = "WARRIOR" },
}

-- Offensive totems don't need party coverage tracking (they damage enemies, not buff party)
local offensiveTotems = {
    ["Searing Totem"] = true,
    ["Magma Totem"] = true,
    ["Fire Nova Totem"] = true,
    ["Stoneclaw Totem"] = true,
    ["Earthbind Totem"] = true,
    ["Fire Elemental Totem"] = true,
    ["Earth Elemental Totem"] = true,
}

-- Which test party members are "out of range" for each totem slot (only for beneficial totems)
local testNotInRange = {
    [FIRE_TOTEM_SLOT] = nil,                 -- Fire totems are offensive, no party tracking
    [EARTH_TOTEM_SLOT] = {},                 -- Everyone in range (Strength of Earth)
    [WATER_TOTEM_SLOT] = { "Stabsworth", "Pyroblaster" },  -- Melee and ranged out
    [AIR_TOTEM_SLOT] = { "Healbot", "Furylolz" },  -- Healer and warrior out of range (RIP Windfury)
}

local defaults = {
    enabled = true,
    width = 180,
    barHeight = 16,
    spacing = 2,
    x = -300,
    y = -200,
    xPct = -0.156,
    yPct = -0.185,
    point = "CENTER",
    bgColor = { 0.05, 0.05, 0.05, 0.85 },
    borderColor = { 0.3, 0.3, 0.3, 1 },
    showTooltip = true,
    anchored = false,
}

local function CreateTotemBar(parent, index)
    local cfg = CastbornDB.totems
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(cfg.width - 8, cfg.barHeight)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4 - (index - 1) * (cfg.barHeight + cfg.spacing))

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 2 + cfg.barHeight, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    bar:SetStatusBarTexture(Castborn:GetBarTexture())
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    frame.bar = bar
    Castborn:RegisterBarFrame(bar)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    barBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    -- Icon button for Masque compatibility
    local iconFrame = CreateFrame("Button", nil, frame)
    iconFrame:SetSize(cfg.barHeight - 2, cfg.barHeight - 2)
    iconFrame:SetPoint("LEFT", frame, "LEFT", 2, 0)

    local icon = iconFrame:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    iconFrame.Icon = icon
    frame.icon = icon

    local iconNormal = iconFrame:CreateTexture(nil, "BORDER")
    iconNormal:SetPoint("TOPLEFT", -1, 1)
    iconNormal:SetPoint("BOTTOMRIGHT", 1, -1)
    iconNormal:SetColorTexture(0.3, 0.3, 0.3, 1)
    iconFrame.Normal = iconNormal
    if Castborn.Masque and Castborn.Masque.enabled then
        iconFrame:SetNormalTexture(iconNormal)
    else
        iconNormal:Hide()
    end

    local iconCooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
    iconCooldown:SetAllPoints()
    iconCooldown:SetDrawEdge(false)
    iconCooldown:SetHideCountdownNumbers(true)
    iconFrame.Cooldown = iconCooldown

    frame.iconButton = iconFrame

    -- Register with Masque if available
    if Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:AddButton("totems", iconFrame, {
            Icon = icon,
            Cooldown = iconCooldown,
            Normal = iconNormal,
        })
    end

    local nameText = bar:CreateFontString(nil, "OVERLAY")
    nameText:SetFont("Fonts\\ARIALN.TTF", cfg.barHeight - 6, "OUTLINE")
    nameText:SetPoint("LEFT", bar, "LEFT", 2, 0)
    nameText:SetJustifyH("LEFT")
    frame.nameText = nameText

    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont("Fonts\\ARIALN.TTF", cfg.barHeight - 6, "OUTLINE")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    timeText:SetJustifyH("RIGHT")
    frame.timeText = timeText

    -- Buff count indicator (shows party members in range)
    local countText = bar:CreateFontString(nil, "OVERLAY")
    countText:SetFont("Fonts\\ARIALN.TTF", cfg.barHeight - 7, "OUTLINE")
    countText:SetPoint("RIGHT", timeText, "LEFT", -6, 0)
    countText:SetJustifyH("RIGHT")
    countText:SetAlpha(0.9)
    frame.countText = countText

    -- Store the slot for tooltip
    frame.totemSlot = index

    -- Enable mouse for tooltip
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        local cfg = CastbornDB.totems
        if not cfg.showTooltip then return end
        TotemTracker:ShowTooltip(self)
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    frame:Hide()
    return frame
end

-- Get party size (excluding player, subgroup only - totems don't affect the whole raid)
local function GetPartySize()
    if testModeActive then
        return #testPartyMembers
    end
    -- In a raid, GetNumPartyMembers() returns 0, but "party1"-"party4" still refer to
    -- subgroup members. Count them directly so we only track our party, not the full raid.
    local count = 0
    for i = 1, 4 do
        if UnitExists("party" .. i) then
            count = count + 1
        end
    end
    return count
end

-- Get buffed count for a totem slot (returns buffed, total)
function TotemTracker:GetBuffedCount(totemSlot, totemName)
    local partySize = GetPartySize()
    if partySize == 0 then return 0, 0 end

    -- Offensive totems don't buff party
    if offensiveTotems[totemName] then return 0, 0 end

    local notAffected
    if testModeActive then
        notAffected = testNotInRange[totemSlot] or {}
    else
        notAffected = self:GetMembersNotAffected(totemSlot)
    end

    local buffedCount = partySize - #notAffected
    return buffedCount, partySize
end

-- Get party/raid members not in range of the totem
function TotemTracker:GetMembersNotAffected(totemSlot)
    local notAffected = {}
    local haveTotem, totemName, startTime, duration, icon = GetTotemInfo(totemSlot)

    if not haveTotem then return notAffected end

    -- Check party members (only subgroup, not full raid)
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            if not UnitIsDeadOrGhost(unit) then
                -- Use CheckInteractDistance for range check (index 4 = 28 yards, close to totem range)
                local inRange = CheckInteractDistance(unit, 4)
                if not inRange then
                    local name = UnitName(unit)
                    table.insert(notAffected, name)
                end
            end
        end
    end

    return notAffected
end

function TotemTracker:ShowTooltip(frame)
    local slot = frame.totemSlot
    local totemName

    -- In test mode, use test data
    if testModeActive then
        local testTotems = {
            [FIRE_TOTEM_SLOT] = "Searing Totem",
            [EARTH_TOTEM_SLOT] = "Strength of Earth Totem",
            [WATER_TOTEM_SLOT] = "Mana Spring Totem",
            [AIR_TOTEM_SLOT] = "Windfury Totem",
        }
        totemName = testTotems[slot] or "Test Totem"
    else
        local haveTotem, name, startTime, duration, icon = GetTotemInfo(slot)
        if not haveTotem then return end
        totemName = name
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine(totemName, 1, 1, 1)

    -- Skip party coverage for offensive totems (they don't buff the party)
    if offensiveTotems[totemName] then
        GameTooltip:Show()
        return
    end

    -- Get members not in range (real or test data)
    local notAffected
    if testModeActive then
        notAffected = testNotInRange[slot] or {}
    else
        notAffected = self:GetMembersNotAffected(slot)
    end

    -- Show party member status for beneficial totems
    local numParty = GetPartySize()

    if #notAffected > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Not in range:", 1, 0.5, 0.5)
        for _, name in ipairs(notAffected) do
            GameTooltip:AddLine("  " .. name, 0.8, 0.3, 0.3)
        end
    elseif numParty > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("All party members in range", 0.3, 0.9, 0.3)
    end

    GameTooltip:Show()
end

local function UpdateTotemBar(totemBar, slot, name, icon, startTime, duration)
    local remaining = (startTime + duration) - GetTime()
    local progress = duration > 0 and (remaining / duration) or 1
    progress = math.max(0, math.min(1, progress))

    totemBar.bar:SetValue(progress)
    totemBar.icon:SetTexture(icon)

    -- Show shortened name (remove "Totem" suffix for brevity)
    local displayName = name:gsub(" Totem$", "")
    totemBar.nameText:SetText(displayName)
    totemBar.timeText:SetText(CB:FormatTime(remaining))

    local color = totemColors[slot]
    totemBar.bar:SetStatusBarColor(color[1], color[2], color[3], 1)

    -- Colour time text based on remaining duration
    if remaining < 5 then
        totemBar.timeText:SetTextColor(1, 0.3, 0.3, 1)
    elseif remaining < 10 then
        totemBar.timeText:SetTextColor(1, 0.8, 0.3, 1)
    else
        totemBar.timeText:SetTextColor(1, 1, 1, 1)
    end

    -- Update buff count indicator (player pips)
    if totemBar.countText then
        local buffed, total = TotemTracker:GetBuffedCount(slot, name)
        if total > 0 then
            -- Build pip string: ● for buffed, ○ for not buffed
            local pips = string.rep("●", buffed) .. string.rep("○", total - buffed)
            totemBar.countText:SetText(pips)
            -- Colour based on coverage
            if buffed == total then
                totemBar.countText:SetTextColor(0.3, 0.9, 0.3, 0.9)  -- Green - all buffed
            elseif buffed == 0 then
                totemBar.countText:SetTextColor(0.9, 0.3, 0.3, 0.9)  -- Red - none buffed
            else
                totemBar.countText:SetTextColor(1, 0.8, 0.3, 0.9)    -- Yellow - partial
            end
            totemBar.countText:Show()
        else
            totemBar.countText:Hide()
        end
    end

    totemBar:Show()
end

local function ScanTotems()
    local cfg = CastbornDB.totems

    -- Skip normal scanning during test mode
    if testModeActive then return end

    if not cfg.enabled then
        for i = 1, MAX_TOTEMS do
            if totemBars[i] then totemBars[i]:Hide() end
        end
        if CB.totemTracker then CB.totemTracker:Hide() end
        return
    end

    -- Collect active totems
    local activeTotems = {}
    for slot = 1, MAX_TOTEMS do
        local haveTotem, totemName, startTime, duration, icon = GetTotemInfo(slot)
        if haveTotem and duration > 0 then
            local remaining = (startTime + duration) - GetTime()
            table.insert(activeTotems, {
                slot = slot,
                name = totemName,
                startTime = startTime,
                duration = duration,
                icon = icon,
                remaining = remaining,
            })
        end
    end

    -- Sort by remaining time (soonest to expire first)
    table.sort(activeTotems, function(a, b)
        return a.remaining < b.remaining
    end)

    -- Display sorted totems
    for i, totem in ipairs(activeTotems) do
        if not totemBars[i] then
            totemBars[i] = CreateTotemBar(CB.totemTracker, i)
        end

        local totemBar = totemBars[i]
        totemBar.totemSlot = totem.slot  -- Store actual slot for tooltip

        local yOffset = -4 - (i - 1) * (cfg.barHeight + cfg.spacing)
        totemBar:ClearAllPoints()
        totemBar:SetPoint("TOPLEFT", CB.totemTracker, "TOPLEFT", 4, yOffset)
        totemBar:SetSize(cfg.width - 8, cfg.barHeight)

        -- Update bar positions
        totemBar.bar:ClearAllPoints()
        totemBar.bar:SetPoint("TOPLEFT", 2 + cfg.barHeight, -2)
        totemBar.bar:SetPoint("BOTTOMRIGHT", -2, 2)

        UpdateTotemBar(totemBar, totem.slot, totem.name, totem.icon, totem.startTime, totem.duration)
    end

    -- Hide unused bars
    for i = #activeTotems + 1, MAX_TOTEMS do
        if totemBars[i] then totemBars[i]:Hide() end
    end

    -- Adjust container height and visibility
    local totalHeight = math.max(30, #activeTotems * (cfg.barHeight + cfg.spacing) + 8)
    CB.totemTracker:SetHeight(totalHeight)

    if #activeTotems > 0 then
        CB.totemTracker:Show()
    else
        CB.totemTracker:Hide()
    end
end

-- Update appearance based on combat state
local function UpdateTotemTrackerAppearance()
    if not CB.totemTracker then return end
    local cfg = CastbornDB.totems
    local inCombat = UnitAffectingCombat("player")

    if CB.totemTracker.background then
        if inCombat then
            local bgColor = cfg.bgColor or { 0, 0, 0, 0.7 }
            CB.totemTracker.background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.7)
        else
            CB.totemTracker.background:SetColorTexture(0, 0, 0, 0)
        end
    end

    if CB.totemTracker.border then
        if CastbornDB.showBorders == false then
            CB.totemTracker.border:SetBackdropBorderColor(0, 0, 0, 0)
        else
            local borderColor = cfg.borderColor or { 0.3, 0.3, 0.3, 1 }
            CB.totemTracker.border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3],
                borderColor[4] or 1)
        end
    end
end

function CB:InitTotemTracker()
    -- Only initialize for Shamans
    local _, playerClass = UnitClass("player")
    if playerClass ~= "SHAMAN" then return end

    local cfg = CastbornDB.totems

    -- Ensure opacity default exists
    if cfg.opacity == nil then cfg.opacity = 1.0 end

    local frame = CreateFrame("Frame", "Castborn_TotemTracker", UIParent, "BackdropTemplate")
    frame:SetSize(cfg.width, cfg.barHeight * 4 + cfg.spacing * 3 + 8)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)

    -- Create separate background texture
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0)  -- Start transparent
    frame.background = bg

    -- Create border frame
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    if CastbornDB and CastbornDB.showBorders == false then
        border:SetBackdropBorderColor(0, 0, 0, 0)
    end
    frame.border = border

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, CastbornDB.totems or {}, function(f)
            CastbornDB.totems = CastbornDB.totems or {}
            CastbornDB.totems.anchored = false
        end, "Totem Tracker")
    else
        CB:MakeMoveable(frame, "totems")
    end

    -- Apply position only if not anchored
    if not CastbornDB.totems or CastbornDB.totems.anchored == false then
        CB:ApplyPosition(frame, "totems")
    end

    frame:Hide()
    CB.totemTracker = frame

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "PLAYER_TOTEM_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
            ScanTotems()
        elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
            UpdateTotemTrackerAppearance()
        end
    end)

    -- Periodic update for duration countdown
    CB:CreateThrottledUpdater(0.1, function()
        if CB.totemTracker and CB.totemTracker:IsShown() then
            ScanTotems()
        end
    end)

    -- Initial appearance update
    UpdateTotemTrackerAppearance()

    CB:Print("Totem Tracker initialized")
end

-- Expose function for options
CB.UpdateTotemTrackerAppearance = UpdateTotemTrackerAppearance

-- Create frame for test mode (works for any class)
local function EnsureTestFrame()
    if CB.totemTracker then return end

    local cfg = CastbornDB.totems

    local frame = CreateFrame("Frame", "Castborn_TotemTracker", UIParent, "BackdropTemplate")
    frame:SetSize(cfg.width, cfg.barHeight * 4 + cfg.spacing * 3 + 8)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0)
    frame.background = bg

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    if CastbornDB and CastbornDB.showBorders == false then
        border:SetBackdropBorderColor(0, 0, 0, 0)
    end
    frame.border = border

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, CastbornDB.totems or {}, function(f)
            CastbornDB.totems = CastbornDB.totems or {}
            CastbornDB.totems.anchored = false
        end, "Totem Tracker")
    else
        CB:MakeMoveable(frame, "totems")
    end

    if not CastbornDB.totems or CastbornDB.totems.anchored == false then
        CB:ApplyPosition(frame, "totems")
    end

    frame:Hide()
    CB.totemTracker = frame
end

-- Test mode function (works for any class)
function CB:TestTotemTracker()
    -- Ensure defaults exist
    CastbornDB.totems = Castborn:MergeDefaults(CastbornDB.totems or {}, defaults)

    -- Create frame if needed (for non-Shamans testing)
    EnsureTestFrame()

    if not CB.totemTracker then return end
    local cfg = CastbornDB.totems

    testModeActive = true
    CB.totemTracker:Show()

    -- Show drag indicator (frame was created after ShowDragIndicators was called)
    if CB.totemTracker.dragIndicator and not CastbornDB.locked then
        CB.totemTracker.dragIndicator:Show()
    end

    -- Show background for test mode
    if CB.totemTracker.background then
        local bgColor = cfg.bgColor or { 0, 0, 0, 0.7 }
        CB.totemTracker.background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.7)
    end

    -- Test totems data (realistic mid-combat scenario)
    local testTotems = {
        { slot = FIRE_TOTEM_SLOT, name = "Searing Totem", icon = "Interface\\Icons\\Spell_Fire_SearingTotem", duration = 60, remaining = 23.4 },
        { slot = EARTH_TOTEM_SLOT, name = "Strength of Earth Totem", icon = "Interface\\Icons\\Spell_Nature_EarthBindTotem", duration = 120, remaining = 87.2 },
        { slot = WATER_TOTEM_SLOT, name = "Mana Spring Totem", icon = "Interface\\Icons\\Spell_Nature_ManaRegenTotem", duration = 120, remaining = 4.1 },
        { slot = AIR_TOTEM_SLOT, name = "Windfury Totem", icon = "Interface\\Icons\\Spell_Nature_Windfury", duration = 120, remaining = 71.8 },
    }

    -- Sort by remaining time (soonest to expire first)
    table.sort(testTotems, function(a, b)
        return a.remaining < b.remaining
    end)

    for i, totem in ipairs(testTotems) do
        if not totemBars[i] then
            totemBars[i] = CreateTotemBar(CB.totemTracker, i)
        end

        local totemBar = totemBars[i]
        totemBar.totemSlot = totem.slot

        local yOffset = -4 - (i - 1) * (cfg.barHeight + cfg.spacing)
        totemBar:ClearAllPoints()
        totemBar:SetPoint("TOPLEFT", CB.totemTracker, "TOPLEFT", 4, yOffset)
        totemBar:SetSize(cfg.width - 8, cfg.barHeight)

        -- Update bar positions
        totemBar.bar:ClearAllPoints()
        totemBar.bar:SetPoint("TOPLEFT", 2 + cfg.barHeight, -2)
        totemBar.bar:SetPoint("BOTTOMRIGHT", -2, 2)

        local progress = totem.remaining / totem.duration
        totemBar.bar:SetValue(progress)
        totemBar.icon:SetTexture(totem.icon)

        local displayName = totem.name:gsub(" Totem$", "")
        totemBar.nameText:SetText(displayName)
        totemBar.timeText:SetText(string.format("%.1f", totem.remaining))

        local color = totemColors[totem.slot]
        totemBar.bar:SetStatusBarColor(color[1], color[2], color[3], 1)

        -- Colour time text
        if totem.remaining < 5 then
            totemBar.timeText:SetTextColor(1, 0.3, 0.3, 1)
        elseif totem.remaining < 10 then
            totemBar.timeText:SetTextColor(1, 0.8, 0.3, 1)
        else
            totemBar.timeText:SetTextColor(1, 1, 1, 1)
        end

        -- Update buff count indicator (player pips)
        if totemBar.countText then
            local buffed, total = TotemTracker:GetBuffedCount(totem.slot, totem.name)
            if total > 0 then
                local pips = string.rep("●", buffed) .. string.rep("○", total - buffed)
                totemBar.countText:SetText(pips)
                if buffed == total then
                    totemBar.countText:SetTextColor(0.3, 0.9, 0.3, 0.9)
                elseif buffed == 0 then
                    totemBar.countText:SetTextColor(0.9, 0.3, 0.3, 0.9)
                else
                    totemBar.countText:SetTextColor(1, 0.8, 0.3, 0.9)
                end
                totemBar.countText:Show()
            else
                totemBar.countText:Hide()
            end
        end

        totemBar:Show()
    end

    -- Adjust height
    local totalHeight = math.max(30, #testTotems * (cfg.barHeight + cfg.spacing) + 8)
    CB.totemTracker:SetHeight(totalHeight)
end

-- End test mode
function CB:EndTestTotemTracker()
    testModeActive = false
    if CB.totemTracker then
        -- Hide drag indicator
        if CB.totemTracker.dragIndicator then
            CB.totemTracker.dragIndicator:Hide()
        end
        -- Clear positioning flag so Anchoring doesn't keep it visible
        CB.totemTracker.shownForPositioning = nil

        -- Hide all totem bars first
        for i = 1, MAX_TOTEMS do
            if totemBars[i] then
                totemBars[i]:Hide()
            end
        end

        -- Hide the main frame
        CB.totemTracker:SetShown(false)
        CB.totemTracker:Hide()

        -- Reset background to transparent
        if CB.totemTracker.background then
            CB.totemTracker.background:SetColorTexture(0, 0, 0, 0)
        end
    end
end

-- Register initialization
Castborn:RegisterCallback("INIT", function()
    CastbornDB.totems = Castborn:MergeDefaults(CastbornDB.totems or {}, defaults)
end)

-- Register with TestManager and initialize
Castborn:RegisterCallback("READY", function()
    local _, playerClass = UnitClass("player")

    -- Initialize the real tracker only for Shamans
    if playerClass == "SHAMAN" then
        CB:InitTotemTracker()
    end

    -- Register test mode for ALL classes (so anyone can preview it)
    CB.TestManager:Register("TotemTracker", function() CB:TestTotemTracker() end, function() CB:EndTestTotemTracker() end)
end)

-- Respond to global border visibility toggle
Castborn:RegisterCallback("BORDERS_CHANGED", function(show)
    if CB.totemTracker and CB.totemTracker.border then
        if show then
            local cfg = CastbornDB.totems or {}
            local borderColor = cfg.borderColor or {0.3, 0.3, 0.3, 1}
            CB.totemTracker.border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
        else
            CB.totemTracker.border:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end
end)

Castborn:RegisterModule("TotemTracker", TotemTracker)

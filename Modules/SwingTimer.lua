--[[
    Castborn - Swing Timer Module
    Tracks melee and ranged auto-attack swings
]]

local CB = Castborn
CB.swingTimers = {}

local swingState = {
    mainhand = {speed = 0, startTime = 0, endTime = 0, active = false},
    offhand = {speed = 0, startTime = 0, endTime = 0, active = false},
    ranged = {speed = 0, startTime = 0, endTime = 0, active = false},
}

local testModeActive = false

local swingResetSpells = {
    ["Heroic Strike"]=true, ["Cleave"]=true, ["Slam"]=true, ["Raptor Strike"]=true, ["Maul"]=true,
    ["Sinister Strike"]=true, ["Backstab"]=true, ["Mutilate"]=true, ["Shiv"]=true,
    ["Crusader Strike"]=true, ["Stormstrike"]=true, ["Mangle (Cat)"]=true, ["Mangle (Bear)"]=true, ["Swipe"]=true,
}

local function CreateSwingBar(swingType, dbKey)
    local cfg = CB.db.swing
    local frame = CreateFrame("Frame", "Castborn_Swing_" .. swingType, UIParent)
    frame:SetSize(cfg.width, cfg.barHeight)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)
    frame.swingType = swingType
    
    CB:CreateBackdrop(frame, cfg.bgColor, cfg.borderColor)
    
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    
    if swingType == "mainhand" then bar:SetStatusBarColor(cfg.mainColor[1], cfg.mainColor[2], cfg.mainColor[3], cfg.mainColor[4])
    elseif swingType == "offhand" then bar:SetStatusBarColor(cfg.offColor[1], cfg.offColor[2], cfg.offColor[3], cfg.offColor[4])
    else bar:SetStatusBarColor(cfg.rangedColor[1], cfg.rangedColor[2], cfg.rangedColor[3], cfg.rangedColor[4]) end
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
    
    local label = bar:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\ARIALN.TTF", math.max(8, cfg.barHeight - 4), "OUTLINE")
    label:SetPoint("LEFT", bar, "LEFT", 2, 0)
    label:SetText(swingType == "mainhand" and "MH" or swingType == "offhand" and "OH" or "Ranged")
    frame.label = label
    
    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont("Fonts\\ARIALN.TTF", math.max(8, cfg.barHeight - 4), "OUTLINE")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    frame.timeText = timeText
    
    frame:Hide()
    return frame
end

local function GetWeaponSpeeds()
    local mainSpeed, offSpeed = UnitAttackSpeed("player")
    local rangedSpeed = UnitRangedDamage("player")
    return mainSpeed or 2.0, offSpeed, rangedSpeed
end

local function StartSwing(swingType)
    local mainSpeed, offSpeed, rangedSpeed = GetWeaponSpeeds()
    local speed
    if swingType == "mainhand" then speed = mainSpeed
    elseif swingType == "offhand" then speed = offSpeed if not speed then return end
    else speed = rangedSpeed if not speed or speed == 0 then return end end
    
    local state = swingState[swingType]
    state.speed = speed
    state.startTime = GetTime()
    state.endTime = GetTime() + speed
    state.active = true
end

local function ResetSwing(swingType)
    if swingState[swingType].active then StartSwing(swingType) end
end

local function UpdateSwingBar(frame, swingType)
    local cfg = CB.db.swing
    if not cfg.enabled then frame:Hide() return end
    
    local state = swingState[swingType]
    if not state.active or state.speed == 0 then frame:Hide() return end
    
    local remaining = state.endTime - GetTime()
    if remaining <= 0 then state.active = false frame:Hide() return end
    
    local progress = 1 - (remaining / state.speed)
    progress = math.max(0, math.min(1, progress))
    
    frame.bar:SetValue(progress)
    frame.spark:SetPoint("CENTER", frame.bar, "LEFT", progress * frame.bar:GetWidth(), 0)
    frame.spark:Show()
    frame.timeText:SetText(string.format("%.1f", remaining))
    frame:Show()
end

local function CreateSwingContainer()
    local cfg = CB.db.swing
    local container = CreateFrame("Frame", "Castborn_SwingContainer", UIParent)
    container:SetSize(cfg.width, cfg.barHeight * 3 + cfg.spacing * 2 + 8)
    container:SetFrameStrata("MEDIUM")
    container:SetFrameLevel(4)

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(container, CB.db.swing, nil, "Swing Timer")
    else
        CB:MakeMoveable(container, "swing")
    end
    CB:ApplyPosition(container, "swing")
    container:Hide()  -- Start hidden, will show when swings are active
    return container
end

function CB:InitSwingTimers()
    local cfg = CB.db.swing
    local container = CreateSwingContainer()
    CB.swingTimers.container = container
    
    CB.swingTimers.mainhand = CreateSwingBar("mainhand", "swing")
    CB.swingTimers.mainhand:SetParent(container)
    CB.swingTimers.mainhand:ClearAllPoints()
    CB.swingTimers.mainhand:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    
    CB.swingTimers.offhand = CreateSwingBar("offhand", "swing")
    CB.swingTimers.offhand:SetParent(container)
    CB.swingTimers.offhand:ClearAllPoints()
    CB.swingTimers.offhand:SetPoint("TOPLEFT", CB.swingTimers.mainhand, "BOTTOMLEFT", 0, -cfg.spacing)
    
    CB.swingTimers.ranged = CreateSwingBar("ranged", "swing")
    CB.swingTimers.ranged:SetParent(container)
    CB.swingTimers.ranged:ClearAllPoints()
    CB.swingTimers.ranged:SetPoint("TOPLEFT", CB.swingTimers.offhand, "BOTTOMLEFT", 0, -cfg.spacing)
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
    eventFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
    eventFrame:RegisterEvent("START_AUTOREPEAT_SPELL")
    eventFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    
    local playerGUID = UnitGUID("player")
    local autoShotting = false
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName = CombatLogGetCurrentEventInfo()
            if sourceGUID ~= playerGUID then return end

            if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
                StartSwing("mainhand")
                local _, offSpeed = GetWeaponSpeeds()
                if offSpeed and not swingState.offhand.active then StartSwing("offhand") end
            elseif subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED" then
                if autoShotting then StartSwing("ranged") end
            elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" then
                if swingResetSpells[spellName] then ResetSwing("mainhand") end
            end
        elseif event == "PLAYER_ENTER_COMBAT" then
            StartSwing("mainhand")
            local _, offSpeed = GetWeaponSpeeds()
            if offSpeed then StartSwing("offhand") end
        elseif event == "PLAYER_LEAVE_COMBAT" then
            swingState.mainhand.active = false
            swingState.offhand.active = false
        elseif event == "START_AUTOREPEAT_SPELL" then
            autoShotting = true
            StartSwing("ranged")
        elseif event == "STOP_AUTOREPEAT_SPELL" then
            autoShotting = false
            swingState.ranged.active = false
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, _, spellId = ...
            if unit == "player" then
                local spellName = GetSpellInfo(spellId)
                if spellName and swingResetSpells[spellName] then ResetSwing("mainhand") end
            end
        end
    end)
    
    CB:CreateThrottledUpdater(0.02, function()
        -- Don't override test mode display
        if testModeActive then return end

        UpdateSwingBar(CB.swingTimers.mainhand, "mainhand")
        UpdateSwingBar(CB.swingTimers.offhand, "offhand")
        UpdateSwingBar(CB.swingTimers.ranged, "ranged")
        -- Hide container if no bars are visible
        local anyVisible = (CB.swingTimers.mainhand:IsShown() or
                           CB.swingTimers.offhand:IsShown() or
                           CB.swingTimers.ranged:IsShown())
        if anyVisible then
            CB.swingTimers.container:Show()
        else
            CB.swingTimers.container:Hide()
        end
    end)
    
    CB:Print("Swing timers initialized")
end

function CB:TestSwingTimers()
    if not CB.swingTimers or not CB.swingTimers.container then return end

    testModeActive = true

    -- Show container
    CB.swingTimers.container:Show()

    -- Set up test data
    local cfg = CB.db.swing

    -- Mainhand bar
    CB.swingTimers.mainhand.bar:SetValue(0.6)
    CB.swingTimers.mainhand.spark:SetPoint("CENTER", CB.swingTimers.mainhand.bar, "LEFT", 0.6 * CB.swingTimers.mainhand.bar:GetWidth(), 0)
    CB.swingTimers.mainhand.spark:Show()
    CB.swingTimers.mainhand.timeText:SetText("1.0")
    CB.swingTimers.mainhand:Show()

    -- Offhand bar
    CB.swingTimers.offhand.bar:SetValue(0.3)
    CB.swingTimers.offhand.spark:SetPoint("CENTER", CB.swingTimers.offhand.bar, "LEFT", 0.3 * CB.swingTimers.offhand.bar:GetWidth(), 0)
    CB.swingTimers.offhand.spark:Show()
    CB.swingTimers.offhand.timeText:SetText("1.3")
    CB.swingTimers.offhand:Show()

    -- Ranged bar
    CB.swingTimers.ranged.bar:SetValue(0.8)
    CB.swingTimers.ranged.spark:SetPoint("CENTER", CB.swingTimers.ranged.bar, "LEFT", 0.8 * CB.swingTimers.ranged.bar:GetWidth(), 0)
    CB.swingTimers.ranged.spark:Show()
    CB.swingTimers.ranged.timeText:SetText("0.6")
    CB.swingTimers.ranged:Show()
end

function CB:EndTestSwingTimers()
    testModeActive = false
    if CB.swingTimers and CB.swingTimers.container then
        CB.swingTimers.container:Hide()
        if CB.swingTimers.mainhand then CB.swingTimers.mainhand:Hide() end
        if CB.swingTimers.offhand then CB.swingTimers.offhand:Hide() end
        if CB.swingTimers.ranged then CB.swingTimers.ranged:Hide() end
    end
end

-- Register with TestManager
CB:RegisterCallback("READY", function()
    CB.TestManager:Register("SwingTimer", function() CB:TestSwingTimers() end, function() CB:EndTestSwingTimers() end)
end)

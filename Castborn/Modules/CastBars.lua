--[[
    Castborn - CastBars Module
    Player, Target, Target-of-Target, and Focus castbars
]]
local CastBars = {}
Castborn.CastBars = CastBars

local CB = Castborn

-- Castbar frames storage
CB.castbars = {}

-- Test mode flag to prevent update from hiding test bars
local testModeActive = false

-- Cached player class colour
local playerClassColor = nil

-- Get the player's class colour (cached)
local function GetPlayerClassColor()
    if not playerClassColor then
        local _, class = UnitClass("player")
        if class and RAID_CLASS_COLORS[class] then
            local c = RAID_CLASS_COLORS[class]
            playerClassColor = { c.r, c.g, c.b, 1 }
        else
            playerClassColor = { 0.6, 0.6, 0.9, 1 }  -- fallback
        end
    end
    return playerClassColor
end

-- Get bar colour based on settings (class colour > global colour > individual colour)
local function GetBarColor(dbKey)
    local cfg = CB.db[dbKey]
    if CB.db.useClassColors and dbKey == "player" then
        return GetPlayerClassColor()
    end
    if CB.db.useGlobalBarColor and CB.db.globalBarColor then
        return CB.db.globalBarColor
    end
    return cfg.barColor
end

-- Create a single castbar
local function CreateCastBar(unit, dbKey)
    local cfg = CB.db[dbKey]
    
    -- Main frame
    local frame = CreateFrame("Frame", "Castborn_" .. unit, UIParent)
    frame:SetSize(cfg.width, cfg.height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(10)
    frame.unit = unit
    frame.dbKey = dbKey
    
    -- Create backdrop
    CB:CreateBackdrop(frame, cfg.bgColor, cfg.borderColor)
    
    -- Icon frame (left side) - Button for Masque compatibility
    local iconFrame = CreateFrame("Button", nil, frame)
    iconFrame:SetSize(cfg.height + 4, cfg.height + 4)
    iconFrame:SetPoint("RIGHT", frame, "LEFT", -4, 0)
    CB:CreateBackdrop(iconFrame, cfg.bgColor, cfg.borderColor)

    local icon = iconFrame:CreateTexture(nil, "BACKGROUND")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    iconFrame.Icon = icon
    frame.icon = icon
    frame.iconFrame = iconFrame

    -- Normal texture (border) for Masque
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

    -- Cooldown frame for Masque compatibility
    local iconCooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
    iconCooldown:SetAllPoints()
    iconCooldown:SetDrawEdge(false)
    iconCooldown:SetHideCountdownNumbers(true)
    iconFrame.Cooldown = iconCooldown

    if not cfg.showIcon then iconFrame:Hide() end
    
    -- Status bar
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    bar:SetStatusBarTexture(Castborn:GetBarTexture())
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local barColor = GetBarColor(dbKey)
    bar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4])
    frame.bar = bar
    Castborn:RegisterBarFrame(bar)
    
    -- Background for the bar
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    barBg:SetVertexColor(0.15, 0.15, 0.15, 0.8)
    frame.barBg = barBg
    
    -- Spark
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(20, cfg.height * 2.5)
    spark:Hide()
    frame.spark = spark
    
    -- Latency indicator (player only) - always create, show/hide based on setting
    if unit == "player" then
        local latency = bar:CreateTexture(nil, "ARTWORK", nil, 1)
        latency:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        latency:SetVertexColor(1, 0.2, 0.2, 0.6)
        latency:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        latency:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        latency:SetWidth(0)
        latency:Hide()
        frame.latency = latency
    end
    
    -- Spell name text (always create, show/hide based on setting)
    local spellText = bar:CreateFontString(nil, "OVERLAY")
    spellText:SetFont("Fonts\\ARIALN.TTF", math.max(10, cfg.height - 6), "OUTLINE")
    spellText:SetPoint("LEFT", bar, "LEFT", 4, 0)
    spellText:SetJustifyH("LEFT")
    spellText:SetTextColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
    if not cfg.showSpellName then spellText:Hide() end
    frame.spellText = spellText
    
    -- Time text - always create, show/hide based on setting
    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont("Fonts\\ARIALN.TTF", math.max(10, cfg.height - 6), "OUTLINE")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timeText:SetJustifyH("RIGHT")
    timeText:SetTextColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
    if not cfg.showTime then timeText:Hide() end
    frame.timeText = timeText
    
    -- Interruptible indicator (for enemy casts)
    if unit ~= "player" then
        local shield = bar:CreateTexture(nil, "OVERLAY")
        shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield")
        shield:SetSize(cfg.height * 1.5, cfg.height * 1.5)
        shield:SetPoint("CENTER", frame, "LEFT", 0, 0)
        shield:Hide()
        frame.shield = shield
    end
    
    -- Glow effect frame
    local glow = CreateFrame("Frame", nil, frame)
    glow:SetPoint("TOPLEFT", -3, 3)
    glow:SetPoint("BOTTOMRIGHT", 3, -3)
    glow:SetFrameLevel(frame:GetFrameLevel() - 1)
    glow:SetAlpha(0)
    
    local glowTex = glow:CreateTexture(nil, "BACKGROUND")
    glowTex:SetAllPoints()
    glowTex:SetColorTexture(1, 1, 1, 0.3)
    glowTex:SetBlendMode("ADD")
    frame.glow = glow
    frame.glowTex = glowTex
    
    -- Initialize state
    frame.casting = false
    frame.channeling = false
    frame.startTime = 0
    frame.endTime = 0
    frame.fadeOut = 0

    -- Use Anchoring system for draggable functionality (instead of MakeMoveable)
    if Castborn.Anchoring then
        -- Create readable label from unit name
        local labels = {
            player = "Player Cast",
            target = "Target Cast",
            focus = "Focus Cast",
            targettarget = "ToT Cast",
        }
        local label = labels[unit] or (unit .. " Cast")

        Castborn.Anchoring:MakeDraggable(frame, cfg, function(f)
            Castborn:FireCallback("CASTBAR_MOVED", unit)
            if unit == "player" then
                Castborn:FireCallback("PLAYER_CASTBAR_MOVED")
            end
        end, label)
    else
        -- Fallback to original MakeMoveable if Anchoring not available
        CB:MakeMoveable(frame, dbKey)
    end

    CB:ApplyPosition(frame, dbKey)

    -- Register icon with Masque if available
    if frame.iconFrame and Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:AddButton("castbar", frame.iconFrame, {
            Icon = frame.iconFrame.Icon,
            Cooldown = frame.iconFrame.Cooldown,
            Normal = frame.iconFrame.Normal,
        })
    end

    frame:Hide()

    return frame
end

-- Update castbar appearance during cast
local function UpdateCastBar(frame, elapsed)
    -- Don't update during test mode (let test values persist)
    if testModeActive then return end

    if frame.fadeOut > 0 then
        frame.fadeOut = frame.fadeOut - elapsed
        local alpha = math.max(0, frame.fadeOut / 0.3)
        frame:SetAlpha(alpha)
        if frame.fadeOut <= 0 then
            frame:Hide()
            frame:SetAlpha(1)
        end
        return
    end
    
    local currentTime = GetTime()
    local cfg = CB.db[frame.dbKey]
    
    if frame.casting then
        local progress = (currentTime - frame.startTime) / (frame.endTime - frame.startTime)
        progress = math.max(0, math.min(1, progress))
        frame.bar:SetValue(progress)
        
        local sparkPos = progress * frame.bar:GetWidth()
        frame.spark:SetPoint("CENTER", frame.bar, "LEFT", sparkPos, 0)
        frame.spark:Show()
        
        if frame.timeText then
            if cfg.showTime then
                local remaining = frame.endTime - currentTime
                frame.timeText:SetText(CB:FormatTime(math.max(0, remaining)))
                frame.timeText:Show()
            else
                frame.timeText:Hide()
            end
        end

        if currentTime >= frame.endTime then
            frame.casting = false
            frame.fadeOut = 0.3
            frame.spark:Hide()
            frame.bar:SetValue(1)
            frame.bar:SetStatusBarColor(0.3, 0.9, 0.3, 1)  -- Success colour
            if frame.latency then frame.latency:Hide() end
            if frame.shield then frame.shield:Hide() end
        end

    elseif frame.channeling then
        local progress = (frame.endTime - currentTime) / (frame.endTime - frame.startTime)
        progress = math.max(0, math.min(1, progress))
        frame.bar:SetValue(progress)
        
        local sparkPos = progress * frame.bar:GetWidth()
        frame.spark:SetPoint("CENTER", frame.bar, "LEFT", sparkPos, 0)
        frame.spark:Show()
        
        if frame.timeText then
            if cfg.showTime then
                local remaining = frame.endTime - currentTime
                frame.timeText:SetText(CB:FormatTime(math.max(0, remaining)))
                frame.timeText:Show()
            else
                frame.timeText:Hide()
            end
        end

        if currentTime >= frame.endTime then
            frame.channeling = false
            frame.fadeOut = 0.3
            frame.spark:Hide()
            frame.bar:SetStatusBarColor(0.3, 0.9, 0.3, 1)  -- Success colour
            if frame.latency then frame.latency:Hide() end
            if frame.shield then frame.shield:Hide() end
        end
    end
end

local function StartCast(frame, unit)
    local cfg = CB.db[frame.dbKey]
    if not cfg.enabled then return end

    -- Skip self-casts on non-player castbars (e.g., when target/focus is the player)
    if unit ~= "player" and UnitIsUnit(unit, "player") then return end

    -- Skip ToT castbar when target is self-targeting (redundant with target castbar)
    if unit == "targettarget" and UnitIsUnit("targettarget", "target") then return end

    local name, text, texture, startTime, endTime, isTradeSkill, _, notInterruptible, spellID = UnitCastingInfo(unit)

    if not name then return end

    -- Skip tradeskill casts (crafting) if option is enabled
    if isTradeSkill and cfg.hideTradeSkills then return end

    frame.casting = true
    frame.channeling = false
    frame.startTime = startTime / 1000
    frame.endTime = endTime / 1000
    frame.fadeOut = 0

    local barColor = GetBarColor(frame.dbKey)
    frame.bar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4])

    -- Show/hide icon based on setting
    if frame.iconFrame then
        if cfg.showIcon then
            frame.icon:SetTexture(texture)
            frame.iconFrame:Show()
        else
            frame.iconFrame:Hide()
        end
    end

    -- Show/hide spell name based on setting
    if frame.spellText then
        if cfg.showSpellName then
            local displayName = text or name
            -- Add rank if enabled and spellID available
            if cfg.showSpellRank and spellID then
                -- Try GetSpellSubtext first (TBC), fall back to GetSpellInfo
                local rank
                if GetSpellSubtext then
                    rank = GetSpellSubtext(spellID)
                end
                if not rank or rank == "" then
                    local _, r = GetSpellInfo(spellID)
                    rank = r
                end
                if rank and rank ~= "" then
                    -- Format as "Rank X" if it's just a number
                    if tonumber(rank) then
                        rank = "Rank " .. rank
                    end
                    displayName = displayName .. " (" .. rank .. ")"
                end
            end
            frame.spellText:SetText(displayName)
            frame.spellText:Show()
        else
            frame.spellText:Hide()
        end
    end

    -- Show/hide latency based on setting
    if frame.latency and unit == "player" then
        if cfg.showLatency then
            local _, _, lagHome, lagWorld = GetNetStats()
            local lag = (lagHome + lagWorld) / 1000
            local barWidth = frame.bar:GetWidth()
            local lagWidth = math.min(lag / (frame.endTime - frame.startTime) * barWidth, barWidth * 0.5)
            frame.latency:SetWidth(lagWidth)
            frame.latency:Show()
        else
            frame.latency:Hide()
        end
    end

    if frame.shield then
        if notInterruptible then
            frame.shield:Show()
            frame.bar:SetStatusBarColor(barColor[1] * 0.6, barColor[2] * 0.6, barColor[3] * 0.6, barColor[4])
        else
            frame.shield:Hide()
        end
    end
    
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(0)
    frame:SetAlpha(1)
    frame:Show()
end

local function StartChannel(frame, unit)
    local cfg = CB.db[frame.dbKey]
    if not cfg.enabled then return end

    -- Skip self-casts on non-player castbars (e.g., when target/focus is the player)
    if unit ~= "player" and UnitIsUnit(unit, "player") then return end

    -- Skip ToT castbar when target is self-targeting (redundant with target castbar)
    if unit == "targettarget" and UnitIsUnit("targettarget", "target") then return end

    local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unit)

    if not name then return end

    -- Skip tradeskill channels (crafting) if option is enabled
    if isTradeSkill and cfg.hideTradeSkills then return end

    frame.casting = false
    frame.channeling = true
    frame.startTime = startTime / 1000
    frame.endTime = endTime / 1000
    frame.fadeOut = 0

    local barColor = GetBarColor(frame.dbKey)
    frame.bar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4])

    -- Show/hide icon based on setting
    if frame.iconFrame then
        if cfg.showIcon then
            frame.icon:SetTexture(texture)
            frame.iconFrame:Show()
        else
            frame.iconFrame:Hide()
        end
    end

    -- Show/hide spell name based on setting
    if frame.spellText then
        if cfg.showSpellName then
            local displayName = text or name
            -- Add rank if enabled and spellID available
            if cfg.showSpellRank and spellID then
                -- Try GetSpellSubtext first (TBC), fall back to GetSpellInfo
                local rank
                if GetSpellSubtext then
                    rank = GetSpellSubtext(spellID)
                end
                if not rank or rank == "" then
                    local _, r = GetSpellInfo(spellID)
                    rank = r
                end
                if rank and rank ~= "" then
                    -- Format as "Rank X" if it's just a number
                    if tonumber(rank) then
                        rank = "Rank " .. rank
                    end
                    displayName = displayName .. " (" .. rank .. ")"
                end
            end
            frame.spellText:SetText(displayName)
            frame.spellText:Show()
        else
            frame.spellText:Hide()
        end
    end

    -- Hide latency for channels
    if frame.latency then frame.latency:Hide() end

    if frame.shield then
        if notInterruptible then
            frame.shield:Show()
            frame.bar:SetStatusBarColor(barColor[1] * 0.6, barColor[2] * 0.6, barColor[3] * 0.6, barColor[4])
        else
            frame.shield:Hide()
        end
    end
    
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(1)
    frame:SetAlpha(1)
    frame:Show()
end

local function StopCast(frame, success)
    if not frame.casting and not frame.channeling then return end
    
    frame.casting = false
    frame.channeling = false
    frame.spark:Hide()
    if frame.latency then frame.latency:Hide() end
    if frame.shield then frame.shield:Hide() end
    
    if success then
        frame.bar:SetValue(1)
        frame.bar:SetStatusBarColor(0.3, 0.9, 0.3, 1)
    else
        frame.bar:SetStatusBarColor(0.9, 0.2, 0.2, 1)
    end
    
    frame.fadeOut = 0.3
end

local function CheckUnitCast(frame, unit)
    -- Don't check during test mode (let test values persist)
    if testModeActive then return end

    local cfg = CB.db[frame.dbKey]
    if not cfg.enabled then
        frame:Hide()
        return
    end

    if not UnitExists(unit) then
        frame:Hide()
        frame.casting = false
        frame.channeling = false
        return
    end

    -- Skip self-casts on non-player castbars (e.g., when target/focus is the player)
    if unit ~= "player" and UnitIsUnit(unit, "player") then
        frame:Hide()
        frame.casting = false
        frame.channeling = false
        return
    end

    -- Skip ToT castbar when target is self-targeting (redundant with target castbar)
    if unit == "targettarget" and UnitIsUnit("targettarget", "target") then
        frame:Hide()
        frame.casting = false
        frame.channeling = false
        return
    end

    local name = UnitCastingInfo(unit)
    local channelName = UnitChannelInfo(unit)

    if name and not frame.casting then
        StartCast(frame, unit)
    elseif channelName and not frame.channeling then
        StartChannel(frame, unit)
    elseif not name and not channelName then
        if frame.casting or frame.channeling then
            StopCast(frame, true)
        elseif frame.fadeOut <= 0 and frame:IsShown() then
            -- Safety: bar is visible but no cast active and not fading out - hide it
            frame:Hide()
        end
    end
end

function CB:InitCastBars()
    CB.castbars.player = CreateCastBar("player", "player")
    CB.castbars.target = CreateCastBar("target", "target")
    CB.castbars.targettarget = CreateCastBar("targettarget", "targettarget")
    CB.castbars.focus = CreateCastBar("focus", "focus")

    -- Hide the default Blizzard castbar if setting is enabled
    if CB.db.player and CB.db.player.hideBlizzardCastBar then
        CB:HideBlizzardCastBar(true)  -- silent on init
    end

    -- Fire callback so GCD and 5SR modules can anchor to the player castbar
    Castborn:FireCallback("PLAYER_CASTBAR_CREATED", CB.castbars.player)
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")

    eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            CB.castbars.target.casting = false
            CB.castbars.target.channeling = false
            CB.castbars.target:Hide()
            CB.castbars.targettarget.casting = false
            CB.castbars.targettarget.channeling = false
            CB.castbars.targettarget:Hide()
            CheckUnitCast(CB.castbars.target, "target")
            CheckUnitCast(CB.castbars.targettarget, "targettarget")
            return
        elseif event == "PLAYER_FOCUS_CHANGED" then
            CB.castbars.focus.casting = false
            CB.castbars.focus.channeling = false
            CB.castbars.focus:Hide()
            CheckUnitCast(CB.castbars.focus, "focus")
            return
        end
        
        local frame
        if unit == "player" then frame = CB.castbars.player
        elseif unit == "target" then frame = CB.castbars.target
        elseif unit == "targettarget" then frame = CB.castbars.targettarget
        elseif unit == "focus" then frame = CB.castbars.focus
        else return end

        if event == "UNIT_SPELLCAST_START" then
            StartCast(frame, unit)
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then StartChannel(frame, unit)
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then StopCast(frame, true)
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then StopCast(frame, false)
        elseif event == "UNIT_SPELLCAST_DELAYED" then
            if frame.casting then
                local name, text, texture, startTime, endTime = UnitCastingInfo(unit)
                if name then
                    frame.startTime = startTime / 1000
                    frame.endTime = endTime / 1000
                end
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            if frame.channeling then
                local name, text, texture, startTime, endTime = UnitChannelInfo(unit)
                if name then
                    frame.startTime = startTime / 1000
                    frame.endTime = endTime / 1000
                end
            end
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            if frame.shield then
                frame.shield[event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" and "Show" or "Hide"](frame.shield)
            end
        end
    end)
    
    local updateFrame = CreateFrame("Frame")
    local timeSinceLastUpdate = 0
    
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        timeSinceLastUpdate = timeSinceLastUpdate + elapsed
        if timeSinceLastUpdate >= 0.01 then
            if CB.castbars.player:IsShown() then UpdateCastBar(CB.castbars.player, timeSinceLastUpdate) end
            if CB.castbars.target:IsShown() then UpdateCastBar(CB.castbars.target, timeSinceLastUpdate) end
            if CB.castbars.targettarget:IsShown() then UpdateCastBar(CB.castbars.targettarget, timeSinceLastUpdate) end
            if CB.castbars.focus:IsShown() then UpdateCastBar(CB.castbars.focus, timeSinceLastUpdate) end
            CheckUnitCast(CB.castbars.player, "player")
            CheckUnitCast(CB.castbars.target, "target")
            CheckUnitCast(CB.castbars.targettarget, "targettarget")
            CheckUnitCast(CB.castbars.focus, "focus")
            timeSinceLastUpdate = 0
        end
    end)
    
    CB:Print("Castbars initialized")
end

-- Hide the default Blizzard castbar
function CB:HideBlizzardCastBar(silent)
    -- Try different names used across WoW versions
    local blizzardCastBars = {
        "CastingBarFrame",           -- Classic/TBC
        "PlayerCastingBarFrame",     -- Retail
        "PetCastingBarFrame",        -- Pet castbar
    }

    for _, frameName in ipairs(blizzardCastBars) do
        local frame = _G[frameName]
        if frame then
            frame:UnregisterAllEvents()
            frame:Hide()
            frame:SetScript("OnShow", function(self) self:Hide() end)
        end
    end

    if not silent then
        CB:Print("Default Blizzard castbar hidden")
    end
end

-- Restore the default Blizzard castbar (if needed)
function CB:ShowBlizzardCastBar()
    local frame = _G["CastingBarFrame"] or _G["PlayerCastingBarFrame"]
    if frame then
        frame:SetScript("OnShow", nil)
        -- Re-register events would require knowing original events
        -- For now, just recommend /reload to restore
        CB:Print("Reload UI to fully restore Blizzard castbar (/reload)")
    end
end

-- Refresh castbar colours (called when class colours setting changes)
function CB:RefreshCastbarColors()
    if not CB.castbars then return end
    for dbKey, frame in pairs(CB.castbars) do
        if frame and frame.bar then
            local barColor = GetBarColor(dbKey)
            frame.bar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4])
        end
    end
end

-- Enter test mode for castbars
function CB:TestCastbars()
    testModeActive = true
end

-- End test mode for castbars
function CB:EndTestCastbars()
    testModeActive = false
    -- Hide all castbars when ending test mode
    if CB.castbars then
        for _, frame in pairs(CB.castbars) do
            if frame then
                frame.casting = false
                frame.channeling = false
                frame.fadeOut = 0
                frame:Hide()
            end
        end
    end
end

-- Register with TestManager
CB:RegisterCallback("READY", function()
    CB.TestManager:Register("CastBars", function() CB:TestCastbars() end, function() CB:EndTestCastbars() end)
end)

Castborn:RegisterModule("CastBars", CastBars)

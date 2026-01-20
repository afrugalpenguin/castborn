--[[
    Castborn - DoT Tracker Module
    Tracks debuffs/DoTs on target
]]

local CB = Castborn
CB.dotTracker = nil

local dotBars = {}
local MAX_DOTS = 10

local schoolColors = {
    ["Physical"] = {0.7, 0.7, 0.7}, ["Holy"] = {1.0, 0.9, 0.5}, ["Fire"] = {1.0, 0.4, 0.1},
    ["Nature"] = {0.3, 0.9, 0.3}, ["Frost"] = {0.4, 0.7, 1.0}, ["Shadow"] = {0.6, 0.3, 0.8}, ["Arcane"] = {0.9, 0.6, 1.0},
}

local dotSpellColors = {
    ["Corruption"] = schoolColors["Shadow"], ["Curse of Agony"] = schoolColors["Shadow"],
    ["Curse of Doom"] = schoolColors["Shadow"], ["Immolate"] = schoolColors["Fire"],
    ["Siphon Life"] = schoolColors["Shadow"], ["Unstable Affliction"] = schoolColors["Shadow"],
    ["Shadow Word: Pain"] = schoolColors["Shadow"], ["Devouring Plague"] = schoolColors["Shadow"],
    ["Vampiric Touch"] = schoolColors["Shadow"], ["Moonfire"] = schoolColors["Arcane"],
    ["Insect Swarm"] = schoolColors["Nature"], ["Rake"] = {0.9, 0.7, 0.3}, ["Rip"] = {0.9, 0.7, 0.3},
    ["Serpent Sting"] = schoolColors["Nature"], ["Rupture"] = {0.9, 0.7, 0.3},
    -- Mage CC
    ["Polymorph"] = schoolColors["Arcane"], ["Polymorph: Turtle"] = schoolColors["Arcane"],
    ["Polymorph: Pig"] = schoolColors["Arcane"],
}

local function CreateDotBar(parent, index)
    local cfg = CB.db.dots
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(cfg.width - 8, cfg.barHeight)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4 - (index - 1) * (cfg.barHeight + cfg.spacing))
    
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
    
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 2 + cfg.barHeight, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    frame.bar = bar
    
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    barBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    
    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame:SetSize(cfg.barHeight - 2, cfg.barHeight - 2)
    iconFrame:SetPoint("LEFT", frame, "LEFT", 2, 0)
    
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.icon = icon
    
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
    
    local stackText = iconFrame:CreateFontString(nil, "OVERLAY")
    stackText:SetFont("Fonts\\ARIALN.TTF", cfg.barHeight - 4, "OUTLINE")
    stackText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 2, -2)
    frame.stackText = stackText
    
    frame:Hide()
    return frame
end

local function GetDotColor(name, debuffType)
    if dotSpellColors[name] then return unpack(dotSpellColors[name]) end
    if debuffType == "Magic" then return 0.2, 0.6, 1.0
    elseif debuffType == "Curse" then return 0.6, 0.0, 1.0
    elseif debuffType == "Disease" then return 0.6, 0.4, 0.0
    elseif debuffType == "Poison" then return 0.0, 0.6, 0.0 end
    return 0.8, 0.3, 0.3
end

local function UpdateDotBar(dotBar, name, icon, count, debuffType, duration, expirationTime)
    local remaining = expirationTime - GetTime()
    local progress = duration > 0 and (remaining / duration) or 1
    progress = math.max(0, math.min(1, progress))
    
    dotBar.bar:SetValue(progress)
    dotBar.icon:SetTexture(icon)
    dotBar.nameText:SetText(name)
    dotBar.timeText:SetText(CB:FormatTime(remaining))
    dotBar.stackText:SetText(count and count > 1 and count or "")
    
    local r, g, b = GetDotColor(name, debuffType)
    dotBar.bar:SetStatusBarColor(r, g, b, 1)
    
    if remaining < 3 then dotBar.timeText:SetTextColor(1, 0.3, 0.3, 1)
    elseif remaining < 5 then dotBar.timeText:SetTextColor(1, 0.8, 0.3, 1)
    else dotBar.timeText:SetTextColor(1, 1, 1, 1) end
    
    dotBar:Show()
end

-- Test mode flag
local testModeActive = false
local testModeExpires = 0

local function ScanDebuffs()
    local cfg = CB.db.dots

    -- Skip normal scanning during test mode
    if testModeActive and GetTime() < testModeExpires then
        return
    elseif testModeActive then
        testModeActive = false  -- Test mode expired
    end

    if not cfg.enabled or not UnitExists("target") then
        for i = 1, MAX_DOTS do if dotBars[i] then dotBars[i]:Hide() end end
        return
    end
    
    local dotIndex = 1
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source = UnitDebuff("target", i)
        if not name then break end
        
        local isOurs = source == "player"
        if (not cfg.showOnlyMine or isOurs) and duration and duration > 0 then
            if not dotBars[dotIndex] then dotBars[dotIndex] = CreateDotBar(CB.dotTracker, dotIndex) end
            
            local yOffset = -4 - (dotIndex - 1) * (cfg.barHeight + cfg.spacing)
            dotBars[dotIndex]:ClearAllPoints()
            dotBars[dotIndex]:SetPoint("TOPLEFT", CB.dotTracker, "TOPLEFT", 4, yOffset)
            dotBars[dotIndex]:SetSize(cfg.width - 8, cfg.barHeight)
            
            UpdateDotBar(dotBars[dotIndex], name, icon, count, debuffType, duration, expirationTime)
            dotIndex = dotIndex + 1
            if dotIndex > MAX_DOTS then break end
        end
    end
    
    for i = dotIndex, MAX_DOTS do if dotBars[i] then dotBars[i]:Hide() end end
    
    local totalHeight = math.max(30, (dotIndex - 1) * (cfg.barHeight + cfg.spacing) + 8)
    CB.dotTracker:SetHeight(totalHeight)
    CB.dotTracker[dotIndex > 1 and "Show" or "Hide"](CB.dotTracker)
end

-- Update DoT tracker appearance based on combat state
local function UpdateDoTTrackerAppearance()
    if not CB.dotTracker then return end
    local cfg = CB.db.dots
    local inCombat = UnitAffectingCombat("player")
    local opacity = cfg.opacity or 1.0

    if CB.dotTracker.background then
        if inCombat then
            -- Show background in combat with user opacity
            local bgColor = cfg.bgColor or {0, 0, 0, 0.7}
            CB.dotTracker.background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], (bgColor[4] or 0.7) * opacity)
        else
            -- Hide background out of combat
            CB.dotTracker.background:SetColorTexture(0, 0, 0, 0)
        end
    end

    -- Border always visible with opacity
    if CB.dotTracker.border then
        local borderColor = cfg.borderColor or {0.3, 0.3, 0.3, 1}
        CB.dotTracker.border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * opacity)
    end
end

function CB:InitDoTTracker()
    local cfg = CB.db.dots

    -- Ensure opacity default exists
    if cfg.opacity == nil then cfg.opacity = 1.0 end

    local frame = CreateFrame("Frame", "Castborn_DoTTracker", UIParent, "BackdropTemplate")
    frame:SetSize(cfg.width, cfg.height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)

    -- Create separate background texture (so we can hide it independently)
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
    frame.border = border

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, CastbornDB.dots or {}, function(f)
            CastbornDB.dots = CastbornDB.dots or {}
            CastbornDB.dots.anchored = false
        end, "DoT Tracker")
    else
        CB:MakeMoveable(frame, "dots")
    end

    -- Apply position only if not anchored
    if not CastbornDB.dots or CastbornDB.dots.anchored == false then
        CB:ApplyPosition(frame, "dots")
    end
    frame:Hide()
    CB.dotTracker = frame

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Left combat
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entered combat
    eventFrame:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_AURA" and unit == "target") then
            ScanDebuffs()
        elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
            UpdateDoTTrackerAppearance()
        end
    end)

    CB:CreateThrottledUpdater(0.05, function()
        if CB.dotTracker:IsShown() then ScanDebuffs() end
    end)

    -- Initial appearance update
    UpdateDoTTrackerAppearance()

    CB:Print("DoT Tracker initialized")
end

-- Expose function for options to call when opacity changes
CB.UpdateDoTTrackerAppearance = UpdateDoTTrackerAppearance

-- Test mode function
function CB:TestDoTTracker()
    if not CB.dotTracker then return end
    local cfg = CB.db.dots
    -- Show even if disabled for test mode

    -- Set test mode flag to prevent normal updates from overwriting
    testModeActive = true
    testModeExpires = GetTime() + 99  -- 99 seconds like other test modes

    CB.dotTracker:Show()

    -- Show background for test mode
    if CB.dotTracker.background then
        local bgColor = cfg.bgColor or {0, 0, 0, 0.7}
        CB.dotTracker.background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.7)
    end

    -- Class-specific test DoTs
    local _, playerClass = UnitClass("player")
    local testDoTs = {}

    if playerClass == "MAGE" then
        testDoTs = {
            { name = "Fireball", icon = "Interface\\Icons\\Spell_Fire_FlameBolt", duration = 8, remaining = 5.2, color = {1.0, 0.4, 0.1} },
            { name = "Frostbolt", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02", duration = 9, remaining = 7.1, color = {0.4, 0.7, 1.0} },
            { name = "Polymorph", icon = "Interface\\Icons\\Spell_Nature_Polymorph", duration = 50, remaining = 42.3, color = {0.9, 0.6, 1.0} },
        }
    elseif playerClass == "WARLOCK" then
        testDoTs = {
            { name = "Corruption", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", duration = 18, remaining = 12.5, color = {0.6, 0.3, 0.8} },
            { name = "Immolate", icon = "Interface\\Icons\\Spell_Fire_Immolation", duration = 15, remaining = 8.2, color = {1.0, 0.4, 0.1} },
            { name = "Curse of Agony", icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", duration = 24, remaining = 3.1, color = {0.6, 0.3, 0.8} },
        }
    elseif playerClass == "PRIEST" then
        testDoTs = {
            { name = "Shadow Word: Pain", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", duration = 18, remaining = 11.4, color = {0.6, 0.3, 0.8} },
            { name = "Devouring Plague", icon = "Interface\\Icons\\Spell_Shadow_DevouringPlague", duration = 24, remaining = 18.7, color = {0.6, 0.3, 0.8} },
            { name = "Vampiric Touch", icon = "Interface\\Icons\\Spell_Holy_Stoicism", duration = 15, remaining = 4.2, color = {0.6, 0.3, 0.8} },
        }
    elseif playerClass == "DRUID" then
        testDoTs = {
            { name = "Moonfire", icon = "Interface\\Icons\\Spell_Nature_StarFall", duration = 12, remaining = 8.3, color = {0.9, 0.6, 1.0} },
            { name = "Insect Swarm", icon = "Interface\\Icons\\Spell_Nature_InsectSwarm", duration = 12, remaining = 5.1, color = {0.3, 0.9, 0.3} },
            { name = "Rake", icon = "Interface\\Icons\\Ability_Druid_Disembowel", duration = 9, remaining = 2.8, color = {0.9, 0.7, 0.3} },
        }
    elseif playerClass == "HUNTER" then
        testDoTs = {
            { name = "Serpent Sting", icon = "Interface\\Icons\\Ability_Hunter_Quickshot", duration = 15, remaining = 9.6, color = {0.3, 0.9, 0.3} },
            { name = "Hunter's Mark", icon = "Interface\\Icons\\Ability_Hunter_SniperShot", duration = 120, remaining = 95.2, color = {0.8, 0.3, 0.3} },
        }
    elseif playerClass == "ROGUE" then
        testDoTs = {
            { name = "Rupture", icon = "Interface\\Icons\\Ability_Rogue_Rupture", duration = 16, remaining = 11.4, color = {0.9, 0.7, 0.3} },
            { name = "Garrote", icon = "Interface\\Icons\\Ability_Rogue_Garrote", duration = 18, remaining = 6.2, color = {0.9, 0.7, 0.3} },
            { name = "Deadly Poison", icon = "Interface\\Icons\\Ability_Rogue_DualWeild", duration = 12, remaining = 3.1, color = {0.3, 0.9, 0.3} },
        }
    else
        -- Default/generic DoTs for other classes
        testDoTs = {
            { name = "Debuff 1", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", duration = 18, remaining = 12.5, color = {0.6, 0.3, 0.8} },
            { name = "Debuff 2", icon = "Interface\\Icons\\Spell_Fire_Immolation", duration = 15, remaining = 8.2, color = {1.0, 0.4, 0.1} },
            { name = "Debuff 3", icon = "Interface\\Icons\\Spell_Nature_Polymorph", duration = 24, remaining = 3.1, color = {0.9, 0.6, 1.0} },
        }
    end

    for i, dot in ipairs(testDoTs) do
        if not dotBars[i] then
            dotBars[i] = CreateDotBar(CB.dotTracker, i)
        end

        local dotBar = dotBars[i]
        local yOffset = -4 - (i - 1) * (cfg.barHeight + cfg.spacing)
        dotBar:ClearAllPoints()
        dotBar:SetPoint("TOPLEFT", CB.dotTracker, "TOPLEFT", 4, yOffset)
        dotBar:SetSize(cfg.width - 8, cfg.barHeight)

        local progress = dot.remaining / dot.duration
        dotBar.bar:SetValue(progress)
        dotBar.icon:SetTexture(dot.icon)
        dotBar.nameText:SetText(dot.name)
        dotBar.timeText:SetText(string.format("%.1f", dot.remaining))
        dotBar.stackText:SetText("")
        dotBar.bar:SetStatusBarColor(dot.color[1], dot.color[2], dot.color[3], 1)

        -- Color time text based on remaining
        if dot.remaining < 3 then
            dotBar.timeText:SetTextColor(1, 0.3, 0.3, 1)
        elseif dot.remaining < 5 then
            dotBar.timeText:SetTextColor(1, 0.8, 0.3, 1)
        else
            dotBar.timeText:SetTextColor(1, 1, 1, 1)
        end

        dotBar:Show()
    end

    -- Hide remaining bars
    for i = #testDoTs + 1, MAX_DOTS do
        if dotBars[i] then dotBars[i]:Hide() end
    end

    -- Adjust height
    local totalHeight = math.max(30, #testDoTs * (cfg.barHeight + cfg.spacing) + 8)
    CB.dotTracker:SetHeight(totalHeight)
end

-- End test mode
function CB:EndTestDoTTracker()
    testModeActive = false
    if CB.dotTracker then
        CB.dotTracker:Hide()
        -- Hide all dot bars
        for i = 1, MAX_DOTS do
            if dotBars[i] then dotBars[i]:Hide() end
        end
    end
end

-- Register with TestManager
CB:RegisterCallback("READY", function()
    CB.TestManager:Register("DoTTracker", function() CB:TestDoTTracker() end, function() CB:EndTestDoTTracker() end)

    -- If player castbar already exists and we should be anchored, attach now
    local cfg = CastbornDB.dots
    if cfg and cfg.anchored ~= false and Castborn.Anchoring then
        local playerCastbar = CB.castbars and CB.castbars.player
        if playerCastbar then
            Castborn.Anchoring:ReattachToCastbar(CB.dotTracker, CastbornDB.dots, "BOTTOM", -2)
        end
    end
end)

-- Listen for player castbar creation
CB:RegisterCallback("PLAYER_CASTBAR_READY", function(frame)
    -- Anchor BELOW the player castbar if configured
    if CB.dotTracker and CastbornDB.dots and CastbornDB.dots.anchored ~= false and Castborn.Anchoring then
        Castborn.Anchoring:ReattachToCastbar(CB.dotTracker, CastbornDB.dots, "BOTTOM", -2)
    end
end)

-- Detach DoT tracker from castbar
CB:RegisterCallback("DETACH_DOTS", function()
    if not CB.dotTracker then return end
    if Castborn.Anchoring then
        Castborn.Anchoring:DetachFromCastbar(CB.dotTracker, CastbornDB.dots)
    end
    CB:Print("DoT Tracker detached from castbar")
end)

-- Reattach DoT tracker to castbar
CB:RegisterCallback("REATTACH_DOTS", function()
    if not CB.dotTracker then return end
    if Castborn.Anchoring then
        Castborn.Anchoring:ReattachToCastbar(CB.dotTracker, CastbornDB.dots, "BOTTOM", -2)
    end
    CB:Print("DoT Tracker anchored to castbar")
end)

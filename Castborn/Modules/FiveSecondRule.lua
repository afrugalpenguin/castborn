--[[
    Castborn - Five Second Rule Module
    Tracks the 5-second mana regeneration rule
    Displays as a thin pulse line ABOVE the player castbar
]]

local FiveSecondRule = {}
Castborn.FiveSecondRule = FiveSecondRule

local CB = Castborn
CB.fsrFrame = nil

-- Reference to the player castbar for anchoring
local playerCastbar = nil

local lastManaSpend = 0
local FSR_DURATION = 5.0
local previousMana = 0
local POWER_MANA = 0

-- Track if we were previously in regen (for pulse triggering)
local wasInRegen = false
local testModeActive = false

-- Forward declare for UpdateFSR to check

local function PlayerUsesMana()
    local _, class = UnitClass("player")
    local manaClasses = {PRIEST=true, MAGE=true, WARLOCK=true, DRUID=true, PALADIN=true, SHAMAN=true, HUNTER=true}
    return manaClasses[class]
end

-- Pulse glow effect when entering regen state
local function PulseRegen(frame)
    if not frame or not frame.glow then return end
    local elapsed = 0
    frame.glow:SetVertexColor(0.2, 0.8, 0.4, 1)  -- Green glow
    frame.glow:SetAlpha(0.5)
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local alpha = math.sin(elapsed * 4) * 0.3 + 0.2
        alpha = math.max(0, math.min(1, alpha))  -- Clamp to valid range
        frame.glow:SetAlpha(alpha)
        if elapsed > 1 then
            frame:SetScript("OnUpdate", nil)
            frame.glow:SetAlpha(0)
        end
    end)
end

local function CreateFSRBar()
    local cfg = CB.db.fsr

    -- Make the bar thinner - default 4px height
    local height = cfg.height or 4
    -- Width will be set to match castbar when anchored, or use config/default
    local width = cfg.width or 250

    local frame = CreateFrame("Frame", "Castborn_FSR", UIParent)
    frame:SetSize(width, height)

    -- Store reference for width syncing
    frame.defaultWidth = width
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)

    -- Use shared backdrop creation (matching GCD style)
    CB:CreateBackdrop(frame, {0.05, 0.05, 0.05, 0.7}, cfg.borderColor or {0.3, 0.3, 0.3, 1})

    -- Status bar (inset by 1px like GCD)
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, FSR_DURATION)
    bar:SetValue(0)
    bar:SetStatusBarColor(cfg.regenColor[1], cfg.regenColor[2], cfg.regenColor[3], cfg.regenColor[4])
    frame.bar = bar

    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(12, height * 2)
    spark:Hide()
    frame.spark = spark

    -- Add a glow overlay texture for pulse effect
    frame.glow = frame:CreateTexture(nil, "OVERLAY")
    frame.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.glow:SetBlendMode("ADD")
    frame.glow:SetAllPoints()
    frame.glow:SetAlpha(0)

    -- Time text (smaller for thin bar, or hide if bar is very thin)
    local timeText = bar:CreateFontString(nil, "OVERLAY")
    local fontSize = math.max(8, height - 2)
    if height <= 6 then fontSize = 0 end  -- Hide text on very thin bars
    if fontSize > 0 then
        timeText:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
        timeText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    end
    frame.timeText = timeText


    -- Use Anchoring system if available, otherwise use old moveable system
    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, CastbornDB.fsr or {}, function(f)
            -- On drag stop, mark as detached
            CastbornDB.fsr = CastbornDB.fsr or {}
            CastbornDB.fsr.anchored = false
        end, "5 Second Rule")
    else
        CB:MakeMoveable(frame, "fsr")
    end

    -- Apply position if not anchored to castbar
    if not CastbornDB.fsr or CastbornDB.fsr.anchored == false then
        CB:ApplyPosition(frame, "fsr")
    end

    return frame
end

local function UpdateFSR()
    -- Don't override test mode display
    if testModeActive then return end

    local frame = CB.fsrFrame
    local cfg = CB.db.fsr

    if not cfg.enabled or not PlayerUsesMana() then frame:Hide() return end

    -- Hide out of combat (unless tutorial is active)
    local tutorialActive = Castborn.Tutorial and Castborn.Tutorial:IsActive()
    if not UnitAffectingCombat("player") and not tutorialActive then frame:Hide() return end

    local elapsed = GetTime() - lastManaSpend
    local isInRegen = elapsed >= FSR_DURATION

    if elapsed < FSR_DURATION then
        local remaining = FSR_DURATION - elapsed
        frame.bar:SetValue(remaining)
        frame.bar:SetStatusBarColor(cfg.activeColor[1], cfg.activeColor[2], cfg.activeColor[3], cfg.activeColor[4])

        local progress = remaining / FSR_DURATION
        frame.spark:SetPoint("CENTER", frame.bar, "LEFT", progress * frame.bar:GetWidth(), 0)
        frame.spark:Show()

        -- Only show time text if the font size is valid
        if frame.timeText and cfg.height and cfg.height > 6 then
            frame.timeText:SetText(string.format("%.1f", remaining))
            frame.timeText:Show()
        elseif frame.timeText then
            frame.timeText:Hide()
        end

        frame:Show()
        wasInRegen = false
    else
        frame.bar:SetValue(FSR_DURATION)
        frame.bar:SetStatusBarColor(cfg.regenColor[1], cfg.regenColor[2], cfg.regenColor[3], cfg.regenColor[4])
        frame.spark:Hide()
        if frame.timeText then frame.timeText:Hide() end
        frame:Show()

        -- Pulse when first entering regen state
        if not wasInRegen then
            PulseRegen(frame)
            wasInRegen = true
        end
    end
end

local function SyncFSRWidth()
    if not CB.fsrFrame then return end
    if CastbornDB.fsr and CastbornDB.fsr.anchored ~= false then
        local width = Castborn.Anchoring and Castborn.Anchoring:GetCastbarBarWidth()
        if width then
            CB.fsrFrame:SetWidth(width)
        end
    else
        -- Use default/config width when detached
        CB.fsrFrame:SetWidth(CB.fsrFrame.defaultWidth or 250)
    end
end

-- Detach FSR from castbar
CB:RegisterCallback("DETACH_FSR", function()
    if not CB.fsrFrame then return end
    CastbornDB.fsr = CastbornDB.fsr or {}
    if Castborn.Anchoring then
        Castborn.Anchoring:DetachFromCastbar(CB.fsrFrame, CastbornDB.fsr)
    end
    SyncFSRWidth()
    CB:Print("5 Second Rule detached from castbar")
end)

-- Reattach FSR to castbar
CB:RegisterCallback("REATTACH_FSR", function()
    if not CB.fsrFrame then return end
    CastbornDB.fsr = CastbornDB.fsr or {}
    if Castborn.Anchoring then
        Castborn.Anchoring:ReattachToCastbar(CB.fsrFrame, CastbornDB.fsr, "TOP", 2, SyncFSRWidth)
    end
    CB:Print("5 Second Rule anchored to castbar")
end)

-- Listen for player castbar creation
CB:RegisterCallback("PLAYER_CASTBAR_CREATED", function(frame)
    playerCastbar = frame

    -- Anchor ABOVE the player castbar if configured
    if CB.fsrFrame and CastbornDB.fsr and CastbornDB.fsr.anchored ~= false and Castborn.Anchoring then
        Castborn.Anchoring:ReattachToCastbar(CB.fsrFrame, CastbornDB.fsr, "TOP", 2, SyncFSRWidth)
    end
end)

function CB:InitFSR()
    if not PlayerUsesMana() then CB:Print("Five Second Rule tracker disabled (non-mana class)") return end

    -- Ensure defaults for new settings
    CastbornDB.fsr = CastbornDB.fsr or {}
    if CastbornDB.fsr.anchored == nil then
        CastbornDB.fsr.anchored = true  -- Default to anchored
    end
    if not CastbornDB.fsr.height then
        CastbornDB.fsr.height = 4  -- Default thin pulse line
    end

    CB.fsrFrame = CreateFSRBar()
    previousMana = UnitPower("player", POWER_MANA) or UnitMana("player") or 0

    -- If player castbar already exists and we should be anchored, attach now
    if CastbornDB.fsr.anchored ~= false and Castborn.Anchoring then
        playerCastbar = playerCastbar or (CB.castbars and CB.castbars.player)
        if playerCastbar then
            Castborn.Anchoring:ReattachToCastbar(CB.fsrFrame, CastbornDB.fsr, "TOP", 2, SyncFSRWidth)
        end
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    if not UnitPower then eventFrame:RegisterEvent("UNIT_MANA") end

    eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
        if unit ~= "player" then return end

        if event == "UNIT_POWER_UPDATE" then
            local powerType = ...
            if powerType == "MANA" then
                local currentMana = UnitPower and UnitPower("player", POWER_MANA) or UnitMana("player")
                if currentMana < previousMana and (previousMana - currentMana) > 1 then
                    lastManaSpend = GetTime()
                end
                previousMana = currentMana
            end
        elseif event == "UNIT_MANA" then
            local currentMana = UnitMana("player") or 0
            if currentMana < previousMana and (previousMana - currentMana) > 1 then
                lastManaSpend = GetTime()
            end
            previousMana = currentMana
        end
    end)

    CB:CreateThrottledUpdater(0.02, UpdateFSR)

    CB:Print("Five Second Rule tracker initialized")
end

-- Test mode function
function CB:TestFSR()
    if not CB.fsrFrame then return end
    local cfg = CB.db.fsr

    testModeActive = true

    -- Ensure anchoring is applied in test mode
    if CastbornDB.fsr and CastbornDB.fsr.anchored ~= false and Castborn.Anchoring then
        -- Try to find playerCastbar if not set
        if not playerCastbar then
            playerCastbar = CB.castbars and CB.castbars.player
        end
        if playerCastbar then
            local anchorTarget = playerCastbar.bar or playerCastbar
            Castborn.Anchoring:Anchor(CB.fsrFrame, anchorTarget, "TOP", 0, 2)
            SyncFSRWidth()
        end
    end

    -- Show the bar in "active" state (counting down)
    CB.fsrFrame:Show()
    CB.fsrFrame.bar:SetValue(3.5)  -- Show at 3.5 seconds remaining
    CB.fsrFrame.bar:SetStatusBarColor(cfg.activeColor[1], cfg.activeColor[2], cfg.activeColor[3], cfg.activeColor[4])
    if CB.fsrFrame.spark then
        local progress = 3.5 / FSR_DURATION
        CB.fsrFrame.spark:SetPoint("CENTER", CB.fsrFrame.bar, "LEFT", progress * CB.fsrFrame.bar:GetWidth(), 0)
        CB.fsrFrame.spark:Show()
    end
    if CB.fsrFrame.timeText and cfg.height and cfg.height > 6 then
        CB.fsrFrame.timeText:SetText("3.5")
        CB.fsrFrame.timeText:Show()
    end
end

-- End test mode
function CB:EndTestFSR()
    testModeActive = false
    if CB.fsrFrame then
        CB.fsrFrame:Hide()
    end
end

-- Register with TestManager
CB:RegisterCallback("READY", function()
    CB.TestManager:Register("FSR", function() CB:TestFSR() end, function() CB:EndTestFSR() end)
end)

Castborn:RegisterModule("FiveSecondRule", FiveSecondRule)

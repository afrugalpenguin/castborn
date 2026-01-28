--[[
    Castborn - GCD Indicator Module
    Shows Global Cooldown as a pulse/sweep indicator
]]

local GCDIndicator = {}
Castborn.GCDIndicator = GCDIndicator

local CB = Castborn
CB.gcdFrame = nil

-- Reference to player castbar for anchoring
local playerCastbar = nil

local gcdStart = 0
local gcdDuration = 0
local gcdActive = false
local testModeActive = false

local function DetectGCD()
    local start, duration = GetSpellCooldown(61304)
    if not start or start == 0 then
        local _, class = UnitClass("player")
        local testSpells = {
            MAGE="Frostbolt", WARLOCK="Shadow Bolt", PRIEST="Smite", DRUID="Wrath",
            SHAMAN="Lightning Bolt", PALADIN="Holy Light", HUNTER="Arcane Shot",
            WARRIOR="Heroic Strike", ROGUE="Sinister Strike",
        }
        local testSpell = testSpells[class]
        if testSpell then start, duration = GetSpellCooldown(testSpell) end
    end
    return start, duration
end

local function CreateGCDIndicator()
    local cfg = CB.db.gcd
    local frame = CreateFrame("Frame", "Castborn_GCD", UIParent)
    frame:SetSize(cfg.width, cfg.height)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(8)

    -- Use shared backdrop creation
    CB:CreateBackdrop(frame, {0.05, 0.05, 0.05, 0.7}, cfg.borderColor)

    local bar = frame:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMLEFT", 1, 1)
    bar:SetWidth(0)
    bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetVertexColor(cfg.barColor[1], cfg.barColor[2], cfg.barColor[3], cfg.barColor[4])
    frame.bar = bar
    
    local spark = frame:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(12, cfg.height * 2.5)
    spark:Hide()
    frame.spark = spark
    
    local pulse = frame:CreateTexture(nil, "OVERLAY")
    pulse:SetAllPoints()
    pulse:SetColorTexture(1, 1, 1, 0)
    pulse:SetBlendMode("ADD")
    frame.pulse = pulse
    frame.pulseAlpha = 0
    
    -- Use Anchoring system for draggable functionality
    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, CastbornDB.gcd or {}, function(f)
            -- On drag stop, mark as detached
            CastbornDB.gcd = CastbornDB.gcd or {}
            CastbornDB.gcd.anchored = false
        end, "GCD")
    else
        CB:MakeMoveable(frame, "gcd")
    end

    -- Apply position only if not anchored
    if not CastbornDB.gcd or CastbornDB.gcd.anchored == false then
        CB:ApplyPosition(frame, "gcd")
    end

    frame:Hide()
    return frame
end

local function UpdateGCD(elapsed)
    -- Don't override test mode display
    if testModeActive then return end

    local frame = CB.gcdFrame
    local cfg = CB.db.gcd
    if not cfg.enabled then frame:Hide() return end
    
    if frame.pulseAlpha > 0 then
        frame.pulseAlpha = frame.pulseAlpha - elapsed * 4
        if frame.pulseAlpha < 0 then frame.pulseAlpha = 0 end
        frame.pulse:SetAlpha(frame.pulseAlpha * 0.5)
    end
    
    if gcdActive then
        local remaining = (gcdStart + gcdDuration) - GetTime()
        if remaining <= 0 then
            gcdActive = false
            frame.bar:SetWidth(0)
            frame.spark:Hide()
            frame.pulseAlpha = 1
            frame.pulse:SetAlpha(0.5)
            if not cfg.alwaysShow then frame:Hide() end
        else
            local progress = 1 - (remaining / gcdDuration)
            progress = math.max(0, math.min(1, progress))
            local barWidth = (frame:GetWidth() - 2) * progress
            frame.bar:SetWidth(barWidth)
            frame.spark:SetPoint("CENTER", frame, "LEFT", barWidth + 1, 0)
            frame.spark:Show()
            frame:Show()
        end
    elseif cfg.alwaysShow then
        frame:Show()
        frame.bar:SetWidth(frame:GetWidth() - 2)
        frame.bar:SetVertexColor(cfg.readyColor[1], cfg.readyColor[2], cfg.readyColor[3], cfg.readyColor[4])
        frame.spark:Hide()
    end
end

local function SyncGCDWidth()
    if not CB.gcdFrame then return end
    if CastbornDB.gcd and CastbornDB.gcd.anchored ~= false then
        local width = Castborn.Anchoring and Castborn.Anchoring:GetCastbarBarWidth()
        if width then
            CB.gcdFrame:SetWidth(width)
        end
    end
end

function CB:InitGCD()
    CB.gcdFrame = CreateGCDIndicator()

    -- If player castbar already exists and we should be anchored, attach now
    local cfg = CastbornDB.gcd
    if cfg and cfg.anchored ~= false and Castborn.Anchoring then
        playerCastbar = playerCastbar or (CB.castbars and CB.castbars.player)
        if playerCastbar then
            Castborn.Anchoring:ReattachToCastbar(CB.gcdFrame, CastbornDB.gcd, "BOTTOM", -2, SyncGCDWidth)
        end
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    
    eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
        if event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_START" then
            if unit ~= "player" then return end
        end
        local start, duration = DetectGCD()
        if start and start > 0 and duration and duration > 0 then
            -- Only update if the GCD is actually still running (not already expired)
            local remaining = (start + duration) - GetTime()
            if remaining > 0 then
                gcdStart = start
                gcdDuration = duration
                gcdActive = true
                local cfg = CB.db.gcd
                CB.gcdFrame.bar:SetVertexColor(cfg.barColor[1], cfg.barColor[2], cfg.barColor[3], cfg.barColor[4])
            end
        end
    end)
    
    CB:CreateThrottledUpdater(0.016, UpdateGCD)
    
    CB:Print("GCD indicator initialized")
end

function CB:TestGCD()
    if not CB.gcdFrame then return end

    testModeActive = true

    -- Ensure anchoring is applied in test mode
    local cfg = CastbornDB.gcd
    if cfg and cfg.anchored ~= false and Castborn.Anchoring then
        playerCastbar = playerCastbar or (CB.castbars and CB.castbars.player)
        if playerCastbar then
            Castborn.Anchoring:ReattachToCastbar(CB.gcdFrame, CastbornDB.gcd, "BOTTOM", -2, SyncGCDWidth)
        end
    end

    gcdStart = GetTime()
    gcdDuration = 1.5
    gcdActive = true
    cfg = CB.db.gcd
    CB.gcdFrame.bar:SetVertexColor(cfg.barColor[1], cfg.barColor[2], cfg.barColor[3], cfg.barColor[4])
    CB.gcdFrame:Show()
end

-- End test mode
function CB:EndTestGCD()
    testModeActive = false
    if CB.gcdFrame then
        CB.gcdFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- Anchoring Support
--------------------------------------------------------------------------------

-- Listen for player castbar creation and anchor to it
CB:RegisterCallback("PLAYER_CASTBAR_CREATED", function(frame)
    playerCastbar = frame

    -- Anchor BELOW the player castbar if configured
    if CB.gcdFrame and CastbornDB.gcd and CastbornDB.gcd.anchored ~= false and Castborn.Anchoring then
        Castborn.Anchoring:ReattachToCastbar(CB.gcdFrame, CastbornDB.gcd, "BOTTOM", -2, SyncGCDWidth)
    end
end)

-- Listen for player castbar movement (anchored frames auto-update)
CB:RegisterCallback("PLAYER_CASTBAR_MOVED", function()
    -- Nothing needed - anchored frames move automatically
end)

-- Detach GCD indicator from castbar for independent positioning
function Castborn_GCD_Detach()
    if not CB.gcdFrame then return end
    CastbornDB.gcd = CastbornDB.gcd or {}
    if Castborn.Anchoring then
        Castborn.Anchoring:DetachFromCastbar(CB.gcdFrame, CastbornDB.gcd)
    end
end

-- Reattach GCD indicator to player castbar
function Castborn_GCD_Reattach()
    if not CB.gcdFrame then return end
    CastbornDB.gcd = CastbornDB.gcd or {}
    if Castborn.Anchoring then
        Castborn.Anchoring:ReattachToCastbar(CB.gcdFrame, CastbornDB.gcd, "BOTTOM", -2, SyncGCDWidth)
    end
    CB:Print("GCD anchored to castbar")
end

-- Register callbacks for Options panel
CB:RegisterCallback("DETACH_GCD", function()
    Castborn_GCD_Detach()
    CB:Print("GCD detached from castbar")
end)

CB:RegisterCallback("REATTACH_GCD", function()
    Castborn_GCD_Reattach()
end)

--------------------------------------------------------------------------------
-- SkinEngine Integration
--------------------------------------------------------------------------------

-- Register with SkinEngine after frame is created
CB:RegisterCallback("READY", function()
    if CB.gcdFrame and CB.SkinEngine then
        CB.SkinEngine:RegisterFrame(CB.gcdFrame, "bar", function(frame, skin)
            if not frame or not skin then return end
            local style = skin.bar
            if style then
                if frame.bar and style.barTexture then
                    frame.bar:SetTexture(style.barTexture)
                end
            end
        end)
    end

    -- Register with TestManager
    CB.TestManager:Register("GCD", function() CB:TestGCD() end, function() CB:EndTestGCD() end)
end)

Castborn:RegisterModule("GCDIndicator", GCDIndicator)

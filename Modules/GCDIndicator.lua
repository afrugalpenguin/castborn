--[[
    Castborn - GCD Indicator Module
    Shows Global Cooldown as a pulse/sweep indicator
]]

local GCDIndicator = {}
Castborn.GCDIndicator = GCDIndicator

local CB = Castborn
CB.gcdFrame = nil

local gcdStart = 0
local gcdDuration = 0
local gcdActive = false
local testModeActive = false

-- A spell per class that triggers the GCD, used when the GCD spell itself reports nothing
GCDIndicator.testSpells = {
    MAGE="Frostbolt", WARLOCK="Shadow Bolt", PRIEST="Smite", DRUID="Wrath",
    SHAMAN="Lightning Bolt", PALADIN="Holy Light", HUNTER="Arcane Shot",
    WARRIOR="Heroic Strike", ROGUE="Sinister Strike",
}

local function DetectGCD()
    local start, duration = GetSpellCooldown(61304)
    if not start or start == 0 then
        local _, class = UnitClass("player")
        local testSpell = GCDIndicator.testSpells[class]
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
    CB:CreateBackdrop(frame, cfg.bgColor or {0.05, 0.05, 0.05, 0.7}, cfg.borderColor)

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
    end

    -- Apply position only if not anchored
    if not CastbornDB.gcd or CastbornDB.gcd.anchored == false then
        CB:ApplyPosition(frame, "gcd")
    end

    frame:Hide()
    return frame
end

-- Draw the GCD sweep for the current time, or the ready state. Forever overrides this.
function CB:UpdateGCDBar(frame, cfg)
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

    CB:UpdateGCDBar(frame, cfg)
end

-- Start the sweep when the GCD is running. Forever overrides this.
function CB:CheckGCD()
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
end

-- Whether this class's bar sits on the swing timer. Saved per class, as the 5 Second Rule
-- choice is: settings are account-wide, and melee and casters want different places.
function GCDIndicator:AnchorsToSwing()
    local cfg = CastbornDB.gcd
    local class = CB:GetPlayerInfo().class
    local choice = cfg and cfg.anchorToSwingByClass and cfg.anchorToSwingByClass[class]
    return choice == true
end

function GCDIndicator:SetAnchorsToSwing(value)
    CastbornDB.gcd = CastbornDB.gcd or {}
    CastbornDB.gcd.anchorToSwingByClass = CastbornDB.gcd.anchorToSwingByClass or {}
    CastbornDB.gcd.anchorToSwingByClass[CB:GetPlayerInfo().class] = value and true or false
end

-- The top swing bar, when the bar should sit on the swing timer instead of the castbar
local function SwingAnchor()
    if not GCDIndicator:AnchorsToSwing() then return nil end
    return CB.swingTimers and CB.swingTimers.mainhand
end

-- The GCD bar, while it is turned on and sits on the swing timer, so the 5 Second Rule
-- (when it is anchored to the swing timer too) stacks above it
function GCDIndicator:FrameOnSwing()
    local cfg = CastbornDB.gcd
    if not (CB.gcdFrame and cfg and cfg.enabled ~= false and cfg.anchored ~= false) then return nil end
    if not SwingAnchor() then return nil end
    return CB.gcdFrame
end

local function SyncGCDWidth()
    if not CB.gcdFrame then return end
    if CastbornDB.gcd and CastbornDB.gcd.anchored ~= false then
        local swing = SwingAnchor()
        local width
        if swing then
            width = swing:GetWidth()
        else
            width = Castborn.Anchoring and Castborn.Anchoring:GetCastbarBarWidth()
        end
        if width then
            CB.gcdFrame:SetWidth(width)
        end
    end
end

-- The 5 Second Rule stacks on this bar when both sit on the swing timer, so re-place it
-- whenever this bar changes where it sits
local function RestackFSR()
    local fsr = CB.FiveSecondRule
    if fsr and CastbornDB.fsr and CastbornDB.fsr.anchored ~= false then
        fsr:Reattach()
    end
end
GCDIndicator.RestackFSR = RestackFSR

-- Anchor directly above the swing timer if chosen and present, otherwise below the castbar
function GCDIndicator:Reattach()
    local frame, cfg = CB.gcdFrame, CastbornDB.gcd
    if not (frame and cfg and Castborn.Anchoring) then return false end
    local swing = SwingAnchor()
    if swing then
        cfg.anchored = true
        Castborn.Anchoring:Anchor(frame, swing, "TOP", 0, 2)
        SyncGCDWidth()
        return true
    end
    return Castborn.Anchoring:ReattachToCastbar(frame, cfg, "BOTTOM", -2, SyncGCDWidth)
end

function CB:InitGCD()
    CB.gcdFrame = CreateGCDIndicator()

    -- If player castbar already exists and we should be anchored, attach now
    local cfg = CastbornDB.gcd
    if cfg and cfg.anchored ~= false then
        GCDIndicator:Reattach()
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    
    eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
        if event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_START" then
            if unit ~= "player" then return end
        end
        CB:CheckGCD()
    end)
    
    CB:CreateThrottledUpdater(0.016, UpdateGCD)
    
    CB:Print("GCD indicator initialized")
end

function CB:TestGCD()
    if not CB.gcdFrame then return end

    testModeActive = true

    -- Ensure anchoring is applied in test mode
    local cfg = CastbornDB.gcd
    if cfg and cfg.anchored ~= false then
        GCDIndicator:Reattach()
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
    -- Anchor BELOW the player castbar (or above the swing timer) if configured
    if CB.gcdFrame and CastbornDB.gcd and CastbornDB.gcd.anchored ~= false then
        GCDIndicator:Reattach()
    end
end)

-- Detach / reattach GCD
CB:RegisterAnchorCallbacks("GCD", "GCD", function() return CB.gcdFrame end, "gcd", "BOTTOM", -2, {
    syncCallback = SyncGCDWidth,
    reattach = function()
        GCDIndicator:Reattach()
        RestackFSR()
    end,
    onDetach = RestackFSR,
})

-- The swing timer is built after this bar, so move above it once everything exists
CB:RegisterCallback("READY", function()
    if CastbornDB.gcd and CastbornDB.gcd.anchored ~= false and SwingAnchor() then
        GCDIndicator:Reattach()
    end
end)

CB:RegisterCallback("SWING_RESIZED", SyncGCDWidth)

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

-- Repaint the GCD bar's background from the saved colour
function GCDIndicator:ApplyBackground()
    local cfg = CB.db and CB.db.gcd
    if cfg then CB:PaintBackdrop(CB.gcdFrame, cfg.bgColor) end
end

CB:RegisterCallback("BACKGROUND_CHANGED", function(key)
    if key == "gcd" then GCDIndicator:ApplyBackground() end
end)

Castborn:RegisterModule("GCDIndicator", GCDIndicator)

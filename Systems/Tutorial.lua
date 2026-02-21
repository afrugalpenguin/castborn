--[[
    Castborn - Tutorial/Onboarding System
    Step-by-step wizard that guides new users through each feature
]]

local Tutorial = {}
Castborn.Tutorial = Tutorial

local currentStep = 0
local tutorialFrame = nil
local highlightFrame = nil
local spotlightOverlay = nil
local isActive = false
local originalFrameInfo = {}  -- Store original strata/level for restoration

-- Tutorial steps configuration
-- configKey maps to CastbornDB[key].enabled for the enable checkbox
local steps = {
    {
        id = "welcome",
        title = "Welcome to Castborn!",
        description = "This tutorial will guide you through all the features of Castborn.\n\nYou can enable or disable each module as we go through them.",
        tip = "You can replay this tutorial anytime with |cff88ddff/cb tutorial|r",
        frame = nil,
    },
    {
        id = "player_castbar",
        title = "Player Castbar",
        description = "This is your main casting bar. It shows your spell casts and channels with a progress bar, spell name, and remaining time.",
        tip = "When your cast bar reaches the red part, press your next spell. You'll cast faster.",
        getFrame = function() return Castborn.castbars and Castborn.castbars.player end,
        -- No configKey - player castbar is always enabled
    },
    {
        id = "gcd",
        title = "GCD Indicator",
        description = "Shows when your Global Cooldown is active. Appears below your castbar and sweeps from left to right.",
        tip = "This helps you time your next ability perfectly as the GCD ends.",
        getFrame = function() return Castborn.gcdFrame end,
        configKey = "gcd",
    },
    {
        id = "fsr",
        title = "5 Second Rule (MP5)",
        description = "For mana users, tracks the 5-second rule. After spending mana, you must wait 5 seconds before spirit-based mana regeneration resumes.",
        tip = "The bar turns green and pulses when you enter the regeneration state. Only visible in combat.",
        getFrame = function() return Castborn.fsrFrame end,
        configKey = "fsr",
    },
    {
        id = "cooldowns",
        title = "Cooldown Tracker",
        description = "Track your important cooldowns like Icy Veins, trinkets, and major abilities. Icons show remaining cooldown and glow when ready.\n\nYou can reorder icons by dragging them in test mode.",
        tip = "Use the up/down arrows in Options > Cooldowns to reorder, or drag icons while in test mode.",
        getFrame = function() return _G["Castborn_CooldownTracker"] end,
        configKey = "cooldowns",
    },
    {
        id = "target_castbar",
        title = "Target Castbar",
        description = "See what your target is casting. Essential for interrupting enemy spells in PvP and PvE.",
        tip = "A shield icon appears on spells that cannot be interrupted.",
        getFrame = function() return Castborn.castbars and Castborn.castbars.target end,
        configKey = "target",
    },
    {
        id = "targettarget_castbar",
        title = "Target-of-Target Castbar",
        description = "See what your target's target is casting. Useful for watching tank threat or healer casts.",
        tip = "Commonly used by healers to monitor what the tank is fighting.",
        getFrame = function() return Castborn.castbars and Castborn.castbars.targettarget end,
        configKey = "targettarget",
    },
    {
        id = "focus_castbar",
        title = "Focus Castbar",
        description = "Track your focus target's casts separately. Great for watching a specific enemy while targeting another.",
        tip = "Set a focus target with /focus or by right-clicking a unit frame.",
        getFrame = function() return Castborn.castbars and Castborn.castbars.focus end,
        configKey = "focus",
    },
    {
        id = "dots",
        title = "DoT Tracker",
        description = "Track your damage-over-time effects on your current target. Shows duration remaining with color-coded urgency.",
        tip = "Red means expiring soon! Refresh your DoTs before they fall off.",
        getFrame = function() return _G["Castborn_DoTTracker"] end,
        configKey = "dots",
    },
    {
        id = "multidot",
        title = "Multi-DoT Tracker",
        description = "In multi-target fights, shows DoT status across multiple enemies so you can keep them all dotted.",
        tip = "Targets are sorted by urgency - the one needing attention most appears first.",
        getFrame = function() return _G["Castborn_MultiDoTTracker"] end,
        configKey = "multidot",
    },
    {
        id = "procs",
        title = "Proc Tracker",
        description = "Track important procs and temporary buffs like Clearcasting, Nightfall, and trinket activations.",
        tip = "Procs pulse with a glow effect to grab your attention when they activate.",
        getFrame = function() return _G["Castborn_ProcTracker"] end,
        configKey = "procs",
    },
    {
        id = "swing",
        title = "Swing Timer",
        description = "For melee and hunters, track your auto-attack swing timer. Shows mainhand, offhand, and ranged attack timers.",
        tip = "Useful for timing abilities between auto-attacks for maximum DPS.",
        getFrame = function() return _G["Castborn_SwingTimer"] end,
        configKey = "swing",
    },
    {
        id = "interrupt",
        title = "Interrupt Tracker",
        description = "Track your interrupt ability cooldown and any school lockouts you've applied to enemies.",
        tip = "Shows when your kick/counterspell is ready and how long the enemy is locked out.",
        getFrame = function() return _G["Castborn_InterruptTracker"] end,
        configKey = "interrupt",
    },
    {
        id = "totems",
        title = "Totem Tracker",
        description = "Track your active totems with duration bars. Shows Fire, Earth, Water, and Air totems with remaining time.",
        tip = "Mouseover a totem bar to see which party members are NOT in range.",
        getFrame = function() return _G["Castborn_TotemTracker"] end,
        configKey = "totems",
        class = "SHAMAN",
    },
    {
        id = "absorbs",
        title = "Absorb Tracker",
        description = "Track absorb shields like Ice Barrier, Mana Shield, Fire Ward, Shadow Ward, Power Word: Shield, and more.\n\nShows remaining absorb amount with a drain effect. Multiple shields display as a row of icons.",
        tip = "Works for all classes — Power Word: Shield from a healer is tracked automatically.",
        getFrame = function() return _G["Castborn_AbsorbTracker"] end,
        configKey = "absorbs",
    },
    {
        id = "appearance",
        title = "Customize Appearance",
        description = "You can customize the look of every module!\n\nToggle frame borders on or off globally in |cff88ddffLook & Feel|r options, and set a custom background color and opacity for each module in its settings.",
        tip = "Open |cff88ddff/cb|r and check Look & Feel for borders, or each module's page for background color.",
        getFrame = function() return Castborn.castbars and Castborn.castbars.player end,
    },
    {
        id = "moving",
        title = "Moving & Positioning",
        description = "All Castborn frames can be repositioned!\n\nType |cff88ddff/cb unlock|r to enable dragging, then drag any frame to your preferred position.\n\n|cff88ddffCtrl+Shift+Click|r a module header to temporarily hide it — useful when frames overlap.",
        tip = "Use |cff88ddff/cb lock|r when done. Use |cff88ddff/cb grid|r for a positioning grid overlay.",
        frame = nil,
    },
    {
        id = "options",
        title = "Options Panel",
        description = "Customize everything in the options panel. Adjust sizes, colors, and behaviors for each module.",
        tip = "Open options anytime with |cff88ddff/cb|r or find Castborn in Interface > AddOns.",
        frame = nil,
        action = function()
            if Castborn.Options then
                Castborn.Options:Show()
            end
        end,
    },
    {
        id = "complete",
        title = "Setup Complete!",
        description = "You're all set! Castborn is now configured to your preferences.\n\nRemember:\n|cff88ddff/cb|r - Open options\n|cff88ddff/cb unlock|r - Move frames\n|cff88ddff/cb tutorial|r - Replay this setup",
        tip = "Have fun and good luck with your adventures!",
        frame = nil,
    },
}

-- Create the highlight frame that surrounds the current element
local function CreateHighlightFrame()
    local frame = CreateFrame("Frame", "CastbornTutorialHighlight", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)

    -- Main border
    frame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 3,
    })
    frame:SetBackdropBorderColor(0.4, 0.8, 1, 1)

    -- Outer glow layer 1
    frame.glow1 = frame:CreateTexture(nil, "BACKGROUND")
    frame.glow1:SetPoint("TOPLEFT", -12, 12)
    frame.glow1:SetPoint("BOTTOMRIGHT", 12, -12)
    frame.glow1:SetColorTexture(0.3, 0.6, 1, 0.2)

    -- Outer glow layer 2 (larger, more subtle)
    frame.glow2 = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    frame.glow2:SetPoint("TOPLEFT", -20, 20)
    frame.glow2:SetPoint("BOTTOMRIGHT", 20, -20)
    frame.glow2:SetColorTexture(0.2, 0.5, 1, 0.1)

    -- Corner accents
    local function CreateCorner(point1, point2, xOff, yOff)
        local corner = frame:CreateTexture(nil, "OVERLAY")
        corner:SetColorTexture(0.5, 0.9, 1, 0.9)
        corner:SetSize(12, 3)
        corner:SetPoint(point1, frame, point1, xOff, yOff)
        local corner2 = frame:CreateTexture(nil, "OVERLAY")
        corner2:SetColorTexture(0.5, 0.9, 1, 0.9)
        corner2:SetSize(3, 12)
        corner2:SetPoint(point1, frame, point1, xOff, yOff)
        return corner, corner2
    end

    CreateCorner("TOPLEFT", "TOPLEFT", -2, 2)
    CreateCorner("TOPRIGHT", "TOPRIGHT", 2, 2)
    CreateCorner("BOTTOMLEFT", "BOTTOMLEFT", -2, -2)
    CreateCorner("BOTTOMRIGHT", "BOTTOMRIGHT", 2, -2)

    -- Pulsing animation
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local pulse = math.sin(elapsed * 3) * 0.3 + 0.7
        local glowPulse = math.sin(elapsed * 2) * 0.1 + 0.2
        self:SetBackdropBorderColor(0.4, 0.8, 1, pulse)
        self.glow1:SetAlpha(glowPulse + 0.1)
        self.glow2:SetAlpha(glowPulse * 0.5)
    end)

    frame:Hide()
    return frame
end

-- Create the spotlight overlay (dims everything except the focused element)
local function CreateSpotlightOverlay()
    local overlay = CreateFrame("Frame", "CastbornTutorialSpotlight", UIParent)
    overlay:SetFrameStrata("FULLSCREEN")
    overlay:SetFrameLevel(50)
    overlay:SetAllPoints(UIParent)

    -- Create 4 dark panels that surround the spotlight "hole"
    -- Top panel (above the spotlight)
    overlay.top = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.top:SetColorTexture(0, 0, 0, 0.75)
    overlay.top:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
    overlay.top:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT")

    -- Bottom panel (below the spotlight)
    overlay.bottom = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.bottom:SetColorTexture(0, 0, 0, 0.75)
    overlay.bottom:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT")
    overlay.bottom:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")

    -- Left panel (left of the spotlight)
    overlay.left = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.left:SetColorTexture(0, 0, 0, 0.75)
    overlay.left:SetPoint("TOPLEFT", overlay.top, "BOTTOMLEFT")
    overlay.left:SetPoint("BOTTOMLEFT", overlay.bottom, "TOPLEFT")

    -- Right panel (right of the spotlight)
    overlay.right = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.right:SetColorTexture(0, 0, 0, 0.75)
    overlay.right:SetPoint("TOPRIGHT", overlay.top, "BOTTOMRIGHT")
    overlay.right:SetPoint("BOTTOMRIGHT", overlay.bottom, "TOPRIGHT")

    -- Fade in/out animation state
    overlay.targetAlpha = 0.75
    overlay.currentAlpha = 0

    overlay:SetScript("OnUpdate", function(self, delta)
        if self.currentAlpha ~= self.targetAlpha then
            local diff = self.targetAlpha - self.currentAlpha
            local change = delta * 3  -- Speed of fade
            if math.abs(diff) < change then
                self.currentAlpha = self.targetAlpha
            else
                self.currentAlpha = self.currentAlpha + (diff > 0 and change or -change)
            end
            local a = self.currentAlpha
            self.top:SetAlpha(a)
            self.bottom:SetAlpha(a)
            self.left:SetAlpha(a)
            self.right:SetAlpha(a)
        end
    end)

    overlay:Hide()
    return overlay
end

-- Position the spotlight hole around a target frame
local function PositionSpotlight(targetFrame, padding)
    if not spotlightOverlay then
        spotlightOverlay = CreateSpotlightOverlay()
    end

    padding = padding or 15

    -- Clear all points first
    spotlightOverlay.top:ClearAllPoints()
    spotlightOverlay.bottom:ClearAllPoints()
    spotlightOverlay.left:ClearAllPoints()
    spotlightOverlay.right:ClearAllPoints()

    if targetFrame and targetFrame:IsShown() and targetFrame:GetLeft() then
        local left = targetFrame:GetLeft() - padding
        local right = targetFrame:GetRight() + padding
        local top = targetFrame:GetTop() + padding
        local bottom = targetFrame:GetBottom() - padding
        local screenWidth = GetScreenWidth()
        local screenHeight = GetScreenHeight()

        -- Top panel: covers from screen top down to spotlight top
        spotlightOverlay.top:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        spotlightOverlay.top:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", screenWidth, top)

        -- Bottom panel: covers from spotlight bottom down to screen bottom
        spotlightOverlay.bottom:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, bottom)
        spotlightOverlay.bottom:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)

        -- Left panel: covers left side between top and bottom panels
        spotlightOverlay.left:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, top)
        spotlightOverlay.left:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", left, bottom)

        -- Right panel: covers right side between top and bottom panels
        spotlightOverlay.right:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right, top)
        spotlightOverlay.right:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", screenWidth, bottom)

        spotlightOverlay.targetAlpha = 0.75
        spotlightOverlay:Show()
    else
        -- No target - show subtle overlay for welcome/complete screens
        spotlightOverlay.top:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        spotlightOverlay.top:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
        -- Hide other panels when no spotlight
        spotlightOverlay.bottom:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        spotlightOverlay.bottom:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", 0, 0)
        spotlightOverlay.left:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        spotlightOverlay.left:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", 0, 0)
        spotlightOverlay.right:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        spotlightOverlay.right:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", 0, 0)
        spotlightOverlay.targetAlpha = 0.6
        spotlightOverlay:Show()
    end
end

-- Raise a frame above the spotlight overlay
local function RaiseFrameAboveSpotlight(frame)
    if not frame then return end

    -- Store original info for restoration
    originalFrameInfo[frame] = {
        strata = frame:GetFrameStrata(),
        level = frame:GetFrameLevel(),
    }

    -- Raise above spotlight but below tutorial UI
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(90)
end

-- Restore a frame to its original strata/level
local function RestoreFrame(frame)
    if not frame or not originalFrameInfo[frame] then return end

    frame:SetFrameStrata(originalFrameInfo[frame].strata)
    frame:SetFrameLevel(originalFrameInfo[frame].level)
    originalFrameInfo[frame] = nil
end

-- Restore all raised frames
local function RestoreAllFrames()
    for frame, info in pairs(originalFrameInfo) do
        if frame and frame.SetFrameStrata then
            frame:SetFrameStrata(info.strata)
            frame:SetFrameLevel(info.level)
        end
    end
    originalFrameInfo = {}
end

-- Create the tutorial explanation panel
local function CreateTutorialFrame()
    local frame = CreateFrame("Frame", "CastbornTutorialFrame", UIParent, "BackdropTemplate")
    frame:SetSize(400, 240)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -170)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(101)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    frame:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
    frame:SetBackdropBorderColor(0.3, 0.5, 0.8, 1)

    -- Make it movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Step counter
    frame.stepText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.stepText:SetPoint("TOPLEFT", 12, -10)
    frame.stepText:SetTextColor(0.6, 0.6, 0.6, 1)

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -28)
    frame.title:SetTextColor(0.5, 0.8, 1, 1)

    -- Description
    frame.description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.description:SetPoint("TOPLEFT", 16, -55)
    frame.description:SetPoint("TOPRIGHT", -16, -55)
    frame.description:SetJustifyH("LEFT")
    frame.description:SetJustifyV("TOP")
    frame.description:SetSpacing(2)

    -- Tip section
    frame.tipIcon = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.tipIcon:SetPoint("BOTTOMLEFT", 16, 52)
    frame.tipIcon:SetText("|cff88ddffTip:|r")

    frame.tip = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.tip:SetPoint("LEFT", frame.tipIcon, "RIGHT", 6, 0)
    frame.tip:SetPoint("RIGHT", -16, 0)
    frame.tip:SetJustifyH("LEFT")
    frame.tip:SetTextColor(0.7, 0.7, 0.7, 1)

    -- Enable checkbox (for modules that can be toggled)
    frame.enableCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.enableCheck:SetSize(26, 26)
    frame.enableCheck:SetPoint("BOTTOMLEFT", 16, 42)
    frame.enableCheck.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.enableCheck.text:SetPoint("LEFT", frame.enableCheck, "RIGHT", 4, 0)
    frame.enableCheck.text:SetText("Enable this module")
    frame.enableCheck.text:SetTextColor(0.9, 0.9, 0.9, 1)
    frame.enableCheck:Hide()  -- Hidden by default, shown for steps with configKey

    -- Buttons
    frame.skipBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.skipBtn:SetSize(70, 22)
    frame.skipBtn:SetPoint("BOTTOMLEFT", 12, 12)
    frame.skipBtn:SetText("Skip")
    frame.skipBtn:SetScript("OnClick", function()
        Tutorial:End()
    end)

    frame.backBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.backBtn:SetSize(70, 22)
    frame.backBtn:SetPoint("BOTTOM", -45, 12)
    frame.backBtn:SetText("Back")
    frame.backBtn:SetScript("OnClick", function()
        Tutorial:PreviousStep()
    end)

    frame.nextBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.nextBtn:SetSize(70, 22)
    frame.nextBtn:SetPoint("BOTTOM", 45, 12)
    frame.nextBtn:SetText("Next")
    frame.nextBtn:SetScript("OnClick", function()
        Tutorial:NextStep()
    end)

    frame:Hide()
    return frame
end

-- Mockup interrupt tracker for tutorial (when player hasn't learned interrupt yet)
local mockupInterruptFrame = nil
local function CreateMockupInterruptTracker()
    if mockupInterruptFrame then
        mockupInterruptFrame:Show()
        return mockupInterruptFrame
    end

    local db = CastbornDB.interrupt or {width = 100, height = 16}
    local frame = CreateFrame("Frame", "Castborn_TutorialInterrupt", UIParent, "BackdropTemplate")
    frame:SetSize(db.width or 100, db.height or 16)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -280)
    frame:SetFrameStrata("MEDIUM")

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)

    -- Icon (use Counterspell icon as example)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(db.height or 16, db.height or 16)
    frame.icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.icon:SetTexture("Interface\\Icons\\Spell_Frost_IceShock")
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Status bar
    frame.bar = CreateFrame("StatusBar", nil, frame)
    frame.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", (db.height or 16) + 2, -1)
    frame.bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(1)
    frame.bar:SetStatusBarColor(0.2, 0.8, 0.2, 1)

    -- Ready text
    frame.ready = frame:CreateFontString(nil, "OVERLAY")
    frame.ready:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    frame.ready:SetPoint("CENTER", frame.bar, "CENTER")
    frame.ready:SetText("READY")
    frame.ready:SetTextColor(0.2, 1, 0.2, 1)

    mockupInterruptFrame = frame
    frame:Show()
    return frame
end

-- Show a test/demo version of a frame
local function ShowTestFrame(frameId)
    local CB = Castborn

    -- Enable castbar test mode to prevent update from hiding bars
    if CB.TestCastbars then CB:TestCastbars() end

    if frameId == "player_castbar" then
        -- Show test player castbar with latency indicator
        if CB.castbars and CB.castbars.player then
            local frame = CB.castbars.player
            local cfg = CB.db and CB.db.player or {}
            frame.bar:SetMinMaxValues(0, 1)
            frame.bar:SetValue(0.6)
            frame.bar:SetStatusBarColor(cfg.barColor and cfg.barColor[1] or 0.6, cfg.barColor and cfg.barColor[2] or 0.6, cfg.barColor and cfg.barColor[3] or 0.9, 1)
            if frame.spellText then frame.spellText:SetText("Frostbolt") end
            if frame.timeText then frame.timeText:SetText("1.2s") end
            if frame.icon then frame.icon:SetTexture("Interface\\Icons\\Spell_Frost_FrostBolt02") end
            if frame.iconFrame then frame.iconFrame:Show() end
            -- Show latency indicator (~350ms mockup)
            if frame.latency then
                local barWidth = frame.bar:GetWidth()
                local latencyWidth = barWidth * 0.14
                frame.latency:SetWidth(latencyWidth)
                frame.latency:Show()
            end
            frame:SetAlpha(1)
            frame:Show()
            return frame
        end
    elseif frameId == "gcd" then
        if CB.TestGCD then CB:TestGCD() end
        if CB.gcdFrame then
            CB.gcdFrame:Show()
            return CB.gcdFrame
        end
    elseif frameId == "fsr" then
        if CB.TestFSR then CB:TestFSR() end
        if CB.fsrFrame then
            return CB.fsrFrame
        end
    elseif frameId == "cooldowns" then
        if CB.TestCooldowns then CB:TestCooldowns() end
        local frame = _G["Castborn_CooldownTracker"]
        if frame then
            return frame
        end
    elseif frameId == "target_castbar" then
        if CB.castbars and CB.castbars.target then
            local frame = CB.castbars.target
            local cfg = CB.db and CB.db.target or {}
            -- Set casting state to keep bar visible
            frame.casting = true
            frame.channeling = false
            frame.fadeOut = 0
            frame.startTime = GetTime()
            frame.endTime = GetTime() + 99
            frame.bar:SetMinMaxValues(0, 1)
            frame.bar:SetValue(0.4)
            frame.bar:SetStatusBarColor(cfg.barColor and cfg.barColor[1] or 0.9, cfg.barColor and cfg.barColor[2] or 0.4, cfg.barColor and cfg.barColor[3] or 0.4, 1)
            if frame.spellText then frame.spellText:SetText("Shadow Bolt") end
            if frame.timeText then frame.timeText:SetText("2.1s") end
            if frame.icon then frame.icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt") end
            if frame.iconFrame then frame.iconFrame:Show() end
            if frame.spark then frame.spark:Hide() end
            frame:SetAlpha(1)
            frame:Show()
            return frame
        end
    elseif frameId == "targettarget_castbar" then
        if CB.castbars and CB.castbars.targettarget then
            local frame = CB.castbars.targettarget
            local cfg = CB.db and CB.db.targettarget or {}
            -- Set casting state to keep bar visible
            frame.casting = true
            frame.channeling = false
            frame.fadeOut = 0
            frame.startTime = GetTime()
            frame.endTime = GetTime() + 99
            frame.bar:SetMinMaxValues(0, 1)
            frame.bar:SetValue(0.35)
            frame.bar:SetStatusBarColor(cfg.barColor and cfg.barColor[1] or 0.7, cfg.barColor and cfg.barColor[2] or 0.5, cfg.barColor and cfg.barColor[3] or 0.8, 1)
            if frame.spellText then frame.spellText:SetText("Shadow Bolt") end
            if frame.timeText then frame.timeText:SetText("1.8s") end
            if frame.icon then frame.icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt") end
            if frame.iconFrame then frame.iconFrame:Show() end
            if frame.spark then frame.spark:Hide() end
            frame:SetAlpha(1)
            frame:Show()
            return frame
        end
    elseif frameId == "focus_castbar" then
        if CB.castbars and CB.castbars.focus then
            local frame = CB.castbars.focus
            local cfg = CB.db and CB.db.focus or {}
            -- Set casting state to keep bar visible
            frame.casting = true
            frame.channeling = false
            frame.fadeOut = 0
            frame.startTime = GetTime()
            frame.endTime = GetTime() + 99
            frame.bar:SetMinMaxValues(0, 1)
            frame.bar:SetValue(0.7)
            frame.bar:SetStatusBarColor(cfg.barColor and cfg.barColor[1] or 0.3, cfg.barColor and cfg.barColor[2] or 0.7, cfg.barColor and cfg.barColor[3] or 0.9, 1)
            if frame.spellText then frame.spellText:SetText("Greater Heal") end
            if frame.timeText then frame.timeText:SetText("2.5s") end
            if frame.icon then frame.icon:SetTexture("Interface\\Icons\\Spell_Holy_GreaterHeal") end
            if frame.iconFrame then frame.iconFrame:Show() end
            if frame.spark then frame.spark:Hide() end
            frame:SetAlpha(1)
            frame:Show()
            return frame
        end
    elseif frameId == "dots" then
        -- Call the test function to populate with example data
        if CB.TestDoTTracker then CB:TestDoTTracker() end
        local frame = _G["Castborn_DoTTracker"]
        if frame then
            return frame
        end
    elseif frameId == "multidot" then
        -- Call the test function to populate with example data
        if CB.TestMultiDoT then CB:TestMultiDoT() end
        local frame = _G["Castborn_MultiDoTTracker"]
        if frame then
            return frame
        end
    elseif frameId == "procs" then
        if CB.TestProcs then CB:TestProcs() end
        local frame = _G["Castborn_ProcTracker"]
        if frame then
            return frame
        end
    elseif frameId == "swing" then
        -- Start test swing timers to populate the bars
        if CB.TestSwingTimers then
            CB:TestSwingTimers()
        end
        local container = CB.swingTimers and CB.swingTimers.container
        if container then
            return container
        end
    elseif frameId == "interrupt" then
        if CB.TestInterrupt then CB:TestInterrupt() end
        local frame = _G["Castborn_Interrupt"] or _G["Castborn_Interrupt_Mock"]
        if frame then
            return frame
        else
            -- Create a mockup interrupt tracker for the tutorial
            return CreateMockupInterruptTracker()
        end
    elseif frameId == "totems" then
        if CB.TestTotemTracker then CB:TestTotemTracker() end
        local frame = _G["Castborn_TotemTracker"]
        if frame then
            return frame
        end
    elseif frameId == "absorbs" then
        if CB.TestAbsorbTracker then CB:TestAbsorbTracker() end
        local frame = _G["Castborn_AbsorbTracker"]
        if frame then
            return frame
        end
    end

    return nil
end

-- Highlight a specific frame with spotlight effect
local function HighlightFrame(targetFrame)
    if not highlightFrame then
        highlightFrame = CreateHighlightFrame()
    end

    -- Restore any previously raised frames
    RestoreAllFrames()

    if targetFrame then
        -- Make sure the frame is visible
        targetFrame:Show()

        -- Raise the target frame above the spotlight
        RaiseFrameAboveSpotlight(targetFrame)

        -- Also raise the icon frame if this is a castbar with an icon
        if targetFrame.iconFrame then
            RaiseFrameAboveSpotlight(targetFrame.iconFrame)
        end

        -- Position and show the spotlight overlay
        PositionSpotlight(targetFrame, 20)

        -- Position highlight border around the frame
        highlightFrame:ClearAllPoints()
        highlightFrame:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", -8, 8)
        highlightFrame:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", 8, -8)
        highlightFrame:Show()
    else
        -- No target - show dim overlay for welcome/complete screens
        PositionSpotlight(nil)
        highlightFrame:Hide()
    end
end

-- Show a specific tutorial step
local function ShowStep(stepNum)
    if stepNum < 1 or stepNum > #steps then return end

    currentStep = stepNum
    local step = steps[stepNum]

    if not tutorialFrame then
        tutorialFrame = CreateTutorialFrame()
    end

    -- Update step counter
    tutorialFrame.stepText:SetText(string.format("Step %d of %d", stepNum, #steps))

    -- Update content
    tutorialFrame.title:SetText(step.title)
    tutorialFrame.description:SetText(step.description)
    tutorialFrame.tip:SetText(step.tip or "")
    tutorialFrame.tipIcon:SetShown(step.tip and step.tip ~= "")

    -- Update button states
    tutorialFrame.backBtn:SetEnabled(stepNum > 1)
    if stepNum == #steps then
        tutorialFrame.nextBtn:SetText("Finish")
    else
        tutorialFrame.nextBtn:SetText("Next")
    end

    -- Handle enable checkbox
    if step.configKey then
        local configKey = step.configKey
        local db = CastbornDB[configKey]

        -- Set checkbox state based on current setting
        tutorialFrame.enableCheck:SetChecked(db and db.enabled)

        -- Wire up the click handler
        tutorialFrame.enableCheck:SetScript("OnClick", function(self)
            if CastbornDB[configKey] then
                CastbornDB[configKey].enabled = self:GetChecked()
                Castborn:Print(step.title .. " " .. (self:GetChecked() and "enabled" or "disabled"))
            end
        end)

        tutorialFrame.enableCheck:Show()
        tutorialFrame.enableCheck.text:Show()

        -- Adjust tip position when checkbox is visible
        tutorialFrame.tipIcon:SetPoint("BOTTOMLEFT", 16, 72)
    else
        tutorialFrame.enableCheck:Hide()
        tutorialFrame.enableCheck.text:Hide()

        -- Reset tip position when checkbox is hidden
        tutorialFrame.tipIcon:SetPoint("BOTTOMLEFT", 16, 52)
    end

    -- Show test frame and highlight it
    local targetFrame = nil

    -- First try to show a test version of the frame
    if step.id then
        targetFrame = ShowTestFrame(step.id)
    end

    -- Fall back to getFrame if no test frame was shown
    if not targetFrame and step.getFrame then
        targetFrame = step.getFrame()
        if targetFrame then
            targetFrame:Show()
        end
    end

    HighlightFrame(targetFrame)

    -- Execute any action for this step
    if step.action then
        step.action()
    end

    tutorialFrame:Show()
end

-- Public API
function Tutorial:Start()
    if isActive then return end
    isActive = true
    currentStep = 0

    -- Show first step (test frames are shown per-step)
    self:NextStep()
    Castborn:Print("Tutorial started. Follow the steps to learn about Castborn!")
end

-- Check if a step should be shown for the current player class
local function ShouldShowStep(stepNum)
    local step = steps[stepNum]
    if not step then return false end
    if not step.class then return true end
    local _, playerClass = UnitClass("player")
    return step.class == playerClass
end

function Tutorial:NextStep()
    local nextStep = currentStep + 1
    -- Skip steps that don't match the player's class
    while nextStep <= #steps and not ShouldShowStep(nextStep) do
        nextStep = nextStep + 1
    end
    if nextStep > #steps then
        self:End()
        return
    end
    ShowStep(nextStep)
end

function Tutorial:PreviousStep()
    local prevStep = currentStep - 1
    -- Skip steps that don't match the player's class
    while prevStep >= 1 and not ShouldShowStep(prevStep) do
        prevStep = prevStep - 1
    end
    if prevStep < 1 then return end
    ShowStep(prevStep)
end

function Tutorial:End()
    isActive = false
    currentStep = 0

    -- Restore all raised frames to original strata/level
    RestoreAllFrames()

    -- End all test modes
    local CB = Castborn
    if CB.EndTestCastbars then CB:EndTestCastbars() end
    if CB.EndTestGCD then CB:EndTestGCD() end
    if CB.EndTestFSR then CB:EndTestFSR() end
    if CB.EndTestSwingTimers then CB:EndTestSwingTimers() end
    if CB.EndTestCooldowns then CB:EndTestCooldowns() end
    if CB.EndTestProcs then CB:EndTestProcs() end
    if CB.EndTestInterrupt then CB:EndTestInterrupt() end
    if CB.EndTestDoTTracker then CB:EndTestDoTTracker() end
    if CB.EndTestMultiDoT then CB:EndTestMultiDoT() end
    if CB.EndTestTotemTracker then CB:EndTestTotemTracker() end
    if CB.EndTestAbsorbTracker then CB:EndTestAbsorbTracker() end

    if tutorialFrame then
        tutorialFrame:Hide()
    end
    if highlightFrame then
        highlightFrame:Hide()
    end
    if spotlightOverlay then
        spotlightOverlay:Hide()
    end
    if mockupInterruptFrame then
        mockupInterruptFrame:Hide()
    end

    -- Mark tutorial as complete
    CastbornDB.tutorialComplete = true

    -- Hide options if we opened it
    if Castborn.Options then
        Castborn.Options:Hide()
    end

    Castborn:Print("Tutorial complete! Use |cff88ddff/cb tutorial|r to replay anytime.")
end

function Tutorial:IsActive()
    return isActive
end

function Tutorial:ShouldAutoStart()
    return not CastbornDB.tutorialComplete
end

-- Simple delay function for TBC Classic compatibility
local function DelayedCall(delay, func)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, func)
    else
        -- Fallback for TBC Classic
        local frame = CreateFrame("Frame")
        local elapsed = 0
        frame:SetScript("OnUpdate", function(self, delta)
            elapsed = elapsed + delta
            if elapsed >= delay then
                self:SetScript("OnUpdate", nil)
                func()
            end
        end)
    end
end

-- Register callback to auto-start on first run
Castborn:RegisterCallback("READY", function()
    -- Delay slightly to ensure all frames are created
    DelayedCall(1.5, function()
        if Tutorial:ShouldAutoStart() then
            Tutorial:Start()
        end
    end)
end)

Castborn:RegisterModule("Tutorial", Tutorial)

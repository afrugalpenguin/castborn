--[[
    Castborn - Tutorial/Onboarding System
    Step-by-step wizard that guides new users through each feature
]]

local Tutorial = {}
Castborn.Tutorial = Tutorial

local currentStep = 0
local tutorialFrame = nil
local highlightFrames = {}
local spotlightOverlay = nil
local isActive = false
local originalFrameInfo = {}  -- Store original strata/level for restoration

-- Tutorial steps configuration
-- configKey maps to CastbornDB[key].enabled for the enable checkbox
-- configKeys is an array of keys for merged steps with multiple toggles
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
        id = "castbar_companions",
        title = "Castbar Companions",
        description = "Two thin bars accompany your player castbar:\n\n|cff88ddff5 Second Rule|r \226\128\148 tracks the 5-second mana regeneration window. The bar turns green and pulses when spirit regen resumes.\n\n|cff88ddffGCD Indicator|r \226\128\148 sweeps left-to-right while your Global Cooldown is active, helping you time your next ability.",
        tip = "Both bars anchor to your player castbar by default.",
        getFrame = function() return Castborn.castbars and Castborn.castbars.player end,
        configKeys = {"fsr", "gcd"},
    },
    {
        id = "cooldowns",
        title = "Cooldown Tracker",
        description = "Track your important cooldowns like trinkets, major abilities, and class cooldowns. Icons show remaining cooldown and glow when ready.\n\nYou can reorder icons by dragging them in test mode.",
        tip = "Use the up/down arrows in Options > Cooldowns to reorder, or drag icons while in test mode.",
        getFrame = function() return _G["Castborn_CooldownTracker"] end,
        configKey = "cooldowns",
    },
    {
        id = "other_castbars",
        title = "Other Castbars",
        description = "Castborn provides castbars for your |cff88ddfftarget|r, |cff88ddfftarget-of-target|r, and |cff88ddfffocus|r.\n\nSee what enemies are casting so you can interrupt, or watch your healer's casts to anticipate incoming heals.",
        tip = "A shield icon appears on spells that cannot be interrupted.",
        getFrame = function() return Castborn.castbars and Castborn.castbars.target end,
        configKeys = {"target", "targettarget", "focus"},
    },
    {
        id = "dots",
        title = "DoT Tracking",
        description = "Track your damage-over-time effects on your current target with colour-coded urgency bars.\n\nThe |cff88ddffMulti-DoT Tracker|r extends this to multiple enemies, so you can keep them all dotted in AoE fights.",
        tip = "Red means expiring soon! Refresh your DoTs before they fall off.",
        getFrame = function() return _G["Castborn_DoTTracker"] end,
        configKeys = {"dots", "multidot"},
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
        title = "Defensive Trackers",
        description = "|cff88ddffAbsorb Tracker|r \226\128\148 tracks absorb shields like Ice Barrier, Power Word: Shield, and Fire/Shadow Ward. Shows remaining absorb with a drain effect; multiple shields display as a row of icons.\n\n|cff88ddffArmour Tracker|r \226\128\148 shows an alert icon when your class armour buff is missing (e.g. Mage Armour, Demon Skin). A quick reminder to rebuff after dying or zoning.",
        tip = "Both trackers work for all classes \226\128\148 Power Word: Shield from a healer is tracked automatically.",
        getFrame = function() return _G["Castborn_AbsorbTracker"] end,
        configKeys = {"absorbs", "armortracker"},
    },
    {
        id = "customise",
        title = "Customise & Position",
        description = "Make Castborn your own!\n\n|cff88ddff/cb|r \226\128\148 Open the options panel to adjust sizes, colours, and behaviours.\n|cff88ddff/cb unlock|r \226\128\148 Drag any frame to reposition it.\n|cff88ddff/cb grid|r \226\128\148 Show a positioning grid overlay.\n\n|cff88ddffCtrl+Shift+Click|r a module header to temporarily hide it when frames overlap.",
        tip = "Toggle borders globally in |cff88ddffLook & Feel|r, or set per-module background colour in each module's page.",
        frame = nil,
    },
    {
        id = "complete",
        title = "Setup Complete!",
        description = "Castborn's modules are now enabled to your preferences.\n\nTo customise them further, open the options panel with |cff88ddff/cb|r or use |cff88ddff/cb unlock|r to reposition frames.\n\nIf you'd like to configure the layout now:",
        tip = "I hope you enjoy using Castborn \226\128\148 GLHF!",
        frame = nil,
    },
}

-- Human-readable labels for configKey values (used by multi-checkbox merged steps)
local configKeyLabels = {
    gcd = "GCD Indicator",
    fsr = "5 Second Rule",
    target = "Target Castbar",
    targettarget = "Target-of-Target",
    focus = "Focus Castbar",
    dots = "DoT Tracker",
    multidot = "Multi-DoT Tracker",
    absorbs = "Absorb Tracker",
    armortracker = "Armour Tracker",
}

-- Create a highlight frame that surrounds a target element
local function CreateHighlightFrame(index)
    local frame = CreateFrame("Frame", "CastbornTutorialHighlight" .. (index or 1), UIParent, "BackdropTemplate")
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

-- Create the spotlight overlay (dims everything except focused elements)
local function CreateSpotlightOverlay()
    local overlay = CreateFrame("Frame", "CastbornTutorialSpotlight", UIParent)
    overlay:SetFrameStrata("FULLSCREEN")
    overlay:SetFrameLevel(50)
    overlay:SetAllPoints(UIParent)

    -- Pool of dark panels used to dim the screen around spotlight holes
    overlay.panels = {}

    local function GetPanel(index)
        if not overlay.panels[index] then
            local tex = overlay:CreateTexture(nil, "BACKGROUND")
            tex:SetColorTexture(0, 0, 0, 0.75)
            tex:Hide()
            overlay.panels[index] = tex
        end
        return overlay.panels[index]
    end
    overlay.GetPanel = GetPanel

    -- Fade in/out animation state
    overlay.targetAlpha = 0.75
    overlay.currentAlpha = 0
    overlay.activePanels = 0

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
            for i = 1, self.activePanels do
                self.panels[i]:SetAlpha(a)
            end
        end
    end)

    overlay:Hide()
    return overlay
end

-- Compute bounding box across one or more frames
local function ComputeBoundingBox(frames, padding)
    padding = padding or 15
    local left, right, top, bottom

    for _, f in ipairs(frames) do
        if f and f:IsShown() and f:GetLeft() then
            local fl, fr, ft, fb = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
            left = left and min(left, fl) or fl
            right = right and max(right, fr) or fr
            top = top and max(top, ft) or ft
            bottom = bottom and min(bottom, fb) or fb
        end
    end

    if not left then return nil end
    return left - padding, right + padding, top + padding, bottom - padding
end

-- Hide all spotlight panels
local function HideSpotlightPanels()
    if not spotlightOverlay then return end
    for _, p in ipairs(spotlightOverlay.panels) do
        p:Hide()
    end
    spotlightOverlay.activePanels = 0
end

-- Add a positioned dark panel to the spotlight overlay
local function AddSpotlightPanel(l, r, t, b)
    if r <= l or t <= b then return end -- skip zero-size panels
    local idx = spotlightOverlay.activePanels + 1
    local panel = spotlightOverlay.GetPanel(idx)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
    panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", r, b)
    panel:SetAlpha(spotlightOverlay.currentAlpha)
    panel:Show()
    spotlightOverlay.activePanels = idx
end

-- Position spotlight with individual holes around each target frame
-- Uses a scanline algorithm to correctly handle any frame arrangement
local function PositionSpotlight(frames, padding)
    if not spotlightOverlay then
        spotlightOverlay = CreateSpotlightOverlay()
    end

    padding = padding or 15
    HideSpotlightPanels()

    -- Collect padded bounds for each visible frame (including icon frames)
    local holes = {}
    for _, f in ipairs(frames) do
        if f and f:IsShown() and f.GetLeft and f:GetLeft() then
            local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
            -- Expand bounds to include icon frame if present
            if f.iconFrame and f.iconFrame:IsShown() and f.iconFrame:GetLeft() then
                l = min(l, f.iconFrame:GetLeft())
                r = max(r, f.iconFrame:GetRight())
                t = max(t, f.iconFrame:GetTop())
                b = min(b, f.iconFrame:GetBottom())
            end
            tinsert(holes, {
                l = l - padding,
                r = r + padding,
                t = t + padding,
                b = b - padding,
            })
        end
    end

    local sw = GetScreenWidth()
    local sh = GetScreenHeight()

    if #holes == 0 then
        -- No targets - dim the whole screen
        AddSpotlightPanel(0, sw, sh, 0)
        spotlightOverlay.targetAlpha = 0.6
        spotlightOverlay:Show()
        return
    end

    -- Collect unique Y edges sorted descending (screen top to bottom)
    local ySet = {}
    ySet[sh] = true
    ySet[0] = true
    for _, h in ipairs(holes) do
        ySet[h.t] = true
        ySet[h.b] = true
    end
    local yEdges = {}
    for y in pairs(ySet) do
        tinsert(yEdges, y)
    end
    table.sort(yEdges, function(a, b) return a > b end)

    -- Scanline: for each horizontal band between consecutive Y edges,
    -- find which holes are active and create dark panels around them
    for i = 1, #yEdges - 1 do
        local bandTop = yEdges[i]
        local bandBot = yEdges[i + 1]

        -- Find holes that span this band
        local active = {}
        for _, h in ipairs(holes) do
            if h.t >= bandTop and h.b <= bandBot then
                tinsert(active, h)
            end
        end

        if #active == 0 then
            -- No holes in this band - fill it entirely
            AddSpotlightPanel(0, sw, bandTop, bandBot)
        else
            -- Sort active holes left-to-right
            table.sort(active, function(a, b) return a.l < b.l end)

            -- Dark panel from screen left to first hole
            AddSpotlightPanel(0, active[1].l, bandTop, bandBot)

            -- Dark panels between consecutive holes
            for j = 1, #active - 1 do
                AddSpotlightPanel(active[j].r, active[j + 1].l, bandTop, bandBot)
            end

            -- Dark panel from last hole to screen right
            AddSpotlightPanel(active[#active].r, sw, bandTop, bandBot)
        end
    end

    spotlightOverlay.targetAlpha = 0.75
    spotlightOverlay:Show()
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
    frame:SetSize(450, 290)
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
    frame.description:SetJustifyH("CENTER")
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

    -- Enable checkboxes (pool of 3 for merged steps with multiple toggles)
    frame.enableChecks = {}
    for i = 1, 3 do
        local cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        cb.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.text:SetTextColor(0.9, 0.9, 0.9, 1)
        cb:Hide()
        frame.enableChecks[i] = cb
    end

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

    -- Test Mode button (shown only on final step)
    frame.testModeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.testModeBtn:SetSize(100, 22)
    frame.testModeBtn:SetPoint("TOP", frame.description, "BOTTOM", 0, -8)
    frame.testModeBtn:SetText("Test Mode")
    frame.testModeBtn:SetScript("OnClick", function()
        Tutorial:End()
        Castborn:EnterTestMode()
    end)
    frame.testModeBtn:Hide()
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
    frame.bar:SetStatusBarTexture(Castborn:GetBarTexture())
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(1)
    frame.bar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
    Castborn:RegisterBarFrame(frame.bar)

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
    elseif frameId == "castbar_companions" then
        -- Show GCD + FSR test, highlight only enabled companion bars
        local frames = {}
        if CastbornDB.fsr and CastbornDB.fsr.enabled then
            if CB.TestFSR then CB:TestFSR() end
            if CB.fsrFrame then tinsert(frames, CB.fsrFrame) end
        else
            if CB.EndTestFSR then CB:EndTestFSR() end
        end
        if CastbornDB.gcd and CastbornDB.gcd.enabled then
            if CB.TestGCD then CB:TestGCD() end
            if CB.gcdFrame then tinsert(frames, CB.gcdFrame) end
        else
            if CB.EndTestGCD then CB:EndTestGCD() end
        end
        -- Include the player castbar for context
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
            frame:SetAlpha(1)
            frame:Show()
            tinsert(frames, frame)
        end
        if #frames > 0 then
            frames.grouped = true
            return frames
        end
    elseif frameId == "cooldowns" then
        if CB.TestCooldowns then CB:TestCooldowns() end
        -- Return both frames as a group so they share one highlight border
        local cd = _G["Castborn_CooldownTracker"]
        local trinkets = _G["Castborn_TrinketTracker"]
        if cd and trinkets and trinkets:IsShown() then
            return {cd, trinkets, grouped = true}
        elseif cd then
            return cd
        end
    elseif frameId == "other_castbars" then
        -- Show enabled castbars: target, target-of-target, focus
        local frames = {}
        local castbarData = {
            {key = "target",       spell = "Shadow Bolt",  icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt",  val = 0.4,  r = 0.9, g = 0.4, b = 0.4},
            {key = "targettarget", spell = "Shadow Bolt",  icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt",  val = 0.35, r = 0.7, g = 0.5, b = 0.8},
            {key = "focus",        spell = "Greater Heal", icon = "Interface\\Icons\\Spell_Holy_GreaterHeal",   val = 0.7,  r = 0.3, g = 0.7, b = 0.9},
        }
        for _, data in ipairs(castbarData) do
            local db = CastbornDB[data.key]
            local frame = CB.castbars and CB.castbars[data.key]
            if frame and db and db.enabled then
                local cfg = CB.db and CB.db[data.key] or {}
                frame.casting = true
                frame.channeling = false
                frame.fadeOut = 0
                frame.startTime = GetTime()
                frame.endTime = GetTime() + 99
                frame.bar:SetMinMaxValues(0, 1)
                frame.bar:SetValue(data.val)
                frame.bar:SetStatusBarColor(cfg.barColor and cfg.barColor[1] or data.r, cfg.barColor and cfg.barColor[2] or data.g, cfg.barColor and cfg.barColor[3] or data.b, 1)
                if frame.spellText then frame.spellText:SetText(data.spell) end
                if frame.timeText then frame.timeText:SetText(string.format("%.1fs", data.val * 3)) end
                if frame.icon then frame.icon:SetTexture(data.icon) end
                if frame.iconFrame then frame.iconFrame:Show() end
                if frame.spark then frame.spark:Hide() end
                frame:SetAlpha(1)
                frame:Show()
                tinsert(frames, frame)
            elseif frame then
                frame.casting = false
                frame:Hide()
            end
        end
        if #frames > 0 then return frames end
    elseif frameId == "dots" then
        -- Show enabled DoT trackers
        local frames = {}
        if CastbornDB.dots and CastbornDB.dots.enabled then
            if CB.TestDoTTracker then CB:TestDoTTracker() end
            local dot = _G["Castborn_DoTTracker"]
            if dot then tinsert(frames, dot) end
        else
            if CB.EndTestDoTTracker then CB:EndTestDoTTracker() end
        end
        if CastbornDB.multidot and CastbornDB.multidot.enabled then
            if CB.TestMultiDoT then CB:TestMultiDoT() end
            local mdot = _G["Castborn_MultiDoTTracker"]
            if mdot then tinsert(frames, mdot) end
        else
            if CB.EndTestMultiDoT then CB:EndTestMultiDoT() end
        end
        if #frames > 0 then return frames end
    elseif frameId == "procs" then
        if CB.TestProcs then CB:TestProcs() end
        local frame = _G["Castborn_ProcTracker"]
        if frame then return frame end
    elseif frameId == "swing" then
        if CB.TestSwingTimers then CB:TestSwingTimers() end
        local container = CB.swingTimers and CB.swingTimers.container
        if container then return container end
    elseif frameId == "interrupt" then
        if CB.TestInterrupt then CB:TestInterrupt() end
        local frame = _G["Castborn_Interrupt"] or _G["Castborn_Interrupt_Mock"]
        if frame then
            return frame
        else
            return CreateMockupInterruptTracker()
        end
    elseif frameId == "totems" then
        if CB.TestTotemTracker then CB:TestTotemTracker() end
        local frame = _G["Castborn_TotemTracker"]
        if frame then return frame end
    elseif frameId == "absorbs" then
        local frames = {}
        if CastbornDB.absorbs and CastbornDB.absorbs.enabled then
            if CB.TestAbsorbTracker then CB:TestAbsorbTracker() end
            local f = _G["Castborn_AbsorbTracker"]
            if f then tinsert(frames, f) end
        else
            if CB.EndTestAbsorbTracker then CB:EndTestAbsorbTracker() end
        end
        if CastbornDB.armortracker and CastbornDB.armortracker.enabled then
            if CB.TestArmorTracker then CB:TestArmorTracker() end
            local f = _G["Castborn_ArmorTracker"]
            if f then tinsert(frames, f) end
        else
            if CB.EndTestArmorTracker then CB:EndTestArmorTracker() end
        end
        if #frames > 0 then return frames end
    elseif frameId == "customise" then
        -- No specific frame to highlight — this step explains commands
        return nil
    end

    return nil
end

-- Get or create a highlight frame from the pool
local function GetHighlightFrame(index)
    if not highlightFrames[index] then
        highlightFrames[index] = CreateHighlightFrame(index)
    end
    return highlightFrames[index]
end

-- Hide all highlight frames
local function HideAllHighlights()
    for _, hf in ipairs(highlightFrames) do
        hf:Hide()
    end
end

-- Highlight one or more frames with spotlight effect
-- targetFrames can be a single frame or a table of frames
local function HighlightFrame(targetFrames)
    -- Restore any previously raised frames
    RestoreAllFrames()
    HideAllHighlights()

    -- Normalise to a table
    if targetFrames and not targetFrames[1] then
        targetFrames = {targetFrames}
    end

    if targetFrames and #targetFrames > 0 then
        -- Raise all target frames above the spotlight
        for _, f in ipairs(targetFrames) do
            f:Show()
            RaiseFrameAboveSpotlight(f)
            if f.iconFrame then
                RaiseFrameAboveSpotlight(f.iconFrame)
            end
        end

        if #targetFrames == 1 or targetFrames.grouped then
            -- Single frame or grouped frames: spotlight hole + one bounding highlight
            PositionSpotlight(targetFrames, 20)
            local left, right, top, bottom = ComputeBoundingBox(targetFrames, 8)
            if left then
                local hf = GetHighlightFrame(1)
                hf:ClearAllPoints()
                hf:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
                hf:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right, bottom)
                hf:Show()
            end
        else
            -- Multiple scattered frames: individual holes + individual highlight per frame
            PositionSpotlight(targetFrames, 20)
            for i, f in ipairs(targetFrames) do
                local hf = GetHighlightFrame(i)
                hf:ClearAllPoints()
                hf:SetPoint("TOPLEFT", f, "TOPLEFT", -8, 8)
                hf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 8, -8)
                hf:Show()
            end
        end
    else
        -- No target - show dim overlay for welcome/complete screens
        PositionSpotlight({})
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
        tutorialFrame.testModeBtn:Show()
    else
        tutorialFrame.nextBtn:SetText("Next")
        tutorialFrame.testModeBtn:Hide()
    end

    -- Handle enable checkboxes (single configKey or merged configKeys)
    local keys = step.configKeys or (step.configKey and {step.configKey}) or nil
    local numChecks = keys and #keys or 0

    -- Hide all checkboxes first
    for i = 1, 3 do
        tutorialFrame.enableChecks[i]:Hide()
        tutorialFrame.enableChecks[i].text:Hide()
    end

    if keys then
        for i, key in ipairs(keys) do
            local cb = tutorialFrame.enableChecks[i]
            local db = CastbornDB[key]

            -- Position: stack from bottom, first key at top
            cb:ClearAllPoints()
            cb:SetPoint("BOTTOMLEFT", 16, 42 + (numChecks - i) * 24)

            -- Set checkbox state based on current setting
            cb:SetChecked(db and db.enabled)

            -- Label: generic for single-key steps, specific for merged steps
            if numChecks == 1 then
                cb.text:SetText("Enable this module")
            else
                cb.text:SetText("Enable " .. (configKeyLabels[key] or key))
            end

            -- Wire up the click handler — toggle setting and refresh the step
            cb:SetScript("OnClick", function(self)
                if CastbornDB[key] then
                    CastbornDB[key].enabled = self:GetChecked()
                    local label = configKeyLabels[key] or step.title
                    Castborn:Print(label .. " " .. (self:GetChecked() and "enabled" or "disabled"))
                    -- Refresh the step to update visible frames and highlights
                    ShowStep(currentStep)
                end
            end)

            cb:Show()
            cb.text:Show()
        end

        -- Adjust tip position based on number of checkboxes
        tutorialFrame.tipIcon:ClearAllPoints()
        tutorialFrame.tipIcon:SetPoint("BOTTOMLEFT", 16, 42 + numChecks * 24 + 6)
    else
        -- Reset tip position when no checkboxes
        tutorialFrame.tipIcon:ClearAllPoints()
        tutorialFrame.tipIcon:SetPoint("BOTTOMLEFT", 16, 52)
    end

    -- Show test frame(s) and highlight them
    local targetFrames = nil

    -- First try to show a test version of the frame
    if step.id then
        targetFrames = ShowTestFrame(step.id)
    end

    -- Fall back to getFrame if no test frame was shown
    if not targetFrames and step.getFrame then
        local f = step.getFrame()
        if f then
            f:Show()
            targetFrames = f
        end
    end

    HighlightFrame(targetFrames)

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
    if CB.EndTestArmorTracker then CB:EndTestArmorTracker() end

    if tutorialFrame then
        tutorialFrame:Hide()
    end
    HideAllHighlights()
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

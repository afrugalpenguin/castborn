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

-- Highlighted words in step text: the options window's heading gold
local HL = "|cfff0cf7a"

-- Tutorial steps configuration
-- configKey maps to CastbornDB[key].enabled for the enable checkbox
-- configKeys is an array of keys for merged steps with multiple toggles
-- module, if set, names a Castborn module the step needs (skipped when this build lacks it)
local steps = {
    {
        id = "welcome",
        title = "Welcome to Castborn",
        description = "A quick tour of what Castborn can show you. Each page lights up one part of your screen, and you can switch that part on or off as you go.\n\nIt takes about a minute.",
        tip = "Replay this tour any time with " .. HL .. "/cb tutorial|r.",
        frame = nil,
    },
    {
        id = "player_castbar",
        title = "Player Castbar",
        description = "Your casts and channels, with the spell, its icon and the time left.",
        tip = "The red end of the bar is your latency. Start your next cast when the bar reaches it and you lose no time between casts.",
        getFrame = function() return Castborn.castbars and Castborn.castbars.player end,
        -- No configKey - player castbar is always enabled
    },
    {
        id = "castbar_companions",
        title = "Castbar Companions",
        description = "Two thin bars sit with your castbar.\n\n" .. HL .. "5 Second Rule|r shows the five seconds after you spend mana, while spirit regen is paused. It turns green and pulses once regen is back.\n\n" .. HL .. "GCD Indicator|r sweeps across while your global cooldown runs, so you know when your next ability is ready.",
        tip = "Both follow your player castbar unless you detach them.",
        getFrame = function() return Castborn.castbars and Castborn.castbars.player end,
        configKeys = {"fsr", "gcd"},
    },
    {
        id = "cooldowns",
        title = "Cooldown Tracker",
        description = "Icons for the cooldowns that matter: class spells, trinkets and racials. Each one counts down and glows when it is ready.",
        tip = "Change the order with the arrows in " .. HL .. "Options > Cooldowns|r, or drag icons in test mode.",
        getFrame = function() return _G["Castborn_CooldownTracker"] end,
        configKey = "cooldowns",
    },
    {
        id = "cooldowntext",
        title = "Cooldown Text",
        description = "Countdown numbers on your action bars (Bartender4 included) and on Castborn's icons. They turn yellow under a minute and red under five seconds.\n\nWhen a cooldown comes back, the button can pulse, burst or flash.",
        tip = "Pick the colours and the finish effect in " .. HL .. "Options > Cooldown Text|r.",
        configKey = "cooldowntext",
        module = "CooldownText",
    },
    {
        id = "items",
        title = "Item Tracker",
        description = "Your consumables at a glance, with how many you carry. An icon greys out while the item is on cooldown or when you run out.",
        tip = "Add any item by its ID in " .. HL .. "Options > Items|r. Handy for potions, healthstones and bandages.",
        getFrame = function() return _G["Castborn_ItemTracker"] end,
        configKey = "itemtracker",
    },
    {
        id = "other_castbars",
        title = "Other Castbars",
        description = "Castbars for your " .. HL .. "target|r, their " .. HL .. "target|r and your " .. HL .. "focus|r.\n\nSee what an enemy is casting in time to interrupt it, or follow your healer's casts.",
        tip = "A shield on the icon means the spell cannot be interrupted.",
        getFrame = function() return Castborn.castbars and Castborn.castbars.target end,
        configKeys = {"target", "targettarget", "focus"},
    },
    {
        id = "dots",
        title = "DoT Tracking",
        description = "Your damage over time on your target, as bars that change colour as they run out.\n\nThe " .. HL .. "Multi-DoT Tracker|r does the same for every enemy you have dotted, for fights with several targets.",
        tip = "Red means it is about to fall off: refresh it.",
        getFrame = function() return _G["Castborn_DoTTracker"] end,
        configKeys = {"dots", "multidot"},
    },
    {
        id = "procs",
        title = "Proc Tracker",
        description = "Procs and short buffs worth reacting to, such as Clearcasting, Nightfall and trinket procs. They pulse when they appear.",
        tip = "Choose which procs to show in " .. HL .. "Options > Proc Tracker|r.",
        getFrame = function() return _G["Castborn_ProcTracker"] end,
        configKey = "procs",
        optionKey = "buffs",  -- the proc options page id differs from its saved variables key
    },
    {
        id = "swing",
        title = "Swing Timer",
        description = "For melee and hunters: when your next main hand, off hand and ranged attacks land.",
        tip = "Fit your abilities between swings without delaying them.",
        getFrame = function() return _G["Castborn_SwingTimer"] end,
        configKey = "swing",
    },
    {
        id = "interrupt",
        title = "Interrupt Tracker",
        description = "Your interrupt's cooldown, and how long an enemy is locked out of a school of magic after you interrupt them.",
        tip = "The bar shows " .. HL .. "READY|r when you can interrupt again.",
        getFrame = function() return _G["Castborn_InterruptTracker"] end,
        configKey = "interrupt",
    },
    {
        id = "totems",
        title = "Totem Tracker",
        description = "Your active totems for each element, with the time left on each.",
        tip = "Hover over a totem bar to see which party members are out of its range.",
        getFrame = function() return _G["Castborn_TotemTracker"] end,
        configKey = "totems",
    },
    {
        id = "absorbs",
        title = "Absorb Tracker",
        description = "Your absorb shields, such as Ice Barrier, Power Word: Shield and the elemental Wards. Each icon drains as its shield soaks damage.",
        tip = "When an icon is nearly empty, that shield is about to break.",
        getFrame = function() return _G["Castborn_AbsorbTracker"] end,
        configKey = "absorbs",
    },
    {
        id = "armour",
        title = "Armour Tracker",
        description = "An alert when your self-buff is missing, such as Mage Armour or Demon Skin, so you rebuff after dying or zoning.\n\nPaladins get alerts for their chosen " .. HL .. "Blessing|r (Might, Wisdom, Kings or Sanctuary), their " .. HL .. "Aura|r, and " .. HL .. "Righteous Fury|r when Improved Righteous Fury is talented (or always, if you choose).",
        tip = "Paladins choose the blessing to watch in " .. HL .. "Options > Armour|r.",
        getFrame = function() return _G["Castborn_ArmorTracker"] end,
        configKey = "armortracker",
    },
    {
        id = "seals",
        title = "Seal Tracker",
        description = "Your active seal, with a sweep for the time it has left.\n\nWhen no seal is up, the icon turns red with a |cffff3333!|r so you can reseal before a pull or after Judgement.",
        tip = "Turn the warning off, or limit it to combat, in " .. HL .. "Options > Seals|r.",
        getFrame = function() return _G["Castborn_SealTracker"] end,
        configKey = "seals",
    },
    {
        id = "customise",
        title = "Make It Yours",
        description = HL .. "/cb|r opens the options, where you can change sizes, colours and textures.\n" .. HL .. "/cb unlock|r lets you drag any frame.\n" .. HL .. "/cb grid|r shows a grid to line frames up.\n\nWhile frames are unlocked, " .. HL .. "Ctrl+Shift+Click|r a frame's label to hide it for now.",
        tip = HL .. "Look & Feel|r sets the bar texture and font for every Castborn bar.",
        frame = nil,
    },
    {
        id = "complete",
        title = "You're All Set",
        description = "The modules you picked are switched on. Open the options to fine-tune them, or enter test mode to move everything into place.",
        tip = "Enjoy, and good luck out there.",
        frame = nil,
    },
}

Tutorial.steps = steps

-- Human-readable labels for configKey values (used by multi-checkbox merged steps)
local configKeyLabels = {
    gcd = "GCD Indicator",
    fsr = "5 Second Rule",
    target = "Target Castbar",
    targettarget = "Target of Target",
    focus = "Focus Castbar",
    dots = "DoT Tracker",
    multidot = "Multi-DoT Tracker",
    absorbs = "Absorb Tracker",
    armortracker = "Armour Tracker",
    seals = "Seal Tracker",
    cooldowntext = "Cooldown Text",
}

-- Whether a module is any use to a class. Modules not listed suit every class.
local function SpellDataHasClass(tbl, class)
    for _, info in pairs(tbl or {}) do
        if info.class == class then return true end
    end
    return false
end

local keyForClass = {
    fsr = function(class)
        local defaults = Castborn.ClassDefaults and Castborn.ClassDefaults:GetDefaults(class) or {}
        return defaults.fiveSecondRule ~= false
    end,
    swing = function(class)
        local defaults = Castborn.ClassDefaults and Castborn.ClassDefaults:GetDefaults(class) or {}
        return defaults.swingTimer ~= false
    end,
    interrupt = function(class)
        return Castborn.SpellData ~= nil and Castborn.SpellData:GetInterrupt(class) ~= nil
    end,
    totems = function(class) return class == "SHAMAN" end,
    absorbs = function(class)
        return Castborn.SpellData ~= nil and SpellDataHasClass(Castborn.SpellData.absorbs, class)
    end,
    armortracker = function(class)
        return Castborn.SpellData ~= nil and Castborn.SpellData:GetClassArmors(class) ~= nil
    end,
    seals = function(class) return class == "PALADIN" end,
}

-- Create a highlight frame that surrounds a target element: a gold chamfered outline with a
-- soft glow and a diamond at each corner, breathing gently
local function CreateHighlightFrame(index)
    local Theme = Castborn.Theme
    local frame = CreateFrame("Frame", "CastbornTutorialHighlight" .. (index or 1), UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)

    -- Soft gold light around the target
    frame.glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.glow:SetTexture(Theme.media.glow)
    frame.glow:SetVertexColor(Theme:Color("accent"))
    frame.glow:SetBlendMode("ADD")
    frame.glow:SetPoint("TOPLEFT", -26, 26)
    frame.glow:SetPoint("BOTTOMRIGHT", 26, -26)

    -- The outline: an edge-only chamfered box
    Theme:Chamfer(frame, { cut = 6, edge = "heading", layer = "BORDER" })

    for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local diamond = frame:CreateTexture(nil, "OVERLAY")
        diamond:SetTexture(Theme.media.diamond)
        diamond:SetVertexColor(Theme:Color("heading"))
        diamond:SetSize(11, 11)
        diamond:SetPoint("CENTER", frame, point, 0, 0)
    end

    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local pulse = math.sin(elapsed * 3) * 0.25 + 0.75
        for _, tex in ipairs(self.chamfer.edge) do
            tex:SetAlpha(pulse)
        end
        self.glow:SetAlpha(math.sin(elapsed * 2) * 0.08 + 0.22)
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

-- Layout of the tutorial panel
local PANEL_WIDTH = 480
local TEXT_WIDTH = 420
local MAX_PIPS = 20

-- Create the tutorial explanation panel (Gilded Grimoire, like the options window)
local function CreateTutorialFrame()
    local Theme = Castborn.Theme
    local frame = Theme:CreatePanel({
        name = "CastbornTutorialFrame",
        width = PANEL_WIDTH,
        height = 300,
        titleSize = 26,
    })
    frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    frame:SetFrameLevel(101)
    local inner = frame.inner

    -- Step counter, small and quiet in the top-left corner
    frame.stepText = inner:CreateFontString(nil, "OVERLAY")
    Theme:Font(frame.stepText, "strong", 10)
    frame.stepText:SetTextColor(Theme:Color("muted"))
    frame.stepText:SetPoint("TOPLEFT", 16, -12)

    -- Description
    frame.description = inner:CreateFontString(nil, "OVERLAY")
    Theme:Font(frame.description, "body", 15)
    frame.description:SetWidth(TEXT_WIDTH)
    frame.description:SetPoint("TOP", frame.rule, "BOTTOM", 0, -14)
    frame.description:SetJustifyH("CENTER")
    frame.description:SetJustifyV("TOP")
    frame.description:SetSpacing(3)

    -- Tip: a quiet inset box with a gold label
    frame.tipBox = CreateFrame("Frame", nil, inner)
    frame.tipBox:SetWidth(TEXT_WIDTH)
    Theme:Chamfer(frame.tipBox, { cut = 6, fill = "navA", edge = "divider" })
    frame.tipLabel = frame.tipBox:CreateFontString(nil, "OVERLAY")
    Theme:Font(frame.tipLabel, "strong", 11)
    frame.tipLabel:SetTextColor(Theme:Color("accent"))
    frame.tipLabel:SetPoint("TOPLEFT", 12, -10)
    frame.tipLabel:SetText("TIP")
    frame.tip = frame.tipBox:CreateFontString(nil, "OVERLAY")
    Theme:Font(frame.tip, "body", 13)
    frame.tip:SetTextColor(Theme:Color("muted"))
    frame.tip:SetPoint("TOPLEFT", 44, -9)
    frame.tip:SetWidth(TEXT_WIDTH - 56)
    frame.tip:SetJustifyH("LEFT")
    frame.tip:SetSpacing(2)

    -- Enable checkboxes (pool of 3 for merged steps with multiple toggles); each click
    -- toggles the key the current step gave it
    frame.enableChecks = {}
    for i = 1, 3 do
        local cb = Theme:CreateCheckbox(inner, "", nil, nil, function(checked)
            Tutorial:OnCheckboxClicked(frame.enableChecks[i], checked)
        end)
        cb:Hide()
        frame.enableChecks[i] = cb
    end

    -- Last step: open the options or go straight to test mode
    frame.optionsBtn = Theme:CreateButton(inner, "Open Options", 130, function()
        Tutorial:End()
        if Castborn.Options then Castborn.Options:Show() end
    end)
    frame.testModeBtn = Theme:CreateButton(inner, "Test Mode", 130, function()
        Tutorial:End()
        Castborn:EnterTestMode()
    end)

    -- Footer: a rule, then Skip on the left, progress pips in the middle, Back and Next right
    local footerRule = inner:CreateTexture(nil, "ARTWORK")
    footerRule:SetHeight(1)
    footerRule:SetPoint("BOTTOMLEFT", 16, 48)
    footerRule:SetPoint("BOTTOMRIGHT", -16, 48)
    footerRule:SetColorTexture(Theme:Color("divider"))

    frame.skipBtn = Theme:CreateButton(inner, "Skip", 70, function()
        Tutorial:End()
    end)
    frame.skipBtn:SetPoint("BOTTOMLEFT", 14, 14)

    frame.nextBtn = Theme:CreateButton(inner, "Next", 80, function()
        Tutorial:NextStep()
    end, "primary")
    frame.nextBtn:SetPoint("BOTTOMRIGHT", -14, 14)

    frame.backBtn = Theme:CreateButton(inner, "Back", 70, function()
        Tutorial:PreviousStep()
    end)
    frame.backBtn:SetPoint("RIGHT", frame.nextBtn, "LEFT", -8, 0)

    frame.pips = CreateFrame("Frame", nil, inner)
    frame.pips:SetHeight(12)
    frame.pips:SetPoint("BOTTOM", 0, 20)
    for i = 1, MAX_PIPS do
        local pip = frame.pips:CreateTexture(nil, "ARTWORK")
        pip:SetTexture(Theme.media.diamond)
        pip:SetPoint("LEFT", (i - 1) * 13, 0)
        pip:Hide()
        frame.pips[i] = pip
    end

    return frame
end

-- Light the pips up to the current step: done and current in gold, the rest dim
local function UpdatePips(frame, position, total)
    local Theme = Castborn.Theme
    local shown = math.min(total, MAX_PIPS)
    frame.pips:SetWidth(math.max(1, (shown - 1) * 13 + 11))
    for i = 1, MAX_PIPS do
        local pip = frame.pips[i]
        if i <= shown then
            local size = (i == position) and 11 or 7
            pip:SetSize(size, size)
            pip:SetVertexColor(Theme:Color(i <= position and "heading" or "rule"))
            pip:ClearAllPoints()
            pip:SetPoint("CENTER", frame.pips, "LEFT", (i - 1) * 13 + 5.5, 0)
            pip:Show()
        else
            pip:Hide()
        end
    end
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

    -- Mockup lockout indicator (example: Frost school locked)
    local lockout = CreateFrame("Frame", nil, frame)
    lockout:SetSize(80, 20)
    lockout:SetPoint("LEFT", frame, "RIGHT", 10, 0)

    lockout.bg = lockout:CreateTexture(nil, "BACKGROUND")
    lockout.bg:SetAllPoints()
    lockout.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    lockout.text = lockout:CreateFontString(nil, "OVERLAY")
    lockout.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    lockout.text:SetPoint("CENTER")
    lockout.text:SetText("Locked 2.4s")
    lockout.text:SetTextColor(0.5, 0.5, 1.0, 1)  -- Frost school colour

    frame.lockout = lockout

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
    elseif frameId == "items" then
        if CB.TestItems then CB:TestItems() end
        local frame = _G["Castborn_ItemTracker"]
        if frame then return frame end
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
        local iFrame = _G["Castborn_Interrupt"] or _G["Castborn_Interrupt_Mock"]
        if not iFrame then
            iFrame = CreateMockupInterruptTracker()
        end
        -- Show a mockup lockout indicator if the real one isn't visible (and the build has one)
        local hasLockout = Castborn:IsOptionAvailable("interrupt.lockout")
        if iFrame.lockout then iFrame.lockout:SetShown(hasLockout) end
        local realLockout = _G["Castborn_Lockout"]
        if hasLockout and not (realLockout and realLockout:IsShown()) and not iFrame.tutorialLockout then
            local lo = CreateFrame("Frame", nil, iFrame)
            lo:SetSize(80, 20)
            lo:SetPoint("LEFT", iFrame, "RIGHT", 10, 0)
            lo.bg = lo:CreateTexture(nil, "BACKGROUND")
            lo.bg:SetAllPoints()
            lo.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
            lo.text = lo:CreateFontString(nil, "OVERLAY")
            lo.text:SetFont(Castborn:GetBarFont(), 10, "OUTLINE")
            lo.text:SetPoint("CENTER")
            lo.text:SetText("Locked 2.4s")
            lo.text:SetTextColor(0.5, 0.5, 1.0, 1)
            iFrame.tutorialLockout = lo
        end
        if iFrame.tutorialLockout then iFrame.tutorialLockout:SetShown(hasLockout) end
        return iFrame
    elseif frameId == "totems" then
        if CB.TestTotemTracker then CB:TestTotemTracker() end
        local frame = _G["Castborn_TotemTracker"]
        if frame then return frame end
    elseif frameId == "absorbs" then
        if CastbornDB.absorbs and CastbornDB.absorbs.enabled then
            if CB.TestAbsorbTracker then CB:TestAbsorbTracker() end
            local f = _G["Castborn_AbsorbTracker"]
            if f then return f end
        elseif CB.EndTestAbsorbTracker then
            CB:EndTestAbsorbTracker()
        end
    elseif frameId == "armour" then
        local frames = {}
        if CastbornDB.armortracker and CastbornDB.armortracker.enabled then
            if CB.TestArmorTracker then CB:TestArmorTracker() end
            -- Paladins can have up to three alert icons
            for _, name in ipairs({ "Castborn_ArmorTracker", "Castborn_ArmorTracker2", "Castborn_ArmorTracker3" }) do
                local f = _G[name]
                if f and f:IsShown() then tinsert(frames, f) end
            end
        elseif CB.EndTestArmorTracker then
            CB:EndTestArmorTracker()
        end
        if #frames > 0 then
            frames.grouped = true
            return frames
        end
    elseif frameId == "seals" then
        if CastbornDB.seals and CastbornDB.seals.enabled then
            if CB.TestSealTracker then CB:TestSealTracker() end
            local f = _G["Castborn_SealTracker"]
            if f then return f end
        elseif CB.EndTestSealTracker then
            CB:EndTestSealTracker()
        end
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
-- The module keys a step toggles, or nil for steps without checkboxes
local function StepKeys(step)
    return step.configKeys or (step.configKey and {step.configKey}) or nil
end

-- Whether this build loads the module behind a key (every module on TBC; fewer on Forever)
-- and the module is any use to the player's class
local function IsKeyAvailable(step, key)
    if not Castborn:IsOptionAvailable(step.optionKey or key) then return false end
    local forClass = keyForClass[key]
    if not forClass then return true end
    local _, playerClass = UnitClass("player")
    return forClass(playerClass) == true
end

-- The keys of a step that get a checkbox: those this build loads and the class can use
function Tutorial:GetShownKeys(step)
    local stepKeys = StepKeys(step)
    if not stepKeys then return nil end
    local keys = {}
    for _, key in ipairs(stepKeys) do
        if IsKeyAvailable(step, key) then keys[#keys + 1] = key end
    end
    return keys
end

-- A step is shown if it matches the player's class and at least one of its modules is loaded
function Tutorial:IsStepShown(stepNum)
    local step = steps[stepNum]
    if not step then return false end
    if step.class then
        local _, playerClass = UnitClass("player")
        if step.class ~= playerClass then return false end
    end
    if step.module and not Castborn[step.module] then return false end
    local keys = StepKeys(step)
    if not keys then return true end
    for _, key in ipairs(keys) do
        if IsKeyAvailable(step, key) then return true end
    end
    return false
end

-- Position of a step among the shown steps, and how many steps are shown
function Tutorial:GetStepPosition(stepNum)
    local position, total = 0, 0
    for i = 1, #steps do
        if self:IsStepShown(i) then
            total = total + 1
            if i <= stepNum then position = total end
        end
    end
    return position, total
end

local function ShowStep(stepNum)
    if stepNum < 1 or stepNum > #steps then return end

    currentStep = stepNum
    local step = steps[stepNum]

    if not tutorialFrame then
        tutorialFrame = CreateTutorialFrame()
    end
    local f = tutorialFrame

    -- Step counter and progress pips count only the steps this player sees
    local position, total = Tutorial:GetStepPosition(stepNum)
    f.stepText:SetText(string.format("STEP %d OF %d", position, total))
    UpdatePips(f, position, total)

    f.title:SetText(step.title)
    f.description:SetText(step.description)

    local isLast = stepNum == #steps
    f.backBtn:SetEnabled(position > 1)
    f.nextBtn:SetText(isLast and "Finish" or "Next")

    -- Below the description, top to bottom: enable checkboxes, the last step's buttons, the
    -- tip. y is the running distance below the description.
    local y = 0

    -- Only modules this build loads, and the class can use, get a checkbox
    local keys = Tutorial:GetShownKeys(step)
    local numChecks = keys and #keys or 0
    for i = 1, 3 do
        local cb = f.enableChecks[i]
        local key = keys and keys[i]
        if key then
            if i == 1 then y = y + 12 end
            cb.key = key
            cb.label = configKeyLabels[key] or step.title
            cb:SetLabel(numChecks == 1 and "Enable this module" or ("Enable " .. (configKeyLabels[key] or key)))
            cb:SetChecked(CastbornDB[key] and CastbornDB[key].enabled)
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", f.description, "BOTTOMLEFT", -4, -y)
            cb:Show()
            y = y + 28
        else
            cb.key = nil
            cb:Hide()
        end
    end

    f.optionsBtn:SetShown(isLast)
    f.testModeBtn:SetShown(isLast)
    if isLast then
        y = y + 18
        f.optionsBtn:ClearAllPoints()
        f.optionsBtn:SetPoint("TOPRIGHT", f.description, "BOTTOM", -5, -y)
        f.testModeBtn:ClearAllPoints()
        f.testModeBtn:SetPoint("TOPLEFT", f.description, "BOTTOM", 5, -y)
        y = y + 24
    end

    local hasTip = step.tip and step.tip ~= ""
    f.tipBox:SetShown(hasTip)
    if hasTip then
        y = y + 16
        f.tip:SetText(step.tip)
        local tipHeight = math.max(f.tip:GetStringHeight(), 14) + 20
        f.tipBox:SetHeight(tipHeight)
        f.tipBox:ClearAllPoints()
        f.tipBox:SetPoint("TOP", f.description, "BOTTOM", 0, -y)
        y = y + tipHeight
    end

    -- Fit the panel: frame inset, title and rule, description, the rows above, the footer
    local top = 4 + 14 + f.title:GetStringHeight() + 6 + 9 + 14
    f:SetHeight(math.floor(top + f.description:GetStringHeight() + y + 20 + 52 + 0.5))

    -- Show test frame(s) and highlight them
    local targetFrames = nil

    -- First try to show a test version of the frame
    if step.id then
        targetFrames = ShowTestFrame(step.id)
    end

    -- Fall back to getFrame if no test frame was shown
    if not targetFrames and step.getFrame then
        local frame = step.getFrame()
        if frame then
            frame:Show()
            targetFrames = frame
        end
    end

    HighlightFrame(targetFrames)

    -- Execute any action for this step
    if step.action then
        step.action()
    end

    f:Show()
end

-- An enable checkbox was clicked: switch its module and refresh the step
function Tutorial:OnCheckboxClicked(cb, checked)
    local key = cb.key
    if not key or not CastbornDB[key] then return end
    CastbornDB[key].enabled = checked
    Castborn:Print(cb.label .. " " .. (checked and "enabled" or "disabled"))
    ShowStep(currentStep)
end

-- Public API
function Tutorial:Start()
    if isActive then return end
    isActive = true
    currentStep = 0

    -- Show first step (test frames are shown per-step)
    self:NextStep()
    Castborn:Print("Tutorial started. Follow the steps to learn about Castborn.")
end

function Tutorial:NextStep()
    local nextStep = currentStep + 1
    -- Skip steps for another class or for modules this build does not load
    while nextStep <= #steps and not self:IsStepShown(nextStep) do
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
    -- Skip steps for another class or for modules this build does not load
    while prevStep >= 1 and not self:IsStepShown(prevStep) do
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
    if CB.EndTestSealTracker then CB:EndTestSealTracker() end
    if CB.EndTestItems then CB:EndTestItems() end

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
    -- Hide tutorial lockout on real interrupt frames
    local iFrame = _G["Castborn_Interrupt"] or _G["Castborn_Interrupt_Mock"]
    if iFrame and iFrame.tutorialLockout then
        iFrame.tutorialLockout:Hide()
    end

    -- Mark tutorial as complete
    CastbornDB.tutorialComplete = true

    -- Hide options if we opened it
    if Castborn.Options then
        Castborn.Options:Hide()
    end

    Castborn:Print("Tutorial complete. Use " .. HL .. "/cb tutorial|r to replay it any time.")
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

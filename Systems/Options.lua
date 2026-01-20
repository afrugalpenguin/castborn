--[[
    Castborn - GUI Options Panel
    WeakAuras-inspired style
]]

local Options = {}
Castborn.Options = Options

--------------------------------------------------------------------------------
-- Style Constants (WeakAuras-inspired)
--------------------------------------------------------------------------------

local C = {
    -- Backgrounds
    bgMain = {0.1, 0.1, 0.1, 0.95},
    bgSection = {0.15, 0.15, 0.15, 1},
    bgInput = {0.2, 0.2, 0.2, 1},
    bgHighlight = {0.25, 0.25, 0.25, 1},

    -- Borders
    border = {0.4, 0.4, 0.4, 1},
    borderDark = {0.25, 0.25, 0.25, 1},

    -- Text
    gold = {1, 0.82, 0, 1},           -- WeakAuras gold
    white = {1, 1, 1, 1},
    grey = {0.7, 0.7, 0.7, 1},
    darkGrey = {0.5, 0.5, 0.5, 1},

    -- Accent
    accent = {0.3, 0.6, 1, 1},        -- Blue for active states
    accentDim = {0.2, 0.4, 0.7, 0.5},
}

local LOGO_PATH = "Interface\\Icons\\Spell_Arcane_Arcane04"
local optionsFrame = nil
local contentFrames = {}
local currentCategory = "general"

local categories = {
    { id = "general", name = "General" },
    { id = "castbars", name = "Castbars" },
    { id = "gcd", name = "GCD Indicator" },
    { id = "fsr", name = "5 Second Rule" },
    { id = "swing", name = "Swing Timer" },
    { id = "dots", name = "DoT Tracker" },
    { id = "multidot", name = "Multi-DoT" },
    { id = "buffs", name = "Buff Tracker" },
    { id = "cooldowns", name = "Cooldowns" },
    { id = "interrupt", name = "Interrupt" },
    { id = "profiles", name = "Profiles" },
}

--------------------------------------------------------------------------------
-- UI Components
--------------------------------------------------------------------------------

-- Section header (gold text with line)
local function CreateHeader(parent, text)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(24)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(text)
    label:SetTextColor(unpack(C.gold))

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    line:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.3)

    return frame
end

-- Group box (bordered container)
local function CreateGroup(parent, title, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetHeight(height or 100)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(C.bgSection))
    frame:SetBackdropBorderColor(unpack(C.borderDark))

    if title then
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 8, 12)
        label:SetText(title)
        label:SetTextColor(unpack(C.gold))
    end

    return frame
end

-- Button (WoW-style)
local function CreateButton(parent, text, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 100, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", function(self)
        if onClick then onClick(self) end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    return btn
end

-- Checkbox (WoW-style)
local function CreateCheckbox(parent, label, dbTable, dbKey, onChange)
    local frame = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    frame:SetSize(26, 26)

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("LEFT", frame, "RIGHT", 2, 0)
    frame.text:SetText(label)

    if dbTable and dbKey then
        frame:SetChecked(dbTable[dbKey])
    end

    frame:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if dbTable and dbKey then
            dbTable[dbKey] = checked
        end
        if onChange then onChange(checked) end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    return frame
end

local function CreateSlider(parent, label, dbTable, dbKey, minVal, maxVal, step, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(200, 50)

    local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 0, 0)
    labelText:SetText(label)
    labelText:SetTextColor(unpack(C.grey))

    local valueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOPRIGHT", 0, 0)

    local slider = CreateFrame("Slider", nil, frame)
    slider:SetPoint("TOPLEFT", 0, -20)
    slider:SetPoint("TOPRIGHT", 0, -20)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)

    -- Track background
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOPLEFT", 0, -6)
    track:SetPoint("BOTTOMRIGHT", 0, 6)
    track:SetColorTexture(0.15, 0.15, 0.15, 1)

    -- Track border
    local trackBorder = slider:CreateTexture(nil, "BORDER")
    trackBorder:SetPoint("TOPLEFT", track, -1, 1)
    trackBorder:SetPoint("BOTTOMRIGHT", track, 1, -1)
    trackBorder:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Thumb
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(14, 14)
    thumb:SetColorTexture(0.6, 0.6, 0.6, 1)
    slider:SetThumbTexture(thumb)

    local currentValue = (dbTable and dbKey and dbTable[dbKey]) or minVal
    slider:SetValue(currentValue)
    valueText:SetText(currentValue)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valueText:SetText(value)
        if dbTable and dbKey then
            dbTable[dbKey] = value
        end
        if onChange then onChange(value) end
    end)

    frame.slider = slider
    return frame
end

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

local function CreateOptionsFrame()
    local frame = CreateFrame("Frame", "CastbornOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(600, 450)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(unpack(C.bgMain))
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", -4, -4)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    titleBar:SetBackdropColor(0.15, 0.15, 0.15, 1)

    -- Logo
    local logo = titleBar:CreateTexture(nil, "ARTWORK")
    logo:SetSize(20, 20)
    logo:SetPoint("LEFT", 8, 0)
    logo:SetTexture(LOGO_PATH)

    -- Title
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText("|cffFFCC00Castborn|r Options")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Sidebar
    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetWidth(130)
    sidebar:SetPoint("TOPLEFT", 6, -36)
    sidebar:SetPoint("BOTTOMLEFT", 6, 6)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    sidebar:SetBackdropColor(unpack(C.bgSection))
    sidebar:SetBackdropBorderColor(unpack(C.borderDark))
    frame.sidebar = sidebar

    -- Category buttons
    local y = -8
    for i, cat in ipairs(categories) do
        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetSize(120, 22)
        btn:SetPoint("TOPLEFT", 5, y)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0, 0, 0, 0)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("LEFT", 8, 0)
        btn.text:SetText(cat.name)
        btn.text:SetTextColor(unpack(C.grey))

        btn:SetScript("OnEnter", function(self)
            if currentCategory ~= cat.id then
                self.bg:SetColorTexture(1, 1, 1, 0.1)
            end
        end)

        btn:SetScript("OnLeave", function(self)
            if currentCategory ~= cat.id then
                self.bg:SetColorTexture(0, 0, 0, 0)
            end
        end)

        btn:SetScript("OnClick", function()
            Options:ShowCategory(cat.id)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)

        cat.button = btn
        y = y - 22
    end

    -- Content area
    local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 6, 0)
    content:SetPoint("BOTTOMRIGHT", -6, 6)
    content:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    content:SetBackdropColor(unpack(C.bgSection))
    content:SetBackdropBorderColor(unpack(C.borderDark))
    frame.content = content

    -- Inner content with padding
    local inner = CreateFrame("Frame", nil, content)
    inner:SetPoint("TOPLEFT", 12, -12)
    inner:SetPoint("BOTTOMRIGHT", -12, 12)
    frame.contentInner = inner

    return frame
end

--------------------------------------------------------------------------------
-- Category Display
--------------------------------------------------------------------------------

function Options:ShowCategory(catId)
    currentCategory = catId

    -- Update sidebar buttons
    for _, cat in ipairs(categories) do
        if cat.id == catId then
            cat.button.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)
            cat.button.text:SetTextColor(unpack(C.white))
        else
            cat.button.bg:SetColorTexture(0, 0, 0, 0)
            cat.button.text:SetTextColor(unpack(C.grey))
        end
    end

    -- Hide all content frames
    for _, frame in pairs(contentFrames) do
        frame:Hide()
    end

    -- Show or create content
    if not contentFrames[catId] then
        contentFrames[catId] = self:CreateContent(catId)
    end
    contentFrames[catId]:Show()
end

function Options:CreateContent(catId)
    local content = CreateFrame("Frame", nil, optionsFrame.contentInner)
    content:SetAllPoints()

    if catId == "general" then
        self:BuildGeneral(content)
    elseif catId == "castbars" then
        self:BuildCastbars(content)
    elseif catId == "profiles" then
        self:BuildProfiles(content)
    else
        self:BuildModule(content, catId)
    end

    return content
end

--------------------------------------------------------------------------------
-- Content Builders
--------------------------------------------------------------------------------

function Options:BuildGeneral(parent)
    local y = 0

    -- Actions header
    local header1 = CreateHeader(parent, "Actions")
    header1:SetPoint("TOPLEFT", 0, y)
    header1:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    -- Action buttons
    local lockBtn = CreateButton(parent, CastbornDB.locked and "Unlock Frames" or "Lock Frames", 110, function(self)
        CastbornDB.locked = not CastbornDB.locked
        self:SetText(CastbornDB.locked and "Unlock Frames" or "Lock Frames")
        if CastbornDB.locked then
            Castborn:Print("Frames locked")
            if Castborn.Anchoring then Castborn.Anchoring:HideDragIndicators(true) end
            Castborn:EndTestMode()
            if Castborn.HideTestFrames then Castborn:HideTestFrames() end
        else
            Castborn:Print("Frames unlocked - drag to reposition")
            if Castborn.ShowTest then Castborn:ShowTest() end
            Castborn:StartTestMode()
            if Castborn.Anchoring then Castborn.Anchoring:ShowDragIndicators(true) end
        end
    end)
    lockBtn:SetPoint("TOPLEFT", 0, y)

    local testBtn = CreateButton(parent, "Test Mode", 90, function()
        CastbornDB.locked = false
        Castborn:FireCallback("TEST_MODE")
        if Castborn.ShowTest then Castborn:ShowTest() end
        Castborn:StartTestMode()
        if Castborn.Anchoring then Castborn.Anchoring:ShowDragIndicators(true) end
        if Castborn.ShowTestModePanel then Castborn:ShowTestModePanel() end
    end)
    testBtn:SetPoint("LEFT", lockBtn, "RIGHT", 8, 0)

    local gridBtn = CreateButton(parent, "Grid", 60, function()
        if Castborn.GridPosition then Castborn.GridPosition:TogglePositioningMode() end
    end)
    gridBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)

    local resetBtn = CreateButton(parent, "Reset Positions", 110, function()
        Castborn:FireCallback("RESET_POSITIONS")
    end)
    resetBtn:SetPoint("LEFT", gridBtn, "RIGHT", 8, 0)

    y = y - 40

    -- Module toggles header
    local header2 = CreateHeader(parent, "Modules")
    header2:SetPoint("TOPLEFT", 0, y)
    header2:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    -- Module checkboxes in two columns
    local modules = {
        { key = "player", label = "Player Castbar" },
        { key = "target", label = "Target Castbar" },
        { key = "focus", label = "Focus Castbar" },
        { key = "targettarget", label = "Target of Target" },
        { key = "gcd", label = "GCD Indicator" },
        { key = "fsr", label = "5 Second Rule" },
        { key = "swing", label = "Swing Timer" },
        { key = "dots", label = "DoT Tracker" },
        { key = "buffs", label = "Buff Tracker" },
        { key = "cooldowns", label = "Cooldowns" },
    }

    local col = 0
    local startY = y
    for i, mod in ipairs(modules) do
        CastbornDB[mod.key] = CastbornDB[mod.key] or {}
        local cb = CreateCheckbox(parent, mod.label, CastbornDB[mod.key], "enabled")
        cb:SetPoint("TOPLEFT", col * 200, y)
        y = y - 26
        if i == 5 then
            col = 1
            y = startY
        end
    end
end

function Options:BuildCastbars(parent)
    local y = 0

    -- Player Castbar
    local header1 = CreateHeader(parent, "Player Castbar")
    header1:SetPoint("TOPLEFT", 0, y)
    header1:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    CastbornDB.player = CastbornDB.player or {}

    local cb1 = CreateCheckbox(parent, "Enabled", CastbornDB.player, "enabled")
    cb1:SetPoint("TOPLEFT", 0, y)
    local cb2 = CreateCheckbox(parent, "Show Icon", CastbornDB.player, "showIcon")
    cb2:SetPoint("TOPLEFT", 150, y)
    local cb3 = CreateCheckbox(parent, "Show Time", CastbornDB.player, "showTime")
    cb3:SetPoint("TOPLEFT", 280, y)
    y = y - 26

    local cb4 = CreateCheckbox(parent, "Show Spell Name", CastbornDB.player, "showSpellName")
    cb4:SetPoint("TOPLEFT", 0, y)
    local cb5 = CreateCheckbox(parent, "Show Latency", CastbornDB.player, "showLatency")
    cb5:SetPoint("TOPLEFT", 150, y)
    y = y - 36

    local slider1 = CreateSlider(parent, "Width", CastbornDB.player, "width", 100, 400, 10, function(v)
        if Castborn.castbars and Castborn.castbars.player then
            Castborn.castbars.player:SetWidth(v)
        end
    end)
    slider1:SetPoint("TOPLEFT", 0, y)

    local slider2 = CreateSlider(parent, "Height", CastbornDB.player, "height", 10, 40, 2, function(v)
        if Castborn.castbars and Castborn.castbars.player then
            local f = Castborn.castbars.player
            f:SetHeight(v)
            if f.iconFrame then f.iconFrame:SetSize(v + 4, v + 4) end
            if f.spark then f.spark:SetHeight(v * 2.5) end
        end
    end)
    slider2:SetPoint("TOPLEFT", 220, y)
    y = y - 60

    -- Target Castbar
    local header2 = CreateHeader(parent, "Target Castbar")
    header2:SetPoint("TOPLEFT", 0, y)
    header2:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    CastbornDB.target = CastbornDB.target or {}

    local tcb1 = CreateCheckbox(parent, "Enabled", CastbornDB.target, "enabled")
    tcb1:SetPoint("TOPLEFT", 0, y)
    local tcb2 = CreateCheckbox(parent, "Show Icon", CastbornDB.target, "showIcon")
    tcb2:SetPoint("TOPLEFT", 150, y)
    local tcb3 = CreateCheckbox(parent, "Show Time", CastbornDB.target, "showTime")
    tcb3:SetPoint("TOPLEFT", 280, y)
    y = y - 40

    -- Other castbars
    local header3 = CreateHeader(parent, "Other Castbars")
    header3:SetPoint("TOPLEFT", 0, y)
    header3:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    CastbornDB.focus = CastbornDB.focus or {}
    CastbornDB.targettarget = CastbornDB.targettarget or {}

    local fcb = CreateCheckbox(parent, "Focus Castbar", CastbornDB.focus, "enabled")
    fcb:SetPoint("TOPLEFT", 0, y)
    local totcb = CreateCheckbox(parent, "Target of Target", CastbornDB.targettarget, "enabled")
    totcb:SetPoint("TOPLEFT", 150, y)
end

function Options:BuildProfiles(parent)
    local y = 0

    local header1 = CreateHeader(parent, "Profile Management")
    header1:SetPoint("TOPLEFT", 0, y)
    header1:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    local currentName = "Default"
    if Castborn.Profiles and Castborn.Profiles.GetCurrentProfileName then
        currentName = Castborn.Profiles:GetCurrentProfileName()
    end

    local profileLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profileLabel:SetPoint("TOPLEFT", 0, y)
    profileLabel:SetText("Current Profile: |cffFFCC00" .. currentName .. "|r")
    y = y - 30

    local newBtn = CreateButton(parent, "New Profile", 100, function()
        if Castborn.Profiles and Castborn.Profiles.CreateProfile then
            local name = "Profile " .. (Castborn.Profiles:GetProfileCount() + 1)
            Castborn.Profiles:CreateProfile(name)
            Options:ShowCategory("profiles")
        end
    end)
    newBtn:SetPoint("TOPLEFT", 0, y)

    local copyBtn = CreateButton(parent, "Copy", 70, function()
        if Castborn.Profiles and Castborn.Profiles.CopyProfile then
            Castborn.Profiles:CopyProfile()
            Options:ShowCategory("profiles")
        end
    end)
    copyBtn:SetPoint("LEFT", newBtn, "RIGHT", 8, 0)

    local deleteBtn = CreateButton(parent, "Delete", 70, function()
        if Castborn.Profiles and Castborn.Profiles.DeleteProfile then
            Castborn.Profiles:DeleteProfile()
            Options:ShowCategory("profiles")
        end
    end)
    deleteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0)
    y = y - 40

    if not (Castborn.Profiles and Castborn.Profiles.GetAllProfiles) then
        local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        note:SetPoint("TOPLEFT", 0, y)
        note:SetText("Profile system not available")
    end
end

function Options:BuildModule(parent, key)
    local titles = {
        gcd = "GCD Indicator",
        fsr = "5 Second Rule",
        swing = "Swing Timer",
        dots = "DoT Tracker",
        multidot = "Multi-DoT Tracker",
        buffs = "Buff Tracker",
        cooldowns = "Cooldown Tracker",
        interrupt = "Interrupt Tracker",
    }

    local y = 0

    local header = CreateHeader(parent, titles[key] or key)
    header:SetPoint("TOPLEFT", 0, y)
    header:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    CastbornDB[key] = CastbornDB[key] or {}
    local db = CastbornDB[key]

    -- Enabled checkbox
    local enabledCB = CreateCheckbox(parent, "Enabled", db, "enabled", function()
        Castborn:FireCallback("SETTINGS_CHANGED")
    end)
    enabledCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    -- Width/Height sliders for applicable modules
    if key == "gcd" or key == "fsr" or key == "dots" or key == "swing" then
        db.width = db.width or 200
        local widthSlider = CreateSlider(parent, "Width", db, "width", 50, 400, 10, function(v)
            if key == "gcd" and Castborn.gcdFrame then Castborn.gcdFrame:SetWidth(v)
            elseif key == "fsr" and Castborn.fsrFrame then Castborn.fsrFrame:SetWidth(v)
            elseif key == "dots" and Castborn.dotTracker then Castborn.dotTracker:SetWidth(v)
            elseif key == "swing" and Castborn.swingTimers then
                if Castborn.swingTimers.mainhand then Castborn.swingTimers.mainhand:SetWidth(v) end
                if Castborn.swingTimers.offhand then Castborn.swingTimers.offhand:SetWidth(v) end
                if Castborn.swingTimers.ranged then Castborn.swingTimers.ranged:SetWidth(v) end
            end
        end)
        widthSlider:SetPoint("TOPLEFT", 0, y)

        if key == "gcd" or key == "fsr" then
            local hKey = db.barHeight ~= nil and "barHeight" or "height"
            db[hKey] = db[hKey] or 12
            local heightSlider = CreateSlider(parent, "Height", db, hKey, 2, 40, 2, function(v)
                if key == "gcd" and Castborn.gcdFrame then Castborn.gcdFrame:SetHeight(v)
                elseif key == "fsr" and Castborn.fsrFrame then Castborn.fsrFrame:SetHeight(v) end
            end)
            heightSlider:SetPoint("TOPLEFT", 220, y)
        end
        y = y - 60
    end

    -- Anchor checkbox
    if db.anchored ~= nil then
        local anchorCB = CreateCheckbox(parent, "Anchor to Castbar", db, "anchored", function(v)
            if v then
                Castborn:FireCallback("REATTACH_" .. string.upper(key))
            else
                Castborn:FireCallback("DETACH_" .. string.upper(key))
            end
        end)
        anchorCB:SetPoint("TOPLEFT", 0, y)
        y = y - 30
    end

    -- Module-specific options
    if key == "gcd" then
        local alwaysCB = CreateCheckbox(parent, "Always Show (even when ready)", db, "alwaysShow")
        alwaysCB:SetPoint("TOPLEFT", 0, y)
        y = y - 30
        local testBtn = CreateButton(parent, "Test GCD", 80, function()
            if Castborn.TestGCD then Castborn:TestGCD() end
        end)
        testBtn:SetPoint("TOPLEFT", 0, y)

    elseif key == "dots" then
        local mineCB = CreateCheckbox(parent, "Show Only My DoTs", db, "showOnlyMine")
        mineCB:SetPoint("TOPLEFT", 0, y)
        y = y - 36
        db.spacing = db.spacing or 2
        local spacingSlider = CreateSlider(parent, "Bar Spacing", db, "spacing", 0, 10, 1)
        spacingSlider:SetPoint("TOPLEFT", 0, y)
        db.opacity = db.opacity or 1
        local opacitySlider = CreateSlider(parent, "Opacity", db, "opacity", 0, 1, 0.05)
        opacitySlider:SetPoint("TOPLEFT", 220, y)

    elseif key == "swing" then
        local testBtn = CreateButton(parent, "Test Swing", 90, function()
            if Castborn.TestSwingTimers then Castborn:TestSwingTimers() end
        end)
        testBtn:SetPoint("TOPLEFT", 0, y)

    elseif key == "buffs" then
        local mineCB = CreateCheckbox(parent, "Show Only My Buffs", db, "showOnlyMine")
        mineCB:SetPoint("TOPLEFT", 0, y)
        local timersCB = CreateCheckbox(parent, "Show Timers", db, "showTimers")
        timersCB:SetPoint("TOPLEFT", 200, y)

    elseif key == "cooldowns" then
        db.minDuration = db.minDuration or 0
        local minSlider = CreateSlider(parent, "Min Duration (sec)", db, "minDuration", 0, 30, 1)
        minSlider:SetPoint("TOPLEFT", 0, y)
        local iconsCB = CreateCheckbox(parent, "Show Icons", db, "showIcons")
        iconsCB:SetPoint("TOPLEFT", 220, y + 15)

    elseif key == "interrupt" then
        local targetCB = CreateCheckbox(parent, "Track Target", db, "trackTarget")
        targetCB:SetPoint("TOPLEFT", 0, y)
        local focusCB = CreateCheckbox(parent, "Track Focus", db, "trackFocus")
        focusCB:SetPoint("TOPLEFT", 150, y)

    elseif key == "multidot" then
        db.maxTargets = db.maxTargets or 5
        local maxSlider = CreateSlider(parent, "Max Targets", db, "maxTargets", 1, 10, 1)
        maxSlider:SetPoint("TOPLEFT", 0, y)
        local sortCB = CreateCheckbox(parent, "Sort by Time", db, "sortByTime")
        sortCB:SetPoint("TOPLEFT", 220, y + 15)
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Options:Toggle()
    if not optionsFrame then
        optionsFrame = CreateOptionsFrame()
    end
    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        self:ShowCategory("general")
        optionsFrame:Show()
    end
end

function Options:Show()
    if not optionsFrame then
        optionsFrame = CreateOptionsFrame()
    end
    self:ShowCategory("general")
    optionsFrame:Show()
end

function Options:Hide()
    if optionsFrame then
        optionsFrame:Hide()
    end
end

function Castborn:ToggleOptions()
    Options:Toggle()
end

function Castborn:SelectOptionsTab(key)
    Options:ShowCategory(key)
end

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------

local function ToggleModule(dbKey, displayName, state, hideFrame)
    local db = CastbornDB[dbKey]
    if not db then return end

    if state == "on" then
        db.enabled = true
    elseif state == "off" then
        db.enabled = false
        if hideFrame then hideFrame() end
    else
        db.enabled = not db.enabled
        if not db.enabled and hideFrame then hideFrame() end
    end
    Castborn:Print(displayName .. " " .. (db.enabled and "enabled" or "disabled"))
end

SLASH_CASTBORN1 = "/cb"
SLASH_CASTBORN2 = "/castborn"
SlashCmdList["CASTBORN"] = function(msg)
    msg = string.lower(msg or ""):match("^%s*(.-)%s*$")  -- trim whitespace
    local args = {}
    for word in msg:gmatch("%S+") do table.insert(args, word) end
    local cmd = args[1] or ""
    local state = args[2]

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "settings" then
        Options:Toggle()
    elseif cmd == "lock" then
        CastbornDB.locked = true
        Castborn:Print("Frames locked")
        if Castborn.Anchoring then Castborn.Anchoring:HideDragIndicators(true) end
        Castborn:EndTestMode()
        if Castborn.HideTestFrames then Castborn:HideTestFrames() end
    elseif cmd == "unlock" then
        CastbornDB.locked = false
        Castborn:Print("Frames unlocked - drag to reposition")
        if Castborn.ShowTest then Castborn:ShowTest() end
        Castborn:StartTestMode()
        if Castborn.Anchoring then Castborn.Anchoring:ShowDragIndicators(true) end
    elseif cmd == "grid" then
        if Castborn.GridPosition then
            Castborn.GridPosition:TogglePositioningMode()
        end
    elseif cmd == "test" then
        CastbornDB.locked = false
        Castborn:FireCallback("TEST_MODE")
        if Castborn.ShowTest then Castborn:ShowTest() end
        Castborn:StartTestMode()
        if Castborn.Anchoring then Castborn.Anchoring:ShowDragIndicators(true) end
        if Castborn.ShowTestModePanel then Castborn:ShowTestModePanel() end
    elseif cmd == "reset" then
        Castborn:FireCallback("RESET_POSITIONS")
    elseif cmd == "profiles" then
        Options:Show()
        Options:ShowCategory("profiles")
    elseif cmd == "tutorial" then
        if Castborn.Tutorial then
            Castborn.Tutorial:Start()
        end
    -- Module toggle commands
    elseif cmd == "player" then
        ToggleModule("player", "Player castbar", state, function()
            if Castborn.castbars and Castborn.castbars.player then Castborn.castbars.player:Hide() end
        end)
    elseif cmd == "target" then
        ToggleModule("target", "Target castbar", state, function()
            if Castborn.castbars and Castborn.castbars.target then Castborn.castbars.target:Hide() end
        end)
    elseif cmd == "tot" then
        ToggleModule("targettarget", "Target-of-target castbar", state, function()
            if Castborn.castbars and Castborn.castbars.targettarget then Castborn.castbars.targettarget:Hide() end
        end)
    elseif cmd == "focus" then
        ToggleModule("focus", "Focus castbar", state, function()
            if Castborn.castbars and Castborn.castbars.focus then Castborn.castbars.focus:Hide() end
        end)
    elseif cmd == "dots" then
        ToggleModule("dots", "DoT tracker", state, function()
            if Castborn.dotTracker then Castborn.dotTracker:Hide() end
        end)
    elseif cmd == "fsr" then
        ToggleModule("fsr", "Five Second Rule tracker", state, function()
            if Castborn.fsrFrame then Castborn.fsrFrame:Hide() end
        end)
    elseif cmd == "swing" then
        ToggleModule("swing", "Swing timer", state, function()
            if Castborn.swingTimers then
                if Castborn.swingTimers.mainhand then Castborn.swingTimers.mainhand:Hide() end
                if Castborn.swingTimers.offhand then Castborn.swingTimers.offhand:Hide() end
                if Castborn.swingTimers.ranged then Castborn.swingTimers.ranged:Hide() end
            end
        end)
    elseif cmd == "gcd" then
        ToggleModule("gcd", "GCD indicator", state, function()
            if Castborn.gcdFrame then Castborn.gcdFrame:Hide() end
        end)
    elseif cmd == "help" then
        Castborn:Print("Commands:")
        print("  |cffFFCC00/cb|r - Open options")
        print("  |cffFFCC00/cb unlock|r - Unlock frames")
        print("  |cffFFCC00/cb lock|r - Lock frames")
        print("  |cffFFCC00/cb test|r - Test mode")
        print("  |cffFFCC00/cb grid|r - Toggle grid")
        print("  |cffFFCC00/cb reset|r - Reset positions")
        print("  |cffFFCC00/cb player|target|tot|focus|dots|fsr|swing|gcd [on/off]|r - Toggle modules")
    else
        Castborn:Print("Unknown command. Type /cb help")
    end
end

Castborn:RegisterModule("Options", Options)

--------------------------------------------------------------------------------
-- Interface Options Panel
--------------------------------------------------------------------------------

local function CreateInterfacePanel()
    local panel = CreateFrame("Frame", "CastbornInterfacePanel", UIParent)
    panel.name = "Castborn"

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(32, 32)
    logo:SetPoint("TOPLEFT", 16, -16)
    logo:SetTexture(LOGO_PATH)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    title:SetText("|cffFFCC00Castborn|r")

    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText("Version 2.1.0")

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -12)
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")
    desc:SetText("Castbars, swing timers, DoT tracking, and more for TBC Classic.")

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(160, 24)
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    openBtn:SetText("Open Castborn Options")
    openBtn:SetScript("OnClick", function()
        if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
        if SettingsPanel then SettingsPanel:Hide() end
        Options:Show()
    end)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -12)
    hint:SetText("Or type |cffFFCC00/cb|r in chat")

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

Castborn:RegisterCallback("READY", CreateInterfacePanel)

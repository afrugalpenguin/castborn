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
    { id = "buffs", name = "Proc Tracker" },
    { id = "cooldowns", name = "Cooldowns" },
    { id = "interrupt", name = "Interrupt" },
    { id = "totems", name = "Totems", class = "SHAMAN" },
    { id = "absorbs", name = "Absorbs", class = "MAGE" },
    { divider = true },
    { id = "lookfeel", name = "Look & Feel" },
    { id = "profiles", name = "Profiles" },
    { id = "changelog", name = "Changelog" },
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

    local slider = CreateFrame("Slider", nil, frame, "BackdropTemplate")
    slider:SetPoint("TOPLEFT", 0, -18)
    slider:SetPoint("TOPRIGHT", 0, -18)
    slider:SetHeight(18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)

    -- Track background with subtle rounded look
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    slider:SetBackdropColor(0.12, 0.12, 0.12, 1)
    slider:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    -- Fill bar (shows progress)
    local fill = slider:CreateTexture(nil, "ARTWORK", nil, 1)
    fill:SetHeight(6)
    fill:SetPoint("LEFT", 4, 0)
    fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.6)
    slider.fill = fill

    -- Thumb texture - use WoW's slider thumb for better look
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(16, 16)
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetThumbTexture(thumb)

    -- Min/max labels
    local minLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 2, -2)
    minLabel:SetText(minVal)
    minLabel:SetTextColor(unpack(C.darkGrey))

    local maxLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", -2, -2)
    maxLabel:SetText(maxVal)
    maxLabel:SetTextColor(unpack(C.darkGrey))

    local currentValue = (dbTable and dbKey and dbTable[dbKey]) or minVal
    slider:SetValue(currentValue)
    valueText:SetText(currentValue)

    -- Update fill bar width based on value
    local function UpdateFill(value)
        local range = maxVal - minVal
        if range > 0 then
            local pct = (value - minVal) / range
            local trackWidth = slider:GetWidth() - 8
            fill:SetWidth(math.max(1, trackWidth * pct))
        end
    end

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valueText:SetText(value)
        UpdateFill(value)
        if dbTable and dbKey then
            dbTable[dbKey] = value
        end
        if onChange then onChange(value) end
    end)

    -- Initialize fill when slider gets its size
    slider:SetScript("OnSizeChanged", function(self, width, height)
        if width and width > 0 then
            UpdateFill(self:GetValue())
        end
    end)

    frame.slider = slider
    return frame
end

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

local function CreateOptionsFrame()
    local frame = CreateFrame("Frame", "CastbornOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(700, 450)
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

    -- Lock frames when options panel is closed
    frame:SetScript("OnHide", function()
        if not CastbornDB.locked then
            CastbornDB.locked = true
            Castborn:Print("Frames locked")
            if Castborn.Anchoring then Castborn.Anchoring:HideDragIndicators(true) end
            Castborn:EndTestMode()
            if Castborn.HideTestFrames then Castborn:HideTestFrames() end
            if Castborn.HideTestModePanel then Castborn:HideTestModePanel() end
        end
    end)

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
    local _, playerClass = UnitClass("player")
    for i, cat in ipairs(categories) do
        -- Skip class-restricted categories for other classes
        if cat.class and cat.class ~= playerClass then
            -- Skip this category
        elseif cat.divider then
            -- Create a horizontal divider line
            local divider = sidebar:CreateTexture(nil, "ARTWORK")
            divider:SetHeight(1)
            divider:SetPoint("TOPLEFT", 10, y - 6)
            divider:SetPoint("TOPRIGHT", -10, y - 6)
            divider:SetColorTexture(unpack(C.borderDark))
            y = y - 14
        else
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
        if cat.button then  -- Skip dividers
            if cat.id == catId then
                cat.button.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)
                cat.button.text:SetTextColor(unpack(C.white))
            else
                cat.button.bg:SetColorTexture(0, 0, 0, 0)
                cat.button.text:SetTextColor(unpack(C.grey))
            end
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
        local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", -24, 0)
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(content:GetWidth() - 24)
        scrollFrame:SetScrollChild(scrollChild)
        scrollFrame:SetScript("OnSizeChanged", function(self, w)
            if w and w > 0 then scrollChild:SetWidth(w) end
        end)
        self:BuildCastbars(scrollChild)
    elseif catId == "lookfeel" then
        self:BuildLookFeel(content)
    elseif catId == "profiles" then
        self:BuildProfiles(content)
    elseif catId == "changelog" then
        self:BuildChangelog(content)
    else
        -- Module pages use a scroll frame for overflow
        local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", -24, 0)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(content:GetWidth() - 24)
        scrollFrame:SetScrollChild(scrollChild)
        scrollFrame:SetScript("OnSizeChanged", function(self, w)
            if w and w > 0 then scrollChild:SetWidth(w) end
        end)

        self:BuildModule(scrollChild, catId)
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
            if Castborn.HideTestModePanel then Castborn:HideTestModePanel() end
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
    local _, playerClass = UnitClass("player")
    local modules = {
        { key = "player", label = "Player Castbar" },
        { key = "target", label = "Target Castbar" },
        { key = "focus", label = "Focus Castbar" },
        { key = "targettarget", label = "Target of Target" },
        { key = "gcd", label = "GCD Indicator" },
        { key = "fsr", label = "5 Second Rule" },
        { key = "swing", label = "Swing Timer" },
        { key = "dots", label = "DoT Tracker" },
        { key = "buffs", label = "Proc Tracker" },
        { key = "cooldowns", label = "Cooldowns" },
        { key = "totems", label = "Totem Tracker", class = "SHAMAN" },
        { key = "absorbs", label = "Absorb Tracker", class = "MAGE" },
    }

    local col = 0
    local startY = y
    local count = 0
    for i, mod in ipairs(modules) do
        -- Skip class-restricted modules for other classes
        if not mod.class or mod.class == playerClass then
            count = count + 1
            CastbornDB[mod.key] = CastbornDB[mod.key] or {}
            local cb = CreateCheckbox(parent, mod.label, CastbornDB[mod.key], "enabled")
            cb:SetPoint("TOPLEFT", col * 200, y)
            y = y - 26
            if count == 5 then
                col = 1
                y = startY
            end
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

    local cb2 = CreateCheckbox(parent, "Show Icon", CastbornDB.player, "showIcon", function(checked)
        local playerBar = Castborn.castbars and Castborn.castbars.player
        if playerBar and playerBar.iconFrame then
            if checked then
                playerBar.iconFrame:Show()
            else
                playerBar.iconFrame:Hide()
            end
        end
    end)
    cb2:SetPoint("TOPLEFT", 0, y)
    local cb3 = CreateCheckbox(parent, "Show Time", CastbornDB.player, "showTime", function(checked)
        local playerBar = Castborn.castbars and Castborn.castbars.player
        if playerBar and playerBar.timeText then
            if checked then
                playerBar.timeText:Show()
            else
                playerBar.timeText:Hide()
            end
        end
    end)
    cb3:SetPoint("TOPLEFT", 150, y)
    y = y - 26

    local cb4 = CreateCheckbox(parent, "Show Spell Name", CastbornDB.player, "showSpellName", function(checked)
        local playerBar = Castborn.castbars and Castborn.castbars.player
        if playerBar and playerBar.spellText then
            if checked then
                playerBar.spellText:Show()
            else
                playerBar.spellText:Hide()
            end
        end
    end)
    cb4:SetPoint("TOPLEFT", 0, y)
    local cb5 = CreateCheckbox(parent, "Show Latency", CastbornDB.player, "showLatency", function(checked)
        local playerBar = Castborn.castbars and Castborn.castbars.player
        if playerBar and playerBar.latency then
            if checked then
                playerBar.latency:Show()
            else
                playerBar.latency:Hide()
            end
        end
    end)
    cb5:SetPoint("TOPLEFT", 150, y)
    y = y - 26

    local cbRank = CreateCheckbox(parent, "Show Spell Rank", CastbornDB.player, "showSpellRank")
    cbRank:SetPoint("TOPLEFT", 0, y)
    y = y - 26

    local cb6 = CreateCheckbox(parent, "Hide Blizzard Castbar", CastbornDB.player, "hideBlizzardCastBar", function(checked)
        if checked then
            Castborn:HideBlizzardCastBar()
        else
            Castborn:ShowBlizzardCastBar()
        end
    end)
    cb6:SetPoint("TOPLEFT", 0, y)
    local cb7 = CreateCheckbox(parent, "Hide Tradeskill Casts", CastbornDB.player, "hideTradeSkills")
    cb7:SetPoint("TOPLEFT", 150, y)
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
            if f.shield then f.shield:SetSize(v * 1.5, v * 1.5) end
            if f.spellText then f.spellText:SetFont("Fonts\\ARIALN.TTF", math.max(10, v - 6), "OUTLINE") end
            if f.timeText then f.timeText:SetFont("Fonts\\ARIALN.TTF", math.max(10, v - 6), "OUTLINE") end
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

    local tcb2 = CreateCheckbox(parent, "Show Icon", CastbornDB.target, "showIcon", function(checked)
        local targetBar = Castborn.castbars and Castborn.castbars.target
        if targetBar and targetBar.iconFrame then
            if checked then
                targetBar.iconFrame:Show()
            else
                targetBar.iconFrame:Hide()
            end
        end
    end)
    tcb2:SetPoint("TOPLEFT", 0, y)
    local tcb3 = CreateCheckbox(parent, "Show Time", CastbornDB.target, "showTime", function(checked)
        local targetBar = Castborn.castbars and Castborn.castbars.target
        if targetBar and targetBar.timeText then
            if checked then
                targetBar.timeText:Show()
            else
                targetBar.timeText:Hide()
            end
        end
    end)
    tcb3:SetPoint("TOPLEFT", 150, y)
    y = y - 36

    local tslider1 = CreateSlider(parent, "Width", CastbornDB.target, "width", 100, 400, 10, function(v)
        if Castborn.castbars and Castborn.castbars.target then
            Castborn.castbars.target:SetWidth(v)
        end
    end)
    tslider1:SetPoint("TOPLEFT", 0, y)

    local tslider2 = CreateSlider(parent, "Height", CastbornDB.target, "height", 10, 40, 2, function(v)
        local f = Castborn.castbars and Castborn.castbars.target
        if f then
            f:SetHeight(v)
            if f.iconFrame then f.iconFrame:SetSize(v + 4, v + 4) end
            if f.spark then f.spark:SetHeight(v * 2.5) end
            if f.shield then f.shield:SetSize(v * 1.5, v * 1.5) end
            if f.spellText then f.spellText:SetFont("Fonts\\ARIALN.TTF", math.max(10, v - 6), "OUTLINE") end
            if f.timeText then f.timeText:SetFont("Fonts\\ARIALN.TTF", math.max(10, v - 6), "OUTLINE") end
        end
    end)
    tslider2:SetPoint("TOPLEFT", 220, y)
    y = y - 60

    -- Focus Castbar
    local header3 = CreateHeader(parent, "Focus Castbar")
    header3:SetPoint("TOPLEFT", 0, y)
    header3:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    CastbornDB.focus = CastbornDB.focus or {}

    local fcb1 = CreateCheckbox(parent, "Show Icon", CastbornDB.focus, "showIcon", function(checked)
        local focusBar = Castborn.castbars and Castborn.castbars.focus
        if focusBar and focusBar.iconFrame then
            if checked then
                focusBar.iconFrame:Show()
            else
                focusBar.iconFrame:Hide()
            end
        end
    end)
    fcb1:SetPoint("TOPLEFT", 0, y)
    local fcb2 = CreateCheckbox(parent, "Show Time", CastbornDB.focus, "showTime", function(checked)
        local focusBar = Castborn.castbars and Castborn.castbars.focus
        if focusBar and focusBar.timeText then
            if checked then
                focusBar.timeText:Show()
            else
                focusBar.timeText:Hide()
            end
        end
    end)
    fcb2:SetPoint("TOPLEFT", 150, y)
    y = y - 36

    local fslider1 = CreateSlider(parent, "Width", CastbornDB.focus, "width", 100, 400, 10, function(v)
        if Castborn.castbars and Castborn.castbars.focus then
            Castborn.castbars.focus:SetWidth(v)
        end
    end)
    fslider1:SetPoint("TOPLEFT", 0, y)

    local fslider2 = CreateSlider(parent, "Height", CastbornDB.focus, "height", 10, 40, 2, function(v)
        local f = Castborn.castbars and Castborn.castbars.focus
        if f then
            f:SetHeight(v)
            if f.iconFrame then f.iconFrame:SetSize(v + 4, v + 4) end
            if f.spark then f.spark:SetHeight(v * 2.5) end
            if f.shield then f.shield:SetSize(v * 1.5, v * 1.5) end
            if f.spellText then f.spellText:SetFont("Fonts\\ARIALN.TTF", math.max(10, v - 6), "OUTLINE") end
            if f.timeText then f.timeText:SetFont("Fonts\\ARIALN.TTF", math.max(10, v - 6), "OUTLINE") end
        end
    end)
    fslider2:SetPoint("TOPLEFT", 220, y)
    y = y - 60

    -- Target-of-Target Castbar
    local header4 = CreateHeader(parent, "Target-of-Target Castbar")
    header4:SetPoint("TOPLEFT", 0, y)
    header4:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    CastbornDB.targettarget = CastbornDB.targettarget or {}

    local ttcb1 = CreateCheckbox(parent, "Show Icon", CastbornDB.targettarget, "showIcon", function(checked)
        local totBar = Castborn.castbars and Castborn.castbars.targettarget
        if totBar and totBar.iconFrame then
            if checked then
                totBar.iconFrame:Show()
            else
                totBar.iconFrame:Hide()
            end
        end
    end)
    ttcb1:SetPoint("TOPLEFT", 0, y)
    local ttcb2 = CreateCheckbox(parent, "Show Time", CastbornDB.targettarget, "showTime", function(checked)
        local totBar = Castborn.castbars and Castborn.castbars.targettarget
        if totBar and totBar.timeText then
            if checked then
                totBar.timeText:Show()
            else
                totBar.timeText:Hide()
            end
        end
    end)
    ttcb2:SetPoint("TOPLEFT", 150, y)
    y = y - 36

    local ttslider1 = CreateSlider(parent, "Width", CastbornDB.targettarget, "width", 100, 400, 10, function(v)
        if Castborn.castbars and Castborn.castbars.targettarget then
            Castborn.castbars.targettarget:SetWidth(v)
        end
    end)
    ttslider1:SetPoint("TOPLEFT", 0, y)

    local ttslider2 = CreateSlider(parent, "Height", CastbornDB.targettarget, "height", 10, 40, 2, function(v)
        local f = Castborn.castbars and Castborn.castbars.targettarget
        if f then
            f:SetHeight(v)
            if f.iconFrame then f.iconFrame:SetSize(v + 4, v + 4) end
            if f.spark then f.spark:SetHeight(v * 2.5) end
            if f.shield then f.shield:SetSize(v * 1.5, v * 1.5) end
            if f.spellText then f.spellText:SetFont("Fonts\\ARIALN.TTF", math.max(10, v - 6), "OUTLINE") end
            if f.timeText then f.timeText:SetFont("Fonts\\ARIALN.TTF", math.max(10, v - 6), "OUTLINE") end
        end
    end)
    ttslider2:SetPoint("TOPLEFT", 220, y)
    y = y - 60

    parent:SetHeight(math.abs(y) + 20)
end

function Options:BuildLookFeel(parent)
    local y = 0

    local header1 = CreateHeader(parent, "Colors")
    header1:SetPoint("TOPLEFT", 0, y)
    header1:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    local cb1 = CreateCheckbox(parent, "Use Class Colors", CastbornDB, "useClassColors", function(checked)
        -- Refresh castbar colors
        if Castborn.RefreshCastbarColors then
            Castborn:RefreshCastbarColors()
        end
    end)
    cb1:SetPoint("TOPLEFT", 0, y)
    y = y - 40

    local header2 = CreateHeader(parent, "Effects")
    header2:SetPoint("TOPLEFT", 0, y)
    header2:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    CastbornDB.cooldowns = CastbornDB.cooldowns or {}
    local cb2 = CreateCheckbox(parent, "Cooldowns Glow", CastbornDB.cooldowns, "showReadyGlow", function(checked)
        if not checked then
            Castborn:FireCallback("COOLDOWNS_GLOW_OFF")
        end
    end)
    cb2:SetPoint("TOPLEFT", 0, y)
    y = y - 40

    local header3 = CreateHeader(parent, "Appearance")
    header3:SetPoint("TOPLEFT", 0, y)
    header3:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    CastbornDB.bgOpacity = CastbornDB.bgOpacity or 1
    local opacitySlider = CreateSlider(parent, "Background Opacity", CastbornDB, "bgOpacity", 0, 1, 0.05, function()
        if Castborn.RefreshBackdropOpacity then
            Castborn:RefreshBackdropOpacity()
        end
    end)
    opacitySlider:SetPoint("TOPLEFT", 0, y)
end

function Options:BuildProfiles(parent)
    local y = 0
    local Profiles = Castborn.Profiles

    -- Profile Management header
    local header1 = CreateHeader(parent, "Profile Management")
    header1:SetPoint("TOPLEFT", 0, y)
    header1:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    -- Character label
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    local charLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    charLabel:SetPoint("TOPLEFT", 0, y)
    charLabel:SetText("Character: |cffFFCC00" .. charKey .. "|r")
    y = y - 26

    -- Current Profile dropdown
    local dropdownLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropdownLabel:SetPoint("TOPLEFT", 0, y)
    dropdownLabel:SetText("Current Profile:")
    dropdownLabel:SetTextColor(unpack(C.grey))

    local dropdown = CreateFrame("Frame", "CastbornProfileDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 90, y + 6)
    UIDropDownMenu_SetWidth(dropdown, 150)

    local function RefreshDropdown()
        local profiles = Profiles:GetProfileList()
        local currentProfile = Profiles:GetCurrentProfileName()

        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, profileName in ipairs(profiles) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = profileName
                info.value = profileName
                info.checked = (profileName == currentProfile)
                info.func = function()
                    Profiles:SetCurrentProfile(profileName)
                    UIDropDownMenu_SetText(dropdown, profileName)
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetText(dropdown, currentProfile)
    end
    RefreshDropdown()

    y = y - 36

    -- Profile action buttons
    local newBtn = CreateButton(parent, "New", 70, function()
        StaticPopup_Show("CASTBORN_NEW_PROFILE")
    end)
    newBtn:SetPoint("TOPLEFT", 0, y)

    local copyBtn = CreateButton(parent, "Copy", 70, function()
        StaticPopup_Show("CASTBORN_COPY_PROFILE")
    end)
    copyBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)

    local deleteBtn = CreateButton(parent, "Delete", 70, function()
        local currentProfile = Profiles:GetCurrentProfileName()
        if currentProfile == "Default" then
            Castborn:Print("Cannot delete the Default profile")
            return
        end
        StaticPopup_Show("CASTBORN_DELETE_PROFILE", currentProfile)
    end)
    deleteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 6, 0)

    local saveBtn = CreateButton(parent, "Save", 70, function()
        local currentProfile = Profiles:GetCurrentProfileName()
        Profiles:SaveCurrentToProfile(currentProfile)
        Castborn:Print("Saved current settings to profile: " .. currentProfile)
    end)
    saveBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 6, 0)

    y = y - 50

    -- Import/Export header
    local header2 = CreateHeader(parent, "Import / Export")
    header2:SetPoint("TOPLEFT", 0, y)
    header2:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    -- Export/Import buttons
    local exportBtn = CreateButton(parent, "Export", 100, function()
        local currentProfile = Profiles:GetCurrentProfileName()
        local data, err = Profiles:ExportProfile(currentProfile)
        if data then
            parent.exportEditBox:SetText(data)
            parent.exportEditBox:HighlightText()
            parent.exportEditBox:SetFocus()
            Castborn:Print("Profile exported. Press Ctrl+C to copy.")
        else
            Castborn:Print("Export failed: " .. (err or "unknown error"))
        end
    end)
    exportBtn:SetPoint("TOPLEFT", 0, y)

    local importBtn = CreateButton(parent, "Import", 100, function()
        local data = parent.exportEditBox:GetText()
        if not data or data == "" then
            Castborn:Print("Paste profile data into the text box first")
            return
        end
        StaticPopup_Show("CASTBORN_IMPORT_PROFILE", nil, nil, data)
    end)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)

    y = y - 32

    -- Multi-line edit box for import/export data
    local editBoxContainer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    editBoxContainer:SetPoint("TOPLEFT", 0, y)
    editBoxContainer:SetPoint("TOPRIGHT", 0, y)
    editBoxContainer:SetHeight(100)
    editBoxContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    editBoxContainer:SetBackdropColor(unpack(C.bgInput))
    editBoxContainer:SetBackdropBorderColor(unpack(C.borderDark))

    local scrollFrame = CreateFrame("ScrollFrame", "CastbornProfileExportScroll", editBoxContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)

    local editBox = CreateFrame("EditBox", "CastbornProfileExportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth() or 350)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    parent.exportEditBox = editBox

    -- Register StaticPopup dialogs
    if not StaticPopupDialogs["CASTBORN_NEW_PROFILE"] then
        StaticPopupDialogs["CASTBORN_NEW_PROFILE"] = {
            text = "Enter new profile name:",
            button1 = "Create",
            button2 = "Cancel",
            hasEditBox = true,
            editBoxWidth = 200,
            OnAccept = function(self)
                local name = self.EditBox:GetText()
                if name and name ~= "" then
                    Profiles:CreateProfile(name)
                    Profiles:SetCurrentProfile(name)
                    RefreshDropdown()
                    Castborn:Print("Created and switched to profile: " .. name)
                end
            end,
            OnShow = function(self)
                self.EditBox:SetText("")
                self.EditBox:SetFocus()
            end,
            EditBoxOnEnterPressed = function(self)
                local parent = self:GetParent()
                local name = self:GetText()
                if name and name ~= "" then
                    Profiles:CreateProfile(name)
                    Profiles:SetCurrentProfile(name)
                    RefreshDropdown()
                    Castborn:Print("Created and switched to profile: " .. name)
                end
                parent:Hide()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }

        StaticPopupDialogs["CASTBORN_COPY_PROFILE"] = {
            text = "Enter name for the copy:",
            button1 = "Copy",
            button2 = "Cancel",
            hasEditBox = true,
            editBoxWidth = 200,
            OnAccept = function(self)
                local name = self.EditBox:GetText()
                if name and name ~= "" then
                    local current = Profiles:GetCurrentProfileName()
                    Profiles:CopyProfile(current, name)
                    RefreshDropdown()
                    Castborn:Print("Copied profile '" .. current .. "' to '" .. name .. "'")
                end
            end,
            OnShow = function(self)
                self.EditBox:SetText("")
                self.EditBox:SetFocus()
            end,
            EditBoxOnEnterPressed = function(self)
                local parent = self:GetParent()
                local name = self:GetText()
                if name and name ~= "" then
                    local current = Profiles:GetCurrentProfileName()
                    Profiles:CopyProfile(current, name)
                    RefreshDropdown()
                    Castborn:Print("Copied profile '" .. current .. "' to '" .. name .. "'")
                end
                parent:Hide()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }

        StaticPopupDialogs["CASTBORN_DELETE_PROFILE"] = {
            text = "Delete profile '%s'?",
            button1 = "Delete",
            button2 = "Cancel",
            OnAccept = function(self, data)
                local profileName = Profiles:GetCurrentProfileName()
                Profiles:DeleteProfile(profileName)
                Profiles:SetCurrentProfile("Default")
                RefreshDropdown()
                Castborn:Print("Deleted profile: " .. profileName)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            showAlert = true,
        }

        StaticPopupDialogs["CASTBORN_IMPORT_PROFILE"] = {
            text = "Enter name for imported profile:",
            button1 = "Import",
            button2 = "Cancel",
            hasEditBox = true,
            editBoxWidth = 200,
            OnAccept = function(self, data)
                local name = self.EditBox:GetText()
                if name and name ~= "" and data then
                    local success, err = Profiles:ImportProfile(name, data)
                    if success then
                        RefreshDropdown()
                        Castborn:Print("Imported profile: " .. name)
                    else
                        Castborn:Print("Import failed: " .. (err or "unknown error"))
                    end
                end
            end,
            OnShow = function(self)
                self.EditBox:SetText("")
                self.EditBox:SetFocus()
            end,
            EditBoxOnEnterPressed = function(self)
                local parent = self:GetParent()
                local name = self:GetText()
                local data = parent.data
                if name and name ~= "" and data then
                    local success, err = Profiles:ImportProfile(name, data)
                    if success then
                        RefreshDropdown()
                        Castborn:Print("Imported profile: " .. name)
                    else
                        Castborn:Print("Import failed: " .. (err or "unknown error"))
                    end
                end
                parent:Hide()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
    end
end

function Options:BuildChangelog(parent)
    local y = 0

    local header1 = CreateHeader(parent, "Version History")
    header1:SetPoint("TOPLEFT", 0, y)
    header1:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    -- Create scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, y)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 400)
    scrollFrame:SetScrollChild(scrollChild)

    -- Get changelog data from WhatsNew module
    local changelog = Castborn.WhatsNew and Castborn.WhatsNew:GetChangelog() or {}

    local contentY = 0
    local contentWidth = 400

    for i, entry in ipairs(changelog) do
        -- Version header
        local versionHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        versionHeader:SetPoint("TOPLEFT", 0, contentY)
        versionHeader:SetWidth(contentWidth)
        versionHeader:SetJustifyH("LEFT")

        if i == 1 then
            versionHeader:SetText("|cffFFCC00v" .. entry.version .. " (Current)|r")
        else
            versionHeader:SetText("|cff888888v" .. entry.version .. "|r")
        end

        contentY = contentY - 18

        -- Features section
        if entry.features and #entry.features > 0 then
            local featuresLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            featuresLabel:SetPoint("TOPLEFT", 8, contentY)
            featuresLabel:SetText("|cff88ddffFeatures:|r")
            contentY = contentY - 14

            for _, feature in ipairs(entry.features) do
                local bullet = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                bullet:SetPoint("TOPLEFT", 16, contentY)
                bullet:SetWidth(contentWidth - 24)
                bullet:SetJustifyH("LEFT")
                bullet:SetText("|cffcccccc-|r " .. feature)
                bullet:SetSpacing(2)
                local textHeight = bullet:GetStringHeight()
                contentY = contentY - textHeight - 2
            end
        end

        -- Changes section
        if entry.changes and #entry.changes > 0 then
            local changesLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            changesLabel:SetPoint("TOPLEFT", 8, contentY)
            changesLabel:SetText("|cffffcc00Changes:|r")
            contentY = contentY - 14

            for _, change in ipairs(entry.changes) do
                local bullet = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                bullet:SetPoint("TOPLEFT", 16, contentY)
                bullet:SetWidth(contentWidth - 24)
                bullet:SetJustifyH("LEFT")
                bullet:SetText("|cffcccccc-|r " .. change)
                bullet:SetSpacing(2)
                local textHeight = bullet:GetStringHeight()
                contentY = contentY - textHeight - 2
            end
        end

        -- Fixes section
        if entry.fixes and #entry.fixes > 0 then
            local fixesLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fixesLabel:SetPoint("TOPLEFT", 8, contentY)
            fixesLabel:SetText("|cff88ff88Fixes:|r")
            contentY = contentY - 14

            for _, fix in ipairs(entry.fixes) do
                local bullet = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                bullet:SetPoint("TOPLEFT", 16, contentY)
                bullet:SetWidth(contentWidth - 24)
                bullet:SetJustifyH("LEFT")
                bullet:SetText("|cffcccccc-|r " .. fix)
                bullet:SetSpacing(2)
                local textHeight = bullet:GetStringHeight()
                contentY = contentY - textHeight - 2
            end
        end

        -- Spacing between versions
        contentY = contentY - 10
    end

    -- Set scroll child height
    scrollChild:SetHeight(math.abs(contentY) + 20)
end

function Options:BuildModule(parent, key)
    local titles = {
        gcd = "GCD Indicator",
        fsr = "5 Second Rule",
        swing = "Swing Timer",
        dots = "DoT Tracker",
        multidot = "Multi-DoT Tracker",
        buffs = "Proc Tracker",
        cooldowns = "Cooldown Tracker",
        interrupt = "Interrupt Tracker",
        totems = "Totem Tracker",
        absorbs = "Absorb Tracker",
    }

    local y = 0

    local header = CreateHeader(parent, titles[key] or key)
    header:SetPoint("TOPLEFT", 0, y)
    header:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    CastbornDB[key] = CastbornDB[key] or {}
    local db = CastbornDB[key]

    -- Width/Height sliders for applicable modules
    if key == "gcd" or key == "fsr" or key == "swing" or key == "absorbs" then
        db.width = db.width or 200
        local widthSlider = CreateSlider(parent, "Width", db, "width", 50, 400, 10, function(v)
            if key == "gcd" and Castborn.gcdFrame then Castborn.gcdFrame:SetWidth(v)
            elseif key == "fsr" and Castborn.fsrFrame then Castborn.fsrFrame:SetWidth(v)
            elseif key == "swing" and Castborn.swingTimers then
                if Castborn.swingTimers.mainhand then Castborn.swingTimers.mainhand:SetWidth(v) end
                if Castborn.swingTimers.offhand then Castborn.swingTimers.offhand:SetWidth(v) end
                if Castborn.swingTimers.ranged then Castborn.swingTimers.ranged:SetWidth(v) end
            elseif key == "absorbs" then
                local f = _G["Castborn_AbsorbTracker"]
                if f then f:SetWidth(v) end
            end
        end)
        widthSlider:SetPoint("TOPLEFT", 0, y)

        if key == "gcd" or key == "fsr" or key == "absorbs" then
            local hKey = db.barHeight ~= nil and "barHeight" or "height"
            db[hKey] = db[hKey] or 12
            local heightSlider = CreateSlider(parent, "Height", db, hKey, 2, 40, 2, function(v)
                if key == "gcd" and Castborn.gcdFrame then Castborn.gcdFrame:SetHeight(v)
                elseif key == "fsr" and Castborn.fsrFrame then Castborn.fsrFrame:SetHeight(v)
                elseif key == "absorbs" then
                    local f = _G["Castborn_AbsorbTracker"]
                    if f then f:SetHeight(v) end
                end
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

        db.width = db.width or 200
        local dotWidthSlider = CreateSlider(parent, "Width", db, "width", 100, 400, 10, function(v)
            if Castborn.dotTracker then Castborn.dotTracker:SetWidth(v) end
        end)
        dotWidthSlider:SetPoint("TOPLEFT", 0, y)

        db.barHeight = db.barHeight or 16
        local dotBarHeightSlider = CreateSlider(parent, "Bar Height", db, "barHeight", 10, 30, 1, function(v)
            if Castborn.dotTracker then
                Castborn.dotTracker:SetHeight(math.max(30, 3 * (v + (db.spacing or 2)) + 8))
            end
        end)
        dotBarHeightSlider:SetPoint("TOPLEFT", 220, y)
        y = y - 60

        db.spacing = db.spacing or 2
        local spacingSlider = CreateSlider(parent, "Bar Spacing", db, "spacing", 0, 10, 1, function(v)
            if Castborn.dotTracker then
                Castborn.dotTracker:SetHeight(math.max(30, 3 * ((db.barHeight or 16) + v) + 8))
            end
        end)
        spacingSlider:SetPoint("TOPLEFT", 0, y)

    elseif key == "swing" then
        local testBtn = CreateButton(parent, "Test Swing", 90, function()
            if Castborn.TestSwingTimers then Castborn:TestSwingTimers() end
        end)
        testBtn:SetPoint("TOPLEFT", 0, y)

    elseif key == "buffs" then
        -- ProcTracker stores settings in CastbornDB.procs, not CastbornDB.buffs
        local procsDB = CastbornDB.procs

        local timersCB = CreateCheckbox(parent, "Show Timers", procsDB, "showDuration")
        timersCB:SetPoint("TOPLEFT", 0, y)

        local glowCB = CreateCheckbox(parent, "Show Proc Glow", procsDB, "showGlow")
        glowCB:SetPoint("TOPLEFT", 220, y)
        y = y - 36

        procsDB.iconSize = procsDB.iconSize or 28
        local iconSlider = CreateSlider(parent, "Icon Size", procsDB, "iconSize", 20, 56, 2, function()
            if Castborn.ProcTracker then Castborn.ProcTracker:UpdateLayout() end
        end)
        iconSlider:SetPoint("TOPLEFT", 0, y)

    elseif key == "cooldowns" then
        -- Icon Size and Spacing sliders
        db.iconSize = db.iconSize or 36
        local iconSlider = CreateSlider(parent, "Icon Size", db, "iconSize", 20, 56, 2)
        iconSlider:SetPoint("TOPLEFT", 0, y)
        db.spacing = db.spacing or 4
        local spacingSlider = CreateSlider(parent, "Spacing", db, "spacing", 0, 12, 1)
        spacingSlider:SetPoint("TOPLEFT", 220, y)
        y = y - 50

        -- Grow direction checkbox
        local growCB = CreateCheckbox(parent, "Grow Left", db, "growLeft", function(v)
            db.growDirection = v and "LEFT" or "RIGHT"
        end)
        -- Sync initial state from growDirection
        db.growLeft = (db.growDirection == "LEFT")
        growCB:SetChecked(db.growLeft)
        growCB:SetPoint("TOPLEFT", 0, y)

        local trinketCB = CreateCheckbox(parent, "Track Trinket Cooldowns", db, "trackTrinkets")
        trinketCB:SetPoint("TOPLEFT", 220, y)
        y = y - 30

        -- Divider
        local divider = parent:CreateTexture(nil, "ARTWORK")
        divider:SetHeight(1)
        divider:SetPoint("TOPLEFT", 0, y - 4)
        divider:SetPoint("TOPRIGHT", 0, y - 4)
        divider:SetColorTexture(0.25, 0.25, 0.25, 1)
        y = y - 14

        -- Build ordered list from SpellData (ensures all class spells are always shown)
        local _, class = UnitClass("player")
        local classSpells = Castborn.SpellData and Castborn.SpellData:GetClassCooldowns(class) or {}
        db.trackedSpells = db.trackedSpells or {}

        -- Index existing tracked spells by spellId for quick lookup
        local tracked = {}
        for _, spell in ipairs(db.trackedSpells) do
            tracked[spell.spellId] = spell
        end

        -- Ensure all class spells exist in trackedSpells
        for _, def in ipairs(classSpells) do
            if not tracked[def.spellId] then
                local entry = { spellId = def.spellId, name = def.name, enabled = true }
                table.insert(db.trackedSpells, entry)
                tracked[def.spellId] = entry
            end
        end

        -- Container for spell rows (so we can rebuild on reorder)
        local spellListContainer = CreateFrame("Frame", nil, parent)
        spellListContainer:SetPoint("TOPLEFT", 0, y)
        spellListContainer:SetPoint("TOPRIGHT", 0, y)
        spellListContainer:SetHeight(1)  -- Will be resized

        local function BuildSpellList()
            -- Clear existing children
            for _, child in ipairs({spellListContainer:GetChildren()}) do
                child:Hide()
                child:SetParent(nil)
            end

            local listY = 0
            local total = #db.trackedSpells

            for i, spell in ipairs(db.trackedSpells) do
                if spell.enabled == nil then spell.enabled = true end

                local row = CreateFrame("Frame", nil, spellListContainer)
                row:SetHeight(26)
                row:SetPoint("TOPLEFT", 0, listY)
                row:SetPoint("TOPRIGHT", 0, listY)

                -- Checkbox
                local cb = CreateCheckbox(row, spell.name, spell, "enabled")
                cb:SetPoint("LEFT", 0, 0)

                -- Down arrow
                local downBtn = CreateFrame("Button", nil, row)
                downBtn:SetSize(14, 14)
                downBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                downBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
                downBtn:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight")
                downBtn:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
                if i == total then
                    downBtn:SetAlpha(0.3)
                    downBtn:Disable()
                end
                downBtn:SetScript("OnClick", function()
                    if i < total then
                        db.trackedSpells[i], db.trackedSpells[i + 1] = db.trackedSpells[i + 1], db.trackedSpells[i]
                        BuildSpellList()
                        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                    end
                end)

                -- Up arrow
                local upBtn = CreateFrame("Button", nil, row)
                upBtn:SetSize(14, 14)
                upBtn:SetPoint("RIGHT", downBtn, "LEFT", -2, 0)
                upBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
                upBtn:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight")
                upBtn:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
                if i == 1 then
                    upBtn:SetAlpha(0.3)
                    upBtn:Disable()
                end
                upBtn:SetScript("OnClick", function()
                    if i > 1 then
                        db.trackedSpells[i], db.trackedSpells[i - 1] = db.trackedSpells[i - 1], db.trackedSpells[i]
                        BuildSpellList()
                        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                    end
                end)

                listY = listY - 26
            end

            spellListContainer:SetHeight(math.abs(listY) + 4)
        end

        BuildSpellList()
        y = y - (26 * #db.trackedSpells) - 4

    elseif key == "interrupt" then
        local targetCB = CreateCheckbox(parent, "Track Target", db, "trackTarget")
        targetCB:SetPoint("TOPLEFT", 0, y)
        local focusCB = CreateCheckbox(parent, "Track Focus", db, "trackFocus")
        focusCB:SetPoint("TOPLEFT", 150, y)

    elseif key == "totems" then
        db.width = db.width or 200
        local totemWidthSlider = CreateSlider(parent, "Width", db, "width", 100, 400, 10, function(v)
            if Castborn.totemTracker then Castborn.totemTracker:SetWidth(v) end
        end)
        totemWidthSlider:SetPoint("TOPLEFT", 0, y)
        y = y - 60

        db.barHeight = db.barHeight or 16
        local barHeightSlider = CreateSlider(parent, "Bar Height", db, "barHeight", 10, 30, 1, function(v)
            if Castborn.totemTracker then
                Castborn.totemTracker:SetHeight(v * 4 + (db.spacing or 2) * 3 + 8)
            end
        end)
        barHeightSlider:SetPoint("TOPLEFT", 0, y)
        db.spacing = db.spacing or 2
        local spacingSlider = CreateSlider(parent, "Bar Spacing", db, "spacing", 0, 10, 1, function(v)
            if Castborn.totemTracker then
                Castborn.totemTracker:SetHeight((db.barHeight or 16) * 4 + v * 3 + 8)
            end
        end)
        spacingSlider:SetPoint("TOPLEFT", 220, y)
        y = y - 60

        local tooltipCB = CreateCheckbox(parent, "Show Tooltip (party members not in range)", db, "showTooltip")
        tooltipCB:SetPoint("TOPLEFT", 0, y)
        y = y - 30

        local testBtn = CreateButton(parent, "Test Totems", 100, function()
            if Castborn.TestTotemTracker then Castborn:TestTotemTracker() end
        end)
        testBtn:SetPoint("TOPLEFT", 0, y)

    elseif key == "multidot" then
        db.maxTargets = db.maxTargets or 5
        local maxSlider = CreateSlider(parent, "Max Targets", db, "maxTargets", 1, 10, 1)
        maxSlider:SetPoint("TOPLEFT", 0, y)
        local sortCB = CreateCheckbox(parent, "Sort by Time", db, "sortByTime")
        sortCB:SetPoint("TOPLEFT", 220, y + 15)

        y = y - 50

        local mdWidthSlider = CreateSlider(parent, "Width", db, "width", 100, 400, 10, function(v)
            local mdFrame = _G["Castborn_MultiDoTTracker"]
            if mdFrame then
                local maxT = db.maxTargets or 5
                mdFrame:SetWidth(v)
                for i = 1, maxT do
                    local row = _G["Castborn_MultiDoT_Row" .. i]
                    if row then row:SetWidth(v - 4) end
                end
            end
        end)
        mdWidthSlider:SetPoint("TOPLEFT", 0, y)

        db.rowHeight = db.rowHeight or 20
        local mdRowSlider = CreateSlider(parent, "Row Height", db, "rowHeight", 12, 32, 2, function(v)
            local mdFrame = _G["Castborn_MultiDoTTracker"]
            if mdFrame then
                local maxT = db.maxTargets or 5
                mdFrame:SetHeight(v * maxT + 18)
                for i = 1, maxT do
                    local row = _G["Castborn_MultiDoT_Row" .. i]
                    if row then
                        row:SetHeight(v)
                        row:SetPoint("TOPLEFT", mdFrame, "TOPLEFT", 2, -14 - (i - 1) * v)
                        if row.urgency then row.urgency:SetHeight(v) end
                        if row.dots then
                            for j, dot in ipairs(row.dots) do
                                dot:SetSize(v - 4, v - 4)
                                dot:SetPoint("LEFT", row, "LEFT", 5 + (j - 1) * (v - 2), 0)
                            end
                        end
                        if row.name then
                            row.name:SetPoint("LEFT", row, "LEFT", 5 + 6 * (v - 2), 0)
                        end
                    end
                end
            end
        end)
        mdRowSlider:SetPoint("TOPLEFT", 220, y)
        y = y - 50

        -- Nameplate Indicators section
        local npHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        npHeader:SetPoint("TOPLEFT", 0, y)
        npHeader:SetText("|cff88ddffNameplate Indicators|r")
        y = y - 20

        local npDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        npDesc:SetPoint("TOPLEFT", 0, y)
        npDesc:SetWidth(350)
        npDesc:SetJustifyH("LEFT")
        npDesc:SetText("Show DoT timer badges on enemy nameplates. Helps identify which mob needs attention when multiple mobs have the same name.")
        npDesc:SetTextColor(0.7, 0.7, 0.7, 1)
        y = y - 30

        local npEnableCB = CreateCheckbox(parent, "Show Nameplate Indicators", db, "nameplateIndicators")
        npEnableCB:SetPoint("TOPLEFT", 0, y)
        y = y - 30

        db.nameplateIndicatorSize = db.nameplateIndicatorSize or 20
        local npSizeSlider = CreateSlider(parent, "Indicator Size", db, "nameplateIndicatorSize", 14, 32, 1)
        npSizeSlider:SetPoint("TOPLEFT", 0, y)

        -- Position dropdown
        local posLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        posLabel:SetPoint("TOPLEFT", 220, y)
        posLabel:SetText("Position:")
        posLabel:SetTextColor(unpack(C.grey))

        local posDropdown = CreateFrame("Frame", "CastbornNPIndicatorPosDropdown", parent, "UIDropDownMenuTemplate")
        posDropdown:SetPoint("TOPLEFT", 270, y + 6)
        UIDropDownMenu_SetWidth(posDropdown, 90)

        local positions = { "BOTTOM", "TOP", "LEFT", "RIGHT" }
        local positionLabels = { BOTTOM = "Bottom", TOP = "Top", LEFT = "Left", RIGHT = "Right" }
        UIDropDownMenu_Initialize(posDropdown, function(self, level)
            for _, pos in ipairs(positions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = positionLabels[pos]
                info.value = pos
                info.checked = (db.nameplateIndicatorPosition == pos)
                info.func = function()
                    db.nameplateIndicatorPosition = pos
                    UIDropDownMenu_SetText(posDropdown, positionLabels[pos])
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetText(posDropdown, positionLabels[db.nameplateIndicatorPosition or "BOTTOM"])
        y = y - 10

    elseif key == "absorbs" then
        local testBtn = CreateButton(parent, "Test Absorb", 90, function()
            if Castborn.TestAbsorbTracker then Castborn:TestAbsorbTracker() end
        end)
        testBtn:SetPoint("TOPLEFT", 0, y)
    end

    -- Set parent height for scroll frame
    parent:SetHeight(math.abs(y) + 20)
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

        -- Show What's New overlay if version changed
        if Castborn.WhatsNew and Castborn.WhatsNew:ShouldShow() then
            Castborn.WhatsNew:Show()
        end
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
        if Castborn.HideTestModePanel then Castborn:HideTestModePanel() end
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
    elseif cmd == "changelog" then
        Options:Show()
        Options:ShowCategory("changelog")
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
        print("  |cffFFCC00/cb changelog|r - View version history")
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
    version:SetText("Version " .. (Castborn.version or "?"))

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

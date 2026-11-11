--[[
    Castborn - GUI Options Panel
    Gilded Grimoire style; palette, fonts and the chamfered box come from Systems/Theme.lua
]]

local Options = {}
Castborn.Options = Options

local Theme = Castborn.Theme
local SIDEBAR_WIDTH = 168

--------------------------------------------------------------------------------
-- Style Constants
--------------------------------------------------------------------------------

-- Older page code colours text with these; they map onto the Gilded palette
local C = {
    gold = { Theme:Color("heading") },
    white = { Theme:Color("title") },
    grey = { Theme:Color("muted") },
    darkGrey = { Theme:Color("navText") },
    accent = { Theme:Color("accent") },
}

-- Font objects for labels and notes that pages create directly
local function MakeFont(name, role, size)
    local font = CreateFont(name)
    Theme:Font(font, role, size)
    return font
end
MakeFont("CastbornOptionsText", "body", 14)
MakeFont("CastbornOptionsSmall", "body", 12):SetTextColor(Theme:Color("muted"))
MakeFont("CastbornOptionsLarge", "heading", 19)

local LOGO_PATH = "Interface\\Icons\\Spell_Arcane_Arcane04"

-- Previews started from a page's Test button, ended when the window closes: EndTest name -> true
local openPreviews = {}

-- The Castborn dialog shown over the options window (see ShowDialog)
local dialog

local function StartPreview(startName, endName)
    if Castborn[startName] then
        Castborn[startName](Castborn)
        openPreviews[endName] = true
    end
end
local optionsFrame = nil
local contentFrames = {}
local currentCategory = "general"

local categories = {
    { id = "general", name = "General" },
    { id = "castbars", name = "Castbars" },
    { id = "resources", name = "Resource Bars" },
    { id = "gcd", name = "GCD Indicator" },
    { id = "fsr", name = "5 Second Rule" },
    { id = "swing", name = "Swing Timer" },
    { id = "dots", name = "DoT Tracker" },
    { id = "multidot", name = "Multi-DoT" },
    { id = "buffs", name = "Proc Tracker" },
    { id = "cooldowns", name = "Cooldowns" },
    { id = "itemtracker", name = "Items" },
    { id = "interrupt", name = "Interrupt" },
    { id = "cooldowntext", name = "Cooldown Text", module = "CooldownText" },  -- Forever only
    { id = "totems", name = "Totems", class = "SHAMAN" },
    { id = "absorbs", name = "Absorbs", class = "MAGE" },
    { id = "armortracker", name = "Armour", classes = {"MAGE", "WARLOCK", "PRIEST", "PALADIN"} },
    { id = "seals", name = "Seals", class = "PALADIN" },
    { divider = true },
    { id = "lookfeel", name = "Look & Feel" },
    { id = "profiles", name = "Profiles" },
    { id = "changelog", name = "Changelog" },
}

-- One line under each page title
local pageSubtitles = {
    general = "Lock and test your frames, and the essentials.",
    castbars = "Your castbar and those of your target, their target and your focus.",
    resources = "Your health and power, in their own movable frame.",
    gcd = "A sweep that shows the global cooldown.",
    fsr = "The five-second rule for mana regeneration.",
    swing = "When your next auto attack lands.",
    dots = "Your damage over time on your target.",
    multidot = "Your damage over time across every enemy.",
    buffs = "Procs and buffs worth reacting to.",
    cooldowns = "The spells you want to watch, in the order they appear.",
    itemtracker = "Potions, trinkets and other usable items.",
    interrupt = "Your interrupt, and when it is ready.",
    cooldowntext = "Countdown numbers on your action bars and Castborn icons.",
    totems = "Your totems and how long they have left.",
    absorbs = "Your absorb shields and what they have left.",
    armortracker = "A reminder when your self-buff is missing.",
    seals = "Your active seal and its time left.",
    lookfeel = "The texture and font every Castborn bar uses.",
    profiles = "Save a set of settings and share it between characters.",
    changelog = "What changed in each version.",
}

--------------------------------------------------------------------------------
-- UI Components
--------------------------------------------------------------------------------

-- Section heading: serif gold text with a quiet rule running to the right
local function CreateHeader(parent, text)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(24)

    local label = frame:CreateFontString(nil, "OVERLAY")
    Theme:Font(label, "heading", 19)
    label:SetPoint("LEFT", 0, 0)
    label:SetText(text)

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", label, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    line:SetColorTexture(Theme:Color("divider"))

    return frame
end

-- Group box: a quiet chamfered panel
local function CreateGroup(parent, title, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(height or 100)
    Theme:Chamfer(frame, { cut = 6, fill = "navA", edge = "divider" })

    if title then
        local label = frame:CreateFontString(nil, "OVERLAY")
        Theme:Font(label, "heading", 16)
        label:SetPoint("TOPLEFT", 8, 14)
        label:SetText(title)
    end

    return frame
end

-- Buttons and checkboxes are shared with the other Castborn windows (Systems/Theme.lua)
local function CreateButton(parent, text, width, onClick, variant)
    return Theme:CreateButton(parent, text, width, onClick, variant)
end

local function CreateCheckbox(parent, label, dbTable, dbKey, onChange)
    return Theme:CreateCheckbox(parent, label, dbTable, dbKey, onChange)
end

-- Slider (Systems/Theme.lua)
local function CreateSlider(parent, label, dbTable, dbKey, minVal, maxVal, step, onChange)
    return Theme:CreateSlider(parent, label, dbTable, dbKey, minVal, maxVal, step, onChange)
end

local function CreateColorPicker(parent, label, dbTable, dbKey, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(200, 26)

    local labelText = frame:CreateFontString(nil, "OVERLAY")
    Theme:Font(labelText, "body", 14)
    labelText:SetPoint("LEFT", 0, 0)
    labelText:SetText(label)

    -- Gilt frame: a chamfered gold-edged plate with the colour set inside it
    local swatch = CreateFrame("Button", nil, frame)
    swatch:SetSize(26, 26)
    swatch:SetPoint("LEFT", labelText, "RIGHT", 10, 0)
    Theme:Chamfer(swatch, { cut = 4, fill = "inputBg", edge = "accent" })
    swatch:SetScript("OnEnter", function(self) Theme:SetChamferColors(self, "knob", "heading") end)
    swatch:SetScript("OnLeave", function(self) Theme:SetChamferColors(self, "inputBg", "accent") end)

    local swatchColor = swatch:CreateTexture(nil, "ARTWORK")
    swatchColor:SetPoint("TOPLEFT", 5, -5)
    swatchColor:SetPoint("BOTTOMRIGHT", -5, 5)
    swatch.colorTex = swatchColor

    local function UpdateSwatch()
        local c = dbTable[dbKey] or {0.1, 0.1, 0.1, 0.8}
        swatchColor:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
    UpdateSwatch()

    swatch:SetScript("OnClick", function()
        local c = dbTable[dbKey] or {0.1, 0.1, 0.1, 0.8}
        local r, g, b, a = c[1], c[2], c[3], c[4] or 1

        -- Forever's modern client has no SetColorRGB or OpacitySliderFrame; it takes an info
        -- table, and opacity there is the alpha itself. TBC keeps the path below.
        if not ColorPickerFrame.SetColorRGB and ColorPickerFrame.SetupColorPickerAndShow then
            local function SetColor()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                dbTable[dbKey] = {nr, ng, nb, ColorPickerFrame:GetColorAlpha()}
                UpdateSwatch()
                if onChange then onChange(dbTable[dbKey]) end
            end
            -- Open on the next frame: the picker closes on any GLOBAL_MOUSE_DOWN outside itself,
            -- and the click that opened it could otherwise arrive after it is shown
            C_Timer.After(0, function()
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = r, g = g, b = b, opacity = a, hasOpacity = true,
                    swatchFunc = SetColor,
                    opacityFunc = SetColor,
                    cancelFunc = function()
                        dbTable[dbKey] = {r, g, b, a}
                        UpdateSwatch()
                        if onChange then onChange(dbTable[dbKey]) end
                    end,
                })
            end)
            return
        end

        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - a
        ColorPickerFrame.previousValues = {r, g, b, a}

        local function SetColor()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local opacity = OpacitySliderFrame and OpacitySliderFrame:GetValue() or ColorPickerFrame.opacity or 0
            local na = 1 - opacity
            dbTable[dbKey] = {nr, ng, nb, na}
            UpdateSwatch()
            if onChange then onChange(dbTable[dbKey]) end
        end

        ColorPickerFrame.swatchFunc = SetColor
        ColorPickerFrame.func = SetColor
        ColorPickerFrame.opacityFunc = SetColor
        ColorPickerFrame.cancelFunc = function(prev)
            dbTable[dbKey] = {prev[1], prev[2], prev[3], prev[4]}
            UpdateSwatch()
            if onChange then onChange(dbTable[dbKey]) end
        end

        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)

    frame.swatch = swatch
    frame.UpdateSwatch = UpdateSwatch
    return frame
end

-- Scrollbars on long pages (Systems/Theme.lua)
local function SkinScrollBar(scrollFrame)
    Theme:SkinScrollBar(scrollFrame)
end

-- UIDropDownMenuTemplate: the template's art hidden behind a chamfered box and a gold chevron.
-- The pop-up list is Blizzard's shared menu and keeps its own look.
local function SkinDropdown(dropdown)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local part = dropdown[key] or _G[(dropdown:GetName() or "") .. key]
        if part then part:SetAlpha(0) end
    end
    local box = CreateFrame("Frame", nil, dropdown)
    box:SetFrameLevel(math.max(0, dropdown:GetFrameLevel() - 1))
    box:SetPoint("LEFT", dropdown, "LEFT", 16, 2)
    local arrow = dropdown.Button or _G[(dropdown:GetName() or "") .. "Button"]
    if arrow then
        box:SetPoint("RIGHT", arrow, "RIGHT", 2, 0)
        for _, setter in ipairs({ "SetNormalTexture", "SetPushedTexture", "SetDisabledTexture", "SetHighlightTexture" }) do
            arrow[setter](arrow, Theme.media.chevron)
        end
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
            local tex = arrow[getter](arrow)
            if tex then
                tex:ClearAllPoints()
                tex:SetPoint("CENTER")
                tex:SetSize(12, 12)
                tex:SetVertexColor(Theme:Color("accent"))
            end
        end
        local glowTex = arrow:GetHighlightTexture()
        if glowTex then
            glowTex:ClearAllPoints()
            glowTex:SetPoint("CENTER")
            glowTex:SetSize(12, 12)
            glowTex:SetVertexColor(Theme:Color("title"))
        end
    else
        box:SetPoint("RIGHT", dropdown, "RIGHT", -16, 2)
    end
    box:SetHeight(26)
    Theme:Chamfer(box, { cut = 6, fill = "inputBg", edge = "rule" })
    local text = dropdown.Text or _G[(dropdown:GetName() or "") .. "Text"]
    if text then
        Theme:Font(text, "body", 13)
    end
end

-- Tabs: a row of chamfered buttons with the open one in gold. Returns the row frame and a
-- function that opens a tab by index (calling onSelect with it).
local function CreateTabs(parent, labels, onSelect)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(28)
    local tabs, x = {}, 0

    local function Paint(tab, hover)
        local edge = tab.open and nil or (hover and "accent" or "rule")
        Theme:SetChamferColors(tab, tab.open and "ribbonB" or "raised", edge)
        tab:GetFontString():SetTextColor(Theme:Color(tab.open and "onAccent" or (hover and "title" or "navText")))
    end

    local function Open(index)
        for i, tab in ipairs(tabs) do
            tab.open = i == index
            Paint(tab)
        end
        onSelect(index)
    end

    for i, label in ipairs(labels) do
        local tab = CreateFrame("Button", nil, row)
        tab:SetHeight(28)
        Theme:Chamfer(tab, { cut = 6 })
        local text = tab:CreateFontString(nil, "OVERLAY")
        Theme:Font(text, "strong", 13)
        text:SetPoint("CENTER", 0, 0)
        tab:SetFontString(text)
        tab:SetText(label)
        tab:SetWidth(text:GetStringWidth() + 32)
        tab:SetPoint("TOPLEFT", x, 0)
        x = x + tab:GetWidth() + 6
        tab:SetScript("OnEnter", function(self) Paint(self, true) end)
        tab:SetScript("OnLeave", function(self) Paint(self) end)
        tab:SetScript("OnClick", function()
            Open(i)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
        tabs[i] = tab
    end
    row:SetWidth(x)
    return row, Open
end

-- Long lists: a quiet divider under each row
local function StyleListRow(row)
    local line = row:CreateTexture(nil, "BACKGROUND")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    line:SetColorTexture(Theme:Color("divider"))
end

-- Row controls: gold chevrons to move a row up or down, a red cross to remove it
local function CreateRowButton(parent, kind)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    local mark
    if kind == "remove" then
        mark = btn:CreateFontString(nil, "OVERLAY")
        Theme:Font(mark, "strong", 16)
        mark:SetText("×")
        mark:SetPoint("CENTER", 0, 1)
        mark:SetTextColor(Theme:Color("dangerText"))
        btn:SetScript("OnEnter", function() mark:SetTextColor(Theme:Color("title")) end)
        btn:SetScript("OnLeave", function() mark:SetTextColor(Theme:Color("dangerText")) end)
    else
        mark = btn:CreateTexture(nil, "ARTWORK")
        mark:SetTexture(Theme.media.chevron)
        mark:SetSize(12, 12)
        mark:SetPoint("CENTER")
        if kind == "up" then mark:SetTexCoord(0, 1, 1, 0) end
        mark:SetVertexColor(Theme:Color("accent"))
        btn:SetScript("OnEnter", function() mark:SetVertexColor(Theme:Color("title")) end)
        btn:SetScript("OnLeave", function() mark:SetVertexColor(Theme:Color("accent")) end)
    end
    btn:SetScript("OnDisable", function(self) self:SetAlpha(0.25) end)
    btn:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    return btn
end

-- InputBoxTemplate: the template's art hidden behind a chamfered box
local function SkinInput(editBox)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local part = editBox[key] or _G[(editBox:GetName() or "") .. key]
        if part then part:SetAlpha(0) end
    end
    -- Kept within the box's own bounds (scrolling pages clip anything to the left of it);
    -- the text is padded inward instead
    local box = CreateFrame("Frame", nil, editBox)
    box:SetFrameLevel(math.max(0, editBox:GetFrameLevel() - 1))
    box:SetPoint("TOPLEFT", 0, 3)
    box:SetPoint("BOTTOMRIGHT", 0, -3)
    Theme:Chamfer(box, { cut = 6, fill = "inputBg", edge = "rule" })
    editBox:SetTextInsets(8, 6, 0, 0)
    Theme:Font(editBox, "body", 13)
    editBox:SetTextColor(Theme:Color("title"))
    editBox:HookScript("OnEditFocusGained", function() Theme:SetChamferColors(box, "inputBg", "accent") end)
    editBox:HookScript("OnEditFocusLost", function() Theme:SetChamferColors(box, "inputBg", "rule") end)
end

local function CreateScrollableContent(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    SkinScrollBar(scrollFrame)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 0)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(parent:GetWidth() - 24)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        if w and w > 0 then scrollChild:SetWidth(w) end
    end)
    return scrollChild, scrollFrame
end

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

local function CreateOptionsFrame()
    local frame = CreateFrame("Frame", "CastbornOptionsFrame", UIParent)
    frame:SetSize(900, 640)
    frame:SetPoint("CENTER")
    Theme:Chamfer(frame, { cut = 10, fill = "navA", edge = "rule" })
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
            Castborn:LockFrames()
            Castborn:Print("Frames locked")
        end
        -- End the previews started from the pages' Test buttons, unless full test mode
        -- (/cb test) is running, which keeps its own previews until it ends
        if not (Castborn.TestManager and Castborn.TestManager:IsActive()) then
            for endName in pairs(openPreviews) do
                if Castborn[endName] then Castborn[endName](Castborn) end
            end
        end
        wipe(openPreviews)
        if dialog then dialog:Hide() end
    end)

    -- Sidebar: the window's own fill is its background
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    sidebar:SetPoint("TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    frame.sidebar = sidebar

    local wordmark = sidebar:CreateFontString(nil, "OVERLAY")
    Theme:Font(wordmark, "display", 26)
    wordmark:SetPoint("TOPLEFT", 18, -20)
    wordmark:SetText("Castborn")

    local tagline = sidebar:CreateFontString(nil, "OVERLAY")
    Theme:Font(tagline, "body", 10)
    tagline:SetTextColor(Theme:Color("muted"))
    tagline:SetPoint("TOPLEFT", wordmark, "BOTTOMLEFT", 1, -2)
    tagline:SetText("BOOK OF SETTINGS")

    -- Page panel, with a soft glow that fades out before its cut corners
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", SIDEBAR_WIDTH, -6)
    page:SetPoint("BOTTOMRIGHT", -6, 6)
    Theme:Chamfer(page, { cut = 8, fill = "pageB", edge = "divider" })
    local glow = page:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetTexture(Theme.media.glow)
    glow:SetVertexColor(Theme:Color("pageA"))
    glow:SetSize(440, 300)
    glow:SetPoint("CENTER", page, "TOPLEFT", 220, -150)
    frame.page = page

    -- Close button: a small chamfered plate with a gold cross
    local closeBtn = CreateFrame("Button", nil, page)
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", -12, -12)
    Theme:Chamfer(closeBtn, { cut = 4, fill = "knob" })
    local cross = closeBtn:CreateFontString(nil, "OVERLAY")
    Theme:Font(cross, "strong", 16)
    cross:SetTextColor(Theme:Color("heading"))
    cross:SetPoint("CENTER", 0, 1)
    cross:SetText("×")
    closeBtn:SetScript("OnEnter", function(self) Theme:SetChamferColors(self, "rule") end)
    closeBtn:SetScript("OnLeave", function(self) Theme:SetChamferColors(self, "knob") end)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Category buttons
    local y = -78
    local _, playerClass = UnitClass("player")
    for i, cat in ipairs(categories) do
        -- Skip class-restricted categories for other classes, and pages this build does not load
        if (cat.class and cat.class ~= playerClass) or (cat.classes and not tContains(cat.classes, playerClass))
            or (cat.id and not Castborn:IsOptionAvailable(cat.id))
            or (cat.module and not Castborn[cat.module]) then
            -- Skip this category
        elseif cat.divider then
            local dots = sidebar:CreateFontString(nil, "OVERLAY")
            Theme:Font(dots, "subtitle", 14)
            dots:SetPoint("TOP", sidebar, "TOP", 0, y - 4)
            dots:SetText("· · ·")
            y = y - 24
        else
            -- The open page is marked by a gold bookmark ribbon running into the page
            local btn = CreateFrame("Button", nil, sidebar)
            btn:SetHeight(26)
            btn:SetPoint("TOPLEFT", 0, y)
            btn:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 1, y)

            btn.ribbon = btn:CreateTexture(nil, "BACKGROUND")
            btn.ribbon:SetAllPoints()
            btn.ribbon:SetTexture(Theme.media.ribbon)
            btn.ribbon:Hide()

            btn.text = btn:CreateFontString(nil, "OVERLAY")
            Theme:Font(btn.text, "body", 14)
            btn.text:SetTextColor(Theme:Color("navText"))
            btn.text:SetPoint("LEFT", 18, 0)
            btn.text:SetText(cat.name)

            btn:SetScript("OnEnter", function(self)
                if currentCategory ~= cat.id then
                    self.text:SetTextColor(Theme:Color("title"))
                end
            end)

            btn:SetScript("OnLeave", function(self)
                if currentCategory ~= cat.id then
                    self.text:SetTextColor(Theme:Color("navText"))
                end
            end)

            btn:SetScript("OnClick", function()
                Options:ShowCategory(cat.id)
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end)

            cat.button = btn
            y = y - 26
        end
    end

    -- Page content, inset from the panel's edges
    local inner = CreateFrame("Frame", nil, page)
    inner:SetPoint("TOPLEFT", 26, -22)
    inner:SetPoint("BOTTOMRIGHT", -20, 16)
    frame.contentInner = inner

    return frame
end

-- Page title, italic subtitle and an ornamental rule; returns the frame the page builds into
local function CreatePageHeader(content, catId)
    local name = catId
    for _, cat in ipairs(categories) do
        if cat.id == catId then name = cat.name break end
    end

    local title = content:CreateFontString(nil, "OVERLAY")
    Theme:Font(title, "display", 32)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(name)

    local subtitle = content:CreateFontString(nil, "OVERLAY")
    Theme:Font(subtitle, "subtitle", 16)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText(pageSubtitles[catId] or "")

    local diamond = content:CreateTexture(nil, "ARTWORK")
    diamond:SetTexture(Theme.media.diamond)
    diamond:SetVertexColor(Theme:Color("accent"))
    diamond:SetSize(10, 10)
    diamond:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 120, -10)
    for _, side in ipairs({ -1, 1 }) do
        local line = content:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(Theme:Color("rule"))
        line:SetSize(112, 1)
        if side < 0 then
            line:SetPoint("RIGHT", diamond, "LEFT", -4, 0)
        else
            line:SetPoint("LEFT", diamond, "RIGHT", 4, 0)
        end
    end

    local body = CreateFrame("Frame", nil, content)
    body:SetPoint("TOPLEFT", 0, -92)
    body:SetPoint("BOTTOMRIGHT", 0, 0)
    return body
end

--------------------------------------------------------------------------------
-- Category Display
--------------------------------------------------------------------------------

function Options:ShowCategory(catId)
    currentCategory = catId

    -- Update sidebar buttons
    for _, cat in ipairs(categories) do
        if cat.button then  -- Skip dividers
            local open = cat.id == catId
            cat.button.ribbon:SetShown(open)
            Theme:Font(cat.button.text, open and "strong" or "body", 14)
            cat.button.text:SetTextColor(Theme:Color(open and "onAccent" or "navText"))
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
    local body = CreatePageHeader(content, catId)

    if catId == "general" then
        self:BuildGeneral(body)
    elseif catId == "castbars" then
        local scrollChild = CreateScrollableContent(body)
        self:BuildCastbars(scrollChild)
    elseif catId == "lookfeel" then
        self:BuildLookFeel(body)
    elseif catId == "profiles" then
        self:BuildProfiles(body)
    elseif catId == "changelog" then
        self:BuildChangelog(body)
    else
        -- Module pages use a scroll frame for overflow
        local scrollChild = CreateScrollableContent(body)
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
        if not CastbornDB.locked then
            Castborn:LockFrames()
            Castborn:Print("Frames locked")
        else
            Castborn:UnlockFrames()
            Castborn:Print("Frames unlocked - drag to reposition")
        end
        self:SetText(CastbornDB.locked and "Unlock Frames" or "Lock Frames")
    end)
    lockBtn:SetPoint("TOPLEFT", 0, y)

    local testBtn = CreateButton(parent, "Test Mode", 90, function()
        Castborn:EnterTestMode()
    end)
    testBtn:SetPoint("LEFT", lockBtn, "RIGHT", 8, 0)
    testBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Test Mode")
        GameTooltip:AddLine("Shows all modules with sample data so you can reposition them.", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Ctrl+Shift+Click a frame's label to hide it for now, useful when frames overlap.", Theme:Color("heading"))
        GameTooltip:Show()
    end)
    testBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

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
        { key = "buffs", label = "Proc Tracker", db = "procs" },
        { key = "cooldowns", label = "Cooldowns" },
        { key = "itemtracker", label = "Item Tracker" },
        { key = "totems", label = "Totem Tracker", class = "SHAMAN" },
        { key = "absorbs", label = "Absorb Tracker" },
        { key = "armortracker", label = "Armour Tracker", classes = {"MAGE", "WARLOCK", "PRIEST", "PALADIN"} },
        { key = "seals", label = "Seal Tracker", class = "PALADIN" },
        { key = "interrupt", label = "Interrupt Tracker" },
        { key = "multidot", label = "Multi-DoT Tracker" },
        { key = "resources", label = "Resource Bars", onChange = function()
            if Castborn.ResourceBars then Castborn.ResourceBars:ApplySettings() end
        end },
    }

    local col = 0
    local startY = y
    local count = 0
    for i, mod in ipairs(modules) do
        -- Skip class-restricted modules for other classes, and modules this build does not load
        if Castborn:IsOptionAvailable(mod.key)
            and ((not mod.class and not mod.classes) or (mod.class and mod.class == playerClass) or (mod.classes and tContains(mod.classes, playerClass))) then
            count = count + 1
            local dbKey = mod.db or mod.key
            CastbornDB[dbKey] = CastbornDB[dbKey] or {}
            local cb = CreateCheckbox(parent, mod.label, CastbornDB[dbKey], "enabled", mod.onChange)
            cb:SetPoint("TOPLEFT", col * 200, y)
            y = y - 26
            if count == 5 then
                col = 1
                y = startY
            end
        end
    end
end

local function ApplyCastbarHeight(barKey, v)
    local f = Castborn.castbars and Castborn.castbars[barKey]
    if not f then return end
    f:SetHeight(v)
    if f.iconFrame then f.iconFrame:SetSize(v + 4, v + 4) end
    if f.spark then f.spark:SetHeight(v * 2.5) end
    if f.shield then f.shield:SetSize(v * 1.5, v * 1.5) end
    local fontSize = math.max(10, v - 6)
    for _, key in ipairs({"spellText", "timeText"}) do
        if f[key] then
            f[key]:SetFont(Castborn:GetBarFont(), fontSize, "OUTLINE")
            Castborn:RegisterFontString(f[key], fontSize, "OUTLINE")
        end
    end
end

local castbarDefs = {
    { key = "player", frameKey = "player", label = "Player Castbar", tab = "Player" },
    { key = "target", frameKey = "target", label = "Target Castbar", tab = "Target" },
    { key = "focus", frameKey = "focus", label = "Focus Castbar", tab = "Focus" },
    { key = "targettarget", frameKey = "targettarget", label = "Target-of-Target Castbar", tab = "Target of Target" },
}

function Options:BuildCastbars(parent)
    local y = 0

    -- Global Castbar Colours section
    local colorHeader = CreateHeader(parent, "Castbar Colours")
    colorHeader:SetPoint("TOPLEFT", 0, y)
    colorHeader:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    local classColorCB = CreateCheckbox(parent, "Use Class Colours (Player)", CastbornDB, "useClassColors", function()
        if Castborn.RefreshCastbarColors then Castborn:RefreshCastbarColors() end
    end)
    classColorCB:SetPoint("TOPLEFT", 0, y)
    y = y - 26

    local globalColorCB = CreateCheckbox(parent, "Set all castbars globally to:", CastbornDB, "useGlobalBarColor", function()
        if Castborn.RefreshCastbarColors then Castborn:RefreshCastbarColors() end
    end)
    globalColorCB:SetPoint("TOPLEFT", 0, y)

    local globalPicker = CreateColorPicker(parent, "Global Bar Colour", CastbornDB, "globalBarColor", function()
        if Castborn.RefreshCastbarColors then Castborn:RefreshCastbarColors() end
    end)
    globalPicker:SetPoint("TOPLEFT", 250, y)
    y = y - 36

    -- One tab per castbar; each castbar's settings sit on their own panel
    local panels, labels = {}, {}
    for i, def in ipairs(castbarDefs) do labels[i] = def.tab end
    local tabRow, openTab = CreateTabs(parent, labels, function(index)
        for i, panel in ipairs(panels) do panel:SetShown(i == index) end
    end)
    tabRow:SetPoint("TOPLEFT", 0, y)
    y = y - 44
    local panelTop, tallest = y, 0

    for _, def in ipairs(castbarDefs) do
        local dbKey = def.key
        local frameKey = def.frameKey

        local panel = CreateFrame("Frame", nil, parent)
        panel:SetPoint("TOPLEFT", 0, panelTop)
        panel:SetPoint("TOPRIGHT", 0, panelTop)
        panels[#panels + 1] = panel
        local y = 0  -- each panel lays out from its own top

        CastbornDB[dbKey] = CastbornDB[dbKey] or {}

        local iconCB = CreateCheckbox(panel, "Show Icon", CastbornDB[dbKey], "showIcon", function(checked)
            local bar = Castborn.castbars and Castborn.castbars[frameKey]
            if bar and bar.iconFrame then
                if checked then
                    bar.iconFrame:Show()
                else
                    bar.iconFrame:Hide()
                end
            end
        end)
        iconCB:SetPoint("TOPLEFT", 0, y)
        local timeCB = CreateCheckbox(panel, "Show Time", CastbornDB[dbKey], "showTime", function(checked)
            local bar = Castborn.castbars and Castborn.castbars[frameKey]
            if bar and bar.timeText then
                if checked then
                    bar.timeText:Show()
                else
                    bar.timeText:Hide()
                end
            end
        end)
        timeCB:SetPoint("TOPLEFT", 150, y)
        y = y - 26

        if def.key == "player" then
            local spellNameCB = CreateCheckbox(panel, "Show Spell Name", CastbornDB[dbKey], "showSpellName", function(checked)
                local bar = Castborn.castbars and Castborn.castbars[frameKey]
                if bar and bar.spellText then
                    if checked then
                        bar.spellText:Show()
                    else
                        bar.spellText:Hide()
                    end
                end
            end)
            spellNameCB:SetPoint("TOPLEFT", 0, y)
            local latencyCB = CreateCheckbox(panel, "Show Latency", CastbornDB[dbKey], "showLatency", function(checked)
                local bar = Castborn.castbars and Castborn.castbars[frameKey]
                if bar and bar.latency then
                    if checked then
                        bar.latency:Show()
                    else
                        bar.latency:Hide()
                    end
                end
            end)
            latencyCB:SetPoint("TOPLEFT", 150, y)
            y = y - 26

            local rankCB = CreateCheckbox(panel, "Show Spell Rank", CastbornDB[dbKey], "showSpellRank")
            rankCB:SetPoint("TOPLEFT", 0, y)
            y = y - 26

            local blizzCB = CreateCheckbox(panel, "Hide Blizzard Castbar", CastbornDB[dbKey], "hideBlizzardCastBar", function(checked)
                if checked then
                    Castborn:HideBlizzardCastBar()
                else
                    Castborn:ShowBlizzardCastBar()
                end
            end)
            blizzCB:SetPoint("TOPLEFT", 0, y)
            local tradeCB = CreateCheckbox(panel, "Hide Tradeskill Casts", CastbornDB[dbKey], "hideTradeSkills")
            tradeCB:SetPoint("TOPLEFT", 150, y)
            y = y - 36
        else
            y = y - 10
        end

        local widthSlider = CreateSlider(panel, "Width", CastbornDB[dbKey], "width", 100, 400, 10, function(v)
            if Castborn.castbars and Castborn.castbars[frameKey] then
                Castborn.castbars[frameKey]:SetWidth(v)
            end
        end)
        widthSlider:SetPoint("TOPLEFT", 0, y)

        local heightSlider = CreateSlider(panel, "Height", CastbornDB[dbKey], "height", 10, 40, 2, function(v)
            ApplyCastbarHeight(frameKey, v)
        end)
        heightSlider:SetPoint("TOPLEFT", 220, y)
        y = y - 60

        local barPicker = CreateColorPicker(panel, "Bar Colour", CastbornDB[dbKey], "barColor", function()
            if Castborn.RefreshCastbarColors then Castborn:RefreshCastbarColors() end
        end)
        barPicker:SetPoint("TOPLEFT", 0, y)

        local bgPicker = CreateColorPicker(panel, "Background Colour", CastbornDB[dbKey], "bgColor", function()
            if Castborn.RefreshBackgrounds then Castborn:RefreshBackgrounds() end
        end)
        bgPicker:SetPoint("TOPLEFT", 220, y)
        y = y - 30
        panel:SetHeight(math.abs(y))
        tallest = math.max(tallest, math.abs(y))
    end

    openTab(1)
    parent:SetHeight(math.abs(panelTop) + tallest + 20)
end

function Options:BuildLookFeel(parent)
    local y = 0

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

    local borderCB = CreateCheckbox(parent, "Show Frame Borders", CastbornDB, "showBorders", function()
        if Castborn.UpdateBorders then
            Castborn:UpdateBorders()
        end
    end)
    borderCB:SetPoint("TOPLEFT", 0, y)
    y = y - 36

    -- Bar skin for the castbars and resource bars. With Masque, they follow Masque's
    -- Castborn > Bars group; this list is the fallback without Masque or with that group off.
    local BarSkin = Castborn.BarSkin
    if BarSkin then
        local skinLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
        skinLabel:SetPoint("TOPLEFT", 0, y)
        skinLabel:SetText(Castborn.Masque and Castborn.Masque.lib and "Bar Skin without Masque" or "Bar Skin")
        skinLabel:SetTextColor(unpack(C.grey))
        y = y - 22

        if Castborn.Masque and Castborn.Masque.lib then
            local note = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsSmall")
            note:SetPoint("TOPLEFT", 0, y)
            note:SetWidth(440)
            note:SetJustifyH("LEFT")
            note:SetText("Masque skins the castbars and resource bars: choose their skin in Masque's options under Castborn > Bars. This list applies when that group is disabled.")
            y = y - 32
        end

        local skinDropdown = CreateFrame("Frame", "CastbornBarSkinDropdown", parent, "UIDropDownMenuTemplate")
        SkinDropdown(skinDropdown)
        skinDropdown:SetPoint("TOPLEFT", -10, y)
        UIDropDownMenu_SetWidth(skinDropdown, 180)
        local current = "Castborn"
        for _, item in ipairs(BarSkin:List()) do
            if item.value == CastbornDB.barSkin then current = item.label end
        end
        UIDropDownMenu_SetText(skinDropdown, current)
        UIDropDownMenu_Initialize(skinDropdown, function()
            for _, item in ipairs(BarSkin:List()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = item.label
                info.value = item.value
                info.checked = CastbornDB.barSkin == item.value
                info.func = function()
                    CastbornDB.barSkin = item.value
                    UIDropDownMenu_SetText(skinDropdown, item.label)
                    CloseDropDownMenus()
                    BarSkin:ApplyAll()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)

        local sizeSlider = CreateSlider(parent, "Skin Border Size", CastbornDB, "barSkinBorder", 1, 8, 1, function()
            BarSkin:ApplyAll()
        end)
        sizeSlider:SetPoint("TOPLEFT", 230, y + 18)
        y = y - 44
    end

    -- Bar Texture dropdown
    local texLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
    texLabel:SetPoint("TOPLEFT", 0, y)
    texLabel:SetText("Bar Texture")
    texLabel:SetTextColor(unpack(C.grey))
    y = y - 22

    local texDropdown = CreateFrame("Frame", "CastbornTextureDropdown", parent, "UIDropDownMenuTemplate")
    SkinDropdown(texDropdown)
    texDropdown:SetPoint("TOPLEFT", -10, y)
    UIDropDownMenu_SetWidth(texDropdown, 150)
    UIDropDownMenu_SetText(texDropdown, CastbornDB.barTexture or "Blizzard")

    -- Preview bar
    local preview = CreateFrame("StatusBar", nil, parent)
    preview:SetPoint("LEFT", texDropdown, "RIGHT", 0, 2)
    preview:SetSize(120, 16)
    preview:SetStatusBarTexture(Castborn:GetBarTexture())
    preview:SetStatusBarColor(0.4, 0.6, 0.9, 1)
    preview:SetMinMaxValues(0, 1)
    preview:SetValue(0.7)

    UIDropDownMenu_Initialize(texDropdown, function(self, level)
        -- Built-in textures (sorted)
        local builtinNames = {}
        for name in pairs(Castborn.builtinTextures) do
            table.insert(builtinNames, name)
        end
        table.sort(builtinNames)

        for _, name in ipairs(builtinNames) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.value = name
            info.checked = (CastbornDB.barTexture == name)
            info.func = function()
                CastbornDB.barTexture = name
                UIDropDownMenu_SetText(texDropdown, name)
                CloseDropDownMenus()
                preview:SetStatusBarTexture(Castborn:GetBarTexture())
                Castborn:RefreshBarTextures()
            end
            UIDropDownMenu_AddButton(info)
        end

        -- LSM textures (if available)
        local lsm = Castborn.LSM
        if lsm then
            local lsmList = lsm:List("statusbar") or {}
            for _, name in ipairs(lsmList) do
                if not Castborn.builtinTextures[name] then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = name
                    info.value = name
                    info.checked = (CastbornDB.barTexture == name)
                    info.func = function()
                        CastbornDB.barTexture = name
                        UIDropDownMenu_SetText(texDropdown, name)
                        CloseDropDownMenus()
                        preview:SetStatusBarTexture(Castborn:GetBarTexture())
                        Castborn:RefreshBarTextures()
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
    end)

    y = y - 36

    -- Bar Font dropdown
    local fontLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
    fontLabel:SetPoint("TOPLEFT", 0, y)
    fontLabel:SetText("Bar Font")
    fontLabel:SetTextColor(unpack(C.grey))
    y = y - 22

    local fontDropdown = CreateFrame("Frame", "CastbornFontDropdown", parent, "UIDropDownMenuTemplate")
    SkinDropdown(fontDropdown)
    fontDropdown:SetPoint("TOPLEFT", -10, y)
    UIDropDownMenu_SetWidth(fontDropdown, 150)
    UIDropDownMenu_SetText(fontDropdown, CastbornDB.barFont or "Arial Narrow")

    -- Preview text
    local fontPreview = parent:CreateFontString(nil, "OVERLAY")
    fontPreview:SetPoint("LEFT", fontDropdown, "RIGHT", 0, 2)
    fontPreview:SetFont(Castborn:GetBarFont(), 13, "OUTLINE")
    fontPreview:SetText("Sample Text 123")
    fontPreview:SetTextColor(1, 1, 1)

    UIDropDownMenu_Initialize(fontDropdown, function(self, level)
        -- Built-in fonts (sorted)
        local builtinNames = {}
        for name in pairs(Castborn.builtinFonts) do
            table.insert(builtinNames, name)
        end
        table.sort(builtinNames)

        for _, name in ipairs(builtinNames) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.value = name
            info.checked = (CastbornDB.barFont == name)
            info.func = function()
                CastbornDB.barFont = name
                UIDropDownMenu_SetText(fontDropdown, name)
                CloseDropDownMenus()
                fontPreview:SetFont(Castborn:GetBarFont(), 13, "OUTLINE")
                Castborn:RefreshFonts()
            end
            UIDropDownMenu_AddButton(info)
        end

        -- LSM fonts (if available)
        local lsm = Castborn.LSM
        if lsm then
            local lsmList = lsm:List("font") or {}
            for _, name in ipairs(lsmList) do
                if not Castborn.builtinFonts[name] then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = name
                    info.value = name
                    info.checked = (CastbornDB.barFont == name)
                    info.func = function()
                        CastbornDB.barFont = name
                        UIDropDownMenu_SetText(fontDropdown, name)
                        CloseDropDownMenus()
                        fontPreview:SetFont(Castborn:GetBarFont(), 13, "OUTLINE")
                        Castborn:RefreshFonts()
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
    end)
end

-- A Castborn dialog over the options window, in place of Blizzard's popups: a chamfered gold
-- plaque with a title, a message, an optional name box and confirm / cancel buttons.
-- opts: title, text, input (true to ask for a name), confirm (button label),
-- danger (true for a red confirm button), onConfirm(name)
local function ShowDialog(opts)
    if not dialog then
        dialog = CreateFrame("Frame", nil, optionsFrame)
        dialog:SetAllPoints(optionsFrame)
        dialog:SetFrameLevel(optionsFrame:GetFrameLevel() + 50)
        dialog:EnableMouse(true)  -- blocks clicks on the page underneath
        Theme:Chamfer(dialog, { cut = 10, fill = { 0, 0, 0, 0.6 } })

        local plaque = CreateFrame("Frame", nil, dialog)
        plaque:SetWidth(400)
        plaque:SetPoint("CENTER")
        Theme:Chamfer(plaque, { cut = 14, fill = "raised", edge = "accent" })
        local inner = CreateFrame("Frame", nil, plaque)
        inner:SetPoint("TOPLEFT", 4, -4)
        inner:SetPoint("BOTTOMRIGHT", -4, 4)
        Theme:Chamfer(inner, { cut = 11, fill = "pageB", edge = "rule" })
        dialog.plaque = plaque

        local title = inner:CreateFontString(nil, "OVERLAY")
        Theme:Font(title, "display", 26)
        title:SetPoint("TOP", 0, -20)
        dialog.title = title

        local diamond = inner:CreateTexture(nil, "ARTWORK")
        diamond:SetTexture(Theme.media.diamond)
        diamond:SetVertexColor(Theme:Color("accent"))
        diamond:SetSize(9, 9)
        diamond:SetPoint("TOP", title, "BOTTOM", 0, -8)
        for _, side in ipairs({ -1, 1 }) do
            local line = inner:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(Theme:Color("rule"))
            line:SetSize(70, 1)
            if side < 0 then
                line:SetPoint("RIGHT", diamond, "LEFT", -4, 0)
            else
                line:SetPoint("LEFT", diamond, "RIGHT", 4, 0)
            end
        end

        local text = inner:CreateFontString(nil, "OVERLAY")
        Theme:Font(text, "body", 15)
        text:SetWidth(340)
        text:SetJustifyH("CENTER")
        text:SetPoint("TOP", diamond, "BOTTOM", 0, -12)
        dialog.text = text

        local input = CreateFrame("EditBox", nil, inner)
        input:SetSize(240, 26)
        input:SetAutoFocus(false)
        input:SetFontObject("CastbornOptionsText")
        input:SetTextColor(Theme:Color("title"))
        input:SetTextInsets(8, 6, 0, 0)
        input:SetMaxLetters(40)
        Theme:Chamfer(input, { cut = 6, fill = "inputBg", edge = "accent" })
        dialog.input = input

        local function Confirm()
            local name = strtrim(input:GetText() or "")
            if dialog.needsName and name == "" then return end
            dialog:Hide()
            if dialog.onConfirm then dialog.onConfirm(name) end
        end
        input:SetScript("OnEnterPressed", Confirm)
        input:SetScript("OnEscapePressed", function() dialog:Hide() end)

        dialog.cancel = CreateButton(inner, "Cancel", 90, function() dialog:Hide() end)
        dialog.confirm = CreateButton(inner, "", 90, Confirm, "primary")
        dialog.confirmDanger = CreateButton(inner, "", 90, Confirm, "danger")
        for _, btn in ipairs({ dialog.confirm, dialog.confirmDanger }) do
            btn:SetPoint("BOTTOMRIGHT", inner, "BOTTOM", -6, 18)
        end
        dialog.cancel:SetPoint("BOTTOMLEFT", inner, "BOTTOM", 6, 18)
    end

    dialog.title:SetText(opts.title)
    dialog.text:SetText(opts.text or "")
    dialog.onConfirm = opts.onConfirm
    dialog.needsName = opts.input and true or false
    dialog.confirm:SetShown(not opts.danger)
    dialog.confirmDanger:SetShown(opts.danger and true or false)
    local confirm = opts.danger and dialog.confirmDanger or dialog.confirm
    confirm:SetText(opts.confirm or "OK")

    local height = 96 + dialog.text:GetStringHeight() + 64
    dialog.input:ClearAllPoints()
    if opts.input then
        dialog.input:SetPoint("TOP", dialog.text, "BOTTOM", 0, -14)
        dialog.input:SetText(opts.default or "")
        dialog.input:Show()
        height = height + 40
    else
        dialog.input:Hide()
    end
    dialog.plaque:SetHeight(height)
    dialog:Show()
    if opts.input then dialog.input:SetFocus() end
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
    local charLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
    charLabel:SetPoint("TOPLEFT", 0, y)
    charLabel:SetText("Character: |cffFFCC00" .. charKey .. "|r")
    y = y - 26

    -- Current Profile dropdown
    local dropdownLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
    dropdownLabel:SetPoint("TOPLEFT", 0, y)
    dropdownLabel:SetText("Current Profile:")
    dropdownLabel:SetTextColor(unpack(C.grey))

    local dropdown = CreateFrame("Frame", "CastbornProfileDropdown", parent, "UIDropDownMenuTemplate")
    SkinDropdown(dropdown)
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
        ShowDialog({
            title = "New profile",
            text = "Name the new profile. You'll switch to it straight away.",
            input = true,
            confirm = "Create",
            onConfirm = function(name)
                Profiles:CreateProfile(name)
                Profiles:SetCurrentProfile(name)
                RefreshDropdown()
                Castborn:Print("Created and switched to profile: " .. name)
            end,
        })
    end, "primary")
    newBtn:SetPoint("TOPLEFT", 0, y)

    local copyBtn = CreateButton(parent, "Copy", 70, function()
        local current = Profiles:GetCurrentProfileName()
        ShowDialog({
            title = "Copy profile",
            text = "Name the copy of " .. current .. ".",
            input = true,
            confirm = "Copy",
            onConfirm = function(name)
                Profiles:CopyProfile(current, name)
                RefreshDropdown()
                Castborn:Print("Copied profile '" .. current .. "' to '" .. name .. "'")
            end,
        })
    end)
    copyBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)

    local deleteBtn = CreateButton(parent, "Delete", 70, function()
        local currentProfile = Profiles:GetCurrentProfileName()
        if currentProfile == "Default" then
            Castborn:Print("Cannot delete the Default profile")
            return
        end
        ShowDialog({
            title = "Delete profile?",
            text = "The profile " .. currentProfile .. " will be removed for every character. This cannot be undone.",
            confirm = "Delete",
            danger = true,
            onConfirm = function()
                Profiles:DeleteProfile(currentProfile)
                Profiles:SetCurrentProfile("Default")
                RefreshDropdown()
                Castborn:Print("Deleted profile: " .. currentProfile)
            end,
        })
    end, "danger")
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
        ShowDialog({
            title = "Import profile",
            text = "Name the imported profile.",
            input = true,
            confirm = "Import",
            onConfirm = function(name)
                local success, err = Profiles:ImportProfile(name, data)
                if success then
                    RefreshDropdown()
                    Castborn:Print("Imported profile: " .. name)
                else
                    Castborn:Print("Import failed: " .. (err or "unknown error"))
                end
            end,
        })
    end)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 6, 0)

    y = y - 32

    -- Multi-line edit box for import/export data
    local editBoxContainer = CreateFrame("Frame", nil, parent)
    editBoxContainer:SetPoint("TOPLEFT", 0, y)
    editBoxContainer:SetPoint("TOPRIGHT", 0, y)
    editBoxContainer:SetHeight(100)
    Theme:Chamfer(editBoxContainer, { cut = 8, fill = "inputBg", edge = "rule" })

    local scrollFrame = CreateFrame("ScrollFrame", "CastbornProfileExportScroll", editBoxContainer, "UIPanelScrollFrameTemplate")
    SkinScrollBar(scrollFrame)
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)

    local editBox = CreateFrame("EditBox", "CastbornProfileExportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("CastbornOptionsSmall")
    editBox:SetTextColor(Theme:Color("text"))
    editBox:SetWidth(scrollFrame:GetWidth() or 350)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    parent.exportEditBox = editBox
end

function Options:BuildChangelog(parent)
    local y = 0

    local header1 = CreateHeader(parent, "Version History")
    header1:SetPoint("TOPLEFT", 0, y)
    header1:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    -- Create scroll frame
    local scrollChild, scrollFrame = CreateScrollableContent(parent)
    scrollFrame:SetPoint("TOPLEFT", 0, y)

    -- The same list the What's New window shows (Systems/WhatsNew.lua)
    if Castborn.WhatsNew then
        scrollChild:SetHeight(Castborn.WhatsNew:RenderChangelog(scrollChild, 400) + 20)
    end
end

-- Per-module option builders. Each receives the content frame, the module's
-- settings table, and the running y offset, and returns the updated offset.
local moduleBuilders = {}

function moduleBuilders.gcd(parent, db, y)
    local alwaysCB = CreateCheckbox(parent, "Always Show (even when ready)", db, "alwaysShow")
    alwaysCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local testBtn = CreateButton(parent, "Test GCD", 80, function()
        StartPreview("TestGCD", "EndTestGCD")
    end)
    testBtn:SetPoint("TOPLEFT", 0, y)

    return y
end

function moduleBuilders.dots(parent, db, y)
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

    return y
end

function moduleBuilders.swing(parent, db, y)
    local testBtn = CreateButton(parent, "Test Swing", 90, function()
        StartPreview("TestSwingTimers", "EndTestSwingTimers")
    end)
    testBtn:SetPoint("TOPLEFT", 0, y)

    return y
end

function moduleBuilders.buffs(parent, db, y)
    -- ProcTracker stores settings in CastbornDB.procs, not CastbornDB.buffs
    local procsDB = CastbornDB.procs

    local timersCB = CreateCheckbox(parent, "Show Timers", procsDB, "showDuration")
    timersCB:SetPoint("TOPLEFT", 0, y)

    local glowCB = CreateCheckbox(parent, "Show Proc Glow", procsDB, "showGlow")
    glowCB:SetPoint("TOPLEFT", 220, y)
    y = y - 36

    local trinketCB = CreateCheckbox(parent, "Show Trinket Procs", procsDB, "showTrinketProcs", function(checked)
        if Castborn.ProcTracker then
            Castborn.ProcTracker:SetTrinketProcs(checked)
        end
    end)
    trinketCB:SetPoint("TOPLEFT", 0, y)
    y = y - 36

    procsDB.iconSize = procsDB.iconSize or 28
    local iconSlider = CreateSlider(parent, "Icon Size", procsDB, "iconSize", 20, 56, 2, function()
        if Castborn.ProcTracker then Castborn.ProcTracker:UpdateLayout() end
    end)
    iconSlider:SetPoint("TOPLEFT", 0, y)
    y = y - 60

    -- Grow Direction dropdown
    local growLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
    growLabel:SetPoint("TOPLEFT", 0, y)
    growLabel:SetText("Grow Direction:")
    growLabel:SetTextColor(unpack(C.grey))

    local growOptions = {
        { value = "RIGHT", label = "Grow Right" },
        { value = "LEFT", label = "Grow Left" },
        { value = "CENTRE", label = "Grow from Centre" },
        { value = "UP", label = "Grow Up" },
        { value = "DOWN", label = "Grow Down" },
    }

    local growDropdown = CreateFrame("Frame", "CastbornProcGrowDropdown", parent, "UIDropDownMenuTemplate")
    SkinDropdown(growDropdown)
    growDropdown:SetPoint("TOPLEFT", 90, y + 6)
    UIDropDownMenu_SetWidth(growDropdown, 140)

    local currentGrow = procsDB.growDirection or "RIGHT"
    for _, opt in ipairs(growOptions) do
        if opt.value == currentGrow then
            UIDropDownMenu_SetText(growDropdown, opt.label)
        end
    end

    UIDropDownMenu_Initialize(growDropdown, function(self, level)
        for _, opt in ipairs(growOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.value = opt.value
            info.checked = (procsDB.growDirection or "RIGHT") == opt.value
            info.func = function()
                procsDB.growDirection = opt.value
                UIDropDownMenu_SetText(growDropdown, opt.label)
                CloseDropDownMenus()
                if Castborn.ProcTracker then Castborn.ProcTracker:UpdateLayout() end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    return y
end

function moduleBuilders.cooldowns(parent, db, y)
    -- Icon Size and Spacing sliders
    db.iconSize = db.iconSize or 36
    local iconSlider = CreateSlider(parent, "Icon Size", db, "iconSize", 20, 56, 2)
    iconSlider:SetPoint("TOPLEFT", 0, y)
    db.spacing = db.spacing or 4
    local spacingSlider = CreateSlider(parent, "Spacing", db, "spacing", 0, 12, 1)
    spacingSlider:SetPoint("TOPLEFT", 220, y)
    y = y - 60
    db.iconsPerRow = db.iconsPerRow or 10
    local perRowSlider = CreateSlider(parent, "Icons Per Row", db, "iconsPerRow", 1, 20, 1)
    perRowSlider:SetPoint("TOPLEFT", 0, y)
    y = y - 50

    -- Orientation checkbox
    local vertCB = CreateCheckbox(parent, "Vertical Layout", db, "verticalLayout", function(v)
        db.orientation = v and "VERTICAL" or "HORIZONTAL"
    end)
    db.verticalLayout = (db.orientation == "VERTICAL")
    vertCB:SetChecked(db.verticalLayout)
    vertCB:SetPoint("TOPLEFT", 0, y)

    local trinketCB = CreateCheckbox(parent, "Track Trinket Cooldowns", db, "trackTrinkets")
    trinketCB:SetPoint("TOPLEFT", 220, y)
    y = y - 36

    -- Grow Direction dropdown
    local growLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
    growLabel:SetPoint("TOPLEFT", 0, y)
    growLabel:SetText("Grow Direction:")
    growLabel:SetTextColor(unpack(C.grey))

    local growOptions = {
        { value = "RIGHT", label = "Grow Right" },
        { value = "LEFT", label = "Grow Left" },
        { value = "UP", label = "Grow Up" },
        { value = "DOWN", label = "Grow Down" },
    }

    local growDropdown = CreateFrame("Frame", "CastbornCooldownGrowDropdown", parent, "UIDropDownMenuTemplate")
    SkinDropdown(growDropdown)
    growDropdown:SetPoint("TOPLEFT", 90, y + 6)
    UIDropDownMenu_SetWidth(growDropdown, 140)

    local currentGrow = db.growDirection or "LEFT"
    for _, opt in ipairs(growOptions) do
        if opt.value == currentGrow then
            UIDropDownMenu_SetText(growDropdown, opt.label)
        end
    end

    UIDropDownMenu_Initialize(growDropdown, function(self, level)
        for _, opt in ipairs(growOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.value = opt.value
            info.checked = (db.growDirection or "LEFT") == opt.value
            info.func = function()
                db.growDirection = opt.value
                UIDropDownMenu_SetText(growDropdown, opt.label)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    y = y - 30

    -- Divider
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 0, y - 4)
    divider:SetPoint("TOPRIGHT", 0, y - 4)
    divider:SetColorTexture(0.25, 0.25, 0.25, 1)
    y = y - 14

    -- Build ordered list from SpellData (ensures all class + racial spells are always shown)
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local classSpells = Castborn.SpellData and Castborn.SpellData:GetClassCooldowns(class) or {}
    local racialSpells = Castborn.SpellData and race and Castborn.SpellData:GetRacialCooldowns(race) or {}
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

    -- Ensure all racial spells exist in trackedSpells
    for _, def in ipairs(racialSpells) do
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
        -- Clear existing children (frames)
        for _, child in ipairs({spellListContainer:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
        end
        -- Clear existing regions (font strings, textures)
        for _, region in ipairs({spellListContainer:GetRegions()}) do
            region:Hide()
            region:SetParent(nil)
        end

        local listY = 0
        local total = #db.trackedSpells

        for i, spell in ipairs(db.trackedSpells) do
            if spell.enabled == nil then spell.enabled = true end

            local row = CreateFrame("Frame", nil, spellListContainer)
            row:SetHeight(26)
            row:SetPoint("TOPLEFT", 0, listY)
            row:SetPoint("TOPRIGHT", 0, listY)
            StyleListRow(row)

            -- Checkbox
            local CT = Castborn.CooldownTracker
            local spellName = CT and CT:GetTrackedSpellName(spell) or spell.name
            local displayName = spell.custom and (spellName .. " |cff888888(Custom)|r") or spellName
            local cb = CreateCheckbox(row, displayName, spell, "enabled")
            cb:SetPoint("LEFT", 0, 0)

            -- Down arrow
            local downBtn = CreateRowButton(row, "down")
            downBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
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
            local upBtn = CreateRowButton(row, "up")
            upBtn:SetPoint("RIGHT", downBtn, "LEFT", -2, 0)
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

            -- Remove button for custom spells
            if spell.custom then
                local removeBtn = CreateRowButton(row, "remove")
                removeBtn:SetPoint("RIGHT", upBtn, "LEFT", -6, 0)
                removeBtn:SetScript("OnClick", function()
                    table.remove(db.trackedSpells, i)
                    BuildSpellList()
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                end)
            end

            listY = listY - 26
        end

        -- Custom spell input section
        local customY = listY - 10

        local customLabel = spellListContainer:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
        customLabel:SetPoint("TOPLEFT", 0, customY)
        customLabel:SetText("Add Custom Spell ID")
        customY = customY - 20

        local inputBox = CreateFrame("EditBox", nil, spellListContainer, "InputBoxTemplate")
        SkinInput(inputBox)
        inputBox:SetSize(120, 22)
        inputBox:SetPoint("TOPLEFT", 0, customY)
        inputBox:SetAutoFocus(false)
        inputBox:SetNumeric(true)
        inputBox:SetMaxLetters(6)

        local addBtn = CreateButton(spellListContainer, "Add", 60, nil, "primary")
        addBtn:SetPoint("LEFT", inputBox, "RIGHT", 10, 0)

        local statusText = spellListContainer:CreateFontString(nil, "OVERLAY", "CastbornOptionsSmall")
        statusText:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
        statusText:SetText("")

        addBtn:SetScript("OnClick", function()
            local idText = inputBox:GetText()
            local spellId = tonumber(idText)
            if not spellId or spellId <= 0 then
                statusText:SetText("|cffff4444Enter a valid spell ID|r")
                return
            end

            -- Check cap
            if #db.trackedSpells >= 20 then
                statusText:SetText("|cffff4444Maximum of 20 spells reached|r")
                return
            end

            -- Check for duplicates
            for _, spell in ipairs(db.trackedSpells) do
                if spell.spellId == spellId then
                    statusText:SetText("|cffff4444Already tracked|r")
                    return
                end
            end

            -- Validate spell exists
            local name = GetSpellInfo(spellId)
            if not name then
                statusText:SetText("|cffff4444Spell not found|r")
                return
            end

            -- Add the custom spell
            table.insert(db.trackedSpells, {
                spellId = spellId,
                name = name,
                enabled = true,
                custom = true,
            })

            inputBox:SetText("")
            statusText:SetText("|cff44ff44Added: " .. name .. "|r")
            BuildSpellList()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)

        inputBox:SetScript("OnEnterPressed", function()
            addBtn:Click()
        end)

        inputBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        customY = customY - 30
        spellListContainer:SetHeight(math.abs(customY) + 4)
    end

    BuildSpellList()

    y = y - (26 * #db.trackedSpells) - 60

    return y
end

function moduleBuilders.itemtracker(parent, db, y)
    -- Icon Size and Spacing sliders
    db.iconSize = db.iconSize or 36
    local iconSlider = CreateSlider(parent, "Icon Size", db, "iconSize", 20, 56, 2)
    iconSlider:SetPoint("TOPLEFT", 0, y)
    db.spacing = db.spacing or 4
    local spacingSlider = CreateSlider(parent, "Spacing", db, "spacing", 0, 12, 1)
    spacingSlider:SetPoint("TOPLEFT", 220, y)
    y = y - 60
    db.iconsPerRow = db.iconsPerRow or 10
    local perRowSlider = CreateSlider(parent, "Icons Per Row", db, "iconsPerRow", 1, 20, 1)
    perRowSlider:SetPoint("TOPLEFT", 0, y)
    y = y - 50

    -- Orientation checkbox
    local vertCB = CreateCheckbox(parent, "Vertical Layout", db, "verticalLayout", function(v)
        db.orientation = v and "VERTICAL" or "HORIZONTAL"
    end)
    db.verticalLayout = (db.orientation == "VERTICAL")
    vertCB:SetChecked(db.verticalLayout)
    vertCB:SetPoint("TOPLEFT", 0, y)
    y = y - 36

    -- Grow Direction dropdown
    local growLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
    growLabel:SetPoint("TOPLEFT", 0, y)
    growLabel:SetText("Grow Direction:")
    growLabel:SetTextColor(unpack(C.grey))

    local growOptions = {
        { value = "RIGHT", label = "Grow Right" },
        { value = "LEFT", label = "Grow Left" },
        { value = "UP", label = "Grow Up" },
        { value = "DOWN", label = "Grow Down" },
    }

    local growDropdown = CreateFrame("Frame", "CastbornItemGrowDropdown", parent, "UIDropDownMenuTemplate")
    SkinDropdown(growDropdown)
    growDropdown:SetPoint("TOPLEFT", 90, y + 6)
    UIDropDownMenu_SetWidth(growDropdown, 140)

    local currentGrow = db.growDirection or "RIGHT"
    for _, opt in ipairs(growOptions) do
        if opt.value == currentGrow then
            UIDropDownMenu_SetText(growDropdown, opt.label)
        end
    end

    UIDropDownMenu_Initialize(growDropdown, function(self, level)
        for _, opt in ipairs(growOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.value = opt.value
            info.checked = (db.growDirection or "RIGHT") == opt.value
            info.func = function()
                db.growDirection = opt.value
                UIDropDownMenu_SetText(growDropdown, opt.label)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    y = y - 30

    -- Divider
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 0, y - 4)
    divider:SetPoint("TOPRIGHT", 0, y - 4)
    divider:SetColorTexture(0.25, 0.25, 0.25, 1)
    y = y - 14

    db.trackedItems = db.trackedItems or {}

    -- Container for item rows
    local itemListContainer = CreateFrame("Frame", nil, parent)
    itemListContainer:SetPoint("TOPLEFT", 0, y)
    itemListContainer:SetPoint("TOPRIGHT", 0, y)
    itemListContainer:SetHeight(1)

    local function BuildItemList()
        -- Clear existing children
        for _, child in ipairs({itemListContainer:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
        end
        -- Clear existing regions
        for _, region in ipairs({itemListContainer:GetRegions()}) do
            region:Hide()
            region:SetParent(nil)
        end

        local listY = 0
        local total = #db.trackedItems

        for i, item in ipairs(db.trackedItems) do
            if item.enabled == nil then item.enabled = true end

            -- Resolve item name (may be cached)
            local itemName = item.name
            if not itemName then
                itemName = GetItemInfo(item.itemId)
                if itemName then item.name = itemName end
            end
            itemName = itemName or ("Item #" .. item.itemId)

            local row = CreateFrame("Frame", nil, itemListContainer)
            row:SetHeight(26)
            row:SetPoint("TOPLEFT", 0, listY)
            row:SetPoint("TOPRIGHT", 0, listY)
            StyleListRow(row)

            -- Checkbox
            local cb = CreateCheckbox(row, itemName, item, "enabled")
            cb:SetPoint("LEFT", 0, 0)

            -- Remove button
            local removeBtn = CreateRowButton(row, "remove")
            removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            removeBtn:SetScript("OnClick", function()
                table.remove(db.trackedItems, i)
                BuildItemList()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end)

            listY = listY - 26
        end

        -- Add item input section
        local customY = listY - 10

        local customLabel = itemListContainer:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
        customLabel:SetPoint("TOPLEFT", 0, customY)
        customLabel:SetText("Add Item |cff888888(ID or Drag from Bags)|r")
        customY = customY - 20

        local inputBox = CreateFrame("EditBox", nil, itemListContainer, "InputBoxTemplate")
        SkinInput(inputBox)
        inputBox:SetSize(120, 22)
        inputBox:SetPoint("TOPLEFT", 0, customY)
        inputBox:SetAutoFocus(false)
        inputBox:SetNumeric(true)
        inputBox:SetMaxLetters(6)

        -- Accept drag-and-dropped items
        inputBox:EnableMouse(true)
        inputBox:SetScript("OnReceiveDrag", function(self)
            local infoType, itemId = GetCursorInfo()
            if infoType == "item" and itemId then
                self:SetText(tostring(itemId))
                ClearCursor()
            end
        end)
        inputBox:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" and GetCursorInfo() then
                local infoType, itemId = GetCursorInfo()
                if infoType == "item" and itemId then
                    self:SetText(tostring(itemId))
                    ClearCursor()
                    return
                end
            end
            self:SetFocus()
        end)

        local addBtn = CreateButton(itemListContainer, "Add", 60, nil, "primary")
        addBtn:SetPoint("LEFT", inputBox, "RIGHT", 10, 0)

        local statusText = itemListContainer:CreateFontString(nil, "OVERLAY", "CastbornOptionsSmall")
        statusText:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
        statusText:SetText("")

        addBtn:SetScript("OnClick", function()
            local idText = inputBox:GetText()
            local itemId = tonumber(idText)
            if not itemId or itemId <= 0 then
                statusText:SetText("|cffff4444Enter a valid item ID|r")
                return
            end

            -- Check cap
            if #db.trackedItems >= 20 then
                statusText:SetText("|cffff4444Maximum of 20 items reached|r")
                return
            end

            -- Check for duplicates
            for _, item in ipairs(db.trackedItems) do
                if item.itemId == itemId then
                    statusText:SetText("|cffff4444Already tracked|r")
                    return
                end
            end

            -- Validate item exists
            local name = GetItemInfo(itemId)
            if not name then
                statusText:SetText("|cffff4444Item not found (try again after opening bags)|r")
                return
            end

            -- Add the item
            table.insert(db.trackedItems, {
                itemId = itemId,
                name = name,
                enabled = true,
            })

            inputBox:SetText("")
            statusText:SetText("|cff44ff44Added: " .. name .. "|r")
            BuildItemList()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)

        inputBox:SetScript("OnEnterPressed", function()
            addBtn:Click()
        end)

        inputBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        customY = customY - 30
        itemListContainer:SetHeight(math.abs(customY) + 4)
    end

    BuildItemList()

    y = y - (26 * #db.trackedItems) - 60

    return y
end

function moduleBuilders.interrupt(parent, db, y)
    local widthSlider = CreateSlider(parent, "Width", db, "width", 60, 300, 5, function(v)
        local f = _G["Castborn_Interrupt"]
        if f then
            f:SetWidth(v)
            if f.bar then
                f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", (db.height or 16) + 2, -1)
            end
        end
    end)
    widthSlider:SetPoint("TOPLEFT", 0, y)

    local heightSlider = CreateSlider(parent, "Height", db, "height", 10, 40, 1, function(v)
        local f = _G["Castborn_Interrupt"]
        if f then
            f:SetHeight(v)
            if f.iconButton then
                f.iconButton:SetSize(v, v)
            end
            if f.bar then
                f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", v + 2, -1)
            end
        end
    end)
    heightSlider:SetPoint("TOPLEFT", 220, y)
    y = y - 60

    if Castborn:IsOptionAvailable("interrupt.lockout") then
        local lockoutCB = CreateCheckbox(parent, "Show Lockout", db, "showLockout")
        lockoutCB:SetPoint("TOPLEFT", 0, y)
        y = y - 30
    end

    local targetCB = CreateCheckbox(parent, "Track Target", db, "trackTarget")
    targetCB:SetPoint("TOPLEFT", 0, y)
    local focusCB = CreateCheckbox(parent, "Track Focus", db, "trackFocus")
    focusCB:SetPoint("TOPLEFT", 150, y)
    y = y - 30

    local glowCB = CreateCheckbox(parent, "Show Ready Glow", db, "showReadyGlow")

    local showBarCB = CreateCheckbox(parent, "Show Interrupt Bar", db, "showBar", function(checked)
        local f = _G["Castborn_Interrupt"]
        if f then
            if checked then f:Show() else f:Hide() end
        end
        local lf = _G["Castborn_Lockout"]
        if lf and not checked then lf:Hide() end
    end)
    showBarCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    local attachCB = CreateCheckbox(parent, "Attach to Castbars", db, "attachToCastbars", function(checked)
        if Castborn.InterruptTracker and Castborn.InterruptTracker.UpdateAttachMode then
            Castborn.InterruptTracker:UpdateAttachMode()
        end
        if checked then glowCB:Show() else glowCB:Hide() end
    end)
    attachCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    glowCB:SetPoint("TOPLEFT", 0, y)
    if not db.attachToCastbars then glowCB:Hide() end

    return y
end

function moduleBuilders.totems(parent, db, y)
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

    local soloCB = CreateCheckbox(parent, "Show range indicator when not grouped", db, "showSoloIndicator")
    soloCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    local testBtn = CreateButton(parent, "Test Totems", 100, function()
        StartPreview("TestTotemTracker", "EndTestTotemTracker")
    end)
    testBtn:SetPoint("TOPLEFT", 0, y)

    return y
end

function moduleBuilders.multidot(parent, db, y)
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
    local npHeader = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
    npHeader:SetPoint("TOPLEFT", 0, y)
    npHeader:SetText(Theme:Code("heading") .. "Nameplate Indicators|r")
    y = y - 20

    local npDesc = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsSmall")
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
    local posLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
    posLabel:SetPoint("TOPLEFT", 220, y)
    posLabel:SetText("Position:")
    posLabel:SetTextColor(unpack(C.grey))

    local posDropdown = CreateFrame("Frame", "CastbornNPIndicatorPosDropdown", parent, "UIDropDownMenuTemplate")
    SkinDropdown(posDropdown)
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

    return y
end

function moduleBuilders.armortracker(parent, db, y)
    local enableCB = CreateCheckbox(parent, "Enable Armour Tracker", db, "enabled")
    enableCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    db.iconSize = db.iconSize or 50
    local sizeSlider = CreateSlider(parent, "Icon Size", db, "iconSize", 24, 80, 4, function(v)
        if Castborn.ArmorTracker and Castborn.ArmorTracker.ApplyIconSize then
            Castborn.ArmorTracker:ApplyIconSize(v)
        end
    end)
    sizeSlider:SetPoint("TOPLEFT", 0, y)
    y = y - 50

    -- Paladin: blessing selection dropdown + RF note
    local _, optClass = UnitClass("player")
    if optClass == "PALADIN" then
        y = y - 10
        local blessLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
        blessLabel:SetPoint("TOPLEFT", 0, y)
        blessLabel:SetText("Blessing to track:")
        blessLabel:SetTextColor(unpack(C.grey))

        local blessDropdown = CreateFrame("Frame", "CastbornBlessingDropdown", parent, "UIDropDownMenuTemplate")
        SkinDropdown(blessDropdown)
        blessDropdown:SetPoint("TOPLEFT", 110, y + 6)
        UIDropDownMenu_SetWidth(blessDropdown, 140)

        local allBlessings = {
            { key = "might",     label = "Blessing of Might" },
            { key = "wisdom",    label = "Blessing of Wisdom" },
            { key = "kings",     label = "Blessing of Kings" },
            { key = "sanctuary", label = "Blessing of Sanctuary" },
        }
        -- Only blessings this build has (no Sanctuary on Forever)
        local blessings = {}
        for _, b in ipairs(allBlessings) do
            if Castborn:IsOptionAvailable("armortracker." .. b.key) then
                blessings[#blessings + 1] = b
            end
        end
        local blessLabelMap = {}
        for _, b in ipairs(blessings) do blessLabelMap[b.key] = b.label end

        local function TrackedBlessing()
            local AT = Castborn.ArmorTracker
            return AT and AT:GetSelectedBlessing(db) or db.selectedBlessing or "might"
        end

        UIDropDownMenu_Initialize(blessDropdown, function(self, level)
            for _, b in ipairs(blessings) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = b.label
                info.value = b.key
                info.checked = (TrackedBlessing() == b.key)
                info.func = function()
                    db.selectedBlessing = b.key
                    UIDropDownMenu_SetText(blessDropdown, b.label)
                    if Castborn.ArmorTracker and Castborn.ArmorTracker.RebuildBlessingSlot then
                        Castborn.ArmorTracker:RebuildBlessingSlot()
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetText(blessDropdown, blessLabelMap[TrackedBlessing()])
        y = y - 40

        local rfNote = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsSmall")
        rfNote:SetPoint("TOPLEFT", 0, y)
        rfNote:SetText("Righteous Fury is tracked automatically when Improved Righteous Fury is talented.")
        rfNote:SetTextColor(0.6, 0.6, 0.6)
        y = y - 24

        local rfCB = CreateCheckbox(parent, "Always remind me about Righteous Fury", db, "alwaysTrackRF", function()
            if Castborn.ArmorTracker and Castborn.ArmorTracker.RebuildSlots then
                Castborn.ArmorTracker:RebuildSlots()
            end
        end)
        rfCB:SetPoint("TOPLEFT", 0, y)
        y = y - 30
    end

    local testBtn = CreateButton(parent, "Test Armour Alert", 120, function()
        StartPreview("TestArmorTracker", "EndTestArmorTracker")
    end)
    testBtn:SetPoint("TOPLEFT", 0, y)

    return y
end

function moduleBuilders.seals(parent, db, y)
    local function apply()
        if Castborn.SealTracker and Castborn.SealTracker.ApplySettings then
            Castborn.SealTracker:ApplySettings()
        end
    end

    local enableCB = CreateCheckbox(parent, "Enable Seal Tracker", db, "enabled", apply)
    enableCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    db.iconSize = db.iconSize or 40
    local sizeSlider = CreateSlider(parent, "Icon Size", db, "iconSize", 24, 80, 4, apply)
    sizeSlider:SetPoint("TOPLEFT", 0, y)
    y = y - 50

    local countdownCB = CreateCheckbox(parent, "Show Countdown Number", db, "showCountdown", apply)
    countdownCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    if db.warnNoSeal == nil then db.warnNoSeal = true end
    local combatOnlyCB = CreateCheckbox(parent, "Only warn in combat", db, "warnInCombatOnly", apply)
    local warnCB = CreateCheckbox(parent, "Warn when no seal is up", db, "warnNoSeal", function(checked)
        if checked then combatOnlyCB:Show() else combatOnlyCB:Hide() end
        apply()
    end)
    warnCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    combatOnlyCB:SetPoint("TOPLEFT", 20, y)
    if db.warnNoSeal == false then combatOnlyCB:Hide() end
    y = y - 30

    local testBtn = CreateButton(parent, "Test Seal", 90, function()
        StartPreview("TestSealTracker", "EndTestSealTracker")
    end)
    testBtn:SetPoint("TOPLEFT", 0, y)

    return y
end

-- Forever only: the page is listed only when CooldownText_Forever.lua is loaded
function moduleBuilders.cooldowntext(parent, db, y)
    local function apply()
        if Castborn.CooldownText then Castborn.CooldownText:Apply() end
    end

    local enableCB = CreateCheckbox(parent, "Enable Cooldown Text", db, "enabled", apply)
    enableCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    local barsCB = CreateCheckbox(parent, "Action Bars", db, "actionBars", apply)
    barsCB:SetPoint("TOPLEFT", 0, y)
    local iconsCB = CreateCheckbox(parent, "Castborn Icons", db, "castbornIcons", apply)
    iconsCB:SetPoint("TOPLEFT", 220, y)
    y = y - 30

    local note = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsSmall")
    note:SetPoint("TOPLEFT", 0, y)
    note:SetWidth(420)
    note:SetJustifyH("LEFT")
    note:SetText("Action bar numbers turn on the game's \"cooldown numbers\" setting while enabled. Uses the Look & Feel font.")
    note:SetTextColor(unpack(C.grey))
    y = y - 30

    local sizeSlider = CreateSlider(parent, "Text Size (% of button)", db, "textScale", 25, 70, 5, apply)
    sizeSlider:SetPoint("TOPLEFT", 0, y)
    local outlineCB = CreateCheckbox(parent, "Outline", db, "outline", apply)
    outlineCB:SetPoint("TOPLEFT", 220, y - 14)
    y = y - 60

    local minSlider = CreateSlider(parent, "Hide Under (seconds)", db, "minDuration", 0, 5, 0.5, apply)
    minSlider:SetPoint("TOPLEFT", 0, y)
    local decimalsSlider = CreateSlider(parent, "Tenths Below (seconds)", db, "decimalsBelow", 0, 10, 1, apply)
    decimalsSlider:SetPoint("TOPLEFT", 220, y)
    y = y - 60

    local stagesCB = CreateCheckbox(parent, "Colour by Time Left", db, "colorStages", apply)
    stagesCB:SetPoint("TOPLEFT", 0, y)
    y = y - 34

    local longPicker = CreateColorPicker(parent, "1 minute or more", db, "longColor", apply)
    longPicker:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local mediumPicker = CreateColorPicker(parent, "Under 1 minute", db, "mediumColor", apply)
    mediumPicker:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local shortPicker = CreateColorPicker(parent, "Under 5 seconds", db, "shortColor", apply)
    shortPicker:SetPoint("TOPLEFT", 0, y)
    y = y - 40

    -- Finish effect (CooldownFinish_Forever.lua)
    local finish = Castborn.CooldownText and Castborn.CooldownText.Finish
    if finish then
        local finishLabel = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
        finishLabel:SetPoint("TOPLEFT", 0, y)
        finishLabel:SetText("When a Cooldown Finishes:")
        finishLabel:SetTextColor(unpack(C.grey))

        local dropdown = CreateFrame("Frame", "CastbornCooldownFinishDropdown", parent, "UIDropDownMenuTemplate")
        SkinDropdown(dropdown)
        dropdown:SetPoint("TOPLEFT", 160, y + 6)
        UIDropDownMenu_SetWidth(dropdown, 100)
        UIDropDownMenu_SetText(dropdown, finish.labels[db.finishEffect or "pulse"])
        UIDropDownMenu_Initialize(dropdown, function()
            for _, key in ipairs(finish.effects) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = finish.labels[key]
                info.value = key
                info.checked = (db.finishEffect or "pulse") == key
                info.func = function()
                    db.finishEffect = key
                    UIDropDownMenu_SetText(dropdown, finish.labels[key])
                    CloseDropDownMenus()
                    finish:Preview()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)

        local previewBtn = CreateButton(parent, "Preview", 80, function() finish:Preview() end)
        previewBtn:SetPoint("TOPLEFT", 320, y + 2)
        y = y - 34
    end

    return y
end

function moduleBuilders.resources(parent, db, y)
    local RB = Castborn.ResourceBars
    local function apply()
        if RB then RB:ApplySettings() end
    end

    -- A labelled dropdown that saves one of a set of values and applies it
    local function CreateChoice(name, label, key, choices, x, onPick)
        local labelText = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
        labelText:SetPoint("TOPLEFT", x, y)
        labelText:SetText(label)
        labelText:SetTextColor(unpack(C.grey))

        local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
        SkinDropdown(dropdown)
        dropdown:SetPoint("TOPLEFT", x - 16, y - 16)
        UIDropDownMenu_SetWidth(dropdown, 150)
        for _, choice in ipairs(choices) do
            if choice.value == db[key] then UIDropDownMenu_SetText(dropdown, choice.label) end
        end
        UIDropDownMenu_Initialize(dropdown, function()
            for _, choice in ipairs(choices) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = choice.label
                info.value = choice.value
                info.checked = db[key] == choice.value
                info.func = function()
                    db[key] = choice.value
                    UIDropDownMenu_SetText(dropdown, choice.label)
                    CloseDropDownMenus()
                    if onPick then onPick(choice.value) end
                    apply()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        return dropdown
    end

    local enableCB = CreateCheckbox(parent, "Enable Resource Bars", db, "enabled", apply)
    enableCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    local healthCB = CreateCheckbox(parent, "Show Health", db, "showHealth", apply)
    healthCB:SetPoint("TOPLEFT", 0, y)
    local powerCB = CreateCheckbox(parent, "Show Power", db, "showPower", apply)
    powerCB:SetPoint("TOPLEFT", 220, y)
    y = y - 40

    -- Size
    local sizeHeader = CreateHeader(parent, "Size")
    sizeHeader:SetPoint("TOPLEFT", 0, y)
    sizeHeader:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    local widthSlider = CreateSlider(parent, "Width", db, "width", 80, 400, 10, apply)
    widthSlider:SetPoint("TOPLEFT", 0, y)
    local gapSlider = CreateSlider(parent, "Gap", db, "gap", 0, 10, 1, apply)
    gapSlider:SetPoint("TOPLEFT", 220, y)
    y = y - 60

    local healthHeightSlider = CreateSlider(parent, "Health Height", db, "healthHeight", 4, 40, 1, apply)
    healthHeightSlider:SetPoint("TOPLEFT", 0, y)
    local powerHeightSlider = CreateSlider(parent, "Power Height", db, "powerHeight", 2, 40, 1, apply)
    powerHeightSlider:SetPoint("TOPLEFT", 220, y)
    y = y - 60

    -- Texture: the global Look & Feel one, or its own (built-in, then LibSharedMedia)
    local textures = { { value = "GLOBAL", label = "Use Look & Feel" } }
    local builtinNames = {}
    for name in pairs(Castborn.builtinTextures) do builtinNames[#builtinNames + 1] = name end
    table.sort(builtinNames)
    for _, name in ipairs(builtinNames) do textures[#textures + 1] = { value = name, label = name } end
    if Castborn.LSM then
        for _, name in ipairs(Castborn.LSM:List("statusbar") or {}) do
            if not Castborn.builtinTextures[name] then textures[#textures + 1] = { value = name, label = name } end
        end
    end
    CreateChoice("CastbornResourceTextureDropdown", "Bar Texture:", "barTexture", textures, 0)
    y = y - 56

    -- Colours: each picker shows only in Custom mode
    local colourHeader = CreateHeader(parent, "Colours")
    colourHeader:SetPoint("TOPLEFT", 0, y)
    colourHeader:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    local healthPicker = CreateColorPicker(parent, "Custom Health Colour", db, "healthColor", apply)
    local powerPicker = CreateColorPicker(parent, "Custom Power Colour", db, "powerColor", apply)
    CreateChoice("CastbornResourceHealthColourDropdown", "Health Colour:", "healthColorMode", {
        { value = "CLASS", label = "Class Colour" },
        { value = "CUSTOM", label = "Custom" },
    }, 0, function(v) if v == "CUSTOM" then healthPicker:Show() else healthPicker:Hide() end end)
    CreateChoice("CastbornResourcePowerColourDropdown", "Power Colour:", "powerColorMode", {
        { value = "TYPE", label = "By Power Type" },
        { value = "CUSTOM", label = "Custom" },
    }, 220, function(v) if v == "CUSTOM" then powerPicker:Show() else powerPicker:Hide() end end)
    y = y - 56

    healthPicker:SetPoint("TOPLEFT", 0, y)
    powerPicker:SetPoint("TOPLEFT", 220, y)
    if db.healthColorMode ~= "CUSTOM" then healthPicker:Hide() end
    if db.powerColorMode ~= "CUSTOM" then powerPicker:Hide() end
    y = y - 40

    -- Text
    local textHeader = CreateHeader(parent, "Text")
    textHeader:SetPoint("TOPLEFT", 0, y)
    textHeader:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    CreateChoice("CastbornResourceTextDropdown", "Text Format:", "textFormat", {
        { value = "NONE", label = "None" },
        { value = "CURRENT", label = "Current" },
        { value = "CURRENT_MAX", label = "Current / Max" },
        { value = "PERCENT", label = "Percentage" },
        { value = "CURRENT_PERCENT", label = "Current (Percentage)" },
    }, 0)
    local textSizeSlider = CreateSlider(parent, "Text Size", db, "textSize", 6, 24, 1, apply)
    textSizeSlider:SetPoint("TOPLEFT", 220, y)
    y = y - 60

    if RB and not RB:SupportsPercent() then
        local note = parent:CreateFontString(nil, "OVERLAY", "CastbornOptionsSmall")
        note:SetPoint("TOPLEFT", 0, y)
        note:SetWidth(420)
        note:SetJustifyH("LEFT")
        note:SetText("Percentages are not available on this client, so those formats show current / max instead.")
        y = y - 30
    end

    -- Visibility
    local visHeader = CreateHeader(parent, "Visibility")
    visHeader:SetPoint("TOPLEFT", 0, y)
    visHeader:SetPoint("TOPRIGHT", 0, y)
    y = y - 30

    local fadeSlider = CreateSlider(parent, "Out of Combat Opacity", db, "fadeAlpha", 0, 1, 0.05, apply)
    CreateChoice("CastbornResourceVisibilityDropdown", "Show:", "visibility", {
        { value = "ALWAYS", label = "Always" },
        { value = "COMBAT", label = "In Combat Only" },
        { value = "FADE", label = "Fade Out of Combat" },
    }, 0, function(v) if v == "FADE" then fadeSlider:Show() else fadeSlider:Hide() end end)
    fadeSlider:SetPoint("TOPLEFT", 220, y)
    if db.visibility ~= "FADE" then fadeSlider:Hide() end
    y = y - 60

    local testBtn = CreateButton(parent, "Test Resource Bars", 140, function()
        StartPreview("TestResourceBars", "EndTestResourceBars")
    end)
    testBtn:SetPoint("TOPLEFT", 0, y)

    return y
end

function moduleBuilders.absorbs(parent, db, y)
    db.size = db.size or 48
    local sizeSlider = CreateSlider(parent, "Size", db, "size", 32, 128, 4, function(v)
        local f = _G["Castborn_AbsorbTracker"]
        if f then f:SetSize(v, v) end
    end)
    sizeSlider:SetPoint("TOPLEFT", 0, y)
    db.spacing = db.spacing or 4
    local spacingSlider = CreateSlider(parent, "Spacing", db, "spacing", 0, 12, 1)
    spacingSlider:SetPoint("TOPLEFT", 220, y)
    y = y - 50

    -- Grow direction checkbox
    local growCB = CreateCheckbox(parent, "Grow Left", db, "growLeft", function(v)
        db.growDirection = v and "LEFT" or "RIGHT"
    end)
    db.growLeft = (db.growDirection == "LEFT")
    growCB:SetChecked(db.growLeft)
    growCB:SetPoint("TOPLEFT", 0, y)
    y = y - 30

    local testBtn = CreateButton(parent, "Test Absorb", 90, function()
        StartPreview("TestAbsorbTracker", "EndTestAbsorbTracker")
    end)
    testBtn:SetPoint("TOPLEFT", 0, y)
    return y
end

function Options:BuildModule(parent, key)
    local y = 0  -- the page header (CreatePageHeader) already names the page

    CastbornDB[key] = CastbornDB[key] or {}
    local db = CastbornDB[key]

    -- Width/Height sliders for applicable modules
    if key == "gcd" or key == "fsr" or key == "swing" then
        db.width = db.width or 200
        local widthSlider = CreateSlider(parent, "Width", db, "width", 50, 400, 10, function(v)
            if key == "gcd" and Castborn.gcdFrame then Castborn.gcdFrame:SetWidth(v)
            elseif key == "fsr" and Castborn.fsrFrame then Castborn.fsrFrame:SetWidth(v)
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
                elseif key == "fsr" and Castborn.fsrFrame then Castborn.fsrFrame:SetHeight(v)
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

    -- Background colour picker
    if db.bgColor then
        local bgPicker = CreateColorPicker(parent, "Background Colour", db, "bgColor", function()
            if Castborn.RefreshBackgrounds then
                Castborn:RefreshBackgrounds()
            end
        end)
        bgPicker:SetPoint("TOPLEFT", 0, y)
        y = y - 30
    end

    -- Module-specific options
    local builder = moduleBuilders[key]
    if builder then
        y = builder(parent, db, y)
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
        Castborn:LockFrames()
        Castborn:Print("Frames locked")
    elseif cmd == "unlock" then
        Castborn:UnlockFrames()
        Castborn:Print("Frames unlocked - drag to reposition")
    elseif cmd == "grid" then
        if Castborn.GridPosition then
            Castborn.GridPosition:TogglePositioningMode()
        end
    elseif cmd == "test" then
        Castborn:EnterTestMode()
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
    elseif cmd == "debug" and state == "totems" then
        -- Debug: print totem buff info for party members
        Castborn:Print("Totem debug info:")
        for slot = 1, 4 do
            local haveTotem, name = GetTotemInfo(slot)
            if haveTotem and name then
                print("  Slot " .. slot .. ": " .. name)
            end
        end
        local partySize = 0
        for i = 1, 4 do
            if UnitExists("party" .. i) then partySize = partySize + 1 end
        end
        if partySize == 0 then
            print("  No party members (solo)")
        else
            for i = 1, 4 do
                local unit = "party" .. i
                if UnitExists(unit) then
                    local unitName = UnitName(unit)
                    print("  " .. unitName .. " buffs:")
                    for b = 1, 40 do
                        local buffName = UnitBuff(unit, b)
                        if not buffName then break end
                        print("    " .. b .. ": " .. buffName)
                    end
                end
            end
        end
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

    local title = panel:CreateFontString(nil, "OVERLAY", "CastbornOptionsLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    title:SetText("|cffFFCC00Castborn|r")

    local version = panel:CreateFontString(nil, "OVERLAY", "CastbornOptionsSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText("Version " .. (Castborn.version or "?"))

    local desc = panel:CreateFontString(nil, "OVERLAY", "CastbornOptionsText")
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

    local hint = panel:CreateFontString(nil, "OVERLAY", "CastbornOptionsSmall")
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

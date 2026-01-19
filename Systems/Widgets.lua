-- Systems/Widgets.lua
local Widgets = {}
Castborn.Widgets = Widgets

-- Create a checkbox
function Widgets:CreateCheckbox(parent, label, db, key, onChange)
    local frame = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    frame:SetSize(24, 24)

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("LEFT", frame, "RIGHT", 4, 0)
    frame.text:SetText(label)

    frame:SetChecked(db[key])
    frame:SetScript("OnClick", function(self)
        db[key] = self:GetChecked()
        if onChange then onChange(db[key]) end
    end)

    return frame
end

function Widgets:CreateSlider(parent, label, db, key, minVal, maxVal, step, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(180, 40)

    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 0, 0)
    labelText:SetText(label .. ": " .. tostring(db[key] or minVal))

    local slider = CreateFrame("Slider", nil, container)
    slider:SetPoint("TOPLEFT", 0, -16)
    slider:SetPoint("TOPRIGHT", 0, -16)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(db[key] or minVal)
    slider:EnableMouse(true)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOPLEFT", 0, -6)
    track:SetPoint("BOTTOMRIGHT", 0, 6)
    track:SetColorTexture(0.15, 0.15, 0.15, 1)

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(14, 14)
    thumb:SetColorTexture(0.6, 0.6, 0.6, 1)
    slider:SetThumbTexture(thumb)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / (step or 1) + 0.5) * (step or 1)
        db[key] = value
        labelText:SetText(label .. ": " .. tostring(value))
        if onChange then onChange(value) end
    end)

    container.slider = slider
    return container
end

-- Create a dropdown
function Widgets:CreateDropdown(parent, label, db, key, options, onChange)
    local frame = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    frame:SetPoint("LEFT", 0, 0)

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 16, 2)
    frame.label:SetText(label)

    UIDropDownMenu_SetWidth(frame, 150)
    UIDropDownMenu_SetText(frame, db[key] or "Select...")

    UIDropDownMenu_Initialize(frame, function(self, level)
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label or option
            info.value = option.value or option
            info.checked = (db[key] == info.value)
            info.func = function()
                db[key] = info.value
                UIDropDownMenu_SetText(frame, info.text)
                if onChange then onChange(info.value) end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    return frame
end

-- Create a color picker button
function Widgets:CreateColorPicker(parent, label, db, key, onChange)
    local frame = CreateFrame("Button", nil, parent)
    frame:SetSize(24, 24)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()

    local color = db[key] or {1, 1, 1, 1}
    frame.bg:SetColorTexture(unpack(color))

    frame.border = frame:CreateTexture(nil, "BORDER")
    frame.border:SetPoint("TOPLEFT", -1, 1)
    frame.border:SetPoint("BOTTOMRIGHT", 1, -1)
    frame.border:SetColorTexture(0.3, 0.3, 0.3, 1)

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.label:SetPoint("LEFT", frame, "RIGHT", 6, 0)
    frame.label:SetText(label)

    frame:SetScript("OnClick", function()
        local r, g, b, a = unpack(db[key] or {1, 1, 1, 1})

        local function OnColorChanged()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            local newA = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
            db[key] = {newR, newG, newB, newA}
            frame.bg:SetColorTexture(newR, newG, newB, newA)
            if onChange then onChange(db[key]) end
        end

        local function OnCancel()
            db[key] = {r, g, b, a}
            frame.bg:SetColorTexture(r, g, b, a)
            if onChange then onChange(db[key]) end
        end

        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - (a or 1)
        ColorPickerFrame.previousValues = {r, g, b, a}
        ColorPickerFrame.func = OnColorChanged
        ColorPickerFrame.opacityFunc = OnColorChanged
        ColorPickerFrame.cancelFunc = OnCancel
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    end)

    return frame
end

-- Create a button
function Widgets:CreateButton(parent, label, onClick)
    local frame = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    frame:SetSize(100, 22)
    frame:SetText(label)
    frame:SetScript("OnClick", onClick)
    return frame
end

-- Create a section header
function Widgets:CreateHeader(parent, text)
    local frame = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame:SetText(text)
    return frame
end

-- Create a divider line
function Widgets:CreateDivider(parent, width)
    local frame = parent:CreateTexture(nil, "ARTWORK")
    frame:SetSize(width or 300, 1)
    frame:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    return frame
end

-- Create a scroll frame
function Widgets:CreateScrollFrame(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width, height)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(width - 20, 1) -- Height will grow
    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end

-- Create an edit box
function Widgets:CreateEditBox(parent, label, db, key, width, onChange)
    local frame = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    frame:SetSize(width or 150, 20)
    frame:SetAutoFocus(false)
    frame:SetText(db[key] or "")

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
    frame.label:SetText(label)

    frame:SetScript("OnEnterPressed", function(self)
        db[key] = self:GetText()
        self:ClearFocus()
        if onChange then onChange(db[key]) end
    end)

    frame:SetScript("OnEscapePressed", function(self)
        self:SetText(db[key] or "")
        self:ClearFocus()
    end)

    return frame
end

--[[
    Castborn - options theme (Gilded Grimoire, chamfered)
    Palette, bundled fonts and textures, and the chamfered (cut-corner) box every options
    control is drawn with. The box is a 9-slice built from one white fill texture and one
    white edge texture, tinted with SetVertexColor, so one art set serves every colour.
    Shared by TBC and Forever: all art ships with the addon.
]]

local Theme = {}
Castborn.Theme = Theme

local MEDIA = "Interface\\AddOns\\Castborn\\Media\\"
local TEXTURES = MEDIA .. "Textures\\"
local FONTS = MEDIA .. "Fonts\\"

-- Texture paths (no extension; WoW finds the .tga)
Theme.media = {
    chamferFill = TEXTURES .. "ChamferFill",
    chamferEdge = TEXTURES .. "ChamferEdge",
    chamferEdgeSmall = TEXTURES .. "ChamferEdgeSmall",
    ribbon = TEXTURES .. "Ribbon",
    diamond = TEXTURES .. "Diamond",
    tick = TEXTURES .. "Tick",
    chevron = TEXTURES .. "Chevron",
    glow = TEXTURES .. "Glow",
}

Theme.fonts = {
    display = FONTS .. "CormorantGaramond-Bold.ttf",
    heading = FONTS .. "CormorantGaramond-SemiBold.ttf",
    body = FONTS .. "SourceSans3-Regular.ttf",
    strong = FONTS .. "SourceSans3-SemiBold.ttf",
}

local function hex(h)
    return {
        tonumber(h:sub(2, 3), 16) / 255,
        tonumber(h:sub(4, 5), 16) / 255,
        tonumber(h:sub(6, 7), 16) / 255,
    }
end

-- Gilded palette
Theme.colors = {
    frame = hex("#100D09"),
    navA = hex("#0B0906"),
    navB = hex("#16120C"),
    pageA = hex("#2A2216"),
    pageB = hex("#19140D"),
    text = hex("#ECE2CC"),
    title = hex("#F7ECD2"),
    muted = hex("#B9AB8C"),
    navText = hex("#C2B496"),
    heading = hex("#F0CF7A"),
    accent = hex("#D4A84A"),
    rule = hex("#5C4C2E"),
    divider = hex("#33291A"),
    ribbonA = hex("#6B4E17"),
    ribbonB = hex("#A57A26"),
    onAccent = hex("#FFF6DE"),
    inputBg = hex("#0B0906"),
    raised = hex("#16120C"),
    knob = hex("#2A2216"),
    dangerEdge = hex("#8A3122"),
    dangerFill = hex("#1A0F0B"),
    dangerText = hex("#F2A08C"),
}

-- r, g, b, a for a palette name or an explicit {r, g, b[, a]}
function Theme:Color(color, alpha)
    local c = type(color) == "table" and color or self.colors[color]
    return c[1], c[2], c[3], alpha or c[4] or 1
end

-- Font roles: face and colour
local ROLES = {
    display = { "display", "title" },
    heading = { "heading", "heading" },
    subtitle = { "heading", "muted" },  -- upright, in the muted colour
    body = { "body", "text" },
    strong = { "strong", "title" },
}

function Theme:Font(fontString, role, size, flags)
    local r = ROLES[role] or ROLES.body
    fontString:SetFont(self.fonts[r[1]], size, flags or "")
    fontString:SetTextColor(self:Color(r[2]))
end

-- The textures are 32px with 8px cuts
local TEXTURE_SIZE, TEXTURE_CUT = 32, 8

-- The nine regions of a chamfer texture cut at `cut` of `size` pixels: texture coordinates,
-- and the two frame anchors of each region, with x/y as multiples of the on-screen cut size
function Theme.SliceLayout(cut, size)
    local c = cut / size
    local spans = { { 0, c }, { c, 1 - c }, { 1 - c, 1 } }
    local names = {
        { "TOPLEFT", "TOP", "TOPRIGHT" },
        { "LEFT", "CENTER", "RIGHT" },
        { "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
    }
    -- Left/right edges per column, top/bottom edges per row: side of the frame and offset
    local leftEdge = { { "LEFT", 0 }, { "LEFT", 1 }, { "RIGHT", -1 } }
    local rightEdge = { { "LEFT", 1 }, { "RIGHT", -1 }, { "RIGHT", 0 } }
    local topEdge = { { "TOP", 0 }, { "TOP", -1 }, { "BOTTOM", 1 } }
    local bottomEdge = { { "TOP", -1 }, { "BOTTOM", 1 }, { "BOTTOM", 0 } }

    local regions = {}
    for row = 1, 3 do
        for col = 1, 3 do
            regions[#regions + 1] = {
                key = names[row][col],
                left = spans[col][1], right = spans[col][2],
                top = spans[row][1], bottom = spans[row][2],
                from = { rel = topEdge[row][1] .. leftEdge[col][1], x = leftEdge[col][2], y = topEdge[row][2] },
                to = { rel = bottomEdge[row][1] .. rightEdge[col][1], x = rightEdge[col][2], y = bottomEdge[row][2] },
            }
        end
    end
    return regions
end

-- Draw a chamfered box on `frame`. opts: cut (on-screen px, default 8), fill and edge
-- (palette names or colours; nil hides that layer), layer (draw layer, default BACKGROUND)
function Theme:Chamfer(frame, opts)
    opts = opts or {}
    local px = opts.cut or 8
    local layer = opts.layer or "BACKGROUND"
    local edgeTexture = px < TEXTURE_CUT and self.media.chamferEdgeSmall or self.media.chamferEdge
    local box = { fill = {}, edge = {} }
    for _, r in ipairs(self.SliceLayout(TEXTURE_CUT, TEXTURE_SIZE)) do
        for kind, path in pairs({ fill = self.media.chamferFill, edge = edgeTexture }) do
            local tex = frame:CreateTexture(nil, layer, nil, kind == "fill" and 0 or 1)
            tex:SetTexture(path)
            tex:SetTexCoord(r.left, r.right, r.top, r.bottom)
            tex:SetPoint("TOPLEFT", frame, r.from.rel, r.from.x * px, r.from.y * px)
            tex:SetPoint("BOTTOMRIGHT", frame, r.to.rel, r.to.x * px, r.to.y * px)
            table.insert(box[kind], tex)
        end
    end
    frame.chamfer = box
    self:SetChamferColors(frame, opts.fill, opts.edge)
    return box
end

-- Retint a chamfered box (hover, checked, disabled); nil hides that layer
function Theme:SetChamferColors(frame, fill, edge)
    for kind, color in pairs({ fill = fill or false, edge = edge or false }) do
        for _, tex in ipairs(frame.chamfer[kind]) do
            if color then
                tex:SetVertexColor(self:Color(color))
                tex:Show()
            else
                tex:Hide()
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Shared widgets: the options window and every other Castborn window build with these
--------------------------------------------------------------------------------

-- Buttons: secondary (dark plate, quiet gold edge) unless a variant is given:
-- "primary" (solid gold) or "danger" (dark red edge, for deleting)
local BUTTON_STYLES = {
    primary = { fill = "ribbonB", hoverFill = "accent", text = "onAccent" },
    secondary = { fill = "raised", edge = "rule", hoverEdge = "accent", text = "text" },
    danger = { fill = "dangerFill", edge = "dangerEdge", hoverEdge = "dangerText", text = "dangerText" },
}

function Theme:CreateButton(parent, text, width, onClick, variant)
    local style = BUTTON_STYLES[variant or "secondary"]
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 100, 24)
    self:Chamfer(btn, { cut = 6, fill = style.fill, edge = style.edge })

    local label = btn:CreateFontString(nil, "OVERLAY")
    self:Font(label, "strong", 13)
    label:SetTextColor(self:Color(style.text))
    label:SetPoint("CENTER", 0, 0)
    btn:SetFontString(label)
    btn:SetText(text)

    btn:SetScript("OnEnter", function(b)
        Theme:SetChamferColors(b, style.hoverFill or style.fill, style.hoverEdge or style.edge)
    end)
    btn:SetScript("OnLeave", function(b)
        Theme:SetChamferColors(b, style.fill, style.edge)
    end)
    btn:SetScript("OnDisable", function(b) b:SetAlpha(0.45) end)
    btn:SetScript("OnEnable", function(b) b:SetAlpha(1) end)
    btn:SetScript("OnClick", function(b)
        if onClick then onClick(b) end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    return btn
end

-- Checkbox: a small chamfered box with a gold tick; the label is part of the click area.
-- With dbTable/dbKey it reads and writes that setting; onChange(checked) runs after a click.
function Theme:CreateCheckbox(parent, label, dbTable, dbKey, onChange)
    local frame = CreateFrame("CheckButton", nil, parent)
    frame:SetSize(26, 26)

    local box = CreateFrame("Frame", nil, frame)
    box:SetSize(18, 18)
    box:SetPoint("CENTER")
    self:Chamfer(box, { cut = 4 })

    local tick = box:CreateTexture(nil, "OVERLAY")
    tick:SetTexture(self.media.tick)
    tick:SetVertexColor(self:Color("heading"))
    tick:SetSize(14, 14)
    tick:SetPoint("CENTER")

    frame.text = frame:CreateFontString(nil, "OVERLAY")
    self:Font(frame.text, "body", 14)
    frame.text:SetPoint("LEFT", frame, "RIGHT", 4, 0)

    -- Relabel, keeping the click area the width of the label
    function frame:SetLabel(text)
        self.text:SetText(text)
        self:SetHitRectInsets(0, -(self.text:GetStringWidth() + 8), 0, 0)
    end
    frame:SetLabel(label)

    local function Refresh(cb, hover)
        local on = cb:GetChecked() and true or false
        Theme:SetChamferColors(box, on and "knob" or "inputBg", (hover or on) and "accent" or "rule")
        tick:SetShown(on)
        cb.text:SetTextColor(Theme:Color((hover or on) and "text" or "navText"))
    end

    -- Callers set the state directly too, so keep the look in step with it
    local setChecked = frame.SetChecked
    frame.SetChecked = function(cb, checked)
        setChecked(cb, checked)
        Refresh(cb)
    end

    frame:SetChecked(dbTable and dbKey and dbTable[dbKey])

    frame:SetScript("OnEnter", function(cb) Refresh(cb, true) end)
    frame:SetScript("OnLeave", function(cb) Refresh(cb) end)
    frame:SetScript("OnClick", function(cb)
        local checked = cb:GetChecked() and true or false
        if dbTable and dbKey then
            dbTable[dbKey] = checked
        end
        Refresh(cb, true)
        if onChange then onChange(checked) end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    return frame
end

-- Slider: label and value above a hairline track that fills gold, with a diamond knob.
-- With dbTable/dbKey it reads and writes that setting; onChange(value) runs on every change.
-- format(value), if given, turns the value into the text shown.
function Theme:CreateSlider(parent, label, dbTable, dbKey, minVal, maxVal, step, onChange, format)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(200, 50)

    local labelText = frame:CreateFontString(nil, "OVERLAY")
    self:Font(labelText, "body", 14)
    labelText:SetPoint("TOPLEFT", 0, 0)
    labelText:SetText(label)

    local valueText = frame:CreateFontString(nil, "OVERLAY")
    self:Font(valueText, "strong", 14)
    valueText:SetPoint("TOPRIGHT", 0, 0)
    local function ShowValue(value)
        valueText:SetText(format and format(value) or value)
    end

    local slider = CreateFrame("Slider", nil, frame)
    slider:SetPoint("TOPLEFT", 0, -20)
    slider:SetPoint("TOPRIGHT", 0, -20)
    slider:SetHeight(18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)

    -- A hairline track that fills gold up to the value
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetHeight(2)
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetColorTexture(self:Color("rule"))

    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(2)
    fill:SetPoint("LEFT", 0, 0)
    fill:SetColorTexture(self:Color("accent"))
    slider.fill = fill

    -- Diamond knob, brighter while hovered
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(self.media.diamond)
    thumb:SetVertexColor(self:Color("heading"))
    thumb:SetSize(14, 14)
    slider:SetThumbTexture(thumb)
    slider:SetScript("OnEnter", function() thumb:SetVertexColor(Theme:Color("title")) end)
    slider:SetScript("OnLeave", function() thumb:SetVertexColor(Theme:Color("heading")) end)

    local currentValue = (dbTable and dbKey and dbTable[dbKey]) or minVal
    slider:SetValue(currentValue)
    ShowValue(currentValue)

    -- Update fill bar width based on value
    local function UpdateFill(value)
        local range = maxVal - minVal
        if range > 0 then
            local pct = (value - minVal) / range
            fill:SetWidth(math.max(1, slider:GetWidth() * pct))
        end
    end

    slider:SetScript("OnValueChanged", function(s, value)
        value = math.floor(value / step + 0.5) * step
        ShowValue(value)
        UpdateFill(value)
        if dbTable and dbKey then
            dbTable[dbKey] = value
        end
        if onChange then onChange(value) end
    end)

    -- Initialize fill when slider gets its size
    slider:SetScript("OnSizeChanged", function(s, width)
        if width and width > 0 then
            UpdateFill(s:GetValue())
        end
    end)

    frame.slider = slider
    return frame
end

-- Scrollbars on UIPanelScrollFrameTemplate: the template's arrows and track hidden,
-- a slim gold thumb instead
function Theme:SkinScrollBar(scrollFrame)
    local bar = scrollFrame.ScrollBar or (scrollFrame:GetName() and _G[scrollFrame:GetName() .. "ScrollBar"])
    if not bar then return end
    for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
        local arrow = bar[key] or (bar:GetName() and _G[bar:GetName() .. key])
        if arrow then
            arrow:SetAlpha(0)
            arrow:EnableMouse(false)
        end
    end
    for _, region in ipairs({ bar:GetRegions() }) do
        if region:IsObjectType("Texture") and region ~= bar:GetThumbTexture() then
            region:SetAlpha(0)
        end
    end
    local rail = bar:CreateTexture(nil, "BACKGROUND")
    rail:SetWidth(1)
    rail:SetPoint("TOP", 0, 0)
    rail:SetPoint("BOTTOM", 0, 0)
    rail:SetColorTexture(self:Color("divider"))
    local thumb = bar:GetThumbTexture()
    if thumb then
        thumb:SetColorTexture(self:Color("rule"))
        thumb:SetSize(4, 36)
    end
end

-- A gold diamond between two short rules, centred under `anchor`
function Theme:CreateDiamondRule(parent, anchor, lineWidth, gap)
    local diamond = parent:CreateTexture(nil, "ARTWORK")
    diamond:SetTexture(self.media.diamond)
    diamond:SetVertexColor(self:Color("accent"))
    diamond:SetSize(9, 9)
    diamond:SetPoint("TOP", anchor, "BOTTOM", 0, -(gap or 8))
    for _, side in ipairs({ -1, 1 }) do
        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(self:Color("rule"))
        line:SetSize(lineWidth or 70, 1)
        if side < 0 then
            line:SetPoint("RIGHT", diamond, "LEFT", -4, 0)
        else
            line:SetPoint("LEFT", diamond, "RIGHT", 4, 0)
        end
    end
    return diamond
end

-- A free-standing Castborn window: a gold-edged plaque with an inner rule and a display-face
-- title over a diamond rule; draggable, above the game UI. opts: name, width, height, title,
-- titleSize (default 24). Build content on plaque.inner, below plaque.rule (the diamond).
function Theme:CreatePanel(opts)
    local width = opts.width or 300
    local plaque = CreateFrame("Frame", opts.name, UIParent)
    plaque:SetSize(width, opts.height or 200)
    plaque:SetFrameStrata("FULLSCREEN_DIALOG")
    plaque:SetClampedToScreen(true)
    plaque:SetMovable(true)
    plaque:EnableMouse(true)
    plaque:RegisterForDrag("LeftButton")
    plaque:SetScript("OnDragStart", plaque.StartMoving)
    plaque:SetScript("OnDragStop", plaque.StopMovingOrSizing)
    self:Chamfer(plaque, { cut = 12, fill = "frame", edge = "accent" })

    local inner = CreateFrame("Frame", nil, plaque)
    inner:SetPoint("TOPLEFT", 4, -4)
    inner:SetPoint("BOTTOMRIGHT", -4, 4)
    self:Chamfer(inner, { cut = 9, fill = "pageB", edge = "rule" })
    plaque.inner = inner

    -- Soft light behind the title, like the options page
    local glow = inner:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetTexture(self.media.glow)
    glow:SetVertexColor(self:Color("pageA"))
    glow:SetSize(math.min(440, width * 1.1), 170)
    glow:SetPoint("CENTER", inner, "TOP", 0, -50)

    local title = inner:CreateFontString(nil, "OVERLAY")
    self:Font(title, "display", opts.titleSize or 24)
    title:SetPoint("TOP", 0, -14)
    title:SetText(opts.title or "")
    plaque.title = title

    plaque.rule = self:CreateDiamondRule(inner, title, 60, 6)

    plaque:Hide()
    return plaque
end

-- A text colour code for inline use in strings, from a palette name: "|cffRRGGBB"
function Theme:Code(name)
    local r, g, b = self:Color(name)
    return string.format("|cff%02x%02x%02x", r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5)
end

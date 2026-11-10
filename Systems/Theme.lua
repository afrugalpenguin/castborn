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

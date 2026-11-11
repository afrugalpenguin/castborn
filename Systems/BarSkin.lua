--[[
    Castborn - Bar skins
    Draws a skin's border, backdrop, gloss and shadow around Castborn's bars.
    With Masque installed, the bars follow the "Bars" group in Masque's options, like the icon
    groups: its skin, its Backdrop / Gloss / Shadow toggles and its colours. Without Masque, or
    with that group disabled, they fall back to the skin chosen on the Look & Feel page: the plain
    Castborn look, a built-in skin, or one another addon added with Castborn:RegisterBarSkin.

    Skins use Masque's region format (Normal = border, Backdrop, Gloss, Shadow; each with Texture
    or Atlas, TexCoords, Color, BlendMode, Width, Height sized for a 36px button). Masque only
    skins square buttons, so the border is drawn as a nine-slice: corners stay square and the
    edges stretch along their length only. Skins do not say how thick their border art is, so the
    corner size comes from the Skin Border Size setting.
]]

local BarSkin = {}
Castborn.BarSkin = BarSkin

local CB = Castborn

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BUTTON_SIZE = 36  -- Masque skins are drawn for a 36px button
local NONE = "Castborn"  -- the plain look: Castborn's own border and background

-- A fallback skin draws every layer it has, with the skin's own colours
local FALLBACK_OPTS = { backdrop = true, gloss = true, shadow = true }

-- Frames that wear the skin
BarSkin.frames = {}

BarSkin.skins = {
    Flat = {
        Normal = { Texture = WHITE, Color = { 0, 0, 0, 1 } },
        Backdrop = { Texture = WHITE, Color = { 0, 0, 0, 0.75 } },
    },
    ["Flat Grey"] = {
        Normal = { Texture = WHITE, Color = { 0.45, 0.45, 0.45, 1 } },
        Backdrop = { Texture = WHITE, Color = { 0.05, 0.05, 0.05, 0.75 } },
    },
}

-- Lets other addons add a skin in Masque's region format
function CB:RegisterBarSkin(id, data)
    if type(id) == "string" and type(data) == "table" and id ~= NONE then
        BarSkin.skins[id] = data
    end
end

-- The Masque group the bars follow, or nil without Masque or with the group disabled
function BarSkin:GetMasqueGroup()
    local M = CB.Masque
    local group = M and M.lib and M.groups and M.groups.bars
    if not group or type(group.db) ~= "table" or group.db.Disabled then return nil end
    return group
end

function BarSkin:IsMasqueActive()
    return self:GetMasqueGroup() ~= nil
end

-- The skin to draw and which layers to draw: the Masque group's, else the fallback choice
function BarSkin:GetActiveSkin()
    local group = self:GetMasqueGroup()
    if group then
        local lib, db = CB.Masque.lib, group.db
        local skin = lib.GetSkin and lib:GetSkin(db.SkinID)
        if not skin and lib.GetDefaultSkin then
            local _, default = lib:GetDefaultSkin()
            skin = default
        end
        if skin then
            return skin, {
                backdrop = db.Backdrop and true or false,
                gloss = db.Gloss and true or false,
                shadow = db.Shadow and true or false,
                colors = db.Colors,
            }
        end
    end
    local saved = (CB.db or CastbornDB or {}).barSkin
    return self:GetSkinData(saved), FALLBACK_OPTS
end

-- Fallback dropdown entries: the plain look, then Castborn's and other addons' skins
function BarSkin:List()
    local list = { { value = NONE, label = "Castborn" } }
    local names = {}
    for id in pairs(self.skins) do names[#names + 1] = id end
    table.sort(names)
    for _, id in ipairs(names) do list[#list + 1] = { value = id, label = id } end
    return list
end

-- Fallback skin data for a saved id, or nil for the plain look
function BarSkin:GetSkinData(id)
    if not id or id == NONE then return nil end
    return self.skins[id]
end

-- A region's table, following names that point at another region; nil if hidden or missing
function BarSkin:ResolveRegion(skin, name)
    local region = skin and skin[name]
    if type(region) == "string" then region = skin[region] end
    if type(region) ~= "table" or region.Hide then return nil end
    return region
end

-- file, left, right, top, bottom for a region's texture or atlas
function BarSkin:GetRegionTexture(region)
    if not region then return nil end
    if region.Atlas then
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(region.Atlas)
        if not info then return nil end
        return info.file or info.filename, info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    end
    if not region.Texture then return nil end
    local tc = region.TexCoords
    if type(tc) == "table" then return region.Texture, tc[1], tc[2], tc[3], tc[4] end
    return region.Texture, 0, 1, 0, 1
end

-- Texture coordinates for the eight border pieces; fx and fy are the corner's share of the texture
function BarSkin:SliceCoords(l, r, t, b, fx, fy)
    local u, U = l + (r - l) * fx, r - (r - l) * fx
    local v, V = t + (b - t) * fy, b - (b - t) * fy
    return {
        TOPLEFT = { l, u, t, v }, TOP = { u, U, t, v }, TOPRIGHT = { U, r, t, v },
        LEFT = { l, u, v, V }, RIGHT = { U, r, v, V },
        BOTTOMLEFT = { l, u, V, b }, BOTTOM = { u, U, V, b }, BOTTOMRIGHT = { U, r, V, b },
    }
end

-- override is a Masque group colour for the layer, if the user set one
local function SetColor(texture, region, override)
    local c = override or region.Color
    if type(c) == "table" then
        texture:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    else
        texture:SetVertexColor(1, 1, 1, 1)
    end
    texture:SetBlendMode(region.BlendMode or "BLEND")
end

-- How far a region reaches past the frame, from its size against Masque's 36px button
local function Outset(region)
    return ((region.Width or BUTTON_SIZE) - BUTTON_SIZE) / 2, ((region.Height or BUTTON_SIZE) - BUTTON_SIZE) / 2
end

local PIECES = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

-- The skin's textures for a frame, created on first use. The border sits on a child frame
-- above the bar; backdrop and shadow sit behind it on the frame itself.
local function GetParts(frame)
    if frame.castbornSkin then return frame.castbornSkin end
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 5)

    local parts = { overlay = overlay, pieces = {} }
    for _, key in ipairs(PIECES) do
        parts.pieces[key] = overlay:CreateTexture(nil, "BORDER")
    end
    parts.gloss = overlay:CreateTexture(nil, "OVERLAY")
    parts.backdrop = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    parts.shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    for _, tex in pairs(parts.pieces) do tex:Hide() end
    parts.gloss:Hide()
    parts.backdrop:Hide()
    parts.shadow:Hide()
    frame.castbornSkin = parts
    return parts
end

local function HideParts(parts)
    if not parts then return end
    for _, tex in pairs(parts.pieces) do tex:Hide() end
    parts.gloss:Hide()
    parts.backdrop:Hide()
    parts.shadow:Hide()
end

local function SetCastbornBorder(frame, shown)
    if not frame.border then return end
    for _, tex in pairs(frame.border) do
        if shown then tex:Show() else tex:Hide() end
    end
end

-- Stretch a region's texture over the frame, reaching past it by the region's outset
local function ApplyStretched(frame, texture, region, colour)
    local file, l, r, t, b = BarSkin:GetRegionTexture(region)
    if not file then texture:Hide() return false end
    local ox, oy = Outset(region)
    texture:SetTexture(file)
    texture:SetTexCoord(l, r, t, b)
    SetColor(texture, region, colour)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", -ox, oy)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", ox, -oy)
    texture:Show()
    return true
end

local function ApplyBorder(frame, parts, region, size, colour)
    local file, l, r, t, b = BarSkin:GetRegionTexture(region)
    if not file then
        for _, tex in pairs(parts.pieces) do tex:Hide() end
        return false
    end
    local width, height = region.Width or BUTTON_SIZE, region.Height or BUTTON_SIZE
    local coords = BarSkin:SliceCoords(l, r, t, b, size / width, size / height)
    local ox, oy = Outset(region)
    local p = parts.pieces
    for _, key in ipairs(PIECES) do
        local tex = p[key]
        tex:SetTexture(file)
        local c = coords[key]
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
        SetColor(tex, region, colour)
        tex:ClearAllPoints()
    end
    -- Corners at fixed size; edges fill the gaps between them
    for _, key in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        p[key]:SetSize(size, size)
    end
    p.TOPLEFT:SetPoint("TOPLEFT", frame, "TOPLEFT", -ox, oy)
    p.TOPRIGHT:SetPoint("TOPRIGHT", frame, "TOPRIGHT", ox, oy)
    p.BOTTOMLEFT:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -ox, -oy)
    p.BOTTOMRIGHT:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", ox, -oy)
    p.TOP:SetPoint("TOPLEFT", p.TOPLEFT, "TOPRIGHT")
    p.TOP:SetPoint("BOTTOMRIGHT", p.TOPRIGHT, "BOTTOMLEFT")
    p.BOTTOM:SetPoint("TOPLEFT", p.BOTTOMLEFT, "TOPRIGHT")
    p.BOTTOM:SetPoint("BOTTOMRIGHT", p.BOTTOMRIGHT, "BOTTOMLEFT")
    p.LEFT:SetPoint("TOPLEFT", p.TOPLEFT, "BOTTOMLEFT")
    p.LEFT:SetPoint("BOTTOMRIGHT", p.BOTTOMLEFT, "TOPRIGHT")
    p.RIGHT:SetPoint("TOPLEFT", p.TOPRIGHT, "BOTTOMLEFT")
    p.RIGHT:SetPoint("BOTTOMRIGHT", p.BOTTOMRIGHT, "TOPRIGHT")
    for _, tex in pairs(p) do tex:Show() end
    return true
end

-- Dress one frame in the current skin, or put the Castborn look back
function BarSkin:Apply(frame)
    local db = CB.db or CastbornDB or {}
    local bordersOn = db.showBorders ~= false
    local skin, opts = self:GetActiveSkin()

    if not skin then
        HideParts(frame.castbornSkin)
        SetCastbornBorder(frame, bordersOn)
        if frame.bg then frame.bg:Show() end
        return
    end

    local parts = GetParts(frame)
    local size = db.barSkinBorder or 2
    local colors = opts.colors or {}

    -- The skin's border replaces Castborn's; with no usable border art, keep Castborn's
    local border = self:ResolveRegion(skin, "Normal")
    local usable = border ~= nil and self:GetRegionTexture(border) ~= nil
    if not (usable and bordersOn and ApplyBorder(frame, parts, border, size, colors.Normal)) then
        for _, tex in pairs(parts.pieces) do tex:Hide() end
    end
    SetCastbornBorder(frame, bordersOn and not usable)

    -- Each other layer draws only if the skin has it and (for Masque) the group has it on
    local backdrop = opts.backdrop and self:ResolveRegion(skin, "Backdrop")
    local hasBackdrop = backdrop and ApplyStretched(frame, parts.backdrop, backdrop, colors.Backdrop)
    if not hasBackdrop then parts.backdrop:Hide() end
    if frame.bg then
        if hasBackdrop then frame.bg:Hide() else frame.bg:Show() end
    end

    local gloss = opts.gloss and self:ResolveRegion(skin, "Gloss")
    if not (gloss and ApplyStretched(frame, parts.gloss, gloss, colors.Gloss)) then parts.gloss:Hide() end

    local shadow = opts.shadow and self:ResolveRegion(skin, "Shadow")
    if not (shadow and ApplyStretched(frame, parts.shadow, shadow, colors.Shadow)) then parts.shadow:Hide() end
end

function BarSkin:Register(frame)
    if not frame then return end
    self.frames[frame] = true
    self:Apply(frame)
end

function BarSkin:ApplyAll()
    for frame in pairs(self.frames) do
        self:Apply(frame)
    end
end

CB:RegisterCallback("BORDERS_CHANGED", function()
    BarSkin:ApplyAll()
end)

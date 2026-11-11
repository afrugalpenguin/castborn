-- Modules/CooldownGroup.lua
-- A group of cooldown icons: its container, icon pool, optional trinket pair, layout,
-- live updates and test mode with drag-to-reorder. CooldownTracker.lua owns the settings,
-- the spell list and the update loop, and drives one group through this object.
local CooldownGroup = {}
CooldownGroup.__index = CooldownGroup
Castborn.CooldownGroup = CooldownGroup

local MAX_ICONS = 20
CooldownGroup.MAX_ICONS = MAX_ICONS

local TRINKET_SLOTS = { 13, 14 }

-- Grow directions the build-time layout places icons for; anything else leaves them unanchored
local LAYOUT_DIRECTIONS = { LEFT = true, RIGHT = true, UP = true, DOWN = true, CENTER = true }

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

-- Calculate x,y offsets for a given visible index with row/column wrapping
local function CalcIconPosition(visibleIndex, settings)
    local size = settings.iconSize or 36
    local spacing = settings.spacing or 4
    local perRow = settings.iconsPerRow or 10
    local isVertical = settings.orientation == "VERTICAL"

    if isVertical then
        -- Vertical: primary axis is Y (down), wrapping on X (right)
        local row = (visibleIndex - 1) % perRow
        local col = math.floor((visibleIndex - 1) / perRow)
        local x = col * (size + spacing)
        local y = -(row * (size + spacing))
        return x, y
    else
        -- Horizontal: primary axis is X (right), wrapping on Y (down)
        local col = (visibleIndex - 1) % perRow
        local row = math.floor((visibleIndex - 1) / perRow)
        local x = col * (size + spacing)
        local y = -(row * (size + spacing))
        return x, y
    end
end

-- How many icons sit in the row (column when vertical) holding slot, out of count icons.
-- Without a count every row is full.
local function LineLength(slot, perRow, count)
    if not count then return perRow end
    local line = math.floor((slot - 1) / perRow)
    return math.max(1, math.min(perRow, count - line * perRow))
end

-- Where slot N sits in the container: the anchor point, the container's relative point and
-- the x/y offsets. Every placement goes through here. LEFT grows from the top right, UP from
-- the bottom left, CENTER centres each row on the top edge (each column on the left edge
-- when vertical), and RIGHT, DOWN and anything else grow from the top left.
-- grow defaults to settings.growDirection. count, the number of visible icons, only matters
-- for CENTER, where it sets the length of the last row.
function CooldownGroup.GetSlotAnchor(slot, settings, grow, count)
    if grow == nil then grow = settings.growDirection end
    local colX, rowY = CalcIconPosition(slot, settings)
    if grow == "CENTER" then
        local size = settings.iconSize or 36
        local step = size + (settings.spacing or 4)
        local perRow = settings.iconsPerRow or 10
        local length = LineLength(slot, perRow, count) * step - step + size
        local index = (slot - 1) % perRow
        if settings.orientation == "VERTICAL" then
            return "LEFT", "LEFT", colX, length / 2 - size / 2 - index * step
        end
        return "TOP", "TOP", index * step + size / 2 - length / 2, rowY
    elseif grow == "LEFT" then
        return "TOPRIGHT", "TOPRIGHT", -colX, rowY
    elseif grow == "UP" then
        return "BOTTOMLEFT", "BOTTOMLEFT", colX, -rowY
    end
    return "TOPLEFT", "TOPLEFT", colX, rowY
end

-- Container width and height for count icons, plus 4px of height
function CooldownGroup.GetContainerSize(count, settings)
    local perRow = settings.iconsPerRow or 10
    local size = settings.iconSize or 36
    local spacing = settings.spacing or 4
    local cols, rows
    if settings.orientation == "VERTICAL" then
        rows = math.min(count, perRow)
        cols = math.ceil(count / perRow)
    else
        cols = math.min(count, perRow)
        rows = math.ceil(count / perRow)
    end
    return cols * size + (cols - 1) * spacing,
           rows * size + (rows - 1) * spacing + 4
end

local GetSlotAnchor = CooldownGroup.GetSlotAnchor

-- Which slot the point (x, y) falls in: the inverse of GetSlotAnchor, for a container with
-- the given edges. Distances are measured from the corner slot 1 is anchored to, in the
-- direction the icons grow. Along a row (a column when vertical) a point past the middle
-- of a slot counts as the next slot, so a drop lands where the insertion marker shows;
-- across rows it is the row the point is in. Not clamped to the number of icons. count, the
-- number of icons shown, only matters for CENTER, where it sets the length of the last row.
function CooldownGroup.GetSlotAtPoint(settings, x, y, left, right, top, bottom, count)
    local size = settings.iconSize or 36
    local spacing = settings.spacing or 4
    local perRow = settings.iconsPerRow or 10
    local step = size + spacing
    local vertical = settings.orientation == "VERTICAL"

    local along, across
    if settings.growDirection == "CENTER" then
        -- Rows (columns) are centred, so measure along each from where it starts
        across = vertical and (x - left) or (top - y)
        local line = math.max(0, math.floor(across / step))
        local length = LineLength(line * perRow + 1, perRow, count) * step - step + size
        if vertical then
            along = ((top + bottom) / 2 + length / 2) - y
        else
            along = x - ((left + right) / 2 - length / 2)
        end
    else
        local point = GetSlotAnchor(1, settings)
        local dx = (point == "TOPRIGHT") and (right - x) or (x - left)
        local dy = (point == "BOTTOMLEFT") and (y - bottom) or (top - y)
        if vertical then
            along, across = dy, dx
        else
            along, across = dx, dy
        end
    end

    local index = math.floor(along / step + 0.5)
    index = math.max(0, math.min(index, perRow - 1))
    local line = math.max(0, math.floor(across / step))
    return line * perRow + index + 1
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

-- opts:
--   id           stable group key
--   getSettings  returns the group's settings table (iconSize, spacing, iconsPerRow, ...)
--   getModuleSettings  returns the module-wide settings table (enabled, showReadyGlow,
--                trackTrinkets)
--   getSpells    returns the tracked spell list
--   names        global frame names: container, icon (prefix), and for the group that
--                owns trinkets, trinkets (container) and trinket (prefix)
--   masqueGroup  key passed to Castborn.Masque:AddButton
--   dragLabel    label for Anchoring:MakeDraggable
--   tracker      table with the GetTrackedSpellName, GetSpellCooldownState and
--                SetIconCooldown seams
function CooldownGroup:New(opts)
    local group = setmetatable({}, CooldownGroup)
    group.id = opts.id
    group.getSettings = opts.getSettings
    group.getModuleSettings = opts.getModuleSettings
    group.getSpells = opts.getSpells
    group.names = opts.names
    group.masqueGroup = opts.masqueGroup
    group.dragLabel = opts.dragLabel
    group.tracker = opts.tracker

    group.frame = nil
    group.icons = {}
    group.trinketFrame = nil
    group.trinketIcons = {}

    group.lastCooldownDuration = {}
    group.testModeActive = false
    group.visibleToTrackIndex = {}  -- maps visible icon index -> spell list index
    group.testSpellCount = 0        -- number of visible test spells
    group.dragState = {
        draggingIndex = nil,
        currentTargetSlot = nil,
    }
    return group
end

function CooldownGroup:GetSettings()
    return self.getSettings()
end

function CooldownGroup:GetModuleSettings()
    return self.getModuleSettings()
end

function CooldownGroup:GetSpells()
    return self.getSpells()
end

function CooldownGroup:CreateIcon(parent, index)
    local size = self:GetSettings().iconSize or 32

    -- Use Button frame for Masque compatibility
    local f = CreateFrame("Button", self.names.icon .. index, parent)
    f:SetSize(size, size)

    -- Icon texture
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.Icon = f.icon  -- Masque alias

    -- Normal texture (border) for Masque
    f.Normal = f:CreateTexture(nil, "BORDER")
    f.Normal:SetPoint("TOPLEFT", -1, 1)
    f.Normal:SetPoint("BOTTOMRIGHT", 1, -1)
    f.Normal:SetColorTexture(0.3, 0.3, 0.3, 1)
    if Castborn.Masque and Castborn.Masque.enabled then
        f:SetNormalTexture(f.Normal)
    else
        f.Normal:Hide()
    end

    -- Cooldown frame
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    f.cooldown:SetDrawEdge(true)
    f.cooldown:SetHideCountdownNumbers(false)
    f.cooldown:EnableMouse(false)
    f.Cooldown = f.cooldown  -- Masque alias
    Castborn:FireCallback("COOLDOWN_FRAME_CREATED", f.cooldown)  -- styled by CooldownText_Forever.lua

    f.time = f:CreateFontString(nil, "OVERLAY")
    f.time:SetFont(Castborn:GetBarFont(), 11, "OUTLINE")
    Castborn:RegisterFontString(f.time, 11, "OUTLINE")
    f.time:SetPoint("CENTER")

    -- Charge counter (displayed centered on icon for Earth Shield, Water Shield)
    f.charges = f:CreateFontString(nil, "OVERLAY", nil, 7)
    f.charges:SetFont(Castborn:GetBarFont(), 24, "OUTLINE")
    Castborn:RegisterFontString(f.charges, 24, "OUTLINE")
    f.charges:SetPoint("CENTER", f.icon, "CENTER", 0, 0)
    f.charges:SetTextColor(1, 0.82, 0, 1)  -- Yellow/gold colour
    f.charges:Hide()

    -- Glow effect using layered textures for soft glow look
    f.glowOuter = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.glowOuter:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    f.glowOuter:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    f.glowOuter:SetBlendMode("ADD")
    f.glowOuter:SetPoint("TOPLEFT", -8, 8)
    f.glowOuter:SetPoint("BOTTOMRIGHT", 8, -8)
    -- Full vertex alpha and zero region alpha: the retail engine (Forever) multiplies the two,
    -- so a zero vertex alpha would keep the glow invisible after SetAlpha(0.3)
    f.glowOuter:SetVertexColor(1, 0.8, 0.3, 1)
    f.glowOuter:SetAlpha(0)
    f.glow = f.glowOuter  -- Keep reference for existing code

    -- Drag shadow effect (hidden by default)
    f.dragShadow = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    f.dragShadow:SetColorTexture(0, 0, 0, 0.5)
    f.dragShadow:SetPoint("TOPLEFT", 3, -3)
    f.dragShadow:SetPoint("BOTTOMRIGHT", 3, -3)
    f.dragShadow:Hide()

    -- Bright drag glow effect (hidden by default)
    f.dragGlow = f:CreateTexture(nil, "OVERLAY")
    f.dragGlow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    f.dragGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    f.dragGlow:SetBlendMode("ADD")
    f.dragGlow:SetPoint("TOPLEFT", -10, 10)
    f.dragGlow:SetPoint("BOTTOMRIGHT", 10, -10)
    f.dragGlow:SetVertexColor(1, 0.8, 0.2, 1)  -- Bright gold
    f.dragGlow:Hide()

    -- Drag cursor overlay icon
    f.dragCursor = f:CreateTexture(nil, "OVERLAY")
    f.dragCursor:SetTexture("Interface\\CURSOR\\Move")
    f.dragCursor:SetSize(20, 20)
    f.dragCursor:SetPoint("TOPLEFT", -4, 4)
    f.dragCursor:SetAlpha(0.9)
    f.dragCursor:Hide()


    -- Register with Masque if available
    if Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:AddButton(self.masqueGroup, f, {
            Icon = f.icon,
            Cooldown = f.cooldown,
            Normal = f.Normal,
        })
    end

    -- Click-through (WeakAuras pattern): Disable + EnableMouse(false)
    f:Disable()
    f:EnableMouse(false)
    f:Hide()
    return f
end

function CooldownGroup:CreateTrinketIcon(parent, index)
    local size = self:GetSettings().iconSize or 32

    local f = CreateFrame("Button", self.names.trinket .. index, parent)
    f:SetSize(size, size)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.Icon = f.icon

    f.Normal = f:CreateTexture(nil, "BORDER")
    f.Normal:SetPoint("TOPLEFT", -1, 1)
    f.Normal:SetPoint("BOTTOMRIGHT", 1, -1)
    f.Normal:SetColorTexture(0.3, 0.3, 0.3, 1)
    if Castborn.Masque and Castborn.Masque.enabled then
        f:SetNormalTexture(f.Normal)
    else
        f.Normal:Hide()
    end

    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    f.cooldown:SetDrawEdge(true)
    f.cooldown:SetHideCountdownNumbers(false)
    f.cooldown:EnableMouse(false)
    f.Cooldown = f.cooldown
    Castborn:FireCallback("COOLDOWN_FRAME_CREATED", f.cooldown)  -- styled by CooldownText_Forever.lua

    f.time = f:CreateFontString(nil, "OVERLAY")
    f.time:SetFont(Castborn:GetBarFont(), 11, "OUTLINE")
    Castborn:RegisterFontString(f.time, 11, "OUTLINE")
    f.time:SetPoint("CENTER")

    if Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:AddButton(self.masqueGroup, f, {
            Icon = f.icon,
            Cooldown = f.cooldown,
            Normal = f.Normal,
        })
    end

    -- Click-through (WeakAuras pattern): Disable + EnableMouse(false)
    f:Disable()
    f:EnableMouse(false)
    f:Hide()
    return f
end

function CooldownGroup:CreateContainer()
    local settings = self:GetSettings()

    local frame = CreateFrame("Frame", self.names.container, UIParent)
    self.frame = frame
    frame:SetSize(CooldownGroup.GetContainerSize(MAX_ICONS, settings))
    frame:SetPoint(settings.point, UIParent, settings.point, settings.x, settings.y)

    for i = 1, MAX_ICONS do
        self.icons[i] = self:CreateIcon(frame, i)
    end

    -- Enhanced insertion marker (4px thick with glow)
    frame.insertMarker = frame:CreateTexture(nil, "OVERLAY")
    frame.insertMarker:SetColorTexture(0.3, 0.8, 1, 0.9)
    frame.insertMarker:SetSize(4, settings.iconSize or 36)
    frame.insertMarker:Hide()

    frame.insertMarkerGlow = frame:CreateTexture(nil, "OVERLAY", nil, -1)
    frame.insertMarkerGlow:SetColorTexture(0.3, 0.8, 1, 0.3)
    frame.insertMarkerGlow:SetSize(8, settings.iconSize or 36)
    frame.insertMarkerGlow:Hide()

    -- Slot highlight box
    frame.slotHighlight = frame:CreateTexture(nil, "BACKGROUND")
    frame.slotHighlight:SetColorTexture(0.3, 0.8, 1, 0.2)
    frame.slotHighlight:SetSize(settings.iconSize or 36, settings.iconSize or 36)
    frame.slotHighlight:Hide()

    if Castborn.Anchoring then
        -- Drags read and save the position through the group's current settings table, so a
        -- drag after a profile switch lands in the new profile rather than a stale copy
        local group = self
        local current = setmetatable({}, {
            __index = function(_, key) return group:GetSettings()[key] end,
            __newindex = function(_, key, value) group:GetSettings()[key] = value end,
        })
        Castborn.Anchoring:MakeDraggable(frame, current, function(f) group:OnDragStopped(f) end, self.dragLabel)
    end

    frame:Hide()  -- Start hidden, will show when cooldowns are tracked
    return frame
end

-- A centred group is re-saved by its centre, so it stays centred as its icon count changes.
-- Other directions keep the corner the drag saved.
function CooldownGroup:OnDragStopped(frame)
    local settings = self:GetSettings()
    if settings.growDirection ~= "CENTER" then return end
    local cx, cy = frame:GetCenter()
    if not cx or not cy then return end

    local x, y = cx - GetScreenWidth() / 2, cy - GetScreenHeight() / 2
    if Castborn.Anchoring then
        Castborn.Anchoring:SavePosition(settings, "CENTER", x, y)
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

-- Hide a group whose settings have gone (removed, or not in a new profile). Frames cannot be
-- destroyed, so the object is kept and reused if the group comes back.
function CooldownGroup:Deactivate()
    self:EndTest()
    if self.frame then
        self.frame:Hide()
        -- Keep the strip out of unlock mode, which shows every draggable frame
        self.frame.dragDisabled = true
    end
    self.inactive = true
end

function CooldownGroup:Reactivate()
    self.inactive = false
    if self.frame then self.frame.dragDisabled = nil end
end

-- The label shown on the strip while frames are unlocked
function CooldownGroup:SetLabel(label)
    self.dragLabel = label
    if self.frame and Castborn.Anchoring and Castborn.Anchoring.SetDragLabel then
        Castborn.Anchoring:SetDragLabel(self.frame, label)
    end
end

-- Register every icon with this group's Masque group again (after it was recreated)
function CooldownGroup:AddToMasque()
    if not (Castborn.Masque and Castborn.Masque.enabled) then return end
    for _, f in ipairs(self.icons) do
        Castborn.Masque:AddButton(self.masqueGroup, f, {
            Icon = f.icon,
            Cooldown = f.cooldown,
            Normal = f.Normal,
        })
    end
end

function CooldownGroup:CreateTrinketContainer()
    local settings = self:GetSettings()
    local size = settings.iconSize or 36
    local spacing = settings.spacing or 4

    local trinketFrame = CreateFrame("Frame", self.names.trinkets, self.frame)
    self.trinketFrame = trinketFrame
    trinketFrame:SetSize(size * 2 + spacing, size + 4)
    trinketFrame:SetPoint("BOTTOMRIGHT", self.frame, "TOPRIGHT", 0, spacing)

    for i = 1, 2 do
        self.trinketIcons[i] = self:CreateTrinketIcon(trinketFrame, i)
    end

    trinketFrame:Hide()
end

-- Build the container, icons and (for the group that owns them) trinkets, then lay out
function CooldownGroup:Build()
    self:CreateContainer()
    if self.names.trinkets then
        self:CreateTrinketContainer()
    end
    self:LayoutAll()
end

-- Put a frame or texture in slot N of the container
function CooldownGroup:PlaceAtSlot(region, slot, settings, count)
    local point, relativePoint, x, y = GetSlotAnchor(slot, settings, nil, count)
    region:ClearAllPoints()
    region:SetPoint(point, self.frame, relativePoint, x, y)
end

-- Place every icon in the pool, as at build time. A missing grow direction counts as LEFT
-- here, unlike everywhere else, where it falls through to the top-left anchor.
function CooldownGroup:LayoutAll()
    local settings = self:GetSettings()
    local size = settings.iconSize or 32
    local grow = settings.growDirection or "LEFT"

    for i, f in ipairs(self.icons) do
        f:ClearAllPoints()
        f:SetSize(size, size)
        if LAYOUT_DIRECTIONS[grow] then
            local point, relativePoint, x, y = GetSlotAnchor(i, settings, grow, MAX_ICONS)
            f:SetPoint(point, self.frame, relativePoint, x, y)
        end
    end
end

--------------------------------------------------------------------------------
-- Ready glow
--------------------------------------------------------------------------------

-- Static glow for ready cooldowns
local function StartEdgePulse(cdFrame)
    if cdFrame.edgePulseActive then return end
    cdFrame.edgePulseActive = true
    cdFrame.glow:SetAlpha(0.3)
end

local function StopEdgePulse(cdFrame)
    if not cdFrame.edgePulseActive then return end
    cdFrame.edgePulseActive = false
    cdFrame.glow:SetAlpha(0)
end

function CooldownGroup:StopGlows()
    for i = 1, MAX_ICONS do
        if self.icons[i] then
            StopEdgePulse(self.icons[i])
        end
    end
end

--------------------------------------------------------------------------------
-- Live update
--------------------------------------------------------------------------------

function CooldownGroup:UpdateTrinkets()
    -- Don't override the sample trinkets test mode shows
    if self.testModeActive then return end

    local settings = self:GetSettings()
    local trinketFrame = self.trinketFrame
    if not trinketFrame then return end
    if not self:GetModuleSettings().trackTrinkets then
        trinketFrame:Hide()
        return
    end

    local size = settings.iconSize or 36
    local spacing = settings.spacing or 4
    local anyVisible = false

    for i, slot in ipairs(TRINKET_SLOTS) do
        local tf = self.trinketIcons[i]
        if not tf then break end

        local itemId = GetInventoryItemID("player", slot)
        if itemId and GetItemSpell(itemId) then
            local icon = GetInventoryItemTexture("player", slot)
            local start, duration, enabled = GetInventoryItemCooldown("player", slot)

            tf.icon:SetTexture(icon)
            tf:SetSize(size, size)
            tf:ClearAllPoints()
            tf:SetPoint("RIGHT", trinketFrame, "RIGHT", -((i - 1) * (size + spacing)), 0)

            if duration and duration > 1.5 then
                tf.cooldown:SetCooldown(start, duration)
                tf.icon:SetDesaturated(true)
            else
                tf.cooldown:Clear()
                tf.icon:SetDesaturated(false)
            end

            tf:Show()
            anyVisible = true
        else
            tf:Hide()
        end
    end

    if anyVisible then
        trinketFrame:SetSize(size * 2 + spacing, size + 4)
        trinketFrame:Show()
    else
        trinketFrame:Hide()
    end
end

function CooldownGroup:Update()
    -- Don't override test mode display
    if self.testModeActive then return end

    local settings = self:GetSettings()
    local moduleSettings = self:GetModuleSettings()
    local frame = self.frame
    local cdFrames = self.icons
    local tracker = self.tracker
    if not moduleSettings.enabled or not frame then
        if frame then frame:Hide() end
        return
    end

    local spells = self:GetSpells() or {}

    -- Centred rows need to know how many icons will show before the first is placed
    local shownCount
    if settings.growDirection == "CENTER" then
        shownCount = 0
        for _, spell in ipairs(spells) do
            if spell.enabled ~= false and Castborn:IsSpellKnown(spell.spellId) then
                shownCount = shownCount + 1
            end
        end
        shownCount = math.min(shownCount, MAX_ICONS)
    end

    local visibleIndex = 0
    for i, spell in ipairs(spells) do
        -- Skip disabled spells
        if spell.enabled == false then
            -- do nothing
        -- Skip spells the player doesn't know
        elseif not Castborn:IsSpellKnown(spell.spellId) then
            -- Hide this frame if it was previously shown
            if cdFrames[i] then cdFrames[i]:Hide() end
        else
            visibleIndex = visibleIndex + 1
            local cdFrame = cdFrames[visibleIndex]
            if not cdFrame then break end

            local spellName = tracker:GetTrackedSpellName(spell)
            local onCooldown, isLong, start, duration = tracker:GetSpellCooldownState(spellName)
            local icon = GetSpellTexture(spellName)

            -- Size and position the frame based on visible index (compact layout with row
            -- wrapping), so a new icon size shows straight away
            local size = settings.iconSize or 36
            cdFrame:SetSize(size, size)
            self:PlaceAtSlot(cdFrame, visibleIndex, settings, shownCount)

            if icon then
                cdFrame.icon:SetTexture(icon)

                -- Create charges fontstring if it doesn't exist (for existing frames)
                if not cdFrame.charges then
                    cdFrame.charges = cdFrame:CreateFontString(nil, "OVERLAY", nil, 7)
                    cdFrame.charges:SetFont(Castborn:GetBarFont(), 24, "OUTLINE")
                    Castborn:RegisterFontString(cdFrame.charges, 24, "OUTLINE")
                    cdFrame.charges:SetPoint("CENTER", cdFrame.icon, "CENTER", 0, 0)
                    cdFrame.charges:SetTextColor(1, 0.82, 0, 1)  -- Yellow/gold colour
                end

                -- Check for charge-based buffs (Earth Shield, Water Shield)
                local charges = nil
                if UnitBuff and (spell.spellId == 974 or spell.spellId == 24398) then
                    -- Check if buff is active on player
                    for j = 1, 40 do
                        local name, _, count = UnitBuff("player", j)
                        if not name then break end
                        if name == spell.name then
                            charges = count
                            break
                        end
                    end
                end

                -- Display charges if available
                if charges and charges > 0 then
                    cdFrame.charges:SetText(charges)
                    cdFrame.charges:Show()
                else
                    cdFrame.charges:Hide()
                end

                if onCooldown then
                    tracker:SetIconCooldown(cdFrame.cooldown, spellName, start, duration)
                    cdFrame.icon:SetDesaturated(true)
                    cdFrame.glow:SetAlpha(0)
                    -- Remember a real cooldown (only if significant) so the ready glow can follow
                    if isLong then
                        self.lastCooldownDuration[spell.spellId] = true
                    end
                    -- Stop edge pulse when on cooldown
                    StopEdgePulse(cdFrame)
                else
                    cdFrame.cooldown:Clear()
                    cdFrame.icon:SetDesaturated(false)

                    -- Start edge pulse if enabled and was a real cooldown
                    if moduleSettings.showReadyGlow ~= false and self.lastCooldownDuration[spell.spellId] then
                        if not cdFrame.edgePulseActive then
                            StartEdgePulse(cdFrame)
                        end
                    end
                end

                cdFrame:Show()
            else
                cdFrame:Hide()
            end
        end  -- end of enabled/known check
    end

    -- Hide any remaining cooldown frames that aren't being used
    for i = visibleIndex + 1, MAX_ICONS do
        if cdFrames[i] then
            cdFrames[i]:Hide()
        end
    end

    -- Only show container if there are visible cooldowns
    if visibleIndex > 0 then
        frame:SetSize(CooldownGroup.GetContainerSize(visibleIndex, settings))
        frame:Show()
        if frame.dragIndicator and CastbornDB.locked ~= false then
            frame.dragIndicator:Hide()
        end
    else
        frame:Hide()
    end
end

--------------------------------------------------------------------------------
-- Test mode and drag-to-reorder
--------------------------------------------------------------------------------

-- Smooth animation for icon repositioning
function CooldownGroup:SmoothRepositionIcon(icon, targetSlot, settings)
    if not icon or not settings then return end
    local frame = self.frame

    local _, _, targetX, targetY = GetSlotAnchor(targetSlot, settings, nil, self.testSpellCount)
    icon.targetX = targetX
    icon.targetY = targetY

    if not icon.isAnimating then
        icon.isAnimating = true

        local animFrame = icon.animFrame or CreateFrame("Frame")
        icon.animFrame = animFrame

        animFrame:SetScript("OnUpdate", function(self, elapsed)
            if not icon or not icon:IsShown() then
                icon.isAnimating = false
                animFrame:SetScript("OnUpdate", nil)
                return
            end

            local currentX = select(4, icon:GetPoint()) or 0
            local currentY = select(5, icon:GetPoint()) or 0

            -- Lerp towards target (30% per frame)
            local newX = currentX + (icon.targetX - currentX) * 0.3
            local newY = currentY + (icon.targetY - currentY) * 0.3

            -- Snap if very close
            if math.abs(newX - icon.targetX) < 0.5 then
                newX = icon.targetX
                newY = icon.targetY
                icon.isAnimating = false
                animFrame:SetScript("OnUpdate", nil)
            end

            -- Apply position
            local point, relativePoint = GetSlotAnchor(1, settings)
            icon:ClearAllPoints()
            icon:SetPoint(point, frame, relativePoint, newX, newY)
        end)
    end
end

function CooldownGroup:RefreshTestIcons()
    local settings = self:GetSettings()
    local spells = self:GetSpells()

    -- Rebuild visible spell list from current spell order
    local testSpells = {}
    self.visibleToTrackIndex = {}
    for trackIdx, spell in ipairs(spells or {}) do
        if spell.enabled ~= false then
            -- In test mode, show all enabled spells regardless of whether known
            local icon = GetSpellTexture(spell.spellId) or GetSpellTexture(spell.name)

            -- If still no icon, try to get it from spell data
            if not icon and spell.spellId then
                -- For unknown spells, create a placeholder or use spell ID
                icon = "Interface\\Icons\\INV_Misc_QuestionMark"
            end

            if icon then
                table.insert(testSpells, { icon = icon, trackIdx = trackIdx })
                self.visibleToTrackIndex[#testSpells] = trackIdx
            end
            if #testSpells >= MAX_ICONS then break end
        end
    end

    -- Fallback if no spells configured
    if #testSpells == 0 then
        local fallbacks = {
            "Interface\\Icons\\Spell_Frost_FrostShock",
            "Interface\\Icons\\Spell_Fire_FlameBolt",
            "Interface\\Icons\\Spell_Nature_Lightning",
        }
        for i, icon in ipairs(fallbacks) do
            table.insert(testSpells, { icon = icon, trackIdx = nil })
        end
    end

    self.testSpellCount = #testSpells

    -- Fit the container to the test icons, as the live update does, so the drag area
    -- matches what is shown
    self.frame:SetSize(CooldownGroup.GetContainerSize(#testSpells, settings))

    local size = settings.iconSize or 36
    for i = 1, #testSpells do
        local cdFrame = self.icons[i]
        if cdFrame then
            self:PlaceAtSlot(cdFrame, i, settings, #testSpells)
            cdFrame:SetSize(size, size)
            cdFrame.icon:SetTexture(testSpells[i].icon)
            cdFrame.icon:SetDesaturated(i == 2)
            cdFrame.cooldown:Clear()

            -- Create charges fontstring if it doesn't exist (for existing frames)
            if not cdFrame.charges then
                cdFrame.charges = cdFrame:CreateFontString(nil, "OVERLAY", nil, 7)
                cdFrame.charges:SetFont(Castborn:GetBarFont(), 24, "OUTLINE")
                Castborn:RegisterFontString(cdFrame.charges, 24, "OUTLINE")
                cdFrame.charges:SetPoint("CENTER", cdFrame.icon, "CENTER", 0, 0)
                cdFrame.charges:SetTextColor(1, 0.82, 0, 1)  -- Yellow/gold colour
            end

            -- Show example charges for Earth Shield (974) and Water Shield (24398)
            if testSpells[i].trackIdx then
                local spell = spells[testSpells[i].trackIdx]
                if spell and (spell.spellId == 974 or spell.spellId == 24398) then
                    local exampleCharges = spell.spellId == 974 and 6 or 3
                    cdFrame.charges:SetText(exampleCharges)
                    cdFrame.charges:Show()
                else
                    cdFrame.charges:Hide()
                end
            else
                cdFrame.charges:Hide()
            end

            if i == 2 then
                cdFrame.cooldown:SetCooldown(GetTime() - 5, 30)
                StopEdgePulse(cdFrame)
            else
                if self:GetModuleSettings().showReadyGlow ~= false then
                    StartEdgePulse(cdFrame)
                end
            end
            cdFrame.visibleIndex = i
            cdFrame:Show()
        end
    end

    -- Hide remaining frames
    for i = #testSpells + 1, MAX_ICONS do
        if self.icons[i] then self.icons[i]:Hide() end
    end
end

function CooldownGroup:SetupDragReorder(cdFrame, visibleIndex)
    local group = self
    local settings = self:GetSettings()
    local frame = self.frame
    local cdFrames = self.icons
    local dragState = self.dragState
    cdFrame.visibleIndex = visibleIndex

    cdFrame:SetMovable(true)
    cdFrame:Enable()
    cdFrame:EnableMouse(true)
    cdFrame:RegisterForDrag("LeftButton")

    -- Ghost frame (translucent copy at original position)
    if not cdFrame.ghost then
        cdFrame.ghost = frame:CreateTexture(nil, "ARTWORK", nil, -1)
        cdFrame.ghost:SetSize(settings.iconSize or 36, settings.iconSize or 36)
        cdFrame.ghost:SetAlpha(0.3)
        cdFrame.ghost:SetDesaturated(true)
    end

    cdFrame:SetScript("OnDragStart", function(self)
        if not group.testModeActive then return end

        -- Store initial cursor and frame positions
        local scale = UIParent:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        self.dragStartCursorX = cursorX / scale
        self.dragStartCursorY = cursorY / scale

        -- Store offset from icon center to cursor
        local centerX, centerY = self:GetCenter()
        self.dragOffsetX = centerX - self.dragStartCursorX
        self.dragOffsetY = centerY - self.dragStartCursorY

        -- Setup ghost at original position
        local size = settings.iconSize or 36
        self.ghost:SetTexture(self.icon:GetTexture())
        group:PlaceAtSlot(self.ghost, self.visibleIndex, settings, group.testSpellCount)
        self.ghost:SetSize(size, size)
        self.ghost:Show()

        -- Visual enhancements for dragged icon
        self:SetFrameLevel(self:GetFrameLevel() + 10)
        self:SetScale(1.1)
        self:SetAlpha(1.0)  -- Keep fully opaque
        if self.dragShadow then
            self.dragShadow:Show()
        end
        if self.dragGlow then
            self.dragGlow:Show()
        end
        if self.dragCursor then
            self.dragCursor:Show()
        end

        -- Dim all other cooldown icons
        for i = 1, group.testSpellCount do
            if cdFrames[i] and cdFrames[i] ~= self and cdFrames[i]:IsShown() then
                cdFrames[i]:SetAlpha(0.4)
                cdFrames[i].icon:SetDesaturated(true)
            end
        end

        self.isDragging = true
        dragState.draggingIndex = self.visibleIndex
        dragState.currentTargetSlot = nil
    end)

    cdFrame:SetScript("OnDragStop", function(self)
        if not self.isDragging then return end
        self.isDragging = false

        -- Reset dragged icon appearance
        self:SetScale(1.0)
        self:SetAlpha(1.0)
        self:SetFrameLevel(self:GetFrameLevel() - 10)
        if self.dragShadow then
            self.dragShadow:Hide()
        end
        if self.dragGlow then
            self.dragGlow:Hide()
        end
        if self.dragCursor then
            self.dragCursor:Hide()
        end

        -- Restore all other cooldown icons
        for i = 1, group.testSpellCount do
            if cdFrames[i] and cdFrames[i] ~= self and cdFrames[i]:IsShown() then
                cdFrames[i]:SetAlpha(1.0)
                -- Only restore saturation if it was ready (not on cooldown)
                if i ~= 2 then  -- Frame 2 is the test cooldown frame
                    cdFrames[i].icon:SetDesaturated(false)
                end
            end
        end

        -- Hide all visual feedback
        if self.ghost then self.ghost:Hide() end
        if frame.insertMarker then frame.insertMarker:Hide() end
        if frame.insertMarkerGlow then frame.insertMarkerGlow:Hide() end
        if frame.slotHighlight then frame.slotHighlight:Hide() end

        -- Stop all animations and calculate final target slot
        local targetSlot = dragState.currentTargetSlot or self.visibleIndex
        targetSlot = math.max(1, math.min(targetSlot, group.testSpellCount))

        local fromSlot = self.visibleIndex
        local visibleToTrackIndex = group.visibleToTrackIndex
        if fromSlot ~= targetSlot and visibleToTrackIndex[fromSlot] and visibleToTrackIndex[targetSlot] then
            -- Move the spell in the spell list
            local spells = group:GetSpells()
            local fromTrack = visibleToTrackIndex[fromSlot]
            local toTrack = visibleToTrackIndex[targetSlot]
            local spell = table.remove(spells, fromTrack)

            -- Take the target spell's place, as the preview showed. Dragging forwards, the
            -- removal has already moved the target spell back one, so inserting at its old
            -- index puts the dragged spell just after it; dragging backwards, just before it.
            table.insert(spells, toTrack, spell)
        end

        -- Reset drag state
        dragState.draggingIndex = nil
        dragState.currentTargetSlot = nil

        -- Stop all animations
        for i = 1, group.testSpellCount do
            if cdFrames[i] and cdFrames[i].animFrame then
                cdFrames[i].animFrame:SetScript("OnUpdate", nil)
                cdFrames[i].isAnimating = false
            end
        end

        -- Refresh all icons to reflect new order
        group:RefreshTestIcons()

        -- Re-setup drag handlers with updated indices
        for i = 1, group.testSpellCount do
            if cdFrames[i] and cdFrames[i]:IsShown() then
                group:SetupDragReorder(cdFrames[i], i)
            end
        end
    end)

    cdFrame:SetScript("OnUpdate", function(self, elapsed)
        if not self.isDragging then return end

        -- Update icon position to follow cursor
        local scale = UIParent:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        cursorX = cursorX / scale
        cursorY = cursorY / scale

        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            cursorX + self.dragOffsetX,
            cursorY + self.dragOffsetY)

        -- Calculate target slot from cursor position
        local size = settings.iconSize or 36

        local frameLeft = frame:GetLeft()
        local frameRight = frame:GetRight()
        local frameTop = frame:GetTop()
        local frameBottom = frame:GetBottom()
        if not frameLeft or not frameRight or not frameTop or not frameBottom then return end

        local targetSlot = CooldownGroup.GetSlotAtPoint(settings, cursorX, cursorY,
            frameLeft, frameRight, frameTop, frameBottom, group.testSpellCount)
        targetSlot = math.max(1, math.min(targetSlot, group.testSpellCount))

        -- Only update if target slot changed
        if targetSlot ~= dragState.currentTargetSlot then
            dragState.currentTargetSlot = targetSlot

            -- Reposition other icons to show where dragged icon will fit
            for i = 1, group.testSpellCount do
                local icon = cdFrames[i]
                if i ~= self.visibleIndex and icon and icon:IsShown() then
                    local displaySlot = i

                    -- Calculate where this icon should be in the new layout
                    if self.visibleIndex < i and i <= targetSlot then
                        displaySlot = i - 1
                    elseif self.visibleIndex > i and i >= targetSlot then
                        displaySlot = i + 1
                    end

                    -- Smoothly move to new position
                    group:SmoothRepositionIcon(icon, displaySlot, settings)
                end
            end

            -- Update insertion marker: 4px wide, straddling the slot's leading edge (its
            -- right edge when growing left, its left edge otherwise)
            if frame.insertMarker then
                frame.insertMarker:ClearAllPoints()
                frame.insertMarker:SetSize(4, size)

                local point, relativePoint, markerX, markerY =
                    GetSlotAnchor(targetSlot, settings, nil, group.testSpellCount)
                if point == "TOPRIGHT" then
                    markerX = markerX + 2
                elseif point == "TOP" then
                    -- Centred icons are anchored by their top middle; the marker is too
                    markerX = markerX - size / 2
                else
                    markerX = markerX - 2
                end
                frame.insertMarker:SetPoint(point, frame, relativePoint, markerX, markerY)
                frame.insertMarker:Show()

                if frame.insertMarkerGlow then
                    frame.insertMarkerGlow:ClearAllPoints()
                    frame.insertMarkerGlow:SetSize(8, size)
                    frame.insertMarkerGlow:SetPoint("CENTER", frame.insertMarker, "CENTER", 0, 0)
                    frame.insertMarkerGlow:Show()
                end
            end

            -- Update slot highlight
            if frame.slotHighlight then
                frame.slotHighlight:SetSize(size, size)
                group:PlaceAtSlot(frame.slotHighlight, targetSlot, settings, group.testSpellCount)
                frame.slotHighlight:Show()
            end
        end
    end)
end

function CooldownGroup:StartTest()
    local settings = self:GetSettings()
    local frame = self.frame
    if not frame then return end

    self.testModeActive = true
    frame:Show()

    -- Refresh icons from current spell order
    self:RefreshTestIcons()

    -- Setup drag reorder on each visible icon
    for i = 1, self.testSpellCount do
        if self.icons[i] and self.icons[i]:IsShown() then
            self:SetupDragReorder(self.icons[i], i)
        end
    end

    -- Show sample trinket icons in test mode
    local trinketFrame = self.trinketFrame
    if self:GetModuleSettings().trackTrinkets and trinketFrame then
        local size = settings.iconSize or 36
        local spacing = settings.spacing or 4
        local testTrinketIcons = {
            "Interface\\Icons\\INV_Trinket_Naxxramas04",
            "Interface\\Icons\\INV_Trinket_Naxxramas03",
        }
        for i = 1, 2 do
            local tf = self.trinketIcons[i]
            if tf then
                tf.icon:SetTexture(testTrinketIcons[i])
                tf:SetSize(size, size)
                tf:ClearAllPoints()
                tf:SetPoint("RIGHT", trinketFrame, "RIGHT", -((i - 1) * (size + spacing)), 0)
                tf.cooldown:Clear()
                tf.icon:SetDesaturated(i == 1)
                if i == 1 then
                    tf.cooldown:SetCooldown(GetTime() - 10, 120)
                end
                tf:Show()
            end
        end
        trinketFrame:SetSize(size * 2 + spacing, size + 4)
        trinketFrame:Show()
    end
end

function CooldownGroup:EndTest()
    self.testModeActive = false
    local frame = self.frame
    if frame then
        -- Clean up drag state and visual markers
        if frame.insertMarker then frame.insertMarker:Hide() end
        if frame.insertMarkerGlow then frame.insertMarkerGlow:Hide() end
        if frame.slotHighlight then frame.slotHighlight:Hide() end

        for i = 1, MAX_ICONS do
            local f = self.icons[i]
            if f then
                StopEdgePulse(f)
                f:Disable()
                f:EnableMouse(false)
                f:SetScript("OnDragStart", nil)
                f:SetScript("OnDragStop", nil)
                f:SetScript("OnUpdate", nil)
                f.isDragging = false
                f:SetAlpha(1.0)
                f:SetScale(1.0)
                if f.ghost then f.ghost:Hide() end
                if f.dragShadow then f.dragShadow:Hide() end
                if f.dragGlow then f.dragGlow:Hide() end
                if f.dragCursor then f.dragCursor:Hide() end
                if f.charges then f.charges:Hide() end
                if f.animFrame then
                    f.animFrame:SetScript("OnUpdate", nil)
                    f.isAnimating = false
                end
                f:Hide()
            end
        end
        frame:Hide()
    end
    -- Hide trinket test frames
    if self.trinketFrame then
        for i = 1, 2 do
            if self.trinketIcons[i] then self.trinketIcons[i]:Hide() end
        end
        self.trinketFrame:Hide()
    end
    self.visibleToTrackIndex = {}
    self.testSpellCount = 0
    self.dragState.draggingIndex = nil
    self.dragState.currentTargetSlot = nil
end

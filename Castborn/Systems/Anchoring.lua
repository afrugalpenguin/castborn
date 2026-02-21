-- Systems/Anchoring.lua
local Anchoring = {}
Castborn.Anchoring = Anchoring

-- Store anchor relationships
Anchoring.anchors = {}

-- Convert pixel offset to percentage of screen
function Anchoring:PixelToPercent(x, y)
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    return x / screenWidth, y / screenHeight
end

-- Convert percentage to pixel offset
function Anchoring:PercentToPixel(xPct, yPct)
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    return xPct * screenWidth, yPct * screenHeight
end

-- Apply position from database (handles both legacy pixels and percentages)
function Anchoring:ApplyPosition(frame, db)
    if not frame or not db then return end

    local x, y
    -- Use percentages if available, otherwise fall back to pixels
    if db.xPct ~= nil and db.yPct ~= nil then
        x, y = self:PercentToPixel(db.xPct, db.yPct)
    else
        x, y = db.x or 0, db.y or 0
    end

    frame:ClearAllPoints()
    frame:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", x, y)
end

-- Save position to database as percentage
function Anchoring:SavePosition(db, point, x, y)
    db.point = point
    db.x = x  -- Keep pixels for backwards compatibility
    db.y = y
    db.xPct, db.yPct = self:PixelToPercent(x, y)
end

-- Migrate legacy pixel positions to percentages
function Anchoring:MigratePosition(db)
    if db and db.x ~= nil and db.y ~= nil and db.xPct == nil then
        db.xPct, db.yPct = self:PixelToPercent(db.x, db.y)
    end
end

-- Anchor positions
Anchoring.POSITIONS = {
    TOP = { point = "BOTTOM", relPoint = "TOP", xOff = 0, yOff = 2 },
    BOTTOM = { point = "TOP", relPoint = "BOTTOM", xOff = 0, yOff = -2 },
    LEFT = { point = "RIGHT", relPoint = "LEFT", xOff = -2, yOff = 0 },
    RIGHT = { point = "LEFT", relPoint = "RIGHT", xOff = 2, yOff = 0 },
}

-- Anchor a frame to a parent
function Anchoring:Anchor(frame, parent, position, offsetX, offsetY)
    if not frame or not parent then return end

    local pos = self.POSITIONS[position] or self.POSITIONS.BOTTOM
    offsetX = offsetX or pos.xOff
    offsetY = offsetY or pos.yOff

    frame:ClearAllPoints()
    frame:SetPoint(pos.point, parent, pos.relPoint, offsetX, offsetY)

    -- Store relationship
    self.anchors[frame] = {
        parent = parent,
        position = position,
        offsetX = offsetX,
        offsetY = offsetY,
    }

    -- Mark as anchored
    frame.isAnchored = true
    frame.anchorParent = parent
end

-- Detach a frame (make it free-floating)
function Anchoring:Detach(frame, db)
    if not frame then return end

    frame:ClearAllPoints()
    self:ApplyPosition(frame, db)

    -- Remove relationship
    self.anchors[frame] = nil
    frame.isAnchored = false
    frame.anchorParent = nil
end

-- Check if frame is anchored
function Anchoring:IsAnchored(frame)
    return frame and frame.isAnchored
end

-- Get anchor info
function Anchoring:GetAnchorInfo(frame)
    return self.anchors[frame]
end

-- Re-anchor a previously detached frame
function Anchoring:Reanchor(frame)
    local info = self.anchors[frame]
    if info then
        self:Anchor(frame, info.parent, info.position, info.offsetX, info.offsetY)
    end
end

Anchoring.CASTBAR_INDENT = 5

function Anchoring:ReattachToCastbar(frame, db, position, offsetY, widthSyncFn)
    if not frame then return false end

    -- Find the player castbar
    local castbar = Castborn.castbars and Castborn.castbars.player
    if not castbar then return false end

    -- Update database
    db.anchored = true

    -- Anchor to the bar element (not the frame which includes icon)
    local anchorTarget = castbar.bar or castbar
    self:Anchor(frame, anchorTarget, position, 0, offsetY)

    -- Sync width if callback provided
    if widthSyncFn then
        widthSyncFn()
    elseif castbar.bar then
        -- Default: match castbar width with standard indent
        frame:SetWidth(castbar.bar:GetWidth() - (self.CASTBAR_INDENT * 2))
    end

    return true
end

function Anchoring:DetachFromCastbar(frame, db)
    if not frame then return end
    db.anchored = false
    self:Detach(frame, db)
end

function Anchoring:GetCastbarBarWidth()
    local castbar = Castborn.castbars and Castborn.castbars.player
    if castbar and castbar.bar then
        return castbar.bar:GetWidth() - (self.CASTBAR_INDENT * 2)
    end
    return nil
end

-- Create a drag indicator overlay for a frame
-- The indicator is positioned above the frame so it doesn't cover content
local function CreateDragIndicator(frame, label)
    local indicator = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    -- Position above the frame, centred, with a minimum width to fit the label
    indicator:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    indicator:SetHeight(14)
    indicator:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    indicator:SetBackdropColor(0.2, 0.6, 1.0, 0.8)
    indicator:SetBackdropBorderColor(0.2, 0.6, 1.0, 1)
    indicator:SetFrameStrata("DIALOG")

    local text = indicator:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetText(label or "Drag")
    text:SetTextColor(1, 1, 1, 1)

    -- Size to fit the label text or the frame width, whichever is larger
    local textWidth = text:GetStringWidth() + 12
    local minWidth = math.max(frame:GetWidth(), textWidth)
    indicator:SetWidth(minWidth)

    -- Make the indicator handle dragging (so it works over child frames with EnableMouse)
    indicator:EnableMouse(true)
    indicator:RegisterForDrag("LeftButton")
    indicator:SetScript("OnDragStart", function(self)
        if not CastbornDB.locked then
            frame:StartMoving()
        end
    end)
    indicator:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        -- Trigger the parent's OnDragStop to save position
        if frame:GetScript("OnDragStop") then
            frame:GetScript("OnDragStop")(frame)
        end
    end)

    -- Ctrl+Shift+Click to temporarily hide this frame while unlocked
    indicator:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsControlKeyDown() and IsShiftKeyDown() then
            frame:Hide()
            self:Hide()
            frame.hiddenForPositioning = true
        end
    end)

    indicator:Hide()
    frame.dragIndicator = indicator
    return indicator
end

-- Track all draggable frames for lock/unlock
Anchoring.draggableFrames = {}

-- Make a frame draggable (when unlocked)
-- label: optional display name for the drag indicator
function Anchoring:MakeDraggable(frame, db, onDragStop, label)
    frame:SetMovable(true)
    frame:EnableMouse(false)

    -- Create drag indicator with label
    CreateDragIndicator(frame, label)

    -- Store drag callbacks so we can set/clear them on unlock/lock
    frame._dragStartFunc = function(self)
        if not CastbornDB.locked then
            if self.isAnchored then
                Anchoring:Detach(self, db)
            end
            self:StartMoving()
        end
    end
    frame._dragStopFunc = function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()

        if CastbornDB.snapToGrid and Castborn.GridPosition then
            x, y = Castborn.GridPosition:SnapToGrid(x, y)
            self:ClearAllPoints()
            self:SetPoint(point, UIParent, point, x, y)
        end

        Anchoring:SavePosition(db, point, x, y)
        db.anchored = false

        if onDragStop then
            onDragStop(self)
        end
    end

    -- Track this frame
    table.insert(self.draggableFrames, frame)

    -- Starts click-through; drag scripts set on unlock via ShowDragIndicators()
end

-- Show drag indicators on all draggable frames
-- If forceShowFrames is true, also show the frames themselves (for unlock mode)
function Anchoring:ShowDragIndicators(forceShowFrames)
    for _, frame in ipairs(self.draggableFrames) do
        -- Enable mouse interaction for dragging
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        if frame._dragStartFunc then
            frame:SetScript("OnDragStart", frame._dragStartFunc)
            frame:SetScript("OnDragStop", frame._dragStopFunc)
        end
        if frame.dragIndicator then
            -- Restore frames that were Ctrl+Shift hidden in a previous unlock
            if frame.hiddenForPositioning then
                frame:Show()
                frame.hiddenForPositioning = nil
                frame.shownForPositioning = true
            end
            if forceShowFrames and not frame:IsShown() then
                -- Show the frame itself so it can be repositioned
                frame:Show()
                frame.shownForPositioning = true
            end
            if frame:IsShown() then
                frame.dragIndicator:Show()
            end
        end
    end
end

-- Hide drag indicators on all draggable frames
-- If hideFrames is true, also hide frames that were shown for positioning
function Anchoring:HideDragIndicators(hideFrames)
    for _, frame in ipairs(self.draggableFrames) do
        -- Fully disable mouse interaction for click-through
        frame:EnableMouse(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        if frame.dragIndicator then
            frame.dragIndicator:Hide()
        end
        -- Restore frames that were Ctrl+Shift hidden during this unlock
        if frame.hiddenForPositioning then
            frame:Show()
            frame.hiddenForPositioning = nil
            frame.shownForPositioning = true
        end
        if hideFrames and frame.shownForPositioning then
            frame:Hide()
            frame.shownForPositioning = nil
        end
    end
end

Castborn:RegisterCallback("INIT", function()
    -- Always start locked on reload
    CastbornDB.locked = true
end)

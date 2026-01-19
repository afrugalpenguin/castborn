-- Systems/GridPosition.lua
local GridPosition = {}
Castborn.GridPosition = GridPosition

GridPosition.gridFrame = nil
GridPosition.isActive = false
GridPosition.gridSize = 16
GridPosition.showRulers = true

function GridPosition:CreateGrid()
    if self.gridFrame then return self.gridFrame end

    local frame = CreateFrame("Frame", "CastbornGridOverlay", UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(0)
    frame:EnableMouse(false)
    frame:Hide()

    frame.lines = {}
    frame.markers = {}
    self.gridFrame = frame

    return frame
end

function GridPosition:DrawGrid(size)
    local frame = self:CreateGrid()

    -- Clear existing elements
    for _, line in ipairs(frame.lines) do
        line:Hide()
    end
    for _, marker in ipairs(frame.markers) do
        marker:Hide()
    end
    frame.lines = {}
    frame.markers = {}

    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2

    -- Minor grid lines (subtle)
    local minorAlpha = 0.15
    local minorColor = {0.5, 0.7, 1}

    -- Vertical minor lines
    for x = centerX, screenWidth, size do
        self:CreateLine(frame, x, 0, x, screenHeight, minorAlpha, minorColor)
    end
    for x = centerX - size, 0, -size do
        self:CreateLine(frame, x, 0, x, screenHeight, minorAlpha, minorColor)
    end

    -- Horizontal minor lines
    for y = centerY, screenHeight, size do
        self:CreateLine(frame, 0, y, screenWidth, y, minorAlpha, minorColor)
    end
    for y = centerY - size, 0, -size do
        self:CreateLine(frame, 0, y, screenWidth, y, minorAlpha, minorColor)
    end

    -- Major grid lines (every 4th line, brighter)
    local majorSize = size * 4
    local majorAlpha = 0.3
    local majorColor = {0.4, 0.6, 1}

    for x = centerX + majorSize, screenWidth, majorSize do
        self:CreateLine(frame, x, 0, x, screenHeight, majorAlpha, majorColor)
    end
    for x = centerX - majorSize, 0, -majorSize do
        self:CreateLine(frame, x, 0, x, screenHeight, majorAlpha, majorColor)
    end
    for y = centerY + majorSize, screenHeight, majorSize do
        self:CreateLine(frame, 0, y, screenWidth, y, majorAlpha, majorColor)
    end
    for y = centerY - majorSize, 0, -majorSize do
        self:CreateLine(frame, 0, y, screenWidth, y, majorAlpha, majorColor)
    end

    -- Center crosshair (bright, thicker)
    self:CreateLine(frame, centerX, 0, centerX, screenHeight, 0.6, {1, 0.8, 0.2}, 2)
    self:CreateLine(frame, 0, centerY, screenWidth, centerY, 0.6, {1, 0.8, 0.2}, 2)

    -- Center marker circle
    self:CreateCenterMarker(frame, centerX, centerY)

    -- Quadrant labels
    if self.showRulers then
        self:CreateQuadrantLabels(frame, centerX, centerY)
    end
end

function GridPosition:CreateLine(frame, x1, y1, x2, y2, alpha, color, thickness)
    local line = frame:CreateTexture(nil, "ARTWORK")
    color = color or {1, 1, 1}
    thickness = thickness or 1
    line:SetColorTexture(color[1], color[2], color[3], alpha)

    if x1 == x2 then
        -- Vertical line
        line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x1 - thickness/2, y1)
        line:SetSize(thickness, y2 - y1)
    else
        -- Horizontal line
        line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x1, y1 - thickness/2)
        line:SetSize(x2 - x1, thickness)
    end

    table.insert(frame.lines, line)
    return line
end

function GridPosition:CreateCenterMarker(frame, x, y)
    -- Outer ring
    local outer = frame:CreateTexture(nil, "OVERLAY")
    outer:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    outer:SetSize(24, 24)
    outer:SetPoint("CENTER", frame, "BOTTOMLEFT", x, y)
    outer:SetVertexColor(1, 0.8, 0.2, 0.5)
    table.insert(frame.markers, outer)

    -- Center dot
    local dot = frame:CreateTexture(nil, "OVERLAY")
    dot:SetColorTexture(1, 0.8, 0.2, 0.8)
    dot:SetSize(6, 6)
    dot:SetPoint("CENTER", frame, "BOTTOMLEFT", x, y)
    table.insert(frame.markers, dot)
end

function GridPosition:CreateQuadrantLabels(frame, centerX, centerY)
    local labels = {
        {x = centerX + 100, y = centerY + 50, text = "+X +Y"},
        {x = centerX - 100, y = centerY + 50, text = "-X +Y"},
        {x = centerX + 100, y = centerY - 50, text = "+X -Y"},
        {x = centerX - 100, y = centerY - 50, text = "-X -Y"},
    }

    for _, l in ipairs(labels) do
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", frame, "BOTTOMLEFT", l.x, l.y)
        label:SetText(l.text)
        label:SetTextColor(0.5, 0.7, 1, 0.4)
        table.insert(frame.markers, label)
    end

    -- Distance markers along center lines
    local markerInterval = self.gridSize * 4
    for dist = markerInterval, centerX, markerInterval do
        -- Right
        local r = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r:SetPoint("TOP", frame, "BOTTOMLEFT", centerX + dist, centerY - 4)
        r:SetText(tostring(math.floor(dist)))
        r:SetTextColor(0.6, 0.6, 0.6, 0.6)
        table.insert(frame.markers, r)
        -- Left
        local l = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l:SetPoint("TOP", frame, "BOTTOMLEFT", centerX - dist, centerY - 4)
        l:SetText(tostring(-math.floor(dist)))
        l:SetTextColor(0.6, 0.6, 0.6, 0.6)
        table.insert(frame.markers, l)
    end
    for dist = markerInterval, centerY, markerInterval do
        -- Up
        local u = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        u:SetPoint("LEFT", frame, "BOTTOMLEFT", centerX + 4, centerY + dist)
        u:SetText(tostring(math.floor(dist)))
        u:SetTextColor(0.6, 0.6, 0.6, 0.6)
        table.insert(frame.markers, u)
        -- Down
        local d = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        d:SetPoint("LEFT", frame, "BOTTOMLEFT", centerX + 4, centerY - dist)
        d:SetText(tostring(-math.floor(dist)))
        d:SetTextColor(0.6, 0.6, 0.6, 0.6)
        table.insert(frame.markers, d)
    end
end

-- Show grid only (doesn't affect locked state)
function GridPosition:ShowGrid(gridSize)
    self.gridSize = gridSize or self.gridSize
    self:DrawGrid(self.gridSize)
    self.gridFrame:Show()
    self.isActive = true

    self:CreateControlPanel()
    self.controlPanel:Show()

    Castborn:FireCallback("POSITIONING_MODE_ENTERED")
end

-- Hide grid only (doesn't affect locked state)
function GridPosition:HideGrid()
    if self.gridFrame then
        self.gridFrame:Hide()
    end
    self.isActive = false

    if self.controlPanel then
        self.controlPanel:Hide()
    end

    Castborn:FireCallback("POSITIONING_MODE_EXITED")
end

-- Toggle grid visibility only (doesn't affect locked state)
function GridPosition:ToggleGrid()
    if self.isActive then
        self:HideGrid()
    else
        self:ShowGrid()
    end
end

-- Full positioning mode: unlocks frames AND shows grid (for /cb grid command)
function GridPosition:EnterPositioningMode(gridSize)
    CastbornDB.locked = false

    -- Show drag indicators on all frames
    if Castborn.Anchoring then
        Castborn.Anchoring:ShowDragIndicators()
    end

    self:ShowGrid(gridSize)
    Castborn:Print("Grid mode enabled. Drag frames to position. |cff88ddff/cb grid|r to exit.")
end

-- Exit full positioning mode: hides grid AND locks frames (for /cb grid command)
function GridPosition:ExitPositioningMode()
    self:HideGrid()

    CastbornDB.locked = true

    -- Hide drag indicators
    if Castborn.Anchoring then
        Castborn.Anchoring:HideDragIndicators()
    end

    Castborn:Print("Grid mode disabled. Frames locked.")
end

-- Toggle full positioning mode (for /cb grid command)
function GridPosition:TogglePositioningMode()
    if self.isActive then
        self:ExitPositioningMode()
    else
        self:EnterPositioningMode()
    end
end

function GridPosition:SetGridSize(size)
    self.gridSize = size
    CastbornDB.gridSize = size
    if self.isActive then
        self:DrawGrid(size)
    end
end

function GridPosition:CreateControlPanel()
    if self.controlPanel then return end

    local panel = CreateFrame("Frame", "CastbornGridControlPanel", UIParent, "BackdropTemplate")
    panel:SetSize(200, 160)
    panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -100)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    panel:SetBackdropColor(0.1, 0.1, 0.15, 0.95)
    panel:SetBackdropBorderColor(0.3, 0.5, 0.8, 1)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText("|cff88ddffGrid Positioning|r")

    -- Grid size label
    local sizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", 12, -30)
    sizeLabel:SetText("Grid Size:")

    -- Grid size slider
    local slider = CreateFrame("Slider", "CastbornGridSizeSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 12, -48)
    slider:SetSize(176, 16)
    slider:SetMinMaxValues(4, 64)
    slider:SetValueStep(4)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(self.gridSize)
    slider.Low:SetText("4")
    slider.High:SetText("64")
    slider.Text:SetText(self.gridSize .. "px")

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 4 + 0.5) * 4
        self.Text:SetText(value .. "px")
        GridPosition:SetGridSize(value)
    end)

    -- Snap to grid checkbox (positioned below slider with room for slider labels)
    local snap = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    snap:SetSize(24, 24)
    snap:SetPoint("TOPLEFT", 8, -78)
    snap:SetChecked(CastbornDB.snapToGrid ~= false)
    local snapText = snap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    snapText:SetPoint("LEFT", snap, "RIGHT", 2, 0)
    snapText:SetText("Snap to Grid")
    snap:SetScript("OnClick", function(self)
        CastbornDB.snapToGrid = self:GetChecked()
    end)

    -- Coordinate display (below checkbox)
    panel.coords = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.coords:SetPoint("TOPLEFT", 12, -108)
    panel.coords:SetText("Drag a frame...")

    -- Done button
    local doneBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    doneBtn:SetSize(80, 22)
    doneBtn:SetPoint("BOTTOM", 0, 12)
    doneBtn:SetText("Done")
    doneBtn:SetScript("OnClick", function()
        GridPosition:ExitPositioningMode()
    end)

    panel:SetScript("OnUpdate", function(self)
        if GridPosition.draggingFrame then
            local _, _, _, x, y = GridPosition.draggingFrame:GetPoint()
            self.coords:SetText(string.format("|cffaaaaaaPos:|r X: |cffffffff%d|r  Y: |cffffffff%d|r", math.floor(x or 0), math.floor(y or 0)))
        end
    end)

    panel:Hide()
    self.controlPanel = panel
end

function GridPosition:SnapToGrid(x, y)
    if not CastbornDB.snapToGrid then return x, y end

    local size = self.gridSize
    return math.floor(x / size + 0.5) * size, math.floor(y / size + 0.5) * size
end

function GridPosition:SetDragging(frame)
    self.draggingFrame = frame
end

function GridPosition:ClearDragging()
    self.draggingFrame = nil
end

Castborn:RegisterCallback("INIT", function()
    CastbornDB.snapToGrid = CastbornDB.snapToGrid ~= false
    CastbornDB.gridSize = CastbornDB.gridSize or 16
    GridPosition.gridSize = CastbornDB.gridSize
end)

Castborn:RegisterModule("GridPosition", GridPosition)

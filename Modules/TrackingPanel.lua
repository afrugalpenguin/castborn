--[[
    Castborn - Tracking Panel
    A floating window with one row per tracked item: XP and the watched reputation.
    Replaces Blizzard's XP and reputation bars, which it hides while enabled.
    Every read and every piece of maths on XP and reputation values is a named seam
    (ReadXP, ReadWatchedFaction, ShouldShowXP, BuildXPRow, BuildReputationRow), and the
    Blizzard frames to hide come from GetBlizzardBars; TrackingPanel_Forever.lua overrides
    only what differs on Forever.
]]

local TrackingPanel = {}
Castborn.TrackingPanel = TrackingPanel

local CB = Castborn

-- Defaults live in CB.defaults.tracking (Core.lua), so Reset Positions can find them
local defaults = CB.defaults.tracking
TrackingPanel.defaults = defaults

TrackingPanel.EVENTS = {
    "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
}

-- Events the client rejected
TrackingPanel.skippedEvents = {}

TrackingPanel.testModeActive = false
-- Set when a Blizzard bar change was asked for in combat; applied on PLAYER_REGEN_ENABLED
TrackingPanel.pendingBlizzardBars = false
-- Blizzard frames currently hidden, each mapped to what is needed to put it back
TrackingPanel.hiddenBars = {}

-- Used when the client has no FACTION_STANDING_LABEL<n> globals
TrackingPanel.standingLabels = {
    "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted",
}

-- Blizzard's standing colours, used when the client has no FACTION_BAR_COLORS
TrackingPanel.fallbackStandingColors = {
    [1] = { r = 0.8, g = 0.3, b = 0.22 },
    [2] = { r = 0.8, g = 0.3, b = 0.22 },
    [3] = { r = 0.75, g = 0.27, b = 0 },
    [4] = { r = 0.9, g = 0.7, b = 0 },
    [5] = { r = 0, g = 0.6, b = 0.1 },
    [6] = { r = 0, g = 0.6, b = 0.1 },
    [7] = { r = 0, g = 0.6, b = 0.1 },
    [8] = { r = 0, g = 0.6, b = 0.1 },
}

local EXALTED = 8
local XP_COLOR = { 0.58, 0, 0.55 }
local RESTED_ALPHA = 0.35
local DETAIL_COLOR = { 0.6, 0.6, 0.6 }

local HEADER_HEIGHT = 16
local PADDING = 4
local ROW_GAP = 6
local LINE_GAP = 2

-- Sample values for test mode: level 42 at 58.7% with rested to 80%, Darkspear Raiders Honored 60.8%
local SAMPLE_XP = { level = 42, current = 58700, max = 100000, rested = 21300, maxLevel = 70, disabled = false }
local SAMPLE_REPUTATION = { name = "Darkspear Raiders", reaction = 6, min = 9000, max = 21000, value = 16296 }

local function GetDB()
    return CB.db and CB.db.tracking
end

--------------------------------------------------------------------------------
-- Text and colours
--------------------------------------------------------------------------------

-- 41300 -> "41,300"
function TrackingPanel:FormatNumber(n)
    local s = tostring(math.floor(n + 0.5))
    local sign, digits = s:match("^(-?)(%d+)$")
    if not digits then return s end
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. grouped
end

function TrackingPanel:StandingLabel(reaction)
    return _G["FACTION_STANDING_LABEL" .. tostring(reaction)] or self.standingLabels[reaction] or "Unknown"
end

function TrackingPanel:StandingColor(reaction)
    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if not c then c = self.fallbackStandingColors[reaction] or self.fallbackStandingColors[4] end
    return c.r, c.g, c.b
end

local function Hex(v)
    return math.floor(v * 255 + 0.5)
end

--------------------------------------------------------------------------------
-- Seams over XP and reputation values (TBC behaviour; Forever overrides some)
--------------------------------------------------------------------------------

function TrackingPanel:ReadXP()
    return {
        level = UnitLevel("player"),
        current = UnitXP("player"),
        max = UnitXPMax("player"),
        rested = GetXPExhaustion and GetXPExhaustion() or 0,
        maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or MAX_PLAYER_LEVEL,
        disabled = IsXPUserDisabled and IsXPUserDisabled() or false,
    }
end

-- min and max are the standing's bounds, value the faction's standing; all absolute
function TrackingPanel:ReadWatchedFaction()
    if not GetWatchedFactionInfo then return nil end
    local name, reaction, min, max, value = GetWatchedFactionInfo()
    if not name then return nil end
    return { name = name, reaction = reaction, min = min, max = max, value = value }
end

function TrackingPanel:ShouldShowXP(xp)
    if xp.disabled then return false end
    if xp.maxLevel and xp.level >= xp.maxLevel then return false end
    return true
end

-- A row is the texts, the bar range (0 to max) and fills, and colours
function TrackingPanel:BuildXPRow(xp)
    local current, max = xp.current or 0, xp.max or 0
    local percent = max > 0 and current * 100 / max or 0
    local rested = xp.rested or 0
    local barMax = max > 0 and max or 1
    return {
        name = "Level " .. tostring(xp.level),
        value = string.format("%.1f%% (%s to go)", percent, self:FormatNumber(math.max(0, max - current))),
        detail = rested > 0 and ("Rested " .. self:FormatNumber(rested)) or nil,
        max = barMax,
        fill = current,
        rested = math.min(current + rested, barMax),
        color = { XP_COLOR[1], XP_COLOR[2], XP_COLOR[3] },
    }
end

function TrackingPanel:BuildReputationRow(rep)
    local range = rep.max - rep.min
    local percent = range > 0 and (rep.value - rep.min) * 100 / range or 100
    local r, g, b = self:StandingColor(rep.reaction)
    local detail
    if range > 0 and rep.reaction < EXALTED then
        detail = self:FormatNumber(rep.max - rep.value) .. " to " .. self:StandingLabel(rep.reaction + 1)
    end
    return {
        name = rep.name,
        value = string.format("|cff%02x%02x%02x%s|r %.1f%%", Hex(r), Hex(g), Hex(b),
            self:StandingLabel(rep.reaction), percent),
        detail = detail,
        max = range > 0 and range or 1,
        fill = range > 0 and (rep.value - rep.min) or 1,
        color = { r, g, b },
    }
end

-- The Blizzard frames the panel replaces. mode "reparent" moves the frame to a hidden parent;
-- "alpha" fades it and turns its mouse off, for frames where reparenting risks taint.
-- ExhaustionTick is a child of MainMenuExpBar and goes with it.
function TrackingPanel:GetBlizzardBars()
    return {
        { name = "MainMenuExpBar", mode = "reparent" },
        { name = "ReputationWatchBar", mode = "reparent" },
        { name = "MainMenuBarMaxLevelBar", mode = "reparent" },
    }
end

--------------------------------------------------------------------------------
-- Rows and visibility
--------------------------------------------------------------------------------

function TrackingPanel:CollectRows(db)
    if self.testModeActive then
        return { self:BuildXPRow(SAMPLE_XP), self:BuildReputationRow(SAMPLE_REPUTATION) }
    end
    local rows = {}
    if db.showXP then
        local xp = self:ReadXP()
        if xp and self:ShouldShowXP(xp) then rows[#rows + 1] = self:BuildXPRow(xp) end
    end
    if db.showReputation then
        local rep = self:ReadWatchedFaction()
        if rep then rows[#rows + 1] = self:BuildReputationRow(rep) end
    end
    return rows
end

-- Shown when enabled and something is tracked, or always in test mode
function TrackingPanel:GetVisibility(db, rowCount)
    if not db or not db.enabled then return false end
    if self.testModeActive then return true end
    return rowCount > 0
end

--------------------------------------------------------------------------------
-- Blizzard bars
--------------------------------------------------------------------------------

-- Hidden parent for reparented Blizzard frames
TrackingPanel.hider = CreateFrame("Frame")
TrackingPanel.hider:Hide()

-- Depends only on settings, never on test mode
function TrackingPanel:ShouldHideBlizzardBars(db)
    return db and db.enabled and db.hideBlizzardBars and true or false
end

function TrackingPanel:HideBlizzardBars()
    for _, entry in ipairs(self:GetBlizzardBars()) do
        local frame = _G[entry.name]
        if frame and not self.hiddenBars[frame] then
            local saved = { mode = entry.mode }
            if entry.mode == "alpha" then
                saved.alpha = frame:GetAlpha()
                saved.mouse = frame:IsMouseEnabled()
                frame:SetAlpha(0)
                frame:EnableMouse(false)
            else
                saved.parent = frame:GetParent()
                saved.points = {}
                for i = 1, frame:GetNumPoints() do
                    saved.points[i] = { frame:GetPoint(i) }
                end
                frame:SetParent(self.hider)
            end
            self.hiddenBars[frame] = saved
        end
    end
end

function TrackingPanel:RestoreBlizzardBars()
    for frame, saved in pairs(self.hiddenBars) do
        if saved.mode == "alpha" then
            frame:SetAlpha(saved.alpha or 1)
            frame:EnableMouse(saved.mouse and true or false)
        else
            frame:SetParent(saved.parent)
            frame:ClearAllPoints()
            for _, point in ipairs(saved.points) do
                frame:SetPoint(unpack(point))
            end
        end
        self.hiddenBars[frame] = nil
    end
end

-- Hide or restore to match the settings; in combat, wait for PLAYER_REGEN_ENABLED
function TrackingPanel:UpdateBlizzardBars()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingBlizzardBars = true
        return
    end
    self.pendingBlizzardBars = false
    if self:ShouldHideBlizzardBars(GetDB()) then
        self:HideBlizzardBars()
    else
        self:RestoreBlizzardBars()
    end
end

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

local function CreateText(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(CB:GetBarFont(), size, "OUTLINE")
    CB:RegisterFontString(fs, size, "OUTLINE")
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

local function CreateStatusBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetAllPoints(parent)
    bar:SetStatusBarTexture(CB:GetBarTexture())
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    CB:RegisterBarFrame(bar)
    return bar
end

function TrackingPanel:CreateRow()
    local f = self.frame
    local db = GetDB()
    local row = CreateFrame("Frame", nil, f)
    row.name = CreateText(row, db.textSize)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.value = CreateText(row, db.textSize)
    row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)

    row.track = CreateFrame("Frame", nil, row)
    local trackBg = row.track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0, 0, 0, 0.5)
    row.rested = CreateStatusBar(row.track)
    row.bar = CreateStatusBar(row.track)
    row.bar:SetFrameLevel(row.rested:GetFrameLevel() + 1)

    row.detail = CreateText(row, db.textSize - 2, DETAIL_COLOR[1], DETAIL_COLOR[2], DETAIL_COLOR[3])
    row.detail:SetPoint("TOPLEFT", row.track, "BOTTOMLEFT", 0, -LINE_GAP)
    return row
end

function TrackingPanel:CreateFrames()
    local db = GetDB()
    local f = CreateFrame("Frame", "Castborn_TrackingPanel", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetSize(db.width, HEADER_HEIGHT)
    CB:CreateBackdrop(f, db.bgColor)
    self.frame = f

    f.title = CreateText(f, db.textSize, 1, 0.82, 0)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -3)
    f.title:SetText("Tracking")

    local collapse = CreateFrame("Button", nil, f)
    collapse:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
    collapse:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    collapse.text = CreateText(collapse, db.textSize + 2)
    collapse.text:SetPoint("CENTER", collapse, "CENTER", 0, 0)
    collapse:SetScript("OnClick", function()
        local current = GetDB()
        current.collapsed = not current.collapsed
        TrackingPanel:Refresh()
    end)
    f.collapse = collapse

    f.rows = {}

    if CB.Anchoring then
        CB.Anchoring:MakeDraggable(f, db, nil, "Tracking")
    end
    CB:ApplyPosition(f, "tracking")
    return f
end

-- Fill a row widget from row data and return the row's height
function TrackingPanel:FillRow(row, data, db)
    row.name:SetText(data.name)
    row.value:SetText(data.value)
    row.bar:SetMinMaxValues(0, data.max)
    row.bar:SetValue(data.fill)
    row.bar:SetStatusBarColor(data.color[1], data.color[2], data.color[3])
    if data.rested then
        row.rested:SetMinMaxValues(0, data.max)
        row.rested:SetValue(data.rested)
        row.rested:SetStatusBarColor(data.color[1], data.color[2], data.color[3], RESTED_ALPHA)
        row.rested:Show()
    else
        row.rested:Hide()
    end

    local nameHeight = db.textSize + 2
    row.track:ClearAllPoints()
    row.track:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(nameHeight + LINE_GAP))
    row.track:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -(nameHeight + LINE_GAP))
    row.track:SetHeight(db.barHeight)

    local height = nameHeight + LINE_GAP + db.barHeight
    if data.detail then
        row.detail:SetText(data.detail)
        row.detail:Show()
        height = height + LINE_GAP + db.textSize
    else
        row.detail:Hide()
    end
    return height
end

function TrackingPanel:Refresh()
    local f = self.frame
    local db = GetDB()
    if not f or not db then return end
    local rows = self:CollectRows(db)

    f:SetWidth(db.width)
    f.collapse.text:SetText(db.collapsed and "+" or "-")

    local y = -HEADER_HEIGHT
    for i, data in ipairs(rows) do
        local row = f.rows[i] or self:CreateRow()
        f.rows[i] = row
        if db.collapsed then
            row:Hide()
        else
            local height = self:FillRow(row, data, db)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
            row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
            row:SetHeight(height)
            row:Show()
            y = y - height - ROW_GAP
        end
    end
    for i = #rows + 1, #f.rows do
        f.rows[i]:Hide()
    end
    f:SetHeight(-y + (db.collapsed and 0 or PADDING - ROW_GAP))

    if self:GetVisibility(db, #rows) then f:Show() else f:Hide() end
end

function TrackingPanel:ApplyFonts()
    local f = self.frame
    local db = GetDB()
    if not f or not db then return end
    f.title:SetFont(CB:GetBarFont(), db.textSize, "OUTLINE")
    CB:RegisterFontString(f.title, db.textSize, "OUTLINE")
    for _, row in ipairs(f.rows) do
        for _, fs in ipairs({ row.name, row.value }) do
            fs:SetFont(CB:GetBarFont(), db.textSize, "OUTLINE")
            CB:RegisterFontString(fs, db.textSize, "OUTLINE")
        end
        row.detail:SetFont(CB:GetBarFont(), db.textSize - 2, "OUTLINE")
        CB:RegisterFontString(row.detail, db.textSize - 2, "OUTLINE")
    end
end

-- Called whenever a tracking setting changes, including the General page toggle
function TrackingPanel:ApplySettings()
    if self.frame then
        local db = GetDB()
        CB:PaintBackdrop(self.frame, db.bgColor or defaults.bgColor)
        self:ApplyFonts()
        self:Refresh()
    end
    self:UpdateBlizzardBars()
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- Register each event, skipping any the client rejects
function TrackingPanel:RegisterEvents(f)
    self.skippedEvents = {}
    for _, event in ipairs(self.EVENTS) do
        if not pcall(f.RegisterEvent, f, event) then
            self.skippedEvents[#self.skippedEvents + 1] = event
        end
    end
end

function TrackingPanel:OnEvent(event)
    if event == "PLAYER_REGEN_ENABLED" then
        if self.pendingBlizzardBars then self:UpdateBlizzardBars() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        self:UpdateBlizzardBars()
    end
    self:Refresh()
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

CB:RegisterCallback("INIT", function()
    CastbornDB.tracking = CB:MergeDefaults(CastbornDB.tracking or {}, defaults)
end)

CB:RegisterCallback("READY", function()
    TrackingPanel:CreateFrames()

    local eventFrame = CreateFrame("Frame")
    TrackingPanel:RegisterEvents(eventFrame)
    eventFrame:SetScript("OnEvent", function(_, event)
        TrackingPanel:OnEvent(event)
    end)

    TrackingPanel:ApplySettings()

    CB.TestManager:Register("TrackingPanel",
        function() CB:TestTrackingPanel() end,
        function() CB:EndTestTrackingPanel() end
    )
end)

-- Locking hides frames that were shown for positioning; put the panel back as it should be
CB:RegisterCallback("FRAMES_LOCKED", function()
    TrackingPanel:Refresh()
end)

--------------------------------------------------------------------------------
-- Test Mode
--------------------------------------------------------------------------------

-- Test mode shows sample rows only; it never hides or restores Blizzard's bars
function CB:TestTrackingPanel()
    TrackingPanel.testModeActive = true
    TrackingPanel:Refresh()
end

function CB:EndTestTrackingPanel()
    TrackingPanel.testModeActive = false
    TrackingPanel:Refresh()
end

Castborn:RegisterModule("TrackingPanel", TrackingPanel)

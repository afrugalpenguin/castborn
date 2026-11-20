--[[
    Castborn - Progress Panel
    A floating window with one row per tracked item: XP and the watched reputation.
    Replaces Blizzard's XP and reputation bars, which it hides while enabled.
    Every read and every piece of maths on XP and reputation values is a named seam
    (ReadXP, ReadWatchedFaction, ReadFactionByID, ReadKnownFactions, ShouldShowXP, BuildXPRow,
    BuildReputationRow), and the
    Blizzard frames to hide come from GetBlizzardBars; ProgressPanel_Forever.lua overrides
    only what differs on Forever.
]]

local ProgressPanel = {}
Castborn.ProgressPanel = ProgressPanel

local CB = Castborn

-- Defaults live in CB.defaults.progress (Core.lua), so Reset Positions can find them
local defaults = CB.defaults.progress
ProgressPanel.defaults = defaults

ProgressPanel.EVENTS = {
    "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}

-- A plain boolean from PLAYER_REGEN_DISABLED / ENABLED only, for fading in combat
ProgressPanel.inCombat = false
ProgressPanel.COMBAT_ALPHA = 0.4

-- Events the client rejected
ProgressPanel.skippedEvents = {}

ProgressPanel.testModeActive = false
-- Set when a Blizzard bar change was asked for in combat; applied on PLAYER_REGEN_ENABLED
ProgressPanel.pendingBlizzardBars = false
-- Blizzard frames currently hidden, each mapped to what is needed to put it back
ProgressPanel.hiddenBars = {}

-- Used when the client has no FACTION_STANDING_LABEL<n> globals
ProgressPanel.standingLabels = {
    "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted",
}

-- Blizzard's standing colours, used when the client has no FACTION_BAR_COLORS
ProgressPanel.fallbackStandingColors = {
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

-- Collapsed mode: thin bars only, and a small handle to expand again
local COLLAPSED_BAR_HEIGHT = 4
local COLLAPSED_GAP = 2
local HANDLE_SIZE = 12

-- Sample values for test mode: level 42 at 58.7% with rested to 80%, Darkspear Raiders Honored 60.8%
local SAMPLE_XP = { level = 42, current = 58700, max = 100000, rested = 21300, maxLevel = 70, disabled = false }
local SAMPLE_REPUTATION = { name = "Darkspear Raiders", reaction = 6, min = 9000, max = 21000, value = 16296 }
local SAMPLE_XP_RATE = 48200
local SAMPLE_REP_GAIN = 250

local function GetDB()
    return CB.db and CB.db.progress
end

--------------------------------------------------------------------------------
-- Text and colours
--------------------------------------------------------------------------------

-- 41300 -> "41,300"
function ProgressPanel:FormatNumber(n)
    local s = tostring(math.floor(n + 0.5))
    local sign, digits = s:match("^(-?)(%d+)$")
    if not digits then return s end
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. grouped
end

function ProgressPanel:StandingLabel(reaction)
    return _G["FACTION_STANDING_LABEL" .. tostring(reaction)] or self.standingLabels[reaction] or "Unknown"
end

function ProgressPanel:StandingColor(reaction)
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

function ProgressPanel:ReadXP()
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
function ProgressPanel:ReadWatchedFaction()
    if not GetWatchedFactionInfo then return nil end
    local name, reaction, min, max, value, factionID = GetWatchedFactionInfo()
    if not name then return nil end
    return { factionID = factionID, name = name, reaction = reaction, min = min, max = max, value = value }
end

-- A pinned faction, looked up by ID (indexes shift when reputation headers collapse)
function ProgressPanel:ReadFactionByID(factionID)
    if not GetFactionInfoByID then return nil end
    local name, _, reaction, min, max, value = GetFactionInfoByID(factionID)
    if not name then return nil end
    return { factionID = factionID, name = name, reaction = reaction, min = min, max = max, value = value }
end

-- The factions the picker offers and gains are detected on, as { id, name, value } in
-- reputation pane order (value is the absolute standing). Headers and inactive factions are
-- skipped; hidden factions are never returned by the client. Factions under a collapsed
-- header are not listed by the client either.
function ProgressPanel:ReadKnownFactions()
    local list = {}
    if not (GetNumFactions and GetFactionInfo) then return list end
    local underInactive = false
    for i = 1, GetNumFactions() do
        local name, _, _, _, _, value, _, _, isHeader, _, _, _, _, factionID = GetFactionInfo(i)
        if isHeader then
            underInactive = name ~= nil and name == FACTION_INACTIVE
        elseif name and factionID and not underInactive
                and not (IsFactionInactive and IsFactionInactive(i)) then
            list[#list + 1] = { id = factionID, name = name, value = value }
        end
    end
    return list
end

-- db is optional; without it the XP row hides at max level
function ProgressPanel:ShouldShowXP(xp, db)
    if xp.disabled then return false end
    local hideAtMax = not db or db.hideAtMaxLevel ~= false
    if hideAtMax and xp.maxLevel and xp.level >= xp.maxLevel then return false end
    return true
end

-- 3060 -> "51m", 4500 -> "1h 15m"
function ProgressPanel:FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    if minutes < 1 then return "<1m" end
    if minutes < 60 then return minutes .. "m" end
    local hours = math.floor(minutes / 60)
    if hours >= 100 then return "99h+" end
    return hours .. "h " .. (minutes % 60) .. "m"
end

-- Detail line parts are joined with a spaced hyphen (commas already group the numbers)
local function JoinDetail(parts)
    if #parts == 0 then return nil end
    return table.concat(parts, " - ")
end

-- A row is the texts, the bar range (0 to max) and fills, and colours.
-- rate is XP per hour this session, or nil to leave the rate out.
function ProgressPanel:BuildXPRow(xp, rate)
    local current, max = xp.current or 0, xp.max or 0
    local percent = max > 0 and current * 100 / max or 0
    local rested = xp.rested or 0
    local barMax = max > 0 and max or 1
    local remaining = math.max(0, max - current)
    local parts = {}
    if rested > 0 then parts[#parts + 1] = "Rested " .. self:FormatNumber(rested) end
    if rate and rate > 0 then
        parts[#parts + 1] = self:FormatNumber(rate) .. " XP/h"
        parts[#parts + 1] = self:FormatDuration(remaining / rate * 3600) .. " to level"
    end
    return {
        name = "Level " .. tostring(xp.level),
        value = string.format("%.1f%% (%s to go)", percent, self:FormatNumber(remaining)),
        detail = JoinDetail(parts),
        max = barMax,
        fill = current,
        rested = math.min(current + rested, barMax),
        color = { XP_COLOR[1], XP_COLOR[2], XP_COLOR[3] },
    }
end

-- sessionGain is the standing gained this session, or nil to leave it out
function ProgressPanel:BuildReputationRow(rep, sessionGain)
    local range = rep.max - rep.min
    local percent = range > 0 and (rep.value - rep.min) * 100 / range or 100
    local r, g, b = self:StandingColor(rep.reaction)
    local parts = {}
    if range > 0 and rep.reaction < EXALTED then
        parts[#parts + 1] = self:FormatNumber(rep.max - rep.value) .. " to " .. self:StandingLabel(rep.reaction + 1)
    end
    if sessionGain and sessionGain ~= 0 then
        parts[#parts + 1] = (sessionGain > 0 and "+" or "") .. self:FormatNumber(sessionGain) .. " this session"
    end
    local detail = JoinDetail(parts)
    return {
        factionID = rep.factionID,
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
function ProgressPanel:GetBlizzardBars()
    return {
        { name = "MainMenuExpBar", mode = "reparent" },
        { name = "ReputationWatchBar", mode = "reparent" },
        { name = "MainMenuBarMaxLevelBar", mode = "reparent" },
    }
end

--------------------------------------------------------------------------------
-- Pinned reputations, per character (CastbornDB.characters, which profiles leave alone)
--------------------------------------------------------------------------------

function ProgressPanel:GetCharacterKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- Faction IDs pinned by this character, in the order they were added
function ProgressPanel:GetPinnedFactions()
    CastbornDB.characters = CastbornDB.characters or {}
    local key = self:GetCharacterKey()
    local data = CastbornDB.characters[key] or {}
    CastbornDB.characters[key] = data
    data.trackedFactions = data.trackedFactions or {}
    return data.trackedFactions
end

function ProgressPanel:IsPinned(factionID)
    for _, id in ipairs(self:GetPinnedFactions()) do
        if id == factionID then return true end
    end
    return false
end

-- Returns true if the faction was added
function ProgressPanel:PinFaction(factionID)
    if not factionID or self:IsPinned(factionID) then return false end
    local pinned = self:GetPinnedFactions()
    pinned[#pinned + 1] = factionID
    return true
end

-- Returns true if the faction was removed
function ProgressPanel:UnpinFaction(factionID)
    local pinned = self:GetPinnedFactions()
    for i, id in ipairs(pinned) do
        if id == factionID then
            table.remove(pinned, i)
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Reputation gains: untracked factions that gain are added as temporary rows
--------------------------------------------------------------------------------

-- An auto-added row is dropped after this long without another gain
ProgressPanel.AUTO_ADD_EXPIRY = 600
ProgressPanel.AUTO_ADD_NOTICE = "Auto-added - pin to keep"

-- factionID -> absolute standing, taken on PLAYER_ENTERING_WORLD and kept up to date
ProgressPanel.factionSnapshot = nil
-- Temporary rows, oldest first: { factionID, lastGain, flash }
ProgressPanel.autoAdded = {}

-- The clock, a seam so specs can move time
function ProgressPanel:Now()
    return GetTime()
end

function ProgressPanel:TakeFactionSnapshot()
    self.factionSnapshot = {}
    for _, faction in ipairs(self:ReadKnownFactions()) do
        if faction.value ~= nil then
            self.factionSnapshot[faction.id] = faction.value
            self:RecordFactionStart(faction.id, faction.value)
        end
    end
end

-- Compare every faction with the snapshot and return the gains as { id, delta }. Factions
-- not seen before (a header just expanded) are recorded, not counted. Chat messages are not
-- parsed: their text may be secret on Forever.
function ProgressPanel:DetectFactionGains()
    if not self.factionSnapshot then
        self:TakeFactionSnapshot()
        return {}
    end
    local gains = {}
    for _, faction in ipairs(self:ReadKnownFactions()) do
        if faction.value ~= nil then
            local old = self.factionSnapshot[faction.id]
            if old ~= nil and faction.value > old then
                gains[#gains + 1] = { id = faction.id, delta = faction.value - old }
            end
            self.factionSnapshot[faction.id] = faction.value
        end
    end
    return gains
end

-- Already a row of its own: pinned, or the watched faction while that row is shown
function ProgressPanel:IsTracked(factionID, db)
    if self:IsPinned(factionID) then return true end
    if db.showReputation then
        local watched = self:ReadWatchedFaction()
        if watched and watched.factionID == factionID then return true end
    end
    return false
end

local function FindAutoAdded(self, factionID)
    for i, entry in ipairs(self.autoAdded) do
        if entry.factionID == factionID then return i, entry end
    end
end

-- A gain on an untracked faction adds it at the bottom (highlighted once), or keeps an
-- existing temporary row for another ten minutes
function ProgressPanel:NoteGain(factionID, db)
    if not db.trackOnGain or self:IsTracked(factionID, db) then return end
    local now = self:Now()
    local _, entry = FindAutoAdded(self, factionID)
    if entry then
        entry.lastGain = now
    else
        self.autoAdded[#self.autoAdded + 1] = { factionID = factionID, lastGain = now, flash = true }
    end
    -- Nothing else may refresh the panel when the row runs out
    if C_Timer then
        C_Timer.After(self.AUTO_ADD_EXPIRY + 1, function() ProgressPanel:Refresh() end)
    end
end

function ProgressPanel:ExpireAutoAdded()
    local now = self:Now()
    for i = #self.autoAdded, 1, -1 do
        if now - self.autoAdded[i].lastGain >= self.AUTO_ADD_EXPIRY then
            table.remove(self.autoAdded, i)
        end
    end
end

-- Clicking a temporary row pins it, making it permanent
function ProgressPanel:OnRowClick(data)
    if not data or not data.autoAdded or not data.factionID then return false end
    self:PinFaction(data.factionID)
    local i = FindAutoAdded(self, data.factionID)
    if i then table.remove(self.autoAdded, i) end
    self:Refresh()
    return true
end

--------------------------------------------------------------------------------
-- Session rate: XP per hour and reputation gained since login (a /reload starts again)
--------------------------------------------------------------------------------

-- The XP rate stays hidden until this much data exists
ProgressPanel.MIN_RATE_SECONDS = 120

function ProgressPanel:ResetSession()
    -- startTime is set by the first XP reading; repStart holds each faction's first standing
    self.session = { startTime = nil, xpGained = 0, lastXP = nil, repStart = {} }
end
ProgressPanel:ResetSession()

-- Add the XP gained since the last reading. Only UnitXP is diffed, so the rested pool
-- filling or draining never counts; rested bonus XP actually earned does. A level-up adds
-- the rest of the old level plus the XP into the new one. UnitLevel can lag a moment behind
-- UnitXP, so XP going down at the same level counts as the level-up, and the stored level
-- moves on so the late level change is not counted again.
function ProgressPanel:RecordXP(xp)
    local s = self.session
    if not s.startTime then
        s.startTime = self:Now()
        -- Show the rate as soon as it may, without waiting for the next XP event
        if C_Timer then
            C_Timer.After(self.MIN_RATE_SECONDS + 1, function() ProgressPanel:Refresh() end)
        end
    end
    local last = s.lastXP
    local level = xp.level
    if last then
        level = math.max(xp.level, last.level)
        if xp.level > last.level or xp.current < last.current then
            s.xpGained = s.xpGained + math.max(0, last.max - last.current) + xp.current
            level = math.max(xp.level, last.level + 1)
        else
            s.xpGained = s.xpGained + (xp.current - last.current)
        end
    end
    s.lastXP = { level = level, current = xp.current, max = xp.max }
end

-- XP per hour, or nil until two minutes of data and some XP exist
function ProgressPanel:XPRate()
    local s = self.session
    if not s.startTime or s.xpGained <= 0 then return nil end
    local elapsed = self:Now() - s.startTime
    if elapsed < self.MIN_RATE_SECONDS then return nil end
    return s.xpGained * 3600 / elapsed
end

-- The first standing seen this session is the baseline (from the login snapshot, or the first
-- time the row is read, for factions the snapshot could not see)
function ProgressPanel:RecordFactionStart(factionID, value)
    if factionID and value ~= nil and self.session.repStart[factionID] == nil then
        self.session.repStart[factionID] = value
    end
end

function ProgressPanel:SessionRepGain(factionID, value)
    local start = factionID and self.session.repStart[factionID]
    if start == nil or value == nil then return nil end
    return value - start
end

--------------------------------------------------------------------------------
-- Rows and visibility
--------------------------------------------------------------------------------

-- Display settings that apply to every row, test mode included
local function ApplyRowSettings(rows, db)
    for _, row in ipairs(rows) do
        if db.showRested == false then row.rested = nil end
        if db.showDetail == false then row.detail = nil end
    end
    return rows
end

-- XP, then the watched reputation, then pinned reputations in the order added.
-- A pinned faction that is also watched is shown once, as the watched row.
function ProgressPanel:CollectRows(db)
    local showRate = db.showSessionRate
    if self.testModeActive then
        return ApplyRowSettings({
            self:BuildXPRow(SAMPLE_XP, showRate and SAMPLE_XP_RATE or nil),
            self:BuildReputationRow(SAMPLE_REPUTATION, showRate and SAMPLE_REP_GAIN or nil),
        }, db)
    end
    local rows = {}
    if db.showXP then
        local xp = self:ReadXP()
        if xp then
            self:RecordXP(xp)
            if self:ShouldShowXP(xp, db) then
                rows[#rows + 1] = self:BuildXPRow(xp, showRate and self:XPRate() or nil)
            end
        end
    end

    local function ReputationRow(rep)
        self:RecordFactionStart(rep.factionID, rep.value)
        local gain = showRate and self:SessionRepGain(rep.factionID, rep.value) or nil
        rows[#rows + 1] = self:BuildReputationRow(rep, gain)
    end

    local watchedID
    if db.showReputation then
        local rep = self:ReadWatchedFaction()
        if rep then
            watchedID = rep.factionID
            ReputationRow(rep)
        end
    end
    for _, factionID in ipairs(self:GetPinnedFactions()) do
        if factionID ~= watchedID then
            local rep = self:ReadFactionByID(factionID)
            if rep then ReputationRow(rep) end
        end
    end
    ApplyRowSettings(rows, db)

    -- Temporary rows last; their detail line is the notice, whatever showDetail says
    if db.trackOnGain then
        self:ExpireAutoAdded()
        for _, entry in ipairs(self.autoAdded) do
            if entry.factionID ~= watchedID and not self:IsPinned(entry.factionID) then
                local rep = self:ReadFactionByID(entry.factionID)
                if rep then
                    local row = self:BuildReputationRow(rep)
                    row.autoAdded = true
                    row.detail = self.AUTO_ADD_NOTICE
                    row.rested = nil
                    row.flash = entry.flash
                    entry.flash = false
                    rows[#rows + 1] = row
                end
            end
        end
    end
    return rows
end

--------------------------------------------------------------------------------
-- Collapsed mode
--------------------------------------------------------------------------------

-- The header's button; the state is saved, so it survives a /reload
function ProgressPanel:ToggleCollapsed()
    local db = GetDB()
    db.collapsed = not db.collapsed
    self:Refresh()
end

-- At login, "Start collapsed" folds the panel; otherwise the saved state stands
function ProgressPanel:ApplyStartCollapsed(db)
    if db.startCollapsed then db.collapsed = true end
end

-- What hovering a collapsed bar shows: name and value, then the detail line
function ProgressPanel:GetTooltipLines(data)
    return { left = data.name, right = data.value, detail = data.detail }
end

-- Rows take the mouse only while collapsed (for the tooltip) or when temporary (click to pin),
-- and never while frames are unlocked, so they do not get in the way of dragging the panel
function ProgressPanel:RowWantsMouse(data, db)
    if CastbornDB.locked == false then return false end
    return (db.collapsed or data.autoAdded) and true or false
end

-- Faded in combat when asked; never in test mode, so the panel can be positioned
function ProgressPanel:GetPanelAlpha(db)
    if db and db.fadeInCombat and self.inCombat and not self.testModeActive then
        return self.COMBAT_ALPHA
    end
    return 1
end

function ProgressPanel:ApplyAlpha()
    if self.frame then self.frame:SetAlpha(self:GetPanelAlpha(GetDB())) end
end

-- Shown when enabled and something is tracked, or always in test mode
function ProgressPanel:GetVisibility(db, rowCount)
    if not db or not db.enabled then return false end
    if self.testModeActive then return true end
    return rowCount > 0
end

--------------------------------------------------------------------------------
-- Blizzard bars
--------------------------------------------------------------------------------

-- Hidden parent for reparented Blizzard frames
ProgressPanel.hider = CreateFrame("Frame")
ProgressPanel.hider:Hide()

-- Depends only on settings, never on test mode
function ProgressPanel:ShouldHideBlizzardBars(db)
    return db and db.enabled and db.hideBlizzardBars and true or false
end

function ProgressPanel:HideBlizzardBars()
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

function ProgressPanel:RestoreBlizzardBars()
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
function ProgressPanel:UpdateBlizzardBars()
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

function ProgressPanel:CreateRow()
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

    row:SetScript("OnEnter", function(self)
        if not self.data or not GetDB().collapsed then return end
        local lines = ProgressPanel:GetTooltipLines(self.data)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddDoubleLine(lines.left, lines.right, 1, 1, 1, 1, 1, 1)
        if lines.detail then
            GameTooltip:AddLine(lines.detail, DETAIL_COLOR[1], DETAIL_COLOR[2], DETAIL_COLOR[3])
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then ProgressPanel:OnRowClick(self.data) end
    end)

    -- A standing-coloured outline that fades out once when a row is auto-added
    local outline = CreateFrame("Frame", nil, row)
    outline:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 2)
    outline:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 2, -2)
    outline:SetAlpha(0)
    outline.edges = {}
    -- Each edge runs between two corners; horizontal edges are 1 pixel high, vertical 1 wide
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
            { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local edge = outline:CreateTexture(nil, "OVERLAY")
        edge:SetPoint(side[1], outline, side[1], 0, 0)
        edge:SetPoint(side[2], outline, side[2], 0, 0)
        if side[3] then edge:SetHeight(1) else edge:SetWidth(1) end
        outline.edges[#outline.edges + 1] = edge
    end
    local fade = outline:CreateAnimationGroup()
    local alpha = fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(1.5)
    fade:SetScript("OnFinished", function() outline:SetAlpha(0) end)
    outline.fade = fade
    row.outline = outline
    return row
end

function ProgressPanel:FlashRow(row, color)
    local outline = row.outline
    for _, edge in ipairs(outline.edges) do
        edge:SetColorTexture(color[1], color[2], color[3], 1)
    end
    outline.fade:Stop()
    outline:SetAlpha(1)
    outline.fade:Play()
end

function ProgressPanel:CreateFrames()
    local db = GetDB()
    local f = CreateFrame("Frame", "Castborn_ProgressPanel", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetSize(db.width, HEADER_HEIGHT)
    CB:CreateBackdrop(f, db.bgColor)
    self.frame = f

    f.title = CreateText(f, db.textSize, 1, 0.82, 0)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -3)
    f.title:SetText("Progress")

    -- In the header while expanded; a small handle beside the bars while collapsed
    local collapse = CreateFrame("Button", nil, f)
    collapse.text = CreateText(collapse, db.textSize + 2)
    collapse.text:SetPoint("CENTER", collapse, "CENTER", 0, 0)
    collapse:SetScript("OnClick", function()
        ProgressPanel:ToggleCollapsed()
    end)
    f.collapse = collapse

    f.rows = {}

    if CB.Anchoring then
        CB.Anchoring:MakeDraggable(f, db, nil, "Progress")
    end
    CB:ApplyPosition(f, "progress")
    return f
end

local function ShowIf(region, shown)
    if shown then region:Show() else region:Hide() end
end

-- Fill a row widget from row data and return the row's height
function ProgressPanel:FillRow(row, data, db)
    row.data = data
    row:EnableMouse(self:RowWantsMouse(data, db))
    local collapsed = db.collapsed and true or false
    ShowIf(row.name, not collapsed)
    ShowIf(row.value, not collapsed)
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

    -- Collapsed: the bar alone, thin, at the top of the row
    local nameHeight = collapsed and 0 or (db.textSize + 2)
    local barTop = collapsed and 0 or (nameHeight + LINE_GAP)
    local barHeight = collapsed and COLLAPSED_BAR_HEIGHT or db.barHeight
    row.track:ClearAllPoints()
    row.track:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -barTop)
    row.track:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -barTop)
    row.track:SetHeight(barHeight)

    local height = barTop + barHeight
    if data.detail and not collapsed then
        row.detail:SetText(data.detail)
        row.detail:Show()
        height = height + LINE_GAP + db.textSize
    else
        row.detail:Hide()
    end
    return height
end

function ProgressPanel:Refresh()
    local f = self.frame
    local db = GetDB()
    if not f or not db then return end
    local rows = self:CollectRows(db)
    local collapsed = db.collapsed and true or false

    f:SetWidth(db.width)
    ShowIf(f.title, not collapsed)
    local handle = f.collapse
    handle:ClearAllPoints()
    if collapsed then
        handle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
        handle:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, 0)
        handle.text:SetText("+")
    else
        handle:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
        handle:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        handle.text:SetText("-")
    end

    local gap = collapsed and COLLAPSED_GAP or ROW_GAP
    local y = collapsed and -PADDING or -HEADER_HEIGHT
    for i, data in ipairs(rows) do
        local row = f.rows[i] or self:CreateRow()
        f.rows[i] = row
        local height = self:FillRow(row, data, db)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, y)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, y)
        row:SetHeight(height)
        row:Show()
        if data.flash then self:FlashRow(row, data.color) end
        y = y - height - gap
    end
    for i = #rows + 1, #f.rows do
        f.rows[i]:Hide()
    end
    -- y ends one gap below the last row
    f:SetHeight(-y - gap + PADDING)

    f:SetAlpha(self:GetPanelAlpha(db))
    if self:GetVisibility(db, #rows) then f:Show() else f:Hide() end
end

function ProgressPanel:ApplyFonts()
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

-- Called whenever a progress setting changes, including the General page toggle
function ProgressPanel:ApplySettings()
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
function ProgressPanel:RegisterEvents(f)
    self.skippedEvents = {}
    for _, event in ipairs(self.EVENTS) do
        if not pcall(f.RegisterEvent, f, event) then
            self.skippedEvents[#self.skippedEvents + 1] = event
        end
    end
end

function ProgressPanel:OnEvent(event)
    if event == "PLAYER_REGEN_DISABLED" then
        self.inCombat = true
        self:ApplyAlpha()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.inCombat = false
        self:ApplyAlpha()
        if self.pendingBlizzardBars then self:UpdateBlizzardBars() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        self:UpdateBlizzardBars()
        self:TakeFactionSnapshot()
    elseif event == "UPDATE_FACTION" then
        local db = GetDB()
        for _, gain in ipairs(self:DetectFactionGains()) do
            self:NoteGain(gain.id, db)
        end
    end
    self:Refresh()
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

CB:RegisterCallback("INIT", function()
    CastbornDB.progress = CB:MergeDefaults(CastbornDB.progress or {}, defaults)
end)

CB:RegisterCallback("READY", function()
    ProgressPanel:ApplyStartCollapsed(CastbornDB.progress)
    ProgressPanel:CreateFrames()

    local eventFrame = CreateFrame("Frame")
    ProgressPanel:RegisterEvents(eventFrame)
    eventFrame:SetScript("OnEvent", function(_, event)
        ProgressPanel:OnEvent(event)
    end)

    ProgressPanel:ApplySettings()

    CB.TestManager:Register("ProgressPanel",
        function() CB:TestProgressPanel() end,
        function() CB:EndTestProgressPanel() end
    )
end)

-- Repaint when the Progress page's background picker changes
CB:RegisterCallback("BACKGROUND_CHANGED", function(key)
    if key == "progress" then ProgressPanel:ApplySettings() end
end)

-- Locking hides frames that were shown for positioning; put the panel back as it should be
CB:RegisterCallback("FRAMES_LOCKED", function()
    ProgressPanel:Refresh()
end)

-- Collapsed rows give up the mouse while unlocked, so the panel can be dragged by them
CB:RegisterCallback("FRAMES_UNLOCKED", function()
    ProgressPanel:Refresh()
end)

--------------------------------------------------------------------------------
-- Test Mode
--------------------------------------------------------------------------------

-- Test mode shows sample rows only; it never hides or restores Blizzard's bars
function CB:TestProgressPanel()
    ProgressPanel.testModeActive = true
    ProgressPanel:Refresh()
end

function CB:EndTestProgressPanel()
    ProgressPanel.testModeActive = false
    ProgressPanel:Refresh()
end

Castborn:RegisterModule("ProgressPanel", ProgressPanel)

--[[
    Castborn - Resource Bars
    The player's health and power bars, stacked in one movable frame.
    Anything that does maths or comparisons on health or power is a named seam
    (SetBarValues, FormatText, ShouldHidePower, SupportsPercent), because those values are
    secret on Forever; ResourceBars_Forever.lua overrides only those.
]]

local ResourceBars = {}
Castborn.ResourceBars = ResourceBars

local CB = Castborn

-- Defaults live in CB.defaults.resources (Core.lua), so Reset Positions can find them
local defaults = CB.defaults.resources
ResourceBars.defaults = defaults

-- Used when the client has no PowerBarColor, or it lacks the power type
ResourceBars.fallbackPowerColors = {
    MANA = { 0, 0, 1 },
    RAGE = { 1, 0, 0 },
    FOCUS = { 1, 0.5, 0.25 },
    ENERGY = { 1, 1, 0 },
}

-- Unit events are registered for the player only; the rest are plain events.
-- UNIT_HEALTH_FREQUENT is gone on modern clients, so it is deliberately absent.
ResourceBars.EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}
local unitEvents = {
    UNIT_HEALTH = true, UNIT_MAXHEALTH = true,
    UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true,
}

-- Events the client rejected, listed by /cbapi on Forever
ResourceBars.skippedEvents = {}

-- Plain booleans from PLAYER_REGEN_*; never derived from health or power
ResourceBars.inCombat = false
ResourceBars.testModeActive = false
-- Set when the power bar is hidden because the player has no power (TBC only)
ResourceBars.powerHidden = false

local function GetDB()
    return CB.db and CB.db.resources
end

--------------------------------------------------------------------------------
-- Text
--------------------------------------------------------------------------------

local function TrimZero(s)
    return (s:gsub("%.0$", ""))
end

-- 999 -> "999", 12345 -> "12.3k", 1234567 -> "1.2m"
function ResourceBars:ShortNumber(n)
    -- 999950 would print as "1000.0k", so it counts as a million
    if n >= 999950 then
        return TrimZero(string.format("%.1f", n / 1000000)) .. "m"
    elseif n >= 1000 then
        return TrimZero(string.format("%.1f", n / 1000)) .. "k"
    end
    return tostring(math.floor(n + 0.5))
end

local function Percent(current, max)
    if max <= 0 then return 0 end
    return math.floor(current * 100 / max + 0.5)
end

-- The text for a format, worked out in plain Lua
function ResourceBars:BuildText(format, current, max)
    if format == "NONE" then return "" end
    if format == "CURRENT" then return self:ShortNumber(current) end
    if format == "PERCENT" then return Percent(current, max) .. "%" end
    if format == "CURRENT_PERCENT" then
        return self:ShortNumber(current) .. " (" .. Percent(current, max) .. "%)"
    end
    return self:ShortNumber(current) .. " / " .. self:ShortNumber(max)
end

-- Whether PERCENT and CURRENT_PERCENT can be shown; otherwise they fall back to CURRENT_MAX
function ResourceBars:SupportsPercent()
    return true
end

-- The saved text format, with percentages swapped for CURRENT_MAX when unsupported
function ResourceBars:GetTextFormat(db)
    local format = db and db.textFormat or "CURRENT_MAX"
    if (format == "PERCENT" or format == "CURRENT_PERCENT") and not self:SupportsPercent() then
        return "CURRENT_MAX"
    end
    return format
end

--------------------------------------------------------------------------------
-- Seams over health and power values (overridden on Forever)
--------------------------------------------------------------------------------

function ResourceBars:SetBarValues(bar, current, max)
    if not max or max < 1 then max = 1 end
    bar:SetMinMaxValues(0, max)
    bar:SetValue(current or 0)
end

-- kind is "health" or "power"; unit is used by Forever's percentage APIs
function ResourceBars:FormatText(fontString, current, max, unit, kind)
    fontString:SetText(self:BuildText(self:GetTextFormat(GetDB()), current or 0, max or 0))
end

function ResourceBars:ShouldHidePower(max)
    return max == 0
end

--------------------------------------------------------------------------------
-- Colours
--------------------------------------------------------------------------------

function ResourceBars:GetPowerColor(powerType, powerToken)
    local pbc = PowerBarColor
    local c = pbc and ((powerToken and pbc[powerToken]) or (powerType and pbc[powerType]))
    if c and c.r then return c.r, c.g, c.b end
    local f = (powerToken and self.fallbackPowerColors[powerToken]) or self.fallbackPowerColors.MANA
    return f[1], f[2], f[3]
end

function ResourceBars:GetHealthColor(db)
    if db.healthColorMode == "CUSTOM" and db.healthColor then
        return db.healthColor[1], db.healthColor[2], db.healthColor[3]
    end
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.2, 0.8, 0.2
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

-- Returns shown, alpha. Uses only settings and the combat flag.
function ResourceBars:GetVisibility(db)
    if not db or not db.enabled then return false, 1 end
    if not db.showHealth and not db.showPower then return false, 1 end
    if self.testModeActive then return true, 1 end
    if db.visibility == "COMBAT" then
        return self.inCombat, 1
    elseif db.visibility == "FADE" then
        return true, self.inCombat and 1 or (db.fadeAlpha or 0.4)
    end
    return true, 1
end

function ResourceBars:ApplyVisibility()
    local f = self.frame
    if not f then return end
    local shown, alpha = self:GetVisibility(GetDB())
    f:SetAlpha(alpha)
    if shown then f:Show() else f:Hide() end
end

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

local function CreateBar(parent, db)
    local holder = CreateFrame("Frame", nil, parent)
    CB:CreateBackdrop(holder, db.bgColor)

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(CB:GetBarTexture())
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    CB:RegisterBarFrame(bar)

    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetFont(CB:GetBarFont(), db.textSize, "OUTLINE")
    CB:RegisterFontString(text, db.textSize, "OUTLINE")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)

    return { holder = holder, bar = bar, text = text }
end

-- Keeps the width setting when anchored, instead of matching the castbar width
local function SyncWidth()
    ResourceBars:Layout()
end

function ResourceBars:CreateFrames()
    local db = GetDB()
    local f = CreateFrame("Frame", "Castborn_ResourceBars", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetSize(db.width, db.healthHeight + db.gap + db.powerHeight)
    f.health = CreateBar(f, db)
    f.power = CreateBar(f, db)
    self.frame = f

    if CB.Anchoring then
        CB.Anchoring:MakeDraggable(f, db, function()
            db.anchored = false
        end, "Resource Bars")
    end
    -- Always placed, so an anchored frame still shows if the castbar never appears;
    -- anchoring then moves it under the castbar
    CB:ApplyPosition(f, "resources")

    self:ApplySettings()
    return f
end

-- Stack the shown bars and size the container around them
function ResourceBars:Layout()
    local f = self.frame
    local db = GetDB()
    if not f or not db then return end
    f:SetWidth(db.width)

    local y = 0
    local rows = {
        { part = f.health, shown = db.showHealth, height = db.healthHeight },
        { part = f.power, shown = db.showPower and not self.powerHidden, height = db.powerHeight },
    }
    for _, row in ipairs(rows) do
        local holder = row.part.holder
        if row.shown then
            holder:ClearAllPoints()
            holder:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
            holder:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, y)
            holder:SetHeight(row.height)
            holder:Show()
            y = y - row.height - db.gap
        else
            holder:Hide()
        end
    end
    -- y ends one gap below the last shown bar
    f:SetHeight(math.max(1, -y - db.gap))
end

function ResourceBars:ApplyBackground()
    local f = self.frame
    local db = GetDB()
    if not f or not db then return end
    local c = db.bgColor or defaults.bgColor
    for _, part in ipairs({ f.health, f.power }) do
        part.holder._bgColor = c
        if part.holder.bg then part.holder.bg:SetColorTexture(c[1], c[2], c[3], c[4] or 0.6) end
    end
end

-- The bars' own texture, or the global Look & Feel one
function ResourceBars:GetTexture(db)
    if not db or not db.barTexture or db.barTexture == "GLOBAL" then
        return CB:GetBarTexture()
    end
    return CB:ResolveBarTexture(db.barTexture)
end

function ResourceBars:ApplyTexture()
    local f = self.frame
    if not f then return end
    local texture = self:GetTexture(GetDB())
    f.health.bar:SetStatusBarTexture(texture)
    f.power.bar:SetStatusBarTexture(texture)
end

function ResourceBars:ApplyFonts()
    local f = self.frame
    local db = GetDB()
    if not f or not db then return end
    for _, part in ipairs({ f.health, f.power }) do
        part.text:SetFont(CB:GetBarFont(), db.textSize, "OUTLINE")
        CB:RegisterFontString(part.text, db.textSize, "OUTLINE")
    end
end

function ResourceBars:UpdateHealthColor()
    local f = self.frame
    if not f then return end
    local r, g, b = self:GetHealthColor(GetDB())
    f.health.bar:SetStatusBarColor(r, g, b)
end

function ResourceBars:UpdatePowerColor()
    local f = self.frame
    if not f then return end
    local db = GetDB()
    local r, g, b
    if db.powerColorMode == "CUSTOM" and db.powerColor then
        r, g, b = db.powerColor[1], db.powerColor[2], db.powerColor[3]
    else
        r, g, b = self:GetPowerColor(UnitPowerType("player"))
    end
    f.power.bar:SetStatusBarColor(r, g, b)
end

function ResourceBars:UpdateHealth()
    local f = self.frame
    if not f or self.testModeActive then return end
    local current, max = UnitHealth("player"), UnitHealthMax("player")
    self:SetBarValues(f.health.bar, current, max)
    self:FormatText(f.health.text, current, max, "player", "health")
end

function ResourceBars:UpdatePower()
    local f = self.frame
    if not f or self.testModeActive then return end
    local powerType = UnitPowerType("player")
    local current, max = UnitPower("player", powerType), UnitPowerMax("player", powerType)
    self:SetBarValues(f.power.bar, current, max)
    self:FormatText(f.power.text, current, max, "player", "power")
    -- ShouldHidePower returns a plain boolean (always false on Forever)
    local hide = self:ShouldHidePower(max) and true or false
    if hide ~= self.powerHidden then
        self.powerHidden = hide
        self:Layout()
    end
end

-- Sample values for test mode, plain on every client
function ResourceBars:ShowTestValues()
    local f = self.frame
    if not f then return end
    local format = self:GetTextFormat(GetDB())
    f.health.bar:SetMinMaxValues(0, 10000)
    f.health.bar:SetValue(7500)
    f.health.text:SetText(self:BuildText(format, 7500, 10000))
    f.power.bar:SetMinMaxValues(0, 10000)
    f.power.bar:SetValue(6000)
    f.power.text:SetText(self:BuildText(format, 6000, 10000))
end

function ResourceBars:Refresh()
    if self.testModeActive then
        self:ShowTestValues()
    else
        self:UpdateHealth()
        self:UpdatePower()
    end
end

-- Called by the options page whenever a resource bar setting changes
function ResourceBars:ApplySettings()
    if not self.frame then return end
    if self.testModeActive then self.powerHidden = false end
    self:Layout()
    self:ApplyBackground()
    self:ApplyTexture()
    self:ApplyFonts()
    self:UpdateHealthColor()
    self:UpdatePowerColor()
    self:Refresh()
    self:ApplyVisibility()
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- Register each event, skipping any the client rejects
function ResourceBars:RegisterEvents(f)
    self.skippedEvents = {}
    for _, event in ipairs(self.EVENTS) do
        local ok
        if unitEvents[event] then
            ok = pcall(f.RegisterUnitEvent, f, event, "player")
        else
            ok = pcall(f.RegisterEvent, f, event)
        end
        if not ok then self.skippedEvents[#self.skippedEvents + 1] = event end
    end
end

function ResourceBars:OnEvent(event)
    if event == "PLAYER_REGEN_DISABLED" then
        self.inCombat = true
        self:ApplyVisibility()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self.inCombat = false
        self:ApplyVisibility()
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        self:UpdateHealth()
    elseif event == "UNIT_DISPLAYPOWER" then
        self:UpdatePowerColor()
        self:UpdatePower()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self.inCombat = UnitAffectingCombat("player") and true or false
        self:UpdateHealthColor()
        self:UpdatePowerColor()
        self:Refresh()
        self:ApplyVisibility()
    else
        self:UpdatePower()
    end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

CB:RegisterCallback("INIT", function()
    CastbornDB.resources = CB:MergeDefaults(CastbornDB.resources or {}, defaults)
end)

local function Reattach()
    local db = CastbornDB.resources
    if ResourceBars.frame and db and db.anchored and CB.Anchoring then
        CB.Anchoring:ReattachToCastbar(ResourceBars.frame, db, "BOTTOM", -2, SyncWidth)
    end
end

CB:RegisterCallback("READY", function()
    ResourceBars:CreateFrames()

    local eventFrame = CreateFrame("Frame")
    ResourceBars:RegisterEvents(eventFrame)
    eventFrame:SetScript("OnEvent", function(_, event)
        ResourceBars:OnEvent(event)
    end)

    ResourceBars.inCombat = UnitAffectingCombat("player") and true or false
    Reattach()
    ResourceBars:Refresh()
    ResourceBars:ApplyVisibility()

    CB.TestManager:Register("ResourceBars",
        function() CB:TestResourceBars() end,
        function() CB:EndTestResourceBars() end
    )
end)

CB:RegisterCallback("PLAYER_CASTBAR_CREATED", Reattach)

-- Locking hides frames that were shown or Ctrl+Shift hidden for positioning; nothing else
-- would re-show the bars until health, power or combat changed
CB:RegisterCallback("FRAMES_LOCKED", function()
    ResourceBars:ApplyVisibility()
end)

CB:RegisterAnchorCallbacks("RESOURCES", "Resource Bars", function() return ResourceBars.frame end,
    "resources", "BOTTOM", -2, { syncCallback = SyncWidth })

--------------------------------------------------------------------------------
-- Test Mode
--------------------------------------------------------------------------------

function CB:TestResourceBars()
    if not ResourceBars.frame then return end
    ResourceBars.testModeActive = true
    ResourceBars:ApplySettings()
end

function CB:EndTestResourceBars()
    ResourceBars.testModeActive = false
    if ResourceBars.frame then
        ResourceBars:ApplySettings()
    end
end

Castborn:RegisterModule("ResourceBars", ResourceBars)

--[[
    Castborn - cooldown text on Forever
    Styles the game's own countdown numbers on Blizzard's action buttons and on Castborn's
    cooldown and item icons. The engine draws the numbers, so secret cooldown times never pass
    through Lua; colour stages come from a step colour curve evaluated by each cooldown's
    duration object, whose (secret) result goes straight into SetTextColor.
    Loaded only by Castborn_Camelot.toc.
]]

local CB = Castborn
local CooldownText = {}
CB.CooldownText = CooldownText

local CVAR = "countdownForCooldowns"
local SHORT_SECONDS, LONG_SECONDS = 5, 60
local RECOLOUR_INTERVAL = 0.1

local ACTION_BARS = {
    { prefix = "ActionButton", count = 12 },
    { prefix = "MultiBarBottomLeftButton", count = 12 },
    { prefix = "MultiBarBottomRightButton", count = 12 },
    { prefix = "MultiBarRightButton", count = 12 },
    { prefix = "MultiBarLeftButton", count = 12 },
    { prefix = "MultiBar5Button", count = 12 },
    { prefix = "MultiBar6Button", count = 12 },
    { prefix = "MultiBar7Button", count = 12 },
    { prefix = "PetActionButton", count = 10 },
    { prefix = "StanceButton", count = 10 },
}

CooldownText.defaults = {
    enabled = true,
    actionBars = true,
    castbornIcons = true,
    textScale = 45,      -- percent of the button's width
    outline = true,
    minDuration = 2,     -- seconds; shorter cooldowns (the GCD) show no number
    decimalsBelow = 3,   -- seconds; below this the number shows tenths
    colorStages = true,
    longColor = { 1, 1, 1, 1 },          -- a minute or more
    mediumColor = { 1, 0.85, 0.3, 1 },   -- under a minute
    shortColor = { 1, 0.3, 0.25, 1 },    -- under five seconds
}

-- cooldown frame -> { kind = "actionbar" | "castborn", button = action button, duration = captured }
CooldownText.entries = setmetatable({}, { __mode = "k" })
-- cooldown frame -> Blizzard's own settings, so disabling restores them
local originals = setmetatable({}, { __mode = "k" })

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

local function DB()
    return CB.db and CB.db.cooldowntext
end

function CooldownText:IsActiveFor(entry)
    local db = DB()
    if not db or not db.enabled then return false end
    if entry.kind == "actionbar" then return db.actionBars == true end
    return db.castbornIcons == true
end

-- Text size for a button: a share of its width, never below 8
function CooldownText:TextSize(width)
    local db = DB()
    if type(width) ~= "number" or isSecret(width) or width <= 0 then width = 36 end
    return math.max(8, math.floor(width * db.textScale / 100 + 0.5))
end

-- Step curve: the colour of the last point at or below the remaining seconds
function CooldownText:BuildCurve()
    local db = DB()
    if not (C_CurveUtil and CreateColor) then
        self.curve = nil
        return
    end
    local curve = C_CurveUtil.CreateColorCurve()
    if Enum and Enum.LuaCurveType then curve:SetType(Enum.LuaCurveType.Step) end
    local s, m, l = db.shortColor, db.mediumColor, db.longColor
    curve:AddPoint(0, CreateColor(s[1], s[2], s[3], s[4]))
    curve:AddPoint(SHORT_SECONDS, CreateColor(m[1], m[2], m[3], m[4]))
    curve:AddPoint(LONG_SECONDS, CreateColor(l[1], l[2], l[3], l[4]))
    self.curve = curve
end

local function Remember(cooldown, fs)
    if originals[cooldown] then return end
    local path, size, flags = fs:GetFont()
    originals[cooldown] = {
        font = { path, size, flags },
        color = { fs:GetTextColor() },
        minimum = cooldown:GetMinimumCountdownDuration(),
        decimals = cooldown:GetCountdownMillisecondsThreshold(),
    }
end

function CooldownText:Style(cooldown)
    local entry = self.entries[cooldown]
    local fs = entry and cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
    if not fs then return end
    Remember(cooldown, fs)

    if not self:IsActiveFor(entry) then
        local o = originals[cooldown]
        if o.font[1] then fs:SetFont(o.font[1], o.font[2], o.font[3]) end
        fs:SetTextColor(o.color[1], o.color[2], o.color[3], o.color[4])
        cooldown:SetMinimumCountdownDuration(o.minimum)
        cooldown:SetCountdownMillisecondsThreshold(o.decimals)
        return
    end

    local db = DB()
    local owner = cooldown:GetParent()
    fs:SetFont(CB:GetBarFont(), self:TextSize(owner and owner:GetWidth()), db.outline and "OUTLINE" or "")
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", cooldown, "CENTER", 0, 0)
    cooldown:SetMinimumCountdownDuration(math.floor(db.minDuration * 1000))
    cooldown:SetCountdownMillisecondsThreshold(db.decimalsBelow)
    local c = db.longColor
    fs:SetTextColor(c[1], c[2], c[3], c[4])
    if entry.kind == "castborn" then cooldown:SetHideCountdownNumbers(false) end
end

-- The duration object behind a cooldown's countdown, if one can be had
function CooldownText:DurationFor(entry)
    if entry.kind == "actionbar" then
        -- LibActionButton buttons (Bartender4) know their own duration
        if entry.button and entry.button.GetCooldownDuration then
            return entry.button:GetCooldownDuration()
        end
        local action = entry.button and entry.button.action
        if type(action) ~= "number" or not (C_ActionBar and C_ActionBar.GetActionCooldownDuration) then
            return nil
        end
        return C_ActionBar.GetActionCooldownDuration(action)
    end
    return entry.duration
end

function CooldownText:Recolour(cooldown)
    local entry = self.entries[cooldown]
    if not entry or not self.curve or not self:IsActiveFor(entry) or not DB().colorStages then return end
    local duration = self:DurationFor(entry)
    if not duration then return end
    local fs = cooldown:GetCountdownFontString()
    local ok, colour = pcall(duration.EvaluateRemainingDuration, duration, self.curve)
    if ok and colour then
        fs:SetTextColor(colour:GetRGBA())
    elseif not ok then
        self.lastError = tostring(colour)  -- reported by /cbcdt
    end
end

function CooldownText:RecolourAll()
    self.ticks = (self.ticks or 0) + 1
    for cooldown in pairs(self.entries) do
        if cooldown:IsVisible() then self:Recolour(cooldown) end
    end
end

-- Castborn icons: keep the duration behind whatever the module last put on the cooldown
local function CaptureDurations(cooldown)
    hooksecurefunc(cooldown, "SetCooldownFromDurationObject", function(self, duration)
        local entry = CooldownText.entries[self]
        if entry then entry.duration = duration end
    end)
    hooksecurefunc(cooldown, "SetCooldown", function(self, start, length)
        local entry = CooldownText.entries[self]
        if not entry then return end
        entry.duration = nil
        if isSecret(start) or isSecret(length) or not (C_DurationUtil and C_DurationUtil.CreateDuration) then return end
        local duration = C_DurationUtil.CreateDuration()
        duration:SetTimeFromStart(start, length)
        entry.duration = duration
    end)
    hooksecurefunc(cooldown, "Clear", function(self)
        local entry = CooldownText.entries[self]
        if entry then entry.duration = nil end
    end)
end

function CooldownText:Register(cooldown, kind, button)
    if not cooldown or self.entries[cooldown] then return end
    self.entries[cooldown] = { kind = kind, button = button }
    if kind == "castborn" then
        CaptureDurations(cooldown)
        -- Tracker icons resize from their options; keep the text in proportion
        local owner = cooldown:GetParent()
        if owner then
            owner:HookScript("OnSizeChanged", function()
                if CooldownText.ready then CooldownText:Style(cooldown) end
            end)
        end
    end
    if self.ready then self:Style(cooldown) end
end

function CooldownText:RegisterActionButtons()
    for _, bar in ipairs(ACTION_BARS) do
        for i = 1, bar.count do
            local button = _G[bar.prefix .. i]
            if button and button.cooldown then
                self:Register(button.cooldown, "actionbar", button)
            end
        end
    end
end

-- Bartender4 and other bar addons build their buttons with LibActionButton-1.0, which keeps a
-- registry of every button and announces new ones
function CooldownText:RegisterLibActionButtons()
    local lab = LibStub and LibStub("LibActionButton-1.0", true)
    if not lab then return end
    for button in pairs(lab.buttonRegistry or {}) do
        if button.cooldown then self:Register(button.cooldown, "actionbar", button) end
    end
    if lab.RegisterCallback then
        lab.RegisterCallback(self, "OnButtonCreated", function(_, button)
            if button.cooldown then self:Register(button.cooldown, "actionbar", button) end
        end)
    end
end

-- Blizzard shows action bar numbers only while this CVar is on. Remember the player's own
-- setting and put it back when the feature is turned off. CVars are never touched in combat.
function CooldownText:UpdateCVar()
    if InCombatLockdown() then
        self.cvarPending = true
        return
    end
    self.cvarPending = nil
    local db = DB()
    local want = db.enabled and db.actionBars
    local current = C_CVar.GetCVar(CVAR)
    if want then
        if current ~= "1" then
            db.savedCVar = current
            C_CVar.SetCVar(CVAR, "1")
        end
    elseif db.savedCVar ~= nil then
        C_CVar.SetCVar(CVAR, db.savedCVar)
        db.savedCVar = nil
    end
end

-- Re-apply everything after an options change
function CooldownText:Apply()
    if not self.ready then return end
    self:BuildCurve()
    self:UpdateCVar()
    for cooldown in pairs(self.entries) do
        self:Style(cooldown)
    end
end

CB:RegisterCallback("COOLDOWN_FRAME_CREATED", function(cooldown)
    CooldownText:Register(cooldown, "castborn")
end)

CB:RegisterCallback("INIT", function()
    CastbornDB.cooldowntext = CB:MergeDefaults(CastbornDB.cooldowntext or {}, CooldownText.defaults)
end)

CB:RegisterCallback("READY", function()
    CooldownText.readyStage = "started"
    CooldownText:RegisterActionButtons()
    CooldownText:RegisterLibActionButtons()
    CooldownText.readyStage = "buttons registered"
    CooldownText.ready = true
    CooldownText:Apply()
    CooldownText.readyStage = "applied"

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function()
        if CooldownText.cvarPending then CooldownText:UpdateCVar() end
    end)

    CB:CreateThrottledUpdater(RECOLOUR_INTERVAL, function()
        CooldownText:RecolourAll()
    end)
    CooldownText.readyStage = "ticker running"
end)

-- Diagnostics: run /cbcdt while an action button is cooling down, then /reload to save.
local function Describe(v)
    if CB.APICheck then return CB.APICheck:Describe(v) end
    if isSecret(v) then return "secret" end
    return type(v)
end

local function Attempt(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then return false, "error: " .. tostring(result) end
    return true, result
end

function CooldownText:Diagnose()
    local r = {
        readyStage = tostring(self.readyStage),
        ticks = self.ticks or 0,
        lastError = self.lastError or "none",
        curveUtil = C_CurveUtil and "yes" or "no",
        createColor = CreateColor and "yes" or "no",
        luaCurveType = (Enum and Enum.LuaCurveType) and "yes" or "no",
    }
    local count = 0
    for _ in pairs(self.entries) do count = count + 1 end
    r.entries = count
    local ok, err = Attempt(self.BuildCurve, self)
    r.buildCurve = ok and (self.curve and "ok" or "ok, but no curve") or err

    -- Walk the colour chain on every visible cooldown, so short and long ones can be compared
    local visible = 0
    for cooldown, entry in pairs(self.entries) do
        if cooldown:IsVisible() then
            visible = visible + 1
            local name = entry.button and entry.button.GetName and entry.button:GetName()
                or (entry.kind .. visible)
            local parts = { "kind=" .. entry.kind }
            if entry.button then parts[#parts + 1] = "action=" .. Describe(entry.button.action) end
            local okD, duration = Attempt(self.DurationFor, self, entry)
            parts[#parts + 1] = "duration=" .. (okD and Describe(duration) or duration)
            if okD and duration then
                local okT, total = Attempt(duration.GetTotalDuration, duration)
                parts[#parts + 1] = "total=" .. (okT and Describe(total) or total)
                if okT and type(total) == "number" and not isSecret(total) then
                    parts[#parts + 1] = string.format("(%.1fs)", total)
                end
                if self.curve then
                    local okE, colour = Attempt(duration.EvaluateRemainingDuration, duration, self.curve)
                    parts[#parts + 1] = "evaluate=" .. (okE and Describe(colour) or colour)
                    if okE and colour and not isSecret(colour) then
                        local okR, red, green, blue = pcall(colour.GetRGB, colour)
                        if okR and not isSecret(red) and type(red) == "number" then
                            parts[#parts + 1] = string.format("rgb=%.2f,%.2f,%.2f", red, green, blue)
                        end
                    end
                    local okRem, remaining = Attempt(duration.GetRemainingDuration, duration)
                    if okRem and type(remaining) == "number" and not isSecret(remaining) then
                        parts[#parts + 1] = string.format("remaining=%.1fs", remaining)
                    end
                end
            end
            r["cooling " .. name] = table.concat(parts, " ")
        end
    end
    r.visibleCooldowns = visible

    CastbornDB.cooldowntextDebug = r
    CB:Print("Cooldown text diagnostics (saved to CastbornDB.cooldowntextDebug, /reload to write):")
    local keys = {}
    for k in pairs(r) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do print("  " .. k .. " = " .. tostring(r[k])) end
end

SLASH_CASTBORNCDT1 = "/cbcdt"
SlashCmdList["CASTBORNCDT"] = function() CooldownText:Diagnose() end

CB:RegisterModule("CooldownText", CooldownText)

--[[
    Castborn - Beautiful Castbars for TBC Classic
    Core initialization, event bus, and utilities
]]

Castborn = Castborn or {}
local CB = Castborn

-- Addon info
CB.name = "Castborn"
CB.version = "5.2.1"

-- Module registry and event bus
CB.modules = {}
CB.callbacks = {}
CB._backdropFrames = {}
CB._barFrames = {}
CB._fontStrings = {}

-- Optional library detection
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

--------------------------------------------------------------------------------
-- Module Registration System
--------------------------------------------------------------------------------

-- Register a module with the addon
function CB:RegisterModule(name, module)
    self.modules[name] = module
    if module.OnInitialize then
        module:OnInitialize()
    end
end

-- Get a registered module by name
function CB:GetModule(name)
    return self.modules[name]
end

--------------------------------------------------------------------------------
-- Event Bus for Inter-Module Communication
--------------------------------------------------------------------------------

-- Register a callback for a custom event
function CB:RegisterCallback(event, callback)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], callback)
end

-- Fire a custom event to all registered callbacks
function CB:FireCallback(event, ...)
    if self.callbacks[event] then
        for _, callback in ipairs(self.callbacks[event]) do
            callback(...)
        end
    end
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

-- Deep copy a table
function CB:DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = self:DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- Merge defaults into destination table (dest takes priority for existing keys)
function CB:MergeDefaults(dest, src)
    for k, v in pairs(src) do
        if dest[k] == nil then
            dest[k] = self:DeepCopy(v)
        elseif type(v) == "table" and type(dest[k]) == "table" then
            self:MergeDefaults(dest[k], v)
        end
    end
    return dest
end

-- Local deep copy for internal use (preserved for backwards compatibility)
local function DeepCopy(src, dest)
    dest = dest or {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = DeepCopy(v, dest[k])
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
    return dest
end

--------------------------------------------------------------------------------
-- Player Info Cache
--------------------------------------------------------------------------------

-- Get cached player information
function CB:GetPlayerInfo()
    if not self.playerInfo then
        local _, class = UnitClass("player")
        self.playerInfo = {
            class = class,
            isManaUser = (class == "PRIEST" or class == "MAGE" or class == "WARLOCK"
                or class == "DRUID" or class == "PALADIN" or class == "SHAMAN" or class == "HUNTER"),
            isMelee = (class == "WARRIOR" or class == "ROGUE" or class == "PALADIN"
                or class == "SHAMAN" or class == "DRUID"),
            isHunter = (class == "HUNTER"),
        }
    end
    return self.playerInfo
end

--------------------------------------------------------------------------------
-- Default Settings
--------------------------------------------------------------------------------

CB.defaults = {
    locked = false,
    useClassColors = true,
    useGlobalBarColor = false,
    globalBarColor = {0.4, 0.6, 0.9, 1},
    showBorders = true,
    barTexture = "Blizzard",
    barFont = "Arial Narrow",

    player = {
        enabled = true,
        width = 250,
        height = 20,
        x = 0,
        y = -300,
        xPct = 0,
        yPct = -0.278,
        point = "CENTER",
        showIcon = true,
        showTime = true,
        showSpellName = true,
        showSpellRank = false,
        showLatency = true,
        hideBlizzardCastBar = true,
        hideTradeSkills = false,
        barColor = {0.4, 0.6, 0.9, 1},
        channelColor = {0.3, 0.8, 0.3, 1},
        bgColor = {0.1, 0.1, 0.1, 0.8},
        borderColor = {0.3, 0.3, 0.3, 1},
        textColor = {1, 1, 1, 1},
    },

    target = {
        enabled = true,
        width = 220,
        height = 16,
        x = 0,
        y = -100,
        xPct = 0,
        yPct = -0.09,
        point = "CENTER",
        showIcon = true,
        showTime = true,
        showSpellName = true,
        barColor = {0.9, 0.4, 0.4, 1},
        channelColor = {0.8, 0.6, 0.3, 1},
        bgColor = {0.1, 0.1, 0.1, 0.8},
        borderColor = {0.3, 0.3, 0.3, 1},
        textColor = {1, 1, 1, 1},
    },

    targettarget = {
        enabled = false,
        width = 180,
        height = 12,
        x = 0,
        y = -390,
        xPct = 0,
        yPct = -0.361,
        point = "CENTER",
        showIcon = true,
        showTime = true,
        showSpellName = true,
        barColor = {0.7, 0.5, 0.8, 1},
        channelColor = {0.6, 0.7, 0.5, 1},
        bgColor = {0.1, 0.1, 0.1, 0.8},
        borderColor = {0.3, 0.3, 0.3, 1},
        textColor = {1, 1, 1, 1},
    },

    focus = {
        enabled = false,
        width = 200,
        height = 16,
        x = 350,
        y = -410,
        xPct = 0.18,
        yPct = -0.380,
        point = "CENTER",
        showIcon = true,
        showTime = true,
        showSpellName = true,
        barColor = {0.3, 0.7, 0.9, 1},
        channelColor = {0.5, 0.8, 0.6, 1},
        bgColor = {0.1, 0.1, 0.1, 0.8},
        borderColor = {0.3, 0.3, 0.3, 1},
        textColor = {1, 1, 1, 1},
    },

    dots = {
        enabled = true,
        width = 200,
        height = 100,
        x = 450,
        y = -300,
        xPct = 0.234,
        yPct = -0.278,
        point = "CENTER",
        barHeight = 16,
        spacing = 2,
        showOnlyMine = true,
        bgColor = {0.05, 0.05, 0.05, 0.85},
        borderColor = {0.3, 0.3, 0.3, 1},
        anchored = false,
    },

    fsr = {
        enabled = true,
        width = 250,
        height = 4,
        anchored = true,
        x = 0,
        y = -440,
        xPct = 0,
        yPct = -0.408,
        point = "CENTER",
        activeColor = {0.2, 0.5, 0.9, 1},
        regenColor = {0.3, 0.9, 0.4, 1},
        bgColor = {0.1, 0.1, 0.1, 0.8},
        borderColor = {0.3, 0.3, 0.3, 1},
    },

    swing = {
        enabled = true,
        width = 180,
        barHeight = 10,
        spacing = 2,
        x = 0,
        y = -356,
        xPct = 0,
        yPct = -0.330,
        point = "CENTER",
        mainColor = {0.8, 0.7, 0.3, 1},
        offColor = {0.6, 0.6, 0.6, 1},
        rangedColor = {0.4, 0.7, 0.4, 1},
        bgColor = {0.1, 0.1, 0.1, 0.8},
        borderColor = {0.3, 0.3, 0.3, 1},
        anchored = false,
    },

    gcd = {
        enabled = true,
        width = 250,
        height = 4,
        x = 0,
        y = -325,
        xPct = 0,
        yPct = -0.301,
        point = "CENTER",
        alwaysShow = false,
        anchored = true,  -- Anchor to player castbar by default
        barColor = {0.9, 0.7, 0.2, 1},
        readyColor = {0.3, 0.9, 0.3, 0.6},
        bgColor = {0.05, 0.05, 0.05, 0.7},
        borderColor = {0.25, 0.25, 0.25, 1},
    },

    -- Module defaults (for reset functionality)
    interrupt = {
        enabled = true,
        width = 100,
        height = 16,
        point = "CENTER",
        x = 0,
        y = -215,
        xPct = 0,
        yPct = -0.199,
        bgColor = {0.05, 0.05, 0.05, 0.9},
    },

    procs = {
        enabled = true,
        iconSize = 28,
        spacing = 4,
        point = "CENTER",
        x = 0,
        y = -255,
        xPct = 0,
        yPct = -0.237,
        anchored = false,
    },

    cooldowns = {
        enabled = true,
        iconSize = 36,
        spacing = 4,
        point = "CENTER",
        x = -450,
        y = -300,
        xPct = -0.234,
        yPct = -0.278,
        anchored = true,
        showReadyGlow = true,
    },

    multidot = {
        enabled = true,
        width = 180,
        rowHeight = 20,
        point = "CENTER",
        x = 660,
        y = -300,
        xPct = 0.345,
        yPct = -0.278,
        bgColor = {0.05, 0.05, 0.05, 0.8},
    },

    totems = {
        enabled = true,
        width = 180,
        barHeight = 16,
        spacing = 2,
        point = "CENTER",
        x = -300,
        y = -200,
        xPct = -0.156,
        yPct = -0.185,
        bgColor = { 0.05, 0.05, 0.05, 0.85 },
        borderColor = { 0.3, 0.3, 0.3, 1 },
        showTooltip = true,
        anchored = false,
    },

    armortracker = {
        enabled = true,
        iconSize = 50,
        point = "CENTER",
        xPct = 0.05,
        yPct = -0.185,
    },
}

-- Initialize saved variables
local function InitDB()
    CastbornDB = CastbornDB or {}
    CB.db = DeepCopy(CB.defaults, CastbornDB)
    CastbornDB = CB.db

    -- Migrate bgOpacity into per-module bgColour alpha
    if CastbornDB.bgOpacity ~= nil then
        local opacity = CastbornDB.bgOpacity
        local moduleKeys = {"player", "target", "targettarget", "focus", "dots", "fsr", "swing", "gcd", "totems", "interrupt", "multidot"}
        for _, key in ipairs(moduleKeys) do
            if CastbornDB[key] and CastbornDB[key].bgColor then
                local c = CastbornDB[key].bgColor
                c[4] = (c[4] or 0.9) * opacity
            end
        end
        CastbornDB.bgOpacity = nil
    end
end

--------------------------------------------------------------------------------
-- UI Helper Functions
--------------------------------------------------------------------------------

-- Create backdrop (TBC Classic compatible)
function CB:CreateBackdrop(frame, bgColor, borderColor)
    bgColor = bgColor or {0.1, 0.1, 0.1, 0.9}
    borderColor = borderColor or {0.3, 0.3, 0.3, 1}

    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.9)
    frame.bg = bg

    -- Border using edge textures
    local borderSize = 1

    local top = frame:CreateTexture(nil, "BORDER")
    top:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", -borderSize, borderSize)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", borderSize, borderSize)
    top:SetHeight(borderSize)

    local bottom = frame:CreateTexture(nil, "BORDER")
    bottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -borderSize, -borderSize)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", borderSize, -borderSize)
    bottom:SetHeight(borderSize)

    local left = frame:CreateTexture(nil, "BORDER")
    left:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", -borderSize, borderSize)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -borderSize, -borderSize)
    left:SetWidth(borderSize)

    local right = frame:CreateTexture(nil, "BORDER")
    right:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", borderSize, borderSize)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", borderSize, -borderSize)
    right:SetWidth(borderSize)

    frame.border = {top = top, bottom = bottom, left = left, right = right}
    frame._bgColor = bgColor

    -- Track frame for border toggling
    self._backdropFrames[#self._backdropFrames + 1] = frame

    -- Hide borders if showBorders is disabled
    if CastbornDB and CastbornDB.showBorders == false then
        top:Hide()
        bottom:Hide()
        left:Hide()
        right:Hide()
    end

    return bg
end

-- Toggle border visibility on all tracked backdrop frames
function CB:UpdateBorders()
    local show = CastbornDB.showBorders ~= false
    for _, frame in ipairs(self._backdropFrames) do
        if frame.border then
            for _, tex in pairs(frame.border) do
                if show then
                    tex:Show()
                else
                    tex:Hide()
                end
            end
        end
    end
    self:FireCallback("BORDERS_CHANGED", show)
end

-- Built-in bar textures
CB.builtinTextures = {
    ["Blizzard"]  = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Smooth"]    = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
    ["Raid"]      = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    ["Flat"]      = "Interface\\Tooltips\\UI-Tooltip-Background",
}

function CB:RegisterBarFrame(bar)
    self._barFrames[bar] = true
end

function CB:GetBarTexture()
    local name = self.db and self.db.barTexture or "Blizzard"
    if self.builtinTextures[name] then
        return self.builtinTextures[name]
    end
    if LSM then
        local path = LSM:Fetch("statusbar", name)
        if path then return path end
    end
    return self.builtinTextures["Blizzard"]
end

function CB:RefreshBarTextures()
    local texture = self:GetBarTexture()
    for bar in pairs(self._barFrames) do
        bar:SetStatusBarTexture(texture)
    end
end

-- Built-in bar fonts
CB.builtinFonts = {
    ["Arial Narrow"]  = "Fonts\\ARIALN.TTF",
    ["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
    ["Morpheus"]      = "Fonts\\MORPHEUS.TTF",
    ["Skurri"]        = "Fonts\\SKURRI.TTF",
}

function CB:RegisterFontString(fs, size, flags)
    self._fontStrings[fs] = { size = size, flags = flags or "OUTLINE" }
end

function CB:GetBarFont()
    local name = self.db and self.db.barFont or "Arial Narrow"
    if self.builtinFonts[name] then
        return self.builtinFonts[name]
    end
    if LSM then
        local path = LSM:Fetch("font", name)
        if path then return path end
    end
    return self.builtinFonts["Arial Narrow"]
end

function CB:RefreshFonts()
    local fontPath = self:GetBarFont()
    for fs, info in pairs(self._fontStrings) do
        fs:SetFont(fontPath, info.size, info.flags)
    end
end

-- Refresh backgrounds on all frames
function CB:RefreshBackgrounds()
    -- Frames created with CreateBackdrop
    for _, frame in ipairs(self._backdropFrames) do
        if frame.bg and frame._bgColor then
            local c = frame._bgColor
            frame.bg:SetColorTexture(c[1], c[2], c[3], c[4] or 0.9)
        end
    end
    -- DoT tracker (separate background texture)
    if CB.dotTracker and CB.dotTracker.background then
        local cfg = CB.db.dots or {}
        local bgColor = cfg.bgColor or {0, 0, 0, 0.7}
        CB.dotTracker.background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.7)
    end
    -- Multi-DoT tracker (BackdropTemplate)
    local mdFrame = _G["Castborn_MultiDoTTracker"]
    if mdFrame then
        local mdCfg = CB.db.multidot or {}
        local bgColor = mdCfg.bgColor or {0.05, 0.05, 0.05, 0.8}
        mdFrame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.8)
    end
    -- Totem tracker (separate background texture)
    if CB.totemTracker and CB.totemTracker.background then
        local tCfg = CB.db.totems or {}
        local bgColor = tCfg.bgColor or {0, 0, 0, 0.7}
        CB.totemTracker.background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.7)
    end
end

-- Backwards compat alias
CB.RefreshBackdropOpacity = CB.RefreshBackgrounds

-- Create gradient bar texture
function CB:CreateGradientBar(parent, color)
    local bar = parent:CreateTexture(nil, "ARTWORK")
    bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")

    if color then
        local r, g, b, a = color[1], color[2], color[3], color[4] or 1
        bar:SetVertexColor(r, g, b, a)
    end

    return bar
end

-- Create spark texture for castbar
function CB:CreateSpark(parent)
    local spark = parent:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetWidth(20)
    spark:SetHeight(parent:GetHeight() * 2.5)
    spark:Hide()
    return spark
end

-- Make frame moveable
function CB:MakeMoveable(frame, dbKey)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    frame:SetScript("OnDragStart", function(self)
        if not CB.db.locked then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        -- Save position
        local point, _, _, x, y = self:GetPoint()
        if CB.db[dbKey] then
            CB.db[dbKey].point = point
            CB.db[dbKey].x = x
            CB.db[dbKey].y = y
        end
    end)
end

function CB:ApplyPosition(frame, dbKey)
    local cfg = CB.db[dbKey]
    if cfg and Castborn.Anchoring then
        Castborn.Anchoring:ApplyPosition(frame, cfg)
    end
end

-- Format time display
function CB:FormatTime(seconds)
    if seconds >= 60 then
        return string.format("%d:%02d", seconds / 60, seconds % 60)
    elseif seconds >= 10 then
        return string.format("%.0f", seconds)
    else
        return string.format("%.1f", seconds)
    end
end

-- Get class colour
function CB:GetClassColor(unit)
    if UnitExists(unit) and UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class and RAID_CLASS_COLORS[class] then
            local c = RAID_CLASS_COLORS[class]
            return c.r, c.g, c.b
        end
    end
    return 0.5, 0.5, 0.5
end

-- Print utility
function CB:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ddffCast|cffffffffborn|r: " .. tostring(msg))
end

--------------------------------------------------------------------------------
-- Test Manager
--------------------------------------------------------------------------------

CB.TestManager = {
    modules = {},
    active = false,
}

function CB.TestManager:Register(name, startFn, endFn)
    self.modules[name] = { start = startFn, stop = endFn }
end

function CB.TestManager:StartAll()
    self.active = true

    -- Unlock frames and show drag indicators
    CastbornDB.locked = false
    if CB.Anchoring then
        CB.Anchoring:ShowDragIndicators(true)
    end

    for _, module in pairs(self.modules) do
        if module.start then module.start() end
    end
end

function CB.TestManager:EndAll()
    self.active = false

    -- Lock frames and hide drag indicators
    CastbornDB.locked = true
    if CB.Anchoring then
        CB.Anchoring:HideDragIndicators(true)
    end

    for _, module in pairs(self.modules) do
        if module.stop then module.stop() end
    end
end

function CB.TestManager:IsActive()
    return self.active
end

function CB:StartTestMode()
    self.TestManager:StartAll()
end

function CB:EndTestMode()
    self.TestManager:EndAll()
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

function CB:IsSpellKnown(spellId)
    if IsSpellKnown and IsSpellKnown(spellId) then
        return true
    end
    if IsPlayerSpell and IsPlayerSpell(spellId) then
        return true
    end
    -- Fallback: check by spell name (handles multi-rank talent spells)
    local name = GetSpellInfo(spellId)
    if not name then return false end
    return GetSpellInfo(name) ~= nil
end

function CB:CreateThrottledUpdater(interval, callback)
    local frame = CreateFrame("Frame")
    local timeSinceLastUpdate = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        timeSinceLastUpdate = timeSinceLastUpdate + elapsed
        if timeSinceLastUpdate >= interval then
            callback(timeSinceLastUpdate)
            timeSinceLastUpdate = 0
        end
    end)
    return frame
end

--------------------------------------------------------------------------------
-- Main Initialization
--------------------------------------------------------------------------------

-- Main frame for events
local mainFrame = CreateFrame("Frame", "CastbornMain", UIParent)
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat

mainFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Castborn" then
        -- Initialize saved variables
        InitDB()

        -- Migrate legacy pixel positions to percentages
        if Castborn.Anchoring then
            local positionKeys = {"player", "target", "targettarget", "focus", "dots", "fsr", "swing", "gcd",
                                  "interrupt", "cooldowns", "multidot", "procs", "totems", "absorbs", "armortracker"}
            for _, key in ipairs(positionKeys) do
                if CB.db[key] then
                    Castborn.Anchoring:MigratePosition(CB.db[key])
                end
            end
        end

        -- Store optional library reference
        CB.LSM = LSM

        -- Fire INIT callback for all registered modules
        CB:FireCallback("INIT")

        CB:Print("v" .. CB.version .. " loaded. Type /cb for options.")

    elseif event == "PLAYER_LOGIN" then
        -- Legacy module initialization (for backwards compatibility)
        if CB.InitCastBars then CB:InitCastBars() end
        if CB.InitDoTTracker then CB:InitDoTTracker() end
        if CB.InitFSR then CB:InitFSR() end
        if CB.InitSwingTimers then CB:InitSwingTimers() end
        if CB.InitGCD then CB:InitGCD() end
        if CB.InitConfig then CB:InitConfig() end
        if CB.InitOptions then CB:InitOptions() end

        -- Fire READY callback after a short delay to ensure all modules loaded
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                CB:FireCallback("READY")
            end)
        else
            -- TBC fallback using OnUpdate
            local readyFrame = CreateFrame("Frame")
            local elapsed = 0
            readyFrame:SetScript("OnUpdate", function(self, delta)
                elapsed = elapsed + delta
                if elapsed >= 0.1 then
                    self:SetScript("OnUpdate", nil)
                    CB:FireCallback("READY")
                end
            end)
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Auto-lock frames when entering combat
        if not CastbornDB.locked then
            CastbornDB.locked = true
            CB:EndTestMode()
            if CB.HideTestFrames then CB:HideTestFrames() end
            if CB.Anchoring then CB.Anchoring:HideDragIndicators(true) end
            if CB.GridPosition then CB.GridPosition:HideGrid() end
        end
    end
end)

CB.eventFrame = mainFrame

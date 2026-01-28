--[[
    Castborn - Beautiful Castbars for TBC Classic
    Core initialization, event bus, and utilities
]]

Castborn = Castborn or {}
local CB = Castborn

-- Addon info
CB.name = "Castborn"
CB.version = "4.0.0"

-- Module registry and event bus
CB.modules = {}
CB.callbacks = {}

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
        showLatency = true,
        hideBlizzardCastBar = true,
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
        width = 220,
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
    },
}

-- Initialize saved variables
local function InitDB()
    CastbornDB = CastbornDB or {}
    CB.db = DeepCopy(CB.defaults, CastbornDB)
    CastbornDB = CB.db
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
    bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
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

    return bg
end

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

-- Get class color
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
    for _, module in pairs(self.modules) do
        if module.start then module.start() end
    end
end

function CB.TestManager:EndAll()
    self.active = false
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
                                  "interrupt", "cooldowns", "multidot", "procs"}
            for _, key in ipairs(positionKeys) do
                if CB.db[key] then
                    Castborn.Anchoring:MigratePosition(CB.db[key])
                end
            end
        end

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

# Castborn Overhaul Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform Castborn into a polished, feature-rich castbar addon with skinning, profiles, new tracking modules, and excellent UX for TBC Anniversary.

**Architecture:** Modular event-driven system with central Core handling initialization and inter-module communication. SkinEngine applies themes globally. Anchoring system allows modules to attach to each other. All modules are toggleable and class-intelligent.

**Tech Stack:** WoW Lua API (TBC Classic), SavedVariables for persistence, XML-free pure Lua frames.

---

## Phase 1: Foundation & Core Systems

### Task 1: Restructure File Organization

**Files:**
- Create: `Modules/` directory
- Create: `Systems/` directory
- Create: `Skins/` directory
- Create: `Data/` directory
- Modify: `Castborn.toc`

**Step 1: Create directory structure**

Create these directories:
- `Modules/`
- `Systems/`
- `Skins/`
- `Data/`

**Step 2: Move existing module files**

Move files to new locations:
- `CastBars.lua` → `Modules/CastBars.lua`
- `DoTTracker.lua` → `Modules/DoTTracker.lua`
- `FiveSecondRule.lua` → `Modules/FiveSecondRule.lua`
- `SwingTimer.lua` → `Modules/SwingTimer.lua`
- `GCDIndicator.lua` → `Modules/GCDIndicator.lua`

**Step 3: Move options to Systems**

- `Options.lua` → `Systems/Options.lua`
- `Config.lua` → `Systems/Config.lua`

**Step 4: Update Castborn.toc**

```lua
## Interface: 20504
## Title: Castborn
## Notes: Castbar addon with DoT tracking, swing timers, and more
## Author: Russell
## Version: 2.0.0
## SavedVariables: CastbornDB

Core.lua

Systems/SkinEngine.lua
Systems/Anchoring.lua
Systems/Profiles.lua
Systems/ClassDefaults.lua
Systems/GridPosition.lua

Data/SpellData.lua

Skins/Minimalist.lua
Skins/Classic.lua
Skins/Sleek.lua
Skins/Retro.lua

Modules/CastBars.lua
Modules/GCDIndicator.lua
Modules/FiveSecondRule.lua
Modules/SwingTimer.lua
Modules/DoTTracker.lua
Modules/MultiDoTTracker.lua
Modules/BuffTracker.lua
Modules/CooldownTracker.lua
Modules/InterruptTracker.lua

Systems/Options.lua
Systems/Config.lua
```

**Step 5: Verify**

Load WoW, check for Lua errors. Addon should still function (will error on missing files - expected until we create them).

---

### Task 2: Create Core.lua Event Bus & Module Registry

**Files:**
- Modify: `Core.lua`

**Step 1: Implement event bus and module registry**

```lua
-- Core.lua
Castborn = Castborn or {}
Castborn.modules = {}
Castborn.callbacks = {}

-- Module registration
function Castborn:RegisterModule(name, module)
    self.modules[name] = module
    if module.OnInitialize then
        module:OnInitialize()
    end
end

function Castborn:GetModule(name)
    return self.modules[name]
end

-- Event bus for inter-module communication
function Castborn:RegisterCallback(event, callback)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], callback)
end

function Castborn:FireCallback(event, ...)
    if self.callbacks[event] then
        for _, callback in ipairs(self.callbacks[event]) do
            callback(...)
        end
    end
end

-- Utility: Deep copy tables
function Castborn:DeepCopy(orig)
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

-- Utility: Merge tables (dest takes priority for existing keys)
function Castborn:MergeDefaults(dest, src)
    for k, v in pairs(src) do
        if dest[k] == nil then
            dest[k] = self:DeepCopy(v)
        elseif type(v) == "table" and type(dest[k]) == "table" then
            self:MergeDefaults(dest[k], v)
        end
    end
    return dest
end

-- Player info cache
function Castborn:GetPlayerInfo()
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

-- Main initialization
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Castborn" then
        -- Initialize saved variables
        CastbornDB = CastbornDB or {}

        -- Fire init callback for all registered modules
        Castborn:FireCallback("INIT")

        -- Fire ready callback after a short delay to ensure all modules loaded
        C_Timer.After(0.1, function()
            Castborn:FireCallback("READY")
        end)
    end
end)

-- Expose frame for other modules
Castborn.eventFrame = frame
```

**Step 2: Verify**

`/reload` - no errors expected.

---

### Task 3: Create Anchoring System

**Files:**
- Create: `Systems/Anchoring.lua`

**Step 1: Implement anchoring system**

```lua
-- Systems/Anchoring.lua
local Anchoring = {}
Castborn.Anchoring = Anchoring

-- Store anchor relationships
Anchoring.anchors = {}

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

    -- Get current position before detaching
    local point, _, relPoint, x, y = frame:GetPoint()

    frame:ClearAllPoints()
    frame:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or x, db.y or y)

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

-- Make a frame draggable (when unlocked)
function Anchoring:MakeDraggable(frame, db, onDragStop)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        if not CastbornDB.locked then
            -- Detach if anchored
            if self.isAnchored then
                Anchoring:Detach(self, db)
            end
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, _, x, y = self:GetPoint()
        db.point = point
        db.x = x
        db.y = y
        db.anchored = false

        if onDragStop then
            onDragStop(self)
        end
    end)
end

Castborn:RegisterCallback("INIT", function()
    -- Initialize anchoring after DB is ready
end)
```

**Step 2: Verify**

`/reload` - no errors expected.

---

### Task 4: Create Skin Engine

**Files:**
- Create: `Systems/SkinEngine.lua`

**Step 1: Implement skin engine**

```lua
-- Systems/SkinEngine.lua
local SkinEngine = {}
Castborn.SkinEngine = SkinEngine

SkinEngine.skins = {}
SkinEngine.registeredFrames = {}
SkinEngine.currentSkin = "minimalist"

-- Register a skin definition
function SkinEngine:RegisterSkin(name, definition)
    self.skins[name] = definition
end

-- Get current skin
function SkinEngine:GetSkin()
    return self.skins[self.currentSkin] or self.skins["minimalist"]
end

-- Get specific skin by name
function SkinEngine:GetSkinByName(name)
    return self.skins[name]
end

-- Set active skin
function SkinEngine:SetSkin(name)
    if not self.skins[name] then return end

    self.currentSkin = name
    CastbornDB.skin = name

    -- Apply to all registered frames
    self:ApplyAll()

    Castborn:FireCallback("SKIN_CHANGED", name)
end

-- Register a frame to receive skin updates
function SkinEngine:RegisterFrame(frame, frameType, applyFunc)
    table.insert(self.registeredFrames, {
        frame = frame,
        frameType = frameType,
        applyFunc = applyFunc,
    })
end

-- Apply skin to a single frame
function SkinEngine:Apply(frame, frameType)
    local skin = self:GetSkin()
    if not skin then return end

    local style = skin[frameType] or skin.bar
    if not style then return end

    -- Apply common properties
    if style.backdrop and frame.SetBackdrop then
        frame:SetBackdrop(style.backdrop)
        if style.backdropColor then
            frame:SetBackdropColor(unpack(style.backdropColor))
        end
        if style.backdropBorderColor then
            frame:SetBackdropBorderColor(unpack(style.backdropBorderColor))
        end
    end

    -- Apply bar texture
    if style.barTexture and frame.SetStatusBarTexture then
        frame:SetStatusBarTexture(style.barTexture)
    end

    -- Apply border
    if frame.border then
        local borderColor = style.borderColor or {0.3, 0.3, 0.3, 1}
        if frame.border.top then frame.border.top:SetColorTexture(unpack(borderColor)) end
        if frame.border.bottom then frame.border.bottom:SetColorTexture(unpack(borderColor)) end
        if frame.border.left then frame.border.left:SetColorTexture(unpack(borderColor)) end
        if frame.border.right then frame.border.right:SetColorTexture(unpack(borderColor)) end
    end

    -- Apply background
    if frame.bg and style.bgColor then
        frame.bg:SetColorTexture(unpack(style.bgColor))
    end
end

-- Apply skin to all registered frames
function SkinEngine:ApplyAll()
    for _, entry in ipairs(self.registeredFrames) do
        if entry.applyFunc then
            entry.applyFunc(entry.frame, self:GetSkin())
        else
            self:Apply(entry.frame, entry.frameType)
        end
    end
end

-- Helper: Create bordered frame with skin support
function SkinEngine:CreateBorderedFrame(name, parent, width, height)
    local skin = self:GetSkin()
    local style = skin and skin.bar or {}

    local frame = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    frame:SetSize(width, height)

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(unpack(style.bgColor or {0.1, 0.1, 0.1, 0.8}))

    -- Border textures (1px lines)
    frame.border = {}
    local borderColor = style.borderColor or {0.3, 0.3, 0.3, 1}
    local borderSize = style.borderSize or 1

    frame.border.top = frame:CreateTexture(nil, "BORDER")
    frame.border.top:SetColorTexture(unpack(borderColor))
    frame.border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.border.top:SetHeight(borderSize)

    frame.border.bottom = frame:CreateTexture(nil, "BORDER")
    frame.border.bottom:SetColorTexture(unpack(borderColor))
    frame.border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.border.bottom:SetHeight(borderSize)

    frame.border.left = frame:CreateTexture(nil, "BORDER")
    frame.border.left:SetColorTexture(unpack(borderColor))
    frame.border.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.border.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.border.left:SetWidth(borderSize)

    frame.border.right = frame:CreateTexture(nil, "BORDER")
    frame.border.right:SetColorTexture(unpack(borderColor))
    frame.border.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.border.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.border.right:SetWidth(borderSize)

    return frame
end

-- Helper: Create status bar with skin support
function SkinEngine:CreateStatusBar(name, parent, width, height)
    local skin = self:GetSkin()
    local style = skin and skin.bar or {}

    local container = self:CreateBorderedFrame(name, parent, width, height)

    local bar = CreateFrame("StatusBar", name .. "Bar", container)
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(style.barTexture or "Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    container.bar = bar

    -- Spark
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetSize(style.sparkWidth or 20, height * 2)
    spark:SetBlendMode("ADD")
    spark:SetPoint("CENTER", bar, "LEFT", 0, 0)
    spark:Hide()
    container.spark = spark

    return container
end

Castborn:RegisterCallback("INIT", function()
    SkinEngine.currentSkin = CastbornDB.skin or "minimalist"
end)

Castborn:RegisterCallback("READY", function()
    SkinEngine:ApplyAll()
end)
```

**Step 2: Verify**

`/reload` - no errors expected.

---

### Task 5: Create Skin Definitions

**Files:**
- Create: `Skins/Minimalist.lua`
- Create: `Skins/Classic.lua`
- Create: `Skins/Sleek.lua`
- Create: `Skins/Retro.lua`

**Step 1: Minimalist skin**

```lua
-- Skins/Minimalist.lua
Castborn.SkinEngine:RegisterSkin("minimalist", {
    name = "Minimalist Modern",
    description = "Clean, flat design with subtle transparency",

    bar = {
        barTexture = "Interface\\Buttons\\WHITE8x8",
        bgColor = {0.1, 0.1, 0.1, 0.8},
        borderColor = {0.2, 0.2, 0.2, 1},
        borderSize = 1,
        sparkWidth = 16,
        sparkAlpha = 0.6,
    },

    castbar = {
        barTexture = "Interface\\Buttons\\WHITE8x8",
        bgColor = {0.05, 0.05, 0.05, 0.9},
        borderColor = {0.15, 0.15, 0.15, 1},
        borderSize = 1,
        iconBorderColor = {0.2, 0.2, 0.2, 1},
    },

    colors = {
        cast = {0.4, 0.6, 0.9, 1},
        channel = {0.3, 0.8, 0.3, 1},
        gcd = {0.9, 0.8, 0.3, 1},
        gcdReady = {0.3, 0.7, 0.3, 1},
        fsr = {0.3, 0.5, 0.9, 1},
        fsrRegen = {0.2, 0.8, 0.4, 1},
    },

    fonts = {
        name = { font = "Fonts\\FRIZQT__.TTF", size = 11, flags = "OUTLINE" },
        time = { font = "Fonts\\FRIZQT__.TTF", size = 10, flags = "OUTLINE" },
        small = { font = "Fonts\\FRIZQT__.TTF", size = 9, flags = "OUTLINE" },
    },

    animations = {
        fadeTime = 0.3,
        pulseScale = 1.1,
        sparkTrail = false,
    },
})
```

**Step 2: Classic skin**

```lua
-- Skins/Classic.lua
Castborn.SkinEngine:RegisterSkin("classic", {
    name = "Classic WoW",
    description = "Blizzard-style textures and gold borders",

    bar = {
        barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
        bgColor = {0.15, 0.15, 0.15, 0.9},
        borderColor = {0.6, 0.5, 0.3, 1}, -- Gold
        borderSize = 2,
        sparkWidth = 20,
        sparkAlpha = 0.8,
    },

    castbar = {
        barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
        bgColor = {0.1, 0.1, 0.1, 0.95},
        borderColor = {0.6, 0.5, 0.3, 1},
        borderSize = 2,
        iconBorderColor = {0.6, 0.5, 0.3, 1},
    },

    colors = {
        cast = {1.0, 0.7, 0.0, 1}, -- Classic gold cast
        channel = {0.0, 1.0, 0.0, 1}, -- Green channel
        gcd = {1.0, 0.8, 0.0, 1},
        gcdReady = {0.0, 0.8, 0.0, 1},
        fsr = {0.0, 0.5, 1.0, 1},
        fsrRegen = {0.0, 1.0, 0.5, 1},
    },

    fonts = {
        name = { font = "Fonts\\FRIZQT__.TTF", size = 12, flags = "OUTLINE" },
        time = { font = "Fonts\\FRIZQT__.TTF", size = 11, flags = "OUTLINE" },
        small = { font = "Fonts\\FRIZQT__.TTF", size = 10, flags = "OUTLINE" },
    },

    animations = {
        fadeTime = 0.4,
        pulseScale = 1.15,
        sparkTrail = true,
    },
})
```

**Step 3: Sleek skin**

```lua
-- Skins/Sleek.lua
Castborn.SkinEngine:RegisterSkin("sleek", {
    name = "Sleek/Futuristic",
    description = "Glowing edges, gradients, modern feel",

    bar = {
        barTexture = "Interface\\AddOns\\Castborn\\Textures\\gradient", -- We'll use a simple gradient or fallback
        bgColor = {0.02, 0.02, 0.05, 0.85},
        borderColor = {0.4, 0.6, 0.9, 0.8}, -- Blue glow
        borderSize = 1,
        glowEnabled = true,
        glowColor = {0.3, 0.5, 0.9, 0.5},
        sparkWidth = 24,
        sparkAlpha = 0.9,
    },

    castbar = {
        barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
        bgColor = {0.02, 0.02, 0.08, 0.9},
        borderColor = {0.4, 0.6, 0.9, 0.9},
        borderSize = 1,
        iconBorderColor = {0.4, 0.6, 0.9, 0.8},
    },

    colors = {
        cast = {0.3, 0.6, 1.0, 1},
        channel = {0.3, 1.0, 0.6, 1},
        gcd = {0.9, 0.7, 0.2, 1},
        gcdReady = {0.2, 0.9, 0.4, 1},
        fsr = {0.4, 0.5, 1.0, 1},
        fsrRegen = {0.2, 1.0, 0.6, 1},
    },

    fonts = {
        name = { font = "Fonts\\FRIZQT__.TTF", size = 11, flags = "OUTLINE" },
        time = { font = "Fonts\\FRIZQT__.TTF", size = 10, flags = "OUTLINE" },
        small = { font = "Fonts\\FRIZQT__.TTF", size = 9, flags = "OUTLINE" },
    },

    animations = {
        fadeTime = 0.25,
        pulseScale = 1.2,
        sparkTrail = true,
    },
})
```

**Step 4: Retro skin**

```lua
-- Skins/Retro.lua
Castborn.SkinEngine:RegisterSkin("retro", {
    name = "Pixel Retro",
    description = "Sharp edges, solid colors, chunky and readable",

    bar = {
        barTexture = "Interface\\Buttons\\WHITE8x8",
        bgColor = {0.0, 0.0, 0.0, 1.0}, -- Solid black
        borderColor = {1.0, 1.0, 1.0, 1.0}, -- White border
        borderSize = 2,
        sparkWidth = 8,
        sparkAlpha = 1.0,
    },

    castbar = {
        barTexture = "Interface\\Buttons\\WHITE8x8",
        bgColor = {0.0, 0.0, 0.0, 1.0},
        borderColor = {1.0, 1.0, 1.0, 1.0},
        borderSize = 2,
        iconBorderColor = {1.0, 1.0, 1.0, 1.0},
    },

    colors = {
        cast = {0.0, 0.5, 1.0, 1}, -- Bright blue
        channel = {0.0, 1.0, 0.0, 1}, -- Bright green
        gcd = {1.0, 1.0, 0.0, 1}, -- Yellow
        gcdReady = {0.0, 1.0, 0.0, 1},
        fsr = {0.0, 0.0, 1.0, 1}, -- Blue
        fsrRegen = {0.0, 1.0, 0.0, 1}, -- Green
    },

    fonts = {
        name = { font = "Fonts\\ARIALN.TTF", size = 12, flags = "" }, -- No outline for retro feel
        time = { font = "Fonts\\ARIALN.TTF", size = 11, flags = "" },
        small = { font = "Fonts\\ARIALN.TTF", size = 10, flags = "" },
    },

    animations = {
        fadeTime = 0.0, -- Instant, no fade
        pulseScale = 1.0, -- No pulse
        sparkTrail = false,
    },
})
```

**Step 5: Verify**

`/reload` - check that addon loads without errors.

---

### Task 6: Create Profile System

**Files:**
- Create: `Systems/Profiles.lua`

**Step 1: Implement profile manager**

```lua
-- Systems/Profiles.lua
local Profiles = {}
Castborn.Profiles = Profiles

local DEFAULT_PROFILE_NAME = "Default"

function Profiles:GetCurrentProfileName()
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    return CastbornDB.profileKeys and CastbornDB.profileKeys[charKey] or DEFAULT_PROFILE_NAME
end

function Profiles:SetCurrentProfile(profileName)
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    CastbornDB.profileKeys = CastbornDB.profileKeys or {}
    CastbornDB.profileKeys[charKey] = profileName

    -- Apply the profile
    self:ApplyProfile(profileName)
end

function Profiles:GetProfile(profileName)
    CastbornDB.profiles = CastbornDB.profiles or {}
    return CastbornDB.profiles[profileName]
end

function Profiles:GetCurrentProfile()
    return self:GetProfile(self:GetCurrentProfileName())
end

function Profiles:SaveCurrentToProfile(profileName)
    CastbornDB.profiles = CastbornDB.profiles or {}

    -- Copy current settings (excluding profile metadata)
    local profile = {}
    for k, v in pairs(CastbornDB) do
        if k ~= "profiles" and k ~= "profileKeys" then
            profile[k] = Castborn:DeepCopy(v)
        end
    end

    CastbornDB.profiles[profileName] = profile
end

function Profiles:ApplyProfile(profileName)
    local profile = self:GetProfile(profileName)
    if not profile then return end

    -- Apply profile settings to current DB
    for k, v in pairs(profile) do
        if k ~= "profiles" and k ~= "profileKeys" then
            CastbornDB[k] = Castborn:DeepCopy(v)
        end
    end

    -- Notify modules to refresh
    Castborn:FireCallback("PROFILE_CHANGED", profileName)
    Castborn:FireCallback("SETTINGS_CHANGED")
end

function Profiles:CreateProfile(profileName, copyFrom)
    CastbornDB.profiles = CastbornDB.profiles or {}

    if copyFrom and CastbornDB.profiles[copyFrom] then
        CastbornDB.profiles[profileName] = Castborn:DeepCopy(CastbornDB.profiles[copyFrom])
    else
        -- Create from current settings
        self:SaveCurrentToProfile(profileName)
    end
end

function Profiles:DeleteProfile(profileName)
    if profileName == DEFAULT_PROFILE_NAME then return end -- Can't delete default

    CastbornDB.profiles = CastbornDB.profiles or {}
    CastbornDB.profiles[profileName] = nil

    -- Switch anyone using this profile to default
    if CastbornDB.profileKeys then
        for charKey, profile in pairs(CastbornDB.profileKeys) do
            if profile == profileName then
                CastbornDB.profileKeys[charKey] = DEFAULT_PROFILE_NAME
            end
        end
    end
end

function Profiles:GetProfileList()
    local list = { DEFAULT_PROFILE_NAME }

    if CastbornDB.profiles then
        for name in pairs(CastbornDB.profiles) do
            if name ~= DEFAULT_PROFILE_NAME then
                table.insert(list, name)
            end
        end
    end

    table.sort(list, function(a, b)
        if a == DEFAULT_PROFILE_NAME then return true end
        if b == DEFAULT_PROFILE_NAME then return false end
        return a < b
    end)

    return list
end

function Profiles:CopyProfile(fromProfile, toProfile)
    if not CastbornDB.profiles or not CastbornDB.profiles[fromProfile] then return end

    CastbornDB.profiles[toProfile] = Castborn:DeepCopy(CastbornDB.profiles[fromProfile])
end

-- Initialize on load
Castborn:RegisterCallback("INIT", function()
    CastbornDB.profiles = CastbornDB.profiles or {}
    CastbornDB.profileKeys = CastbornDB.profileKeys or {}

    -- Ensure default profile exists
    if not CastbornDB.profiles[DEFAULT_PROFILE_NAME] then
        Profiles:SaveCurrentToProfile(DEFAULT_PROFILE_NAME)
    end
end)
```

**Step 2: Verify**

`/reload` - no errors expected.

---

### Task 7: Create Class Defaults System

**Files:**
- Create: `Systems/ClassDefaults.lua`

**Step 1: Implement class defaults**

```lua
-- Systems/ClassDefaults.lua
local ClassDefaults = {}
Castborn.ClassDefaults = ClassDefaults

-- TBC-accurate class configurations
ClassDefaults.definitions = {
    MAGE = {
        fiveSecondRule = true,
        swingTimer = false,
        procs = {
            { spellId = 12536, name = "Clearcasting" }, -- Arcane Concentration
        },
        cooldowns = {
            { spellId = 12472, name = "Icy Veins" },
            { spellId = 11129, name = "Combustion" },
            { spellId = 12042, name = "Arcane Power" },
        },
    },
    WARLOCK = {
        fiveSecondRule = true,
        swingTimer = false,
        procs = {
            { spellId = 17941, name = "Nightfall" }, -- Shadow Trance
            { spellId = 34936, name = "Backlash" },
        },
        cooldowns = {},
    },
    PRIEST = {
        fiveSecondRule = true,
        swingTimer = false,
        procs = {
            { spellId = 15271, name = "Spirit Tap" },
        },
        cooldowns = {
            { spellId = 14751, name = "Inner Focus" },
        },
    },
    DRUID = {
        fiveSecondRule = true,
        swingTimer = "FERAL", -- Only in feral
        procs = {
            { spellId = 16870, name = "Clearcasting" }, -- Nature's Grace proc
        },
        cooldowns = {
            { spellId = 29166, name = "Innervate" },
        },
    },
    PALADIN = {
        fiveSecondRule = true,
        swingTimer = true,
        procs = {
            { spellId = 20050, name = "Vengeance" }, -- Stacking damage buff
        },
        cooldowns = {
            { spellId = 31884, name = "Avenging Wrath" },
        },
    },
    SHAMAN = {
        fiveSecondRule = true,
        swingTimer = "ENHANCEMENT",
        procs = {
            { spellId = 16246, name = "Clearcasting" }, -- Elemental Focus
        },
        cooldowns = {
            { spellId = 2825, name = "Bloodlust" },
        },
    },
    HUNTER = {
        fiveSecondRule = true,
        swingTimer = true,
        swingTimerRanged = true,
        procs = {},
        cooldowns = {
            { spellId = 3045, name = "Rapid Fire" },
            { spellId = 19574, name = "Bestial Wrath" },
        },
    },
    WARRIOR = {
        fiveSecondRule = false,
        swingTimer = true,
        procs = {
            { spellId = 7384, name = "Overpower", type = "ability" }, -- Overpower available
        },
        cooldowns = {
            { spellId = 1719, name = "Recklessness" },
            { spellId = 12292, name = "Death Wish" },
        },
    },
    ROGUE = {
        fiveSecondRule = false,
        swingTimer = true,
        procs = {
            { spellId = 14189, name = "Seal Fate" }, -- Extra combo point
        },
        cooldowns = {
            { spellId = 13750, name = "Adrenaline Rush" },
            { spellId = 13877, name = "Blade Flurry" },
        },
    },
}

function ClassDefaults:GetDefaults(class)
    return self.definitions[class] or {}
end

function ClassDefaults:GetPlayerDefaults()
    local info = Castborn:GetPlayerInfo()
    return self:GetDefaults(info.class)
end

function ClassDefaults:ShouldShowFSR()
    local defaults = self:GetPlayerDefaults()
    return defaults.fiveSecondRule == true
end

function ClassDefaults:ShouldShowSwingTimer()
    local defaults = self:GetPlayerDefaults()
    local info = Castborn:GetPlayerInfo()

    if defaults.swingTimer == true then
        return true
    elseif defaults.swingTimer == "FERAL" then
        -- Check if in feral form (bear or cat)
        local form = GetShapeshiftForm()
        return form == 1 or form == 3 -- Bear or Cat
    elseif defaults.swingTimer == "ENHANCEMENT" then
        -- Could check talents, but for now assume yes for shaman
        return true
    end

    return false
end

function ClassDefaults:GetSuggestedProcs()
    local defaults = self:GetPlayerDefaults()
    return defaults.procs or {}
end

function ClassDefaults:GetSuggestedCooldowns()
    local defaults = self:GetPlayerDefaults()
    return defaults.cooldowns or {}
end

-- Apply class defaults on first run
function ClassDefaults:ApplyFirstRunDefaults()
    if CastbornDB.firstRunComplete then return end

    local defaults = self:GetPlayerDefaults()

    -- Apply module enables based on class
    CastbornDB.fsr = CastbornDB.fsr or {}
    CastbornDB.fsr.enabled = self:ShouldShowFSR()

    CastbornDB.swing = CastbornDB.swing or {}
    CastbornDB.swing.enabled = self:ShouldShowSwingTimer()

    -- Set up default procs/cooldowns
    CastbornDB.buffs = CastbornDB.buffs or {}
    CastbornDB.buffs.trackedSpells = defaults.procs or {}

    CastbornDB.cooldowns = CastbornDB.cooldowns or {}
    CastbornDB.cooldowns.trackedSpells = defaults.cooldowns or {}

    CastbornDB.firstRunComplete = true

    Castborn:FireCallback("DEFAULTS_APPLIED")
end

Castborn:RegisterCallback("READY", function()
    ClassDefaults:ApplyFirstRunDefaults()
end)
```

**Step 2: Verify**

`/reload` - no errors expected.

---

### Task 8: Create Spell Data Repository

**Files:**
- Create: `Data/SpellData.lua`

**Step 1: Implement spell data**

```lua
-- Data/SpellData.lua
local SpellData = {}
Castborn.SpellData = SpellData

-- Spell school colors
SpellData.schoolColors = {
    [1] = { 1.0, 1.0, 0.5, 1 },    -- Physical (tan)
    [2] = { 1.0, 0.9, 0.5, 1 },    -- Holy (yellow)
    [4] = { 1.0, 0.5, 0.0, 1 },    -- Fire (orange)
    [8] = { 0.5, 1.0, 0.5, 1 },    -- Nature (green)
    [16] = { 0.5, 0.5, 1.0, 1 },   -- Frost (blue)
    [32] = { 0.5, 0.0, 0.5, 1 },   -- Shadow (purple)
    [64] = { 1.0, 0.5, 1.0, 1 },   -- Arcane (pink)
}

-- Class colors (standard WoW)
SpellData.classColors = {
    WARRIOR = { 0.78, 0.61, 0.43, 1 },
    PALADIN = { 0.96, 0.55, 0.73, 1 },
    HUNTER = { 0.67, 0.83, 0.45, 1 },
    ROGUE = { 1.0, 0.96, 0.41, 1 },
    PRIEST = { 1.0, 1.0, 1.0, 1 },
    SHAMAN = { 0.0, 0.44, 0.87, 1 },
    MAGE = { 0.41, 0.80, 0.94, 1 },
    WARLOCK = { 0.58, 0.51, 0.79, 1 },
    DRUID = { 1.0, 0.49, 0.04, 1 },
}

-- Interrupt abilities by class
SpellData.interrupts = {
    WARRIOR = { spellId = 6552, name = "Pummel", cooldown = 10 },
    ROGUE = { spellId = 1766, name = "Kick", cooldown = 10 },
    MAGE = { spellId = 2139, name = "Counterspell", cooldown = 24 },
    SHAMAN = { spellId = 8042, name = "Earth Shock", cooldown = 6 }, -- Also does damage
    -- Feral Druid has no interrupt in TBC
    -- Paladin has no interrupt in TBC
}

-- Known DoT spells with their colors
SpellData.dots = {
    -- Warlock
    [172] = { name = "Corruption", school = 32 },
    [348] = { name = "Immolate", school = 4 },
    [980] = { name = "Curse of Agony", school = 32 },
    [603] = { name = "Curse of Doom", school = 32 },
    [30108] = { name = "Unstable Affliction", school = 32 },
    [27243] = { name = "Seed of Corruption", school = 32 },
    [18265] = { name = "Siphon Life", school = 32 },

    -- Priest
    [589] = { name = "Shadow Word: Pain", school = 32 },
    [2944] = { name = "Devouring Plague", school = 32 },
    [15487] = { name = "Silence", school = 32 }, -- Not a DoT but tracked

    -- Druid
    [8921] = { name = "Moonfire", school = 64 },
    [93402] = { name = "Sunfire", school = 8 },
    [1822] = { name = "Rake", school = 1 },
    [1079] = { name = "Rip", school = 1 },
    [33745] = { name = "Lacerate", school = 1 },
    [5570] = { name = "Insect Swarm", school = 8 },

    -- Mage
    [133] = { name = "Fireball", school = 4 }, -- DoT component
    [11366] = { name = "Pyroblast", school = 4 }, -- DoT component

    -- Hunter
    [1978] = { name = "Serpent Sting", school = 8 },
}

function SpellData:GetSchoolColor(school)
    return self.schoolColors[school] or { 0.7, 0.7, 0.7, 1 }
end

function SpellData:GetClassColor(class)
    return self.classColors[class] or { 1, 1, 1, 1 }
end

function SpellData:GetInterrupt(class)
    return self.interrupts[class]
end

function SpellData:GetDoTInfo(spellId)
    return self.dots[spellId]
end

function SpellData:GetDoTColor(spellId)
    local info = self.dots[spellId]
    if info and info.school then
        return self:GetSchoolColor(info.school)
    end
    return { 0.7, 0.7, 0.7, 1 }
end
```

**Step 2: Verify**

`/reload` - no errors expected.

---

### Task 9: Create Grid Positioning System

**Files:**
- Create: `Systems/GridPosition.lua`

**Step 1: Implement grid overlay system**

```lua
-- Systems/GridPosition.lua
local GridPosition = {}
Castborn.GridPosition = GridPosition

GridPosition.gridFrame = nil
GridPosition.isActive = false
GridPosition.gridSize = 20

function GridPosition:CreateGrid()
    if self.gridFrame then return self.gridFrame end

    local frame = CreateFrame("Frame", "CastbornGridOverlay", UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(false)
    frame:Hide()

    frame.lines = {}
    self.gridFrame = frame

    return frame
end

function GridPosition:DrawGrid(size)
    local frame = self:CreateGrid()

    -- Clear existing lines
    for _, line in ipairs(frame.lines) do
        line:Hide()
    end
    frame.lines = {}

    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2

    -- Vertical lines
    for x = centerX, screenWidth, size do
        self:CreateLine(frame, x, 0, x, screenHeight, 0.3)
    end
    for x = centerX - size, 0, -size do
        self:CreateLine(frame, x, 0, x, screenHeight, 0.3)
    end

    -- Horizontal lines
    for y = centerY, screenHeight, size do
        self:CreateLine(frame, 0, y, screenWidth, y, 0.3)
    end
    for y = centerY - size, 0, -size do
        self:CreateLine(frame, 0, y, screenWidth, y, 0.3)
    end

    -- Center lines (brighter)
    self:CreateLine(frame, centerX, 0, centerX, screenHeight, 0.8)
    self:CreateLine(frame, 0, centerY, screenWidth, centerY, 0.8)
end

function GridPosition:CreateLine(frame, x1, y1, x2, y2, alpha)
    local line = frame:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(1, 1, 1, alpha)

    if x1 == x2 then
        -- Vertical line
        line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x1, y1)
        line:SetSize(1, y2 - y1)
    else
        -- Horizontal line
        line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x1, y1)
        line:SetSize(x2 - x1, 1)
    end

    table.insert(frame.lines, line)
    return line
end

function GridPosition:EnterPositioningMode(gridSize)
    self.gridSize = gridSize or self.gridSize
    self:DrawGrid(self.gridSize)
    self.gridFrame:Show()
    self.isActive = true

    -- Unlock all frames
    CastbornDB.locked = false

    -- Show coordinate tooltip
    self:CreateCoordinateTooltip()

    Castborn:FireCallback("POSITIONING_MODE_ENTERED")
end

function GridPosition:ExitPositioningMode()
    if self.gridFrame then
        self.gridFrame:Hide()
    end
    self.isActive = false

    -- Lock all frames
    CastbornDB.locked = true

    -- Hide coordinate tooltip
    if self.coordTooltip then
        self.coordTooltip:Hide()
    end

    Castborn:FireCallback("POSITIONING_MODE_EXITED")
end

function GridPosition:TogglePositioningMode()
    if self.isActive then
        self:ExitPositioningMode()
    else
        self:EnterPositioningMode()
    end
end

function GridPosition:SetGridSize(size)
    self.gridSize = size
    if self.isActive then
        self:DrawGrid(size)
    end
end

function GridPosition:CreateCoordinateTooltip()
    if self.coordTooltip then return end

    local tooltip = CreateFrame("Frame", "CastbornCoordTooltip", UIParent, "BackdropTemplate")
    tooltip:SetSize(120, 30)
    tooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)
    tooltip:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    tooltip:SetBackdropColor(0, 0, 0, 0.8)
    tooltip:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    tooltip:SetFrameStrata("TOOLTIP")

    tooltip.text = tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tooltip.text:SetPoint("CENTER")
    tooltip.text:SetText("X: 0  Y: 0")

    self.coordTooltip = tooltip

    -- Update on mouse move (when dragging)
    tooltip:SetScript("OnUpdate", function()
        if GridPosition.isActive and GridPosition.draggingFrame then
            local _, _, _, x, y = GridPosition.draggingFrame:GetPoint()
            tooltip.text:SetText(string.format("X: %d  Y: %d", math.floor(x or 0), math.floor(y or 0)))
        end
    end)
end

function GridPosition:SnapToGrid(x, y)
    if not CastbornDB.snapToGrid then return x, y end

    local size = self.gridSize
    return math.floor(x / size + 0.5) * size, math.floor(y / size + 0.5) * size
end

-- Track currently dragging frame
function GridPosition:SetDragging(frame)
    self.draggingFrame = frame
end

function GridPosition:ClearDragging()
    self.draggingFrame = nil
end

Castborn:RegisterCallback("INIT", function()
    CastbornDB.snapToGrid = CastbornDB.snapToGrid ~= false -- Default true
    CastbornDB.gridSize = CastbornDB.gridSize or 20
end)
```

**Step 2: Verify**

`/reload` - no errors expected.

---

## Phase 2: Refactor Existing Modules

### Task 10: Refactor Player Castbar with Anchoring Support

**Files:**
- Modify: `Modules/CastBars.lua`

**Step 1: Update castbar to support skin engine and anchoring**

This is a significant refactor. The key changes are:
1. Use SkinEngine for visuals
2. Register with Anchoring system
3. Fire callbacks for GCD/FSR to anchor to
4. Add color mode support (spell/class/custom)

I'll provide the key sections to modify rather than the entire file:

```lua
-- At the top of Modules/CastBars.lua, after the existing code that creates the frame:

-- Register with skin engine for updates
local function ApplySkinToBar(frame, skin)
    if not frame or not skin then return end
    local style = skin.castbar or skin.bar

    if frame.bar then
        frame.bar:SetStatusBarTexture(style.barTexture or "Interface\\TargetingFrame\\UI-StatusBar")
    end

    if frame.bg then
        frame.bg:SetColorTexture(unpack(style.bgColor or {0.1, 0.1, 0.1, 0.8}))
    end

    if frame.border then
        local borderColor = style.borderColor or {0.3, 0.3, 0.3, 1}
        if frame.border.top then frame.border.top:SetColorTexture(unpack(borderColor)) end
        if frame.border.bottom then frame.border.bottom:SetColorTexture(unpack(borderColor)) end
        if frame.border.left then frame.border.left:SetColorTexture(unpack(borderColor)) end
        if frame.border.right then frame.border.right:SetColorTexture(unpack(borderColor)) end
    end
end

-- After creating player castbar frame:
Castborn.SkinEngine:RegisterFrame(playerCastbar, "castbar", ApplySkinToBar)

-- Make draggable with anchoring support:
Castborn.Anchoring:MakeDraggable(playerCastbar, CastbornDB.player, function(frame)
    -- Notify anchored modules to update
    Castborn:FireCallback("PLAYER_CASTBAR_MOVED")
end)

-- Fire callback when player castbar is created so GCD/FSR can anchor
Castborn:FireCallback("PLAYER_CASTBAR_CREATED", playerCastbar)
```

**Note:** Full refactor will be done during implementation. This shows the pattern.

**Step 2: Verify**

`/reload` - test castbar still works, can be moved when unlocked.

---

### Task 11: Refactor GCD Indicator with Anchor Support

**Files:**
- Modify: `Modules/GCDIndicator.lua`

**Step 1: Add anchoring to player castbar**

Key additions:

```lua
-- Add to GCDIndicator.lua

-- Store reference to player castbar
local playerCastbar = nil

-- Listen for player castbar creation
Castborn:RegisterCallback("PLAYER_CASTBAR_CREATED", function(frame)
    playerCastbar = frame

    -- Anchor by default if setting allows
    if CastbornDB.gcd.anchored ~= false then
        Castborn.Anchoring:Anchor(gcdFrame, playerCastbar, "BOTTOM", 0, -2)
    end
end)

-- Listen for player castbar movement
Castborn:RegisterCallback("PLAYER_CASTBAR_MOVED", function()
    if CastbornDB.gcd.anchored and playerCastbar then
        -- Already anchored, position updates automatically
    end
end)

-- Add detach function
function Castborn_GCD_Detach()
    CastbornDB.gcd.anchored = false
    Castborn.Anchoring:Detach(gcdFrame, CastbornDB.gcd)
end

function Castborn_GCD_Reattach()
    if playerCastbar then
        CastbornDB.gcd.anchored = true
        Castborn.Anchoring:Anchor(gcdFrame, playerCastbar, "BOTTOM", 0, -2)
    end
end
```

**Step 2: Verify**

`/reload` - GCD should appear below player castbar by default.

---

### Task 12: Refactor Five Second Rule as Thin Pulse Line

**Files:**
- Modify: `Modules/FiveSecondRule.lua`

**Step 1: Redesign as thin pulse line anchored above castbar**

```lua
-- Replace the FSR frame creation with thin pulse line design

local function CreateFSRBar()
    local db = CastbornDB.fsr
    local skin = Castborn.SkinEngine:GetSkin()
    local colors = skin and skin.colors or {}

    -- Much thinner bar - pulse line style
    local height = db.height or 4
    local width = db.width or 220

    local frame = CreateFrame("Frame", "Castborn_FSR", UIParent)
    frame:SetSize(width, height)

    -- No border for minimal pulse line look
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.6)

    -- Progress bar
    frame.bar = CreateFrame("StatusBar", nil, frame)
    frame.bar:SetAllPoints()
    frame.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    frame.bar:SetStatusBarColor(unpack(colors.fsr or {0.3, 0.5, 0.9, 1}))
    frame.bar:SetMinMaxValues(0, 5)
    frame.bar:SetValue(0)

    -- Pulse glow effect
    frame.glow = frame:CreateTexture(nil, "OVERLAY")
    frame.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.glow:SetBlendMode("ADD")
    frame.glow:SetAllPoints()
    frame.glow:SetAlpha(0)

    -- Status text (very small, optional)
    frame.text = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame.text:SetTextColor(1, 1, 1, 0.8)

    return frame
end

-- Pulse animation when entering regen
local function PulseRegen(frame)
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local alpha = math.sin(elapsed * 4) * 0.3 + 0.2
        frame.glow:SetAlpha(alpha)
        if elapsed > 1 then
            frame:SetScript("OnUpdate", nil)
            frame.glow:SetAlpha(0)
        end
    end)
end

-- Listen for player castbar and anchor ABOVE it
Castborn:RegisterCallback("PLAYER_CASTBAR_CREATED", function(castbar)
    if CastbornDB.fsr.anchored ~= false then
        Castborn.Anchoring:Anchor(fsrFrame, castbar, "TOP", 0, 2)
    end
end)
```

**Step 2: Verify**

`/reload` - FSR should appear as thin line above player castbar.

---

## Phase 3: New Modules

### Task 13: Create Buff/Proc Tracker Module

**Files:**
- Create: `Modules/BuffTracker.lua`

**Step 1: Implement buff tracker**

```lua
-- Modules/BuffTracker.lua
local BuffTracker = {}
Castborn.BuffTracker = BuffTracker

local frame = nil
local buffFrames = {}
local MAX_BUFFS = 8

local defaults = {
    enabled = true,
    width = 200,
    iconSize = 28,
    spacing = 4,
    orientation = "HORIZONTAL", -- or "VERTICAL"
    point = "CENTER",
    x = 300,
    y = -100,
    showDuration = true,
    showStacks = true,
    trackedSpells = {}, -- Filled by ClassDefaults
    anchored = false,
}

local function CreateBuffFrame(parent, index)
    local size = CastbornDB.buffs.iconSize or 28

    local f = CreateFrame("Frame", "Castborn_Buff" .. index, parent)
    f:SetSize(size, size)

    -- Icon
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Border
    f.border = f:CreateTexture(nil, "OVERLAY")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetColorTexture(0.3, 0.3, 0.3, 1)
    f.border:SetDrawLayer("OVERLAY", -1)

    -- Duration text
    f.duration = f:CreateFontString(nil, "OVERLAY")
    f.duration:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    f.duration:SetPoint("BOTTOM", 0, -2)

    -- Stack count
    f.stacks = f:CreateFontString(nil, "OVERLAY")
    f.stacks:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    f.stacks:SetPoint("BOTTOMRIGHT", -1, 1)

    -- Glow for proc activation
    f.glow = f:CreateTexture(nil, "OVERLAY")
    f.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("TOPLEFT", -2, 2)
    f.glow:SetPoint("BOTTOMRIGHT", 2, -2)
    f.glow:SetAlpha(0)

    f:Hide()
    return f
end

local function CreateContainer()
    local db = CastbornDB.buffs

    frame = CreateFrame("Frame", "Castborn_BuffTracker", UIParent)
    frame:SetSize(db.width, db.iconSize + 4)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    -- Create buff frames
    for i = 1, MAX_BUFFS do
        buffFrames[i] = CreateBuffFrame(frame, i)
    end

    -- Make draggable
    Castborn.Anchoring:MakeDraggable(frame, db)

    -- Register with skin engine
    Castborn.SkinEngine:RegisterFrame(frame, "bar")

    return frame
end

local function UpdateLayout()
    local db = CastbornDB.buffs
    local size = db.iconSize or 28
    local spacing = db.spacing or 4
    local isHorizontal = db.orientation == "HORIZONTAL"

    for i, f in ipairs(buffFrames) do
        f:ClearAllPoints()
        f:SetSize(size, size)

        if isHorizontal then
            f:SetPoint("LEFT", frame, "LEFT", (i - 1) * (size + spacing), 0)
        else
            f:SetPoint("TOP", frame, "TOP", 0, -((i - 1) * (size + spacing)))
        end
    end
end

local function PulseGlow(buffFrame)
    local elapsed = 0
    buffFrame.glow:SetVertexColor(1, 0.8, 0.2, 1)
    buffFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local alpha = math.sin(elapsed * 6) * 0.4 + 0.4
        buffFrame.glow:SetAlpha(alpha)
        if elapsed > 0.5 then
            buffFrame:SetScript("OnUpdate", nil)
            buffFrame.glow:SetAlpha(0)
        end
    end)
end

local trackedBuffs = {}

local function ScanBuffs()
    local db = CastbornDB.buffs
    if not db.enabled then
        frame:Hide()
        return
    end

    frame:Show()

    -- Build lookup of tracked spell IDs
    local tracked = {}
    for _, spell in ipairs(db.trackedSpells or {}) do
        tracked[spell.spellId] = spell
    end

    -- Scan player buffs
    local activeBuffs = {}
    for i = 1, 40 do
        local name, icon, stacks, _, duration, expirationTime, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end

        if tracked[spellId] then
            table.insert(activeBuffs, {
                name = name,
                icon = icon,
                stacks = stacks,
                duration = duration,
                expirationTime = expirationTime,
                spellId = spellId,
                isNew = not trackedBuffs[spellId],
            })
        end
    end

    -- Update tracked buffs
    local newTracked = {}
    for _, buff in ipairs(activeBuffs) do
        newTracked[buff.spellId] = true
    end
    trackedBuffs = newTracked

    -- Update display
    for i = 1, MAX_BUFFS do
        local buffFrame = buffFrames[i]
        local buff = activeBuffs[i]

        if buff then
            buffFrame.icon:SetTexture(buff.icon)

            -- Duration
            if db.showDuration and buff.expirationTime and buff.expirationTime > 0 then
                local remaining = buff.expirationTime - GetTime()
                if remaining > 0 then
                    buffFrame.duration:SetText(string.format("%.1f", remaining))
                else
                    buffFrame.duration:SetText("")
                end
            else
                buffFrame.duration:SetText("")
            end

            -- Stacks
            if db.showStacks and buff.stacks and buff.stacks > 1 then
                buffFrame.stacks:SetText(buff.stacks)
            else
                buffFrame.stacks:SetText("")
            end

            -- Pulse if new
            if buff.isNew then
                PulseGlow(buffFrame)
            end

            buffFrame:Show()
        else
            buffFrame:Hide()
        end
    end
end

-- Initialize
Castborn:RegisterCallback("INIT", function()
    CastbornDB.buffs = Castborn:MergeDefaults(CastbornDB.buffs or {}, defaults)
end)

Castborn:RegisterCallback("READY", function()
    CreateContainer()
    UpdateLayout()

    -- Register events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:SetScript("OnEvent", function(self, event, unit)
        if unit == "player" then
            ScanBuffs()
        end
    end)

    -- Initial scan
    ScanBuffs()
end)

Castborn:RegisterModule("BuffTracker", BuffTracker)
```

**Step 2: Verify**

`/reload` - buff tracker should appear if you have tracked procs for your class.

---

### Task 14: Create Cooldown Tracker Module

**Files:**
- Create: `Modules/CooldownTracker.lua`

**Step 1: Implement cooldown tracker**

```lua
-- Modules/CooldownTracker.lua
local CooldownTracker = {}
Castborn.CooldownTracker = CooldownTracker

local frame = nil
local cdFrames = {}
local MAX_COOLDOWNS = 8

local defaults = {
    enabled = true,
    iconSize = 32,
    spacing = 4,
    point = "CENTER",
    x = -300,
    y = -100,
    showTime = true,
    trackedSpells = {}, -- Filled by ClassDefaults
}

local function CreateCooldownFrame(parent, index)
    local size = CastbornDB.cooldowns.iconSize or 32

    local f = CreateFrame("Frame", "Castborn_CD" .. index, parent)
    f:SetSize(size, size)

    -- Icon
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Cooldown sweep
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    f.cooldown:SetDrawEdge(true)
    f.cooldown:SetHideCountdownNumbers(false)

    -- Border
    f.border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Time text (for when not using sweep)
    f.time = f:CreateFontString(nil, "OVERLAY")
    f.time:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    f.time:SetPoint("CENTER")

    -- Ready glow
    f.glow = f:CreateTexture(nil, "OVERLAY")
    f.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("TOPLEFT", -3, 3)
    f.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    f.glow:SetVertexColor(0.2, 1, 0.2, 0)

    f:Hide()
    return f
end

local function CreateContainer()
    local db = CastbornDB.cooldowns

    frame = CreateFrame("Frame", "Castborn_CooldownTracker", UIParent)
    frame:SetSize(db.iconSize * MAX_COOLDOWNS + db.spacing * (MAX_COOLDOWNS - 1), db.iconSize + 4)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    for i = 1, MAX_COOLDOWNS do
        cdFrames[i] = CreateCooldownFrame(frame, i)
    end

    Castborn.Anchoring:MakeDraggable(frame, db)

    return frame
end

local function UpdateLayout()
    local db = CastbornDB.cooldowns
    local size = db.iconSize or 32
    local spacing = db.spacing or 4

    for i, f in ipairs(cdFrames) do
        f:ClearAllPoints()
        f:SetSize(size, size)
        f:SetPoint("LEFT", frame, "LEFT", (i - 1) * (size + spacing), 0)
    end
end

local function FormatTime(seconds)
    if seconds >= 60 then
        return string.format("%dm", math.ceil(seconds / 60))
    elseif seconds >= 10 then
        return string.format("%d", math.ceil(seconds))
    else
        return string.format("%.1f", seconds)
    end
end

local wasReady = {}

local function UpdateCooldowns()
    local db = CastbornDB.cooldowns
    if not db.enabled then
        frame:Hide()
        return
    end

    frame:Show()

    for i, spell in ipairs(db.trackedSpells or {}) do
        local cdFrame = cdFrames[i]
        if not cdFrame then break end

        local start, duration, enabled = GetSpellCooldown(spell.spellId)
        local icon = GetSpellTexture(spell.spellId)

        if icon then
            cdFrame.icon:SetTexture(icon)

            if duration and duration > 1.5 then
                -- On cooldown
                cdFrame.cooldown:SetCooldown(start, duration)
                cdFrame.icon:SetDesaturated(true)
                cdFrame.glow:SetAlpha(0)
                wasReady[spell.spellId] = false
            else
                -- Ready
                cdFrame.cooldown:Clear()
                cdFrame.icon:SetDesaturated(false)

                -- Pulse glow when becoming ready
                if wasReady[spell.spellId] == false then
                    -- Animate glow
                    local elapsed = 0
                    cdFrame:SetScript("OnUpdate", function(self, delta)
                        elapsed = elapsed + delta
                        local alpha = math.sin(elapsed * 6) * 0.4 + 0.3
                        cdFrame.glow:SetAlpha(alpha)
                        if elapsed > 0.75 then
                            cdFrame:SetScript("OnUpdate", nil)
                            cdFrame.glow:SetAlpha(0)
                        end
                    end)
                end
                wasReady[spell.spellId] = true
            end

            cdFrame:Show()
        else
            cdFrame:Hide()
        end
    end

    -- Hide unused frames
    for i = #(db.trackedSpells or {}) + 1, MAX_COOLDOWNS do
        if cdFrames[i] then
            cdFrames[i]:Hide()
        end
    end
end

-- Initialize
Castborn:RegisterCallback("INIT", function()
    CastbornDB.cooldowns = Castborn:MergeDefaults(CastbornDB.cooldowns or {}, defaults)
end)

Castborn:RegisterCallback("READY", function()
    CreateContainer()
    UpdateLayout()

    -- Update timer
    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            UpdateCooldowns()
            elapsed = 0
        end
    end)
end)

Castborn:RegisterModule("CooldownTracker", CooldownTracker)
```

**Step 2: Verify**

`/reload` - cooldown tracker should show your class's suggested cooldowns.

---

### Task 15: Create Interrupt Tracker Module

**Files:**
- Create: `Modules/InterruptTracker.lua`

**Step 1: Implement interrupt tracker**

```lua
-- Modules/InterruptTracker.lua
local InterruptTracker = {}
Castborn.InterruptTracker = InterruptTracker

local frame = nil
local lockoutFrame = nil

local defaults = {
    enabled = true,
    width = 100,
    height = 16,
    point = "CENTER",
    x = 0,
    y = -280,
    showLockout = true,
}

local function CreateInterruptBar()
    local db = CastbornDB.interrupt
    local playerClass = select(2, UnitClass("player"))
    local interruptInfo = Castborn.SpellData:GetInterrupt(playerClass)

    if not interruptInfo then
        -- Class has no interrupt
        return nil
    end

    frame = Castborn.SkinEngine:CreateStatusBar("Castborn_Interrupt", UIParent, db.width, db.height)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    -- Icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(db.height, db.height)
    frame.icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.icon:SetTexture(GetSpellTexture(interruptInfo.spellId))
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Adjust bar to account for icon
    frame.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", db.height + 2, -1)

    -- Time text
    frame.time = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.time:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    frame.time:SetPoint("CENTER")

    -- Ready text
    frame.ready = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.ready:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    frame.ready:SetPoint("CENTER")
    frame.ready:SetText("READY")
    frame.ready:SetTextColor(0.2, 1, 0.2, 1)
    frame.ready:Hide()

    frame.interruptInfo = interruptInfo

    Castborn.Anchoring:MakeDraggable(frame, db)

    return frame
end

local function CreateLockoutDisplay()
    local db = CastbornDB.interrupt

    lockoutFrame = CreateFrame("Frame", "Castborn_Lockout", UIParent)
    lockoutFrame:SetSize(80, 20)
    lockoutFrame:SetPoint("LEFT", frame or UIParent, "RIGHT", 10, 0)

    lockoutFrame.bg = lockoutFrame:CreateTexture(nil, "BACKGROUND")
    lockoutFrame.bg:SetAllPoints()
    lockoutFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    lockoutFrame.text = lockoutFrame:CreateFontString(nil, "OVERLAY")
    lockoutFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    lockoutFrame.text:SetPoint("CENTER")

    lockoutFrame.school = nil
    lockoutFrame.expirationTime = 0

    lockoutFrame:Hide()

    return lockoutFrame
end

-- Track lockouts from combat log
local function OnCombatLogEvent(...)
    local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, _, _, extraSchool = CombatLogGetCurrentEventInfo()

    if sourceGUID ~= UnitGUID("player") then return end

    if subEvent == "SPELL_INTERRUPT" then
        -- We interrupted something
        local lockoutDuration = 4 -- Default, varies by ability

        -- Show lockout indicator
        if lockoutFrame and CastbornDB.interrupt.showLockout then
            local schoolColor = Castborn.SpellData:GetSchoolColor(extraSchool)
            lockoutFrame.text:SetText(string.format("Locked %.1fs", lockoutDuration))
            lockoutFrame.text:SetTextColor(unpack(schoolColor))
            lockoutFrame.school = extraSchool
            lockoutFrame.expirationTime = GetTime() + lockoutDuration
            lockoutFrame:Show()
        end

        -- Flash the interrupt bar
        if frame then
            local elapsed = 0
            frame:SetScript("OnUpdate", function(self, delta)
                elapsed = elapsed + delta
                local alpha = math.sin(elapsed * 10) * 0.5 + 0.5
                if elapsed > 0.3 then
                    frame:SetScript("OnUpdate", nil)
                    return
                end
            end)
        end
    end
end

local function UpdateInterruptCooldown()
    if not frame or not frame.interruptInfo then return end

    local db = CastbornDB.interrupt
    if not db.enabled then
        frame:Hide()
        return
    end

    frame:Show()

    local start, duration = GetSpellCooldown(frame.interruptInfo.spellId)

    if duration and duration > 1.5 then
        -- On cooldown
        local remaining = (start + duration) - GetTime()
        frame.bar:SetMinMaxValues(0, duration)
        frame.bar:SetValue(remaining)
        frame.bar:SetStatusBarColor(0.8, 0.3, 0.3, 1)
        frame.time:SetText(string.format("%.1f", remaining))
        frame.time:Show()
        frame.ready:Hide()
        frame.icon:SetDesaturated(true)
    else
        -- Ready
        frame.bar:SetMinMaxValues(0, 1)
        frame.bar:SetValue(1)
        frame.bar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
        frame.time:Hide()
        frame.ready:Show()
        frame.icon:SetDesaturated(false)
    end
end

local function UpdateLockout()
    if not lockoutFrame then return end

    if lockoutFrame.expirationTime > GetTime() then
        local remaining = lockoutFrame.expirationTime - GetTime()
        lockoutFrame.text:SetText(string.format("Locked %.1fs", remaining))
    else
        lockoutFrame:Hide()
    end
end

-- Initialize
Castborn:RegisterCallback("INIT", function()
    CastbornDB.interrupt = Castborn:MergeDefaults(CastbornDB.interrupt or {}, defaults)
end)

Castborn:RegisterCallback("READY", function()
    CreateInterruptBar()
    CreateLockoutDisplay()

    -- Combat log for lockout tracking
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:SetScript("OnEvent", OnCombatLogEvent)

    -- Update timer
    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.05 then
            UpdateInterruptCooldown()
            UpdateLockout()
            elapsed = 0
        end
    end)
end)

Castborn:RegisterModule("InterruptTracker", InterruptTracker)
```

**Step 2: Verify**

`/reload` - interrupt tracker should show for classes with interrupts.

---

### Task 16: Create Multi-DoT Tracker Module

**Files:**
- Create: `Modules/MultiDoTTracker.lua`

**Step 1: Implement multi-target DoT tracker**

```lua
-- Modules/MultiDoTTracker.lua
local MultiDoTTracker = {}
Castborn.MultiDoTTracker = MultiDoTTracker

local frame = nil
local targetFrames = {}
local MAX_TARGETS = 5

local defaults = {
    enabled = true,
    displayMode = "panel", -- "panel", "nameplate", "grid"
    width = 180,
    rowHeight = 20,
    point = "CENTER",
    x = 350,
    y = 50,
    showCyclingIndicator = true,
}

-- Track targets and their DoTs
local trackedTargets = {} -- [guid] = { name, dots = { [spellId] = expirationTime } }

local function CreateTargetRow(parent, index)
    local db = CastbornDB.multidot

    local row = CreateFrame("Frame", "Castborn_MultiDoT_Row" .. index, parent)
    row:SetSize(db.width, db.rowHeight)

    -- Background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.7)

    -- Target name
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetWidth(60)
    row.name:SetJustifyH("LEFT")

    -- DoT icons container
    row.dots = {}
    for i = 1, 6 do
        local dot = CreateFrame("Frame", nil, row)
        dot:SetSize(db.rowHeight - 4, db.rowHeight - 4)
        dot:SetPoint("LEFT", row, "LEFT", 65 + (i - 1) * (db.rowHeight - 2), 0)

        dot.icon = dot:CreateTexture(nil, "ARTWORK")
        dot.icon:SetAllPoints()
        dot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        dot.time = dot:CreateFontString(nil, "OVERLAY")
        dot.time:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        dot.time:SetPoint("BOTTOM", 0, -1)

        dot:Hide()
        row.dots[i] = dot
    end

    -- Urgency indicator (colored bar on left)
    row.urgency = row:CreateTexture(nil, "OVERLAY")
    row.urgency:SetSize(3, db.rowHeight)
    row.urgency:SetPoint("LEFT", 0, 0)
    row.urgency:SetColorTexture(0.2, 0.8, 0.2, 1) -- Green = healthy

    row:Hide()
    return row
end

local function CreateContainer()
    local db = CastbornDB.multidot

    frame = CreateFrame("Frame", "Castborn_MultiDoTTracker", UIParent, "BackdropTemplate")
    frame:SetSize(db.width, db.rowHeight * MAX_TARGETS + 4)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- Header
    frame.header = frame:CreateFontString(nil, "OVERLAY")
    frame.header:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    frame.header:SetPoint("TOPLEFT", 4, -2)
    frame.header:SetText("DoT Targets")
    frame.header:SetTextColor(0.8, 0.8, 0.8, 1)

    -- Target rows
    for i = 1, MAX_TARGETS do
        local row = CreateTargetRow(frame, i)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -14 - (i - 1) * db.rowHeight)
        targetFrames[i] = row
    end

    Castborn.Anchoring:MakeDraggable(frame, db)

    return frame
end

-- Parse combat log for DoT application
local function OnCombatLogEvent()
    local _, subEvent, _, sourceGUID, _, _, _, destGUID, destName, _, _, spellId = CombatLogGetCurrentEventInfo()

    if sourceGUID ~= UnitGUID("player") then return end

    -- Check if it's a tracked DoT
    local dotInfo = Castborn.SpellData:GetDoTInfo(spellId)
    if not dotInfo then return end

    if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
        -- DoT applied
        if not trackedTargets[destGUID] then
            trackedTargets[destGUID] = {
                name = destName,
                guid = destGUID,
                dots = {},
            }
        end

        -- Get duration from buff (approximate - we'll update on scan)
        trackedTargets[destGUID].dots[spellId] = {
            expirationTime = GetTime() + 18, -- Default, updated on scan
            spellId = spellId,
            name = dotInfo.name,
        }

    elseif subEvent == "SPELL_AURA_REMOVED" then
        -- DoT removed
        if trackedTargets[destGUID] then
            trackedTargets[destGUID].dots[spellId] = nil

            -- Remove target if no more DoTs
            local hasDoTs = false
            for _ in pairs(trackedTargets[destGUID].dots) do
                hasDoTs = true
                break
            end
            if not hasDoTs then
                trackedTargets[destGUID] = nil
            end
        end

    elseif subEvent == "UNIT_DIED" then
        -- Target died
        trackedTargets[destGUID] = nil
    end
end

-- Scan target's debuffs to update expiration times
local function ScanTargetDebuffs()
    local targetGUID = UnitGUID("target")
    if not targetGUID or not trackedTargets[targetGUID] then return end

    for i = 1, 40 do
        local name, _, _, _, duration, expirationTime, source, _, _, spellId = UnitDebuff("target", i)
        if not name then break end

        if source == "player" and trackedTargets[targetGUID].dots[spellId] then
            trackedTargets[targetGUID].dots[spellId].expirationTime = expirationTime
        end
    end
end

local function GetUrgencyColor(remaining)
    if remaining <= 3 then
        return 1, 0.2, 0.2, 1 -- Red - critical
    elseif remaining <= 5 then
        return 1, 0.8, 0.2, 1 -- Yellow - soon
    else
        return 0.2, 0.8, 0.2, 1 -- Green - healthy
    end
end

local function GetSortedTargets()
    local sorted = {}

    for guid, data in pairs(trackedTargets) do
        -- Find most urgent DoT
        local minRemaining = 999
        for spellId, dot in pairs(data.dots) do
            local remaining = dot.expirationTime - GetTime()
            if remaining < minRemaining then
                minRemaining = remaining
            end
        end

        table.insert(sorted, {
            guid = guid,
            name = data.name,
            dots = data.dots,
            urgency = minRemaining,
        })
    end

    -- Sort by urgency (most urgent first)
    table.sort(sorted, function(a, b)
        return a.urgency < b.urgency
    end)

    return sorted
end

local function UpdateDisplay()
    local db = CastbornDB.multidot
    if not db.enabled or not frame then
        if frame then frame:Hide() end
        return
    end

    -- Cleanup old targets (out of range or expired)
    for guid, data in pairs(trackedTargets) do
        local allExpired = true
        for spellId, dot in pairs(data.dots) do
            if dot.expirationTime > GetTime() then
                allExpired = false
            else
                data.dots[spellId] = nil
            end
        end

        local hasDoTs = false
        for _ in pairs(data.dots) do
            hasDoTs = true
            break
        end

        if not hasDoTs then
            trackedTargets[guid] = nil
        end
    end

    -- Count active targets
    local targetCount = 0
    for _ in pairs(trackedTargets) do
        targetCount = targetCount + 1
    end

    -- Only show if 2+ targets
    if targetCount < 2 then
        frame:Hide()
        return
    end

    frame:Show()

    -- Scan current target for accurate times
    ScanTargetDebuffs()

    -- Get sorted targets
    local sorted = GetSortedTargets()

    -- Update rows
    for i = 1, MAX_TARGETS do
        local row = targetFrames[i]
        local target = sorted[i]

        if target then
            -- Truncate name
            local displayName = string.sub(target.name or "Unknown", 1, 8)
            row.name:SetText(displayName)

            -- Urgency bar
            row.urgency:SetColorTexture(GetUrgencyColor(target.urgency))

            -- Update DoT icons
            local dotIndex = 1
            for spellId, dot in pairs(target.dots) do
                local dotFrame = row.dots[dotIndex]
                if dotFrame then
                    local icon = GetSpellTexture(spellId)
                    dotFrame.icon:SetTexture(icon)

                    local remaining = dot.expirationTime - GetTime()
                    if remaining > 0 then
                        dotFrame.time:SetText(string.format("%.0f", remaining))
                        dotFrame.time:SetTextColor(GetUrgencyColor(remaining))
                    else
                        dotFrame.time:SetText("")
                    end

                    dotFrame:Show()
                    dotIndex = dotIndex + 1
                end
            end

            -- Hide unused dots
            for j = dotIndex, 6 do
                row.dots[j]:Hide()
            end

            row:Show()
        else
            row:Hide()
        end
    end
end

-- Initialize
Castborn:RegisterCallback("INIT", function()
    CastbornDB.multidot = Castborn:MergeDefaults(CastbornDB.multidot or {}, defaults)
end)

Castborn:RegisterCallback("READY", function()
    CreateContainer()

    -- Combat log events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:SetScript("OnEvent", OnCombatLogEvent)

    -- Update timer
    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            UpdateDisplay()
            elapsed = 0
        end
    end)
end)

Castborn:RegisterModule("MultiDoTTracker", MultiDoTTracker)
```

**Step 2: Verify**

`/reload` - Multi-DoT tracker appears when you have DoTs on 2+ targets.

---

## Phase 4: Options Panel Redesign

### Task 17: Create Options Widgets Library

**Files:**
- Create: `Systems/Widgets.lua`

This task creates reusable UI components (sliders, checkboxes, dropdowns, color pickers) for the options panel. Due to length, implementation will be done during execution.

---

### Task 18: Redesign Options Panel

**Files:**
- Modify: `Systems/Options.lua`

Implement the new categorized options panel with progressive disclosure. Due to length, implementation will be done during execution.

---

## Verification Checklist

After each phase, verify:

- [ ] Addon loads without Lua errors
- [ ] All existing features still work
- [ ] New features appear and function
- [ ] Frames can be moved when unlocked
- [ ] Settings persist after `/reload`
- [ ] Skins switch correctly
- [ ] Profiles save and load

---

## Commands Reference

- `/cb` or `/castborn` - Open options
- `/cb lock` - Lock frames
- `/cb unlock` - Unlock frames
- `/cb reset` - Reset positions
- `/cb test` - Show test bars
- `/cb grid` - Toggle positioning grid
- `/cb skin <name>` - Switch skin
- `/cb profile <name>` - Switch profile

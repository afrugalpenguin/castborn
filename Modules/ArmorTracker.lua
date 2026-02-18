-- Modules/ArmorTracker.lua
-- Shows an alert icon when the player's armor self-buff is missing
local ArmorTracker = {}
Castborn.ArmorTracker = ArmorTracker

local CB = Castborn

local frame = nil
local eventFrame = nil
local testModeActive = false
local lastKnownSpellId = nil  -- remembers which armor spell was last active

-- Build a fast lookup: spellId -> true, for the player's class
local armorSpellIds = {}
local armorSpellList = nil  -- reference to SpellData.armors[class]

local defaults = {
    enabled = true,
    iconSize = 50,
    point = "CENTER",
    xPct = 0.05,
    yPct = -0.185,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetArmorTexture(spellId)
    if spellId then
        return GetSpellTexture(spellId)
    end
    -- Fallback: use the highest-rank spell from the first armor group
    if armorSpellList and armorSpellList[1] then
        local ids = armorSpellList[1].spellIds
        return GetSpellTexture(ids[#ids])
    end
    return nil
end

local function ScanForArmorBuff()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if spellId and armorSpellIds[spellId] then
            return spellId
        end
    end
    return nil
end

local function UpdateArmorState()
    if not frame then return end
    if testModeActive then return end

    local db = CB.db.armortracker
    if not db or not db.enabled then
        frame:Hide()
        return
    end

    local activeSpellId = ScanForArmorBuff()

    if activeSpellId then
        -- Armor is active — remember it and hide the alert
        lastKnownSpellId = activeSpellId
        db.lastSpellId = activeSpellId
        frame:Hide()
    else
        -- Armor is missing — show alert icon
        local texture = GetArmorTexture(lastKnownSpellId)
        if texture then
            frame.icon:SetTexture(texture)
        end
        frame.icon:SetDesaturated(true)
        frame.icon:SetVertexColor(1, 0.3, 0.3, 1)
        frame:Show()
    end
end

--------------------------------------------------------------------------------
-- Frame Creation
--------------------------------------------------------------------------------

local function CreateArmorFrame()
    local db = CB.db.armortracker
    local size = db.iconSize or 36
    local hasMasque = Castborn.Masque and Castborn.Masque.enabled

    -- Button for Masque compatibility
    local f = CreateFrame("Button", "Castborn_ArmorTracker", UIParent)
    f:SetSize(size, size)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(5)

    -- Icon texture
    local icon = f:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.Icon = icon
    f.icon = icon

    -- Normal texture (border) for Masque
    local iconNormal = f:CreateTexture(nil, "BORDER")
    iconNormal:SetPoint("TOPLEFT", -1, 1)
    iconNormal:SetPoint("BOTTOMRIGHT", 1, -1)
    iconNormal:SetColorTexture(0.3, 0.3, 0.3, 1)
    f.Normal = iconNormal
    f:SetNormalTexture(iconNormal)

    -- Cooldown frame for Masque compatibility
    local iconCooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    iconCooldown:SetAllPoints()
    iconCooldown:SetDrawEdge(false)
    iconCooldown:SetHideCountdownNumbers(true)
    f.Cooldown = iconCooldown

    -- Register with Masque if available
    if hasMasque then
        Castborn.Masque:AddButton("armor", f, {
            Icon = icon,
            Cooldown = iconCooldown,
            Normal = iconNormal,
        })
    end

    -- Manual border (fallback when Masque is not active)
    if not hasMasque then
        local borderSize = 1
        local borderColor = {0.8, 0.2, 0.2, 0.9}

        local top = f:CreateTexture(nil, "OVERLAY")
        top:SetColorTexture(unpack(borderColor))
        top:SetPoint("TOPLEFT", -borderSize, borderSize)
        top:SetPoint("TOPRIGHT", borderSize, borderSize)
        top:SetHeight(borderSize)

        local bottom = f:CreateTexture(nil, "OVERLAY")
        bottom:SetColorTexture(unpack(borderColor))
        bottom:SetPoint("BOTTOMLEFT", -borderSize, -borderSize)
        bottom:SetPoint("BOTTOMRIGHT", borderSize, -borderSize)
        bottom:SetHeight(borderSize)

        local left = f:CreateTexture(nil, "OVERLAY")
        left:SetColorTexture(unpack(borderColor))
        left:SetPoint("TOPLEFT", -borderSize, borderSize)
        left:SetPoint("BOTTOMLEFT", -borderSize, -borderSize)
        left:SetWidth(borderSize)

        local right = f:CreateTexture(nil, "OVERLAY")
        right:SetColorTexture(unpack(borderColor))
        right:SetPoint("TOPRIGHT", borderSize, borderSize)
        right:SetPoint("BOTTOMRIGHT", borderSize, -borderSize)
        right:SetWidth(borderSize)

        f.borderTextures = {top, bottom, left, right}
    end

    -- "!" warning text overlay
    local warning = f:CreateFontString(nil, "OVERLAY")
    warning:SetFont("Fonts\\FRIZQT__.TTF", math.max(14, math.floor(size * 0.4)), "OUTLINE")
    warning:SetPoint("CENTER", 0, 0)
    warning:SetText("!")
    warning:SetTextColor(1, 0.2, 0.2, 1)
    f.warning = warning

    -- Positioning
    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(f, db, nil, "Armor Tracker")
    else
        CB:MakeMoveable(f, "armortracker")
    end
    CB:ApplyPosition(f, "armortracker")

    f:Hide()
    return f
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

CB:RegisterCallback("INIT", function()
    CastbornDB.armortracker = CB:MergeDefaults(CastbornDB.armortracker or {}, defaults)
end)

CB:RegisterCallback("READY", function()
    local info = CB:GetPlayerInfo()
    armorSpellList = Castborn.SpellData:GetClassArmors(info.class)

    -- No armor spells for this class — nothing to do
    if not armorSpellList then return end

    -- Build fast lookup table
    for _, group in ipairs(armorSpellList) do
        for _, id in ipairs(group.spellIds) do
            armorSpellIds[id] = true
        end
    end

    -- Restore last known spell from saved vars
    local db = CB.db.armortracker
    lastKnownSpellId = db.lastSpellId

    if not db.enabled then return end

    -- Create frame
    frame = CreateArmorFrame()

    -- Listen for aura changes
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:SetScript("OnEvent", function(self, event, unit)
        if unit == "player" then
            UpdateArmorState()
        end
    end)

    -- Initial scan
    UpdateArmorState()

    -- Register with TestManager
    CB.TestManager:Register("ArmorTracker",
        function() CB:TestArmorTracker() end,
        function() CB:EndTestArmorTracker() end
    )
end)

--------------------------------------------------------------------------------
-- Test Mode
--------------------------------------------------------------------------------

function CB:TestArmorTracker()
    if not frame and armorSpellList then
        frame = CreateArmorFrame()
    end
    if not frame then return end

    testModeActive = true

    -- Show as if armor is missing
    local testSpellId = armorSpellList and armorSpellList[#armorSpellList].spellIds[1]
    local texture = GetArmorTexture(testSpellId or lastKnownSpellId)
    if texture then
        frame.icon:SetTexture(texture)
    end
    frame.icon:SetDesaturated(true)
    frame.icon:SetVertexColor(1, 0.3, 0.3, 1)
    frame:Show()
end

function CB:EndTestArmorTracker()
    testModeActive = false
    if frame then
        UpdateArmorState()
    end
end

Castborn:RegisterModule("ArmorTracker", ArmorTracker)

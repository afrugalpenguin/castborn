-- Modules/ArmorTracker.lua
-- Shows alert icon(s) when the player's armor/blessing self-buff is missing.
-- Supports multi-slot for Paladin (blessing + Righteous Fury).
local ArmorTracker = {}
Castborn.ArmorTracker = ArmorTracker

local CB = Castborn

local eventFrame = nil
local testModeActive = false

-- slots: array of { spellIds = {id=true,...}, frame = Button, lastSpellId = number, category = string, entry = table }
local slots = {}
local armorSpellList = nil  -- reference to SpellData.armors[class]
local playerClass = nil

local defaults = {
    enabled = true,
    iconSize = 50,
    point = "CENTER",
    xPct = 0.05,
    yPct = -0.185,
    selectedBlessing = "might",
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetSlotTexture(slot)
    if slot.lastSpellId then
        return GetSpellTexture(slot.lastSpellId)
    end
    -- Fallback: first spell ID in the slot's entry list
    if slot.entry then
        local ids = slot.entry.spellIds
        if ids and ids[1] then
            return GetSpellTexture(ids[#ids])
        end
    end
    return nil
end

local function ScanForBuff(slot)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if spellId and slot.spellIds[spellId] then
            return spellId
        end
    end
    return nil
end

local function UpdateSlotState(slot)
    if not slot.frame then return end
    if testModeActive then return end

    local db = CB.db.armortracker
    if not db or not db.enabled then
        slot.frame:Hide()
        return
    end

    local activeSpellId = ScanForBuff(slot)

    if activeSpellId then
        slot.lastSpellId = activeSpellId
        slot.frame:Hide()
    else
        local texture = GetSlotTexture(slot)
        if texture then
            slot.frame.icon:SetTexture(texture)
        end
        slot.frame.icon:SetDesaturated(true)
        slot.frame.icon:SetVertexColor(1, 0.3, 0.3, 1)
        slot.frame:Show()
    end
end

local function UpdateAllSlots()
    for _, slot in ipairs(slots) do
        UpdateSlotState(slot)
    end
end

--------------------------------------------------------------------------------
-- Frame Creation
--------------------------------------------------------------------------------

local function CreateSlotFrame(index)
    local db = CB.db.armortracker
    local size = db.iconSize or 50
    local hasMasque = Castborn.Masque and Castborn.Masque.enabled
    local masqueGroup = hasMasque and Castborn.Masque.groups.armor or nil

    local frameName = "Castborn_ArmorTracker" .. (index > 1 and index or "")
    local f = Castborn:CreateMasqueButton(UIParent, frameName, size, masqueGroup, {
        iconLayer = "BACKGROUND",
    })
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(5)

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

        if CastbornDB and CastbornDB.showBorders == false then
            for _, tex in ipairs(f.borderTextures) do
                tex:Hide()
            end
        end
    end

    -- "!" warning text overlay
    local warning = f:CreateFontString(nil, "OVERLAY")
    warning:SetFont(Castborn:GetBarFont(), math.max(14, math.floor(size * 0.4)), "OUTLINE")
    Castborn:RegisterFontString(warning, math.max(14, math.floor(size * 0.4)), "OUTLINE")
    warning:SetPoint("CENTER", 0, 0)
    warning:SetText("!")
    warning:SetTextColor(1, 0.2, 0.2, 1)
    f.warning = warning

    -- Positioning: first slot uses saved position, subsequent anchor to previous
    if index == 1 then
        if Castborn.Anchoring then
            Castborn.Anchoring:MakeDraggable(f, db, nil, "Armour Tracker")
        else
            CB:MakeMoveable(f, "armortracker")
        end
        CB:ApplyPosition(f, "armortracker")
    else
        local prevFrame = slots[index - 1].frame
        f:ClearAllPoints()
        f:SetPoint("LEFT", prevFrame, "RIGHT", 4, 0)
        -- Make draggable but it moves with the first slot
        f:SetMovable(false)
    end

    f:Hide()
    return f
end

--------------------------------------------------------------------------------
-- Slot Building
--------------------------------------------------------------------------------

local function BuildSpellIdLookup(entry)
    local lookup = {}
    for _, id in ipairs(entry.spellIds) do
        lookup[id] = true
    end
    return lookup
end

local function HasImprovedRF(entry)
    if not entry.talentTab or not entry.talentIndex then return false end
    local _, _, _, _, rank = GetTalentInfo(entry.talentTab, entry.talentIndex)
    return rank and rank > 0
end

local function DestroySlot(index)
    local slot = slots[index]
    if slot and slot.frame then
        slot.frame:Hide()
        slot.frame:SetParent(nil)
    end
    tremove(slots, index)
end

local function BuildSlots()
    -- Destroy existing slots
    for i = #slots, 1, -1 do
        DestroySlot(i)
    end

    if not armorSpellList then return end

    local db = CB.db.armortracker

    if playerClass == "PALADIN" then
        -- Blessing slot: only the selected blessing's spell IDs
        local selectedKey = db.selectedBlessing or "might"
        for _, entry in ipairs(armorSpellList) do
            if entry.category == "blessing" and entry.key == selectedKey then
                local slot = {
                    spellIds = BuildSpellIdLookup(entry),
                    frame = nil,
                    lastSpellId = nil,
                    category = "blessing",
                    entry = entry,
                }
                slots[#slots + 1] = slot
                break
            end
        end

        -- RF slot: only if Improved Righteous Fury is talented
        for _, entry in ipairs(armorSpellList) do
            if entry.category == "rf" and HasImprovedRF(entry) then
                local slot = {
                    spellIds = BuildSpellIdLookup(entry),
                    frame = nil,
                    lastSpellId = nil,
                    category = "rf",
                    entry = entry,
                }
                slots[#slots + 1] = slot
                break
            end
        end
    else
        -- Non-paladin: single slot with all spell IDs pooled
        local allIds = {}
        for _, group in ipairs(armorSpellList) do
            for _, id in ipairs(group.spellIds) do
                allIds[id] = true
            end
        end
        slots[1] = {
            spellIds = allIds,
            frame = nil,
            lastSpellId = db.lastSpellId,
            category = "armor",
            entry = armorSpellList[#armorSpellList],
        }
    end

    -- Create frames for each slot
    for i, slot in ipairs(slots) do
        slot.frame = CreateSlotFrame(i)
    end
end

--- Rebuild just the blessing slot's spell ID lookup (called when dropdown changes).
function ArmorTracker:RebuildBlessingSlot()
    if playerClass ~= "PALADIN" then return end
    local db = CB.db.armortracker
    local selectedKey = db.selectedBlessing or "might"

    for _, slot in ipairs(slots) do
        if slot.category == "blessing" then
            for _, entry in ipairs(armorSpellList) do
                if entry.category == "blessing" and entry.key == selectedKey then
                    slot.spellIds = BuildSpellIdLookup(entry)
                    slot.entry = entry
                    slot.lastSpellId = nil
                    break
                end
            end
            break
        end
    end

    UpdateAllSlots()
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

CB:RegisterCallback("INIT", function()
    CastbornDB.armortracker = CB:MergeDefaults(CastbornDB.armortracker or {}, defaults)
end)

CB:RegisterCallback("READY", function()
    local info = CB:GetPlayerInfo()
    playerClass = info.class
    armorSpellList = Castborn.SpellData:GetClassArmors(playerClass)

    -- No armor spells for this class — nothing to do
    if not armorSpellList then return end

    local db = CB.db.armortracker
    if not db.enabled then return end

    -- Build slots and frames
    BuildSlots()

    -- Listen for aura changes
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" and unit == "player" then
            UpdateAllSlots()
        elseif event == "PLAYER_TALENT_UPDATE" then
            BuildSlots()
            UpdateAllSlots()
        end
    end)

    -- Paladin: also listen for talent changes (respec)
    if playerClass == "PALADIN" then
        eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    end

    -- Initial scan
    UpdateAllSlots()

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
    if #slots == 0 and armorSpellList then
        BuildSlots()
    end
    if #slots == 0 then return end

    testModeActive = true

    for _, slot in ipairs(slots) do
        if slot.frame then
            local texture = GetSlotTexture(slot)
            if texture then
                slot.frame.icon:SetTexture(texture)
            end
            slot.frame.icon:SetDesaturated(true)
            slot.frame.icon:SetVertexColor(1, 0.3, 0.3, 1)
            slot.frame:Show()
        end
    end
end

function CB:EndTestArmorTracker()
    testModeActive = false
    UpdateAllSlots()
end

-- Respond to global border visibility toggle
Castborn:RegisterCallback("BORDERS_CHANGED", function(show)
    for _, slot in ipairs(slots) do
        if slot.frame and slot.frame.borderTextures then
            for _, tex in ipairs(slot.frame.borderTextures) do
                if show then tex:Show() else tex:Hide() end
            end
        end
    end
end)

Castborn:RegisterModule("ArmorTracker", ArmorTracker)

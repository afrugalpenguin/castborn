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
    alwaysTrackRF = false,
    animateAlert = true,      -- pop when an alert appears, then pulse until the buff is back
    trackFood = true,
    foodMode = "instance",  -- "always", "instance" (dungeons and raids) or "raid"
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

-- Seams over aura reads, which Forever blocks in combat; ArmorTracker_Forever.lua overrides them.

function ArmorTracker:CanReadAuras()
    return true
end

-- Returns the spell ID of the first player buff found in the spellIds lookup, or nil
function ArmorTracker:FindPlayerBuff(spellIds)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if spellId and spellIds[spellId] then
            return spellId
        end
    end
    return nil
end

-- Whether a player buff with this name is up
function ArmorTracker:FindPlayerBuffByName(buffName)
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if name == buffName then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- Food (Well Fed)
--------------------------------------------------------------------------------

-- Whether the food reminder applies here: "always", "raid" (raids only), or by default
-- "instance" (dungeons and raids, not battlegrounds or arenas)
function ArmorTracker:FoodReminderWanted(mode)
    if mode == "always" then return true end
    local _, instanceType = IsInInstance()
    if mode == "raid" then return instanceType == "raid" end
    return instanceType == "party" or instanceType == "raid"
end

-- The Well Fed buff name in the client's language, or the English name if the client
-- does not know the spell
local wellFedName = nil
function ArmorTracker:GetWellFedName()
    local wellFed = Castborn.SpellData and Castborn.SpellData.wellFed
    if not wellFedName and wellFed then
        wellFedName = GetSpellInfo(wellFed.spellIds[1])
    end
    return wellFedName or "Well Fed"
end

-- Whether the player is Well Fed. While auras cannot be read the last answer stands, and before
-- any read the player counts as fed, so the alert never shows on a guess.
function ArmorTracker:HasWellFed()
    if self:CanReadAuras() then
        self.wellFed = self:FindPlayerBuffByName(self:GetWellFedName())
    end
    return self.wellFed ~= false
end

-- The food slot's check: true (no alert) when fed, or when the reminder does not apply here.
-- Well Fed is read first either way, so the answer is known before entering a dungeon where
-- auras may not be readable.
local function CheckFood()
    local fed = ArmorTracker:HasWellFed()
    return fed or not ArmorTracker:FoodReminderWanted(CB.db.armortracker.foodMode)
end

local function UpdateSlotState(slot)
    if not slot.frame then return end
    if testModeActive then return end

    local db = CB.db.armortracker
    if not db or not db.enabled then
        slot.frame:Hide()
        return
    end

    -- Custom check function (e.g. pet existence) or default buff scan
    local isActive
    if slot.checkFn then
        isActive = slot.checkFn()
    else
        -- When auras cannot be read (Forever in combat) the slot keeps its current state
        if not ArmorTracker:CanReadAuras() then return end
        local activeSpellId = ArmorTracker:FindPlayerBuff(slot.spellIds)
        if activeSpellId then
            slot.lastSpellId = activeSpellId
        end
        isActive = (activeSpellId ~= nil)
    end

    if isActive then
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

-- Buffs are always readable on TBC, so casts are not needed there; ArmorTracker_Forever.lua overrides it
function ArmorTracker:OnPlayerCast(spellId)
end

-- The player just cast this spell: hide the alert of any slot it buffs. Used while auras
-- cannot be read; the next readable aura check corrects the slot either way.
function ArmorTracker:MarkBuffCast(spellId)
    for _, slot in ipairs(slots) do
        if not slot.checkFn and slot.spellIds[spellId] then
            slot.lastSpellId = spellId
            if slot.frame and not testModeActive then slot.frame:Hide() end
        end
    end
end

-- Test seam: the slots list, which is otherwise local to this file
function ArmorTracker:GetSlots()
    return slots
end

--------------------------------------------------------------------------------
-- Frame Creation
--------------------------------------------------------------------------------

-- Size of the "!" warning text for an icon size
local function WarningFontSize(size)
    return math.max(14, math.floor(size * 0.4))
end

-- The glow ring texture is drawn well inside its square, so it is sized past the icon
local function GlowPadding(size)
    return math.floor(size * 0.45)
end

local POP_SCALE = 1.35
local PULSE_SCALE = 1.12
local PULSE_SECONDS = 0.6

-- The pop (grow, then settle back), the looping size pulse and the glow pulse.
-- Clients without animation groups get none, and the Start/Stop methods do nothing.
local function CreateAlertAnimation(f, size)
    local glow = f:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.2, 0.2)
    local pad = GlowPadding(size)
    glow:SetPoint("TOPLEFT", -pad, pad)
    glow:SetPoint("BOTTOMRIGHT", pad, -pad)
    glow:SetAlpha(0)
    f.glow = glow

    local pop = f:CreateAnimationGroup()
    local pulse = f:CreateAnimationGroup()
    local glowPulse = glow:CreateAnimationGroup()
    if not (pop and pulse and glowPulse) then return end

    local grow = pop:CreateAnimation("Scale")
    grow:SetScale(POP_SCALE, POP_SCALE)
    grow:SetDuration(0.12)
    grow:SetSmoothing("OUT")
    grow:SetOrder(1)
    local settle = pop:CreateAnimation("Scale")
    settle:SetScale(1 / POP_SCALE, 1 / POP_SCALE)
    settle:SetDuration(0.18)
    settle:SetSmoothing("IN_OUT")
    settle:SetOrder(2)
    pop:SetScript("OnFinished", function() ArmorTracker:OnAlertPopFinished(f) end)

    pulse:SetLooping("BOUNCE")
    local swell = pulse:CreateAnimation("Scale")
    swell:SetScale(PULSE_SCALE, PULSE_SCALE)
    swell:SetDuration(PULSE_SECONDS)
    swell:SetSmoothing("IN_OUT")

    glowPulse:SetLooping("BOUNCE")
    local shine = glowPulse:CreateAnimation("Alpha")
    shine:SetFromAlpha(0.25)
    shine:SetToAlpha(0.85)
    shine:SetDuration(PULSE_SECONDS)
    shine:SetSmoothing("IN_OUT")

    f.pop, f.pulse, f.glowPulse = pop, pulse, glowPulse
end

-- Run from the alert's OnShow, so the 0.5s rescans that re-show a shown alert do not restart it
function ArmorTracker:StartAlertAnimation(f)
    if not f.pop then return end
    self:StopAlertAnimation(f)
    local db = CB.db.armortracker
    if db and db.animateAlert then
        f.pop:Play()
    end
end

function ArmorTracker:OnAlertPopFinished(f)
    if not f.pulse or not f:IsShown() then return end
    f.pulse:Play()
    f.glowPulse:Play()
end

function ArmorTracker:StopAlertAnimation(f)
    if not f.pop then return end
    f.pop:Stop()
    f.pulse:Stop()
    f.glowPulse:Stop()
    f.glow:SetAlpha(0)
end

-- Start or stop the alerts on show to match the option (called by its checkbox)
function ArmorTracker:ApplyAlertAnimation()
    for _, slot in ipairs(slots) do
        local f = slot.frame
        if f and f:IsShown() then
            self:StartAlertAnimation(f)
        end
    end
end

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
    warning:SetFont(Castborn:GetBarFont(), WarningFontSize(size), "OUTLINE")
    Castborn:RegisterFontString(warning, WarningFontSize(size), "OUTLINE")
    warning:SetPoint("CENTER", 0, 0)
    warning:SetText("!")
    warning:SetTextColor(1, 0.2, 0.2, 1)
    f.warning = warning

    CreateAlertAnimation(f, size)
    f:HookScript("OnShow", function(self) ArmorTracker:StartAlertAnimation(self) end)
    f:HookScript("OnHide", function(self) ArmorTracker:StopAlertAnimation(self) end)

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

-- The paladin blessing to track: the saved choice, or Might if this build lacks it
-- (Blessing of Sanctuary is not on Forever)
function ArmorTracker:GetSelectedBlessing(db)
    local key = db.selectedBlessing or "might"
    if not Castborn:IsOptionAvailable("armortracker." .. key) then
        return "might"
    end
    return key
end

-- Whether the SpellData entry's talent has points; ArmorTracker_Forever.lua overrides it
function ArmorTracker:HasTalent(entry)
    if not entry.talentTab or not entry.talentIndex then return false end
    local _, _, _, _, rank = GetTalentInfo(entry.talentTab, entry.talentIndex)
    return type(rank) == "number" and rank > 0
end

-- Righteous Fury gets a reminder automatically when Improved Righteous Fury is talented
-- (a sign of tanking), or for any paladin who knows it when "always" is turned on
function ArmorTracker:ShouldTrackRighteousFury(entry, db)
    if self:HasTalent(entry) then return true end
    if not db.alwaysTrackRF then return false end
    local spellId = entry.spellIds and entry.spellIds[1]
    return spellId ~= nil and Castborn:IsSpellKnown(spellId) == true
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

    local db = CB.db.armortracker

    if not armorSpellList then
        -- No class self-buffs: only the food slot below
    elseif playerClass == "PALADIN" then
        -- Blessing slot: only the selected blessing's spell IDs
        local selectedKey = ArmorTracker:GetSelectedBlessing(db)
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
            if entry.category == "rf" and ArmorTracker:ShouldTrackRighteousFury(entry, db) then
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

        -- Aura slot: warn if no aura is active
        for _, entry in ipairs(armorSpellList) do
            if entry.category == "aura" then
                local slot = {
                    spellIds = BuildSpellIdLookup(entry),
                    frame = nil,
                    lastSpellId = nil,
                    category = "aura",
                    entry = entry,
                }
                slots[#slots + 1] = slot
                break
            end
        end
    elseif playerClass == "WARLOCK" then
        -- Armor slot: pool all non-pet spell IDs
        local allIds = {}
        local lastArmorEntry = nil
        for _, entry in ipairs(armorSpellList) do
            if entry.category ~= "pet" then
                for _, id in ipairs(entry.spellIds) do
                    allIds[id] = true
                end
                lastArmorEntry = entry
            end
        end
        slots[#slots + 1] = {
            spellIds = allIds,
            frame = nil,
            lastSpellId = db.lastSpellId,
            category = "armor",
            entry = lastArmorEntry,
        }

        -- Pet slot: alert when no pet is summoned
        local petEntry = nil
        for _, entry in ipairs(armorSpellList) do
            if entry.category == "pet" then
                petEntry = entry
                break
            end
        end
        if petEntry then
            slots[#slots + 1] = {
                spellIds = {},
                frame = nil,
                lastSpellId = nil,
                category = "pet",
                entry = petEntry,
                checkFn = function() return UnitExists("pet") end,
            }
        end
    else
        -- Other classes: single slot with all spell IDs pooled
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

    -- Food slot, for every class: alert when Well Fed is missing
    local wellFed = Castborn.SpellData and Castborn.SpellData.wellFed
    if db.trackFood and wellFed then
        slots[#slots + 1] = {
            spellIds = {},
            frame = nil,
            lastSpellId = nil,
            category = "food",
            entry = wellFed,
            checkFn = CheckFood,
        }
    end

    -- Create frames for each slot
    for i, slot in ipairs(slots) do
        slot.frame = CreateSlotFrame(i)
    end
end

-- Resize one alert icon and its "!" warning text
function ArmorTracker:ResizeSlotFrame(f, size)
    f:SetSize(size, size)
    if f.warning then
        f.warning:SetFont(Castborn:GetBarFont(), WarningFontSize(size), "OUTLINE")
        Castborn:RegisterFontString(f.warning, WarningFontSize(size), "OUTLINE")
    end
    if f.glow then
        local pad = GlowPadding(size)
        f.glow:ClearAllPoints()
        f.glow:SetPoint("TOPLEFT", -pad, pad)
        f.glow:SetPoint("BOTTOMRIGHT", pad, -pad)
    end
end

-- Resize every alert icon (called by the options slider). Masque sizes the icon and border
-- when it skins a button, so the group is re-skinned or the new size would not show.
function ArmorTracker:ApplyIconSize(size)
    for _, slot in ipairs(slots) do
        if slot.frame then self:ResizeSlotFrame(slot.frame, size) end
    end
    if Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:ReSkin("armor")
    end
end

-- Rebuild every slot (called when the Righteous Fury or food reminder options change)
function ArmorTracker:RebuildSlots()
    if not eventFrame then return end  -- the module did not start
    BuildSlots()
    UpdateAllSlots()
end

--- Rebuild just the blessing slot's spell ID lookup (called when dropdown changes).
function ArmorTracker:RebuildBlessingSlot()
    if playerClass ~= "PALADIN" then return end
    local db = CB.db.armortracker
    local selectedKey = ArmorTracker:GetSelectedBlessing(db)

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
    -- May be nil: a class without self-buffs still gets the food slot
    armorSpellList = Castborn.SpellData:GetClassArmors(playerClass)

    if CB.db.armortracker.enabled then
        ArmorTracker:Start()
    end
end)

-- Turn the tracker on or off from the options, without a reload
function ArmorTracker:SetEnabled(enabled)
    if enabled then
        self:Start()
    else
        UpdateAllSlots()  -- every slot hides while disabled
    end
end

-- Build the alerts and start listening. Runs once; later calls just rescan.
function ArmorTracker:Start()
    if eventFrame then
        UpdateAllSlots()
        return
    end

    -- Build slots and frames
    BuildSlots()

    -- Listen for aura changes
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:SetScript("OnEvent", function(_, event, unit, _, spellId)
        if event == "UNIT_AURA" and unit == "player" then
            UpdateAllSlots()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
            ArmorTracker:OnPlayerCast(spellId)
        elseif event == "UNIT_PET" and unit == "player" then
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

    -- Warlock: also listen for pet summon/dismiss
    if playerClass == "WARLOCK" then
        eventFrame:RegisterEvent("UNIT_PET")
    end

    -- Initial scan
    UpdateAllSlots()

    -- Periodic fallback scan: UNIT_AURA can be delayed in raids with heavy
    -- aura traffic, so rescan every 0.5s to catch anything missed.
    CB:CreateThrottledUpdater(0.5, function()
        if not testModeActive and CB.db.armortracker.enabled then
            UpdateAllSlots()
        end
    end)

    -- Register with TestManager
    CB.TestManager:Register("ArmorTracker",
        function() CB:TestArmorTracker() end,
        function() CB:EndTestArmorTracker() end
    )
end

--------------------------------------------------------------------------------
-- Test Mode
--------------------------------------------------------------------------------

function CB:TestArmorTracker()
    if #slots == 0 then
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
    for _, slot in ipairs(slots) do
        if slot.frame then
            slot.frame:Hide()
        end
    end
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

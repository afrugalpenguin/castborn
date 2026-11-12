--[[
    Castborn - proc tracker on Forever
    Loaded only by Castborn_Camelot.toc, in place of ProcTracker.lua.

    Forever hides buff data from addons in combat, so Castborn never reads a proc. Blizzard's
    AuraContainer (CustomAuraContainerTemplate) draws the player's buffs into frames Castborn
    provides, filtered by spell ID: one auto-packing group inside Castborn's own strip, laid out
    as the TBC tracker lays out its icons. Nothing can be read back from it, and its buttons are
    restricted proxies, so their parts are kept here rather than on the buttons.

    Out of combat, where buffs are readable, a tracked proc's real spell ID is learned by name
    and added to the filter, so an ID this list gets wrong corrects itself.
]]

local ProcTracker = {}
Castborn.ProcTracker = ProcTracker

local GROUP_KEY = "procs"
local MAX_PROCS = 8

-- Forever buff IDs (not the talents'), from ForeverDB (foreverdb.net), build 1.60.1.70888.
-- Names must match the buff's name, which is what learning matches on, so an unverified ID
-- corrects itself the first time the proc is seen out of combat.
ProcTracker.classProcs = {
    MAGE = {
        { spellId = 12536, name = "Clearcasting" },       -- Arcane Concentration
        { spellId = 12042, name = "Arcane Power" },
        { spellId = 12043, name = "Presence of Mind" },
        { spellId = 28682, name = "Combustion" },
        { spellId = 425121, name = "Icy Veins" },
        { spellId = 400589, name = "Missile Barrage" },
        { spellId = 48108, name = "Hot Streak" },         -- unverified
    },
    WARLOCK = {
        { spellId = 17941, name = "Shadow Trance" },      -- Nightfall
        { spellId = 427713, name = "Backdraft" },         -- unverified
        { spellId = 440873, name = "Decimation" },        -- unverified
    },
    PRIEST = {
        { spellId = 14751, name = "Inner Focus" },
        { spellId = 15271, name = "Spirit Tap" },
        { spellId = 431666, name = "Surge of Light" },    -- unverified
    },
    DRUID = {
        { spellId = 16870, name = "Clearcasting" },       -- Omen of Clarity
        { spellId = 16886, name = "Nature's Grace" },
        { spellId = 17116, name = "Nature's Swiftness" },
    },
    SHAMAN = {
        { spellId = 16246, name = "Clearcasting" },       -- Elemental Focus
        { spellId = 16188, name = "Nature's Swiftness" },
        { spellId = 16257, name = "Flurry" },             -- one ID for every rank
        { spellId = 408505, name = "Maelstrom Weapon" },
    },
    PALADIN = {
        { spellId = 20050, name = "Vengeance" },          -- every talent rank puts 20050 on you
        { spellId = 20216, name = "Divine Favor" },
        { spellId = 20375, name = "Seal of Command" },    -- rank 1; other ranks are learned
        { spellId = 437063, name = "Infusion of Light" },
        { spellId = 426157, name = "The Art of War" },    -- unverified
    },
    HUNTER = {
        { spellId = 6150, name = "Quick Shots" },         -- unverified
        { spellId = 3045, name = "Rapid Fire" },
        { spellId = 415414, name = "Lock and Load" },     -- unverified
    },
    WARRIOR = {
        { spellId = 12880, name = "Enrage" },             -- one ID for every rank
        { spellId = 12966, name = "Flurry" },             -- one ID for every rank
        { spellId = 12328, name = "Death Wish" },         -- 12292 and 12328 swapped from TBC
        { spellId = 12292, name = "Sweeping Strikes" },
        { spellId = 413380, name = "Blood Surge" },       -- unverified
    },
    ROGUE = {
        { spellId = 13750, name = "Adrenaline Rush" },
        { spellId = 13877, name = "Blade Flurry" },
        { spellId = 6774, name = "Slice and Dice" },      -- rank 2; rank 1 (5171) is learned
        { spellId = 14177, name = "Cold Blood" },
    },
}

-- Trinket and other non-class procs, shared across classes. The TBC ones (Quagmirran's Eye,
-- Robe of the Elder Scribes) are not on Forever.
ProcTracker.sharedProcs = {}

-- As on TBC, so the options page and profiles work the same
local defaults = {
    enabled = true,
    width = 200,
    iconSize = 28,
    spacing = 4,
    iconsPerRow = 10,
    orientation = "HORIZONTAL",
    growDirection = "RIGHT",
    point = "CENTER",
    x = 0,
    y = -255,
    xPct = 0,
    yPct = -0.237,
    showDuration = true,
    showStacks = true,
    showGlow = true,
    showTrinketProcs = true,
    trackedSpells = {},
    anchored = false,
    learnedIds = {},
}

ProcTracker.status = "not built"
ProcTracker.masqueStatus = "not tried"

local strip              -- Castborn_ProcTracker, Castborn's own draggable frame
local container          -- Blizzard's AuraContainer, inside the strip
local buttonParts = {}   -- { button, icon, border, duration, stacks, glow, glowAnim } per button
local testFrames = {}
local testActive = false
local filterPending = false

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

local function InCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function DB() return CastbornDB.procs end

--------------------------------------------------------------------------------
-- Layout: the TBC tracker's rules, in Blizzard's flow layout terms
--------------------------------------------------------------------------------

-- Horizontal: Left grows left, Centre is a centred row, anything else grows right; one row.
-- Vertical: Up grows up, anything else down, a new column every iconsPerRow icons.
-- point is where the container sits in the strip, flowAnchor where icons start in the container.
function ProcTracker.GetLayout(db)
    local axis, dir = AnchorUtil.FlowLayoutAxis, AnchorUtil.FlowDirection
    local size = db.iconSize or 28
    local spacing = db.spacing or 4
    local grow = db.growDirection or "RIGHT"
    local layout = {
        elementWidth = size,
        elementHeight = size,
        elementSpacing = spacing,
        lineSpacing = spacing,
        maxLineSize = math.huge,
    }

    if db.orientation == "VERTICAL" then
        local perColumn = db.iconsPerRow or 10
        layout.axis = axis.Vertical
        layout.horizontal = dir.Right
        layout.maxLineSize = perColumn * size + (perColumn - 1) * spacing
        if grow == "UP" then
            layout.vertical, layout.point, layout.flowAnchor = dir.Up, "BOTTOMLEFT", "BOTTOMLEFT"
        else
            layout.vertical, layout.point, layout.flowAnchor = dir.Down, "TOPLEFT", "TOPLEFT"
        end
        return layout
    end

    layout.axis = axis.Horizontal
    layout.vertical = dir.Down
    if grow == "LEFT" then
        layout.horizontal, layout.point, layout.flowAnchor = dir.Left, "RIGHT", "TOPRIGHT"
    elseif grow == "CENTRE" then
        layout.horizontal, layout.point, layout.flowAnchor = dir.Right, "CENTER", "TOPLEFT"
    else
        layout.horizontal, layout.point, layout.flowAnchor = dir.Right, "LEFT", "TOPLEFT"
    end
    return layout
end

local function GroupLayout(layout)
    return {
        elementSpacing = layout.elementSpacing,
        lineSpacing = layout.lineSpacing,
        elementWidth = layout.elementWidth,
        elementHeight = layout.elementHeight,
    }
end

local function ApplyContainerLayout(layout)
    container:SetFlowLayoutAxis(layout.axis)
    container:SetFlowLayoutAnchorPoint(layout.flowAnchor)
    container:SetFlowLayoutGrowthDirection(layout.horizontal, layout.vertical)
    container:SetFlowLayoutMaximumLineSize(layout.maxLineSize)
    container:ClearAllPoints()
    container:SetPoint(layout.point, strip, layout.point, 0, 0)
end

--------------------------------------------------------------------------------
-- Tracked spells and the filter
--------------------------------------------------------------------------------

local function TrackedNames()
    local names = {}
    for _, spell in ipairs(DB().trackedSpells or {}) do names[spell.name] = true end
    return names
end

-- Every tracked ID plus the IDs learned for tracked names, as Blizzard's lookup table
function ProcTracker:GetFilterIds()
    local db = DB()
    local ids = {}
    for _, spell in ipairs(db.trackedSpells or {}) do
        ids[spell.spellId] = true
        for id in pairs((db.learnedIds or {})[spell.name] or {}) do ids[id] = true end
    end
    return ids
end

local function HasIds(ids)
    return next(ids) ~= nil
end

-- The group shows only while the module is on, not in test mode, and with something to match
-- (an empty filter is never handed over, in case Blizzard reads it as "anything")
local function ApplyEnabled()
    if not container then return end
    local on = DB().enabled and not testActive and HasIds(ProcTracker:GetFilterIds())
    pcall(container.SetAuraGroupEnabled, container, GROUP_KEY, on and true or false)
end

-- Filter changes wait for the end of combat
function ProcTracker:RefreshFilter()
    if not container then return end
    if InCombat() then
        filterPending = true
        return
    end
    filterPending = false
    local ids = self:GetFilterIds()
    if HasIds(ids) then
        pcall(container.SetAuraGroupCandidateFilters, container, GROUP_KEY, { includeSpellIDs = ids })
    end
    ApplyEnabled()
end

-- Load the class list on first run or a class change; otherwise drop entries whose name left the
-- list or whose ID changed, and add new ones. The same rules as the TBC tracker.
local function LoadClassList(db, playerClass)
    local classList = ProcTracker.classProcs[playerClass]
    local needsReload = #(db.trackedSpells or {}) == 0 or db.loadedForClass ~= playerClass
    if needsReload then
        db.trackedSpells = {}
        if classList then
            for _, spell in ipairs(classList) do
                db.trackedSpells[#db.trackedSpells + 1] = { spellId = spell.spellId, name = spell.name }
            end
        end
        db.loadedForClass = playerClass
    elseif classList then
        local canonical = {}
        for _, spell in ipairs(classList) do canonical[spell.name] = spell.spellId end
        local shared = {}
        for _, spell in ipairs(ProcTracker.sharedProcs) do shared[spell.spellId] = true end
        for i = #db.trackedSpells, 1, -1 do
            local saved = db.trackedSpells[i]
            if not shared[saved.spellId] and canonical[saved.name] ~= saved.spellId then
                table.remove(db.trackedSpells, i)
            end
        end
        local existing = {}
        for _, spell in ipairs(db.trackedSpells) do existing[spell.spellId] = true end
        for _, spell in ipairs(classList) do
            if not existing[spell.spellId] then
                db.trackedSpells[#db.trackedSpells + 1] = { spellId = spell.spellId, name = spell.name }
            end
        end
    end
end

local function ApplyTrinketProcs(db)
    local shared = {}
    for _, spell in ipairs(ProcTracker.sharedProcs) do shared[spell.spellId] = spell end
    for i = #db.trackedSpells, 1, -1 do
        if shared[db.trackedSpells[i].spellId] then table.remove(db.trackedSpells, i) end
    end
    if db.showTrinketProcs then
        for _, spell in ipairs(ProcTracker.sharedProcs) do
            db.trackedSpells[#db.trackedSpells + 1] = { spellId = spell.spellId, name = spell.name }
        end
    end
end

function ProcTracker:SetTrinketProcs(enabled)
    local db = DB()
    db.showTrinketProcs = enabled and true or false
    ApplyTrinketProcs(db)
    self:RefreshFilter()
end

--------------------------------------------------------------------------------
-- Learning IDs out of combat
--------------------------------------------------------------------------------

-- A readable buff whose name is tracked: remember its ID. True when that is new.
local function LearnFrom(aura, names)
    if type(aura) ~= "table" or isSecret(aura) then return false end
    local name, id = aura.name, aura.spellId
    if isSecret(name) or isSecret(id) or type(id) ~= "number" or not names[name] then return false end
    if ProcTracker:GetFilterIds()[id] then return false end
    local learned = DB().learnedIds
    learned[name] = learned[name] or {}
    learned[name][id] = true
    return true
end

-- Every buff by index, under pcall: reads are blocked in dungeons even out of combat
local function ScanAll(names)
    local fn = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not fn then return false end
    local changed = false
    for i = 1, 40 do
        local ok, aura = pcall(fn, "player", i, "HELPFUL")
        if not ok or not aura then break end
        if LearnFrom(aura, names) then changed = true end
    end
    return changed
end

function ProcTracker:OnEvent(event, unit, info)
    if event == "PLAYER_REGEN_ENABLED" then
        if filterPending then self:RefreshFilter() end
        return
    end
    if event ~= "UNIT_AURA" or unit ~= "player" or InCombat() then return end
    if type(info) ~= "table" or isSecret(info) then return end

    local names = TrackedNames()
    local changed = false
    local full, added = info.isFullUpdate, info.addedAuras
    if isSecret(full) or isSecret(added) then return end
    if full then
        changed = ScanAll(names)
    elseif type(added) == "table" then
        for _, aura in ipairs(added) do
            if LearnFrom(aura, names) then changed = true end
        end
    end
    if changed then self:RefreshFilter() end
end

--------------------------------------------------------------------------------
-- Buttons: Castborn's parts, filled in by Blizzard
--------------------------------------------------------------------------------

local function ApplyButtonOptions(parts)
    local db = DB()
    local b = parts.button
    if db.showDuration then
        pcall(b.SetDurationText, b, parts.duration)
    else
        pcall(b.ClearDurationText, b)
    end
    if db.showStacks ~= false then
        pcall(b.SetApplicationCount, b, parts.stacks)
    else
        pcall(b.ClearApplicationCount, b)
    end
    if parts.glowAnim then
        if db.showGlow then
            pcall(b.AddAuraShownAnimation, b, parts.glowAnim)
        else
            pcall(b.RemoveAuraShownAnimation, b, parts.glowAnim)
        end
    end
end

local function SizeButton(parts)
    local size = DB().iconSize or 28
    pcall(parts.button.SetSize, parts.button, size, size)
end

-- Called by Blizzard for each button it creates; also exposed for tests
function ProcTracker.InitButton(b)
    local parts = { button = b }

    parts.icon = b:CreateTexture(nil, "ARTWORK")
    parts.icon:SetAllPoints()
    parts.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pcall(b.SetIcon, b, parts.icon)

    -- The Masque border, as on Castborn's other buttons; hidden without Masque
    parts.border = b:CreateTexture(nil, "BORDER")
    parts.border:SetPoint("TOPLEFT", -1, 1)
    parts.border:SetPoint("BOTTOMRIGHT", 1, -1)
    parts.border:SetColorTexture(0.3, 0.3, 0.3, 1)
    parts.border:Hide()

    parts.duration = b:CreateFontString(nil, "OVERLAY")
    parts.duration:SetFont(Castborn:GetBarFont(), 10, "OUTLINE")
    Castborn:RegisterFontString(parts.duration, 10, "OUTLINE")
    parts.duration:SetPoint("BOTTOM", 0, -2)

    parts.stacks = b:CreateFontString(nil, "OVERLAY")
    parts.stacks:SetFont(Castborn:GetBarFont(), 12, "OUTLINE")
    Castborn:RegisterFontString(parts.stacks, 12, "OUTLINE")
    parts.stacks:SetPoint("BOTTOMRIGHT", -1, 1)

    -- Blizzard plays this while the proc is up, as the TBC tracker pulses its glow
    parts.glow = b:CreateTexture(nil, "OVERLAY")
    parts.glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    parts.glow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    parts.glow:SetBlendMode("ADD")
    parts.glow:SetPoint("TOPLEFT", -6, 6)
    parts.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    parts.glow:SetVertexColor(1, 0.8, 0.2, 1)
    parts.glow:SetAlpha(0)
    local anim = parts.glow:CreateAnimationGroup()
    if anim then
        anim:SetLooping("BOUNCE")
        local fade = anim:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.8)
        fade:SetToAlpha(0.3)
        fade:SetDuration(0.8)
        parts.glowAnim = anim
    end

    -- Masque may be refused by Blizzard's button: fall back to the plain look
    local masque = Castborn.Masque
    if masque and masque.enabled then
        local ok, err = pcall(masque.AddButton, masque, "buffs", b,
            { Icon = parts.icon, Normal = parts.border, Count = parts.stacks })
        if ok then
            parts.border:Show()
            ProcTracker.masqueStatus = "ok"
        else
            parts.border:Hide()
            ProcTracker.masqueStatus = "error: " .. tostring(err)
        end
    else
        ProcTracker.masqueStatus = "not installed"
    end

    SizeButton(parts)
    ApplyButtonOptions(parts)
    buttonParts[#buttonParts + 1] = parts
end

-- Show Timers / Stacks / Proc Glow changed (called by the options page when present)
function ProcTracker:RefreshOptions()
    for _, parts in ipairs(buttonParts) do ApplyButtonOptions(parts) end
end

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

local function CreateStrip()
    local db = DB()
    strip = CreateFrame("Frame", "Castborn_ProcTracker", UIParent)
    strip:SetSize(db.width or 200, (db.iconSize or 28) + 4)
    strip:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(strip, db, function()
            CastbornDB.procs.anchored = false
        end, "Procs Tracker")
    end
    if not db.anchored then
        Castborn:ApplyPosition(strip, "procs")
    end
    strip:SetShown(db.enabled and true or false)
end

-- Built once, out of combat; reports why if this client has no AuraContainer
function ProcTracker:BuildContainer()
    local ok, err = pcall(function()
        local db = DB()
        local layout = ProcTracker.GetLayout(db)
        container = CreateFrame("AuraContainer", nil, strip, "CustomAuraContainerTemplate")
        container:SetUnit("player")
        ApplyContainerLayout(layout)
        local ids = self:GetFilterIds()
        container:AddAuraGroup(GROUP_KEY, "HELPFUL", {
            maxFrameCount = MAX_PROCS,
            candidateFilters = HasIds(ids) and { includeSpellIDs = ids } or nil,
            initializeFrame = ProcTracker.InitButton,
            layout = GroupLayout(layout),
        })
        container:SetEnabled(true)
    end)
    if ok then
        self.status = "ok"
        ApplyEnabled()
    else
        container = nil
        self.status = "unavailable: " .. tostring(err)
    end
end

function ProcTracker:UpdateLayout()
    if not strip then return end
    local db = DB()
    strip:SetHeight((db.iconSize or 28) + 4)
    if not container then return end
    local layout = ProcTracker.GetLayout(db)
    pcall(ApplyContainerLayout, layout)
    pcall(container.SetAuraGroupLayout, container, GROUP_KEY, GroupLayout(layout))
    for _, parts in ipairs(buttonParts) do SizeButton(parts) end
end

--------------------------------------------------------------------------------
-- Test mode: sample icons in Castborn's own buttons
--------------------------------------------------------------------------------

local function TestFrame(i)
    if not testFrames[i] then
        local masqueGroup = Castborn.Masque and Castborn.Masque.enabled and Castborn.Masque.groups.buffs or nil
        local f = Castborn:CreateMasqueButton(strip, "Castborn_Proc" .. i, DB().iconSize or 28, masqueGroup, {
            iconLevel = 1,
            clickThrough = true,
        })
        f.cooldown:Hide()
        f.duration = f:CreateFontString(nil, "OVERLAY")
        f.duration:SetFont(Castborn:GetBarFont(), 10, "OUTLINE")
        f.duration:SetPoint("BOTTOM", 0, -2)
        testFrames[i] = f
    end
    return testFrames[i]
end

function Castborn:TestProcs()
    if not strip then return end
    testActive = true
    ApplyEnabled()
    strip:Show()

    local db = DB()
    local layout = ProcTracker.GetLayout(db)
    local size = db.iconSize or 28
    local step = size + (db.spacing or 4)
    local samples = {}
    for _, spell in ipairs(db.trackedSpells or {}) do
        if #samples >= 3 then break end
        samples[#samples + 1] = GetSpellTexture(spell.spellId) or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    if #samples == 0 then samples = { "Interface\\Icons\\Spell_Shadow_ManaBurn" } end

    local vertical = layout.axis == AnchorUtil.FlowLayoutAxis.Vertical
    for i, icon in ipairs(samples) do
        local f = TestFrame(i)
        f:SetSize(size, size)
        f.icon:SetTexture(icon)
        f.duration:SetText(db.showDuration and string.format("%.1f", 12.3 - i * 3) or "")
        f:ClearAllPoints()
        local offset = (i - 1) * step
        if vertical then
            f:SetPoint(layout.flowAnchor, strip, layout.point, 0, offset * layout.vertical)
        elseif layout.point == "CENTER" then
            f:SetPoint("CENTER", strip, "CENTER", offset - (#samples - 1) * step / 2, 0)
        else
            f:SetPoint(layout.point, strip, layout.point, offset * layout.horizontal, 0)
        end
        f:Show()
    end
    for i = #samples + 1, #testFrames do testFrames[i]:Hide() end
end

function Castborn:EndTestProcs()
    testActive = false
    for _, f in ipairs(testFrames) do f:Hide() end
    if strip then strip:SetShown(DB().enabled and true or false) end
    ApplyEnabled()
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

Castborn:RegisterCallback("INIT", function()
    CastbornDB.procs = Castborn:MergeDefaults(CastbornDB.procs or {}, defaults)
    local db = CastbornDB.procs
    db.learnedIds = db.learnedIds or {}
    local _, playerClass = UnitClass("player")
    LoadClassList(db, playerClass)
    ApplyTrinketProcs(db)
end)

Castborn:RegisterCallback("READY", function()
    CreateStrip()
    ProcTracker:BuildContainer()
    if not InCombat() and ScanAll(TrackedNames()) then ProcTracker:RefreshFilter() end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        ProcTracker:OnEvent(event, ...)
    end)

    Castborn.TestManager:Register("Procs", function() Castborn:TestProcs() end, function() Castborn:EndTestProcs() end)

    -- Below the player castbar when anchored, as on TBC
    local db = DB()
    if db.anchored ~= false and Castborn.Anchoring and Castborn.castbars and Castborn.castbars.player then
        Castborn.Anchoring:ReattachToCastbar(strip, db, "BOTTOM", -2)
    end
end)

Castborn:RegisterCallback("PLAYER_CASTBAR_CREATED", function()
    if strip and CastbornDB.procs and CastbornDB.procs.anchored ~= false and Castborn.Anchoring then
        Castborn.Anchoring:ReattachToCastbar(strip, CastbornDB.procs, "BOTTOM", -2)
    end
end)

Castborn:RegisterAnchorCallbacks("PROCS", "Proc Tracker", function() return strip end, "procs", "BOTTOM", -2)

Castborn:RegisterModule("ProcTracker", ProcTracker)

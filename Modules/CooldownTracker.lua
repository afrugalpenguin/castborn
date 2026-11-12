-- Modules/CooldownTracker.lua
-- Settings, groups and their API, default spell loading, the Forever seams, castbar
-- anchoring and the update loop. Frames, layout and test mode live in the group objects
-- (CooldownGroup.lua), one per group.
local CooldownTracker = {}
Castborn.CooldownTracker = CooldownTracker

-- Module-wide settings, merged into CastbornDB.cooldowns. Never put groups (or any other
-- list) here: MergeDefaults would merge a default list index by index into the user's own.
local defaults = {
    enabled = true,
    showTime = true,
    showReadyGlow = true,     -- Animated edge glow when ready
    trackTrinkets = true,
    nextGroupId = 1,          -- new groups are "g1", "g2", ...; ids are never reused
}

-- Per-group settings, filled into each group table on its own
local groupDefaults = {
    iconSize = 36,
    spacing = 4,
    point = "CENTER",
    x = -450,
    y = -300,
    xPct = -0.234,
    yPct = -0.278,
    anchored = true,
    anchorPosition = "LEFT",  -- LEFT, RIGHT, TOP, BOTTOM
    growDirection = "LEFT",   -- LEFT, RIGHT, UP or CENTER
    iconsPerRow = 10,
    orientation = "HORIZONTAL",
}
CooldownTracker.groupDefaults = groupDefaults  -- Reset Positions reads these

local MAIN_GROUP_ID = "main"
local MAX_GROUPS = 8
local MAX_SPELLS = Castborn.CooldownGroup.MAX_ICONS
CooldownTracker.MAX_GROUPS = MAX_GROUPS
CooldownTracker.MAX_SPELLS = MAX_SPELLS

-- Top-level keys that moved into the main group. verticalLayout is the options page's
-- mirror of orientation; it has no default.
local LEGACY_GROUP_KEYS = {
    "iconSize", "spacing", "iconsPerRow", "orientation", "verticalLayout", "growDirection",
    "anchored", "anchorPosition", "point", "x", "y", "xPct", "yPct",
}

-- A saved position is taken as a whole, so a pixel-only position is never mixed with
-- default percentages (ApplyPosition prefers the percentages).
local POSITION_KEYS = { x = true, y = true, xPct = true, yPct = true }

local function FillGroupDefaults(group)
    -- Grow Down looked exactly like Grow Right and has been removed (#279)
    if group.growDirection == "DOWN" then
        group.growDirection = "RIGHT"
    end
    local hasPosition = group.x ~= nil or group.y ~= nil or group.xPct ~= nil or group.yPct ~= nil
    if hasPosition and Castborn.Anchoring then
        Castborn.Anchoring:MigratePosition(group)
    end
    for key, value in pairs(groupDefaults) do
        if group[key] == nil and not (hasPosition and POSITION_KEYS[key]) then
            group[key] = value
        end
    end
    group.spells = group.spells or {}
end

-- Move the old flat settings (top-level layout keys and trackedSpells) into a "main" group.
-- Does nothing if db already has groups. Returns true only when old settings were moved,
-- so a fresh install is not announced as a migration.
function CooldownTracker.MigrateToGroups(db)
    if type(db) ~= "table" or db.groups ~= nil then return false end

    local hadLegacy = db.trackedSpells ~= nil
    for _, key in ipairs(LEGACY_GROUP_KEYS) do
        if db[key] ~= nil then hadLegacy = true end
    end

    -- Keep a one-time copy of the old keys before anything is removed
    if hadLegacy and db.legacyBackup == nil then
        local backup = {}
        for _, key in ipairs(LEGACY_GROUP_KEYS) do
            backup[key] = Castborn:DeepCopy(db[key])
        end
        backup.trackedSpells = Castborn:DeepCopy(db.trackedSpells)
        db.legacyBackup = backup
    end

    local main = { id = MAIN_GROUP_ID, name = "Main" }
    for _, key in ipairs(LEGACY_GROUP_KEYS) do
        main[key] = db[key]
    end
    main.spells = db.trackedSpells or {}
    FillGroupDefaults(main)
    db.groups = { main }

    -- Only now that the group is written, drop the old keys
    for _, key in ipairs(LEGACY_GROUP_KEYS) do
        db[key] = nil
    end
    db.trackedSpells = nil

    return hadLegacy
end

-- Migrate if needed (announcing it once) and fill each group's defaults
local function PrepareGroups(db)
    if CooldownTracker.MigrateToGroups(db) then
        Castborn:Print("Cooldowns moved to the new groups format")
    end
    for _, group in ipairs(db.groups) do
        FillGroupDefaults(group)
    end
end

-- The groups list. Migrates first if the old shape turns up (an old profile or import).
function CooldownTracker:GetGroups()
    local db = CastbornDB.cooldowns
    if db.groups == nil then
        PrepareGroups(db)
    end
    return db.groups
end

function CooldownTracker:GetGroup(id)
    for _, group in ipairs(self:GetGroups()) do
        if group.id == id then return group end
    end
    return nil
end

-- Looked up by id, never by position, because groups can be reordered. Recreated with
-- defaults (and no spells, so READY reloads them) if damaged data lost it.
function CooldownTracker:GetMainGroup()
    local main = self:GetGroup(MAIN_GROUP_ID)
    if not main then
        main = { id = MAIN_GROUP_ID, name = "Main" }
        FillGroupDefaults(main)
        table.insert(self:GetGroups(), 1, main)
    end
    return main
end

-- The group holding a spell, and its index there; nil if no group tracks it
function CooldownTracker:FindSpell(spellId)
    for _, group in ipairs(self:GetGroups()) do
        for i, spell in ipairs(group.spells) do
            if spell.spellId == spellId then return group, i end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Runtime groups
--------------------------------------------------------------------------------

local runtimeGroups = {}   -- group id -> CooldownGroup, kept for the session
local activeGroups = {}    -- the CooldownGroups for the current groups, in list order
local framesBuilt = false  -- frames are built on READY
local testing = false
local playerCastbar = nil

-- main: today's strip, with its original frame names, trinkets and Masque group
local mainGroup = Castborn.CooldownGroup:New({
    id = MAIN_GROUP_ID,
    getSettings = function() return CooldownTracker:GetMainGroup() end,
    getModuleSettings = function() return CastbornDB.cooldowns end,
    getSpells = function() return CooldownTracker:GetMainGroup().spells end,
    names = {
        container = "Castborn_CooldownTracker",
        icon = "Castborn_CD",
        trinkets = "Castborn_TrinketTracker",
        trinket = "Castborn_Trinket",
    },
    masqueGroup = "cooldowns",
    dragLabel = "Cooldowns",
    tracker = CooldownTracker,
})
runtimeGroups[MAIN_GROUP_ID] = mainGroup

local function GroupLabel(data)
    return "Cooldowns: " .. data.name
end

-- The Masque group key for a group other than main, creating the Masque group if needed.
-- Also returns whether it was just created.
local function EnsureMasqueGroup(data)
    local masque = Castborn.Masque
    if masque and masque.EnsureCooldownGroup then
        return masque:EnsureCooldownGroup(data.id, data.name)
    end
    return "cooldowns_" .. data.id, false
end

local function NewRuntimeGroup(data)
    local id = data.id
    return Castborn.CooldownGroup:New({
        id = id,
        getSettings = function() return CooldownTracker:GetGroup(id) end,
        getModuleSettings = function() return CastbornDB.cooldowns end,
        getSpells = function()
            local group = CooldownTracker:GetGroup(id)
            return group and group.spells
        end,
        names = {
            container = "Castborn_CooldownGroup_" .. id,
            icon = "Castborn_CooldownGroup_" .. id .. "_CD",
        },
        masqueGroup = (EnsureMasqueGroup(data)),
        dragLabel = GroupLabel(data),
        tracker = CooldownTracker,
    })
end

-- Put a group's strip where its settings say: main next to the castbar while anchored,
-- everything else at its saved position
local function PositionGroup(runtime, data)
    local frame = runtime.frame
    if not frame then return end
    if data.id == MAIN_GROUP_ID and data.anchored ~= false then
        local castbar = playerCastbar or (Castborn.castbars and Castborn.castbars.player)
        if castbar then
            local anchorTarget = (castbar.iconFrame and castbar.iconFrame:IsShown()) and castbar.iconFrame or castbar
            frame:ClearAllPoints()
            frame:SetPoint("RIGHT", anchorTarget, "LEFT", -4, 0)
            frame.isAnchored = true
            frame.anchorParent = anchorTarget
            return
        end
    end
    if Castborn.Anchoring then
        Castborn.Anchoring:ApplyPosition(frame, data)
    end
end

-- Bring the runtime groups in line with the saved groups: build new ones (once frames
-- exist), hide ones that have gone, keep the update order, and follow renames. With
-- repositionAll, every strip also moves to its saved position (after a profile switch).
function CooldownTracker:SyncGroups(repositionAll)
    local seen = {}
    for i = #activeGroups, 1, -1 do activeGroups[i] = nil end

    for _, data in ipairs(self:GetGroups()) do
        local runtime = runtimeGroups[data.id]
        local returning = false
        if not runtime then
            runtime = NewRuntimeGroup(data)
            runtimeGroups[data.id] = runtime
        elseif data.id ~= MAIN_GROUP_ID then
            local _, created = EnsureMasqueGroup(data)
            if created then runtime:AddToMasque() end
            runtime:SetLabel(GroupLabel(data))
            returning = runtime.inactive
        end
        runtime:Reactivate()
        seen[data.id] = true
        activeGroups[#activeGroups + 1] = runtime

        if framesBuilt then
            if not runtime.frame then
                runtime:Build()
            elseif repositionAll or returning then
                PositionGroup(runtime, data)
            end
            if testing and not runtime.testModeActive then
                runtime:StartTest()
            end
        end
    end

    for id, runtime in pairs(runtimeGroups) do
        if not seen[id] and not runtime.inactive then
            runtime:Deactivate()
        end
    end
end

-- One tick of the update loop
function CooldownTracker:UpdateAll()
    for i = 1, #activeGroups do
        activeGroups[i]:Update()
    end
    mainGroup:UpdateTrinkets()
end

-- In test mode, show a changed group's new order straight away
local function RefreshTest(group)
    local runtime = runtimeGroups[group.id]
    if testing and runtime and runtime.frame then
        runtime:StartTest()
    end
end

--------------------------------------------------------------------------------
-- Group API: each call validates its input and returns true (AddGroup: the new id) or
-- false (nil) and a reason, changing nothing when it refuses
--------------------------------------------------------------------------------

local STACK_GAP = 48

-- Place a group just below the group before it in the list: under that strip when it has a
-- size on screen, else a step below the default position
local function StackPosition(index, data)
    local previous = CooldownTracker:GetGroups()[index - 1]
    local runtime = previous and runtimeGroups[previous.id]
    local frame = runtime and runtime.frame
    local centreX = frame and frame:GetCenter()
    local bottom = frame and frame:GetBottom()

    local x, y
    if centreX and bottom then
        x = centreX - GetScreenWidth() / 2
        y = bottom - 8 - ((data.iconSize or 36) + 4) / 2 - GetScreenHeight() / 2
    else
        x = groupDefaults.x
        y = groupDefaults.y - (index - 1) * STACK_GAP
    end

    if Castborn.Anchoring then
        Castborn.Anchoring:SavePosition(data, "CENTER", x, y)
    else
        data.point, data.x, data.y = "CENTER", x, y
    end
end

local function TrimName(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if name == "" then return nil end
    return name
end

local function IndexOfGroup(id)
    for i, group in ipairs(CooldownTracker:GetGroups()) do
        if group.id == id then return i end
    end
    return nil
end

function CooldownTracker:AddGroup(name)
    name = TrimName(name)
    if not name then return nil, "Enter a name for the group" end
    local groups = self:GetGroups()
    if #groups >= MAX_GROUPS then
        return nil, "You can have up to " .. MAX_GROUPS .. " groups"
    end

    local db = CastbornDB.cooldowns
    local number = db.nextGroupId or 1
    while self:GetGroup("g" .. number) do number = number + 1 end
    local id = "g" .. number
    db.nextGroupId = number + 1

    local data = { id = id, name = name, spells = {} }
    FillGroupDefaults(data)
    data.anchored = false  -- only main may anchor to the castbar
    groups[#groups + 1] = data
    StackPosition(#groups, data)

    self:SyncGroups()
    return id
end

-- Its spells move to the end of main, in order
function CooldownTracker:RemoveGroup(id)
    if id == MAIN_GROUP_ID then return false, "The main group cannot be removed" end
    local index = IndexOfGroup(id)
    if not index then return false, "There is no such group" end

    local groups = self:GetGroups()
    local data = groups[index]
    local main = self:GetMainGroup()
    if #main.spells + #data.spells > MAX_SPELLS then
        return false, "The main group has no room for this group's spells"
    end

    for _, spell in ipairs(data.spells) do
        main.spells[#main.spells + 1] = spell
    end
    table.remove(groups, index)
    if Castborn.Masque and Castborn.Masque.DeleteCooldownGroup then
        Castborn.Masque:DeleteCooldownGroup(id)
    end

    self:SyncGroups()
    RefreshTest(main)
    return true
end

function CooldownTracker:RenameGroup(id, name)
    local data = self:GetGroup(id)
    if not data then return false, "There is no such group" end
    name = TrimName(name)
    if not name then return false, "Enter a name for the group" end
    data.name = name
    self:SyncGroups()
    return true
end

-- newIndex is clamped to the list
function CooldownTracker:MoveGroup(id, newIndex)
    local index = IndexOfGroup(id)
    if not index then return false, "There is no such group" end
    local groups = self:GetGroups()
    local data = table.remove(groups, index)
    newIndex = math.max(1, math.min(newIndex or #groups + 1, #groups + 1))
    table.insert(groups, newIndex, data)
    self:SyncGroups()
    return true
end

-- Move a spell to a group (its own included), at index or at the end; index is clamped
function CooldownTracker:MoveSpell(spellId, toGroupId, index)
    local target = self:GetGroup(toGroupId)
    if not target then return false, "There is no such group" end
    local source, from = self:FindSpell(spellId)
    if not source then return false, "That spell is not tracked" end
    if source ~= target and #target.spells >= MAX_SPELLS then
        return false, "That group already has " .. MAX_SPELLS .. " spells"
    end

    local spell = table.remove(source.spells, from)
    local last = #target.spells + 1
    index = math.max(1, math.min(index or last, last))
    table.insert(target.spells, index, spell)

    RefreshTest(source)
    if target ~= source then RefreshTest(target) end
    return true
end

-- Reset Positions: every group but main goes back below the group before it
function CooldownTracker:RestackGroups()
    for index, data in ipairs(self:GetGroups()) do
        if data.id ~= MAIN_GROUP_ID then
            data.anchored = false
            StackPosition(index, data)
            local runtime = runtimeGroups[data.id]
            if runtime and runtime.frame and Castborn.Anchoring then
                Castborn.Anchoring:ApplyPosition(runtime.frame, data)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Forever seams
--------------------------------------------------------------------------------

-- Whether a tracked spell is on a real cooldown (longer than the GCD), whether it is long
-- enough to earn the ready glow, and its start and duration. Forever overrides this.
function CooldownTracker:GetSpellCooldownState(spellName)
    local start, duration = GetSpellCooldown(spellName)
    if duration and duration > 1.5 then
        return true, duration > 3, start, duration
    end
    return false
end

-- Name used to read a tracked spell's cooldown and icon. Forever overrides this, because
-- several TBC spell IDs are different spells there.
function CooldownTracker:GetTrackedSpellName(spell)
    return spell.name
end

-- Draw the cooldown swipe on an icon. Forever overrides this.
function CooldownTracker:SetIconCooldown(cooldown, spellName, start, duration)
    cooldown:SetCooldown(start, duration)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

Castborn:RegisterCallback("INIT", function()
    CastbornDB.cooldowns = Castborn:MergeDefaults(CastbornDB.cooldowns or {}, defaults)
    PrepareGroups(CastbornDB.cooldowns)
end)

-- A profile saved before groups existed (or an old export string) arrives in the old shape,
-- and a profile can have different groups, so rebuild the runtime groups from it
Castborn:RegisterCallback("PROFILE_CHANGED", function()
    if CastbornDB.cooldowns then
        PrepareGroups(CastbornDB.cooldowns)
        CooldownTracker:SyncGroups(true)
    end
end)

Castborn:RegisterCallback("COOLDOWNS_GLOW_OFF", function()
    for i = 1, #activeGroups do
        activeGroups[i]:StopGlows()
    end
end)

-- A copy of a default spell entry, so SpellData's own lists are never stored or changed
local function CopySpell(spell)
    local copy = {}
    for key, value in pairs(spell) do copy[key] = value end
    return copy
end

-- Spell IDs held by groups other than main
local function SpellsOutsideMain()
    local ids = {}
    for _, group in ipairs(CooldownTracker:GetGroups()) do
        if group.id ~= MAIN_GROUP_ID then
            for _, spell in ipairs(group.spells) do ids[spell.spellId] = true end
        end
    end
    return ids
end

-- Merge new default spells into existing tracked list (for upgrades), skipping any in skip
local function MergeNewDefaults(existingSpells, defaultSpells, skip)
    local existingIds = {}
    for _, spell in ipairs(existingSpells) do
        existingIds[spell.spellId] = true
    end

    local added = 0
    for _, spell in ipairs(defaultSpells) do
        if not existingIds[spell.spellId] and not skip[spell.spellId] then
            table.insert(existingSpells, CopySpell(spell))
            added = added + 1
        end
    end

    return added
end

-- Load the class and racial default spells into main: all of them on a first load or a class
-- change (keeping custom spells), or any new ones after a version change. Spells already in
-- other groups stay there and are skipped.
function CooldownTracker:LoadDefaultSpells()
    local db = CastbornDB.cooldowns
    local main = self:GetMainGroup()
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local currentVersion = Castborn.version

    -- Check if class changed (need to reload defaults)
    -- Note: if loadedForClass is nil but the main group has spells, reload anyway (migration case)
    local classChanged = db.loadedForClass ~= class

    if not main.spells or #main.spells == 0 or classChanged then
        -- Preserve custom spells before reloading class defaults
        local customSpells = {}
        if main.spells then
            for _, spell in ipairs(main.spells) do
                if spell.custom then
                    table.insert(customSpells, spell)
                end
            end
        end

        -- Reload class defaults
        if class and Castborn.SpellData then
            local elsewhere = SpellsOutsideMain()
            local spells = {}
            for _, spell in ipairs(Castborn.SpellData:GetClassCooldowns(class)) do
                if not elsewhere[spell.spellId] then
                    table.insert(spells, CopySpell(spell))
                end
            end
            -- Append racial cooldowns
            if race then
                for _, spell in ipairs(Castborn.SpellData:GetRacialCooldowns(race)) do
                    if not elsewhere[spell.spellId] then
                        table.insert(spells, CopySpell(spell))
                    end
                end
            end
            -- Re-append custom spells
            for _, spell in ipairs(customSpells) do
                table.insert(spells, spell)
            end
            main.spells = spells
            db.defaultsLoaded = currentVersion
            db.loadedForClass = class
        end
    elseif db.defaultsLoaded ~= currentVersion then
        -- Version changed: merge any new default spells
        if class and Castborn.SpellData then
            local elsewhere = SpellsOutsideMain()
            local defaultSpells = Castborn.SpellData:GetClassCooldowns(class)
            local added = 0
            if defaultSpells then
                added = added + MergeNewDefaults(main.spells, defaultSpells, elsewhere)
            end
            -- Merge racial cooldowns
            if race then
                local racials = Castborn.SpellData:GetRacialCooldowns(race)
                if racials then
                    added = added + MergeNewDefaults(main.spells, racials, elsewhere)
                end
            end
            if added > 0 then
                Castborn:Print(added .. " new cooldown(s) added from defaults")
            end
        end
        db.defaultsLoaded = currentVersion
        db.loadedForClass = class
    end
end

Castborn:RegisterCallback("READY", function()
    CooldownTracker:LoadDefaultSpells()

    framesBuilt = true
    CooldownTracker:SyncGroups()
    local frame = mainGroup.frame

    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            CooldownTracker:UpdateAll()
            elapsed = 0
        end
    end)

    -- Apply initial anchoring if enabled and castbar exists
    if CooldownTracker:GetMainGroup().anchored ~= false then
        local castbar = Castborn.castbars and Castborn.castbars.player
        if castbar then
            playerCastbar = castbar
            -- Find the anchor target - prefer the icon frame if it exists
            local anchorTarget = (castbar.iconFrame and castbar.iconFrame:IsShown()) and castbar.iconFrame or castbar

            -- Position to the left of the icon, with icons growing leftward
            frame:ClearAllPoints()
            frame:SetPoint("RIGHT", anchorTarget, "LEFT", -4, 0)
            frame.isAnchored = true
            frame.anchorParent = anchorTarget
        end
    end
end)

Castborn:RegisterCallback("PLAYER_CASTBAR_CREATED", function(castbar)
    playerCastbar = castbar
    local db = CastbornDB.cooldowns
    local frame = mainGroup.frame

    -- Anchor to the left of the castbar's icon (if it exists) by default
    if frame and db and CooldownTracker:GetMainGroup().anchored ~= false then
        -- Find the anchor target - prefer the icon frame if it exists
        local anchorTarget = (castbar.iconFrame and castbar.iconFrame:IsShown()) and castbar.iconFrame or castbar

        -- Position to the left of the icon, with icons growing leftward
        frame:ClearAllPoints()
        frame:SetPoint("RIGHT", anchorTarget, "LEFT", -4, 0)
        frame.isAnchored = true
        frame.anchorParent = anchorTarget
    end
end)

-- Detach cooldowns from castbar
Castborn:RegisterCallback("DETACH_COOLDOWNS", function()
    local main = CooldownTracker:GetMainGroup()
    main.anchored = false
    local frame = mainGroup.frame
    if Castborn.Anchoring then
        Castborn.Anchoring:Detach(frame, main)
    end
    Castborn:Print("Cooldowns detached from castbar")
end)

-- Reattach cooldowns to castbar
Castborn:RegisterCallback("REATTACH_COOLDOWNS", function()
    CooldownTracker:GetMainGroup().anchored = true

    local frame = mainGroup.frame
    -- Try to find playerCastbar if not set
    if not playerCastbar then
        playerCastbar = Castborn.castbars and Castborn.castbars.player
    end

    if playerCastbar then
        -- Find the anchor target - prefer the icon frame if it exists
        local anchorTarget = (playerCastbar.iconFrame and playerCastbar.iconFrame:IsShown()) and playerCastbar.iconFrame or playerCastbar

        -- Position to the left of the icon, with icons growing leftward
        frame:ClearAllPoints()
        frame:SetPoint("RIGHT", anchorTarget, "LEFT", -4, 0)
        frame.isAnchored = true
        frame.anchorParent = anchorTarget
    end
    Castborn:Print("Cooldowns anchored to castbar")
end)

-- Test mode: every group shows its sample icons
function Castborn:TestCooldowns()
    testing = true
    for i = 1, #activeGroups do
        activeGroups[i]:StartTest()
    end
end

-- End test mode
function Castborn:EndTestCooldowns()
    testing = false
    for _, runtime in pairs(runtimeGroups) do
        runtime:EndTest()
    end
end

-- Register with TestManager
Castborn:RegisterCallback("READY", function()
    Castborn.TestManager:Register("Cooldowns", function() Castborn:TestCooldowns() end, function() Castborn:EndTestCooldowns() end)
end)

Castborn:RegisterModule("CooldownTracker", CooldownTracker)

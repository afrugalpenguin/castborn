-- Modules/CooldownTracker.lua
-- Settings, default spell loading, the Forever seams, castbar anchoring and the update loop.
-- Frames, layout and test mode live in the group object (CooldownGroup.lua).
local CooldownTracker = {}
Castborn.CooldownTracker = CooldownTracker

-- Module-wide settings, merged into CastbornDB.cooldowns. Never put groups (or any other
-- list) here: MergeDefaults would merge a default list index by index into the user's own.
local defaults = {
    enabled = true,
    showTime = true,
    showReadyGlow = true,     -- Animated edge glow when ready
    trackTrinkets = true,
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
    growDirection = "LEFT",   -- LEFT or RIGHT
    iconsPerRow = 10,
    orientation = "HORIZONTAL",
}
CooldownTracker.groupDefaults = groupDefaults  -- Reset Positions reads these

local MAIN_GROUP_ID = "main"

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

-- The one group: today's strip, with its original frame names and Masque group
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

Castborn:RegisterCallback("INIT", function()
    CastbornDB.cooldowns = Castborn:MergeDefaults(CastbornDB.cooldowns or {}, defaults)
    PrepareGroups(CastbornDB.cooldowns)
end)

-- A profile saved before groups existed (or an old export string) arrives in the old shape
Castborn:RegisterCallback("PROFILE_CHANGED", function()
    if CastbornDB.cooldowns then
        PrepareGroups(CastbornDB.cooldowns)
    end
end)

Castborn:RegisterCallback("COOLDOWNS_GLOW_OFF", function()
    mainGroup:StopGlows()
end)

-- Merge new default spells into existing tracked list (for upgrades)
local function MergeNewDefaults(existingSpells, defaultSpells)
    local existingIds = {}
    for _, spell in ipairs(existingSpells) do
        existingIds[spell.spellId] = true
    end

    local added = 0
    for _, spell in ipairs(defaultSpells) do
        if not existingIds[spell.spellId] then
            table.insert(existingSpells, spell)
            added = added + 1
        end
    end

    return added
end

-- Anchoring Support
local playerCastbar = nil

Castborn:RegisterCallback("READY", function()
    local db = CastbornDB.cooldowns
    local main = CooldownTracker:GetMainGroup()
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
            main.spells = Castborn.SpellData:GetClassCooldowns(class)
            -- Append racial cooldowns
            if race then
                for _, spell in ipairs(Castborn.SpellData:GetRacialCooldowns(race)) do
                    table.insert(main.spells, spell)
                end
            end
            -- Re-append custom spells
            for _, spell in ipairs(customSpells) do
                table.insert(main.spells, spell)
            end
            db.defaultsLoaded = currentVersion
            db.loadedForClass = class
        end
    elseif db.defaultsLoaded ~= currentVersion then
        -- Version changed: merge any new default spells
        if class and Castborn.SpellData then
            local defaults = Castborn.SpellData:GetClassCooldowns(class)
            local added = 0
            if defaults then
                added = added + MergeNewDefaults(main.spells, defaults)
            end
            -- Merge racial cooldowns
            if race then
                local racials = Castborn.SpellData:GetRacialCooldowns(race)
                if racials then
                    added = added + MergeNewDefaults(main.spells, racials)
                end
            end
            if added > 0 then
                Castborn:Print(added .. " new cooldown(s) added from defaults")
            end
        end
        db.defaultsLoaded = currentVersion
        db.loadedForClass = class
    end

    mainGroup:Build()
    local frame = mainGroup.frame

    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            mainGroup:Update()
            mainGroup:UpdateTrinkets()
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

-- Test mode function
function Castborn:TestCooldowns()
    mainGroup:StartTest()
end

-- End test mode
function Castborn:EndTestCooldowns()
    mainGroup:EndTest()
end

-- Register with TestManager
Castborn:RegisterCallback("READY", function()
    Castborn.TestManager:Register("Cooldowns", function() Castborn:TestCooldowns() end, function() Castborn:EndTestCooldowns() end)
end)

Castborn:RegisterModule("CooldownTracker", CooldownTracker)

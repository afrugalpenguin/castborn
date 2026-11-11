-- Modules/CooldownTracker.lua
-- Settings, default spell loading, the Forever seams, castbar anchoring and the update loop.
-- Frames, layout and test mode live in the group object (CooldownGroup.lua).
local CooldownTracker = {}
Castborn.CooldownTracker = CooldownTracker

local defaults = {
    enabled = true,
    iconSize = 36,
    spacing = 4,
    point = "CENTER",
    x = -450,
    y = -300,
    xPct = -0.234,
    yPct = -0.278,
    showTime = true,
    trackedSpells = {},
    anchored = true,
    anchorPosition = "LEFT",  -- LEFT, RIGHT, TOP, BOTTOM
    growDirection = "LEFT",   -- LEFT or RIGHT
    showReadyGlow = true,     -- Animated edge glow when ready
    trackTrinkets = true,
    iconsPerRow = 10,
    orientation = "HORIZONTAL",
}

-- The one group: today's strip, with its original frame names and Masque group
local mainGroup = Castborn.CooldownGroup:New({
    id = "main",
    getSettings = function() return CastbornDB.cooldowns end,
    getSpells = function() return CastbornDB.cooldowns.trackedSpells end,
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

Castborn:RegisterCallback("READY", function()
    local db = CastbornDB.cooldowns
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    local currentVersion = Castborn.version

    -- Check if class changed (need to reload defaults)
    -- Note: if loadedForClass is nil but trackedSpells exists, reload anyway (migration case)
    local classChanged = db.loadedForClass ~= class

    if not db.trackedSpells or #db.trackedSpells == 0 or classChanged then
        -- Preserve custom spells before reloading class defaults
        local customSpells = {}
        if db.trackedSpells then
            for _, spell in ipairs(db.trackedSpells) do
                if spell.custom then
                    table.insert(customSpells, spell)
                end
            end
        end

        -- Reload class defaults
        if class and Castborn.SpellData then
            db.trackedSpells = Castborn.SpellData:GetClassCooldowns(class)
            -- Append racial cooldowns
            if race then
                for _, spell in ipairs(Castborn.SpellData:GetRacialCooldowns(race)) do
                    table.insert(db.trackedSpells, spell)
                end
            end
            -- Re-append custom spells
            for _, spell in ipairs(customSpells) do
                table.insert(db.trackedSpells, spell)
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
                added = added + MergeNewDefaults(db.trackedSpells, defaults)
            end
            -- Merge racial cooldowns
            if race then
                local racials = Castborn.SpellData:GetRacialCooldowns(race)
                if racials then
                    added = added + MergeNewDefaults(db.trackedSpells, racials)
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
    if db.anchored ~= false then
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

-- Anchoring Support
local playerCastbar = nil

Castborn:RegisterCallback("PLAYER_CASTBAR_CREATED", function(castbar)
    playerCastbar = castbar
    local db = CastbornDB.cooldowns
    local frame = mainGroup.frame

    -- Anchor to the left of the castbar's icon (if it exists) by default
    if frame and db and db.anchored ~= false then
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
    local db = CastbornDB.cooldowns
    db.anchored = false
    local frame = mainGroup.frame
    if Castborn.Anchoring then
        Castborn.Anchoring:Detach(frame, db)
    end
    Castborn:Print("Cooldowns detached from castbar")
end)

-- Reattach cooldowns to castbar
Castborn:RegisterCallback("REATTACH_COOLDOWNS", function()
    local db = CastbornDB.cooldowns
    db.anchored = true

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

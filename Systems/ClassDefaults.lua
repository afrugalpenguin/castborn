-- Systems/ClassDefaults.lua
local ClassDefaults = {}
Castborn.ClassDefaults = ClassDefaults

-- Per-class module defaults (the tracked spells live in Data/SpellData.lua)
ClassDefaults.definitions = {
    MAGE = {
        fiveSecondRule = true,
        swingTimer = false,
    },
    WARLOCK = {
        fiveSecondRule = true,
        swingTimer = false,
    },
    PRIEST = {
        fiveSecondRule = true,
        swingTimer = false,
    },
    DRUID = {
        fiveSecondRule = true,
        swingTimer = "FERAL",
    },
    PALADIN = {
        fiveSecondRule = true,
        fsrAboveSwing = true,  -- melee rarely see the castbar, so the bar sits on the swing timer
        swingTimer = true,
    },
    SHAMAN = {
        fiveSecondRule = true,
        swingTimer = "ENHANCEMENT",
    },
    HUNTER = {
        fiveSecondRule = true,
        swingTimer = true,
        swingTimerRanged = true,
    },
    WARRIOR = {
        fiveSecondRule = false,
        swingTimer = true,
    },
    ROGUE = {
        fiveSecondRule = false,
        swingTimer = true,
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
        local form = GetShapeshiftForm()
        return form == 1 or form == 3
    elseif defaults.swingTimer == "ENHANCEMENT" then
        return true
    end

    return false
end

-- Apply class defaults on first run or when class changes
function ClassDefaults:ApplyFirstRunDefaults()
    local info = Castborn:GetPlayerInfo()
    local currentClass = info.class

    -- Check if this is a different class than before
    -- Also triggers if firstRunClass was never set (existing users before this feature)
    local classChanged = CastbornDB.firstRunClass ~= currentClass

    if CastbornDB.firstRunComplete and not classChanged then return end

    local isFirstRun = not CastbornDB.firstRunComplete

    -- Only apply enabled-state defaults on first run so that user preferences are
    -- respected when switching between characters of different classes.
    if isFirstRun then
        CastbornDB.fsr = CastbornDB.fsr or {}
        CastbornDB.fsr.enabled = self:ShouldShowFSR()

        CastbornDB.swing = CastbornDB.swing or {}
        CastbornDB.swing.enabled = self:ShouldShowSwingTimer()
    end

    -- Signal ProcTracker and CooldownTracker to reload class spells on next session.
    -- Do NOT clear the spell lists here: CooldownTracker's READY callback already
    -- preserves custom spells when reloading for a class change, but only if
    -- the main group's spells are still intact when that callback runs.
    CastbornDB.procs = CastbornDB.procs or {}
    CastbornDB.procs.loadedForClass = nil

    CastbornDB.cooldowns = CastbornDB.cooldowns or {}
    CastbornDB.cooldowns.loadedForClass = nil

    CastbornDB.firstRunComplete = true
    CastbornDB.firstRunClass = currentClass

    Castborn:FireCallback("DEFAULTS_APPLIED")
end

Castborn:RegisterCallback("READY", function()
    ClassDefaults:ApplyFirstRunDefaults()
end)

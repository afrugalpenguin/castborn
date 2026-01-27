-- Systems/ClassDefaults.lua
local ClassDefaults = {}
Castborn.ClassDefaults = ClassDefaults

-- TBC-accurate class configurations
ClassDefaults.definitions = {
    MAGE = {
        fiveSecondRule = true,
        swingTimer = false,
        procs = {
            { spellId = 12536, name = "Clearcasting" },
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
            { spellId = 17941, name = "Nightfall" },
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
        swingTimer = "FERAL",
        procs = {
            { spellId = 16870, name = "Clearcasting" },
        },
        cooldowns = {
            { spellId = 29166, name = "Innervate" },
        },
    },
    PALADIN = {
        fiveSecondRule = true,
        swingTimer = true,
        procs = {
            { spellId = 20050, name = "Vengeance" },
        },
        cooldowns = {
            { spellId = 31884, name = "Avenging Wrath" },
        },
    },
    SHAMAN = {
        fiveSecondRule = true,
        swingTimer = "ENHANCEMENT",
        procs = {
            { spellId = 16246, name = "Clearcasting" },
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
            { spellId = 7384, name = "Overpower", type = "ability" },
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
            { spellId = 14189, name = "Seal Fate" },
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
        local form = GetShapeshiftForm()
        return form == 1 or form == 3
    elseif defaults.swingTimer == "ENHANCEMENT" then
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

-- Apply class defaults on first run or when class changes
function ClassDefaults:ApplyFirstRunDefaults()
    local info = Castborn:GetPlayerInfo()
    local currentClass = info.class

    -- Check if this is a different class than before
    -- Also triggers if firstRunClass was never set (existing users before this feature)
    local classChanged = CastbornDB.firstRunClass ~= currentClass

    if CastbornDB.firstRunComplete and not classChanged then return end

    local defaults = self:GetPlayerDefaults()

    CastbornDB.fsr = CastbornDB.fsr or {}
    CastbornDB.fsr.enabled = self:ShouldShowFSR()

    CastbornDB.swing = CastbornDB.swing or {}
    CastbornDB.swing.enabled = self:ShouldShowSwingTimer()

    -- Reset class-specific tracked spells when class changes
    CastbornDB.procs = CastbornDB.procs or {}
    CastbornDB.procs.trackedSpells = nil  -- Clear to allow ProcTracker to reload
    CastbornDB.procs.loadedForClass = nil

    CastbornDB.cooldowns = CastbornDB.cooldowns or {}
    CastbornDB.cooldowns.trackedSpells = nil  -- Clear to allow CooldownTracker to reload
    CastbornDB.cooldowns.loadedForClass = nil

    CastbornDB.firstRunComplete = true
    CastbornDB.firstRunClass = currentClass

    Castborn:FireCallback("DEFAULTS_APPLIED")
end

Castborn:RegisterCallback("READY", function()
    ClassDefaults:ApplyFirstRunDefaults()
end)

--[[
    Castborn - cooldown tracker on Forever
    GetSpellCooldown is gone. C_Spell.GetSpellCooldown keeps isActive/isOnGCD readable in
    combat while the times are secret, so secret cooldowns are drawn from duration objects.
    Loaded only by Castborn_Camelot.toc, after CooldownTracker.lua.
]]

local CooldownTracker = Castborn.CooldownTracker

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

function CooldownTracker:GetSpellCooldownState(spellName)
    local info = C_Spell.GetSpellCooldown(spellName)
    if not info then return false end
    local duration = info.duration
    if isSecret(duration) then
        if isSecret(info.isActive) or isSecret(info.isOnGCD) then return false end
        -- Secret times: trust the flags, and count any real cooldown as glow-worthy
        if info.isActive and not info.isOnGCD then
            return true, true, info.startTime, duration
        end
        return false
    end
    if duration and duration > 1.5 then
        return true, duration > 3, info.startTime, duration
    end
    return false
end

-- Several TBC spell IDs are different spells on Forever (12472 is Cold Snap, 11958 Ice Block,
-- 12292/12328 swap Sweeping Strikes and Death Wish), so name each entry after what its ID is
-- on this client. Unknown IDs (custom entries) keep their stored name.
function CooldownTracker:GetTrackedSpellName(spell)
    return GetSpellInfo(spell.spellId) or spell.name
end

function CooldownTracker:SetIconCooldown(cooldown, spellName, start, duration)
    if isSecret(start) or isSecret(duration) then
        local durationObject = C_Spell.GetSpellCooldownDuration(spellName)
        if durationObject then
            cooldown:SetCooldownFromDurationObject(durationObject)
        end
        return
    end
    cooldown:SetCooldown(start, duration)
end

-- The creature type is secret in combat, so treat a secret answer as unreadable rather than
-- compare it
function CooldownTracker:GetTargetCreatureType()
    local exists = UnitExists("target")
    if isSecret(exists) then return nil end
    if not exists then return false end
    local creatureType = UnitCreatureType("target")
    if isSecret(creatureType) then return nil end
    return creatureType
end

-- IsUsableSpell is C_Spell.IsSpellUsable here. A secret answer is treated as affordable, so
-- the icon keeps its normal look rather than guessing.
function CooldownTracker:IsOutOfMana(spellName)
    local isUsable = C_Spell and C_Spell.IsSpellUsable
    if not isUsable then return false end
    local _, noMana = isUsable(spellName)
    if isSecret(noMana) then return false end
    return noMana and true or false
end

-- As IsOutOfMana, a secret answer leaves the icon as it is.
function CooldownTracker:IsUnusable(spellName)
    local isUsable = C_Spell and C_Spell.IsSpellUsable
    if not isUsable then return false end
    local usable, noMana = isUsable(spellName)
    if isSecret(usable) or isSecret(noMana) then return false end
    return usable == false and not noMana
end

-- Should the usability answer ever be secret, IsOutOfMana reads it as affordable; tint the
-- icon from the secret answer instead, which the texture accepts, so the blue still shows.
-- (The ready glow cannot be held back then, as that needs the answer read.)
local oomColour, readyColour

function CooldownTracker:SetReadyIconColour(icon, spellName)
    local isUsable = C_Spell and C_Spell.IsSpellUsable
    if isUsable and icon.SetVertexColorFromBoolean and CreateColor then
        local _, noMana = isUsable(spellName)
        if isSecret(noMana) then
            oomColour = oomColour or CreateColor(0.5, 0.5, 1, 1)
            readyColour = readyColour or CreateColor(1, 1, 1, 1)
            icon:SetVertexColorFromBoolean(noMana, oomColour, readyColour)
            return
        end
    end
    icon:SetVertexColor(1, 1, 1, 1)
end

-- When the creature type is secret (in combat), ask the range check instead. It stays plain
-- in combat and answers nil when the spell cannot be cast on the target at all (a humanoid
-- for Exorcism), and true or false, in or out of range, when it can.
local baseGetTargetFit = CooldownTracker.GetTargetFit

function CooldownTracker:GetTargetFit(spell)
    local fit = baseGetTargetFit(self, spell)
    if fit ~= nil then return fit end
    local limited = Castborn.SpellData and Castborn.SpellData.targetCreatureTypes[spell.spellId]
    if not limited then return nil end
    local inRange = C_Spell.IsSpellInRange(self:GetTrackedSpellName(spell), "target")
    if isSecret(inRange) then return nil end
    return inRange ~= nil
end

--------------------------------------------------------------------------------
-- Class cooldown lists
--------------------------------------------------------------------------------

-- TBC talents Forever does not have (see ForeverDB), and cooldowns only Forever has
local notOnForever = {
    [31842] = true,  -- Divine Illumination
    [31884] = true,  -- Avenging Wrath
    [31935] = true,  -- Avenger's Shield
}

local foreverCooldowns = {
    PALADIN = {
        { spellId = 1310994, name = "Swift Judgement" },
    },
}

-- Built once per class, so callers get the same list each time, as on TBC
local SpellData = Castborn.SpellData
local baseGetClassCooldowns = SpellData.GetClassCooldowns
local classLists = {}

function SpellData:GetClassCooldowns(class)
    if not classLists[class] then
        local list = {}
        for _, spell in ipairs(baseGetClassCooldowns(self, class)) do
            if not notOnForever[spell.spellId] then list[#list + 1] = spell end
        end
        for _, spell in ipairs(foreverCooldowns[class] or {}) do
            list[#list + 1] = spell
        end
        classLists[class] = list
    end
    return classLists[class]
end

-- Saved lists made before this still hold the TBC talents; a spell the player added
-- themselves is left alone
function CooldownTracker:DropSpellsNotOnForever()
    for _, group in ipairs(self:GetGroups()) do
        local spells = group.spells or {}
        for i = #spells, 1, -1 do
            if notOnForever[spells[i].spellId] and not spells[i].custom then
                table.remove(spells, i)
            end
        end
    end
end

local baseLoadDefaultSpells = CooldownTracker.LoadDefaultSpells

function CooldownTracker:LoadDefaultSpells()
    baseLoadDefaultSpells(self)
    self:DropSpellsNotOnForever()
end

-- Another profile can still hold them too
Castborn:RegisterCallback("PROFILE_CHANGED", function()
    if CastbornDB.cooldowns then
        CooldownTracker:DropSpellsNotOnForever()
    end
end)

--------------------------------------------------------------------------------
-- Blizzard's Cooldown Manager
--------------------------------------------------------------------------------

-- The Essential and Utility rows duplicate the tracker; the buff viewers are left alone.
-- They are Edit Mode system frames, so (as the progress panel does with the XP bars) they
-- are faded and made click-through rather than reparented, which risks taint.
CooldownTracker.blizzardViewers = { "EssentialCooldownViewer", "UtilityCooldownViewer" }
CooldownTracker.hiddenViewers = {}

Castborn:RegisterCallback("INIT", function()
    if CastbornDB.cooldowns.hideBlizzardCooldowns == nil then
        CastbornDB.cooldowns.hideBlizzardCooldowns = true
    end
end)

function CooldownTracker:ShouldHideBlizzardCooldowns(db)
    return db and db.enabled and db.hideBlizzardCooldowns and true or false
end

-- Viewers whose SetAlpha / EnableMouse are already hooked (hooks cannot be removed)
local hookedViewers = {}
local forcing = false

-- Blizzard sets the viewers' alpha again (fading, opacity setting). Post-hooks record what it
-- asked for, so restoring gives back its latest wish, then put the viewer back to hidden.
-- They act only while the viewer is in hiddenViewers.
local function HookViewer(self, frame)
    if hookedViewers[frame] then return end
    hookedViewers[frame] = true
    hooksecurefunc(frame, "SetAlpha", function(_, alpha)
        local saved = self.hiddenViewers[frame]
        if not saved or forcing then return end
        saved.alpha = alpha
        forcing = true
        frame:SetAlpha(0)
        forcing = false
    end)
    hooksecurefunc(frame, "EnableMouse", function(_, enabled)
        local saved = self.hiddenViewers[frame]
        if not saved or forcing then return end
        saved.mouse = enabled and true or false
        forcing = true
        frame:EnableMouse(false)
        forcing = false
    end)
end

-- Hide or restore the viewers to match the settings
function CooldownTracker:UpdateBlizzardCooldowns()
    local hide = self:ShouldHideBlizzardCooldowns(CastbornDB and CastbornDB.cooldowns)
    for _, name in ipairs(self.blizzardViewers) do
        local frame = _G[name]
        local saved = frame and self.hiddenViewers[frame]
        if frame and hide and not saved then
            self.hiddenViewers[frame] = { alpha = frame:GetAlpha(), mouse = frame:IsMouseEnabled() }
            HookViewer(self, frame)
            forcing = true
            frame:SetAlpha(0)
            frame:EnableMouse(false)
            forcing = false
        elseif saved and not hide then
            -- Out of hiddenViewers first, so the hooks let the restore through
            self.hiddenViewers[frame] = nil
            frame:SetAlpha(saved.alpha or 1)
            frame:EnableMouse(saved.mouse and true or false)
        end
    end
end

-- Checked every tick, so toggling the tracker or the option, a profile change, or a viewer
-- Blizzard builds late all take effect without extra plumbing
local baseUpdateAll = CooldownTracker.UpdateAll

function CooldownTracker:UpdateAll()
    baseUpdateAll(self)
    self:UpdateBlizzardCooldowns()
end

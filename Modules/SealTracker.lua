-- Modules/SealTracker.lua
-- Shows the paladin's active seal as one icon with a swipe for its remaining time.
-- Seals are matched by spell name, so every rank (and any client's spell IDs) counts.
local SealTracker = {}
Castborn.SealTracker = SealTracker

local CB = Castborn

local frame = nil
local testModeActive = false

local sealNames = {}
local judgementNames = {}
local ignoredSpellIds = {}

-- What the icon shows: { spellId, expirationTime, duration }, all nil when no seal is up
SealTracker.state = {}

local defaults = {
    enabled = true,
    iconSize = 40,
    point = "CENTER",
    xPct = -0.05,
    yPct = -0.185,
    showCountdown = true,
    warnNoSeal = true,
    warnInCombatOnly = false,
}

-- Icon for the no-seal warning before any seal has been seen
local fallbackSpellId = nil

--------------------------------------------------------------------------------
-- Seal names
--------------------------------------------------------------------------------

-- Returns the name and ID of the first spell in the list the client knows
local function FirstKnownName(spellIds)
    for _, id in ipairs(spellIds) do
        local name = GetSpellInfo(id)
        if name then return name, id end
    end
    return nil
end

function SealTracker:BuildNames()
    wipe(sealNames)
    wipe(judgementNames)
    fallbackSpellId = nil
    local data = Castborn.SpellData
    if not data or not data.seals then return end
    for _, seal in ipairs(data.seals) do
        local name, id = FirstKnownName(seal.spellIds)
        if name then
            sealNames[name] = true
            fallbackSpellId = fallbackSpellId or id
        end
    end
    local judgement = FirstKnownName(data.judgementSpellIds or {})
    if judgement then judgementNames[judgement] = true end
    ignoredSpellIds = data.sealIgnoreSpellIds or {}
end

function SealTracker:IsSeal(name)
    return name ~= nil and sealNames[name] == true
end

function SealTracker:IsJudgement(name)
    return name ~= nil and judgementNames[name] == true
end

function SealTracker:IsIgnoredSpell(spellId)
    return ignoredSpellIds[spellId] == true
end

--------------------------------------------------------------------------------
-- Seams over aura reads, which Forever blocks in combat; SealTracker_Forever.lua overrides them.
--------------------------------------------------------------------------------

function SealTracker:CanReadAuras()
    return true
end

-- Returns spellId, expirationTime, duration of the active seal, or nil
function SealTracker:FindActiveSeal()
    for i = 1, 40 do
        local name, _, _, _, duration, expirationTime, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if self:IsSeal(name) then
            return spellId, expirationTime, duration
        end
    end
    return nil
end

-- The buff is always readable on TBC, so casts are not needed there
function SealTracker:OnPlayerCast(spellId)
end

--------------------------------------------------------------------------------
-- State and display
--------------------------------------------------------------------------------

function SealTracker:SetState(spellId, expirationTime, duration)
    local s = self.state
    s.spellId = spellId
    s.expirationTime = spellId and expirationTime or nil
    s.duration = spellId and duration or nil
    if spellId then self.lastSpellId = spellId end
end

-- "active" while a seal is up, "warning" when none is (and the warning is on), else "hidden"
function SealTracker:GetDisplayMode(db)
    if self.state.spellId then return "active" end
    if db.warnNoSeal == false then return "hidden" end
    if UnitIsDeadOrGhost("player") then return "hidden" end
    if db.warnInCombatOnly and not UnitAffectingCombat("player") then return "hidden" end
    return "warning"
end

-- Icon for the warning: the last seal seen, else the first seal the client knows
function SealTracker:GetWarningSpellId()
    return self.lastSpellId or fallbackSpellId
end

function SealTracker:UpdateState()
    if self:CanReadAuras() then
        self:SetState(self:FindActiveSeal())
    end
    local s = self.state
    if s.spellId and s.expirationTime and s.expirationTime > 0 and s.expirationTime <= GetTime() then
        self:SetState(nil)
    end
end

-- Red-tinted, greyed icon with "!" for the warning; plain icon for an active seal
local function SetWarningLook(on)
    frame.icon:SetDesaturated(on)
    if on then
        frame.icon:SetVertexColor(1, 0.3, 0.3, 1)
        frame.warning:Show()
    else
        frame.icon:SetVertexColor(1, 1, 1, 1)
        frame.warning:Hide()
    end
end

function SealTracker:Render(db)
    if not frame or testModeActive then return end
    local mode = self:GetDisplayMode(db)
    if mode == "hidden" then
        frame.shownSpellId, frame.shownExpiration, frame.shownWarning = nil, nil, nil
        frame:Hide()
        return
    end
    if mode == "warning" then
        local spellId = self:GetWarningSpellId()
        if not frame.shownWarning or frame.shownSpellId ~= spellId then
            frame.icon:SetTexture(spellId and GetSpellTexture(spellId) or nil)
            frame.cooldown:Clear()
            SetWarningLook(true)
            frame.shownWarning, frame.shownSpellId, frame.shownExpiration = true, spellId, nil
        end
        frame:Show()
        return
    end
    local s = self.state
    if frame.shownWarning or frame.shownSpellId ~= s.spellId or frame.shownExpiration ~= s.expirationTime then
        SetWarningLook(false)
        frame.shownWarning = nil
        frame.icon:SetTexture(GetSpellTexture(s.spellId))
        if s.duration and s.duration > 0 and s.expirationTime then
            frame.cooldown:SetCooldown(s.expirationTime - s.duration, s.duration)
        else
            frame.cooldown:Clear()
        end
        frame.shownSpellId, frame.shownExpiration = s.spellId, s.expirationTime
    end
    frame:Show()
end

function SealTracker:Refresh()
    local db = CB.db and CB.db.seals
    if not frame or testModeActive then return end
    if not db or not db.enabled then
        frame:Hide()
        return
    end
    self:UpdateState()
    self:Render(db)
end

-- Size of the "!" warning text for an icon size
local function WarningFontSize(size)
    return math.max(14, math.floor(size * 0.4))
end

local function CreateSealFrame()
    local db = CB.db.seals
    local masqueGroup = Castborn.Masque and Castborn.Masque.enabled and Castborn.Masque.groups.seals or nil
    local f = Castborn:CreateMasqueButton(UIParent, "Castborn_SealTracker", db.iconSize or 40, masqueGroup)
    f:SetFrameStrata("MEDIUM")
    f.cooldown:SetHideCountdownNumbers(db.showCountdown == false)

    -- "!" shown over the icon when no seal is up
    local size = db.iconSize or 40
    local warning = f:CreateFontString(nil, "OVERLAY")
    warning:SetFont(Castborn:GetBarFont(), WarningFontSize(size), "OUTLINE")
    Castborn:RegisterFontString(warning, WarningFontSize(size), "OUTLINE")
    warning:SetPoint("CENTER", 0, 0)
    warning:SetText("!")
    warning:SetTextColor(1, 0.2, 0.2, 1)
    warning:Hide()
    f.warning = warning

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(f, db, nil, "Seal Tracker")
    end
    CB:ApplyPosition(f, "seals")

    f:Hide()
    return f
end

-- Resize the icon. Masque sizes the icon, border and swipe when it skins the button,
-- so the group is re-skinned or the new size would not show.
function SealTracker:ResizeIcon(f, size)
    f:SetSize(size, size)
    f.warning:SetFont(Castborn:GetBarFont(), WarningFontSize(size), "OUTLINE")
    Castborn:RegisterFontString(f.warning, WarningFontSize(size), "OUTLINE")
    if Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:ReSkin("seals")
    end
end

-- Called by the options page when any seal setting changes
function SealTracker:ApplySettings()
    local db = CB.db.seals
    if not frame then return end
    self:ResizeIcon(frame, db.iconSize or 40)
    frame.cooldown:SetHideCountdownNumbers(db.showCountdown == false)
    frame.shownSpellId, frame.shownWarning = nil, nil  -- redraw the icon and swipe
    self:Refresh()
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

CB:RegisterCallback("INIT", function()
    CastbornDB.seals = CB:MergeDefaults(CastbornDB.seals or {}, defaults)
end)

CB:RegisterCallback("READY", function()
    if CB:GetPlayerInfo().class ~= "PALADIN" then return end

    SealTracker:BuildNames()
    frame = CreateSealFrame()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_DEAD")
    eventFrame:SetScript("OnEvent", function(_, event, unit, _, spellId)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if unit ~= "player" then return end
            SealTracker:OnPlayerCast(spellId)
        elseif event == "UNIT_AURA" then
            if unit ~= "player" then return end
        elseif event == "PLAYER_DEAD" then
            SealTracker:SetState(nil)
        end
        SealTracker:Refresh()
    end)

    -- Expiry and missed events
    CB:CreateThrottledUpdater(0.25, function() SealTracker:Refresh() end)

    SealTracker:Refresh()

    CB.TestManager:Register("SealTracker",
        function() CB:TestSealTracker() end,
        function() CB:EndTestSealTracker() end
    )
end)

--------------------------------------------------------------------------------
-- Test Mode
--------------------------------------------------------------------------------

function CB:TestSealTracker()
    if not frame then return end
    testModeActive = true
    SetWarningLook(false)
    frame.icon:SetTexture(GetSpellTexture(20154) or "Interface\\Icons\\Ability_ThunderBolt")
    frame.cooldown:SetCooldown(GetTime(), 30)
    frame.shownSpellId, frame.shownWarning = nil, nil
    frame:Show()
end

function CB:EndTestSealTracker()
    testModeActive = false
    if frame then
        frame:Hide()
        SealTracker:Refresh()
    end
end

Castborn:RegisterModule("SealTracker", SealTracker)

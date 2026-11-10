--[[
    Castborn - cooldown finish effect on Forever
    Plays a pulse, burst or flash on a button when its cooldown comes back. Detection uses
    plain values only (whether a cooldown is active, and GetTime), so it works in combat:
    events find cooldowns that start, a ticker watches only those, and an effect fires when
    one ends after running longer than the minimum duration (so never for the GCD).
    Shares the buttons registered by CooldownText_Forever.lua.
    Loaded only by Castborn_Camelot.toc, after CooldownText_Forever.lua.
]]

local CB = Castborn
local CooldownText = CB.CooldownText
local Finish = {}
CooldownText.Finish = Finish

local TICK = 0.1
local SCAN_EVERY = 5            -- ticks between full scans, as a fallback to the events
local GCD_GUARD = 1.6           -- seconds; even with "hide under" at 0, the GCD never fires
local STANDARD_BUTTON = 45      -- Blizzard's button size the proc burst art is drawn for
local BURST_SIZE = 150

Finish.effects = { "none", "pulse", "burst", "flash" }
Finish.labels = { none = "None", pulse = "Pulse", burst = "Burst", flash = "Flash" }

-- cooldown frame -> GetTime() when it was first seen active
Finish.cooling = setmetatable({}, { __mode = "k" })
-- owner frame -> { pulse = frame, burst = frame, flash = frame }
local fxFrames = setmetatable({}, { __mode = "k" })

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

local function DB()
    return CB.db and CB.db.cooldowntext
end

-- true / false when known, nil when the client will not say (secret or no data)
function Finish:IsCooling(cooldown, entry)
    if entry.kind ~= "actionbar" then
        return cooldown:IsShown() == true
    end
    local button, info = entry.button, nil
    if button.GetCooldownInfo then
        info = button:GetCooldownInfo()  -- LibActionButton (Bartender4)
    elseif type(button.action) == "number" and C_ActionBar and C_ActionBar.GetActionCooldown then
        info = C_ActionBar.GetActionCooldown(button.action)
    end
    if type(info) ~= "table" or isSecret(info) then return nil end
    local active = info.isActive
    if active == nil or isSecret(active) then return nil end
    return active == true
end

function Finish:Threshold()
    return math.max(DB().minDuration or 0, GCD_GUARD)
end

local function Owner(cooldown, entry)
    return entry.button or cooldown:GetParent()
end

local function Watchable(cooldown, entry)
    if not CooldownText:IsActiveFor(entry) then return false end
    local owner = Owner(cooldown, entry)
    return owner ~= nil and owner:IsVisible()
end

-- Find cooldowns that have started
function Finish:Scan()
    local now = GetTime()
    for cooldown, entry in pairs(CooldownText.entries) do
        if not self.cooling[cooldown] and Watchable(cooldown, entry) and self:IsCooling(cooldown, entry) == true then
            self.cooling[cooldown] = now
        end
    end
end

-- Watch the started ones; fire when one ends after a real cooldown
function Finish:Check()
    local now = GetTime()
    for cooldown, since in pairs(self.cooling) do
        local entry = CooldownText.entries[cooldown]
        local state = entry and self:IsCooling(cooldown, entry)
        if not entry then
            self.cooling[cooldown] = nil
        elseif state == false then
            self.cooling[cooldown] = nil
            if now - since >= self:Threshold() and Watchable(cooldown, entry) then
                self:Play(Owner(cooldown, entry))
            end
        end
    end
end

-- Effects ---------------------------------------------------------------------

local function Icon(owner)
    return owner.icon or owner.Icon
end

local function NewLayer(owner)
    local f = CreateFrame("Frame", nil, owner)
    f:SetPoint("CENTER", owner, "CENTER")
    f:SetFrameLevel(owner:GetFrameLevel() + 10)
    f:Hide()
    return f
end

local function HideWhenDone(group, frame)
    group:SetScript("OnFinished", function() frame:Hide() end)
end

local builders = {}

-- OmniCC-style: a copy of the icon swells and fades
function builders.pulse(owner)
    local f = NewLayer(owner)
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    f.texture = tex
    local group = f:CreateAnimationGroup()
    local grow = group:CreateAnimation("Scale")
    grow:SetScaleFrom(1, 1)
    grow:SetScaleTo(1.5, 1.5)
    grow:SetDuration(0.4)
    grow:SetSmoothing("OUT")
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.4)
    fade:SetSmoothing("IN")
    HideWhenDone(group, f)
    f.anim = group
    f.prepare = function(self)
        local size = owner:GetWidth()
        self:SetSize(size, size)
        local icon = Icon(owner)
        if not icon then return false end
        local ok, texture = pcall(icon.GetTexture, icon)
        if not ok or texture == nil then return false end
        self.texture:SetTexture(texture)
        return true
    end
    return f
end

-- Blizzard's proc-start burst, played once
function builders.burst(owner)
    local f = NewLayer(owner)
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas("UI-HUD-ActionBar-Proc-Start-Flipbook")
    tex:SetAllPoints()
    local group = f:CreateAnimationGroup()
    local flip = group:CreateAnimation("FlipBook")
    flip:SetTarget(tex)
    flip:SetFlipBookRows(6)
    flip:SetFlipBookColumns(5)
    flip:SetFlipBookFrames(30)
    flip:SetFlipBookFrameWidth(0)
    flip:SetFlipBookFrameHeight(0)
    flip:SetDuration(0.7)
    HideWhenDone(group, f)
    f.anim = group
    f.prepare = function(self)
        local size = owner:GetWidth() * BURST_SIZE / STANDARD_BUTTON
        self:SetSize(size, size)
        return true
    end
    return f
end

-- Blizzard's own "cooldown ready" flash
function builders.flash(owner)
    local f = NewLayer(owner)
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas("UI-HUD-ActionBar-GCD-Flipbook")
    tex:SetAllPoints()
    local group = f:CreateAnimationGroup()
    local flip = group:CreateAnimation("FlipBook")
    flip:SetTarget(tex)
    flip:SetFlipBookRows(11)
    flip:SetFlipBookColumns(2)
    flip:SetFlipBookFrames(22)
    flip:SetFlipBookFrameWidth(0)
    flip:SetFlipBookFrameHeight(0)
    flip:SetDuration(0.75)
    HideWhenDone(group, f)
    f.anim = group
    f.prepare = function(self)
        self:SetSize(owner:GetWidth(), owner:GetHeight())
        return true
    end
    return f
end

function Finish:Play(owner, effect)
    effect = effect or DB().finishEffect
    local build = builders[effect]
    if not build or not owner then return end
    fxFrames[owner] = fxFrames[owner] or {}
    local f = fxFrames[owner][effect]
    if not f then
        f = build(owner)
        fxFrames[owner][effect] = f
    end
    f.anim:Stop()
    if not f:prepare() then return end
    f:Show()
    f.anim:Play()
end

-- Options "Preview": play the chosen effect on every visible button that has an icon
function Finish:Preview()
    local played = 0
    for cooldown, entry in pairs(CooldownText.entries) do
        if played >= 24 then break end
        if Watchable(cooldown, entry) then
            self:Play(Owner(cooldown, entry))
            played = played + 1
        end
    end
end

function Finish:IsOn()
    local db = DB()
    return db ~= nil and db.enabled and db.finishEffect ~= nil and db.finishEffect ~= "none"
end

CB:RegisterCallback("READY", function()
    local events = CreateFrame("Frame")
    events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    events:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    events:RegisterEvent("BAG_UPDATE_COOLDOWN")
    events:SetScript("OnEvent", function()
        if Finish:IsOn() then Finish:Scan() end
    end)

    local ticks = 0
    CB:CreateThrottledUpdater(TICK, function()
        if not Finish:IsOn() then
            wipe(Finish.cooling)
            return
        end
        ticks = ticks + 1
        if ticks >= SCAN_EVERY then
            ticks = 0
            Finish:Scan()
        end
        Finish:Check()
    end)
    Finish:Scan()
end)

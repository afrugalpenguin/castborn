--[[
    Castborn - Forever API probe
    Reports which APIs exist on the Forever client and whether they return secret values.
    Loaded only by Castborn_Camelot.toc.
]]

local APICheck = {}
Castborn.APICheck = APICheck

local function pack(...)
    return { n = select("#", ...), ... }
end

-- Walk a dotted path such as "C_Spell.GetSpellInfo" from _G
function APICheck:Resolve(path)
    local value = _G
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

-- "secret" for protected values, otherwise the Lua type; tables list their top-level fields
function APICheck:Describe(value, nested)
    if issecretvalue and issecretvalue(value) then return "secret" end
    if type(value) ~= "table" or nested then return type(value) end
    local parts = {}
    for k, v in pairs(value) do
        parts[#parts + 1] = tostring(k) .. "=" .. self:Describe(v, true)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

-- Call an API by path under pcall and describe every return value
function APICheck:DescribeCall(path, ...)
    local fn = self:Resolve(path)
    if type(fn) ~= "function" then return "missing" end
    local results = pack(pcall(fn, ...))
    if not results[1] then return "error: " .. tostring(results[2]) end
    return self:DescribeValues(unpack(results, 2, results.n))
end

-- Describe each value in a vararg list, keeping nils in position
function APICheck:DescribeValues(...)
    local n = select("#", ...)
    if n == 0 then return "(no returns)" end
    local parts = {}
    for i = 1, n do
        local ok, desc = pcall(self.Describe, self, (select(i, ...)))
        parts[#parts + 1] = ok and desc or "undescribable"
    end
    return table.concat(parts, " ")
end

-- Throwaway widgets whose methods are checked by Run
local probeBar = CreateFrame("StatusBar")
local probeCooldown = CreateFrame("Cooldown")
local probeTexture = probeBar:CreateTexture()
-- A font template is required, or SetText errors "Font not set" and the countdown probe misreports
local probeText = probeBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local probeWidgets = { StatusBar = probeBar, Cooldown = probeCooldown, Texture = probeTexture, FontString = probeText }

local function InCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

local function CombatKey(key)
    return InCombat() and (key .. " [combat]") or key
end

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

-- Rendering probes (issue #236). Once per combat, the first cast with a cooldown duration
-- tries each secret-safe display path the graphics research found, and records what happened.
-- Set up like the GCD watcher, which already relies on OnCooldownDone: visible, nothing drawn.
-- The first probe used alpha 0 and the callback never fired (#238).
local renderCooldown = CreateFrame("Cooldown", nil, UIParent)
renderCooldown:SetSize(1, 1)
renderCooldown:SetPoint("CENTER")
renderCooldown:SetDrawSwipe(false)
renderCooldown:SetDrawEdge(false)
renderCooldown:SetDrawBling(false)
renderCooldown:SetScript("OnCooldownDone", function() APICheck:OnRenderCooldownDone() end)
local renderTexture = probeBar:CreateTexture()
local renderText = probeBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local fallbackText = probeBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")

-- Text binding methods worth knowing about; the report lists which exist
local bindingMethods = {
    "SetFontString", "SetDuration", "SetFormatter", "SetTextFormat", "SetUpdateInterval",
    "SetEnabled", "Enable", "IsEnabled", "GetFormattedText",
}

local function DescribeText(self, ok, text)
    if not ok then return "error: " .. tostring(text) end
    if type(text) == "string" and not isSecret(text) then return "string '" .. text .. "'" end
    return self:Describe(text)
end

function APICheck:OnRenderCooldownDone()
    self.events[CombatKey("Cooldown OnCooldownDone")] = "fired"
end

-- Evaluate a colour (or number) curve against the duration and feed the result to a texture
function APICheck:TryCurve(duration, colour)
    if not (C_CurveUtil and CreateColor) then return "missing" end
    local ok, desc = pcall(function()
        if colour then
            local curve = C_CurveUtil.CreateColorCurve()
            curve:AddPoint(0, CreateColor(1, 0, 0, 1))
            curve:AddPoint(1, CreateColor(0, 1, 0, 1))
            local c = duration:EvaluateRemainingPercent(curve)
            renderTexture:SetVertexColor(c:GetRGBA())
            if isSecret(c) then return "secret" end
            return "r=" .. self:Describe(c.r)
        end
        local curve = C_CurveUtil.CreateCurve()
        curve:AddPoint(0, 0)
        curve:AddPoint(1, 1)
        local a = duration:EvaluateRemainingPercent(curve)
        renderTexture:SetAlpha(a)
        return self:Describe(a)
    end)
    if not ok then return "error: " .. tostring(desc) end
    return "ok " .. desc
end

function APICheck:RecordBoundText(label)
    local key = "Duration text binding text" .. (label and (" " .. label) or "")
    self.events[CombatKey(key)] = DescribeText(self, pcall(renderText.GetText, renderText))
    local binding = self.textBinding
    if binding and binding.GetFormattedText then
        self.events[CombatKey("Duration text binding GetFormattedText" .. (label and (" " .. label) or ""))] =
            DescribeText(self, pcall(binding.GetFormattedText, binding))
    end
end

-- Bind a font string to the duration; the text is read back after 0.5s and 2s
function APICheck:TryTextBinding(duration)
    if not (C_DurationUtil and C_DurationUtil.CreateDurationTextBinding) then return "missing" end
    local ok, err = pcall(function()
        local binding = C_DurationUtil.CreateDurationTextBinding()
        local present = {}
        for _, name in ipairs(bindingMethods) do
            if binding[name] then present[#present + 1] = name end
        end
        self.events["Duration text binding methods"] = table.concat(present, ",")
        binding:SetFontString(renderText)
        if C_StringUtil and C_StringUtil.CreateSecondsFormatter then
            binding:SetFormatter(C_StringUtil.CreateSecondsFormatter())
        end
        if binding.SetUpdateInterval then binding:SetUpdateInterval(0.1) end
        binding:SetDuration(duration)
        if binding.SetEnabled then binding:SetEnabled(true) elseif binding.Enable then binding:Enable() end
        self.textBinding = binding  -- keep it alive until the text is read
    end)
    if not ok then return "error: " .. tostring(err) end
    if C_Timer then
        C_Timer.After(0.5, function() self:RecordBoundText("0.5s") end)
        C_Timer.After(2, function() self:RecordBoundText("2s") end)
    end
    return "ok"
end

-- The fallback for countdown text: pass the (secret) remaining time straight to SetFormattedText
function APICheck:TryFormattedText(duration)
    local ok, err = pcall(function()
        fallbackText:SetFormattedText("%.1f", duration:GetRemainingDuration())
    end)
    if not ok then return "error: " .. tostring(err) end
    return "ok, text " .. DescribeText(self, pcall(fallbackText.GetText, fallbackText))
end

function APICheck:ProbeRendering(duration)
    local ok, err = pcall(renderCooldown.SetCooldownFromDurationObject, renderCooldown, duration)
    self.events[CombatKey("Cooldown armed from duration")] = ok and "ok" or ("error: " .. tostring(err))
    self.events[CombatKey("Curve colour into SetVertexColor")] = self:TryCurve(duration, true)
    self.events[CombatKey("Curve number into SetAlpha")] = self:TryCurve(duration, false)
    self.events[CombatKey("Duration text binding")] = self:TryTextBinding(duration)
    self.events[CombatKey("SetFormattedText with remaining time")] = self:TryFormattedText(duration)
end

-- The spell ID may be secret; GetSpellCooldownDuration then errors inside pcall and is skipped
function APICheck:MaybeProbeRendering(spellID)
    if self.renderProbed or not InCombat() then return end
    local fn = C_Spell and C_Spell.GetSpellCooldownDuration
    if not fn then return end
    local ok, duration = pcall(fn, spellID)
    if not ok or duration == nil then return end
    -- A zero duration would never finish, so wait for a cast that has one
    local zeroOk, zero = pcall(duration.IsZero, duration)
    if zeroOk and not isSecret(zero) and zero == true then return end
    self.renderProbed = true
    self:ProbeRendering(duration)
end

-- Candidate duration object methods; any that exist are listed in the report
local durationMethods = {
    "GetRemainingDuration", "GetElapsedDuration", "GetTotalDuration",
    "GetStartTime", "GetEndTime", "IsZero",
}

-- What a cast duration object offers: its methods, the type of its remaining time, and
-- whether that time survives string.format and SetText (the route to countdown text when secret)
function APICheck:DescribeDuration(path, unit)
    local fn = self:Resolve(path)
    if type(fn) ~= "function" then return "missing" end
    local ok, obj = pcall(fn, unit)
    if not ok then return "error: " .. tostring(obj) end
    if obj == nil then return "nil" end
    -- The real object is not a plain table (its metatable hides __index), so look methods up by name
    local methods = {}
    for _, name in ipairs(durationMethods) do
        local okM, method = pcall(function() return obj[name] end)
        if okM and type(method) == "function" then methods[#methods + 1] = name end
    end
    local remaining, format = "n/a", "n/a"
    local okG, getRemaining = pcall(function() return obj.GetRemainingDuration end)
    if okG and type(getRemaining) == "function" then
        local okR, value = pcall(getRemaining, obj)
        remaining = okR and self:Describe(value) or ("error: " .. tostring(value))
        if okR then
            local okF, text = pcall(string.format, "%.1f", value)
            format = okF and "ok" or ("error: " .. tostring(text))
            if okF then
                local okT, err = pcall(probeText.SetText, probeText, text)
                if not okT then format = "SetText error: " .. tostring(err) end
            end
        end
    end
    return "type=" .. type(obj) .. " methods=" .. table.concat(methods, ",")
        .. " remaining=" .. remaining .. " format=" .. format
end

-- APIs Castborn's modules call on TBC, plus their Mainline replacements
APICheck.names = {
    "UnitBuff", "UnitDebuff", "UnitAura",
    "C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetPlayerAuraBySpellID",
    "GetSpellInfo", "C_Spell.GetSpellInfo",
    "GetSpellCooldown", "C_Spell.GetSpellCooldown",
    "GetSpellTexture", "C_Spell.GetSpellTexture",
    "GetSpellSubtext", "C_Spell.GetSpellSubtext",
    "IsSpellKnown", "IsPlayerSpell",
    "UnitCastingInfo", "UnitChannelInfo",
    "CombatLogGetCurrentEventInfo",
    "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo",
    "C_Container.GetContainerItemCooldown",
    "GetInventoryItemCooldown", "GetItemSpell", "C_Item.GetItemSpell",
    "GetItemInfo", "C_Item.GetItemInfo", "GetItemCount", "C_Item.GetItemCount",
    "GetCursorInfo", "ClearCursor", "GetTalentInfo", "C_SpecializationInfo.GetTalentInfo",
    "GetTotemInfo", "UnitAttackSpeed", "UnitRangedDamage", "GetWeaponEnchantInfo",
    "UnitPower", "UnitPowerMax", "UnitHealth",
    "GetShapeshiftForm", "GetNetStats",
    "C_NamePlate.GetNamePlateForUnit",
    "InterfaceOptions_AddCategory", "Settings.RegisterCanvasLayoutCategory",
    "ColorPickerFrame.SetupColorPickerAndShow", "OpacitySliderFrame",
    "UIDropDownMenu_Initialize", "UIDropDownMenu_CreateInfo",
    "issecretvalue",
    -- Possible Midnight display APIs for secret values (names unconfirmed)
    "UnitCastingDuration", "UnitChannelDuration", "C_DurationUtil.CreateDuration",
    "C_Spell.GetSpellCooldownDuration", "C_CurveUtil.CreateCurve",
    "UnitIsUnit", "C_UnitAuras.GetAuraDuration", "C_UnitAuras.GetAuraDataByAuraInstanceID",
    "BuffIconCooldownViewer", "BuffBarCooldownViewer", "EssentialCooldownViewer",
    "C_SwingTimer.EnableRangeCheck", "C_SwingTimer.IsTargetWithinSwingRange",
    "C_SpellActivationOverlay.IsSpellOverlayed",
    "C_DurationUtil.CreateDurationTextBinding", "C_StringUtil.CreateSecondsFormatter",
}

-- Tables whose fields are listed in the report (enum names the Forever ports need)
APICheck.values = {
    "Enum.StatusBarTimerDirection", "Enum.StatusBarInterpolation", "Enum.PlayerSwingType",
}

-- Calls made when /cbapi runs; have a buff up and target a caster mob first
APICheck.probes = {
    { "UnitCastingInfo", "player" },
    { "UnitChannelInfo", "player" },
    { "UnitBuff", "player", 1 },
    { "UnitDebuff", "target", 1 },
    { "C_UnitAuras.GetAuraDataByIndex", "player", 1, "HELPFUL" },
    { "C_UnitAuras.GetAuraDataByIndex", "target", 1, "HARMFUL" },
    { "GetSpellInfo", 6603 },            -- Auto Attack
    { "C_Spell.GetSpellInfo", 6603 },
    { "GetSpellCooldown", 61304 },       -- Global cooldown
    { "C_Spell.GetSpellCooldown", 61304 },
    { "GetTotemInfo", 1 },
    { "UnitAttackSpeed", "player" },
    { "UnitPower", "player", 0 },
    { "UnitHealth", "target" },
    { "C_Container.GetContainerNumSlots", 0 },
    { "GetInventoryItemCooldown", "player", 13 },
    { "UnitCastingInfo", "target" },
    { "UnitChannelInfo", "target" },
    { "C_Spell.GetSpellCooldown", "Charge" },
    { "C_Spell.GetSpellCooldown", "Battle Shout" },
    { "UnitCastingDuration", "player" },
    { "UnitCastingDuration", "target" },
    { "UnitChannelDuration", "target" },
    { "UnitIsUnit", "target", "player" },
    { "C_Container.GetContainerItemCooldown", 0, 1 },
    { "C_Item.GetItemCount", 6948 },     -- Hearthstone
    { "C_Item.GetItemInfo", 6948 },
    { "GetTalentInfo", 2, 7 },            -- Improved Righteous Fury, as in SpellData (rank is 5th)
    { "IsPlayerSpell", 20468 },           -- Improved Righteous Fury rank 1, a talent-check fallback
    -- Interrupts; only the player's class answers, the rest report nil
    { "C_Spell.GetSpellCooldown", "Counterspell" },
    { "C_Spell.GetSpellCooldown", "Kick" },
    { "C_Spell.GetSpellCooldown", "Pummel" },
    { "C_Spell.GetSpellCooldown", "Earth Shock" },
}

-- Widget methods that might accept secret values directly
APICheck.widgetMethods = {
    { "StatusBar", "SetTimerDuration" },
    { "StatusBar", "SetMinMaxValues" },
    { "StatusBar", "SetValue" },
    { "Cooldown", "SetCooldown" },
    { "Cooldown", "SetCooldownFromDurationObject" },
    { "Cooldown", "SetCooldownDuration" },
    { "Texture", "SetAlphaFromBoolean" },
    { "FontString", "SetFormattedText" },
}

-- Forever blocks aura reads in combat and blames Castborn, so these only run out of combat
local auraPaths = {
    ["UnitBuff"] = true, ["UnitDebuff"] = true, ["UnitAura"] = true,
    ["C_UnitAuras.GetAuraDataByIndex"] = true,
    ["C_UnitAuras.GetPlayerAuraBySpellID"] = true,
}

APICheck.events = {}
APICheck.live = {}
APICheck.eventCounts = {}
APICheck.cleu = { registered = "not attempted", count = 0 }
APICheck.overlaySpells = {}

local function ProbeKey(path, ...)
    local args = {}
    for i = 1, select("#", ...) do args[i] = tostring((select(i, ...))) end
    return path .. "(" .. table.concat(args, ",") .. ")"
end

local function Snapshot(path, ...)
    if auraPaths[path] and InCombat() then return end
    APICheck.events[CombatKey(ProbeKey(path, ...))] = APICheck:DescribeCall(path, ...)
end

function APICheck:OnEvent(event, unit, ...)
    self.eventCounts[event] = (self.eventCounts[event] or 0) + 1
    if event == "PLAYER_REGEN_ENABLED" then
        self.auraDurationTried = nil
        self.renderProbed = nil
        return
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self.cleu.count = self.cleu.count + 1
        if not self.cleu.sample then
            self.cleu.sample = self:DescribeCall("CombatLogGetCurrentEventInfo")
        end
    elseif event == "UNIT_SPELLCAST_START" and (unit == "player" or unit == "target") then
        Snapshot("UnitCastingInfo", unit)
        self.events[CombatKey(event .. "(" .. unit .. ") payload")] = self:DescribeValues(...)
        self.events[CombatKey("UnitCastingDuration(" .. unit .. ") object")] = self:DescribeDuration("UnitCastingDuration", unit)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" and (unit == "player" or unit == "target") then
        Snapshot("UnitChannelInfo", unit)
        self.events[CombatKey(event .. "(" .. unit .. ") payload")] = self:DescribeValues(...)
        self.events[CombatKey("UnitChannelDuration(" .. unit .. ") object")] = self:DescribeDuration("UnitChannelDuration", unit)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        -- spellID may be secret, so it is never used to build a key
        local spellID = select(2, ...)
        -- The seal tracker follows casts in combat, so it needs this to be plain
        self.events[CombatKey("UNIT_SPELLCAST_SUCCEEDED(player) spellID")] = self:Describe(spellID)
        self.events[CombatKey("C_Spell.GetSpellCooldown(last cast)")] = self:DescribeCall("C_Spell.GetSpellCooldown", spellID)
        self:MaybeProbeRendering(spellID)
    elseif event == "UNIT_AURA" and unit == "player" then
        local info = ...
        -- Count payload shapes, so a combat full update (no addedAuras) still leaves a trace
        local shapeKey = CombatKey("UNIT_AURA(player) payload " .. self:DescribeValues(info))
        self.events[shapeKey] = (self.events[shapeKey] or 0) + 1
        -- In combat the whole payload is secret (addedAuras included), so never index it then
        local addedAuras = type(info) == "table" and info.addedAuras
        if issecretvalue and issecretvalue(addedAuras) then return end
        local added = addedAuras and addedAuras[1]
        if added then
            self.events[CombatKey("UNIT_AURA(player) addedAura")] = self:DescribeValues(added)
            if InCombat() and not self.auraDurationTried then
                self.auraDurationTried = true
                self.events["C_UnitAuras.GetAuraDuration(player) [combat]"] =
                    self:DescribeCall("C_UnitAuras.GetAuraDuration", "player", added.auraInstanceID)
            end
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        -- No unit argument: the first value is the spell ID. A proc tracker would need it plain.
        local spellID = unit
        self.events[CombatKey(event .. " spellID")] = self:Describe(spellID)
        if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" and not isSecret(spellID) and type(spellID) == "number" then
            self.overlaySpells[spellID] = true
            local ids = {}
            for id in pairs(self.overlaySpells) do ids[#ids + 1] = id end
            table.sort(ids)
            self.events["SPELL_ACTIVATION_OVERLAY_GLOW_SHOW spells seen"] = table.concat(ids, ",")
        end
    elseif event == "PLAYER_SWING" then
        -- No unit argument: the first value is swingDuration. The swing timer needs it plain.
        self.events[CombatKey("PLAYER_SWING payload")] = self:DescribeValues(unit, ...)
    elseif event == "UNIT_AURA" and unit == "target" then
        Snapshot("C_UnitAuras.GetAuraDataByIndex", "target", 1, "HARMFUL")
        Snapshot("UnitDebuff", "target", 1)
    end
end

function APICheck:Run()
    local report = {
        time = date and date("%Y-%m-%d %H:%M:%S"),
        canDetectSecrets = issecretvalue ~= nil,
        inCombat = InCombat(),
        names = {},
        values = {},
        live = self.live,
        events = self.events,
        eventCounts = self.eventCounts,
        cleu = self.cleu,
        widgets = {},
    }
    if GetBuildInfo then
        local version, build, _, interface = GetBuildInfo()
        report.build = tostring(version) .. " (" .. tostring(build) .. ")"
        report.interface = interface
    end
    for _, path in ipairs(self.names) do
        local value = self:Resolve(path)
        report.names[path] = value == nil and "missing" or type(value)
    end
    for _, path in ipairs(self.values) do
        local value = self:Resolve(path)
        report.values[path] = value == nil and "missing" or self:Describe(value)
    end
    for _, probe in ipairs(self.probes) do
        local key = CombatKey(ProbeKey(unpack(probe)))
        if auraPaths[probe[1]] and InCombat() then
            report.live[key] = "skipped in combat"
        else
            report.live[key] = self:DescribeCall(unpack(probe))
        end
    end
    for _, entry in ipairs(self.widgetMethods) do
        local widgetType, method = entry[1], entry[2]
        local fn = probeWidgets[widgetType][method]
        report.widgets[widgetType .. ":" .. method] = type(fn) == "function" and "function" or "missing"
    end
    CastbornDB.apicheck = report
    return report
end

local function PrintSorted(title, tbl)
    local keys = {}
    for k in pairs(tbl) do keys[#keys + 1] = k end
    table.sort(keys)
    print("  " .. title .. ":")
    for _, k in ipairs(keys) do
        print("    " .. k .. " = " .. tostring(tbl[k]))
    end
end

function APICheck:Print(report)
    Castborn:Print("API check, interface " .. tostring(report.interface) .. ", build " .. tostring(report.build))
    local missing = {}
    for path, kind in pairs(report.names) do
        if kind == "missing" then missing[path] = kind end
    end
    PrintSorted("Missing APIs", missing)
    PrintSorted("Live calls", report.live)
    PrintSorted("Event snapshots", report.events)
    PrintSorted("Event counts", report.eventCounts)
    PrintSorted("Widget methods", report.widgets)
    PrintSorted("Values", report.values)
    print("  Combat log: registered=" .. tostring(report.cleu.registered)
        .. ", events=" .. report.cleu.count
        .. ", sample=" .. tostring(report.cleu.sample))
    print("  Can detect secrets: " .. tostring(report.canDetectSecrets))
    print("  Run in combat: " .. tostring(report.inCombat))
    Castborn:Print("Saved to CastbornDB.apicheck. /reload to write it to disk.")
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_AURA", "PLAYER_REGEN_ENABLED", "PLAYER_SWING",
        "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" }) do
    eventFrame:RegisterEvent(event)
end
-- The combat log is not registered: Forever ignored it in two probe runs and it is the
-- suspected cause of the "UI action blocked" message on login
eventFrame:SetScript("OnEvent", function(_, event, ...)
    APICheck:OnEvent(event, ...)
end)

SLASH_CASTBORNAPI1 = "/cbapi"
SlashCmdList["CASTBORNAPI"] = function()
    APICheck:Print(APICheck:Run())
end

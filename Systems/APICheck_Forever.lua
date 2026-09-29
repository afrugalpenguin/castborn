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
    if results.n == 1 then return "(no returns)" end
    local parts = {}
    for i = 2, results.n do
        local ok, desc = pcall(self.Describe, self, results[i])
        parts[#parts + 1] = ok and desc or "undescribable"
    end
    return table.concat(parts, " ")
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
    "GetTotemInfo", "UnitAttackSpeed", "UnitRangedDamage", "GetWeaponEnchantInfo",
    "UnitPower", "UnitPowerMax", "UnitHealth",
    "GetShapeshiftForm", "GetNetStats",
    "C_NamePlate.GetNamePlateForUnit",
    "InterfaceOptions_AddCategory", "Settings.RegisterCanvasLayoutCategory",
    "ColorPickerFrame.SetupColorPickerAndShow", "OpacitySliderFrame",
    "UIDropDownMenu_Initialize", "UIDropDownMenu_CreateInfo",
    "issecretvalue",
}

-- Calls made when /cbapi runs; target a mob with your DoT on it and have a buff up first
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
}

APICheck.events = {}
APICheck.cleu = { registered = "no", count = 0 }

local function ProbeKey(path, ...)
    local args = {}
    for i = 1, select("#", ...) do args[i] = tostring((select(i, ...))) end
    return path .. "(" .. table.concat(args, ",") .. ")"
end

local function Snapshot(path, ...)
    APICheck.events[ProbeKey(path, ...)] = APICheck:DescribeCall(path, ...)
end

function APICheck:OnEvent(event, unit)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self.cleu.count = self.cleu.count + 1
        if not self.cleu.sample then
            self.cleu.sample = self:DescribeCall("CombatLogGetCurrentEventInfo")
        end
    elseif event == "UNIT_SPELLCAST_START" and (unit == "player" or unit == "target") then
        Snapshot("UnitCastingInfo", unit)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" and (unit == "player" or unit == "target") then
        Snapshot("UnitChannelInfo", unit)
    elseif event == "UNIT_AURA" and unit == "target" then
        Snapshot("C_UnitAuras.GetAuraDataByIndex", "target", 1, "HARMFUL")
        Snapshot("UnitDebuff", "target", 1)
    end
end

function APICheck:Run()
    local report = {
        time = date and date("%Y-%m-%d %H:%M:%S"),
        canDetectSecrets = issecretvalue ~= nil,
        names = {},
        live = {},
        events = self.events,
        cleu = self.cleu,
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
    for _, probe in ipairs(self.probes) do
        report.live[ProbeKey(unpack(probe))] = self:DescribeCall(unpack(probe))
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
    print("  Combat log: registered=" .. tostring(report.cleu.registered)
        .. ", events=" .. report.cleu.count
        .. ", sample=" .. tostring(report.cleu.sample))
    print("  Can detect secrets: " .. tostring(report.canDetectSecrets))
    Castborn:Print("Saved to CastbornDB.apicheck. /reload to write it to disk.")
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_AURA" }) do
    eventFrame:RegisterEvent(event)
end
local ok, err = pcall(eventFrame.RegisterEvent, eventFrame, "COMBAT_LOG_EVENT_UNFILTERED")
APICheck.cleu.registered = ok and "yes" or ("error: " .. tostring(err))
eventFrame:SetScript("OnEvent", function(_, event, unit)
    APICheck:OnEvent(event, unit)
end)

SLASH_CASTBORNAPI1 = "/cbapi"
SlashCmdList["CASTBORNAPI"] = function()
    APICheck:Print(APICheck:Run())
end

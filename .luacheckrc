-- Luacheck configuration for Castborn WoW addon
std = "lua51"
max_line_length = false

-- WoW addon globals (writable)
globals = {
    "Castborn",
    "CastbornDB",
    "SLASH_CASTBORN1",
    "SLASH_CASTBORN2",
    "SlashCmdList",
    "ColorPickerFrame",
    "StaticPopupDialogs",
    "playerCastbar",
}

read_globals = {
    -- WoW Frame API
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "DEFAULT_CHAT_FRAME",
    "StaticPopup_Show",
    "InterfaceOptionsFrame_OpenToCategory",
    "InterfaceOptions_AddCategory",
    "InterfaceOptionsFrame",
    "SettingsPanel",
    "Settings",
    "hooksecurefunc",
    "BackdropTemplateMixin",

    -- WoW Unit API
    "UnitClass",
    "UnitName",
    "UnitExists",
    "UnitIsPlayer",
    "UnitIsUnit",
    "UnitIsDeadOrGhost",
    "UnitDebuff",
    "UnitBuff",
    "UnitGUID",
    "UnitAffectingCombat",
    "UnitPower",
    "UnitPowerMax",
    "UnitPowerType",
    "UnitCastingInfo",
    "UnitChannelInfo",
    "UnitPosition",
    "UnitAttackSpeed",
    "UnitRangedDamage",
    "UnitRace",
    "CheckInteractDistance",

    -- WoW Game State
    "GetTime",
    "GetRealmName",
    "GetScreenWidth",
    "GetScreenHeight",
    "GetCursorPosition",
    "GetSpellInfo",
    "GetSpellSubtext",
    "GetSpellTexture",
    "GetSpellCooldown",
    "GetSpellBonusDamage",
    "IsSpellKnown",
    "IsPlayerSpell",
    "GetShapeshiftForm",
    "GetTotemInfo",
    "GetNumPartyMembers",
    "GetNumGroupMembers",
    "IsInRaid",
    "InCombatLockdown",
    "GetNetStats",
    "GetInventoryItemLink",
    "GetWeaponEnchantInfo",
    "GetRangedCritChance",
    "GetCritChance",
    "IsCurrentSpell",
    "IsAutoRepeatSpell",
    "CombatLogGetCurrentEventInfo",
    "BOOKTYPE_SPELL",

    -- WoW Constants
    "RAID_CLASS_COLORS",
    "LE_PARTY_CATEGORY_HOME",
    "Enum",
    "COMBATLOG_OBJECT_TYPE_PLAYER",
    "COMBATLOG_OBJECT_AFFILIATION_MINE",

    -- WoW Timer API
    "C_Timer",

    -- Lua globals
    "strsplit",
    "strjoin",
    "tinsert",
    "tremove",
    "wipe",
    "format",
    "date",
    "bit",
    "sqrt",
    "floor",
    "ceil",
    "abs",
    "min",
    "max",
    "random",
    "loadstring",
    "setfenv",

    -- WoW string functions
    "strtrim",
    "strmatch",
    "gsub",
    "strlen",

    -- UI Dropdown Menu
    "UIDropDownMenu_SetWidth",
    "UIDropDownMenu_SetText",
    "UIDropDownMenu_Initialize",
    "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_AddButton",

    -- Color Picker
    "OpacitySliderFrame",

    -- Sound
    "PlaySound",
    "SOUNDKIT",

    -- Misc UI
    "CloseDropDownMenus",
    "GameFontHighlightSmall",
    "LibStub",
    "UnitMana",
    "C_NamePlate",

    -- Blizzard frames
    "CastingBarFrame",
    "Masque",
}

-- Ignore certain warnings
ignore = {
    "211",  -- Unused local variable
    "212",  -- Unused argument (common in WoW callbacks)
    "213",  -- Unused loop variable
    "311",  -- Value assigned to variable is unused
    "412",  -- Redefining local variable
    "421",  -- Shadowing local variable
    "431",  -- Shadowing upvalue (common with 'self' in nested callbacks)
    "432",  -- Shadowing upvalue argument
    "542",  -- Empty if branch
    "611",  -- Line contains only whitespace
}

-- Exclude CI/tooling directories
exclude_files = {
    ".lua",
    ".luarocks",
    "lua_modules",
}

-- Exclude test files from some checks
files["tests/**/*.lua"] = {
    std = "+busted",
}

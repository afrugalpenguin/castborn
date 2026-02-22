-- Systems/Profiles.lua
local Profiles = {}
Castborn.Profiles = Profiles

local DEFAULT_PROFILE_NAME = "Default"

function Profiles:GetCurrentProfileName()
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    return CastbornDB.profileKeys and CastbornDB.profileKeys[charKey] or DEFAULT_PROFILE_NAME
end

function Profiles:SetCurrentProfile(profileName)
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    CastbornDB.profileKeys = CastbornDB.profileKeys or {}
    CastbornDB.profileKeys[charKey] = profileName

    -- Apply the profile
    self:ApplyProfile(profileName)
end

function Profiles:GetProfile(profileName)
    CastbornDB.profiles = CastbornDB.profiles or {}
    return CastbornDB.profiles[profileName]
end

function Profiles:GetCurrentProfile()
    return self:GetProfile(self:GetCurrentProfileName())
end

function Profiles:SaveCurrentToProfile(profileName)
    CastbornDB.profiles = CastbornDB.profiles or {}

    -- Copy current settings (excluding profile metadata)
    local profile = {}
    for k, v in pairs(CastbornDB) do
        if k ~= "profiles" and k ~= "profileKeys" then
            profile[k] = Castborn:DeepCopy(v)
        end
    end

    CastbornDB.profiles[profileName] = profile
end

function Profiles:ApplyProfile(profileName)
    local profile = self:GetProfile(profileName)
    if not profile then return end

    -- Preserve metadata
    local profiles = CastbornDB.profiles
    local profileKeys = CastbornDB.profileKeys

    -- Wipe and restore metadata
    wipe(CastbornDB)
    CastbornDB.profiles = profiles
    CastbornDB.profileKeys = profileKeys

    -- Apply profile settings
    for k, v in pairs(profile) do
        if k ~= "profiles" and k ~= "profileKeys" then
            CastbornDB[k] = Castborn:DeepCopy(v)
        end
    end

    -- Notify modules to refresh
    Castborn:FireCallback("PROFILE_CHANGED", profileName)
    Castborn:FireCallback("SETTINGS_CHANGED")
end

function Profiles:CreateProfile(profileName, copyFrom)
    CastbornDB.profiles = CastbornDB.profiles or {}

    if copyFrom and CastbornDB.profiles[copyFrom] then
        CastbornDB.profiles[profileName] = Castborn:DeepCopy(CastbornDB.profiles[copyFrom])
    else
        -- Create from current settings
        self:SaveCurrentToProfile(profileName)
    end
end

function Profiles:DeleteProfile(profileName)
    if profileName == DEFAULT_PROFILE_NAME then return end

    CastbornDB.profiles = CastbornDB.profiles or {}
    CastbornDB.profiles[profileName] = nil

    -- Switch anyone using this profile to default
    if CastbornDB.profileKeys then
        for charKey, profile in pairs(CastbornDB.profileKeys) do
            if profile == profileName then
                CastbornDB.profileKeys[charKey] = DEFAULT_PROFILE_NAME
            end
        end
    end
end

function Profiles:GetProfileList()
    local list = { DEFAULT_PROFILE_NAME }

    if CastbornDB.profiles then
        for name in pairs(CastbornDB.profiles) do
            if name ~= DEFAULT_PROFILE_NAME then
                table.insert(list, name)
            end
        end
    end

    table.sort(list, function(a, b)
        if a == DEFAULT_PROFILE_NAME then return true end
        if b == DEFAULT_PROFILE_NAME then return false end
        return a < b
    end)

    return list
end

function Profiles:CopyProfile(fromProfile, toProfile)
    if not CastbornDB.profiles or not CastbornDB.profiles[fromProfile] then return end

    CastbornDB.profiles[toProfile] = Castborn:DeepCopy(CastbornDB.profiles[fromProfile])
end

--------------------------------------------------------------------------------
-- Serialization for Export/Import
--------------------------------------------------------------------------------

-- Base64 encoding table
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Encode(data)
    local result = {}
    local pad = 0
    local len = #data

    for i = 1, len, 3 do
        local b1 = string.byte(data, i) or 0
        local b2 = string.byte(data, i + 1) or 0
        local b3 = string.byte(data, i + 2) or 0

        local n = b1 * 65536 + b2 * 256 + b3

        table.insert(result, string.sub(b64chars, math.floor(n / 262144) + 1, math.floor(n / 262144) + 1))
        table.insert(result, string.sub(b64chars, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1))
        table.insert(result, string.sub(b64chars, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1))
        table.insert(result, string.sub(b64chars, n % 64 + 1, n % 64 + 1))
    end

    -- Handle padding
    local remainder = len % 3
    if remainder == 1 then
        result[#result] = "="
        result[#result - 1] = "="
    elseif remainder == 2 then
        result[#result] = "="
    end

    return table.concat(result)
end

local function Base64Decode(data)
    -- Build reverse lookup table
    local b64lookup = {}
    for i = 1, 64 do
        b64lookup[string.sub(b64chars, i, i)] = i - 1
    end
    b64lookup["="] = 0

    local result = {}
    local len = #data

    for i = 1, len, 4 do
        local c1 = b64lookup[string.sub(data, i, i)] or 0
        local c2 = b64lookup[string.sub(data, i + 1, i + 1)] or 0
        local c3 = b64lookup[string.sub(data, i + 2, i + 2)] or 0
        local c4 = b64lookup[string.sub(data, i + 3, i + 3)] or 0

        local n = c1 * 262144 + c2 * 4096 + c3 * 64 + c4

        table.insert(result, string.char(math.floor(n / 65536) % 256))
        if string.sub(data, i + 2, i + 2) ~= "=" then
            table.insert(result, string.char(math.floor(n / 256) % 256))
        end
        if string.sub(data, i + 3, i + 3) ~= "=" then
            table.insert(result, string.char(n % 256))
        end
    end

    return table.concat(result)
end

-- Serialize a Lua table to string format
local function SerializeTable(tbl, indent)
    indent = indent or 0
    local parts = {}
    local prefix = string.rep(" ", indent)

    table.insert(parts, "{")

    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return tostring(a) < tostring(b)
        end
        return type(a) < type(b)
    end)

    for _, k in ipairs(keys) do
        local v = tbl[k]
        local keyStr
        if type(k) == "number" then
            keyStr = "[" .. k .. "]"
        else
            keyStr = "[" .. string.format("%q", k) .. "]"
        end

        local valueStr
        if type(v) == "table" then
            valueStr = SerializeTable(v, indent + 1)
        elseif type(v) == "string" then
            valueStr = string.format("%q", v)
        elseif type(v) == "boolean" then
            valueStr = v and "true" or "false"
        elseif type(v) == "number" then
            valueStr = tostring(v)
        else
            -- Skip functions, userdata, etc.
            valueStr = nil
        end

        if valueStr then
            table.insert(parts, keyStr .. "=" .. valueStr .. ",")
        end
    end

    table.insert(parts, "}")
    return table.concat(parts)
end

-- Deserialize a string back to a Lua table (safe evaluation)
local function DeserializeTable(str)
    -- Use loadstring with restricted environment for safety
    local func, err = loadstring("return " .. str)
    if not func then
        return nil, "Parse error: " .. (err or "unknown")
    end

    -- Run in empty environment for safety
    setfenv(func, {})
    local ok, result = pcall(func)
    if not ok then
        return nil, "Execution error: " .. (result or "unknown")
    end

    if type(result) ~= "table" then
        return nil, "Invalid data: expected table"
    end

    return result
end

-- Validate profile structure (basic sanity check)
local function ValidateProfile(profile)
    if type(profile) ~= "table" then
        return false, "Profile must be a table"
    end
    -- Ensure no profile metadata sneaks in
    if profile.profiles or profile.profileKeys then
        return false, "Invalid profile data"
    end
    return true
end

function Profiles:ExportProfile(profileName)
    local profile = self:GetProfile(profileName)
    if not profile then
        return nil, "Profile not found"
    end

    local serialized = SerializeTable(profile)
    local encoded = Base64Encode(serialized)

    -- Add version prefix for future compatibility
    return "CB1:" .. encoded
end

function Profiles:ImportProfile(profileName, dataString)
    if not dataString or dataString == "" then
        return false, "No data provided"
    end

    -- Check version prefix
    if not string.match(dataString, "^CB1:") then
        return false, "Invalid format or unsupported version"
    end

    -- Strip prefix
    local encoded = string.sub(dataString, 5)

    -- Decode
    local decoded = Base64Decode(encoded)
    if not decoded or decoded == "" then
        return false, "Failed to decode data"
    end

    -- Deserialize
    local profile, err = DeserializeTable(decoded)
    if not profile then
        return false, err
    end

    -- Validate
    local valid, validateErr = ValidateProfile(profile)
    if not valid then
        return false, validateErr
    end

    -- Save the profile
    CastbornDB.profiles = CastbornDB.profiles or {}
    CastbornDB.profiles[profileName] = profile

    return true
end

--------------------------------------------------------------------------------
-- Initialize on load
--------------------------------------------------------------------------------

Castborn:RegisterCallback("INIT", function()
    CastbornDB.profiles = CastbornDB.profiles or {}
    CastbornDB.profileKeys = CastbornDB.profileKeys or {}

    -- Ensure default profile exists
    if not CastbornDB.profiles[DEFAULT_PROFILE_NAME] then
        Profiles:SaveCurrentToProfile(DEFAULT_PROFILE_NAME)
    end
end)

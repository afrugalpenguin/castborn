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

    -- Apply profile settings to current DB
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

-- Initialize on load
Castborn:RegisterCallback("INIT", function()
    CastbornDB.profiles = CastbornDB.profiles or {}
    CastbornDB.profileKeys = CastbornDB.profileKeys or {}

    -- Ensure default profile exists
    if not CastbornDB.profiles[DEFAULT_PROFILE_NAME] then
        Profiles:SaveCurrentToProfile(DEFAULT_PROFILE_NAME)
    end
end)

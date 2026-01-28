-- Minimal WoW API mocks for testing
_G.Castborn = {}
_G.CastbornDB = {}

-- Mock GetTime
_G.GetTime = function() return os.time() end

-- Mock GetScreenWidth/Height
_G.GetScreenWidth = function() return 1920 end
_G.GetScreenHeight = function() return 1080 end

-- Mock math functions (already in Lua but WoW exposes them globally)
_G.sqrt = math.sqrt
_G.floor = math.floor
_G.ceil = math.ceil
_G.abs = math.abs
_G.min = math.min
_G.max = math.max

-- Mock UnitClass (for ClassDefaults tests)
_G.UnitClass = function(unit)
    return "Mage", "MAGE"
end

-- Mock UnitName
_G.UnitName = function(unit)
    return "TestPlayer"
end

-- Mock GetRealmName
_G.GetRealmName = function()
    return "TestRealm"
end

-- Mock UIParent (minimal frame mock)
_G.UIParent = {
    GetWidth = function() return 1920 end,
    GetHeight = function() return 1080 end,
}

-- Return module for requiring
return {}

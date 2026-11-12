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

-- Mock unit identity lookups (specs override these with their own world state)
_G.UnitGUID = function(unit)
    return nil
end

_G.UnitExists = function(unit)
    return false
end

-- WoW's table wipe
_G.wipe = function(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

-- Mock chat frame
_G.DEFAULT_CHAT_FRAME = {
    AddMessage = function() end,
}

-- Mock UIParent (minimal frame mock)
_G.UIParent = {
    GetWidth = function() return 1920 end,
    GetHeight = function() return 1080 end,
}

-- Mock CreateFrame — returns a frame-like table; unknown methods fall back to no-ops
local function newMockFrame()
    local frame = {
        events = {},
        scripts = {},
    }
    frame.RegisterEvent = function(self, event) self.events[event] = true end
    frame.RegisterUnitEvent = function(self, event, ...) self.events[event] = { ... } end
    frame.UnregisterEvent = function(self, event) self.events[event] = nil end
    frame.SetScript = function(self, handler, fn) self.scripts[handler] = fn end
    frame.GetScript = function(self, handler) return self.scripts[handler] end
    frame.GetWidth = function() return 100 end
    frame.GetHeight = function() return 20 end
    frame.CreateTexture = function() return newMockFrame() end
    frame.CreateFontString = function() return newMockFrame() end
    -- Placement is recorded so layout specs can read it back
    frame.points = {}
    frame.SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end
    frame.ClearAllPoints = function(self) self.points = {} end
    frame.SetSize = function(self, w, h) self.size = { w, h } end
    setmetatable(frame, { __index = function() return function() end end })
    return frame
end

_G.CreateFrame = function(frameType, name, parent, template)
    local frame = newMockFrame()
    if name then _G[name] = frame end
    return frame
end

-- Return module for requiring
return {}

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

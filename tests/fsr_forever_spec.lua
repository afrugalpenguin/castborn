require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/FiveSecondRule.lua")
dofile("Modules/FiveSecondRule_Forever.lua")

describe("Five second rule on Forever", function()
    local FSR = Castborn.FiveSecondRule
    local realMark = FSR.MarkManaSpent
    local secrets = setmetatable({}, { __mode = "k" })
    local function secret() local s = {} secrets[s] = true return s end
    local costs, registered, marked, powerReads

    local MANA, RAGE = 0, 1

    local function cost(fields)
        local c = { type = MANA, cost = 0, costPercent = 0, costPerSec = 0, requiredAuraID = 0, hasRequiredAura = false }
        for k, v in pairs(fields) do c[k] = v end
        return c
    end

    local function cast(spellId)
        FSR:OnPlayerEvent("UNIT_SPELLCAST_SUCCEEDED", "Cast-GUID", spellId)
    end

    before_each(function()
        costs, registered, marked, powerReads = {}, {}, 0, 0
        _G.issecretvalue = function(v) return secrets[v] == true end
        _G.C_Spell = { GetSpellPowerCost = function(id) return costs[id] end }
        _G.Enum = { PowerType = { Mana = MANA, Rage = RAGE } }
        _G.UnitPower = function() powerReads = powerReads + 1 return secret() end
        FSR.MarkManaSpent = function() marked = marked + 1 end
    end)

    after_each(function()
        _G.issecretvalue = nil
        _G.C_Spell = nil
        _G.Enum = nil
        _G.UnitPower = nil
        FSR.MarkManaSpent = realMark
    end)

    it("listens only for the player's casts and never reads mana", function()
        FSR:RegisterEvents({ RegisterEvent = function(_, event) registered[#registered + 1] = event end })
        assert.are.same({ "UNIT_SPELLCAST_SUCCEEDED" }, registered)
        assert.are.equal(0, powerReads)
    end)

    it("ignores mana updates, because mana is secret", function()
        FSR:OnPlayerEvent("UNIT_POWER_UPDATE", "MANA")
        assert.are.equal(0, marked)
        assert.are.equal(0, powerReads)
    end)

    it("starts the timer when a cast costs flat mana", function()
        costs[133] = { cost({ cost = 30 }) }
        cast(133)
        assert.are.equal(1, marked)
    end)

    it("starts the timer when a cast costs a percentage of mana", function()
        costs[133] = { cost({ costPercent = 12 }) }
        cast(133)
        assert.are.equal(1, marked)
    end)

    it("starts the timer when a channel costs mana per second", function()
        costs[5143] = { cost({ costPerSec = 3 }) }
        cast(5143)
        assert.are.equal(1, marked)
    end)

    it("ignores casts with no cost", function()
        cast(5019)  -- Shoot
        assert.are.equal(0, marked)
    end)

    it("ignores casts that cost another power type", function()
        costs[78] = { cost({ type = RAGE, cost = 15 }) }
        cast(78)
        assert.are.equal(0, marked)
    end)

    it("ignores a mana cost that needs an aura the player lacks", function()
        costs[774] = { cost({ cost = 25, requiredAuraID = 768, hasRequiredAura = false }) }
        cast(774)
        assert.are.equal(0, marked)
    end)

    it("counts a mana cost whose required aura is up", function()
        costs[774] = { cost({ cost = 25, requiredAuraID = 768, hasRequiredAura = true }) }
        cast(774)
        assert.are.equal(1, marked)
    end)

    it("finds mana among several costs", function()
        costs[100] = { cost({ type = RAGE, cost = 10 }), cost({ cost = 20 }) }
        cast(100)
        assert.are.equal(1, marked)
    end)

    it("ignores a secret spell ID without comparing it", function()
        cast(secret())
        assert.are.equal(0, marked)
    end)

    it("ignores secret cost fields without comparing them", function()
        costs[133] = { cost({ type = secret(), cost = secret() }) }
        cast(133)
        assert.are.equal(0, marked)
    end)

    it("copes with the cost API missing", function()
        _G.C_Spell = {}
        costs[133] = { cost({ cost = 30 }) }
        cast(133)
        assert.are.equal(0, marked)
    end)
end)

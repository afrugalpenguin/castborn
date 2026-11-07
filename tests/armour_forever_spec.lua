require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/ArmorTracker.lua")
dofile("Modules/ArmorTracker_Forever.lua")

describe("Armour reminder on Forever", function()
    local AT = Castborn.ArmorTracker
    local secrets = setmetatable({}, { __mode = "k" })
    local function secret() local s = {} secrets[s] = true return s end
    local auras, reads

    before_each(function()
        _G.issecretvalue = function(v) return secrets[v] == true end
        auras, reads = {}, 0
        _G.C_UnitAuras = {
            GetAuraDataByIndex = function(_, i, filter)
                reads = reads + 1
                assert.are.equal("HELPFUL", filter)
                return auras[i]
            end,
        }
        _G.InCombatLockdown = function() return false end
        _G.UnitAffectingCombat = function() return false end
    end)

    after_each(function()
        _G.issecretvalue = nil
        _G.C_UnitAuras = nil
        _G.InCombatLockdown = nil
        _G.UnitAffectingCombat = nil
    end)

    describe("CanReadAuras", function()
        it("reads auras out of combat", function()
            assert.is_true(AT:CanReadAuras())
        end)

        it("does not read auras under combat lockdown", function()
            _G.InCombatLockdown = function() return true end
            assert.is_false(AT:CanReadAuras())
        end)

        it("does not read auras once the player is in combat", function()
            _G.UnitAffectingCombat = function() return true end
            assert.is_false(AT:CanReadAuras())
        end)
    end)

    describe("FindPlayerBuff", function()
        it("finds a tracked buff through C_UnitAuras", function()
            auras = { { spellId = 1126 }, { spellId = 7302 } }
            assert.are.equal(7302, AT:FindPlayerBuff({ [7302] = true }))
        end)

        it("returns nil when no tracked buff is up", function()
            auras = { { spellId = 1126 } }
            assert.is_nil(AT:FindPlayerBuff({ [7302] = true }))
        end)

        it("skips auras whose spell ID is secret", function()
            auras = { { spellId = secret() }, { spellId = 7302 } }
            local found
            assert.has_no.errors(function() found = AT:FindPlayerBuff({ [7302] = true }) end)
            assert.are.equal(7302, found)
        end)

        it("does not read auras in combat", function()
            _G.InCombatLockdown = function() return true end
            auras = { { spellId = 7302 } }
            assert.is_nil(AT:FindPlayerBuff({ [7302] = true }))
            assert.are.equal(0, reads)
        end)
    end)
end)

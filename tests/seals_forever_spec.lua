require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Data/SpellData.lua")
dofile("Modules/SealTracker.lua")
dofile("Modules/SealTracker_Forever.lua")

local spellNames = {
    [20154] = "Seal of Righteousness",
    [20293] = "Seal of Righteousness",
    [20375] = "Seal of Command",
    [20424] = "Seal of Command",  -- the proc hit
    [21082] = "Seal of the Crusader",
    [20271] = "Judgement",
}

describe("Seal tracker on Forever", function()
    local ST = Castborn.SealTracker
    local secrets = setmetatable({}, { __mode = "k" })
    local function secret() local s = {} secrets[s] = true return s end
    local auras, reads, inCombat, now, originalGetTime

    before_each(function()
        _G.issecretvalue = function(v) return secrets[v] == true end
        _G.GetSpellInfo = function(id) return spellNames[id] end
        ST:BuildNames()
        ST:SetState(nil)
        ST.knownDurations = {}
        auras, reads, inCombat, now = {}, 0, false, 100
        _G.C_UnitAuras = {
            GetAuraDataByIndex = function(_, i)
                reads = reads + 1
                return auras[i]
            end,
        }
        _G.InCombatLockdown = function() return inCombat end
        _G.UnitAffectingCombat = function() return inCombat end
        originalGetTime = _G.GetTime
        _G.GetTime = function() return now end
    end)

    after_each(function()
        _G.issecretvalue = nil
        _G.GetSpellInfo = nil
        _G.C_UnitAuras = nil
        _G.InCombatLockdown = nil
        _G.UnitAffectingCombat = nil
        _G.GetTime = originalGetTime
    end)

    describe("out of combat", function()
        it("reads the seal buff through C_UnitAuras", function()
            auras = { { name = "Seal of Righteousness", spellId = 20293, duration = 30, expirationTime = 128 } }
            ST:UpdateState()
            assert.are.same({ spellId = 20293, expirationTime = 128, duration = 30 }, ST.state)
        end)

        it("remembers the seal's real duration", function()
            auras = { { name = "Seal of Righteousness", spellId = 20293, duration = 27, expirationTime = 120 } }
            ST:UpdateState()
            assert.are.equal(27, ST.knownDurations["Seal of Righteousness"])
        end)

        it("ignores casts, because the buff read is exact", function()
            ST:OnPlayerCast(20375)
            assert.is_nil(ST.state.spellId)
        end)
    end)

    describe("in combat", function()
        before_each(function() inCombat = true end)

        it("never reads auras", function()
            ST:UpdateState()
            assert.are.equal(0, reads)
        end)

        it("keeps the seal it had when combat started", function()
            ST:SetState(20293, 128, 30)
            ST:UpdateState()
            assert.are.equal(20293, ST.state.spellId)
        end)

        it("starts a timer when a seal is cast", function()
            ST:OnPlayerCast(21082)
            assert.are.same({ spellId = 21082, expirationTime = 130, duration = 30 }, ST.state)
        end)

        it("uses the duration seen out of combat", function()
            ST.knownDurations["Seal of the Crusader"] = 27
            ST:OnPlayerCast(21082)
            assert.are.equal(127, ST.state.expirationTime)
        end)

        it("replaces the seal when another is cast", function()
            ST:OnPlayerCast(21082)
            ST:OnPlayerCast(20375)
            assert.are.equal(20375, ST.state.spellId)
        end)

        it("clears the seal on Judgement", function()
            ST:OnPlayerCast(21082)
            ST:OnPlayerCast(20271)
            assert.is_nil(ST.state.spellId)
        end)

        it("does not restart the timer on a Seal of Command proc", function()
            ST:OnPlayerCast(20375)
            now = 110
            ST:OnPlayerCast(20424)
            assert.are.equal(130, ST.state.expirationTime)
        end)

        it("holds its state for a secret spell ID", function()
            ST:OnPlayerCast(21082)
            assert.has_no.errors(function() ST:OnPlayerCast(secret()) end)
            assert.are.equal(21082, ST.state.spellId)
        end)

        it("drops the seal once its time runs out", function()
            ST:OnPlayerCast(21082)
            now = 131
            ST:UpdateState()
            assert.is_nil(ST.state.spellId)
        end)
    end)

    it("re-reads the real buff after combat", function()
        inCombat = true
        ST:OnPlayerCast(21082)
        inCombat = false
        auras = { { name = "Seal of Righteousness", spellId = 20293, duration = 30, expirationTime = 125 } }
        ST:UpdateState()
        assert.are.equal(20293, ST.state.spellId)
    end)

    it("tracks Seal of Fury, which is new on Forever", function()
        local found = false
        for _, seal in ipairs(Castborn.SpellData.seals) do
            for _, id in ipairs(seal.spellIds) do
                if id == 1311649 then found = true end
            end
        end
        assert.is_true(found)
        spellNames[1311649] = "Seal of Fury"
        ST:BuildNames()
        inCombat = true
        ST:OnPlayerCast(1311649)
        spellNames[1311649] = nil
        assert.are.equal(1311649, ST.state.spellId)
    end)

    it("skips auras whose name is secret", function()
        auras = { { name = secret() }, { name = "Seal of Command", spellId = 20375, duration = 30, expirationTime = 120 } }
        assert.has_no.errors(function() ST:UpdateState() end)
        assert.are.equal(20375, ST.state.spellId)
    end)
end)

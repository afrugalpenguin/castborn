require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Data/SpellData.lua")
dofile("Modules/SealTracker.lua")

local spellNames = {
    [20154] = "Seal of Righteousness",  -- 21084 deliberately unknown, to test the fallback ID
    [20375] = "Seal of Command",
    [20424] = "Seal of Command",        -- the proc hit, ignored
    [21082] = "Seal of the Crusader",
    [20271] = "Judgement",
}

describe("Seal tracker (TBC behaviour)", function()
    local ST = Castborn.SealTracker
    local buffs, now, originalGetTime

    before_each(function()
        _G.GetSpellInfo = function(id) return spellNames[id] end
        ST:BuildNames()
        buffs = {}
        now = 100
        originalGetTime = _G.GetTime
        _G.GetTime = function() return now end
        -- name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId
        _G.UnitBuff = function(_, i)
            local b = buffs[i]
            if b then return b.name, 1, 0, nil, b.duration, b.expirationTime, "player", false, false, b.spellId end
        end
        ST:SetState(nil)
    end)

    after_each(function()
        _G.GetSpellInfo = nil
        _G.UnitBuff = nil
        _G.GetTime = originalGetTime
    end)

    it("resolves seal names from the first ID the client knows", function()
        assert.is_true(ST:IsSeal("Seal of Righteousness"))
        assert.is_true(ST:IsSeal("Seal of Command"))
        assert.is_false(ST:IsSeal("Blessing of Might"))
        assert.is_true(ST:IsJudgement("Judgement"))
    end)

    it("can always read auras", function()
        assert.is_true(ST:CanReadAuras())
    end)

    it("finds the active seal buff with its timing", function()
        buffs = {
            { name = "Blessing of Might", spellId = 19740, duration = 300, expirationTime = 400 },
            { name = "Seal of Righteousness", spellId = 20293, duration = 30, expirationTime = 120 },
        }
        local spellId, expirationTime, duration = ST:FindActiveSeal()
        assert.are.equal(20293, spellId)
        assert.are.equal(120, expirationTime)
        assert.are.equal(30, duration)
    end)

    it("finds nothing when no seal is up", function()
        buffs = { { name = "Blessing of Might", spellId = 19740, duration = 300, expirationTime = 400 } }
        assert.is_nil(ST:FindActiveSeal())
    end)

    it("takes its state from the seal buff", function()
        buffs = { { name = "Seal of Command", spellId = 27170, duration = 30, expirationTime = 125 } }
        ST:UpdateState()
        assert.are.same({ spellId = 27170, expirationTime = 125, duration = 30 }, ST.state)
    end)

    it("clears its state when the seal buff is gone", function()
        ST:SetState(27170, 125, 30)
        ST:UpdateState()
        assert.is_nil(ST.state.spellId)
    end)

    it("ignores casts, because the buff is always readable", function()
        ST:OnPlayerCast(20375)
        assert.is_nil(ST.state.spellId)
    end)
end)

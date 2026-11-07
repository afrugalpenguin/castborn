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

    describe("ResizeIcon", function()
        local function recorder()
            local r = { calls = {} }
            setmetatable(r, { __index = function(_, k)
                return function(_, ...) r.calls[k] = { ... } end
            end })
            return r
        end

        after_each(function() Castborn.Masque = nil end)

        it("resizes the button and the warning text", function()
            local f = recorder()
            f.warning = recorder()
            ST:ResizeIcon(f, 60)
            assert.are.same({ 60, 60 }, f.calls.SetSize)
            assert.are.equal(24, f.warning.calls.SetFont[2])
        end)

        it("re-skins the seal icon with Masque so the new size shows", function()
            local skinned
            Castborn.Masque = { enabled = true, ReSkin = function(_, group) skinned = group end }
            local f = recorder()
            f.warning = recorder()
            ST:ResizeIcon(f, 60)
            assert.are.equal("seals", skinned)
        end)

        it("does not touch Masque when it is not in use", function()
            local skinned
            Castborn.Masque = { enabled = false, ReSkin = function(_, group) skinned = group end }
            local f = recorder()
            f.warning = recorder()
            ST:ResizeIcon(f, 60)
            assert.is_nil(skinned)
        end)
    end)

    describe("no-seal warning", function()
        local dead, inCombat

        before_each(function()
            dead, inCombat = false, false
            _G.UnitIsDeadOrGhost = function() return dead end
            _G.UnitAffectingCombat = function() return inCombat end
        end)

        after_each(function()
            _G.UnitIsDeadOrGhost = nil
            _G.UnitAffectingCombat = nil
        end)

        it("warns out of combat by default, for pre-pull", function()
            assert.are.equal("warning", ST:GetDisplayMode({ warnNoSeal = true }))
        end)

        it("does not warn out of combat when set to combat only", function()
            assert.are.equal("hidden", ST:GetDisplayMode({ warnNoSeal = true, warnInCombatOnly = true }))
        end)

        it("warns in combat when set to combat only", function()
            inCombat = true
            assert.are.equal("warning", ST:GetDisplayMode({ warnNoSeal = true, warnInCombatOnly = true }))
        end)

        it("shows the seal while one is up", function()
            ST:SetState(27170, 125, 30)
            assert.are.equal("active", ST:GetDisplayMode({ warnNoSeal = true }))
        end)

        it("warns when no seal is up", function()
            assert.are.equal("warning", ST:GetDisplayMode({ warnNoSeal = true }))
        end)

        it("warns by default when the setting has never been saved", function()
            assert.are.equal("warning", ST:GetDisplayMode({}))
        end)

        it("hides instead when the warning is turned off", function()
            assert.are.equal("hidden", ST:GetDisplayMode({ warnNoSeal = false }))
        end)

        it("does not warn while dead or a ghost", function()
            dead = true
            assert.are.equal("hidden", ST:GetDisplayMode({ warnNoSeal = true }))
        end)

        it("remembers the last seal for the warning icon", function()
            ST:SetState(27170, 125, 30)
            ST:SetState(nil)
            assert.are.equal(27170, ST:GetWarningSpellId())
        end)

        it("falls back to the first seal the client knows", function()
            ST.lastSpellId = nil
            assert.are.equal(20154, ST:GetWarningSpellId())
        end)
    end)
end)

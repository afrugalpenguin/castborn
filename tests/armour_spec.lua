require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/ArmorTracker.lua")

describe("Armour reminder seams (TBC behaviour)", function()
    local AT = Castborn.ArmorTracker

    after_each(function() _G.UnitBuff = nil end)

    it("can always read auras", function()
        assert.is_true(AT:CanReadAuras())
    end)

    it("finds a tracked buff by spell ID", function()
        local buffs = { { "Mark of the Wild", 1126 }, { "Ice Armor", 7302 } }
        _G.UnitBuff = function(_, i)
            local b = buffs[i]
            if b then return b[1], nil, nil, nil, nil, nil, nil, nil, nil, b[2] end
        end
        assert.are.equal(7302, AT:FindPlayerBuff({ [7302] = true }))
    end)

    it("returns nil when no tracked buff is up", function()
        _G.UnitBuff = function() return nil end
        assert.is_nil(AT:FindPlayerBuff({ [7302] = true }))
    end)

    it("ignores casts, because the buff read is exact", function()
        local hidden = false
        local slot = { spellIds = { [7302] = true }, frame = { Hide = function() hidden = true end } }
        table.insert(AT:GetSlots(), slot)
        AT:OnPlayerCast(7302)
        wipe(AT:GetSlots())
        assert.is_false(hidden)
        assert.is_nil(slot.lastSpellId)
    end)

    describe("icon size", function()
        local function recorder()
            local r = { calls = {} }
            setmetatable(r, { __index = function(_, k)
                return function(_, ...) r.calls[k] = { ... } end
            end })
            return r
        end

        after_each(function() Castborn.Masque = nil end)

        it("resizes an alert icon and its warning text", function()
            local f = recorder()
            f.warning = recorder()
            AT:ResizeSlotFrame(f, 60)
            assert.are.same({ 60, 60 }, f.calls.SetSize)
            assert.are.equal(24, f.warning.calls.SetFont[2])
        end)

        it("re-skins the armour icons with Masque so the new size shows", function()
            local skinned
            Castborn.Masque = { enabled = true, ReSkin = function(_, group) skinned = group end }
            AT:ApplyIconSize(60)
            assert.are.equal("armor", skinned)
        end)

        it("does not touch Masque when it is not in use", function()
            local skinned
            Castborn.Masque = { enabled = false, ReSkin = function(_, group) skinned = group end }
            AT:ApplyIconSize(60)
            assert.is_nil(skinned)
        end)
    end)

    describe("GetSelectedBlessing", function()
        after_each(function() Castborn.unavailableOptions = nil end)

        it("returns the saved blessing", function()
            assert.are.equal("sanctuary", AT:GetSelectedBlessing({ selectedBlessing = "sanctuary" }))
        end)

        it("defaults to Might", function()
            assert.are.equal("might", AT:GetSelectedBlessing({}))
        end)

        it("falls back to Might when the build lacks the saved blessing", function()
            Castborn.unavailableOptions = { ["armortracker.sanctuary"] = true }
            assert.are.equal("might", AT:GetSelectedBlessing({ selectedBlessing = "sanctuary" }))
        end)
    end)

    describe("HasTalent", function()
        after_each(function() _G.GetTalentInfo = nil end)

        it("is true when the talent has points", function()
            _G.GetTalentInfo = function(tab, index)
                if tab == 2 and index == 7 then return "Improved Righteous Fury", nil, 1, 2, 2, 3 end
            end
            assert.is_true(AT:HasTalent({ talentTab = 2, talentIndex = 7 }))
        end)

        it("is false with no points spent", function()
            _G.GetTalentInfo = function() return "Improved Righteous Fury", nil, 1, 2, 0, 3 end
            assert.is_false(AT:HasTalent({ talentTab = 2, talentIndex = 7 }))
        end)

        it("is false for an entry with no talent position", function()
            assert.is_false(AT:HasTalent({}))
        end)
    end)

    describe("ShouldTrackRighteousFury", function()
        local rf = { spellIds = { 25780 }, talentTab = 2, talentIndex = 7 }
        local talented, knowsRF

        before_each(function()
            talented, knowsRF = false, true
            _G.GetTalentInfo = function() return "Improved Righteous Fury", nil, 1, 2, talented and 1 or 0, 3 end
            _G.IsSpellKnown = function(id) return knowsRF and id == 25780 end
            _G.IsPlayerSpell = function() return false end
            _G.GetSpellInfo = function() return nil end
        end)

        after_each(function()
            _G.GetTalentInfo = nil
            _G.IsSpellKnown = nil
            _G.IsPlayerSpell = nil
            _G.GetSpellInfo = nil
        end)

        it("tracks it automatically when Improved Righteous Fury is talented", function()
            talented = true
            assert.is_true(AT:ShouldTrackRighteousFury(rf, {}))
        end)

        it("does not track it untalented by default", function()
            assert.is_false(AT:ShouldTrackRighteousFury(rf, {}))
        end)

        it("tracks it untalented when the option is on", function()
            assert.is_true(AT:ShouldTrackRighteousFury(rf, { alwaysTrackRF = true }))
        end)

        it("does not track it before Righteous Fury is learned, even with the option on", function()
            knowsRF = false
            assert.is_false(AT:ShouldTrackRighteousFury(rf, { alwaysTrackRF = true }))
        end)
    end)
end)

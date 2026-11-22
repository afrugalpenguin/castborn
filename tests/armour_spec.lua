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

    describe("food reminder", function()
        local instanceType

        before_each(function()
            instanceType = "none"
            _G.IsInInstance = function() return instanceType ~= "none", instanceType end
            AT.wellFed = nil
        end)

        after_each(function()
            _G.IsInInstance = nil
            _G.UnitBuff = nil
            AT.wellFed = nil
        end)

        describe("FoodReminderWanted", function()
            it("always applies in 'always' mode", function()
                assert.is_true(AT:FoodReminderWanted("always"))
            end)

            it("applies in dungeons and raids, but not outside, in 'instance' mode", function()
                assert.is_false(AT:FoodReminderWanted("instance"))
                instanceType = "party"
                assert.is_true(AT:FoodReminderWanted("instance"))
                instanceType = "raid"
                assert.is_true(AT:FoodReminderWanted("instance"))
            end)

            it("does not apply in battlegrounds or arenas in 'instance' mode", function()
                instanceType = "pvp"
                assert.is_false(AT:FoodReminderWanted("instance"))
                instanceType = "arena"
                assert.is_false(AT:FoodReminderWanted("instance"))
            end)

            it("applies only in raids in 'raid' mode", function()
                instanceType = "party"
                assert.is_false(AT:FoodReminderWanted("raid"))
                instanceType = "raid"
                assert.is_true(AT:FoodReminderWanted("raid"))
            end)

            it("treats an unknown mode as dungeons and raids", function()
                instanceType = "party"
                assert.is_true(AT:FoodReminderWanted(nil))
            end)
        end)

        describe("FindPlayerBuffByName", function()
            it("finds a buff by name", function()
                local buffs = { "Arcane Intellect", "Well Fed" }
                _G.UnitBuff = function(_, i) return buffs[i] end
                assert.is_true(AT:FindPlayerBuffByName("Well Fed"))
            end)

            it("is false when the buff is not up", function()
                _G.UnitBuff = function(_, i) if i == 1 then return "Food" end end
                assert.is_false(AT:FindPlayerBuffByName("Well Fed"))
            end)
        end)

        describe("HasWellFed", function()
            local fed
            local canReadAuras = AT.CanReadAuras

            before_each(function()
                fed = false
                _G.UnitBuff = function(_, i) if i == 1 and fed then return "Well Fed" end end
                _G.GetSpellInfo = function(id) if id == 19705 then return "Well Fed" end end
            end)

            after_each(function()
                _G.GetSpellInfo = nil
                AT.CanReadAuras = canReadAuras
            end)

            it("is true with the buff up and false without", function()
                fed = true
                assert.is_true(AT:HasWellFed())
                fed = false
                assert.is_false(AT:HasWellFed())
            end)

            it("keeps the last answer while auras cannot be read", function()
                assert.is_false(AT:HasWellFed())
                AT.CanReadAuras = function() return false end
                fed = true
                assert.is_false(AT:HasWellFed())
            end)

            it("assumes the player is fed before any read, so it never alerts on a guess", function()
                AT.CanReadAuras = function() return false end
                assert.is_true(AT:HasWellFed())
            end)
        end)

        it("names the Well Fed buff in SpellData", function()
            dofile("Data/SpellData.lua")
            assert.are.same({ 19705 }, Castborn.SpellData.wellFed.spellIds)
        end)
    end)
end)

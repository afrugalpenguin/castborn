require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Data/SpellData.lua")
dofile("Modules/CooldownGroup.lua")
dofile("Modules/CooldownTracker.lua")
dofile("Modules/CooldownTracker_Forever.lua")

describe("Cooldowns on Forever", function()
    local CT = Castborn.CooldownTracker
    local secrets = setmetatable({}, { __mode = "k" })
    local function secret() local s = {} secrets[s] = true return s end
    local info, dur

    before_each(function()
        _G.issecretvalue = function(v) return secrets[v] == true end
        dur = {}
        _G.C_Spell = {
            GetSpellCooldown = function() return info end,
            GetSpellCooldownDuration = function() return dur end,
        }
    end)

    after_each(function()
        _G.issecretvalue = nil
        _G.C_Spell = nil
        info = nil
    end)

    it("reads plain cooldowns like TBC", function()
        info = { startTime = 100, duration = 30, isActive = true, isOnGCD = false }
        local onCooldown, isLong, start, duration = CT:GetSpellCooldownState("Hammer of Justice")
        assert.is_true(onCooldown)
        assert.is_true(isLong)
        assert.are.equal(100, start)
        assert.are.equal(30, duration)
    end)

    it("treats a plain GCD-length cooldown as ready", function()
        info = { startTime = 100, duration = 1.5, isActive = true, isOnGCD = true }
        assert.is_false(CT:GetSpellCooldownState("Holy Light"))
    end)

    it("uses the flags when the times are secret", function()
        info = { startTime = secret(), duration = secret(), isActive = true, isOnGCD = false }
        local onCooldown, isLong
        assert.has_no.errors(function() onCooldown, isLong = CT:GetSpellCooldownState("Hammer of Justice") end)
        assert.is_true(onCooldown)
        assert.is_true(isLong)
    end)

    it("does not count the GCD as a cooldown when secret", function()
        info = { startTime = secret(), duration = secret(), isActive = true, isOnGCD = true }
        assert.is_false(CT:GetSpellCooldownState("Holy Light"))
    end)

    it("reports nothing for an unknown spell", function()
        assert.is_false(CT:GetSpellCooldownState("Nonexistent"))
    end)

    it("draws secret cooldowns from a duration object", function()
        local got
        local cooldown = { SetCooldownFromDurationObject = function(_, d) got = d end }
        CT:SetIconCooldown(cooldown, "Hammer of Justice", secret(), secret())
        assert.are.equal(dur, got)
    end)

    describe("GetTrackedSpellName", function()
        local originalGetSpellInfo

        before_each(function()
            originalGetSpellInfo = _G.GetSpellInfo
            -- On Forever these TBC IDs are different spells
            local names = { [12472] = "Cold Snap", [11958] = "Ice Block", [12292] = "Sweeping Strikes" }
            _G.GetSpellInfo = function(id) return names[id] end
        end)

        after_each(function() _G.GetSpellInfo = originalGetSpellInfo end)

        it("names a tracked spell after what its ID is on this client", function()
            assert.are.equal("Cold Snap", CT:GetTrackedSpellName({ spellId = 12472, name = "Icy Veins" }))
            assert.are.equal("Ice Block", CT:GetTrackedSpellName({ spellId = 11958, name = "Cold Snap" }))
            assert.are.equal("Sweeping Strikes", CT:GetTrackedSpellName({ spellId = 12292, name = "Death Wish" }))
        end)

        it("keeps the stored name when the client does not know the ID", function()
            assert.are.equal("Custom Spell", CT:GetTrackedSpellName({ spellId = 999999, name = "Custom Spell" }))
        end)
    end)

    it("draws plain cooldowns with SetCooldown", function()
        local got
        local cooldown = { SetCooldown = function(_, s, d) got = { s, d } end }
        CT:SetIconCooldown(cooldown, "Hammer of Justice", 100, 30)
        assert.are.same({ 100, 30 }, got)
    end)

    describe("GetTargetCreatureType", function()
        local exists, creatureType

        before_each(function()
            exists, creatureType = true, "Undead"
            _G.UnitExists = function() return exists end
            _G.UnitCreatureType = function() return creatureType end
        end)

        after_each(function()
            _G.UnitExists = function() return false end
            _G.UnitCreatureType = nil
        end)

        it("reads a plain creature type", function()
            assert.are.equal("Undead", CT:GetTargetCreatureType())
        end)

        it("reports no target as false", function()
            exists = false
            assert.is_false(CT:GetTargetCreatureType())
        end)

        it("gives up on a secret creature type", function()
            creatureType = secret()
            assert.has_no.errors(function() CT:GetTargetCreatureType() end)
            assert.is_nil(CT:GetTargetCreatureType())
        end)

        it("gives up when whether the target exists is secret", function()
            exists = secret()
            assert.is_nil(CT:GetTargetCreatureType())
        end)
    end)

    -- In combat the creature type is secret, but the range check stays plain: nil when the
    -- spell cannot be cast on the target at all, true or false (in or out of range) when it can
    describe("GetTargetFit with a secret creature type", function()
        local exorcism = { spellId = 879, name = "Exorcism" }
        local inRange, rangeAsked, originalGetSpellInfo

        before_each(function()
            inRange, rangeAsked = nil, nil
            _G.UnitExists = function() return true end
            _G.UnitCreatureType = function() return secret() end
            _G.C_Spell.IsSpellInRange = function(spell, unit)
                rangeAsked = { spell, unit }
                return inRange
            end
            originalGetSpellInfo = _G.GetSpellInfo
            _G.GetSpellInfo = function(id) return id == 879 and "Exorcism" or nil end
        end)

        after_each(function()
            _G.UnitExists = function() return false end
            _G.UnitCreatureType = nil
            _G.GetSpellInfo = originalGetSpellInfo
        end)

        it("fits a target the spell can be cast on, in range", function()
            inRange = true
            assert.is_true(CT:GetTargetFit(exorcism))
            assert.are.same({ "Exorcism", "target" }, rangeAsked)
        end)

        it("fits a target the spell can be cast on, out of range", function()
            inRange = false
            assert.is_true(CT:GetTargetFit(exorcism))
        end)

        it("does not fit a target the spell cannot be cast on", function()
            inRange = nil
            assert.is_false(CT:GetTargetFit(exorcism))
        end)

        it("has no opinion when the range check is secret too", function()
            inRange = secret()
            assert.is_nil(CT:GetTargetFit(exorcism))
        end)

        it("does not check range for spells without a creature type limit", function()
            assert.is_nil(CT:GetTargetFit({ spellId = 853, name = "Hammer of Justice" }))
            assert.is_nil(rangeAsked)
        end)

        it("still uses a plain creature type when it can be read", function()
            _G.UnitCreatureType = function() return "Humanoid" end
            inRange = true
            assert.is_false(CT:GetTargetFit(exorcism))
            assert.is_nil(rangeAsked)
        end)

        it("does not fit with no target, without checking range", function()
            _G.UnitExists = function() return false end
            assert.is_false(CT:GetTargetFit(exorcism))
            assert.is_nil(rangeAsked)
        end)
    end)
end)

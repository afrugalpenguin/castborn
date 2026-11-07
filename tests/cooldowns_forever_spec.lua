require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
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
end)

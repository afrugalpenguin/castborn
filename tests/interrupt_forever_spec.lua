require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/InterruptTracker.lua")
dofile("Modules/InterruptTracker_Forever.lua")

-- Records the arguments of the last call to each method
local function recorder()
    local r = { calls = {} }
    setmetatable(r, { __index = function(_, k)
        return function(_, ...) r.calls[k] = { ... } end
    end })
    return r
end

describe("Interrupt tracker on Forever", function()
    local IT = Castborn.InterruptTracker
    local secrets = setmetatable({}, { __mode = "k" })
    local function secret() local s = {} secrets[s] = true return s end
    local info, dur, originalCreateFrame

    local function fakeFrame()
        return { bar = recorder(), time = recorder(), ready = recorder(), icon = recorder(),
                 interruptInfo = { spellId = 1766 } }
    end

    before_each(function()
        _G.issecretvalue = function(v) return secrets[v] == true end
        dur = { GetRemainingDuration = function() return 4.2 end }
        _G.C_Spell = {
            GetSpellCooldown = function() return info end,
            GetSpellCooldownDuration = function() return dur end,
        }
        _G.Enum = { StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
                    StatusBarInterpolation = { Immediate = 0 } }
        originalCreateFrame = _G.CreateFrame
        _G.CreateFrame = function() return recorder() end
    end)

    after_each(function()
        _G.issecretvalue = nil
        _G.C_Spell = nil
        _G.Enum = nil
        _G.CreateFrame = originalCreateFrame
        _G.UnitCastingInfo = nil
        _G.UnitChannelInfo = nil
        _G.UnitExists = function() return false end
        info = nil
    end)

    describe("GetCooldownState", function()
        it("reads plain cooldowns like TBC", function()
            info = { startTime = 100, duration = 15, isActive = true, isOnGCD = false }
            local onCooldown, start, duration = IT:GetCooldownState(1766)
            assert.is_true(onCooldown)
            assert.are.equal(100, start)
            assert.are.equal(15, duration)
        end)

        it("treats a plain GCD-length cooldown as ready", function()
            info = { startTime = 100, duration = 1.5, isActive = true, isOnGCD = true }
            assert.is_false(IT:GetCooldownState(1766))
        end)

        it("uses the flags when the times are secret", function()
            info = { startTime = secret(), duration = secret(), isActive = true, isOnGCD = false }
            local onCooldown
            assert.has_no.errors(function() onCooldown = IT:GetCooldownState(1766) end)
            assert.is_true(onCooldown)
        end)

        it("does not count the GCD as a cooldown when secret", function()
            info = { startTime = secret(), duration = secret(), isActive = true, isOnGCD = true }
            assert.is_false(IT:GetCooldownState(1766))
        end)

        it("reports nothing for an unknown spell", function()
            assert.is_false(IT:GetCooldownState(1766))
        end)
    end)

    describe("SetIconCooldown", function()
        it("draws secret cooldowns from a duration object", function()
            local cooldown = recorder()
            IT:SetIconCooldown(cooldown, 1766, secret(), secret())
            assert.are.equal(dur, cooldown.calls.SetCooldownFromDurationObject[1])
        end)

        it("draws plain cooldowns with SetCooldown", function()
            local cooldown = recorder()
            IT:SetIconCooldown(cooldown, 1766, 100, 15)
            assert.are.same({ 100, 15 }, cooldown.calls.SetCooldown)
        end)
    end)

    describe("IsUnitCastingInterruptible", function()
        before_each(function()
            _G.UnitExists = function() return true end
            _G.UnitChannelInfo = function() return nil end
        end)

        it("counts a cast with secret interruptibility as an opportunity", function()
            _G.UnitCastingInfo = function() return "Fireball", nil, nil, 0, 0, false, 1, secret() end
            assert.is_true(IT:IsUnitCastingInterruptible("target"))
        end)

        it("counts a cast with a secret name as an opportunity", function()
            _G.UnitCastingInfo = function() return secret(), nil, nil, 0, 0, false, 1, secret() end
            assert.is_true(IT:IsUnitCastingInterruptible("target"))
        end)

        it("still rejects a plain shielded cast", function()
            _G.UnitCastingInfo = function() return "Fireball", nil, nil, 0, 0, false, 1, true end
            assert.is_false(IT:IsUnitCastingInterruptible("target"))
        end)

        it("is false when nothing is being cast", function()
            _G.UnitCastingInfo = function() return nil end
            assert.is_false(IT:IsUnitCastingInterruptible("target"))
        end)
    end)

    describe("ShowCooldownProgress", function()
        it("runs a timer bar from the duration object when times are secret", function()
            local frame = fakeFrame()
            frame.bar.SetTimerDuration = function() end
            assert.has_no.errors(function() IT:ShowCooldownProgress(frame, secret(), secret()) end)
            assert.are.same({ dur, 0, 1 }, frame.timerBar.calls.SetTimerDuration)
            assert.is_not_nil(frame.timerBar.calls.Show)
            assert.are.same({ "%.1f", 4.2 }, frame.time.calls.SetFormattedText)
            assert.are.same({ true }, frame.icon.calls.SetDesaturated)
        end)

        it("starts the timer once per cooldown", function()
            local frame = fakeFrame()
            frame.bar.SetTimerDuration = function() end
            local fetches = 0
            _G.C_Spell.GetSpellCooldownDuration = function() fetches = fetches + 1 return dur end
            IT:ShowCooldownProgress(frame, secret(), secret())
            IT:ShowCooldownProgress(frame, secret(), secret())
            assert.are.equal(1, fetches)
        end)

        it("uses the TBC drawing for plain times", function()
            local frame = fakeFrame()
            local originalGetTime = _G.GetTime
            _G.GetTime = function() return 110 end
            IT:ShowCooldownProgress(frame, 100, 15)
            _G.GetTime = originalGetTime
            assert.are.same({ 5 }, frame.bar.calls.SetValue)
            assert.are.same({ "5.0" }, frame.time.calls.SetText)
        end)
    end)

    describe("ShowReadyState", function()
        it("stops a running timer", function()
            local frame = fakeFrame()
            frame.bar.SetTimerDuration = function() end
            IT:ShowCooldownProgress(frame, secret(), secret())
            IT:ShowReadyState(frame, false)
            assert.is_nil(frame.timerDuration)
            assert.is_not_nil(frame.timerBar.calls.Hide)
            assert.are.same({ 1 }, frame.bar.calls.SetValue)
        end)
    end)

    it("never registers the combat log", function()
        local f = originalCreateFrame("Frame")
        IT:RegisterLockoutEvents(f)
        assert.is_nil(f.events.COMBAT_LOG_EVENT_UNFILTERED)
    end)
end)

describe("Interrupt spell data on Forever", function()
    it("uses the Forever Feral Charge talent for druids and leaves other classes alone", function()
        dofile("Data/SpellData.lua")
        local pummel = Castborn.SpellData.interrupts.WARRIOR.spellId
        dofile("Modules/InterruptTracker_Forever.lua")
        assert.are.equal(1238122, Castborn.SpellData.interrupts.DRUID.spellId)
        assert.are.equal(pummel, Castborn.SpellData.interrupts.WARRIOR.spellId)
    end)
end)

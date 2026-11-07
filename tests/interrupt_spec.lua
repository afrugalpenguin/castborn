require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/InterruptTracker.lua")

-- Records the arguments of the last call to each method
local function recorder()
    local r = { calls = {} }
    setmetatable(r, { __index = function(_, k)
        return function(_, ...) r.calls[k] = { ... } end
    end })
    return r
end

local function fakeFrame()
    return { bar = recorder(), time = recorder(), ready = recorder(), icon = recorder() }
end

describe("Interrupt seams (TBC behaviour)", function()
    local IT = Castborn.InterruptTracker
    local originalGetTime

    before_each(function()
        originalGetTime = _G.GetTime
        _G.GetTime = function() return 110 end
    end)

    after_each(function()
        _G.GetSpellCooldown = nil
        _G.UnitCastingInfo = nil
        _G.UnitChannelInfo = nil
        _G.UnitExists = function() return false end
        _G.GetTime = originalGetTime
    end)

    describe("GetCooldownState", function()
        it("treats a GCD-length cooldown as ready", function()
            _G.GetSpellCooldown = function() return 100, 1.5 end
            assert.is_false(IT:GetCooldownState(1766))
        end)

        it("reports a real cooldown with its times", function()
            _G.GetSpellCooldown = function() return 100, 15 end
            local onCooldown, start, duration = IT:GetCooldownState(1766)
            assert.is_true(onCooldown)
            assert.are.equal(100, start)
            assert.are.equal(15, duration)
        end)

        it("treats a missing cooldown as ready", function()
            _G.GetSpellCooldown = function() return nil end
            assert.is_false(IT:GetCooldownState(1766))
        end)
    end)

    describe("IsUnitCastingInterruptible", function()
        it("is false when the unit does not exist", function()
            assert.is_false(IT:IsUnitCastingInterruptible("target"))
        end)

        it("is true for an interruptible cast", function()
            _G.UnitExists = function() return true end
            _G.UnitCastingInfo = function() return "Fireball", nil, nil, 0, 0, false, 1, false end
            assert.is_true(IT:IsUnitCastingInterruptible("target"))
        end)

        it("is false for a shielded cast", function()
            _G.UnitExists = function() return true end
            _G.UnitCastingInfo = function() return "Fireball", nil, nil, 0, 0, false, 1, true end
            _G.UnitChannelInfo = function() return nil end
            assert.is_false(IT:IsUnitCastingInterruptible("target"))
        end)

        it("is true for an interruptible channel", function()
            _G.UnitExists = function() return true end
            _G.UnitCastingInfo = function() return nil end
            _G.UnitChannelInfo = function() return "Arcane Missiles", nil, nil, 0, 0, false, false end
            assert.is_true(IT:IsUnitCastingInterruptible("target"))
        end)
    end)

    describe("ShowCooldownProgress", function()
        it("fills the bar with the remaining time", function()
            local frame = fakeFrame()
            IT:ShowCooldownProgress(frame, 100, 15)
            assert.are.same({ 0, 15 }, frame.bar.calls.SetMinMaxValues)
            assert.are.same({ 5 }, frame.bar.calls.SetValue)
            assert.are.same({ 0.8, 0.3, 0.3, 1 }, frame.bar.calls.SetStatusBarColor)
            assert.are.same({ "5.0" }, frame.time.calls.SetText)
            assert.is_not_nil(frame.time.calls.Show)
            assert.is_not_nil(frame.ready.calls.Hide)
            assert.are.same({ true }, frame.icon.calls.SetDesaturated)
        end)
    end)

    describe("ShowReadyState", function()
        it("shows a full green bar and READY", function()
            local frame = fakeFrame()
            IT:ShowReadyState(frame, false)
            assert.are.same({ 0, 1 }, frame.bar.calls.SetMinMaxValues)
            assert.are.same({ 1 }, frame.bar.calls.SetValue)
            assert.are.same({ 0.2, 0.8, 0.2, 1 }, frame.bar.calls.SetStatusBarColor)
            assert.is_not_nil(frame.time.calls.Hide)
            assert.is_not_nil(frame.ready.calls.Show)
            assert.are.same({ false }, frame.icon.calls.SetDesaturated)
        end)

        it("turns yellow when there is something to interrupt", function()
            local frame = fakeFrame()
            IT:ShowReadyState(frame, true)
            assert.are.same({ 1, 0.8, 0.2, 1 }, frame.bar.calls.SetStatusBarColor)
        end)
    end)

    describe("SetIconCooldown", function()
        it("draws the swipe from start and duration", function()
            local cooldown = recorder()
            IT:SetIconCooldown(cooldown, 1766, 100, 15)
            assert.are.same({ 100, 15 }, cooldown.calls.SetCooldown)
        end)
    end)

    describe("RegisterLockoutEvents", function()
        it("listens to the combat log", function()
            local f = CreateFrame("Frame")
            IT:RegisterLockoutEvents(f)
            assert.is_true(f.events.COMBAT_LOG_EVENT_UNFILTERED)
            assert.is_not_nil(f.scripts.OnEvent)
        end)
    end)
end)

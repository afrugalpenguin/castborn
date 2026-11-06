require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/GCDIndicator.lua")
dofile("Modules/GCDIndicator_Forever.lua")

describe("GCD on Forever", function()
    local CB = Castborn
    local cfg, frame, gcdInfo, dur
    local originalUnitClass

    -- Records the arguments of the last call to each method
    local function recorder()
        local r = { calls = {} }
        setmetatable(r, { __index = function(_, k)
            return function(_, ...) r.calls[k] = { ... } end
        end })
        return r
    end

    before_each(function()
        originalUnitClass = _G.UnitClass
        cfg = { enabled = true, barColor = { 1, 1, 1, 1 }, readyColor = { 0, 1, 0, 1 } }
        CB.db = { gcd = cfg }
        frame = { bar = recorder(), spark = recorder(), pulse = recorder(),
                  timerBar = recorder(), doneWatcher = recorder() }
        frame.Show = function() frame.shown = true end
        frame.Hide = function() frame.shown = false end
        frame.GetWidth = function() return 102 end
        CB.gcdFrame = frame
        dur = {}
        _G.UnitClass = function() return "Paladin", "PALADIN" end
        _G.Enum = { StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
                    StatusBarInterpolation = { Immediate = 0 } }
        _G.C_Spell = {
            GetSpellCooldown = function() return gcdInfo end,
            GetSpellCooldownDuration = function() return dur end,
        }
    end)

    after_each(function()
        _G.C_Spell = nil
        _G.Enum = nil
        _G.UnitClass = originalUnitClass
        gcdInfo = nil
    end)

    it("starts a timer sweep when the test spell is on the GCD", function()
        gcdInfo = { isActive = true, isOnGCD = true }
        CB:CheckGCD()
        assert.is_true(frame.foreverGCD)
        assert.are.same({ dur, 0, 0 }, frame.timerBar.calls.SetTimerDuration)
        assert.are.same({ dur }, frame.doneWatcher.calls.SetCooldownFromDurationObject)
    end)

    it("ends the sweep when the GCD is over", function()
        gcdInfo = { isActive = true, isOnGCD = true }
        CB:CheckGCD()
        gcdInfo = { isActive = false, isOnGCD = false }
        CB:CheckGCD()
        assert.is_false(frame.foreverGCD)
        assert.is_not_nil(frame.timerBar.calls.Hide)
    end)

    it("does nothing when the spell is unknown", function()
        assert.has_no.errors(function() CB:CheckGCD() end)
        assert.is_nil(frame.foreverGCD)
    end)

    it("keeps the frame shown while the timer runs", function()
        frame.foreverGCD = true
        CB:UpdateGCDBar(frame, cfg)
        assert.is_true(frame.shown)
    end)
end)

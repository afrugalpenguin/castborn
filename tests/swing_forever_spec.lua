require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/SwingTimer.lua")
local tbcInit = Castborn.InitSwingTimers
dofile("Modules/SwingTimer_Forever.lua")

describe("Swing timer on Forever", function()
    local ST = Castborn.SwingTimer

    it("replaces the TBC init, which registers the combat log", function()
        assert.are_not.equal(tbcInit, Castborn.InitSwingTimers)
    end)
    local secrets = setmetatable({}, { __mode = "k" })
    local function secret() local s = {} secrets[s] = true return s end
    local now, speeds, originalGetTime

    before_each(function()
        _G.issecretvalue = function(v) return secrets[v] == true end
        _G.Enum = { PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 } }
        now, speeds = 100, {}
        originalGetTime = _G.GetTime
        _G.GetTime = function() return now end
        _G.UnitAttackSpeed = function() return speeds[1], speeds[2], speeds[3] end
        wipe(ST.swings)
        wipe(ST.outOfRange)
    end)

    after_each(function()
        _G.issecretvalue = nil
        _G.Enum = nil
        _G.GetTime = originalGetTime
        _G.UnitAttackSpeed = nil
        _G.C_SwingTimer = nil
    end)

    describe("PLAYER_SWING", function()
        it("starts the bar for the swing type", function()
            ST:OnSwing(2.6, 0)
            assert.are.same({ start = 100, duration = 2.6 }, ST.swings.mainhand)
        end)

        it("maps off-hand and ranged swings to their own bars", function()
            ST:OnSwing(1.8, 1)
            ST:OnSwing(3.0, 2)
            assert.are.equal(1.8, ST.swings.offhand.duration)
            assert.are.equal(3.0, ST.swings.ranged.duration)
        end)

        it("counts down the remaining time", function()
            ST:OnSwing(2.6, 0)
            now = 101
            assert.is_near(1.6, ST:Remaining("mainhand"), 1e-9)
        end)

        it("restarts on the next swing", function()
            ST:OnSwing(2.6, 0)
            now = 102.6
            ST:OnSwing(2.6, 0)
            assert.is_near(2.6, ST:Remaining("mainhand"), 1e-9)
        end)

        it("keeps an untimed swing when the game hides its length", function()
            ST:OnSwing(secret(), 0)
            assert.is_true(ST.swings.mainhand.untimed)
            assert.is_nil(ST:Remaining("mainhand"))
        end)

        it("drops an untimed swing when combat ends, but keeps timed ones", function()
            ST:OnSwing(secret(), 0)
            ST:OnSwing(3.0, 2)
            ST:OnCombatEnded()
            assert.is_nil(ST.swings.mainhand)
            assert.are.equal(3.0, ST.swings.ranged.duration)
        end)

        it("ignores unknown or secret swing types", function()
            ST:OnSwing(2.6, 7)
            ST:OnSwing(2.6, secret())
            assert.is_nil(next(ST.swings))
        end)

        it("ignores a zero duration", function()
            ST:OnSwing(0, 0)
            assert.is_nil(ST.swings.mainhand)
        end)
    end)

    describe("attack speed changes", function()
        it("stretches the rest of a running swing to the new speed", function()
            ST:OnSwing(2.0, 0)
            now = 101            -- half done
            speeds = { 3.0 }
            ST:OnAttackSpeedChanged()
            assert.are.equal(1.5, ST:Remaining("mainhand"))
        end)

        it("leaves the swing alone when the new speed is secret", function()
            ST:OnSwing(2.0, 0)
            now = 101
            speeds = { secret() }
            ST:OnAttackSpeedChanged()
            assert.are.equal(1.0, ST:Remaining("mainhand"))
        end)

        it("reads the ranged speed from the third return", function()
            ST:OnSwing(2.0, 2)
            now = 101
            speeds = { 2.0, nil, 4.0 }
            ST:OnAttackSpeedChanged()
            assert.are.equal(2.0, ST:Remaining("ranged"))
        end)
    end)

    describe("weapon swaps", function()
        it("restarts a running swing at the new weapon's speed", function()
            ST:OnSwing(2.0, 0)
            now = 101
            speeds = { 3.4 }
            ST:OnWeaponChanged()
            assert.is_near(3.4, ST:Remaining("mainhand"), 1e-9)
        end)

        it("clears the swing when the slot is now empty", function()
            ST:OnSwing(1.8, 1)
            speeds = { 2.6, nil }
            ST:OnWeaponChanged()
            assert.is_nil(ST.swings.offhand)
        end)

        it("does not start bars that were idle", function()
            speeds = { 2.6, 1.8, 3.0 }
            ST:OnWeaponChanged()
            assert.is_nil(next(ST.swings))
        end)
    end)

    describe("range", function()
        it("marks a bar out of range", function()
            ST:SetOutOfRange("mainhand", true)
            assert.is_true(ST.outOfRange.mainhand)
        end)

        it("treats a nil range check as in range", function()
            _G.C_SwingTimer = { IsTargetWithinSwingRange = function(t) if t == 2 then return false end end }
            ST:RefreshRange()
            assert.is_nil(ST.outOfRange.mainhand)
            assert.is_true(ST.outOfRange.ranged)
        end)

        it("ignores a secret range result", function()
            ST:SetOutOfRange("mainhand", true)
            ST:SetOutOfRange("mainhand", secret())
            assert.is_true(ST.outOfRange.mainhand)
        end)
    end)
end)

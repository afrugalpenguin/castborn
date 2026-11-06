require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/CooldownTracker.lua")

describe("Cooldown seams (TBC behaviour)", function()
    local CT = Castborn.CooldownTracker

    after_each(function() _G.GetSpellCooldown = nil end)

    it("treats a GCD-length cooldown as ready", function()
        _G.GetSpellCooldown = function() return 100, 1.5 end
        assert.is_false(CT:GetSpellCooldownState("Holy Light"))
    end)

    it("reports a long cooldown as glow-worthy", function()
        _G.GetSpellCooldown = function() return 100, 30 end
        local onCooldown, isLong, start, duration = CT:GetSpellCooldownState("Hammer of Justice")
        assert.is_true(onCooldown)
        assert.is_true(isLong)
        assert.are.equal(100, start)
        assert.are.equal(30, duration)
    end)

    it("does not mark a short cooldown as glow-worthy", function()
        _G.GetSpellCooldown = function() return 100, 2 end
        local onCooldown, isLong = CT:GetSpellCooldownState("Shock")
        assert.is_true(onCooldown)
        assert.is_false(isLong)
    end)

    it("draws the cooldown swipe from start and duration", function()
        local got
        local cooldown = { SetCooldown = function(_, s, d) got = { s, d } end }
        CT:SetIconCooldown(cooldown, "Hammer of Justice", 100, 30)
        assert.are.same({ 100, 30 }, got)
    end)
end)

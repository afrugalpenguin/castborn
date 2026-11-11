require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Data/SpellData.lua")
dofile("Modules/CooldownGroup.lua")
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

    it("uses the stored name for a tracked spell", function()
        assert.are.equal("Icy Veins", CT:GetTrackedSpellName({ spellId = 12472, name = "Icy Veins" }))
    end)

    it("draws the cooldown swipe from start and duration", function()
        local got
        local cooldown = { SetCooldown = function(_, s, d) got = { s, d } end }
        CT:SetIconCooldown(cooldown, "Hammer of Justice", 100, 30)
        assert.are.same({ 100, 30 }, got)
    end)
end)

describe("Paladin cooldown defaults", function()
    local function indexOf(name)
        for i, spell in ipairs(Castborn.SpellData:GetClassCooldowns("PALADIN")) do
            if spell.name == name then return i, spell end
        end
    end

    it("tracks Divine Protection by its castable rank 1 ID", function()
        local _, spell = indexOf("Divine Protection")
        assert.is_not_nil(spell, "Divine Protection is not tracked")
        assert.are.equal(498, spell.spellId)
    end)

    it("lists Divine Protection just before Divine Shield", function()
        local dp = indexOf("Divine Protection")
        local ds = indexOf("Divine Shield")
        assert.are.equal(ds - 1, dp)
    end)
end)

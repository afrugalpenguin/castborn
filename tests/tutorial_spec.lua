require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")

local function shownIds(Tutorial)
    local ids = {}
    for i, step in ipairs(Tutorial.steps) do
        if Tutorial:IsStepShown(i) then ids[#ids + 1] = step.id end
    end
    return ids
end

local function indexOf(Tutorial, id)
    for i, step in ipairs(Tutorial.steps) do
        if step.id == id then return i end
    end
end

describe("Tutorial steps", function()
    local originalUnitClass

    before_each(function()
        originalUnitClass = _G.UnitClass
        _G.UnitClass = function() return "Mage", "MAGE" end
        Castborn.unavailableOptions = nil
        dofile("Systems/Tutorial.lua")
    end)

    after_each(function()
        _G.UnitClass = originalUnitClass
        Castborn.unavailableOptions = nil
    end)

    describe("on TBC", function()
        it("shows every step except another class's", function()
            local ids = shownIds(Castborn.Tutorial)
            assert.are.equal(#Castborn.Tutorial.steps - 1, #ids)
            assert.is_false(Castborn.Tutorial:IsStepShown(indexOf(Castborn.Tutorial, "totems")))
        end)

        it("counts only shown steps", function()
            local T = Castborn.Tutorial
            local position, total = T:GetStepPosition(indexOf(T, "complete"))
            assert.are.equal(#T.steps - 1, total)
            assert.are.equal(total, position)
        end)
    end)

    describe("on Forever", function()
        before_each(function()
            dofile("Systems/Compat_Forever.lua")
            dofile("Systems/Tutorial_Forever.lua")
        end)

        it("shows only steps for modules Forever loads", function()
            assert.are.same({
                "welcome", "player_castbar", "castbar_companions", "cooldowns", "items",
                "other_castbars", "interrupt", "absorbs", "customise", "complete",
            }, shownIds(Castborn.Tutorial))
        end)

        it("maps the proc step to its options page id", function()
            assert.is_false(Castborn.Tutorial:IsStepShown(indexOf(Castborn.Tutorial, "procs")))
        end)

        it("describes the GCD bar without the five-second rule", function()
            local step = Castborn.Tutorial.steps[indexOf(Castborn.Tutorial, "castbar_companions")]
            assert.are.equal("GCD Indicator", step.title)
            assert.are.same({ "gcd" }, step.configKeys)
        end)

        it("numbers the steps out of those shown", function()
            local T = Castborn.Tutorial
            local position, total = T:GetStepPosition(indexOf(T, "other_castbars"))
            assert.are.equal(6, position)
            assert.are.equal(10, total)
        end)

        it("describes the interrupt tracker without the lockout", function()
            local step = Castborn.Tutorial.steps[indexOf(Castborn.Tutorial, "interrupt")]
            assert.is_nil(step.description:lower():find("lockout"))
            assert.is_nil(step.tip:lower():find("locked out"))
        end)

        it("turns the defensive step into the armour reminder", function()
            local step = Castborn.Tutorial.steps[indexOf(Castborn.Tutorial, "absorbs")]
            assert.are.equal("Armour Tracker", step.title)
            assert.are.same({ "armortracker" }, step.configKeys)
            assert.is_nil(step.description:find("Absorb"))
        end)
    end)
end)

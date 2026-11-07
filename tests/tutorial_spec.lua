require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Data/SpellData.lua")
dofile("Systems/ClassDefaults.lua")

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
    local originalUnitClass, playerClass

    local function load(class, forever)
        playerClass = class
        Castborn.unavailableOptions = nil
        dofile("Systems/Tutorial.lua")
        if forever then
            dofile("Systems/Compat_Forever.lua")
            dofile("Systems/Tutorial_Forever.lua")
        end
        return Castborn.Tutorial
    end

    before_each(function()
        originalUnitClass = _G.UnitClass
        _G.UnitClass = function() return playerClass, playerClass end
    end)

    after_each(function()
        _G.UnitClass = originalUnitClass
        Castborn.unavailableOptions = nil
    end)

    describe("on TBC", function()
        it("shows a mage the steps a mage can use", function()
            assert.are.same({
                "welcome", "player_castbar", "castbar_companions", "cooldowns", "items",
                "other_castbars", "dots", "procs", "interrupt", "absorbs", "armour",
                "customise", "complete",
            }, shownIds(load("MAGE")))
        end)

        it("shows a paladin the swing timer, armour and seals, but no interrupt or absorbs", function()
            assert.are.same({
                "welcome", "player_castbar", "castbar_companions", "cooldowns", "items",
                "other_castbars", "dots", "procs", "swing", "armour", "seals",
                "customise", "complete",
            }, shownIds(load("PALADIN")))
        end)

        it("shows totems only to shamans", function()
            assert.is_true(load("SHAMAN"):IsStepShown(indexOf(Castborn.Tutorial, "totems")))
            assert.is_false(load("MAGE"):IsStepShown(indexOf(Castborn.Tutorial, "totems")))
        end)

        it("drops the five-second rule checkbox for a warrior", function()
            local T = load("WARRIOR")
            assert.are.same({ "gcd" }, T:GetShownKeys(T.steps[indexOf(T, "castbar_companions")]))
        end)

        it("keeps both companion checkboxes for a mage", function()
            local T = load("MAGE")
            assert.are.same({ "fsr", "gcd" }, T:GetShownKeys(T.steps[indexOf(T, "castbar_companions")]))
        end)

        it("counts only shown steps", function()
            local T = load("MAGE")
            local position, total = T:GetStepPosition(indexOf(T, "complete"))
            assert.are.equal(13, total)
            assert.are.equal(13, position)
        end)
    end)

    describe("on Forever", function()
        it("shows a mage only modules Forever loads", function()
            assert.are.same({
                "welcome", "player_castbar", "castbar_companions", "cooldowns", "items",
                "other_castbars", "interrupt", "armour", "customise", "complete",
            }, shownIds(load("MAGE", true)))
        end)

        it("shows a paladin the seal tracker", function()
            assert.are.same({
                "welcome", "player_castbar", "castbar_companions", "cooldowns", "items",
                "other_castbars", "armour", "seals", "customise", "complete",
            }, shownIds(load("PALADIN", true)))
        end)

        it("maps the proc step to its options page id", function()
            local T = load("MAGE", true)
            assert.is_false(T:IsStepShown(indexOf(T, "procs")))
        end)

        it("describes the GCD bar without the five-second rule", function()
            local T = load("MAGE", true)
            local step = T.steps[indexOf(T, "castbar_companions")]
            assert.are.equal("GCD Indicator", step.title)
            assert.are.same({ "gcd" }, step.configKeys)
        end)

        it("numbers the steps out of those shown", function()
            local T = load("MAGE", true)
            local position, total = T:GetStepPosition(indexOf(T, "other_castbars"))
            assert.are.equal(6, position)
            assert.are.equal(10, total)
        end)

        it("describes the interrupt tracker without the lockout", function()
            local T = load("MAGE", true)
            local step = T.steps[indexOf(T, "interrupt")]
            assert.is_nil(step.description:lower():find("lockout"))
            assert.is_nil(step.tip:lower():find("locked out"))
        end)

        it("says the armour reminder checks out of combat", function()
            local T = load("MAGE", true)
            local step = T.steps[indexOf(T, "armour")]
            assert.is_truthy(step.description:find("out of combat"))
        end)
    end)
end)

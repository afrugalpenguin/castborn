require("tests.mocks.wow_api")
dofile("Core.lua")
dofile("Modules/AbsorbTracker.lua")

describe("Absorb Tracker enable option", function()
    local AT = Castborn.AbsorbTracker
    local savedStart, started

    before_each(function()
        savedStart = AT.Start
        started = false
        AT.Start = function() started = true end
    end)

    after_each(function() AT.Start = savedStart end)

    it("starts the tracker when turned on, without a reload", function()
        AT:SetEnabled(true)
        assert.is_true(started)
    end)

    it("leaves turning off to the update loop", function()
        AT:SetEnabled(false)
        assert.is_false(started)
    end)
end)

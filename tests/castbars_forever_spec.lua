require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/CastBars.lua")
dofile("Modules/CastBars_Forever.lua")

describe("CastBars_Forever", function()
    local calls

    before_each(function()
        calls = {}
        _G.PlayerCastingBarFrame = {
            SetUnit = function(_, unit) calls[#calls + 1] = { "SetUnit", unit } end,
            UnregisterAllEvents = function() calls[#calls + 1] = { "UnregisterAllEvents" } end,
            SetScript = function() calls[#calls + 1] = { "SetScript" } end,
            Hide = function() calls[#calls + 1] = { "Hide" } end,
        }
    end)

    after_each(function()
        _G.PlayerCastingBarFrame = nil
    end)

    it("detaches the Blizzard castbar from the player", function()
        Castborn:HideBlizzardCastBar(true)
        assert.are.same({ "SetUnit", nil }, calls[1])
    end)

    it("never unregisters Blizzard's events or replaces its scripts", function()
        Castborn:HideBlizzardCastBar(true)
        for _, call in ipairs(calls) do
            assert.are_not.equal("UnregisterAllEvents", call[1])
            assert.are_not.equal("SetScript", call[1])
        end
    end)

    it("does nothing when the frame is missing", function()
        _G.PlayerCastingBarFrame = nil
        assert.has_no.errors(function() Castborn:HideBlizzardCastBar(true) end)
    end)
end)

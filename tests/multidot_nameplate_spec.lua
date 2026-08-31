require("tests.mocks.wow_api")
dofile("Core.lua")
dofile("Modules/MultiDoTTracker.lua")

describe("MultiDoTTracker nameplate unit lookup", function()
    local MDT = Castborn.MultiDoTTracker

    -- Simulated world state: unit token -> GUID
    local units
    local calls

    local function setWorld(state)
        units = state
        calls = 0
    end

    before_each(function()
        setWorld({})
        MDT:WipeNameplateUnits()

        _G.UnitGUID = function(unit)
            calls = calls + 1
            return units[unit]
        end
        _G.UnitExists = function(unit)
            calls = calls + 1
            return units[unit] ~= nil
        end
    end)

    describe("fast paths", function()
        it("resolves the target without consulting the map", function()
            setWorld({ target = "GUID-A" })
            assert.are.equal("target", MDT:GetUnitIdFromGUID("GUID-A"))
        end)

        it("falls back to focus", function()
            setWorld({ focus = "GUID-F" })
            assert.are.equal("focus", MDT:GetUnitIdFromGUID("GUID-F"))
        end)

        it("falls back to mouseover", function()
            setWorld({ mouseover = "GUID-M" })
            assert.are.equal("mouseover", MDT:GetUnitIdFromGUID("GUID-M"))
        end)

        it("returns nil when the GUID is nowhere", function()
            setWorld({ target = "GUID-OTHER" })
            assert.is_nil(MDT:GetUnitIdFromGUID("GUID-MISSING"))
        end)
    end)

    describe("nameplate map", function()
        it("resolves a GUID added via NAME_PLATE_UNIT_ADDED", function()
            setWorld({ nameplate7 = "GUID-B" })
            MDT:TrackNameplateUnit("nameplate7")
            assert.are.equal("nameplate7", MDT:GetUnitIdFromGUID("GUID-B"))
        end)

        it("stops resolving once the nameplate is removed", function()
            setWorld({ nameplate7 = "GUID-B" })
            MDT:TrackNameplateUnit("nameplate7")
            MDT:UntrackNameplateUnit("nameplate7")
            assert.is_nil(MDT:GetUnitIdFromGUID("GUID-B"))
        end)

        it("untracks by token even when the unit is already gone", function()
            -- On NAME_PLATE_UNIT_REMOVED, UnitGUID(unit) may already return nil,
            -- so removal must not depend on resolving the GUID again.
            setWorld({ nameplate3 = "GUID-C" })
            MDT:TrackNameplateUnit("nameplate3")
            setWorld({})
            MDT:UntrackNameplateUnit("nameplate3")
            setWorld({ nameplate3 = "GUID-C" })
            assert.is_nil(MDT:GetUnitIdFromGUID("GUID-C"))
        end)

        it("drops a stale entry when the plate has been recycled", function()
            -- Plate recycled to a different mob without us seeing the events.
            setWorld({ nameplate2 = "GUID-D" })
            MDT:TrackNameplateUnit("nameplate2")
            setWorld({ nameplate2 = "GUID-RECYCLED" })
            assert.is_nil(MDT:GetUnitIdFromGUID("GUID-D"))
            -- and the stale entry is gone, not left to be re-checked forever
            setWorld({})
            assert.is_nil(MDT:GetUnitIdFromGUID("GUID-D"))
            assert.are.equal(3, calls, "stale entry should not be probed again")
        end)

        it("wipes the map on zone change", function()
            setWorld({ nameplate1 = "GUID-E" })
            MDT:TrackNameplateUnit("nameplate1")
            MDT:WipeNameplateUnits()
            assert.is_nil(MDT:GetUnitIdFromGUID("GUID-E"))
        end)
    end)

    describe("lookup cost", function()
        it("costs a bounded number of unit API calls on a miss", function()
            -- The old implementation probed nameplate1..40 with UnitExists +
            -- UnitGUID, so a miss cost up to ~82 calls. The map makes a miss
            -- cost target + focus + mouseover only.
            local world = {}
            for i = 1, 40 do world["nameplate" .. i] = "GUID-PLATE-" .. i end
            setWorld(world)
            for i = 1, 40 do MDT:TrackNameplateUnit("nameplate" .. i) end

            calls = 0
            assert.is_nil(MDT:GetUnitIdFromGUID("GUID-ABSENT"))
            print(string.format("[bench] miss with 40 plates tracked: %d unit API calls", calls))
            assert.is_true(calls <= 3, "miss cost " .. calls .. " calls, expected <= 3")
        end)

        it("costs a bounded number of unit API calls on a hit", function()
            local world = {}
            for i = 1, 40 do world["nameplate" .. i] = "GUID-PLATE-" .. i end
            setWorld(world)
            for i = 1, 40 do MDT:TrackNameplateUnit("nameplate" .. i) end

            calls = 0
            assert.are.equal("nameplate40", MDT:GetUnitIdFromGUID("GUID-PLATE-40"))
            print(string.format("[bench] hit on last plate: %d unit API calls", calls))
            assert.is_true(calls <= 3, "hit cost " .. calls .. " calls, expected <= 3")
        end)
    end)
end)

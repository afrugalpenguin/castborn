require("tests.mocks.wow_api")
dofile("Core.lua")
dofile("Modules/ProgressPanel.lua")
dofile("Modules/ProgressPanel_Forever.lua")

describe("Progress panel on Forever", function()
    local TP = Castborn.ProgressPanel

    after_each(function()
        _G.C_Reputation = nil
        _G.GetWatchedFactionInfo = nil
    end)

    describe("ReadWatchedFaction", function()
        it("reads the watched faction from C_Reputation", function()
            _G.C_Reputation = {
                GetWatchedFactionData = function()
                    return {
                        factionID = 530, name = "Darkspear Raiders", reaction = 6,
                        currentReactionThreshold = 9000, nextReactionThreshold = 21000, currentStanding = 16296,
                    }
                end,
            }
            assert.are.same({ factionID = 530, name = "Darkspear Raiders", reaction = 6, min = 9000, max = 21000,
                value = 16296 }, TP:ReadWatchedFaction())
        end)

        it("does not need the old global, which Forever lacks", function()
            _G.C_Reputation = { GetWatchedFactionData = function() return nil end }
            assert.is_nil(TP:ReadWatchedFaction())
        end)

        it("reads nothing without C_Reputation", function()
            assert.is_nil(TP:ReadWatchedFaction())
        end)

        it("feeds the same row maths as TBC", function()
            _G.C_Reputation = {
                GetWatchedFactionData = function()
                    return { name = "Orgrimmar", reaction = 5, currentReactionThreshold = 3000,
                        nextReactionThreshold = 9000, currentStanding = 6000 }
                end,
            }
            local row = TP:BuildReputationRow(TP:ReadWatchedFaction())
            assert.matches("Friendly|r 50.0%%$", row.value)
            assert.are.equal("3,000 to Honored", row.detail)
        end)
    end)

    describe("ReadFactionByID", function()
        it("reads a pinned faction from C_Reputation by ID", function()
            _G.C_Reputation = {
                GetFactionDataByID = function(id)
                    if id == 76 then
                        return { factionID = 76, name = "Orgrimmar", reaction = 5, currentReactionThreshold = 3000,
                            nextReactionThreshold = 9000, currentStanding = 6000 }
                    end
                end,
            }
            assert.are.same({ factionID = 76, name = "Orgrimmar", reaction = 5, min = 3000, max = 9000, value = 6000 },
                TP:ReadFactionByID(76))
            assert.is_nil(TP:ReadFactionByID(1))
        end)

        it("reads nothing without the API", function()
            _G.C_Reputation = {}
            assert.is_nil(TP:ReadFactionByID(76))
        end)
    end)

    describe("ReadKnownFactions", function()
        after_each(function() _G.FACTION_INACTIVE = nil end)

        it("lists factions from C_Reputation, skipping headers and inactive ones", function()
            _G.FACTION_INACTIVE = "Inactive"
            local rows = {
                { name = "Horde", isHeader = true, factionID = 67 },
                { name = "Orgrimmar", factionID = 76 },
                { name = "Ravenholdt", factionID = 349 },        -- inactive by IsFactionActive
                { name = "Placeholder", factionID = 0 },
                { name = "Inactive", isHeader = true, factionID = 0 },
                { name = "Bloodsail Buccaneers", factionID = 87 },
            }
            _G.C_Reputation = {
                GetNumFactions = function() return #rows end,
                GetFactionDataByIndex = function(i) return rows[i] end,
                IsFactionActive = function(i) return i ~= 3 end,
            }
            assert.are.same({ { id = 76, name = "Orgrimmar" } }, TP:ReadKnownFactions())
        end)

        it("lists nothing without C_Reputation", function()
            assert.are.same({}, TP:ReadKnownFactions())
        end)
    end)

    describe("GetBlizzardBars", function()
        it("fades the Edit Mode StatusTrackingBar containers instead of reparenting them", function()
            assert.are.same({
                { name = "MainStatusTrackingBarContainer", mode = "alpha" },
                { name = "SecondaryStatusTrackingBarContainer", mode = "alpha" },
            }, TP:GetBlizzardBars())
        end)
    end)
end)

require("tests.mocks.wow_api")
dofile("Core.lua")
dofile("Modules/TrackingPanel.lua")
dofile("Modules/TrackingPanel_Forever.lua")

describe("Tracking panel on Forever", function()
    local TP = Castborn.TrackingPanel

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
            assert.are.same({ name = "Darkspear Raiders", reaction = 6, min = 9000, max = 21000, value = 16296 },
                TP:ReadWatchedFaction())
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

    describe("GetBlizzardBars", function()
        it("fades the Edit Mode StatusTrackingBar containers instead of reparenting them", function()
            assert.are.same({
                { name = "MainStatusTrackingBarContainer", mode = "alpha" },
                { name = "SecondaryStatusTrackingBarContainer", mode = "alpha" },
            }, TP:GetBlizzardBars())
        end)
    end)
end)

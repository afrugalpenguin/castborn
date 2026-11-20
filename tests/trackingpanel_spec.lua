require("tests.mocks.wow_api")
dofile("Core.lua")
dofile("Modules/TrackingPanel.lua")

describe("Tracking panel (TBC behaviour)", function()
    local TP = Castborn.TrackingPanel
    local db

    -- A Blizzard bar that remembers its parent, points, alpha and mouse state
    local function blizzardBar(parent)
        local frame = CreateFrame("Frame")
        frame:SetParent(parent)
        frame:SetPoint("BOTTOM", parent, "BOTTOM", 0, 10)
        frame:SetAlpha(1)
        frame:EnableMouse(true)
        return frame
    end

    local mainMenuBar

    before_each(function()
        db = Castborn:MergeDefaults({}, TP.defaults)
        Castborn.db = Castborn.db or {}
        Castborn.db.tracking = db
        TP.testModeActive = false
        TP.pendingBlizzardBars = false
        TP:RestoreBlizzardBars()
        mainMenuBar = CreateFrame("Frame")
        _G.MainMenuExpBar = blizzardBar(mainMenuBar)
        _G.ReputationWatchBar = blizzardBar(mainMenuBar)
        _G.MainMenuBarMaxLevelBar = nil
    end)

    after_each(function()
        TP:RestoreBlizzardBars()
        _G.MainMenuExpBar = nil
        _G.ReputationWatchBar = nil
        _G.InCombatLockdown = nil
        _G.FACTION_BAR_COLORS = nil
        _G.FACTION_STANDING_LABEL6 = nil
        _G.UnitLevel = nil
        _G.UnitXP = nil
        _G.UnitXPMax = nil
        _G.GetXPExhaustion = nil
        _G.GetMaxPlayerLevel = nil
        _G.IsXPUserDisabled = nil
        _G.GetWatchedFactionInfo = nil
    end)

    describe("FormatNumber", function()
        it("groups thousands with commas", function()
            assert.are.equal("0", TP:FormatNumber(0))
            assert.are.equal("999", TP:FormatNumber(999))
            assert.are.equal("41,300", TP:FormatNumber(41300))
            assert.are.equal("1,234,567", TP:FormatNumber(1234567))
        end)
    end)

    describe("XP row", function()
        local function xp(overrides)
            local t = { level = 42, current = 58700, max = 100000, rested = 0, maxLevel = 70, disabled = false }
            for k, v in pairs(overrides or {}) do t[k] = v end
            return t
        end

        it("shows the level, percentage and amount to go", function()
            local row = TP:BuildXPRow(xp())
            assert.are.equal("Level 42", row.name)
            assert.are.equal("58.7% (41,300 to go)", row.value)
            assert.are.equal(100000, row.max)
            assert.are.equal(58700, row.fill)
        end)

        it("has no detail line when not rested", function()
            local row = TP:BuildXPRow(xp())
            assert.is_nil(row.detail)
            assert.are.equal(58700, row.rested)
        end)

        it("shows rested as a detail line and a second fill", function()
            local row = TP:BuildXPRow(xp({ rested = 21300 }))
            assert.are.equal("Rested 21,300", row.detail)
            assert.are.equal(80000, row.rested)
        end)

        it("caps the rested fill at the level's max", function()
            assert.are.equal(100000, TP:BuildXPRow(xp({ rested = 60000 })).rested)
        end)

        it("copes with a max of 0", function()
            local row = TP:BuildXPRow(xp({ current = 0, max = 0 }))
            assert.are.equal("0.0% (0 to go)", row.value)
            assert.are.equal(1, row.max)
        end)

        it("hides at max level", function()
            assert.is_true(TP:ShouldShowXP(xp()))
            assert.is_false(TP:ShouldShowXP(xp({ level = 70 })))
        end)

        it("hides when XP is disabled", function()
            assert.is_false(TP:ShouldShowXP(xp({ disabled = true })))
        end)

        it("reads XP, treating no rested XP as 0", function()
            _G.UnitLevel = function() return 42 end
            _G.UnitXP = function() return 500 end
            _G.UnitXPMax = function() return 1000 end
            _G.GetXPExhaustion = function() return nil end
            _G.GetMaxPlayerLevel = function() return 70 end
            _G.IsXPUserDisabled = function() return false end
            assert.are.same({ level = 42, current = 500, max = 1000, rested = 0, maxLevel = 70, disabled = false },
                TP:ReadXP())
        end)
    end)

    describe("reputation row", function()
        -- Darkspear Raiders, Honored 7296 / 12000
        local function rep(overrides)
            local t = { name = "Darkspear Raiders", reaction = 6, min = 9000, max = 21000, value = 16296 }
            for k, v in pairs(overrides or {}) do t[k] = v end
            return t
        end

        it("shows the coloured standing and percentage through it", function()
            local row = TP:BuildReputationRow(rep())
            assert.are.equal("Darkspear Raiders", row.name)
            assert.matches("Honored|r 60.8%%$", row.value)
            assert.are.equal(12000, row.max)
            assert.are.equal(7296, row.fill)
        end)

        it("shows the amount to the next standing", function()
            assert.are.equal("4,704 to Revered", TP:BuildReputationRow(rep()).detail)
        end)

        it("has no detail at Exalted", function()
            local row = TP:BuildReputationRow(rep({ reaction = 8, min = 42000, max = 42999, value = 42500 }))
            assert.is_nil(row.detail)
            assert.matches("Exalted|r 50.1%%$", row.value)
        end)

        it("treats a zero-width standing as full", function()
            local row = TP:BuildReputationRow(rep({ min = 100, max = 100, value = 100 }))
            assert.matches(" 100.0%%$", row.value)
            assert.is_nil(row.detail)
            assert.are.equal(1, row.max)
            assert.are.equal(1, row.fill)
        end)

        it("uses the client's standing label when it has one", function()
            _G.FACTION_STANDING_LABEL6 = "Honoured"
            assert.matches("Honoured|r", TP:BuildReputationRow(rep()).value)
        end)

        it("colours by standing from FACTION_BAR_COLORS", function()
            _G.FACTION_BAR_COLORS = { [6] = { r = 0.1, g = 0.2, b = 0.3 } }
            local row = TP:BuildReputationRow(rep())
            assert.are.same({ 0.1, 0.2, 0.3 }, row.color)
            assert.matches("^|cff1a334d", row.value)
        end)

        it("falls back to its own colours without FACTION_BAR_COLORS", function()
            local r, g, b = TP:StandingColor(6)
            local f = TP.fallbackStandingColors[6]
            assert.are.same({ f.r, f.g, f.b }, { r, g, b })
            r = TP:StandingColor(99)
            assert.is_number(r)
        end)

        it("reads the watched faction from the old global", function()
            _G.GetWatchedFactionInfo = function() return "Darkspear Raiders", 6, 9000, 21000, 16296, 530 end
            assert.are.same(rep(), TP:ReadWatchedFaction())
        end)

        it("reads nothing when no faction is watched", function()
            _G.GetWatchedFactionInfo = function() return nil end
            assert.is_nil(TP:ReadWatchedFaction())
        end)
    end)

    describe("rows and visibility", function()
        local readXP, readWatchedFaction = TP.ReadXP, TP.ReadWatchedFaction

        after_each(function()
            TP.ReadXP = readXP
            TP.ReadWatchedFaction = readWatchedFaction
        end)

        it("collects no rows when nothing is tracked", function()
            TP.ReadXP = function() return { level = 70, current = 0, max = 1, rested = 0, maxLevel = 70 } end
            TP.ReadWatchedFaction = function() return nil end
            local rows = TP:CollectRows(db)
            assert.are.equal(0, #rows)
            assert.is_false(TP:GetVisibility(db, #rows))
        end)

        it("shows when a row is tracked", function()
            assert.is_true(TP:GetVisibility(db, 1))
        end)

        it("hides when disabled", function()
            db.enabled = false
            assert.is_false(TP:GetVisibility(db, 2))
        end)

        it("shows the sample rows in test mode", function()
            TP.testModeActive = true
            local rows = TP:CollectRows(db)
            assert.are.equal(2, #rows)
            assert.are.equal("Level 42", rows[1].name)
            assert.are.equal("58.7% (41,300 to go)", rows[1].value)
            assert.are.equal(80000, rows[1].rested)
            assert.are.equal("Darkspear Raiders", rows[2].name)
            assert.matches("Honored|r 60.8%%$", rows[2].value)
            assert.is_true(TP:GetVisibility(db, 0))
        end)

        it("leaves out rows that are turned off", function()
            TP.testModeActive = false
            db.showXP = false
            TP.ReadWatchedFaction = function()
                return { name = "Orgrimmar", reaction = 5, min = 3000, max = 9000, value = 6000 }
            end
            local rows = TP:CollectRows(db)
            assert.are.equal(1, #rows)
            assert.are.equal("Orgrimmar", rows[1].name)
        end)
    end)

    describe("Blizzard bars", function()
        it("lists the TBC bars, all reparented", function()
            local bars = TP:GetBlizzardBars()
            local names = {}
            for _, entry in ipairs(bars) do
                names[#names + 1] = entry.name
                assert.are.equal("reparent", entry.mode)
            end
            assert.are.same({ "MainMenuExpBar", "ReputationWatchBar", "MainMenuBarMaxLevelBar" }, names)
        end)

        it("moves them to a hidden parent while the panel is enabled", function()
            TP:UpdateBlizzardBars()
            assert.are.equal(TP.hider, _G.MainMenuExpBar:GetParent())
            assert.are.equal(TP.hider, _G.ReputationWatchBar:GetParent())
        end)

        it("skips bars this client does not have", function()
            assert.has_no.errors(function() TP:UpdateBlizzardBars() end)
        end)

        it("puts them back with their parent and points when disabled", function()
            TP:UpdateBlizzardBars()
            _G.MainMenuExpBar:ClearAllPoints()
            db.enabled = false
            TP:UpdateBlizzardBars()
            assert.are.equal(mainMenuBar, _G.MainMenuExpBar:GetParent())
            assert.are.same({ { "BOTTOM", mainMenuBar, "BOTTOM", 0, 10 } }, _G.MainMenuExpBar.points)
        end)

        it("puts them back when hideBlizzardBars is turned off", function()
            TP:UpdateBlizzardBars()
            db.hideBlizzardBars = false
            TP:UpdateBlizzardBars()
            assert.are.equal(mainMenuBar, _G.ReputationWatchBar:GetParent())
        end)

        it("leaves them alone when hideBlizzardBars is off", function()
            db.hideBlizzardBars = false
            TP:UpdateBlizzardBars()
            assert.are.equal(mainMenuBar, _G.MainMenuExpBar:GetParent())
        end)

        it("never hides them for test mode alone", function()
            db.enabled = false
            Castborn:TestTrackingPanel()
            assert.are.equal(mainMenuBar, _G.MainMenuExpBar:GetParent())
            Castborn:EndTestTrackingPanel()
            assert.are.equal(mainMenuBar, _G.MainMenuExpBar:GetParent())
        end)

        it("fades and disables the mouse in alpha mode, then restores both", function()
            local original = TP.GetBlizzardBars
            TP.GetBlizzardBars = function() return { { name = "MainMenuExpBar", mode = "alpha" } } end
            _G.MainMenuExpBar:SetAlpha(0.8)
            TP:UpdateBlizzardBars()
            assert.are.equal(0, _G.MainMenuExpBar:GetAlpha())
            assert.is_false(_G.MainMenuExpBar:IsMouseEnabled())
            assert.are.equal(mainMenuBar, _G.MainMenuExpBar:GetParent())
            db.enabled = false
            TP:UpdateBlizzardBars()
            assert.are.equal(0.8, _G.MainMenuExpBar:GetAlpha())
            assert.is_true(_G.MainMenuExpBar:IsMouseEnabled())
            TP.GetBlizzardBars = original
        end)

        it("queues a change in combat until combat ends", function()
            TP:UpdateBlizzardBars()
            _G.InCombatLockdown = function() return true end
            db.enabled = false
            TP:UpdateBlizzardBars()
            assert.are.equal(TP.hider, _G.MainMenuExpBar:GetParent())
            assert.is_true(TP.pendingBlizzardBars)
            _G.InCombatLockdown = function() return false end
            TP:OnEvent("PLAYER_REGEN_ENABLED")
            assert.are.equal(mainMenuBar, _G.MainMenuExpBar:GetParent())
            assert.is_false(TP.pendingBlizzardBars)
        end)

        it("does not hide them in combat either", function()
            _G.InCombatLockdown = function() return true end
            TP:UpdateBlizzardBars()
            assert.are.equal(mainMenuBar, _G.MainMenuExpBar:GetParent())
            _G.InCombatLockdown = function() return false end
            TP:OnEvent("PLAYER_REGEN_ENABLED")
            assert.are.equal(TP.hider, _G.MainMenuExpBar:GetParent())
        end)
    end)

    describe("events", function()
        it("registers every event, skipping any the client rejects", function()
            local frame = CreateFrame("Frame")
            local register = frame.RegisterEvent
            frame.RegisterEvent = function(self, event)
                if event == "UPDATE_EXHAUSTION" then error("unknown event") end
                register(self, event)
            end
            TP:RegisterEvents(frame)
            assert.are.same({ "UPDATE_EXHAUSTION" }, TP.skippedEvents)
            for _, event in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_FACTION",
                    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
                assert.is_true(frame.events[event], event .. " is not registered")
            end
        end)
    end)
end)

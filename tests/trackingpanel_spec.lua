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
        CastbornDB.characters = nil
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
            local t = { factionID = 530, name = "Darkspear Raiders", reaction = 6, min = 9000, max = 21000, value = 16296 }
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

        it("reads a faction by its ID", function()
            _G.GetFactionInfoByID = function(id)
                if id == 530 then return "Darkspear Raiders", "", 6, 9000, 21000, 16296 end
            end
            assert.are.same(rep(), TP:ReadFactionByID(530))
            assert.is_nil(TP:ReadFactionByID(1))
            _G.GetFactionInfoByID = nil
        end)

        it("lists known factions, skipping headers, inactive ones and any without an ID", function()
            _G.FACTION_INACTIVE = "Inactive"
            local rows = {
                { "Horde", true },
                { "Orgrimmar", false, 76 },
                { "Darkspear Raiders", false, 530 },
                { "Ravenholdt", false, 349 },          -- flagged inactive by the client
                { "Nameless", false, nil },
                { "Inactive", true },
                { "Bloodsail Buccaneers", false, 87 },  -- under the Inactive header
            }
            _G.GetNumFactions = function() return #rows end
            _G.GetFactionInfo = function(i)
                local r = rows[i]
                return r[1], "", 4, 0, 0, 0, false, false, r[2], false, false, false, false, r[3]
            end
            _G.IsFactionInactive = function(i) return i == 4 end
            assert.are.same({ { id = 76, name = "Orgrimmar" }, { id = 530, name = "Darkspear Raiders" } },
                TP:ReadKnownFactions())
            _G.FACTION_INACTIVE = nil
            _G.GetNumFactions = nil
            _G.GetFactionInfo = nil
            _G.IsFactionInactive = nil
        end)
    end)

    describe("pinned reputations", function()
        after_each(function()
            _G.UnitName = function() return "TestPlayer" end
        end)

        it("pins a faction once, in the order added", function()
            assert.is_true(TP:PinFaction(530))
            assert.is_true(TP:PinFaction(76))
            assert.is_false(TP:PinFaction(530))
            assert.are.same({ 530, 76 }, TP:GetPinnedFactions())
            assert.is_true(TP:IsPinned(76))
        end)

        it("unpins a faction and keeps the others in order", function()
            TP:PinFaction(530)
            TP:PinFaction(76)
            TP:PinFaction(81)
            assert.is_true(TP:UnpinFaction(76))
            assert.is_false(TP:UnpinFaction(76))
            assert.are.same({ 530, 81 }, TP:GetPinnedFactions())
            assert.is_false(TP:IsPinned(76))
        end)

        it("stores faction IDs per character and realm, outside the tracking settings", function()
            TP:PinFaction(530)
            assert.are.same({ 530 }, CastbornDB.characters["TestPlayer-TestRealm"].trackedFactions)
            assert.is_nil(db.characters)
        end)

        it("keeps each character's list separate", function()
            TP:PinFaction(530)
            _G.UnitName = function() return "Altchar" end
            assert.are.same({}, TP:GetPinnedFactions())
            TP:PinFaction(76)
            _G.UnitName = function() return "TestPlayer" end
            assert.are.same({ 530 }, TP:GetPinnedFactions())
            assert.are.same({ 76 }, CastbornDB.characters["Altchar-TestRealm"].trackedFactions)
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

    describe("row order and settings", function()
        local readXP, readWatchedFaction, readFactionByID = TP.ReadXP, TP.ReadWatchedFaction, TP.ReadFactionByID
        local factions = {
            [76] = { factionID = 76, name = "Orgrimmar", reaction = 5, min = 3000, max = 9000, value = 6000 },
            [530] = { factionID = 530, name = "Darkspear Raiders", reaction = 6, min = 9000, max = 21000, value = 16296 },
            [81] = { factionID = 81, name = "Thunder Bluff", reaction = 4, min = 0, max = 3000, value = 1500 },
        }

        before_each(function()
            TP.ReadXP = function()
                return { level = 42, current = 500, max = 1000, rested = 200, maxLevel = 70, disabled = false }
            end
            TP.ReadWatchedFaction = function() return factions[530] end
            TP.ReadFactionByID = function(_, id) return factions[id] end
        end)

        after_each(function()
            TP.ReadXP = readXP
            TP.ReadWatchedFaction = readWatchedFaction
            TP.ReadFactionByID = readFactionByID
        end)

        local function names(rows)
            local list = {}
            for _, row in ipairs(rows) do list[#list + 1] = row.name end
            return list
        end

        it("puts XP first, then the watched reputation, then pinned ones in the order added", function()
            TP:PinFaction(81)
            TP:PinFaction(76)
            assert.are.same({ "Level 42", "Darkspear Raiders", "Thunder Bluff", "Orgrimmar" }, names(TP:CollectRows(db)))
        end)

        it("shows a pinned faction that is also watched once, as the watched row", function()
            TP:PinFaction(76)
            TP:PinFaction(530)
            assert.are.same({ "Level 42", "Darkspear Raiders", "Orgrimmar" }, names(TP:CollectRows(db)))
        end)

        it("shows a pinned faction in its own place when the watched row is off", function()
            db.showReputation = false
            TP:PinFaction(76)
            TP:PinFaction(530)
            assert.are.same({ "Level 42", "Orgrimmar", "Darkspear Raiders" }, names(TP:CollectRows(db)))
        end)

        it("skips a pinned faction the client cannot read", function()
            TP:PinFaction(999)
            TP:PinFaction(76)
            assert.are.same({ "Level 42", "Darkspear Raiders", "Orgrimmar" }, names(TP:CollectRows(db)))
        end)

        it("drops the rested fill when the overlay is off", function()
            db.showRested = false
            local xpRow = TP:CollectRows(db)[1]
            assert.is_nil(xpRow.rested)
            assert.are.equal("Rested 200", xpRow.detail)
        end)

        it("drops every detail line when detail is off", function()
            db.showDetail = false
            TP:PinFaction(76)
            for _, row in ipairs(TP:CollectRows(db)) do
                assert.is_nil(row.detail, row.name .. " kept its detail")
            end
        end)

        it("applies the settings to test mode's sample rows too", function()
            db.showDetail = false
            db.showRested = false
            TP.testModeActive = true
            local rows = TP:CollectRows(db)
            assert.is_nil(rows[1].rested)
            assert.is_nil(rows[1].detail)
            TP.testModeActive = false
        end)

        it("keeps XP at max level when hiding it there is off", function()
            local atMax = { level = 70, current = 0, max = 0, rested = 0, maxLevel = 70, disabled = false }
            assert.is_false(TP:ShouldShowXP(atMax, db))
            db.hideAtMaxLevel = false
            assert.is_true(TP:ShouldShowXP(atMax, db))
            assert.is_false(TP:ShouldShowXP({ level = 70, maxLevel = 70, disabled = true }, db))
        end)
    end)

    describe("collapsed mode", function()
        it("is off by default", function()
            assert.is_false(db.collapsed)
            assert.is_false(db.startCollapsed)
        end)

        it("saves the state the header button sets, so it survives a reload", function()
            TP:ToggleCollapsed()
            assert.is_true(Castborn.db.tracking.collapsed)
            -- A reload merges defaults into the saved table, which keeps the state
            local reloaded = Castborn:MergeDefaults(Castborn.db.tracking, TP.defaults)
            TP:ApplyStartCollapsed(reloaded)
            assert.is_true(reloaded.collapsed)
            TP:ToggleCollapsed()
            assert.is_false(Castborn.db.tracking.collapsed)
        end)

        it("starts collapsed when asked, whatever was saved", function()
            db.collapsed = false
            db.startCollapsed = true
            TP:ApplyStartCollapsed(db)
            assert.is_true(db.collapsed)
        end)

        it("keeps the saved state when not starting collapsed", function()
            db.collapsed = false
            TP:ApplyStartCollapsed(db)
            assert.is_false(db.collapsed)
        end)

        it("shows the row's name, value and detail in the hover tooltip", function()
            local row = TP:BuildXPRow({ level = 42, current = 58700, max = 100000, rested = 21300 })
            assert.are.same({ left = "Level 42", right = "58.7% (41,300 to go)", detail = "Rested 21,300" },
                TP:GetTooltipLines(row))
        end)

        it("gives rows the mouse only while collapsed and locked", function()
            CastbornDB.locked = true
            assert.is_false(TP:RowWantsMouse({}, db))
            db.collapsed = true
            assert.is_true(TP:RowWantsMouse({}, db))
            CastbornDB.locked = false
            assert.is_false(TP:RowWantsMouse({}, db))
            CastbornDB.locked = nil
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

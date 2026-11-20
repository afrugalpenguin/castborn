require("tests.mocks.wow_api")
dofile("Core.lua")
dofile("Modules/ProgressPanel.lua")

describe("Progress panel (TBC behaviour)", function()
    local TP = Castborn.ProgressPanel
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
        Castborn.db.progress = db
        TP.testModeActive = false
        TP.pendingBlizzardBars = false
        TP:RestoreBlizzardBars()
        CastbornDB.characters = nil
        TP:ResetSession()
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
            assert.are.same({ { id = 76, name = "Orgrimmar", value = 0 }, { id = 530, name = "Darkspear Raiders", value = 0 } },
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

        it("stores faction IDs per character and realm, outside the progress settings", function()
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

    describe("reputation gains", function()
        local readKnown, readByID, readWatched, now = TP.ReadKnownFactions, TP.ReadFactionByID,
            TP.ReadWatchedFaction, TP.Now
        local clock, standings, watched

        local factions = {
            [76] = { name = "Orgrimmar", reaction = 5, min = 3000, max = 9000 },
            [530] = { name = "Darkspear Raiders", reaction = 6, min = 9000, max = 21000 },
            [81] = { name = "Thunder Bluff", reaction = 4, min = 0, max = 3000 },
        }

        before_each(function()
            clock = 1000
            standings = { [76] = 4000, [530] = 10000, [81] = 100 }
            watched = nil
            TP.autoAdded = {}
            TP.factionSnapshot = nil
            TP.Now = function() return clock end
            TP.ReadKnownFactions = function()
                local list = {}
                for _, id in ipairs({ 76, 530, 81 }) do
                    list[#list + 1] = { id = id, name = factions[id].name, value = standings[id] }
                end
                return list
            end
            TP.ReadFactionByID = function(_, id)
                local f = factions[id]
                return { factionID = id, name = f.name, reaction = f.reaction, min = f.min, max = f.max,
                    value = standings[id] }
            end
            TP.ReadWatchedFaction = function()
                return watched and TP:ReadFactionByID(watched) or nil
            end
            db.showXP = false
        end)

        after_each(function()
            TP.ReadKnownFactions = readKnown
            TP.ReadFactionByID = readByID
            TP.ReadWatchedFaction = readWatched
            TP.Now = now
            TP.autoAdded = {}
            TP.factionSnapshot = nil
        end)

        local function gain(id, amount)
            standings[id] = standings[id] + amount
            TP:OnEvent("UPDATE_FACTION")
        end

        local function names(rows)
            local list = {}
            for _, row in ipairs(rows) do list[#list + 1] = row.name end
            return list
        end

        it("detects gains by diffing against the snapshot", function()
            TP:OnEvent("PLAYER_ENTERING_WORLD")
            standings[76] = 4250
            standings[530] = 9900
            assert.are.same({ { id = 76, delta = 250 } }, TP:DetectFactionGains())
            assert.are.same({}, TP:DetectFactionGains())
        end)

        it("takes a snapshot instead of reporting gains when it has none", function()
            assert.are.same({}, TP:DetectFactionGains())
            standings[81] = 200
            assert.are.same({ { id = 81, delta = 100 } }, TP:DetectFactionGains())
        end)

        it("adds an untracked faction that gains as a temporary row at the bottom", function()
            TP:OnEvent("PLAYER_ENTERING_WORLD")
            TP:PinFaction(81)
            gain(76, 25)
            local rows = TP:CollectRows(db)
            assert.are.same({ "Thunder Bluff", "Orgrimmar" }, names(rows))
            assert.is_true(rows[2].autoAdded)
            assert.are.equal("Auto-added - pin to keep", rows[2].detail)
        end)

        it("highlights a temporary row only once", function()
            TP:OnEvent("PLAYER_ENTERING_WORLD")
            gain(76, 25)
            assert.is_true(TP:CollectRows(db)[1].flash)
            assert.is_false(TP:CollectRows(db)[1].flash)
            gain(76, 25)
            assert.is_false(TP:CollectRows(db)[1].flash)
        end)

        it("ignores gains on pinned and watched factions", function()
            TP:OnEvent("PLAYER_ENTERING_WORLD")
            TP:PinFaction(81)
            watched = 530
            gain(81, 10)
            gain(530, 10)
            assert.are.equal(0, #TP.autoAdded)
        end)

        it("drops a temporary row after ten minutes without another gain", function()
            TP:OnEvent("PLAYER_ENTERING_WORLD")
            gain(76, 25)
            clock = 1000 + 599
            assert.are.equal(1, #TP:CollectRows(db))
            clock = 1000 + 600
            assert.are.equal(0, #TP:CollectRows(db))
            assert.are.equal(0, #TP.autoAdded)
        end)

        it("restarts the ten minutes on each gain", function()
            TP:OnEvent("PLAYER_ENTERING_WORLD")
            gain(76, 25)
            clock = 1000 + 300
            gain(76, 25)
            clock = 1000 + 899
            assert.are.equal(1, #TP:CollectRows(db))
            clock = 1000 + 900
            assert.are.equal(0, #TP:CollectRows(db))
        end)

        it("keeps temporary rows in the order they first gained", function()
            TP:OnEvent("PLAYER_ENTERING_WORLD")
            gain(81, 5)
            gain(76, 5)
            gain(81, 5)
            assert.are.same({ "Thunder Bluff", "Orgrimmar" }, names(TP:CollectRows(db)))
        end)

        it("keeps the notice even with detail lines off", function()
            db.showDetail = false
            TP:OnEvent("PLAYER_ENTERING_WORLD")
            gain(76, 25)
            assert.are.equal("Auto-added - pin to keep", TP:CollectRows(db)[1].detail)
        end)

        it("pins a temporary row when it is clicked", function()
            TP:OnEvent("PLAYER_ENTERING_WORLD")
            gain(76, 25)
            local row = TP:CollectRows(db)[1]
            assert.is_true(TP:OnRowClick(row))
            assert.are.same({ 76 }, TP:GetPinnedFactions())
            assert.are.equal(0, #TP.autoAdded)
            local rows = TP:CollectRows(db)
            assert.are.equal(1, #rows)
            assert.is_nil(rows[1].autoAdded)
            -- Pinned now, so it outlives the ten minutes
            clock = 1000 + 3600
            assert.are.equal(1, #TP:CollectRows(db))
        end)

        it("does nothing when an ordinary row is clicked", function()
            assert.is_false(TP:OnRowClick({ factionID = 76 }))
            assert.is_false(TP:OnRowClick(nil))
            assert.are.same({}, TP:GetPinnedFactions())
        end)

        it("gives a temporary row the mouse so it can be clicked", function()
            CastbornDB.locked = true
            assert.is_true(TP:RowWantsMouse({ autoAdded = true }, db))
            CastbornDB.locked = nil
        end)

        it("adds nothing and shows nothing when the option is off", function()
            TP:OnEvent("PLAYER_ENTERING_WORLD")
            gain(76, 25)
            db.trackOnGain = false
            assert.are.equal(0, #TP:CollectRows(db))
            gain(81, 25)
            db.trackOnGain = true
            assert.are.same({ "Orgrimmar" }, names(TP:CollectRows(db)))
        end)
    end)

    describe("session rate", function()
        local now = TP.Now
        local clock

        before_each(function()
            clock = 5000
            TP.Now = function() return clock end
        end)

        after_each(function()
            TP.Now = now
        end)

        local function xp(level, current, max, rested)
            return { level = level, current = current, max = max, rested = rested or 0, maxLevel = 70 }
        end

        it("adds XP gained within a level", function()
            TP:RecordXP(xp(20, 1000, 10000))
            TP:RecordXP(xp(20, 1600, 10000))
            TP:RecordXP(xp(20, 2000, 10000))
            assert.are.equal(1000, TP.session.xpGained)
        end)

        it("counts the rest of the old level and the XP into the new one across a level-up", function()
            TP:RecordXP(xp(20, 9800, 10000))
            TP:RecordXP(xp(21, 300, 11000))
            assert.are.equal(500, TP.session.xpGained)
            TP:RecordXP(xp(21, 900, 11000))
            assert.are.equal(1100, TP.session.xpGained)
        end)

        it("counts a level-up once when UnitLevel lags behind UnitXP", function()
            TP:RecordXP(xp(20, 9800, 10000))
            TP:RecordXP(xp(20, 300, 10000))   -- XP wrapped, level not yet updated
            assert.are.equal(500, TP.session.xpGained)
            TP:RecordXP(xp(20, 300, 10000))   -- still lagging
            TP:RecordXP(xp(21, 300, 11000))   -- level catches up
            assert.are.equal(500, TP.session.xpGained)
            TP:RecordXP(xp(21, 400, 11000))
            assert.are.equal(600, TP.session.xpGained)
        end)

        it("never counts the rested pool", function()
            TP:RecordXP(xp(20, 1000, 10000, 5000))
            TP:RecordXP(xp(20, 1000, 10000, 2000))
            TP:RecordXP(xp(20, 1000, 10000, 9000))
            assert.are.equal(0, TP.session.xpGained)
            -- Rested bonus XP earned shows up in UnitXP, so it counts like any other XP
            TP:RecordXP(xp(20, 1400, 10000, 8800))
            assert.are.equal(400, TP.session.xpGained)
        end)

        it("hides the rate until two minutes of data exist", function()
            TP:RecordXP(xp(20, 1000, 10000))
            TP:RecordXP(xp(20, 2000, 10000))
            clock = 5000 + 119
            assert.is_nil(TP:XPRate())
            clock = 5000 + 120
            assert.are.equal(30000, TP:XPRate())
        end)

        it("hides the rate when no XP has been gained", function()
            TP:RecordXP(xp(20, 1000, 10000))
            clock = 5000 + 600
            assert.is_nil(TP:XPRate())
        end)

        it("shows XP per hour and time to level on the XP row's detail line", function()
            local row = TP:BuildXPRow(xp(20, 2000, 20000), 36000)
            assert.are.equal("36,000 XP/h - 30m to level", row.detail)
            row = TP:BuildXPRow(xp(20, 2000, 20000, 4000), 7200)
            assert.are.equal("Rested 4,000 - 7,200 XP/h - 2h 30m to level", row.detail)
        end)

        it("works out the rate across a level-up", function()
            TP:RecordXP(xp(20, 9000, 10000))
            clock = 5000 + 300
            TP:RecordXP(xp(21, 2000, 12000))
            -- 3,000 XP in five minutes is 36,000 an hour; 10,000 to go is 16m 40s
            assert.are.equal(36000, TP:XPRate())
            assert.are.equal("36,000 XP/h - 16m to level", TP:BuildXPRow(xp(21, 2000, 12000), TP:XPRate()).detail)
        end)

        it("formats durations", function()
            assert.are.equal("<1m", TP:FormatDuration(59))
            assert.are.equal("1m", TP:FormatDuration(60))
            assert.are.equal("59m", TP:FormatDuration(3599))
            assert.are.equal("1h 0m", TP:FormatDuration(3600))
            assert.are.equal("2h 30m", TP:FormatDuration(9000))
            assert.are.equal("99h+", TP:FormatDuration(360000))
        end)

        it("shows reputation gained this session against the first standing seen", function()
            TP:RecordFactionStart(76, 4000)
            TP:RecordFactionStart(76, 4100)
            assert.are.equal(250, TP:SessionRepGain(76, 4250))
            assert.is_nil(TP:SessionRepGain(530, 10000))
            local rep = { factionID = 76, name = "Orgrimmar", reaction = 5, min = 3000, max = 9000, value = 4250 }
            assert.are.equal("4,750 to Honored - +250 this session", TP:BuildReputationRow(rep, 250).detail)
            assert.are.equal("4,750 to Honored - -100 this session", TP:BuildReputationRow(rep, -100).detail)
            assert.are.equal("4,750 to Honored", TP:BuildReputationRow(rep, 0).detail)
        end)

        it("shows the session gain at Exalted, where there is no next standing", function()
            local rep = { factionID = 76, name = "Orgrimmar", reaction = 8, min = 42000, max = 42999, value = 42500 }
            assert.are.equal("+75 this session", TP:BuildReputationRow(rep, 75).detail)
        end)

        it("takes reputation baselines from the login snapshot", function()
            local readKnown = TP.ReadKnownFactions
            TP.ReadKnownFactions = function() return { { id = 76, name = "Orgrimmar", value = 4000 } } end
            TP:TakeFactionSnapshot()
            TP.ReadKnownFactions = readKnown
            assert.are.equal(4000, TP.session.repStart[76])
        end)

        describe("in the rows", function()
            local readXP, readWatched = TP.ReadXP, TP.ReadWatchedFaction
            local current, standing

            before_each(function()
                current, standing = 1000, 4000
                TP.ReadXP = function()
                    return { level = 20, current = current, max = 10000, rested = 0, maxLevel = 70 }
                end
                TP.ReadWatchedFaction = function()
                    return { factionID = 76, name = "Orgrimmar", reaction = 5, min = 3000, max = 9000, value = standing }
                end
            end)

            after_each(function()
                TP.ReadXP = readXP
                TP.ReadWatchedFaction = readWatched
            end)

            it("adds the rate and the session gain once there is data", function()
                local rows = TP:CollectRows(db)
                assert.is_nil(rows[1].detail)
                assert.are.equal("5,000 to Honored", rows[2].detail)
                current, standing = 2000, 4300
                clock = 5000 + 360
                rows = TP:CollectRows(db)
                -- 1,000 XP in six minutes is 10,000 an hour; 8,000 to go is 48 minutes
                assert.are.equal("10,000 XP/h - 48m to level", rows[1].detail)
                assert.are.equal("4,700 to Honored - +300 this session", rows[2].detail)
            end)

            it("leaves both out when the option is off", function()
                TP:CollectRows(db)
                current, standing = 2000, 4300
                clock = 5000 + 360
                db.showSessionRate = false
                local rows = TP:CollectRows(db)
                assert.is_nil(rows[1].detail)
                assert.are.equal("4,700 to Honored", rows[2].detail)
            end)

            it("shows sample rates in test mode", function()
                TP.testModeActive = true
                local rows = TP:CollectRows(db)
                assert.are.equal("Rested 21,300 - 48,200 XP/h - 51m to level", rows[1].detail)
                assert.are.equal("4,704 to Revered - +250 this session", rows[2].detail)
                TP.testModeActive = false
            end)
        end)
    end)

    describe("fade in combat", function()
        after_each(function()
            TP.inCombat = false
            TP.testModeActive = false
        end)

        it("is off by default, so combat changes nothing", function()
            assert.is_false(db.fadeInCombat)
            TP:OnEvent("PLAYER_REGEN_DISABLED")
            assert.are.equal(1, TP:GetPanelAlpha(db))
        end)

        it("lowers the alpha between PLAYER_REGEN_DISABLED and ENABLED", function()
            db.fadeInCombat = true
            assert.are.equal(1, TP:GetPanelAlpha(db))
            TP:OnEvent("PLAYER_REGEN_DISABLED")
            assert.are.equal(TP.COMBAT_ALPHA, TP:GetPanelAlpha(db))
            TP:OnEvent("PLAYER_REGEN_ENABLED")
            assert.are.equal(1, TP:GetPanelAlpha(db))
        end)

        it("stays fully visible in test mode", function()
            db.fadeInCombat = true
            TP:OnEvent("PLAYER_REGEN_DISABLED")
            TP.testModeActive = true
            assert.are.equal(1, TP:GetPanelAlpha(db))
        end)

        it("still applies queued Blizzard bar changes when combat ends", function()
            TP.pendingBlizzardBars = true
            TP:OnEvent("PLAYER_REGEN_ENABLED")
            assert.is_false(TP.pendingBlizzardBars)
        end)
    end)

    describe("collapsed mode", function()
        it("is off by default", function()
            assert.is_false(db.collapsed)
            assert.is_false(db.startCollapsed)
        end)

        it("saves the state the header button sets, so it survives a reload", function()
            TP:ToggleCollapsed()
            assert.is_true(Castborn.db.progress.collapsed)
            -- A reload merges defaults into the saved table, which keeps the state
            local reloaded = Castborn:MergeDefaults(Castborn.db.progress, TP.defaults)
            TP:ApplyStartCollapsed(reloaded)
            assert.is_true(reloaded.collapsed)
            TP:ToggleCollapsed()
            assert.is_false(Castborn.db.progress.collapsed)
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
            Castborn:TestProgressPanel()
            assert.are.equal(mainMenuBar, _G.MainMenuExpBar:GetParent())
            Castborn:EndTestProgressPanel()
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
                    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
                assert.is_true(frame.events[event], event .. " is not registered")
            end
        end)
    end)
end)

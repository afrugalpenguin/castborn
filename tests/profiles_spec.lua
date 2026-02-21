require("tests.mocks.wow_api")
dofile("Castborn/Core.lua")
dofile("Castborn/Systems/Profiles.lua")

describe("Profiles", function()
    local Profiles = Castborn.Profiles

    before_each(function()
        -- Reset state before each test
        _G.CastbornDB = {
            profiles = {},
            profileKeys = {},
        }
    end)

    describe("GetCurrentProfileName", function()
        it("returns Default when no profile set", function()
            CastbornDB.profileKeys = {}
            local name = Profiles:GetCurrentProfileName()
            assert.are.equal("Default", name)
        end)

        it("returns assigned profile for character", function()
            CastbornDB.profileKeys = {
                ["TestPlayer-TestRealm"] = "MyProfile"
            }
            local name = Profiles:GetCurrentProfileName()
            assert.are.equal("MyProfile", name)
        end)
    end)

    describe("GetProfile", function()
        it("returns nil for nonexistent profile", function()
            local profile = Profiles:GetProfile("Nonexistent")
            assert.is_nil(profile)
        end)

        it("returns stored profile data", function()
            CastbornDB.profiles = {
                TestProfile = { setting = "value" }
            }
            local profile = Profiles:GetProfile("TestProfile")
            assert.are.same({ setting = "value" }, profile)
        end)
    end)

    describe("SaveCurrentToProfile", function()
        it("saves current settings to named profile", function()
            CastbornDB.testSetting = "testValue"
            CastbornDB.locked = false
            Profiles:SaveCurrentToProfile("NewProfile")

            local saved = CastbornDB.profiles["NewProfile"]
            assert.is_not_nil(saved)
            assert.are.equal("testValue", saved.testSetting)
            assert.are.equal(false, saved.locked)
        end)

        it("excludes profile metadata from saved profile", function()
            CastbornDB.profiles = { existing = {} }
            CastbornDB.profileKeys = { key = "value" }
            CastbornDB.actualSetting = true
            Profiles:SaveCurrentToProfile("Test")

            local saved = CastbornDB.profiles["Test"]
            assert.is_nil(saved.profiles)
            assert.is_nil(saved.profileKeys)
            assert.is_true(saved.actualSetting)
        end)
    end)

    describe("CreateProfile", function()
        it("creates profile from current settings", function()
            CastbornDB.mySetting = 123
            Profiles:CreateProfile("FromCurrent")

            assert.is_not_nil(CastbornDB.profiles["FromCurrent"])
            assert.are.equal(123, CastbornDB.profiles["FromCurrent"].mySetting)
        end)

        it("copies from existing profile when specified", function()
            CastbornDB.profiles = {
                Source = { copiedSetting = "copied" }
            }
            Profiles:CreateProfile("Destination", "Source")

            assert.are.equal("copied", CastbornDB.profiles["Destination"].copiedSetting)
        end)
    end)

    describe("DeleteProfile", function()
        it("removes the profile", function()
            CastbornDB.profiles = {
                ToDelete = { data = true }
            }
            Profiles:DeleteProfile("ToDelete")
            assert.is_nil(CastbornDB.profiles["ToDelete"])
        end)

        it("does not delete Default profile", function()
            CastbornDB.profiles = {
                Default = { data = true }
            }
            Profiles:DeleteProfile("Default")
            assert.is_not_nil(CastbornDB.profiles["Default"])
        end)

        it("reassigns characters using deleted profile to Default", function()
            CastbornDB.profiles = {
                ToDelete = {}
            }
            CastbornDB.profileKeys = {
                ["Char1-Realm"] = "ToDelete",
                ["Char2-Realm"] = "OtherProfile",
            }
            Profiles:DeleteProfile("ToDelete")

            assert.are.equal("Default", CastbornDB.profileKeys["Char1-Realm"])
            assert.are.equal("OtherProfile", CastbornDB.profileKeys["Char2-Realm"])
        end)
    end)

    describe("GetProfileList", function()
        it("always includes Default first", function()
            CastbornDB.profiles = {}
            local list = Profiles:GetProfileList()
            assert.are.equal("Default", list[1])
        end)

        it("sorts other profiles alphabetically", function()
            CastbornDB.profiles = {
                Zebra = {},
                Alpha = {},
                Default = {},
            }
            local list = Profiles:GetProfileList()
            assert.are.equal("Default", list[1])
            assert.are.equal("Alpha", list[2])
            assert.are.equal("Zebra", list[3])
        end)
    end)

    describe("CopyProfile", function()
        it("copies profile data", function()
            CastbornDB.profiles = {
                Source = { value = 42 }
            }
            Profiles:CopyProfile("Source", "Target")

            assert.are.equal(42, CastbornDB.profiles["Target"].value)
        end)

        it("creates independent copy", function()
            CastbornDB.profiles = {
                Source = { nested = { value = 1 } }
            }
            Profiles:CopyProfile("Source", "Target")

            CastbornDB.profiles["Source"].nested.value = 999
            assert.are.equal(1, CastbornDB.profiles["Target"].nested.value)
        end)

        it("does nothing for nonexistent source", function()
            CastbornDB.profiles = {}
            Profiles:CopyProfile("Nonexistent", "Target")
            assert.is_nil(CastbornDB.profiles["Target"])
        end)
    end)

    describe("Export/Import", function()
        it("exports profile as encoded string", function()
            CastbornDB.profiles = {
                TestExport = { setting = "value" }
            }
            local exported = Profiles:ExportProfile("TestExport")
            assert.is_string(exported)
            assert.is_truthy(exported:match("^CB1:"))
        end)

        it("returns nil for nonexistent profile", function()
            local exported, err = Profiles:ExportProfile("Nonexistent")
            assert.is_nil(exported)
            assert.is_truthy(err)
        end)

        it("imports valid export string", function()
            -- First export a profile
            CastbornDB.profiles = {
                Original = { testKey = "testValue", number = 42 }
            }
            local exported = Profiles:ExportProfile("Original")

            -- Then import to new profile
            local success = Profiles:ImportProfile("Imported", exported)
            assert.is_true(success)
            assert.is_not_nil(CastbornDB.profiles["Imported"])
        end)

        it("rejects invalid format", function()
            local success, err = Profiles:ImportProfile("Test", "invalid data")
            assert.is_false(success)
            assert.is_truthy(err:match("format"))
        end)

        it("rejects empty data", function()
            local success, err = Profiles:ImportProfile("Test", "")
            assert.is_false(success)
        end)

        it("rejects nil data", function()
            local success, err = Profiles:ImportProfile("Test", nil)
            assert.is_false(success)
        end)
    end)
end)

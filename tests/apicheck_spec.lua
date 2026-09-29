require("tests.mocks.wow_api")
_G.SlashCmdList = _G.SlashCmdList or {}
dofile("Core.lua")
dofile("Systems/APICheck_Forever.lua")

describe("APICheck", function()
    local APICheck = Castborn.APICheck

    after_each(function()
        _G.issecretvalue = nil
        _G.C_Test = nil
        _G.UnitCastingInfo = nil
        _G.InCombatLockdown = nil
    end)

    describe("Resolve", function()
        it("finds a namespaced function", function()
            local fn = function() end
            _G.C_Test = { Fn = fn }
            assert.are.equal(fn, APICheck:Resolve("C_Test.Fn"))
        end)

        it("returns nil for a missing namespace", function()
            assert.is_nil(APICheck:Resolve("C_Missing.Fn"))
        end)

        it("returns nil when the path walks through a non-table", function()
            _G.C_Test = { Fn = 5 }
            assert.is_nil(APICheck:Resolve("C_Test.Fn.Deeper"))
        end)
    end)

    describe("Describe", function()
        it("reports plain types", function()
            assert.are.equal("number", APICheck:Describe(1))
            assert.are.equal("nil", APICheck:Describe(nil))
        end)

        it("reports secret values when the client can detect them", function()
            _G.issecretvalue = function(v) return v == "SECRET" end
            assert.are.equal("secret", APICheck:Describe("SECRET"))
            assert.are.equal("string", APICheck:Describe("plain"))
        end)

        it("lists table fields in sorted order", function()
            assert.are.equal("{a=string,b=number}", APICheck:Describe({ b = 1, a = "x" }))
        end)

        it("does not descend into nested tables", function()
            assert.are.equal("{t=table}", APICheck:Describe({ t = { 1 } }))
        end)
    end)

    describe("DescribeCall", function()
        it("reports a missing function", function()
            assert.are.equal("missing", APICheck:DescribeCall("C_Missing.Fn"))
        end)

        it("reports an error without throwing", function()
            _G.C_Test = { Fn = function() error("blocked") end }
            assert.is_truthy(APICheck:DescribeCall("C_Test.Fn"):match("^error: "))
        end)

        it("keeps nils in the middle of multiple returns", function()
            _G.C_Test = { Fn = function() return 1, nil, "s" end }
            assert.are.equal("number nil string", APICheck:DescribeCall("C_Test.Fn"))
        end)

        it("reports a call with no returns", function()
            _G.C_Test = { Fn = function() end }
            assert.are.equal("(no returns)", APICheck:DescribeCall("C_Test.Fn"))
        end)

        it("passes arguments through", function()
            _G.C_Test = { Fn = function(unit) return unit == "player" and 1 or nil end }
            assert.are.equal("number", APICheck:DescribeCall("C_Test.Fn", "player"))
        end)
    end)

    describe("Run", function()
        before_each(function()
            _G.CastbornDB = {}
        end)

        it("saves the report to CastbornDB", function()
            local report = APICheck:Run()
            assert.are.equal(report, CastbornDB.apicheck)
        end)

        it("marks missing APIs", function()
            local report = APICheck:Run()
            assert.are.equal("missing", report.names["UnitCastingInfo"])
        end)

        it("describes live probe results", function()
            _G.UnitCastingInfo = function() return "Fireball", "", 1 end
            local report = APICheck:Run()
            assert.are.equal("function", report.names["UnitCastingInfo"])
            assert.are.equal("string string number", report.live["UnitCastingInfo(player)"])
        end)

        it("snapshots cast info when a cast starts", function()
            _G.UnitCastingInfo = function() return "Fireball" end
            APICheck:OnEvent("UNIT_SPELLCAST_START", "player")
            assert.are.equal("string", APICheck:Run().events["UnitCastingInfo(player)"])
        end)

        it("keeps in-combat snapshots separate", function()
            _G.UnitCastingInfo = function() return "Fireball" end
            _G.InCombatLockdown = function() return true end
            APICheck:OnEvent("UNIT_SPELLCAST_START", "player")
            assert.are.equal("string", APICheck:Run().events["UnitCastingInfo(player) [combat]"])
        end)

        it("counts combat log events", function()
            local before = APICheck.cleu.count
            APICheck:OnEvent("COMBAT_LOG_EVENT_UNFILTERED")
            assert.are.equal(before + 1, APICheck:Run().cleu.count)
        end)
    end)
end)

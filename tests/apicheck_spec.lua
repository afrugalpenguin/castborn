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
        _G.C_UnitAuras = nil
        _G.C_Spell = nil
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

    describe("DescribeValues", function()
        it("keeps nils in position", function()
            assert.are.equal("number nil", APICheck:DescribeValues(1, nil))
        end)

        it("reports no values", function()
            assert.are.equal("(no returns)", APICheck:DescribeValues())
        end)
    end)

    describe("DescribeDuration", function()
        after_each(function() _G.UnitCastingDuration = nil end)

        it("reports a missing API", function()
            assert.are.equal("missing", APICheck:DescribeDuration("UnitCastingDuration", "target"))
        end)

        it("lists methods and formats the remaining time", function()
            local methods = { GetRemainingDuration = function() return 1.5 end }
            _G.UnitCastingDuration = function() return setmetatable({}, { __index = methods }) end
            assert.are.equal("type=table methods=GetRemainingDuration remaining=number format=ok",
                APICheck:DescribeDuration("UnitCastingDuration", "target"))
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

        it("keeps out-of-combat and in-combat runs", function()
            _G.UnitCastingInfo = function() return "Fireball" end
            APICheck:Run()
            _G.InCombatLockdown = function() return true end
            local report = APICheck:Run()
            assert.are.equal("string", report.live["UnitCastingInfo(player)"])
            assert.are.equal("string", report.live["UnitCastingInfo(player) [combat]"])
        end)

        it("skips aura probes in combat", function()
            local calls = 0
            _G.C_UnitAuras = { GetAuraDataByIndex = function() calls = calls + 1 end }
            _G.InCombatLockdown = function() return true end
            local report = APICheck:Run()
            assert.are.equal("skipped in combat", report.live["C_UnitAuras.GetAuraDataByIndex(player,1,HELPFUL) [combat]"])
            assert.are.equal(0, calls)
        end)

        it("does not read auras on UNIT_AURA in combat", function()
            local calls = 0
            _G.C_UnitAuras = { GetAuraDataByIndex = function() calls = calls + 1 end }
            _G.InCombatLockdown = function() return true end
            APICheck:OnEvent("UNIT_AURA", "target")
            assert.are.equal(0, calls)
        end)

        it("counts events", function()
            local before = APICheck.eventCounts.UNIT_AURA or 0
            APICheck:OnEvent("UNIT_AURA", "player")
            assert.are.equal(before + 1, APICheck:Run().eventCounts.UNIT_AURA)
        end)

        it("records the cast payload", function()
            APICheck:OnEvent("UNIT_SPELLCAST_START", "target", "guid", 133)
            assert.are.equal("string number", APICheck:Run().events["UNIT_SPELLCAST_START(target) payload"])
        end)

        it("records the cooldown of the spell just cast", function()
            _G.C_Spell = { GetSpellCooldown = function(id) if id == 100 then return { startTime = 1 } end end }
            APICheck:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 100)
            assert.are.equal("{startTime=number}", APICheck:Run().events["C_Spell.GetSpellCooldown(last cast)"])
        end)

        it("describes the fields of listed values", function()
            _G.Enum = { StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 } }
            local report = APICheck:Run()
            assert.are.equal("{ElapsedTime=number,RemainingTime=number}",
                report.values["Enum.StatusBarTimerDirection"])
            assert.are.equal("missing", report.values["Enum.StatusBarInterpolation"])
            _G.Enum = nil
        end)

        it("probes target cast durations and unit identity", function()
            local report = APICheck:Run()
            assert.are.equal("missing", report.live["UnitCastingDuration(target)"])
            assert.are.equal("missing", report.live["UnitIsUnit(target,player)"])
        end)

        it("checks SetAlphaFromBoolean on textures", function()
            assert.is_not_nil(APICheck:Run().widgets["Texture:SetAlphaFromBoolean"])
        end)

        it("snapshots the target cast duration", function()
            _G.UnitCastingDuration = function() return setmetatable({}, { __index = {} }) end
            APICheck:OnEvent("UNIT_SPELLCAST_START", "target")
            assert.are.equal("type=table methods= remaining=n/a format=n/a",
                APICheck:Run().events["UnitCastingDuration(target) object"])
            _G.UnitCastingDuration = nil
        end)

        it("describes the first added aura from the payload in combat", function()
            _G.InCombatLockdown = function() return true end
            APICheck:OnEvent("UNIT_AURA", "player", { addedAuras = { { spellId = 1, auraInstanceID = 2 } } })
            assert.are.equal("{auraInstanceID=number,spellId=number}",
                APICheck:Run().events["UNIT_AURA(player) addedAura [combat]"])
        end)

        it("records whether the player's cast spell ID is secret", function()
            _G.InCombatLockdown = function() return true end
            APICheck:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20154)
            assert.are.equal("number",
                APICheck:Run().events["UNIT_SPELLCAST_SUCCEEDED(player) spellID [combat]"])
        end)

        it("counts each player UNIT_AURA payload shape in combat", function()
            _G.InCombatLockdown = function() return true end
            local key = "UNIT_AURA(player) payload {isFullUpdate=boolean} [combat]"
            local before = APICheck.events[key] or 0
            APICheck:OnEvent("UNIT_AURA", "player", { isFullUpdate = true })
            APICheck:OnEvent("UNIT_AURA", "player", { isFullUpdate = true })
            assert.are.equal(before + 2, APICheck:Run().events[key])
        end)

        it("does not index a secret addedAuras list", function()
            local secretList = setmetatable({}, { __index = function() error("indexed a secret") end })
            _G.issecretvalue = function(v) return v == secretList end
            _G.InCombatLockdown = function() return true end
            assert.has_no.errors(function()
                APICheck:OnEvent("UNIT_AURA", "player", { addedAuras = secretList })
            end)
            _G.issecretvalue = nil
        end)

        it("tries the aura duration API once per combat", function()
            local calls = 0
            _G.C_UnitAuras = { GetAuraDuration = function() calls = calls + 1 end }
            _G.InCombatLockdown = function() return true end
            APICheck.auraDurationTried = nil
            local info = { addedAuras = { { auraInstanceID = 2 } } }
            APICheck:OnEvent("UNIT_AURA", "player", info)
            APICheck:OnEvent("UNIT_AURA", "player", info)
            assert.are.equal(1, calls)
        end)

        it("allows another aura duration attempt after combat ends", function()
            APICheck.auraDurationTried = true
            APICheck:OnEvent("PLAYER_REGEN_ENABLED")
            assert.is_nil(APICheck.auraDurationTried)
        end)
    end)
end)

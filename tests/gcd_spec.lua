require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/GCDIndicator.lua")

describe("GCD seams (TBC behaviour)", function()
    local CB = Castborn
    local cfg
    local originalGetTime, originalUnitClass

    local function fakeFrame()
        local f = { bar = {}, spark = {} }
        f.bar.SetWidth = function(_, w) f.barWidth = w end
        f.bar.SetVertexColor = function() end
        f.spark.SetPoint = function() end
        f.spark.Show = function() end
        f.spark.Hide = function() end
        f.pulse = { SetAlpha = function() end }
        f.GetWidth = function() return 102 end
        f.Show = function() f.shown = true end
        f.Hide = function() f.shown = false end
        return f
    end

    before_each(function()
        originalGetTime = _G.GetTime
        originalUnitClass = _G.UnitClass
        cfg = { enabled = true, barColor = { 1, 1, 1, 1 }, readyColor = { 0, 1, 0, 1 } }
        CB.db = { gcd = cfg }
        CB.gcdFrame = fakeFrame()
        _G.UnitClass = function() return "Paladin", "PALADIN" end
        _G.GetTime = function() return 100 end
    end)

    after_each(function()
        _G.GetSpellCooldown = nil
        _G.GetTime = originalGetTime
        _G.UnitClass = originalUnitClass
    end)

    it("lists a GCD test spell per class", function()
        assert.are.equal("Holy Light", CB.GCDIndicator.testSpells.PALADIN)
    end)

    it("starts the sweep from the spell cooldown and draws progress", function()
        _G.GetSpellCooldown = function() return 99.5, 1.5 end
        CB:CheckGCD()
        CB:UpdateGCDBar(CB.gcdFrame, cfg)
        assert.is_true(CB.gcdFrame.shown)
        assert.is_near(100 * (0.5 / 1.5), CB.gcdFrame.barWidth, 1e-9)
    end)

    it("ignores a cooldown that has already run out", function()
        -- The module keeps GCD state in file locals, so move time past any earlier sweep
        _G.GetTime = function() return 200 end
        _G.GetSpellCooldown = function() return 190, 1.5 end
        CB:CheckGCD()
        CB:UpdateGCDBar(CB.gcdFrame, cfg)
        assert.is_not_true(CB.gcdFrame.shown)
    end)
end)

describe("GCD anchoring", function()
    local CB = Castborn
    local GCD = Castborn.GCDIndicator
    local anchoredTo, castbarReattaches, fsrReattaches
    local realAnchoring, realDB, realInfo, realFSR

    local function sized(width)
        local w = width
        return {
            GetWidth = function() return w end,
            SetWidth = function(self, v) w = v end,
        }
    end

    before_each(function()
        anchoredTo, castbarReattaches, fsrReattaches = nil, 0, 0
        realAnchoring, realDB, realInfo, realFSR = CB.Anchoring, _G.CastbornDB, CB.playerInfo, CB.FiveSecondRule
        CB.playerInfo = { class = "WARRIOR" }
        CB.Anchoring = {
            Anchor = function(_, frame, parent, position, x, y)
                anchoredTo = { parent = parent, position = position, x = x, y = y }
            end,
            ReattachToCastbar = function(_, frame, db, position, offsetY, sync)
                castbarReattaches = castbarReattaches + 1
                db.anchored = true
                return true
            end,
            DetachFromCastbar = function(_, frame, db) db.anchored = false end,
            GetCastbarBarWidth = function() return 240 end,
        }
        CB.FiveSecondRule = { Reattach = function() fsrReattaches = fsrReattaches + 1 end }
        _G.CastbornDB = { gcd = { enabled = true, anchored = true }, fsr = { anchored = true } }
        CB.gcdFrame = sized(250)
        CB.swingTimers = { mainhand = sized(180), container = sized(300) }
    end)

    after_each(function()
        CB.Anchoring, _G.CastbornDB, CB.playerInfo, CB.FiveSecondRule = realAnchoring, realDB, realInfo, realFSR
        CB.gcdFrame = nil
        CB.swingTimers = {}
    end)

    it("sits below the castbar by default", function()
        assert.is_false(GCD:AnchorsToSwing())
        GCD:Reattach()
        assert.are.equal(1, castbarReattaches)
        assert.is_nil(anchoredTo)
    end)

    it("sits directly above the main-hand swing bar when chosen", function()
        GCD:SetAnchorsToSwing(true)
        GCD:Reattach()
        assert.are.equal(CB.swingTimers.mainhand, anchoredTo.parent)
        assert.are.equal("TOP", anchoredTo.position)
        assert.are.equal(0, castbarReattaches)
        assert.is_true(CastbornDB.gcd.anchored)
    end)

    it("saves the choice per class", function()
        GCD:SetAnchorsToSwing(true)
        CB.playerInfo = { class = "MAGE" }
        assert.is_false(GCD:AnchorsToSwing())
        CB.playerInfo = { class = "WARRIOR" }
        assert.is_true(GCD:AnchorsToSwing())
    end)

    it("matches the swing bar's width, and follows it when resized", function()
        GCD:SetAnchorsToSwing(true)
        GCD:Reattach()
        assert.are.equal(180, CB.gcdFrame:GetWidth())
        CB.swingTimers.mainhand:SetWidth(220)
        CB:FireCallback("SWING_RESIZED")
        assert.are.equal(220, CB.gcdFrame:GetWidth())
    end)

    it("falls back to the castbar when there is no swing timer", function()
        GCD:SetAnchorsToSwing(true)
        CB.swingTimers = {}
        GCD:Reattach()
        assert.are.equal(1, castbarReattaches)
    end)

    it("reattaches to the swing timer from the options toggle", function()
        GCD:SetAnchorsToSwing(true)
        CB:FireCallback("REATTACH_GCD")
        assert.are.equal(CB.swingTimers.mainhand, anchoredTo.parent)
    end)

    it("moves above the swing timer once it exists at login", function()
        GCD:SetAnchorsToSwing(true)
        CB:FireCallback("READY")
        assert.are.equal(CB.swingTimers.mainhand, anchoredTo.parent)
    end)

    it("stays put at login when detached", function()
        GCD:SetAnchorsToSwing(true)
        CastbornDB.gcd.anchored = false
        CB:FireCallback("READY")
        assert.is_nil(anchoredTo)
    end)

    it("moves the 5 Second Rule along when it is reattached or detached", function()
        GCD:SetAnchorsToSwing(true)
        CB:FireCallback("REATTACH_GCD")
        assert.are.equal(1, fsrReattaches)
        CB:FireCallback("DETACH_GCD")
        assert.are.equal(2, fsrReattaches)
    end)

    it("leaves a detached 5 Second Rule alone", function()
        CastbornDB.fsr.anchored = false
        GCD:SetAnchorsToSwing(true)
        CB:FireCallback("REATTACH_GCD")
        assert.are.equal(0, fsrReattaches)
    end)

    describe("FrameOnSwing", function()
        it("is the GCD bar when it is anchored to the swing timer", function()
            GCD:SetAnchorsToSwing(true)
            assert.are.equal(CB.gcdFrame, GCD:FrameOnSwing())
        end)

        it("is nil when the bar is on the castbar", function()
            assert.is_nil(GCD:FrameOnSwing())
        end)

        it("is nil when the bar is detached", function()
            GCD:SetAnchorsToSwing(true)
            CastbornDB.gcd.anchored = false
            assert.is_nil(GCD:FrameOnSwing())
        end)

        it("is nil when the GCD indicator is turned off", function()
            GCD:SetAnchorsToSwing(true)
            CastbornDB.gcd.enabled = false
            assert.is_nil(GCD:FrameOnSwing())
        end)

        it("is nil when there is no swing timer", function()
            GCD:SetAnchorsToSwing(true)
            CB.swingTimers = {}
            assert.is_nil(GCD:FrameOnSwing())
        end)
    end)
end)

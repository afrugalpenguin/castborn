require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/FiveSecondRule.lua")

-- Pins the TBC mana-spend detection behind the seam the Forever build overrides
describe("Five second rule on TBC", function()
    local FSR = Castborn.FiveSecondRule
    local realMark = FSR.MarkManaSpent
    local mana, registered, marked

    local function fakeFrame()
        return { RegisterEvent = function(_, event) registered[#registered + 1] = event end }
    end

    before_each(function()
        mana, registered, marked = 1000, {}, 0
        _G.UnitPower = function() return mana end
        FSR.MarkManaSpent = function() marked = marked + 1 end
        FSR:RegisterEvents(fakeFrame())
    end)

    after_each(function()
        _G.UnitPower = nil
        FSR.MarkManaSpent = realMark
    end)

    it("listens for mana changes", function()
        assert.are.same({ "UNIT_POWER_UPDATE", "UNIT_SPELLCAST_SUCCEEDED" }, registered)
    end)

    it("starts the timer when mana falls", function()
        mana = 900
        FSR:OnPlayerEvent("UNIT_POWER_UPDATE", "MANA")
        assert.are.equal(1, marked)
    end)

    it("ignores mana rising", function()
        mana = 1100
        FSR:OnPlayerEvent("UNIT_POWER_UPDATE", "MANA")
        assert.are.equal(0, marked)
    end)

    it("ignores a one-point drop", function()
        mana = 999
        FSR:OnPlayerEvent("UNIT_POWER_UPDATE", "MANA")
        assert.are.equal(0, marked)
    end)

    it("ignores other power types", function()
        mana = 900
        FSR:OnPlayerEvent("UNIT_POWER_UPDATE", "RAGE")
        assert.are.equal(0, marked)
    end)
end)

describe("Five second rule anchoring", function()
    local FSR = Castborn.FiveSecondRule
    local CB = Castborn
    local anchoredTo, castbarReattaches, realAnchoring, realDB

    local function sized(width)
        local w = width
        return {
            GetWidth = function() return w end,
            SetWidth = function(self, v) w = v end,
        }
    end

    before_each(function()
        anchoredTo, castbarReattaches = nil, 0
        realAnchoring, realDB = Castborn.Anchoring, _G.CastbornDB
        Castborn.Anchoring = {
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
        _G.CastbornDB = { fsr = { anchored = true }, swing = { width = 180 } }
        CB.fsrFrame = sized(250)
        CB.swingTimers = { mainhand = sized(180), container = sized(300) }
    end)

    after_each(function()
        Castborn.Anchoring, _G.CastbornDB = realAnchoring, realDB
        CB.fsrFrame = nil
        CB.swingTimers = {}
    end)

    it("sits above the castbar by default", function()
        FSR:Reattach()
        assert.are.equal(1, castbarReattaches)
        assert.is_nil(anchoredTo)
    end)

    it("sits above the main-hand swing bar when chosen", function()
        CastbornDB.fsr.anchorToSwing = true
        FSR:Reattach()
        assert.are.equal(CB.swingTimers.mainhand, anchoredTo.parent)
        assert.are.equal("TOP", anchoredTo.position)
        assert.are.equal(0, castbarReattaches)
        assert.is_true(CastbornDB.fsr.anchored)
    end)

    it("matches the swing bar's width above the swing timer", function()
        CastbornDB.fsr.anchorToSwing = true
        FSR:Reattach()
        assert.are.equal(180, CB.fsrFrame:GetWidth())
    end)

    it("follows the swing bar when it is resized", function()
        CastbornDB.fsr.anchorToSwing = true
        FSR:Reattach()
        CB.swingTimers.mainhand:SetWidth(220)
        CB:FireCallback("SWING_RESIZED")
        assert.are.equal(220, CB.fsrFrame:GetWidth())
    end)

    it("falls back to the castbar when there is no swing timer", function()
        CastbornDB.fsr.anchorToSwing = true
        CB.swingTimers = {}
        FSR:Reattach()
        assert.are.equal(1, castbarReattaches)
    end)

    it("reattaches to the swing timer from the options toggle", function()
        CastbornDB.fsr.anchorToSwing = true
        CB:FireCallback("REATTACH_FSR")
        assert.are.equal(CB.swingTimers.mainhand, anchoredTo.parent)
    end)

    it("moves above the swing timer once it exists at login", function()
        CastbornDB.fsr.anchorToSwing = true
        CB:FireCallback("READY")
        assert.are.equal(CB.swingTimers.mainhand, anchoredTo.parent)
    end)

    it("stays put at login when detached", function()
        CastbornDB.fsr.anchorToSwing = true
        CastbornDB.fsr.anchored = false
        CB:FireCallback("READY")
        assert.is_nil(anchoredTo)
    end)
end)

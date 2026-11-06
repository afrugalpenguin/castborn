require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/CastBars.lua")

local function fakeBar()
    local bar = { calls = {} }
    bar.SetMinMaxValues = function(_, a, b) bar.calls[#bar.calls + 1] = { "SetMinMaxValues", a, b } end
    bar.SetValue = function(_, v) bar.calls[#bar.calls + 1] = { "SetValue", v } end
    bar.GetWidth = function() return 200 end
    return bar
end

describe("CastBars seams (TBC behaviour)", function()
    local CB = Castborn

    describe("SetCastTiming", function()
        it("stores millisecond times as seconds", function()
            local frame = {}
            CB:SetCastTiming(frame, "player", false, 10000, 12500)
            assert.are.equal(10, frame.startTime)
            assert.are.equal(12.5, frame.endTime)
        end)
    end)

    describe("StartCastBar", function()
        it("starts a cast empty", function()
            local frame = { bar = fakeBar() }
            CB:StartCastBar(frame, false)
            assert.are.same({ { "SetMinMaxValues", 0, 1 }, { "SetValue", 0 } }, frame.bar.calls)
        end)

        it("starts a channel full", function()
            local frame = { bar = fakeBar() }
            CB:StartCastBar(frame, true)
            assert.are.same({ "SetValue", 1 }, frame.bar.calls[2])
        end)
    end)

    describe("UpdateCastProgress", function()
        local function fakeFrame(channeling)
            local text = { shown = false }
            text.SetText = function(_, t) text.value = t end
            text.Show = function() text.shown = true end
            text.Hide = function() text.shown = false end
            local spark = { Show = function() end, SetPoint = function() end }
            return { bar = fakeBar(), spark = spark, timeText = text,
                     startTime = 10, endTime = 12, channeling = channeling }
        end

        it("fills a cast with elapsed time and shows remaining", function()
            local frame = fakeFrame(false)
            local done = CB:UpdateCastProgress(frame, 11, { showTime = true })
            assert.are.same({ "SetValue", 0.5 }, frame.bar.calls[1])
            assert.are.equal("1.0", frame.timeText.value)
            assert.is_false(done)
        end)

        it("drains a channel", function()
            local frame = fakeFrame(true)
            CB:UpdateCastProgress(frame, 11.5, { showTime = false })
            assert.are.same({ "SetValue", 0.25 }, frame.bar.calls[1])
            assert.is_false(frame.timeText.shown)
        end)

        it("reports completion at the end time", function()
            assert.is_true(CB:UpdateCastProgress(fakeFrame(false), 12, { showTime = true }))
        end)
    end)

    describe("GetCastDisplayName", function()
        -- The mock does not define these, so clearing them restores its state
        after_each(function() _G.GetSpellSubtext = nil; _G.GetSpellInfo = nil end)

        it("prefers the cast text over the name", function()
            assert.are.equal("Text", CB:GetCastDisplayName("Name", "Text", nil, {}))
        end)

        it("appends a numeric rank as Rank N", function()
            _G.GetSpellSubtext = function() return "3" end
            assert.are.equal("Frostbolt (Rank 3)",
                CB:GetCastDisplayName("Frostbolt", nil, 116, { showSpellRank = true }))
        end)

        it("falls back to GetSpellInfo's rank", function()
            _G.GetSpellSubtext = function() return "" end
            _G.GetSpellInfo = function() return "Frostbolt", "Rank 2" end
            assert.are.equal("Frostbolt (Rank 2)",
                CB:GetCastDisplayName("Frostbolt", nil, 116, { showSpellRank = true }))
        end)
    end)

    describe("ApplyInterruptShield", function()
        local function frameWithShield()
            local f = { shield = {}, bar = {} }
            f.shield.Show = function() f.shield.shown = true end
            f.shield.Hide = function() f.shield.shown = false end
            f.bar.SetStatusBarColor = function(_, r) f.bar.r = r end
            return f
        end

        it("shows the shield and dims the bar for uninterruptible casts", function()
            local f = frameWithShield()
            CB:ApplyInterruptShield(f, true, { 1, 1, 1, 1 })
            assert.is_true(f.shield.shown)
            assert.are.equal(0.6, f.bar.r)
        end)

        it("hides the shield for interruptible casts", function()
            local f = frameWithShield()
            CB:ApplyInterruptShield(f, false, { 1, 1, 1, 1 })
            assert.is_false(f.shield.shown)
        end)

        it("does nothing without a shield", function()
            assert.has_no.errors(function() CB:ApplyInterruptShield({}, true, { 1, 1, 1, 1 }) end)
        end)
    end)

    describe("GetLatencyWidth", function()
        -- The mock does not define GetNetStats, so clearing it restores its state
        after_each(function() _G.GetNetStats = nil end)

        it("scales latency to the cast length, capped at half the bar", function()
            _G.GetNetStats = function() return 0, 0, 100, 100 end
            local frame = { bar = fakeBar(), startTime = 10, endTime = 12 }
            assert.are.equal(20, CB:GetLatencyWidth(frame))
            frame.endTime = 10.2
            assert.are.equal(100, CB:GetLatencyWidth(frame))
        end)
    end)

    describe("IsHiddenTradeSkill", function()
        it("hides tradeskill casts only when the option is on", function()
            assert.is_truthy(CB:IsHiddenTradeSkill(true, { hideTradeSkills = true }))
            assert.is_falsy(CB:IsHiddenTradeSkill(true, { hideTradeSkills = false }))
            assert.is_falsy(CB:IsHiddenTradeSkill(false, { hideTradeSkills = true }))
        end)
    end)
end)

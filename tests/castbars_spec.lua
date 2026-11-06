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
end)

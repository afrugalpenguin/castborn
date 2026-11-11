require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/CastBars.lua")
dofile("Modules/SwingTimer.lua")
dofile("Modules/GCDIndicator.lua")
dofile("Modules/FiveSecondRule.lua")
dofile("Modules/InterruptTracker.lua")

-- A frame built like CreateBackdrop's, whose background remembers its colour
local function backdropFrame()
    local bg = {}
    function bg:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    return { bg = bg, _bgColor = { 0, 0, 0, 1 } }
end

describe("Background colour pickers", function()
    local CB = Castborn

    local function colour(r) return { r, r, r, 0.5 } end

    before_each(function()
        _G.CastbornDB = {
            player = { bgColor = colour(0.1) }, target = { bgColor = colour(0.2) },
            swing = { bgColor = colour(0.3) }, gcd = { bgColor = colour(0.4) },
            fsr = { bgColor = colour(0.5) }, interrupt = { bgColor = colour(0.6) },
        }
        CB.db = _G.CastbornDB
        CB.castbars = {}
        CB.swingTimers = {}
        CB.gcdFrame, CB.fsrFrame = nil, nil
        _G.Castborn_Interrupt = nil
        CB.InterruptTracker.attachedIcons.target = nil
        CB.InterruptTracker.attachedIcons.focus = nil
    end)

    -- A picker saves a new colour table, then announces which module changed
    local function pick(key, value)
        CastbornDB[key].bgColor = value
        CB:FireCallback("BACKGROUND_CHANGED", key)
    end

    it("paints a backdrop and remembers the colour it was given", function()
        local f = backdropFrame()
        local c = colour(0.7)
        CB:PaintBackdrop(f, c)
        assert.are.same(c, f.bg.color)
        assert.are.equal(c, f._bgColor)
    end)

    it("repaints only the castbar whose picker changed, with its icon", function()
        local player, target = backdropFrame(), backdropFrame()
        player.iconFrame = backdropFrame()
        CB.castbars.player, CB.castbars.target = player, target
        pick("player", colour(0.8))
        assert.are.same(colour(0.8), player.bg.color)
        assert.are.same(colour(0.8), player.iconFrame.bg.color)
        assert.is_nil(target.bg.color)
    end)

    it("repaints all three swing bars", function()
        for _, k in ipairs({ "mainhand", "offhand", "ranged" }) do CB.swingTimers[k] = backdropFrame() end
        pick("swing", colour(0.8))
        for _, k in ipairs({ "mainhand", "offhand", "ranged" }) do
            assert.are.same(colour(0.8), CB.swingTimers[k].bg.color, k)
        end
    end)

    it("repaints the GCD bar", function()
        CB.gcdFrame = backdropFrame()
        pick("gcd", colour(0.8))
        assert.are.same(colour(0.8), CB.gcdFrame.bg.color)
    end)

    it("repaints the 5-second rule bar", function()
        CB.fsrFrame = backdropFrame()
        pick("fsr", colour(0.8))
        assert.are.same(colour(0.8), CB.fsrFrame.bg.color)
    end)

    it("repaints the interrupt tracker", function()
        _G.Castborn_Interrupt = backdropFrame()
        pick("interrupt", colour(0.8))
        assert.are.same(colour(0.8), _G.Castborn_Interrupt.bg.color)
    end)

    it("repaints an interrupt icon with the castbar it is attached to", function()
        local icon = backdropFrame()
        CB.InterruptTracker.attachedIcons.target = icon
        pick("target", colour(0.8))
        assert.are.same(colour(0.8), icon.bg.color)
    end)

    it("leaves other modules alone", function()
        CB.gcdFrame, CB.fsrFrame = backdropFrame(), backdropFrame()
        pick("gcd", colour(0.8))
        assert.is_nil(CB.fsrFrame.bg.color)
    end)

    it("keeps the new colour when backgrounds are refreshed afterwards", function()
        local player = backdropFrame()
        CB.castbars.player = player
        table.insert(CB._backdropFrames, player)
        pick("player", colour(0.8))
        CB:RefreshBackgrounds()
        assert.are.same(colour(0.8), player.bg.color)
    end)

    it("does nothing before the frames exist", function()
        assert.has_no.errors(function()
            for _, key in ipairs({ "player", "swing", "gcd", "fsr", "interrupt", "target" }) do
                pick(key, colour(0.8))
            end
        end)
    end)
end)

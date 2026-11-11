require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/CooldownGroup.lua")

describe("CooldownGroup.GetSlotAnchor", function()
    local GetSlotAnchor = Castborn.CooldownGroup.GetSlotAnchor

    local function settings(grow, orientation)
        return { iconSize = 30, spacing = 2, iconsPerRow = 3, growDirection = grow, orientation = orientation }
    end

    local function anchor(slot, s, grow)
        return { GetSlotAnchor(slot, s, grow) }
    end

    it("grows left from the top right", function()
        local s = settings("LEFT", "HORIZONTAL")
        assert.are.same({ "TOPRIGHT", "TOPRIGHT", 0, 0 }, anchor(1, s))
        assert.are.same({ "TOPRIGHT", "TOPRIGHT", -64, 0 }, anchor(3, s))
        assert.are.same({ "TOPRIGHT", "TOPRIGHT", 0, -32 }, anchor(4, s))
    end)

    it("grows right from the top left", function()
        local s = settings("RIGHT", "HORIZONTAL")
        assert.are.same({ "TOPLEFT", "TOPLEFT", 64, 0 }, anchor(3, s))
        assert.are.same({ "TOPLEFT", "TOPLEFT", 32, -32 }, anchor(5, s))
    end)

    it("grows up from the bottom left, with rows going upwards", function()
        local s = settings("UP", "HORIZONTAL")
        assert.are.same({ "BOTTOMLEFT", "BOTTOMLEFT", 64, 0 }, anchor(3, s))
        assert.are.same({ "BOTTOMLEFT", "BOTTOMLEFT", 32, 32 }, anchor(5, s))
    end)

    it("places DOWN exactly like RIGHT", function()
        for slot = 1, 7 do
            assert.are.same(anchor(slot, settings("RIGHT", "HORIZONTAL")), anchor(slot, settings("DOWN", "HORIZONTAL")))
            assert.are.same(anchor(slot, settings("RIGHT", "VERTICAL")), anchor(slot, settings("DOWN", "VERTICAL")))
        end
    end)

    it("fills columns first when vertical", function()
        local s = settings("RIGHT", "VERTICAL")
        assert.are.same({ "TOPLEFT", "TOPLEFT", 0, -64 }, anchor(3, s))
        assert.are.same({ "TOPLEFT", "TOPLEFT", 32, 0 }, anchor(4, s))
        assert.are.same({ "TOPLEFT", "TOPLEFT", 64, -32 }, anchor(8, s))
    end)

    it("falls through to the top left for a missing or unknown direction", function()
        assert.are.same({ "TOPLEFT", "TOPLEFT", 32, 0 }, anchor(2, settings(nil, "HORIZONTAL")))
        assert.are.same({ "TOPLEFT", "TOPLEFT", 32, 0 }, anchor(2, settings("CENTER", "HORIZONTAL")))
    end)

    it("takes an explicit direction over the settings", function()
        assert.are.same({ "TOPRIGHT", "TOPRIGHT", -32, 0 }, anchor(2, settings("RIGHT", "HORIZONTAL"), "LEFT"))
    end)

    it("uses 36px icons, 4px spacing and 10 per row when unset", function()
        assert.are.same({ "TOPLEFT", "TOPLEFT", 40, 0 }, anchor(2, {}))
        assert.are.same({ "TOPLEFT", "TOPLEFT", 0, -40 }, anchor(11, {}))
    end)
end)

describe("CooldownGroup.GetContainerSize", function()
    local GetContainerSize = Castborn.CooldownGroup.GetContainerSize
    local s = { iconSize = 30, spacing = 2, iconsPerRow = 3 }

    it("fits one partial row", function()
        assert.are.same({ 62, 34 }, { GetContainerSize(2, s) })
    end)

    it("wraps rows when horizontal", function()
        assert.are.same({ 94, 66 }, { GetContainerSize(5, s) })
    end)

    it("wraps columns when vertical", function()
        s.orientation = "VERTICAL"
        assert.are.same({ 62, 98 }, { GetContainerSize(5, s) })
        s.orientation = nil
    end)
end)

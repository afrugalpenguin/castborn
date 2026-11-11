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

describe("CooldownGroup.GetSlotAtPoint", function()
    local GetSlotAnchor = Castborn.CooldownGroup.GetSlotAnchor
    local GetSlotAtPoint = Castborn.CooldownGroup.GetSlotAtPoint
    local LEFT, RIGHT, TOP, BOTTOM = 0, 200, 200, 0

    local function settings(grow, orientation)
        return { iconSize = 30, spacing = 2, iconsPerRow = 3, growDirection = grow, orientation = orientation }
    end

    -- The centre of a slot, from where GetSlotAnchor places it in a container with these edges
    local function centre(slot, s)
        local point, _, x, y = GetSlotAnchor(slot, s)
        if point == "TOPRIGHT" then return RIGHT + x - 15, TOP + y - 15 end
        if point == "BOTTOMLEFT" then return LEFT + x + 15, BOTTOM + y + 15 end
        return LEFT + x + 15, TOP + y - 15
    end

    for _, orientation in ipairs({ "HORIZONTAL", "VERTICAL" }) do
        for _, grow in ipairs({ "LEFT", "RIGHT", "UP", "DOWN" }) do
            it("finds every slot from its centre, " .. orientation .. " growing " .. grow, function()
                local s = settings(grow, orientation)
                for slot = 1, 8 do
                    local x, y = centre(slot, s)
                    assert.are.equal(slot, GetSlotAtPoint(s, x, y, LEFT, RIGHT, TOP, BOTTOM), "slot " .. slot)
                end
            end)
        end
    end

    it("counts a point past the middle of a slot along the row as the next slot", function()
        local s = settings("RIGHT", "HORIZONTAL")
        assert.are.equal(1, GetSlotAtPoint(s, 15, 185, LEFT, RIGHT, TOP, BOTTOM))
        assert.are.equal(2, GetSlotAtPoint(s, 17, 185, LEFT, RIGHT, TOP, BOTTOM))
    end)

    it("does the same down a column when vertical", function()
        local s = settings("RIGHT", "VERTICAL")
        assert.are.equal(1, GetSlotAtPoint(s, 15, TOP - 15, LEFT, RIGHT, TOP, BOTTOM))
        assert.are.equal(2, GetSlotAtPoint(s, 15, TOP - 17, LEFT, RIGHT, TOP, BOTTOM))
    end)

    it("keeps to the last slot of a row and the first row or column", function()
        local s = settings("RIGHT", "HORIZONTAL")
        assert.are.equal(3, GetSlotAtPoint(s, RIGHT - 1, TOP - 1, LEFT, RIGHT, TOP, BOTTOM))
        assert.are.equal(1, GetSlotAtPoint(s, LEFT - 50, TOP + 50, LEFT, RIGHT, TOP, BOTTOM))
    end)
end)

describe("Centred groups", function()
    local GetSlotAnchor = Castborn.CooldownGroup.GetSlotAnchor
    local GetSlotAtPoint = Castborn.CooldownGroup.GetSlotAtPoint
    local LEFT, RIGHT, TOP, BOTTOM = 0, 200, 200, 0

    local function settings(orientation)
        return { iconSize = 30, spacing = 2, iconsPerRow = 3, growDirection = "CENTER", orientation = orientation }
    end

    local function anchor(slot, s, count)
        return { GetSlotAnchor(slot, s, nil, count) }
    end

    it("centres each row on the container's top edge, the short last row included", function()
        local s = settings("HORIZONTAL")
        -- 5 icons, 3 per row: a 94px row then a 62px row
        assert.are.same({ "TOP", "TOP", -32, 0 }, anchor(1, s, 5))
        assert.are.same({ "TOP", "TOP", 0, 0 }, anchor(2, s, 5))
        assert.are.same({ "TOP", "TOP", 32, 0 }, anchor(3, s, 5))
        assert.are.same({ "TOP", "TOP", -16, -32 }, anchor(4, s, 5))
        assert.are.same({ "TOP", "TOP", 16, -32 }, anchor(5, s, 5))
    end)

    it("centres each column on the container's left edge when vertical", function()
        local s = settings("VERTICAL")
        assert.are.same({ "LEFT", "LEFT", 0, 32 }, anchor(1, s, 5))
        assert.are.same({ "LEFT", "LEFT", 0, 0 }, anchor(2, s, 5))
        assert.are.same({ "LEFT", "LEFT", 0, -32 }, anchor(3, s, 5))
        assert.are.same({ "LEFT", "LEFT", 32, 16 }, anchor(4, s, 5))
        assert.are.same({ "LEFT", "LEFT", 32, -16 }, anchor(5, s, 5))
    end)

    it("treats a full pool as full rows when no count is given", function()
        local s = settings("HORIZONTAL")
        assert.are.same({ "TOP", "TOP", -32, -32 }, anchor(4, s))
    end)

    -- The centre of a slot, from where GetSlotAnchor places it in a container with these edges
    local function centre(slot, s, count)
        local point, _, x, y = GetSlotAnchor(slot, s, nil, count)
        if point == "TOP" then return (LEFT + RIGHT) / 2 + x, TOP + y - 15 end
        return LEFT + x + 15, (TOP + BOTTOM) / 2 + y
    end

    for _, orientation in ipairs({ "HORIZONTAL", "VERTICAL" }) do
        for _, count in ipairs({ 7, 8, 9 }) do
            it("finds every slot from its centre, " .. orientation .. " with " .. count .. " icons", function()
                local s = settings(orientation)
                for slot = 1, count do
                    local x, y = centre(slot, s, count)
                    assert.are.equal(slot, GetSlotAtPoint(s, x, y, LEFT, RIGHT, TOP, BOTTOM, count), "slot " .. slot)
                end
            end)
        end
    end

    it("counts a point past the middle of a slot along a row as the next slot", function()
        local s = settings("HORIZONTAL")
        -- One row of 3 centred on x = 100: slots span 53-83, 85-115, 117-147
        assert.are.equal(1, GetSlotAtPoint(s, 68, 185, LEFT, RIGHT, TOP, BOTTOM, 3))
        assert.are.equal(2, GetSlotAtPoint(s, 70, 185, LEFT, RIGHT, TOP, BOTTOM, 3))
    end)

    it("sizes the container from the widest row", function()
        assert.are.same({ 94, 66 }, { Castborn.CooldownGroup.GetContainerSize(5, settings("HORIZONTAL")) })
    end)
end)

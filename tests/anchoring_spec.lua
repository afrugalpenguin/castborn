require("tests.mocks.wow_api")
dofile("Castborn/Core.lua")
dofile("Castborn/Systems/Anchoring.lua")

describe("Anchoring", function()
    local Anchoring = Castborn.Anchoring

    describe("PixelToPercent", function()
        it("converts center position to 0,0", function()
            local xPct, yPct = Anchoring:PixelToPercent(0, 0)
            assert.are.equal(0, xPct)
            assert.are.equal(0, yPct)
        end)

        it("converts positive offsets correctly", function()
            -- At 1920x1080, 960 pixels = 0.5 (half width)
            local xPct, yPct = Anchoring:PixelToPercent(960, 540)
            assert.are.equal(0.5, xPct)
            assert.are.equal(0.5, yPct)
        end)

        it("converts negative offsets correctly", function()
            local xPct, yPct = Anchoring:PixelToPercent(-960, -540)
            assert.are.equal(-0.5, xPct)
            assert.are.equal(-0.5, yPct)
        end)

        it("handles full screen dimensions", function()
            local xPct, yPct = Anchoring:PixelToPercent(1920, 1080)
            assert.are.equal(1, xPct)
            assert.are.equal(1, yPct)
        end)
    end)

    describe("PercentToPixel", function()
        it("converts 0,0 to center (0 offset)", function()
            local x, y = Anchoring:PercentToPixel(0, 0)
            assert.are.equal(0, x)
            assert.are.equal(0, y)
        end)

        it("converts 0.5 to half screen", function()
            local x, y = Anchoring:PercentToPixel(0.5, 0.5)
            assert.are.equal(960, x)
            assert.are.equal(540, y)
        end)

        it("converts negative percentages", function()
            local x, y = Anchoring:PercentToPixel(-0.5, -0.5)
            assert.are.equal(-960, x)
            assert.are.equal(-540, y)
        end)

        it("round-trips with PixelToPercent", function()
            local origX, origY = 150, -200
            local xPct, yPct = Anchoring:PixelToPercent(origX, origY)
            local x, y = Anchoring:PercentToPixel(xPct, yPct)
            assert.are.near(origX, x, 0.001)
            assert.are.near(origY, y, 0.001)
        end)

        it("round-trips arbitrary values", function()
            local origX, origY = 437, -289
            local xPct, yPct = Anchoring:PixelToPercent(origX, origY)
            local x, y = Anchoring:PercentToPixel(xPct, yPct)
            assert.are.near(origX, x, 0.001)
            assert.are.near(origY, y, 0.001)
        end)
    end)

    describe("MigratePosition", function()
        it("adds percentage fields to legacy positions", function()
            local db = { x = 192, y = 108, point = "CENTER" }
            Anchoring:MigratePosition(db)
            assert.are.equal(0.1, db.xPct)
            assert.are.equal(0.1, db.yPct)
        end)

        it("does not overwrite existing percentages", function()
            local db = { x = 192, y = 108, xPct = 0.5, yPct = 0.5 }
            Anchoring:MigratePosition(db)
            assert.are.equal(0.5, db.xPct)
            assert.are.equal(0.5, db.yPct)
        end)

        it("handles nil database gracefully", function()
            -- Should not error
            Anchoring:MigratePosition(nil)
        end)

        it("handles database without x/y", function()
            local db = { point = "CENTER" }
            Anchoring:MigratePosition(db)
            assert.is_nil(db.xPct)
        end)
    end)

    describe("SavePosition", function()
        it("saves both pixel and percentage values", function()
            local db = {}
            Anchoring:SavePosition(db, "CENTER", 192, 108)
            assert.are.equal("CENTER", db.point)
            assert.are.equal(192, db.x)
            assert.are.equal(108, db.y)
            assert.are.equal(0.1, db.xPct)
            assert.are.equal(0.1, db.yPct)
        end)
    end)

    describe("POSITIONS constants", function()
        it("has TOP position defined", function()
            assert.is_not_nil(Anchoring.POSITIONS.TOP)
            assert.are.equal("BOTTOM", Anchoring.POSITIONS.TOP.point)
            assert.are.equal("TOP", Anchoring.POSITIONS.TOP.relPoint)
        end)

        it("has BOTTOM position defined", function()
            assert.is_not_nil(Anchoring.POSITIONS.BOTTOM)
            assert.are.equal("TOP", Anchoring.POSITIONS.BOTTOM.point)
            assert.are.equal("BOTTOM", Anchoring.POSITIONS.BOTTOM.relPoint)
        end)

        it("has LEFT position defined", function()
            assert.is_not_nil(Anchoring.POSITIONS.LEFT)
        end)

        it("has RIGHT position defined", function()
            assert.is_not_nil(Anchoring.POSITIONS.RIGHT)
        end)
    end)
end)

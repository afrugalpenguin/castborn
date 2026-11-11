require("tests.mocks.wow_api")
dofile("Core.lua")
dofile("Systems/Config.lua")

describe("Config", function()
    local CB = Castborn

    describe("ResetPositions", function()
        before_each(function()
            CB.db = {
                player = { point = "TOPLEFT", xPct = 0.5, yPct = 0.5 },
                gcd = { point = "TOPLEFT", xPct = 0.5, yPct = 0.5 },
            }
        end)

        it("resets positions to defaults", function()
            CB:ResetPositions()
            assert.are.equal(CB.defaults.player.point, CB.db.player.point)
            assert.are.equal(CB.defaults.player.xPct, CB.db.player.xPct)
            assert.are.equal(CB.defaults.player.yPct, CB.db.player.yPct)
        end)

        it("still resets later keys when an earlier key has no defaults", function()
            local savedFocusDefaults = CB.defaults.focus
            CB.defaults.focus = nil
            CB:ResetPositions()
            CB.defaults.focus = savedFocusDefaults
            -- gcd comes after focus in positionKeys; it must still be reset
            assert.are.equal(CB.defaults.gcd.point, CB.db.gcd.point)
            assert.are.equal(CB.defaults.gcd.xPct, CB.db.gcd.xPct)
            assert.are.equal(CB.defaults.gcd.yPct, CB.db.gcd.yPct)
        end)

        it("resets the resource bars position, width and anchoring", function()
            CB.db.resources = { point = "TOPLEFT", xPct = 0.5, yPct = 0.5, width = 400, anchored = true }
            CB:ResetPositions()
            assert.are.equal(CB.defaults.resources.point, CB.db.resources.point)
            assert.are.equal(CB.defaults.resources.xPct, CB.db.resources.xPct)
            assert.are.equal(CB.defaults.resources.yPct, CB.db.resources.yPct)
            assert.are.equal(220, CB.db.resources.width)
            assert.is_false(CB.db.resources.anchored)
        end)
    end)
end)

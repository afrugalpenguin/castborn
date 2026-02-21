require("tests.mocks.wow_api")
dofile("Core.lua")

describe("Core utilities", function()
    local CB = Castborn

    describe("DeepCopy", function()
        it("copies simple tables", function()
            local orig = { a = 1, b = 2 }
            local copy = CB:DeepCopy(orig)
            assert.are.same(orig, copy)
            assert.are_not.equal(orig, copy)
        end)

        it("copies nested tables", function()
            local orig = { a = { b = { c = 3 } } }
            local copy = CB:DeepCopy(orig)
            assert.are.same(orig, copy)
            orig.a.b.c = 99
            assert.are.equal(3, copy.a.b.c)
        end)

        it("handles nil input", function()
            assert.is_nil(CB:DeepCopy(nil))
        end)

        it("copies primitive values as-is", function()
            assert.are.equal(42, CB:DeepCopy(42))
            assert.are.equal("hello", CB:DeepCopy("hello"))
            assert.are.equal(true, CB:DeepCopy(true))
        end)
    end)

    describe("MergeDefaults", function()
        it("adds missing keys from defaults", function()
            local dest = { a = 1 }
            local defaults = { a = 0, b = 2 }
            CB:MergeDefaults(dest, defaults)
            assert.are.equal(1, dest.a)  -- Keeps existing
            assert.are.equal(2, dest.b)  -- Adds missing
        end)

        it("recursively merges nested tables", function()
            local dest = { nested = { x = 1 } }
            local defaults = { nested = { x = 0, y = 2 } }
            CB:MergeDefaults(dest, defaults)
            assert.are.equal(1, dest.nested.x)
            assert.are.equal(2, dest.nested.y)
        end)

        it("does not overwrite existing values", function()
            local dest = { a = "original" }
            local defaults = { a = "default" }
            CB:MergeDefaults(dest, defaults)
            assert.are.equal("original", dest.a)
        end)

        it("returns the destination table", function()
            local dest = {}
            local result = CB:MergeDefaults(dest, { a = 1 })
            assert.are.equal(dest, result)
        end)
    end)

    describe("FormatTime", function()
        it("formats seconds under 10 with one decimal", function()
            assert.are.equal("5.0", CB:FormatTime(5))
            assert.are.equal("9.5", CB:FormatTime(9.5))
        end)

        it("formats seconds 10-59 as whole numbers", function()
            assert.are.equal("10", CB:FormatTime(10))
            assert.are.equal("45", CB:FormatTime(45))
        end)

        it("formats minutes:seconds for 60+ seconds", function()
            assert.are.equal("1:30", CB:FormatTime(90))
            assert.are.equal("2:05", CB:FormatTime(125))
        end)

        it("handles zero", function()
            assert.are.equal("0.0", CB:FormatTime(0))
        end)

        it("handles fractional seconds under 10", function()
            assert.are.equal("3.7", CB:FormatTime(3.7))
        end)
    end)

    describe("Module system", function()
        it("registers and retrieves modules", function()
            local testModule = { name = "TestModule" }
            CB:RegisterModule("test", testModule)
            assert.are.equal(testModule, CB:GetModule("test"))
        end)

        it("calls OnInitialize when registering", function()
            local initialized = false
            local testModule = {
                OnInitialize = function() initialized = true end
            }
            CB:RegisterModule("initTest", testModule)
            assert.is_true(initialized)
        end)

        it("returns nil for unregistered modules", function()
            assert.is_nil(CB:GetModule("nonexistent"))
        end)
    end)

    describe("Callback system", function()
        it("fires callbacks to registered listeners", function()
            local received = nil
            CB:RegisterCallback("TEST_EVENT", function(value)
                received = value
            end)
            CB:FireCallback("TEST_EVENT", "test_value")
            assert.are.equal("test_value", received)
        end)

        it("supports multiple callbacks per event", function()
            local count = 0
            CB:RegisterCallback("MULTI_EVENT", function() count = count + 1 end)
            CB:RegisterCallback("MULTI_EVENT", function() count = count + 1 end)
            CB:FireCallback("MULTI_EVENT")
            assert.are.equal(2, count)
        end)

        it("does nothing for events with no listeners", function()
            -- Should not error
            CB:FireCallback("NO_LISTENERS_EVENT", "data")
        end)
    end)
end)

require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Systems/Theme.lua")

-- Theme paths are game paths ("Interface\AddOns\Castborn\Media\..."); map them to the repo
local function repoPath(gamePath)
    return (gamePath:gsub("^Interface\\AddOns\\Castborn\\", ""):gsub("\\", "/"))
end

local function isPowerOfTwo(n)
    return n > 0 and math.floor(math.log(n) / math.log(2) + 0.5) == math.log(n) / math.log(2)
end

describe("Theme", function()
    local Theme = Castborn.Theme

    describe("media", function()
        it("ships every texture as a 32-bit TGA with power-of-two sides", function()
            for name, path in pairs(Theme.media) do
                local file = repoPath(path) .. ".tga"
                local f = io.open(file, "rb")
                assert.is_not_nil(f, name .. ": missing " .. file)
                local header = f:read(18)
                f:close()
                assert.are.equal(2, header:byte(3), name .. " is not an uncompressed true-colour TGA")
                assert.are.equal(32, header:byte(17), name .. " is not 32-bit")
                local width = header:byte(13) + header:byte(14) * 256
                local height = header:byte(15) + header:byte(16) * 256
                assert.is_true(isPowerOfTwo(width) and isPowerOfTwo(height), name .. " is not power-of-two")
            end
        end)

        it("ships every font", function()
            for role, path in pairs(Theme.fonts) do
                local f = io.open(repoPath(path), "rb")
                assert.is_not_nil(f, role .. ": missing " .. repoPath(path))
                f:close()
            end
        end)
    end)

    describe("SliceLayout", function()
        local regions = Theme.SliceLayout(8, 32)

        local function find(key)
            for _, r in ipairs(regions) do
                if r.key == key then return r end
            end
        end

        it("splits the texture into nine regions that tile it exactly", function()
            assert.are.equal(9, #regions)
            local area = 0
            for _, r in ipairs(regions) do
                area = area + (r.right - r.left) * (r.bottom - r.top)
            end
            assert.is_near(1, area, 1e-9)
        end)

        it("cuts the texture at the chamfer size", function()
            local corner = find("TOPLEFT")
            assert.are.same({ 0, 0.25, 0, 0.25 }, { corner.left, corner.right, corner.top, corner.bottom })
            local centre = find("CENTER")
            assert.are.same({ 0.25, 0.75, 0.25, 0.75 }, { centre.left, centre.right, centre.top, centre.bottom })
        end)

        it("anchors corners at a fixed size and stretches the edges", function()
            local corner = find("BOTTOMRIGHT")
            assert.are.same({ rel = "BOTTOMRIGHT", x = -1, y = 1 }, corner.from)
            assert.are.same({ rel = "BOTTOMRIGHT", x = 0, y = 0 }, corner.to)
            local top = find("TOP")
            assert.are.same({ rel = "TOPLEFT", x = 1, y = 0 }, top.from)
            assert.are.same({ rel = "TOPRIGHT", x = -1, y = -1 }, top.to)
        end)
    end)

    describe("Color", function()
        it("returns a named palette colour with alpha", function()
            local r, g, b, a = Theme:Color("accent", 0.5)
            assert.is_near(0xD4 / 255, r, 1e-9)
            assert.is_near(0xA8 / 255, g, 1e-9)
            assert.is_near(0x4A / 255, b, 1e-9)
            assert.are.equal(0.5, a)
        end)

        it("passes an explicit colour through", function()
            assert.are.same({ 0.1, 0.2, 0.3, 1 }, { Theme:Color({ 0.1, 0.2, 0.3 }) })
        end)
    end)

    describe("Code", function()
        it("turns a palette colour into an inline text colour code", function()
            assert.are.equal("|cfff0cf7a", Theme:Code("heading"))
            assert.are.equal("|cffd4a84a", Theme:Code("accent"))
        end)
    end)
end)

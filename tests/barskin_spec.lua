require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Systems/BarSkin.lua")

-- A texture that remembers what it was given
local function spyTexture()
    local t = { shown = true, points = {} }
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    function t:IsShown() return self.shown end
    function t:SetTexture(file) self.file = file end
    function t:SetTexCoord(l, r, top, b) self.coords = { l, r, top, b } end
    function t:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    function t:SetBlendMode(mode) self.blend = mode end
    function t:SetSize(w, h) self.size = { w, h } end
    function t:ClearAllPoints() self.points = {} end
    function t:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function t:SetAllPoints() self.allPoints = true end
    function t:SetDrawLayer() end
    return t
end

-- A frame built like CreateBackdrop's: bg plus four border edges
local function spyFrame()
    local f = { level = 10 }
    function f:CreateTexture() return spyTexture() end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(l) self.level = l end
    function f:SetAllPoints() end
    function f:GetHeight() return 20 end
    f.bg = spyTexture()
    f.border = { top = spyTexture(), bottom = spyTexture(), left = spyTexture(), right = spyTexture() }
    return f
end

describe("Bar skins", function()
    local BS = Castborn.BarSkin
    local originalCreateFrame

    before_each(function()
        _G.CastbornDB = { barSkin = "Castborn", barSkinBorder = 2 }
        Castborn.db = _G.CastbornDB
        Castborn.Masque = nil
        _G.C_Texture = nil
        originalCreateFrame = _G.CreateFrame
        _G.CreateFrame = function() return spyFrame() end
        BS.frames = {}
    end)

    after_each(function()
        _G.CreateFrame = originalCreateFrame
        _G.C_Texture = nil
        Castborn.Masque = nil
    end)

    -- Masque with its "Bars" group set to skinId; settings overrides the group's db fields
    local function useMasque(skins, skinId, settings)
        local db = { SkinID = skinId, Disabled = false, Backdrop = true, Gloss = false, Shadow = false, Colors = {} }
        for k, v in pairs(settings or {}) do db[k] = v end
        Castborn.Masque = {
            lib = {
                GetSkin = function(_, id) return id and skins[id] end,
                GetDefaultSkin = function() return "Default", skins.Default end,
            },
            groups = { bars = { db = db } },
        }
        CastbornDB.barSkinUseMasque = true  -- the Look & Feel switch
        return db
    end

    describe("List (the fallback choice)", function()
        it("offers Castborn's skins, Castborn first", function()
            local list = BS:List()
            assert.are.equal("Castborn", list[1].value)
            local values = {}
            for _, item in ipairs(list) do values[item.value] = item.label end
            assert.is_not_nil(values.Flat)
        end)

        it("does not list Masque skins, which are chosen in Masque", function()
            useMasque({ Frugal = {} }, "Frugal")
            for _, item in ipairs(BS:List()) do
                assert.is_nil(item.value:find("Frugal"))
            end
        end)
    end)

    describe("GetSkinData", function()
        it("has no skin data for the plain Castborn look", function()
            assert.is_nil(BS:GetSkinData("Castborn"))
        end)

        it("returns a built-in skin", function()
            assert.is_table(BS:GetSkinData("Flat"))
        end)

        it("accepts skins registered by other addons", function()
            local skin = { Normal = { Texture = "X" } }
            Castborn:RegisterBarSkin("Mine", skin)
            assert.are.equal(skin, BS:GetSkinData("Mine"))
        end)
    end)

    describe("the Use Masque skin switch", function()
        local frugal = { Normal = { Texture = "Border" } }

        it("is off by default, so installing Masque changes nothing", function()
            assert.is_false(Castborn.defaults.barSkinUseMasque)
        end)

        it("uses Castborn's choice when switched off, even with Masque installed", function()
            useMasque({ Frugal = frugal }, "Frugal")
            CastbornDB.barSkinUseMasque = false
            CastbornDB.barSkin = "Flat"
            assert.are.equal(BS.skins.Flat, (BS:GetActiveSkin()))
            assert.is_false(BS:IsMasqueActive())
            assert.is_true(BS:IsMasqueAvailable())
        end)

        it("is unavailable without Masque", function()
            assert.is_false(BS:IsMasqueAvailable())
        end)

        it("names the skin the Masque group is using", function()
            useMasque({ Frugal = frugal }, "Frugal")
            assert.are.equal("Frugal", BS:GetMasqueSkinName())
        end)

        it("names Masque's default skin when the group's skin is gone", function()
            useMasque({ Default = frugal }, "Uninstalled")
            assert.are.equal("Default", BS:GetMasqueSkinName())
        end)

        it("announces each re-skin so the options page can update", function()
            local fired = 0
            Castborn:RegisterCallback("BAR_SKIN_CHANGED", function() fired = fired + 1 end)
            BS:ApplyAll()
            assert.are.equal(1, fired)
        end)
    end)

    describe("GetActiveSkin", function()
        local frugal = { Normal = { Texture = "Border" } }

        it("follows the Masque Bars group when Masque is installed", function()
            useMasque({ Frugal = frugal }, "Frugal")
            CastbornDB.barSkin = "Flat"
            assert.are.equal(frugal, (BS:GetActiveSkin()))
            assert.is_true(BS:IsMasqueActive())
        end)

        it("falls back to Castborn's choice without Masque", function()
            CastbornDB.barSkin = "Flat"
            assert.are.equal(BS.skins.Flat, (BS:GetActiveSkin()))
            assert.is_false(BS:IsMasqueActive())
        end)

        it("falls back to Castborn's choice when the Masque group is disabled", function()
            useMasque({ Frugal = frugal }, "Frugal", { Disabled = true })
            CastbornDB.barSkin = "Flat"
            assert.are.equal(BS.skins.Flat, (BS:GetActiveSkin()))
            assert.is_false(BS:IsMasqueActive())
        end)

        it("uses Masque's default skin when the group's skin is gone", function()
            local default = { Normal = { Texture = "Default" } }
            useMasque({ Default = default }, "Uninstalled")
            assert.are.equal(default, (BS:GetActiveSkin()))
        end)

        it("passes on the group's layer toggles and colours", function()
            useMasque({ Frugal = frugal }, "Frugal", { Backdrop = false, Gloss = true, Colors = { Normal = { 1, 0, 0, 1 } } })
            local _, opts = BS:GetActiveSkin()
            assert.is_false(opts.backdrop)
            assert.is_true(opts.gloss)
            assert.are.same({ 1, 0, 0, 1 }, opts.colors.Normal)
        end)

        it("draws every layer of a fallback skin", function()
            CastbornDB.barSkin = "Flat"
            local _, opts = BS:GetActiveSkin()
            assert.is_true(opts.backdrop and opts.gloss and opts.shadow)
        end)
    end)

    describe("ResolveRegion", function()
        it("follows a region that names another", function()
            local skin = { Checked = { Texture = "C" }, SlotHighlight = "Checked" }
            assert.are.equal(skin.Checked, BS:ResolveRegion(skin, "SlotHighlight"))
        end)

        it("treats hidden and missing regions as absent", function()
            assert.is_nil(BS:ResolveRegion({ Gloss = { Hide = true } }, "Gloss"))
            assert.is_nil(BS:ResolveRegion({}, "Gloss"))
        end)
    end)

    describe("GetRegionTexture", function()
        it("uses the whole texture by default", function()
            assert.are.same({ "Border", 0, 1, 0, 1 }, { BS:GetRegionTexture({ Texture = "Border" }) })
        end)

        it("uses the skin's texture coordinates", function()
            assert.are.same({ "Border", 0.1, 0.9, 0.2, 0.8 },
                { BS:GetRegionTexture({ Texture = "Border", TexCoords = { 0.1, 0.9, 0.2, 0.8 } }) })
        end)

        it("looks atlases up when the client can", function()
            _G.C_Texture = { GetAtlasInfo = function(name)
                if name == "Frame" then
                    return { file = 123, leftTexCoord = 0.5, rightTexCoord = 0.75, topTexCoord = 0, bottomTexCoord = 0.25 }
                end
            end }
            assert.are.same({ 123, 0.5, 0.75, 0, 0.25 }, { BS:GetRegionTexture({ Atlas = "Frame" }) })
        end)

        it("skips an atlas the client cannot look up", function()
            assert.is_nil(BS:GetRegionTexture({ Atlas = "Frame" }))
        end)
    end)

    describe("SliceCoords", function()
        it("cuts the texture into corners and edges", function()
            local s = BS:SliceCoords(0, 1, 0, 1, 0.25, 0.25)
            assert.are.same({ 0, 0.25, 0, 0.25 }, s.TOPLEFT)
            assert.are.same({ 0.25, 0.75, 0, 0.25 }, s.TOP)
            assert.are.same({ 0.75, 1, 0, 0.25 }, s.TOPRIGHT)
            assert.are.same({ 0, 0.25, 0.25, 0.75 }, s.LEFT)
            assert.are.same({ 0.75, 1, 0.25, 0.75 }, s.RIGHT)
            assert.are.same({ 0, 0.25, 0.75, 1 }, s.BOTTOMLEFT)
            assert.are.same({ 0.25, 0.75, 0.75, 1 }, s.BOTTOM)
            assert.are.same({ 0.75, 1, 0.75, 1 }, s.BOTTOMRIGHT)
        end)

        it("cuts within an atlas's own coordinates", function()
            local s = BS:SliceCoords(0.5, 0.75, 0, 0.5, 0.25, 0.25)
            assert.are.same({ 0.5, 0.5625, 0, 0.125 }, s.TOPLEFT)
            assert.are.same({ 0.6875, 0.75, 0.375, 0.5 }, s.BOTTOMRIGHT)
        end)
    end)

    describe("Apply", function()
        local frugal = {
            Backdrop = { Texture = "Black", Color = { 1, 1, 1, 1 }, Width = 36, Height = 36 },
            Normal = { Texture = "Border", Color = { 1, 1, 1, 1 }, Width = 36, Height = 36 },
            Gloss = { Hide = true },
        }

        it("leaves the plain Castborn look alone", function()
            local f = spyFrame()
            BS:Register(f)
            assert.is_true(f.border.top.shown)
            assert.is_true(f.bg.shown)
        end)

        it("draws the Masque group's skin in place of the Castborn border and background", function()
            useMasque({ Frugal = frugal }, "Frugal")
            local f = spyFrame()
            BS:Register(f)
            assert.is_false(f.border.top.shown)
            assert.is_false(f.bg.shown)
            local skin = f.castbornSkin
            assert.are.equal("Border", skin.pieces.TOPLEFT.file)
            assert.is_true(skin.pieces.BOTTOMRIGHT.shown)
            assert.are.equal("Black", skin.backdrop.file)
            assert.is_true(skin.backdrop.shown)
            assert.is_false(skin.gloss.shown)
        end)

        it("keeps the Castborn background when the Masque group's backdrop is off", function()
            useMasque({ Frugal = frugal }, "Frugal", { Backdrop = false })
            local f = spyFrame()
            BS:Register(f)
            assert.is_true(f.bg.shown)
            assert.is_false(f.castbornSkin.backdrop.shown)
            assert.is_true(f.castbornSkin.pieces.TOP.shown)
        end)

        it("tints with the Masque group's colour override", function()
            useMasque({ Frugal = frugal }, "Frugal", { Colors = { Normal = { 1, 0, 0, 1 } } })
            local f = spyFrame()
            BS:Register(f)
            assert.are.same({ 1, 0, 0, 1 }, f.castbornSkin.pieces.TOP.color)
        end)

        it("sizes the corners from the border setting and slices to match", function()
            useMasque({ Frugal = frugal }, "Frugal")
            CastbornDB.barSkinBorder = 3
            local f = spyFrame()
            BS:Register(f)
            assert.are.same({ 3, 3 }, f.castbornSkin.pieces.TOPLEFT.size)
            assert.are.same({ 0, 3 / 36, 0, 3 / 36 }, f.castbornSkin.pieces.TOPLEFT.coords)
        end)

        it("falls back when the Masque group is disabled, and back again", function()
            local db = useMasque({ Frugal = frugal }, "Frugal")
            local f = spyFrame()
            BS:Register(f)
            db.Disabled = true
            BS:ApplyAll()
            assert.is_true(f.border.top.shown)
            assert.is_true(f.bg.shown)
            assert.is_false(f.castbornSkin.pieces.TOPLEFT.shown)
            assert.is_false(f.castbornSkin.backdrop.shown)
            db.Disabled = false
            BS:ApplyAll()
            assert.is_true(f.castbornSkin.pieces.TOPLEFT.shown)
        end)

        it("uses the Castborn look without Masque", function()
            local f = spyFrame()
            BS:Register(f)
            assert.is_true(f.border.top.shown)
            assert.is_true(f.bg.shown)
        end)

        it("draws a built-in skin with no other addon installed", function()
            CastbornDB.barSkin = "Flat"
            local f = spyFrame()
            BS:Register(f)
            assert.is_false(f.border.top.shown)
            assert.is_true(f.castbornSkin.pieces.TOP.shown)
        end)

        it("hides the skin border too when borders are turned off", function()
            CastbornDB.barSkin = "Flat"
            CastbornDB.showBorders = false
            local f = spyFrame()
            BS:Register(f)
            assert.is_false(f.castbornSkin.pieces.TOP.shown)
            assert.is_false(f.border.top.shown)
        end)

        it("re-applies when borders are toggled", function()
            CastbornDB.barSkin = "Flat"
            local f = spyFrame()
            BS:Register(f)
            CastbornDB.showBorders = false
            Castborn:FireCallback("BORDERS_CHANGED", false)
            assert.is_false(f.castbornSkin.pieces.TOP.shown)
        end)
    end)
end)

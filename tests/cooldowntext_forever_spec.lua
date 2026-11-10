require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
_G.SlashCmdList = _G.SlashCmdList or {}
dofile("Core.lua")
dofile("Modules/CooldownText_Forever.lua")

describe("Cooldown text on Forever", function()
    local CT = Castborn.CooldownText
    local cvars, inCombat

    -- A Cooldown frame whose countdown font string records what was applied
    local function fakeCooldown(width)
        local fs = { color = { 1, 1, 1, 1 }, font = { "Fonts\\FRIZQT__.TTF", 14, "OUTLINE" } }
        function fs:GetFont() return self.font[1], self.font[2], self.font[3] end
        function fs:SetFont(path, size, flags) self.font = { path, size, flags } end
        function fs:GetTextColor() return unpack(self.color) end
        function fs:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
        function fs:ClearAllPoints() end
        function fs:SetPoint() end
        local owner = { GetWidth = function() return width or 40 end }
        local cd = { fs = fs, minimum = 1500, decimals = 0 }
        function cd:GetCountdownFontString() return self.fs end
        function cd:GetParent() return owner end
        function cd:GetMinimumCountdownDuration() return self.minimum end
        function cd:SetMinimumCountdownDuration(v) self.minimum = v end
        function cd:GetCountdownMillisecondsThreshold() return self.decimals end
        function cd:SetCountdownMillisecondsThreshold(v) self.decimals = v end
        function cd:SetHideCountdownNumbers(v) self.hidden = v end
        function cd:IsVisible() return true end
        return cd
    end

    before_each(function()
        Castborn.db = { cooldowntext = Castborn:DeepCopy(CT.defaults) }
        CT.ready = true
        CT.curve = nil
        for k in pairs(CT.entries) do CT.entries[k] = nil end
        cvars, inCombat = { countdownForCooldowns = "0" }, false
        _G.C_CVar = {
            GetCVar = function(name) return cvars[name] end,
            SetCVar = function(name, value) cvars[name] = value end,
        }
        _G.InCombatLockdown = function() return inCombat end
    end)

    after_each(function()
        _G.C_CVar = nil
        _G.InCombatLockdown = nil
        _G.C_ActionBar = nil
        _G.issecretvalue = nil
    end)

    describe("TextSize", function()
        it("scales with the button width", function()
            assert.are.equal(18, CT:TextSize(40))  -- 45% of 40
        end)

        it("never goes below 8", function()
            assert.are.equal(8, CT:TextSize(10))
        end)

        it("falls back to a standard button when the width is unusable", function()
            assert.are.equal(16, CT:TextSize(nil))  -- 45% of 36
        end)
    end)

    describe("IsActiveFor", function()
        it("follows the per-kind switches", function()
            Castborn.db.cooldowntext.actionBars = false
            assert.is_false(CT:IsActiveFor({ kind = "actionbar" }))
            assert.is_true(CT:IsActiveFor({ kind = "castborn" }))
        end)

        it("is off for everything when disabled", function()
            Castborn.db.cooldowntext.enabled = false
            assert.is_false(CT:IsActiveFor({ kind = "castborn" }))
        end)
    end)

    describe("Style", function()
        it("applies size, thresholds and the base colour", function()
            local cd = fakeCooldown(40)
            CT:Register(cd, "actionbar", {})
            assert.are.equal(18, cd.fs.font[2])
            assert.are.equal("OUTLINE", cd.fs.font[3])
            assert.are.equal(2000, cd.minimum)
            assert.are.equal(3, cd.decimals)
            assert.are.same({ 1, 1, 1, 1 }, cd.fs.color)
        end)

        it("restores Blizzard's own settings when turned off", function()
            local cd = fakeCooldown(40)
            CT:Register(cd, "actionbar", {})
            Castborn.db.cooldowntext.enabled = false
            CT:Style(cd)
            assert.are.same({ "Fonts\\FRIZQT__.TTF", 14, "OUTLINE" }, cd.fs.font)
            assert.are.equal(1500, cd.minimum)
            assert.are.equal(0, cd.decimals)
        end)

        it("waits until ready before styling", function()
            CT.ready = false
            local cd = fakeCooldown(40)
            CT:Register(cd, "actionbar", {})
            assert.are.equal(14, cd.fs.font[2])
        end)
    end)

    describe("LibActionButton bars (Bartender4)", function()
        local created, existing

        before_each(function()
            existing = { cooldown = fakeCooldown(40) }
            local lab = {
                buttonRegistry = { [existing] = true },
                RegisterCallback = function(_, event, fn) created = { event = event, fn = fn } end,
            }
            _G.LibStub = function(name) if name == "LibActionButton-1.0" then return lab end end
        end)

        after_each(function() _G.LibStub = nil end)

        it("registers the buttons that already exist", function()
            CT:RegisterLibActionButtons()
            assert.are.equal("actionbar", CT.entries[existing.cooldown].kind)
        end)

        it("registers buttons created later", function()
            CT:RegisterLibActionButtons()
            assert.are.equal("OnButtonCreated", created.event)
            local later = { cooldown = fakeCooldown(40) }
            created.fn("OnButtonCreated", later)
            assert.is_not_nil(CT.entries[later.cooldown])
        end)

        it("does nothing without the library", function()
            _G.LibStub = function() return nil end
            assert.has_no.errors(function() CT:RegisterLibActionButtons() end)
        end)
    end)

    describe("countdown CVar", function()
        it("turns the action bar numbers on and remembers the old value", function()
            CT:UpdateCVar()
            assert.are.equal("1", cvars.countdownForCooldowns)
            assert.are.equal("0", Castborn.db.cooldowntext.savedCVar)
        end)

        it("puts the player's setting back when disabled", function()
            CT:UpdateCVar()
            Castborn.db.cooldowntext.enabled = false
            CT:UpdateCVar()
            assert.are.equal("0", cvars.countdownForCooldowns)
            assert.is_nil(Castborn.db.cooldowntext.savedCVar)
        end)

        it("leaves a CVar that was already on alone", function()
            cvars.countdownForCooldowns = "1"
            CT:UpdateCVar()
            assert.is_nil(Castborn.db.cooldowntext.savedCVar)
        end)

        it("waits for combat to end", function()
            inCombat = true
            CT:UpdateCVar()
            assert.are.equal("0", cvars.countdownForCooldowns)
            assert.is_true(CT.cvarPending)
        end)
    end)

    describe("colour stages", function()
        local duration, evaluated

        before_each(function()
            evaluated = 0
            duration = {
                EvaluateRemainingDuration = function()
                    evaluated = evaluated + 1
                    return { GetRGBA = function() return 1, 0.3, 0.25, 1 end }
                end,
            }
            _G.C_ActionBar = { GetActionCooldownDuration = function(action)
                if action == 7 then return duration end
            end }
            CT.curve = {}
        end)

        it("colours action bar numbers from the button's cooldown duration", function()
            local cd = fakeCooldown(40)
            CT:Register(cd, "actionbar", { action = 7 })
            CT:RecolourAll()
            assert.are.same({ 1, 0.3, 0.25, 1 }, cd.fs.color)
        end)

        it("leaves the base colour when colour stages are off", function()
            Castborn.db.cooldowntext.colorStages = false
            local cd = fakeCooldown(40)
            CT:Register(cd, "actionbar", { action = 7 })
            CT:RecolourAll()
            assert.are.equal(0, evaluated)
        end)

        it("skips buttons without a duration", function()
            local cd = fakeCooldown(40)
            CT:Register(cd, "actionbar", { action = 3 })
            assert.has_no.errors(function() CT:RecolourAll() end)
            assert.are.same({ 1, 1, 1, 1 }, cd.fs.color)
        end)

        it("asks a LibActionButton button for its own duration", function()
            local cd = fakeCooldown(40)
            CT:Register(cd, "actionbar", { GetCooldownDuration = function() return duration end })
            CT:RecolourAll()
            assert.are.same({ 1, 0.3, 0.25, 1 }, cd.fs.color)
        end)

        it("uses the duration captured from a Castborn icon", function()
            assert.are.equal(duration, CT:DurationFor({ kind = "castborn", duration = duration }))
        end)
    end)
end)

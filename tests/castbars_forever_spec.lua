require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/CastBars.lua")
dofile("Modules/CastBars_Forever.lua")

describe("CastBars_Forever", function()
    local calls

    before_each(function()
        calls = {}
        _G.PlayerCastingBarFrame = {
            SetUnit = function(_, unit) calls[#calls + 1] = { "SetUnit", unit } end,
            UnregisterAllEvents = function() calls[#calls + 1] = { "UnregisterAllEvents" } end,
            SetScript = function() calls[#calls + 1] = { "SetScript" } end,
            Hide = function() calls[#calls + 1] = { "Hide" } end,
        }
    end)

    after_each(function()
        _G.PlayerCastingBarFrame = nil
    end)

    it("detaches the Blizzard castbar from the player", function()
        Castborn:HideBlizzardCastBar(true)
        assert.are.same({ "SetUnit", nil }, calls[1])
    end)

    it("never unregisters Blizzard's events or replaces its scripts", function()
        Castborn:HideBlizzardCastBar(true)
        for _, call in ipairs(calls) do
            assert.are_not.equal("UnregisterAllEvents", call[1])
            assert.are_not.equal("SetScript", call[1])
        end
    end)

    it("does nothing when the frame is missing", function()
        _G.PlayerCastingBarFrame = nil
        assert.has_no.errors(function() Castborn:HideBlizzardCastBar(true) end)
    end)

    describe("target and focus castbars", function()
        local names = { "TargetFrameSpellBar", "FocusFrameSpellBar" }
        local frames

        local function fakeSpellBar()
            local f = { hooks = {}, hideCount = 0, calls = {} }
            f.HookScript = function(_, script, fn) f.hooks[#f.hooks + 1] = { script, fn } end
            f.Hide = function() f.hideCount = f.hideCount + 1 end
            f.SetUnit = function() f.calls[#f.calls + 1] = "SetUnit" end
            f.UnregisterAllEvents = function() f.calls[#f.calls + 1] = "UnregisterAllEvents" end
            f.SetScript = function() f.calls[#f.calls + 1] = "SetScript" end
            return f
        end

        before_each(function()
            frames = {}
            for _, name in ipairs(names) do
                frames[name] = fakeSpellBar()
                _G[name] = frames[name]
            end
        end)

        after_each(function()
            for _, name in ipairs(names) do _G[name] = nil end
        end)

        it("hides each bar whenever Blizzard shows it", function()
            Castborn:HideBlizzardCastBar(true)
            for _, name in ipairs(names) do
                local f = frames[name]
                assert.are.equal(1, #f.hooks, name)
                assert.are.equal("OnShow", f.hooks[1][1], name)
                local before = f.hideCount
                f.hooks[1][2](f)
                assert.are.equal(before + 1, f.hideCount, name)
            end
        end)

        it("hooks each bar only once across repeated calls", function()
            Castborn:HideBlizzardCastBar(true)
            Castborn:HideBlizzardCastBar(true)
            for _, name in ipairs(names) do
                assert.are.equal(1, #frames[name].hooks, name)
            end
        end)

        it("never detaches, unregisters or replaces Blizzard's scripts", function()
            Castborn:HideBlizzardCastBar(true)
            for _, name in ipairs(names) do
                assert.are.same({}, frames[name].calls, name)
            end
        end)

        it("does nothing when the bars are missing", function()
            for _, name in ipairs(names) do _G[name] = nil end
            assert.has_no.errors(function() Castborn:HideBlizzardCastBar(true) end)
        end)
    end)

    describe("secret cast data", function()
        local secrets = setmetatable({}, { __mode = "k" })
        local function secret() local s = {} secrets[s] = true return s end
        local CB = Castborn

        local function fakeFrame()
            local f = { bar = {}, spark = {}, timeText = {}, shield = {} }
            f.bar.SetTimerDuration = function(_, d, i, dir) f.timer = { d, i, dir } end
            f.bar.SetMinMaxValues = function() f.reset = true end
            f.bar.SetValue = function() f.reset = true end
            f.bar.SetStatusBarColor = function() end
            f.spark.Hide = function() f.sparkHidden = true end
            f.timeText.SetText = function(_, t) f.text = t end
            f.timeText.Show = function() end
            f.timeText.Hide = function() f.textHidden = true end
            f.shield.Show = function() end
            f.shield.Hide = function() end
            f.shield.SetAlpha = function() end
            f.shield.SetAlphaFromBoolean = function(_, b) f.shieldBool = b end
            return f
        end

        before_each(function()
            _G.issecretvalue = function(v) return secrets[v] == true end
            _G.Enum = { StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
                        StatusBarInterpolation = { Immediate = 0 } }
        end)

        after_each(function()
            _G.issecretvalue = nil
            _G.Enum = nil
            _G.UnitCastingDuration = nil
            _G.UnitChannelDuration = nil
        end)

        it("keeps plain timings on the TBC path", function()
            local f = fakeFrame()
            CB:SetCastTiming(f, "player", false, 1000, 3000)
            assert.are.equal(1, f.startTime)
            assert.is_nil(f.secretTiming)
        end)

        it("drives the bar from a duration object when times are secret", function()
            local dur = {}
            _G.UnitCastingDuration = function() return dur end
            local f = fakeFrame()
            CB:SetCastTiming(f, "target", false, secret(), secret())
            assert.is_true(f.secretTiming)
            assert.are.same({ dur, 0, 0 }, f.timer)
        end)

        it("drains channels with a remaining-time timer", function()
            _G.UnitChannelDuration = function() return {} end
            local f = fakeFrame()
            CB:SetCastTiming(f, "target", true, secret(), secret())
            assert.are.equal(1, f.timer[3])
        end)

        it("does not reset a running timer", function()
            _G.UnitCastingDuration = function() return {} end
            local f = fakeFrame()
            CB:SetCastTiming(f, "target", false, secret(), secret())
            CB:StartCastBar(f, false)
            assert.is_nil(f.reset)
        end)

        it("never does arithmetic on secret progress", function()
            _G.UnitCastingDuration = function() return {} end
            local f = fakeFrame()
            CB:SetCastTiming(f, "target", false, secret(), secret())
            local done
            assert.has_no.errors(function() done = CB:UpdateCastProgress(f, 5, { showTime = true }) end)
            assert.is_false(done)
            assert.is_true(f.sparkHidden)
        end)

        it("shows countdown text from the duration object", function()
            local dur = setmetatable({}, { __index = { GetRemainingDuration = function() return 1.26 end } })
            _G.UnitCastingDuration = function() return dur end
            local f = fakeFrame()
            CB:SetCastTiming(f, "target", false, secret(), secret())
            CB:UpdateCastProgress(f, 5, { showTime = true })
            assert.are.equal("1.3", f.text)
        end)

        it("hides latency for secret casts", function()
            _G.UnitCastingDuration = function() return {} end
            local f = fakeFrame()
            CB:SetCastTiming(f, "target", false, secret(), secret())
            assert.is_nil(CB:GetLatencyWidth(f))
        end)

        it("binds the shield to a secret interruptible flag", function()
            local f = fakeFrame()
            local flag = secret()
            assert.has_no.errors(function() CB:ApplyInterruptShield(f, flag, { 1, 1, 1, 1 }) end)
            assert.are.equal(flag, f.shieldBool)
        end)

        it("never hides a cast for a secret tradeskill flag", function()
            assert.is_false(CB:IsHiddenTradeSkill(secret(), { hideTradeSkills = true }))
        end)

        it("drops the rank when the spell id is secret", function()
            assert.are.equal("Name", CB:GetCastDisplayName("Name", nil, secret(), { showSpellRank = true }))
        end)

        describe("IsSameUnit", function()
            local original
            before_each(function() original = _G.UnitIsUnit end)
            after_each(function() _G.UnitIsUnit = original end)

            it("passes a plain UnitIsUnit result through", function()
                _G.UnitIsUnit = function() return true end
                assert.is_true(CB:IsSameUnit("targettarget", "player"))
                _G.UnitIsUnit = function() return false end
                assert.is_false(CB:IsSameUnit("targettarget", "player"))
            end)

            it("treats a secret result as a different unit", function()
                _G.UnitIsUnit = function() return secret() end
                local same
                assert.has_no.errors(function() same = CB:IsSameUnit("targettarget", "player") end)
                assert.is_false(same)
            end)
        end)
    end)
end)

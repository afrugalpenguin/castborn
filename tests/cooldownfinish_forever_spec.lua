require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
dofile("Modules/CooldownText_Forever.lua")
dofile("Modules/CooldownFinish_Forever.lua")

describe("Cooldown finish effect on Forever", function()
    local CT = Castborn.CooldownText
    local Finish = CT.Finish
    local secrets = setmetatable({}, { __mode = "k" })
    local function secret() local s = {} secrets[s] = true return s end
    local now, played, realPlay, originalGetTime

    local function visible() return { IsVisible = function() return true end } end

    -- A LibActionButton-style button whose cooldown state the test controls
    local function labButton(state)
        local button = visible()
        button.info = { isActive = state }
        function button:GetCooldownInfo() return self.info end
        local cooldown = {}
        CT.entries[cooldown] = { kind = "actionbar", button = button }
        return cooldown, button
    end

    before_each(function()
        Castborn.db = { cooldowntext = Castborn:DeepCopy(CT.defaults) }
        for k in pairs(CT.entries) do CT.entries[k] = nil end
        for k in pairs(Finish.cooling) do Finish.cooling[k] = nil end
        now, played = 100, {}
        originalGetTime = _G.GetTime
        _G.GetTime = function() return now end
        _G.issecretvalue = function(v) return secrets[v] == true end
        realPlay = Finish.Play
        Finish.Play = function(_, owner) played[#played + 1] = owner end
    end)

    after_each(function()
        Finish.Play = realPlay
        _G.GetTime = originalGetTime
        _G.issecretvalue = nil
        _G.C_ActionBar = nil
    end)

    describe("IsCooling", function()
        it("reads a LibActionButton button's cooldown info", function()
            local cooldown = labButton(true)
            assert.is_true(Finish:IsCooling(cooldown, CT.entries[cooldown]))
        end)

        it("reads a Blizzard button through its action slot", function()
            _G.C_ActionBar = { GetActionCooldown = function(slot) return { isActive = slot == 5 } end }
            local entry = { kind = "actionbar", button = { action = 5 } }
            assert.is_true(Finish:IsCooling({}, entry))
        end)

        it("does not guess when the state is secret", function()
            local cooldown = labButton(secret())
            assert.is_nil(Finish:IsCooling(cooldown, CT.entries[cooldown]))
        end)

        it("uses whether a Castborn icon's cooldown is shown", function()
            local cooldown = { IsShown = function() return true end }
            assert.is_true(Finish:IsCooling(cooldown, { kind = "castborn" }))
        end)
    end)

    describe("finishing", function()
        it("plays the effect when a real cooldown ends", function()
            local cooldown, button = labButton(true)
            Finish:Scan(true)
            now = 130
            button.info.isActive = false
            Finish:Check()
            assert.are.same({ button }, played)
        end)

        it("never plays for the GCD", function()
            local cooldown, button = labButton(true)
            Finish:Scan(true)
            now = 101.5
            button.info.isActive = false
            Finish:Check()
            assert.are.equal(0, #played)
            assert.is_nil(Finish.cooling[cooldown])
        end)

        it("respects a longer minimum duration", function()
            Castborn.db.cooldowntext.minDuration = 5
            local _, button = labButton(true)
            Finish:Scan(true)
            now = 104
            button.info.isActive = false
            Finish:Check()
            assert.are.equal(0, #played)
        end)

        it("keeps watching while the state is secret", function()
            local cooldown, button = labButton(true)
            Finish:Scan(true)
            now = 130
            button.info.isActive = secret()
            Finish:Check()
            assert.are.equal(0, #played)
            assert.are.equal(100, Finish.cooling[cooldown])
        end)

        it("does not watch a button that is only on the GCD", function()
            local cooldown, button = labButton(true)
            button.info.isOnGCD = true
            Finish:Scan(true)
            assert.is_nil(Finish.cooling[cooldown])
        end)

        it("never plays after chained GCDs, however long the chain", function()
            local _, button = labButton(true)
            button.info.isOnGCD = true
            for _ = 1, 10 do      -- one SPELL_UPDATE_COOLDOWN per GCD, never inactive between
                Finish:Scan(true)
                now = now + 1.5
            end
            button.info.isActive, button.info.isOnGCD = false, nil
            Finish:Check()
            assert.are.equal(0, #played)
        end)

        it("watches a real cooldown even while the GCD is also running", function()
            local cooldown, button = labButton(true)
            button.info.isOnGCD = false
            Finish:Scan(true)
            assert.are.equal(100, Finish.cooling[cooldown])
        end)

        it("only picks up action buttons from SPELL_UPDATE_COOLDOWN", function()
            local cooldown = labButton(true)
            Finish:Scan(false)
            assert.is_nil(Finish.cooling[cooldown])
        end)

        it("still picks up Castborn icons from any scan", function()
            local cooldown = { IsShown = function() return true end, GetParent = function() return visible() end }
            CT.entries[cooldown] = { kind = "castborn" }
            Finish:Scan(false)
            assert.are.equal(100, Finish.cooling[cooldown])
        end)

        it("ignores buttons on bars that are turned off", function()
            Castborn.db.cooldowntext.actionBars = false
            labButton(true)
            Finish:Scan(true)
            assert.is_nil(next(Finish.cooling))
        end)
    end)

    describe("IsOn", function()
        it("is off when the effect is none", function()
            Castborn.db.cooldowntext.finishEffect = "none"
            assert.is_false(Finish:IsOn())
        end)

        it("is on by default", function()
            assert.is_true(Finish:IsOn())
        end)
    end)
end)

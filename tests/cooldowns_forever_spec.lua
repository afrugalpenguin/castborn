require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
Castborn.isForever = true  -- set by Compat_Forever.lua on Forever
dofile("Data/SpellData.lua")
dofile("Modules/CooldownGroup.lua")
dofile("Modules/CooldownTracker.lua")
dofile("Modules/CooldownTracker_Forever.lua")

describe("Cooldowns on Forever", function()
    local CT = Castborn.CooldownTracker
    local secrets = setmetatable({}, { __mode = "k" })
    local function secret() local s = {} secrets[s] = true return s end
    local info, dur

    before_each(function()
        _G.issecretvalue = function(v) return secrets[v] == true end
        dur = {}
        _G.C_Spell = {
            GetSpellCooldown = function() return info end,
            GetSpellCooldownDuration = function() return dur end,
        }
    end)

    after_each(function()
        _G.issecretvalue = nil
        _G.C_Spell = nil
        info = nil
    end)

    it("reads plain cooldowns like TBC", function()
        info = { startTime = 100, duration = 30, isActive = true, isOnGCD = false }
        local onCooldown, isLong, start, duration = CT:GetSpellCooldownState("Hammer of Justice")
        assert.is_true(onCooldown)
        assert.is_true(isLong)
        assert.are.equal(100, start)
        assert.are.equal(30, duration)
    end)

    it("treats a plain GCD-length cooldown as ready", function()
        info = { startTime = 100, duration = 1.5, isActive = true, isOnGCD = true }
        assert.is_false(CT:GetSpellCooldownState("Holy Light"))
    end)

    it("uses the flags when the times are secret", function()
        info = { startTime = secret(), duration = secret(), isActive = true, isOnGCD = false }
        local onCooldown, isLong
        assert.has_no.errors(function() onCooldown, isLong = CT:GetSpellCooldownState("Hammer of Justice") end)
        assert.is_true(onCooldown)
        assert.is_true(isLong)
    end)

    it("does not count the GCD as a cooldown when secret", function()
        info = { startTime = secret(), duration = secret(), isActive = true, isOnGCD = true }
        assert.is_false(CT:GetSpellCooldownState("Holy Light"))
    end)

    it("reports nothing for an unknown spell", function()
        assert.is_false(CT:GetSpellCooldownState("Nonexistent"))
    end)

    it("draws secret cooldowns from a duration object", function()
        local got
        local cooldown = { SetCooldownFromDurationObject = function(_, d) got = d end }
        CT:SetIconCooldown(cooldown, "Hammer of Justice", secret(), secret())
        assert.are.equal(dur, got)
    end)

    describe("IsOutOfMana", function()
        it("is true when the power cost cannot be met", function()
            _G.C_Spell.IsSpellUsable = function() return false, true end
            assert.is_true(CT:IsOutOfMana("Holy Shock"))
        end)

        it("is false when the spell is usable", function()
            _G.C_Spell.IsSpellUsable = function() return true, false end
            assert.is_false(CT:IsOutOfMana("Holy Shock"))
        end)

        it("leaves the icon alone when the answer is secret", function()
            _G.C_Spell.IsSpellUsable = function() return secret(), secret() end
            local oom
            assert.has_no.errors(function() oom = CT:IsOutOfMana("Holy Shock") end)
            assert.is_false(oom)
        end)

        it("is false on a client without C_Spell.IsSpellUsable", function()
            assert.is_false(CT:IsOutOfMana("Holy Shock"))
        end)

        describe("IsUnusable", function()
            it("is true when unusable for a reason other than mana", function()
                _G.C_Spell.IsSpellUsable = function() return false, false end
                assert.is_true(CT:IsUnusable("Judgement"))
            end)

            it("is false when the spell is usable", function()
                _G.C_Spell.IsSpellUsable = function() return true, false end
                assert.is_false(CT:IsUnusable("Judgement"))
            end)

            it("is false when only mana is lacking", function()
                _G.C_Spell.IsSpellUsable = function() return false, true end
                assert.is_false(CT:IsUnusable("Judgement"))
            end)

            it("leaves the icon alone when either answer is secret", function()
                local unusable
                _G.C_Spell.IsSpellUsable = function() return secret(), false end
                assert.has_no.errors(function() unusable = CT:IsUnusable("Judgement") end)
                assert.is_false(unusable)
                _G.C_Spell.IsSpellUsable = function() return false, secret() end
                assert.has_no.errors(function() unusable = CT:IsUnusable("Judgement") end)
                assert.is_false(unusable)
            end)

            it("is false on a client without C_Spell.IsSpellUsable", function()
                assert.is_false(CT:IsUnusable("Judgement"))
            end)
        end)

        describe("ready icon colour", function()
            local icon

            before_each(function()
                _G.CreateColor = function(r, g, b, a) return { r, g, b, a } end
                icon = {
                    SetVertexColor = function(self, ...) self.colour = { ... } end,
                    SetVertexColorFromBoolean = function(self, flag, onTrue, onFalse)
                        self.fromBoolean = { flag, onTrue, onFalse }
                    end,
                }
            end)

            after_each(function() _G.CreateColor = nil end)

            it("tints blue from a secret answer, through the texture", function()
                local noMana = secret()
                _G.C_Spell.IsSpellUsable = function() return secret(), noMana end
                CT:SetReadyIconColour(icon, "Holy Shock")
                assert.are.equal(noMana, icon.fromBoolean[1])
                assert.are.same({ 0.5, 0.5, 1, 1 }, icon.fromBoolean[2])
                assert.are.same({ 1, 1, 1, 1 }, icon.fromBoolean[3])
                assert.is_nil(icon.colour)
            end)

            it("uses full colour when the answer is plain", function()
                _G.C_Spell.IsSpellUsable = function() return true, false end
                CT:SetReadyIconColour(icon, "Holy Shock")
                assert.are.same({ 1, 1, 1, 1 }, icon.colour)
                assert.is_nil(icon.fromBoolean)
            end)

            it("uses full colour on a client without C_Spell.IsSpellUsable", function()
                CT:SetReadyIconColour(icon, "Holy Shock")
                assert.are.same({ 1, 1, 1, 1 }, icon.colour)
            end)
        end)
    end)

    describe("GetTrackedSpellName", function()
        local originalGetSpellInfo

        before_each(function()
            originalGetSpellInfo = _G.GetSpellInfo
            -- On Forever these TBC IDs are different spells
            local names = { [12472] = "Cold Snap", [11958] = "Ice Block", [12292] = "Sweeping Strikes" }
            _G.GetSpellInfo = function(id) return names[id] end
        end)

        after_each(function() _G.GetSpellInfo = originalGetSpellInfo end)

        it("names a tracked spell after what its ID is on this client", function()
            assert.are.equal("Cold Snap", CT:GetTrackedSpellName({ spellId = 12472, name = "Icy Veins" }))
            assert.are.equal("Ice Block", CT:GetTrackedSpellName({ spellId = 11958, name = "Cold Snap" }))
            assert.are.equal("Sweeping Strikes", CT:GetTrackedSpellName({ spellId = 12292, name = "Death Wish" }))
        end)

        it("keeps the stored name when the client does not know the ID", function()
            assert.are.equal("Custom Spell", CT:GetTrackedSpellName({ spellId = 999999, name = "Custom Spell" }))
        end)
    end)

    it("draws plain cooldowns with SetCooldown", function()
        local got
        local cooldown = { SetCooldown = function(_, s, d) got = { s, d } end }
        CT:SetIconCooldown(cooldown, "Hammer of Justice", 100, 30)
        assert.are.same({ 100, 30 }, got)
    end)

    describe("GetTargetCreatureType", function()
        local exists, creatureType

        before_each(function()
            exists, creatureType = true, "Undead"
            _G.UnitExists = function() return exists end
            _G.UnitCreatureType = function() return creatureType end
        end)

        after_each(function()
            _G.UnitExists = function() return false end
            _G.UnitCreatureType = nil
        end)

        it("reads a plain creature type", function()
            assert.are.equal("Undead", CT:GetTargetCreatureType())
        end)

        it("reports no target as false", function()
            exists = false
            assert.is_false(CT:GetTargetCreatureType())
        end)

        it("gives up on a secret creature type", function()
            creatureType = secret()
            assert.has_no.errors(function() CT:GetTargetCreatureType() end)
            assert.is_nil(CT:GetTargetCreatureType())
        end)

        it("gives up when whether the target exists is secret", function()
            exists = secret()
            assert.is_nil(CT:GetTargetCreatureType())
        end)
    end)

    -- In combat the creature type is secret, but the range check stays plain: nil when the
    -- spell cannot be cast on the target at all, true or false (in or out of range) when it can
    describe("GetTargetFit with a secret creature type", function()
        local exorcism = { spellId = 879, name = "Exorcism" }
        local inRange, rangeAsked, originalGetSpellInfo

        before_each(function()
            inRange, rangeAsked = nil, nil
            _G.UnitExists = function() return true end
            _G.UnitCreatureType = function() return secret() end
            _G.C_Spell.IsSpellInRange = function(spell, unit)
                rangeAsked = { spell, unit }
                return inRange
            end
            originalGetSpellInfo = _G.GetSpellInfo
            _G.GetSpellInfo = function(id) return id == 879 and "Exorcism" or nil end
        end)

        after_each(function()
            _G.UnitExists = function() return false end
            _G.UnitCreatureType = nil
            _G.GetSpellInfo = originalGetSpellInfo
        end)

        it("fits a target the spell can be cast on, in range", function()
            inRange = true
            assert.is_true(CT:GetTargetFit(exorcism))
            assert.are.same({ "Exorcism", "target" }, rangeAsked)
        end)

        it("fits a target the spell can be cast on, out of range", function()
            inRange = false
            assert.is_true(CT:GetTargetFit(exorcism))
        end)

        it("does not fit a target the spell cannot be cast on", function()
            inRange = nil
            assert.is_false(CT:GetTargetFit(exorcism))
        end)

        it("has no opinion when the range check is secret too", function()
            inRange = secret()
            assert.is_nil(CT:GetTargetFit(exorcism))
        end)

        it("does not check range for spells without a creature type limit", function()
            assert.is_nil(CT:GetTargetFit({ spellId = 853, name = "Hammer of Justice" }))
            assert.is_nil(rangeAsked)
        end)

        it("still uses a plain creature type when it can be read", function()
            _G.UnitCreatureType = function() return "Humanoid" end
            inRange = true
            assert.is_false(CT:GetTargetFit(exorcism))
            assert.is_nil(rangeAsked)
        end)

        it("does not fit with no target, without checking range", function()
            _G.UnitExists = function() return false end
            assert.is_false(CT:GetTargetFit(exorcism))
            assert.is_nil(rangeAsked)
        end)
    end)

    describe("Blizzard's cooldown bars", function()
        local essential, utility, savedDB

        before_each(function()
            essential = CreateFrame("Frame", "EssentialCooldownViewer")
            utility = CreateFrame("Frame", "UtilityCooldownViewer")
            essential:EnableMouse(true)
            utility:EnableMouse(true)
            savedDB = _G.CastbornDB
            _G.CastbornDB = { cooldowns = { enabled = true, hideBlizzardCooldowns = true } }
            CT.hiddenViewers = {}
        end)

        after_each(function()
            _G.EssentialCooldownViewer = nil
            _G.UtilityCooldownViewer = nil
            _G.CastbornDB = savedDB
        end)

        it("fades the Essential and Utility rows and turns their mouse off", function()
            CT:UpdateBlizzardCooldowns()
            assert.are.equal(0, essential:GetAlpha())
            assert.are.equal(0, utility:GetAlpha())
            assert.is_false(essential:IsMouseEnabled())
            assert.is_false(utility:IsMouseEnabled())
        end)

        it("leaves the buff viewers alone", function()
            local buffs = CreateFrame("Frame", "BuffIconCooldownViewer")
            CT:UpdateBlizzardCooldowns()
            assert.are.equal(1, buffs:GetAlpha())
            _G.BuffIconCooldownViewer = nil
        end)

        it("keeps them hidden when Blizzard sets their alpha again", function()
            CT:UpdateBlizzardCooldowns()
            essential:SetAlpha(0.8)
            essential:EnableMouse(true)
            assert.are.equal(0, essential:GetAlpha())
            assert.is_false(essential:IsMouseEnabled())
        end)

        it("restores Blizzard's latest alpha and mouse when the option is turned off", function()
            CT:UpdateBlizzardCooldowns()
            essential:SetAlpha(0.8)
            CastbornDB.cooldowns.hideBlizzardCooldowns = false
            CT:UpdateBlizzardCooldowns()
            assert.are.equal(0.8, essential:GetAlpha())
            assert.are.equal(1, utility:GetAlpha())
            assert.is_true(essential:IsMouseEnabled())
        end)

        it("restores them when the cooldown tracker is disabled", function()
            CT:UpdateBlizzardCooldowns()
            CastbornDB.cooldowns.enabled = false
            CT:UpdateBlizzardCooldowns()
            assert.are.equal(1, essential:GetAlpha())
            assert.is_true(utility:IsMouseEnabled())
        end)

        it("leaves them alone when the option is off", function()
            CastbornDB.cooldowns.hideBlizzardCooldowns = false
            CT:UpdateBlizzardCooldowns()
            assert.are.equal(1, essential:GetAlpha())
        end)

        it("skips viewers this client does not have", function()
            _G.UtilityCooldownViewer = nil
            assert.has_no.errors(function() CT:UpdateBlizzardCooldowns() end)
            assert.are.equal(0, essential:GetAlpha())
        end)

        it("is turned on by default", function()
            _G.CastbornDB = { cooldowns = {} }
            Castborn:FireCallback("INIT")
            assert.is_true(CastbornDB.cooldowns.hideBlizzardCooldowns)
        end)
    end)

    describe("class cooldown lists", function()
        local function ids(list)
            local out = {}
            for _, spell in ipairs(list) do out[spell.spellId] = true end
            return out
        end

        it("leaves out the Paladin's TBC talents", function()
            local paladin = ids(Castborn.SpellData:GetClassCooldowns("PALADIN"))
            assert.is_nil(paladin[31842])  -- Divine Illumination
            assert.is_nil(paladin[31884])  -- Avenging Wrath
            assert.is_nil(paladin[31935])  -- Avenger's Shield
            assert.is_true(paladin[853])   -- Hammer of Justice stays
        end)

        it("lists Swift Judgement once for the Paladin", function()
            local count = 0
            for _, spell in ipairs(Castborn.SpellData:GetClassCooldowns("PALADIN")) do
                if spell.spellId == 1310994 then count = count + 1 end
            end
            assert.are.equal(1, count)
        end)

        it("gives the same list each time", function()
            assert.are.equal(Castborn.SpellData:GetClassCooldowns("PALADIN"),
                Castborn.SpellData:GetClassCooldowns("PALADIN"))
        end)

        it("returns an empty list for an unknown class", function()
            assert.are.same({}, Castborn.SpellData:GetClassCooldowns("NOBODY"))
        end)

        it("drops saved TBC talents from every group, keeping custom entries", function()
            _G.CastbornDB = { cooldowns = { groups = {
                { id = "main", spells = {
                    { spellId = 31842, name = "Divine Illumination" },
                    { spellId = 853, name = "Hammer of Justice" },
                    { spellId = 31884, name = "Avenging Wrath" },
                } },
                { id = "g1", spells = {
                    { spellId = 31935, name = "Avenger's Shield" },
                    { spellId = 31884, name = "Avenging Wrath", custom = true },
                } },
            } } }
            CT:DropSpellsNotOnForever()
            local groups = CastbornDB.cooldowns.groups
            assert.are.same({ { spellId = 853, name = "Hammer of Justice" } }, groups[1].spells)
            assert.are.same({ { spellId = 31884, name = "Avenging Wrath", custom = true } }, groups[2].spells)
        end)
    end)
end)

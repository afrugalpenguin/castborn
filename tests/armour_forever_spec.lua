require("tests.mocks.wow_api")
_G.RAID_CLASS_COLORS = {}
dofile("Core.lua")
Castborn.isForever = true  -- set by Compat_Forever.lua on Forever
dofile("Modules/ArmorTracker.lua")
dofile("Modules/ArmorTracker_Forever.lua")

describe("Armour reminder on Forever", function()
    local AT = Castborn.ArmorTracker
    local secrets = setmetatable({}, { __mode = "k" })
    local function secret() local s = {} secrets[s] = true return s end
    local auras, reads

    before_each(function()
        _G.issecretvalue = function(v) return secrets[v] == true end
        auras, reads = {}, 0
        _G.C_UnitAuras = {
            GetAuraDataByIndex = function(_, i, filter)
                reads = reads + 1
                assert.are.equal("HELPFUL", filter)
                return auras[i]
            end,
        }
        _G.InCombatLockdown = function() return false end
        _G.UnitAffectingCombat = function() return false end
    end)

    after_each(function()
        _G.issecretvalue = nil
        _G.C_UnitAuras = nil
        _G.InCombatLockdown = nil
        _G.UnitAffectingCombat = nil
    end)

    describe("CanReadAuras", function()
        it("reads auras out of combat", function()
            assert.is_true(AT:CanReadAuras())
        end)

        it("does not read auras under combat lockdown", function()
            _G.InCombatLockdown = function() return true end
            assert.is_false(AT:CanReadAuras())
        end)

        it("does not read auras once the player is in combat", function()
            _G.UnitAffectingCombat = function() return true end
            assert.is_false(AT:CanReadAuras())
        end)

        it("does not read auras when they are secret out of combat, as in a dungeon", function()
            _G.C_UnitAuras.GetAuraDataByIndex = function()
                error("Auras cannot be accessed when secret")
            end
            local readable
            assert.has_no.errors(function() readable = AT:CanReadAuras() end)
            assert.is_false(readable)
        end)
    end)

    describe("HasTalent", function()
        local known
        local entry = { talentTab = 2, talentIndex = 7, talentSpellIds = { 20468, 20469, 20470 } }

        before_each(function()
            _G.GetTalentInfo = nil
            known = {}
            _G.IsPlayerSpell = function(id) return known[id] == true end
        end)

        after_each(function() _G.IsPlayerSpell = nil end)

        it("detects any rank of the talent with IsPlayerSpell", function()
            known[20469] = true
            assert.is_true(AT:HasTalent(entry))
        end)

        it("is false when no rank is known", function()
            assert.is_false(AT:HasTalent(entry))
        end)

        it("is false for an entry without talent spell IDs", function()
            known[20468] = true
            assert.is_false(AT:HasTalent({ talentTab = 2, talentIndex = 7 }))
        end)

        it("is false when IsPlayerSpell is missing", function()
            _G.IsPlayerSpell = nil
            assert.is_false(AT:HasTalent(entry))
        end)
    end)

    it("lists Improved Righteous Fury's one Forever rank in SpellData", function()
        dofile("Data/SpellData.lua")
        for _, e in ipairs(Castborn.SpellData:GetClassArmors("PALADIN")) do
            if e.category == "rf" then
                assert.are.same({ 20468 }, e.talentSpellIds)
            end
        end
    end)

    describe("slot icon", function()
        after_each(function() _G.GetSpellTexture = nil end)

        it("skips top ranks this client does not have", function()
            -- Only 10220 exists here; 27124 is a TBC rank
            _G.GetSpellTexture = function(id) return id == 10220 and "ice" or nil end
            local slot = { entry = { spellIds = { 7302, 10220, 27124 } } }
            assert.are.equal("ice", AT:GetSlotTexture(slot))
        end)

        it("prefers the buff seen last", function()
            _G.GetSpellTexture = function(id) return id == 7302 and "seen" or "top" end
            local slot = { lastSpellId = 7302, entry = { spellIds = { 7302, 27124 } } }
            assert.are.equal("seen", AT:GetSlotTexture(slot))
        end)
    end)

    describe("armour lists", function()
        local function names(class)
            dofile("Data/SpellData.lua")
            local out = {}
            for _, e in ipairs(Castborn.SpellData:GetClassArmors(class)) do out[e.name] = true end
            return out
        end

        it("leave out the TBC-only armours and Blessing of Sanctuary", function()
            assert.is_nil(names("MAGE")["Molten Armor"])
            assert.is_nil(names("WARLOCK")["Fel Armor"])
            assert.is_nil(names("PALADIN")["Blessing of Sanctuary"])
            assert.is_true(names("MAGE")["Mage Armor"])
        end)
    end)

    describe("OnPlayerCast", function()
        local hidden

        local function addSlot(spellIds, checkFn)
            local slot = { spellIds = spellIds, checkFn = checkFn }
            slot.frame = { Hide = function() hidden[slot] = true end }
            table.insert(AT:GetSlots(), slot)
            return slot
        end

        before_each(function()
            hidden = {}
            wipe(AT:GetSlots())
        end)

        after_each(function() wipe(AT:GetSlots()) end)

        it("hides the alert when its buff is cast in combat", function()
            _G.InCombatLockdown = function() return true end
            local armour = addSlot({ [7302] = true })
            AT:OnPlayerCast(7302)
            assert.is_true(hidden[armour])
            assert.are.equal(7302, armour.lastSpellId)
        end)

        it("hides the blessing alert on any cast of the blessing", function()
            _G.InCombatLockdown = function() return true end
            local blessing = addSlot({ [19740] = true })
            local rf = addSlot({ [25780] = true })
            AT:OnPlayerCast(19740)
            assert.is_true(hidden[blessing])
            assert.is_nil(hidden[rf])
        end)

        it("ignores casts out of combat, where the buff read is exact", function()
            local armour = addSlot({ [7302] = true })
            AT:OnPlayerCast(7302)
            assert.is_nil(hidden[armour])
        end)

        it("ignores a secret spell ID", function()
            _G.InCombatLockdown = function() return true end
            local armour = addSlot({ [7302] = true })
            assert.has_no.errors(function() AT:OnPlayerCast(secret()) end)
            assert.is_nil(hidden[armour])
        end)

        it("leaves slots with their own check, like the warlock pet, alone", function()
            _G.InCombatLockdown = function() return true end
            local pet = addSlot({ [18708] = true }, function() return false end)
            AT:OnPlayerCast(18708)
            assert.is_nil(hidden[pet])
        end)
    end)

    describe("FindPlayerBuff", function()
        it("finds a tracked buff through C_UnitAuras", function()
            auras = { { spellId = 1126 }, { spellId = 7302 } }
            assert.are.equal(7302, AT:FindPlayerBuff({ [7302] = true }))
        end)

        it("returns nil when no tracked buff is up", function()
            auras = { { spellId = 1126 } }
            assert.is_nil(AT:FindPlayerBuff({ [7302] = true }))
        end)

        it("skips auras whose spell ID is secret", function()
            auras = { { spellId = secret() }, { spellId = 7302 } }
            local found
            assert.has_no.errors(function() found = AT:FindPlayerBuff({ [7302] = true }) end)
            assert.are.equal(7302, found)
        end)

        it("does not read auras in combat", function()
            _G.InCombatLockdown = function() return true end
            auras = { { spellId = 7302 } }
            assert.is_nil(AT:FindPlayerBuff({ [7302] = true }))
            assert.are.equal(0, reads)
        end)
    end)

    describe("FindPlayerBuffByName", function()
        it("finds a buff by name through C_UnitAuras", function()
            auras = { { name = "Arcane Intellect" }, { name = "Well Fed" } }
            assert.is_true(AT:FindPlayerBuffByName("Well Fed"))
        end)

        it("is false when the buff is not up", function()
            auras = { { name = "Food" } }
            assert.is_false(AT:FindPlayerBuffByName("Well Fed"))
        end)

        it("skips auras whose name is secret", function()
            auras = { { name = secret() }, { name = "Well Fed" } }
            local found
            assert.has_no.errors(function() found = AT:FindPlayerBuffByName("Well Fed") end)
            assert.is_true(found)
        end)
    end)
end)

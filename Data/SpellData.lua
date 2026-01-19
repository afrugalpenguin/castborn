-- Data/SpellData.lua
local SpellData = {}
Castborn.SpellData = SpellData

-- Spell school colors
SpellData.schoolColors = {
    [1] = { 1.0, 1.0, 0.5, 1 },    -- Physical (tan)
    [2] = { 1.0, 0.9, 0.5, 1 },    -- Holy (yellow)
    [4] = { 1.0, 0.5, 0.0, 1 },    -- Fire (orange)
    [8] = { 0.5, 1.0, 0.5, 1 },    -- Nature (green)
    [16] = { 0.5, 0.5, 1.0, 1 },   -- Frost (blue)
    [32] = { 0.5, 0.0, 0.5, 1 },   -- Shadow (purple)
    [64] = { 1.0, 0.5, 1.0, 1 },   -- Arcane (pink)
}

-- Class colors (standard WoW)
SpellData.classColors = {
    WARRIOR = { 0.78, 0.61, 0.43, 1 },
    PALADIN = { 0.96, 0.55, 0.73, 1 },
    HUNTER = { 0.67, 0.83, 0.45, 1 },
    ROGUE = { 1.0, 0.96, 0.41, 1 },
    PRIEST = { 1.0, 1.0, 1.0, 1 },
    SHAMAN = { 0.0, 0.44, 0.87, 1 },
    MAGE = { 0.41, 0.80, 0.94, 1 },
    WARLOCK = { 0.58, 0.51, 0.79, 1 },
    DRUID = { 1.0, 0.49, 0.04, 1 },
}

-- Interrupt abilities by class
SpellData.interrupts = {
    WARRIOR = { spellId = 6552, name = "Pummel", cooldown = 10 },
    ROGUE = { spellId = 1766, name = "Kick", cooldown = 10 },
    MAGE = { spellId = 2139, name = "Counterspell", cooldown = 24 },
    SHAMAN = { spellId = 8042, name = "Earth Shock", cooldown = 6 },
}

-- Known DoT/Debuff spells with their colors and durations
SpellData.dots = {
    -- Warlock
    [172] = { name = "Corruption", school = 32, duration = 18 },
    [348] = { name = "Immolate", school = 4, duration = 15 },
    [980] = { name = "Curse of Agony", school = 32, duration = 24 },
    [603] = { name = "Curse of Doom", school = 32, duration = 60 },
    [30108] = { name = "Unstable Affliction", school = 32, duration = 18 },
    [27243] = { name = "Seed of Corruption", school = 32, duration = 18 },
    [18265] = { name = "Siphon Life", school = 32, duration = 30 },

    -- Priest
    [589] = { name = "Shadow Word: Pain", school = 32, duration = 18 },
    [2944] = { name = "Devouring Plague", school = 32, duration = 24 },
    [15487] = { name = "Silence", school = 32, duration = 5 },

    -- Druid
    [8921] = { name = "Moonfire", school = 64, duration = 12 },
    [93402] = { name = "Sunfire", school = 8, duration = 12 },
    [1822] = { name = "Rake", school = 1, duration = 9 },
    [1079] = { name = "Rip", school = 1, duration = 12 },
    [33745] = { name = "Lacerate", school = 1, duration = 15 },
    [5570] = { name = "Insect Swarm", school = 8, duration = 12 },

    -- Mage - Fireball (all ranks, DoT component)
    [133] = { name = "Fireball", school = 4, duration = 8 },
    [143] = { name = "Fireball", school = 4, duration = 8 },
    [145] = { name = "Fireball", school = 4, duration = 8 },
    [3140] = { name = "Fireball", school = 4, duration = 8 },
    [8400] = { name = "Fireball", school = 4, duration = 8 },
    [8401] = { name = "Fireball", school = 4, duration = 8 },
    [8402] = { name = "Fireball", school = 4, duration = 8 },
    [10148] = { name = "Fireball", school = 4, duration = 8 },
    [10149] = { name = "Fireball", school = 4, duration = 8 },
    [10150] = { name = "Fireball", school = 4, duration = 8 },
    [10151] = { name = "Fireball", school = 4, duration = 8 },
    [25306] = { name = "Fireball", school = 4, duration = 8 },
    [27070] = { name = "Fireball", school = 4, duration = 8 },      -- TBC Rank 13
    [38692] = { name = "Fireball", school = 4, duration = 8 },      -- TBC Rank 14

    -- Mage - Pyroblast (all ranks)
    [11366] = { name = "Pyroblast", school = 4, duration = 12 },
    [12505] = { name = "Pyroblast", school = 4, duration = 12 },
    [12522] = { name = "Pyroblast", school = 4, duration = 12 },
    [12523] = { name = "Pyroblast", school = 4, duration = 12 },
    [12524] = { name = "Pyroblast", school = 4, duration = 12 },
    [12525] = { name = "Pyroblast", school = 4, duration = 12 },
    [12526] = { name = "Pyroblast", school = 4, duration = 12 },
    [18809] = { name = "Pyroblast", school = 4, duration = 12 },
    [27132] = { name = "Pyroblast", school = 4, duration = 12 },    -- TBC Rank 9
    [33938] = { name = "Pyroblast", school = 4, duration = 12 },    -- TBC Rank 10

    -- Mage - Slow (Arcane talent)
    [31589] = { name = "Slow", school = 64, duration = 15 },

    -- Mage - Polymorph (all variants)
    [118] = { name = "Polymorph", school = 64, duration = 50 },
    [12824] = { name = "Polymorph", school = 64, duration = 50 },
    [12825] = { name = "Polymorph", school = 64, duration = 50 },
    [12826] = { name = "Polymorph", school = 64, duration = 50 },
    [28271] = { name = "Polymorph: Turtle", school = 64, duration = 50 },
    [28272] = { name = "Polymorph: Pig", school = 64, duration = 50 },

    -- Mage - Other debuffs
    [12654] = { name = "Ignite", school = 4, duration = 4 },        -- Fire talent
    [22959] = { name = "Fire Vulnerability", school = 4, duration = 30 }, -- Improved Scorch

    -- Hunter - Serpent Sting (all ranks)
    [1978] = { name = "Serpent Sting", school = 8, duration = 15 },
    [13549] = { name = "Serpent Sting", school = 8, duration = 15 },
    [13550] = { name = "Serpent Sting", school = 8, duration = 15 },
    [13551] = { name = "Serpent Sting", school = 8, duration = 15 },
    [13552] = { name = "Serpent Sting", school = 8, duration = 15 },
    [13553] = { name = "Serpent Sting", school = 8, duration = 15 },
    [13554] = { name = "Serpent Sting", school = 8, duration = 15 },
    [13555] = { name = "Serpent Sting", school = 8, duration = 15 },
    [25295] = { name = "Serpent Sting", school = 8, duration = 15 },
    [27016] = { name = "Serpent Sting", school = 8, duration = 15 },  -- TBC

    -- Hunter - Other debuffs
    [3034] = { name = "Viper Sting", school = 8, duration = 8 },
    [14279] = { name = "Viper Sting", school = 8, duration = 8 },
    [14280] = { name = "Viper Sting", school = 8, duration = 8 },
    [27018] = { name = "Viper Sting", school = 8, duration = 8 },     -- TBC
    [3043] = { name = "Scorpid Sting", school = 8, duration = 20 },
    [14275] = { name = "Scorpid Sting", school = 8, duration = 20 },
    [14276] = { name = "Scorpid Sting", school = 8, duration = 20 },
    [14277] = { name = "Scorpid Sting", school = 8, duration = 20 },

    -- Rogue - Poisons
    [2818] = { name = "Deadly Poison", school = 8, duration = 12 },
    [2819] = { name = "Deadly Poison", school = 8, duration = 12 },
    [11353] = { name = "Deadly Poison", school = 8, duration = 12 },
    [11354] = { name = "Deadly Poison", school = 8, duration = 12 },
    [25349] = { name = "Deadly Poison", school = 8, duration = 12 },
    [26968] = { name = "Deadly Poison", school = 8, duration = 12 },  -- TBC
    [27187] = { name = "Deadly Poison", school = 8, duration = 12 },  -- TBC
    [8680] = { name = "Wound Poison", school = 8, duration = 15 },
    [8685] = { name = "Wound Poison", school = 8, duration = 15 },
    [8689] = { name = "Wound Poison", school = 8, duration = 15 },
    [11335] = { name = "Wound Poison", school = 8, duration = 15 },
    [11336] = { name = "Wound Poison", school = 8, duration = 15 },
    [27188] = { name = "Wound Poison", school = 8, duration = 15 },   -- TBC
    [703] = { name = "Garrote", school = 1, duration = 18 },
    [8631] = { name = "Garrote", school = 1, duration = 18 },
    [8632] = { name = "Garrote", school = 1, duration = 18 },
    [8633] = { name = "Garrote", school = 1, duration = 18 },
    [11289] = { name = "Garrote", school = 1, duration = 18 },
    [11290] = { name = "Garrote", school = 1, duration = 18 },
    [26839] = { name = "Garrote", school = 1, duration = 18 },
    [26884] = { name = "Garrote", school = 1, duration = 18 },        -- TBC
    [1943] = { name = "Rupture", school = 1, duration = 16 },
    [8639] = { name = "Rupture", school = 1, duration = 16 },
    [8640] = { name = "Rupture", school = 1, duration = 16 },
    [11273] = { name = "Rupture", school = 1, duration = 16 },
    [11274] = { name = "Rupture", school = 1, duration = 16 },
    [11275] = { name = "Rupture", school = 1, duration = 16 },
    [26867] = { name = "Rupture", school = 1, duration = 16 },        -- TBC

    -- Warrior debuffs
    [772] = { name = "Rend", school = 1, duration = 15 },
    [6546] = { name = "Rend", school = 1, duration = 15 },
    [6547] = { name = "Rend", school = 1, duration = 15 },
    [6548] = { name = "Rend", school = 1, duration = 15 },
    [11572] = { name = "Rend", school = 1, duration = 15 },
    [11573] = { name = "Rend", school = 1, duration = 15 },
    [11574] = { name = "Rend", school = 1, duration = 15 },
    [25208] = { name = "Rend", school = 1, duration = 15 },           -- TBC
    [12294] = { name = "Mortal Strike", school = 1, duration = 10 },  -- Healing debuff
    [21551] = { name = "Mortal Strike", school = 1, duration = 10 },
    [21552] = { name = "Mortal Strike", school = 1, duration = 10 },
    [21553] = { name = "Mortal Strike", school = 1, duration = 10 },
    [25248] = { name = "Mortal Strike", school = 1, duration = 10 },  -- TBC
    [30330] = { name = "Mortal Strike", school = 1, duration = 10 },  -- TBC

    -- Shaman debuffs
    [17364] = { name = "Stormstrike", school = 8, duration = 12 },    -- Nature debuff
    [8050] = { name = "Flame Shock", school = 4, duration = 12 },
    [8052] = { name = "Flame Shock", school = 4, duration = 12 },
    [8053] = { name = "Flame Shock", school = 4, duration = 12 },
    [10447] = { name = "Flame Shock", school = 4, duration = 12 },
    [10448] = { name = "Flame Shock", school = 4, duration = 12 },
    [29228] = { name = "Flame Shock", school = 4, duration = 12 },
    [25457] = { name = "Flame Shock", school = 4, duration = 12 },    -- TBC
}

function SpellData:GetSchoolColor(school)
    return self.schoolColors[school] or { 0.7, 0.7, 0.7, 1 }
end

function SpellData:GetClassColor(class)
    return self.classColors[class] or { 1, 1, 1, 1 }
end

function SpellData:GetInterrupt(class)
    return self.interrupts[class]
end

function SpellData:GetDoTInfo(spellId)
    return self.dots[spellId]
end

function SpellData:GetDoTColor(spellId)
    local info = self.dots[spellId]
    if info and info.school then
        return self:GetSchoolColor(info.school)
    end
    return { 0.7, 0.7, 0.7, 1 }
end

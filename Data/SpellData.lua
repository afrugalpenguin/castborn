-- Data/SpellData.lua
local SpellData = {}
Castborn.SpellData = SpellData

-- Spell school colours
SpellData.schoolColors = {
    [1] = { 1.0, 1.0, 0.5, 1 },    -- Physical (tan)
    [2] = { 1.0, 0.9, 0.5, 1 },    -- Holy (yellow)
    [4] = { 1.0, 0.5, 0.0, 1 },    -- Fire (orange)
    [8] = { 0.5, 1.0, 0.5, 1 },    -- Nature (green)
    [16] = { 0.5, 0.5, 1.0, 1 },   -- Frost (blue)
    [32] = { 0.5, 0.0, 0.5, 1 },   -- Shadow (purple)
    [64] = { 1.0, 0.5, 1.0, 1 },   -- Arcane (pink)
}

-- Class colours (standard WoW)
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

-- Interrupt abilities by class, in order of preference: the tracker uses the first one the
-- player knows. Tags as for the cooldowns below (see SpellData:IsForThisClient). Hunters
-- have no interrupt on Forever.
SpellData.interrupts = {
    WARRIOR = {
        { spellId = 6552, name = "Pummel", cooldown = 10 },
        { spellId = 72, name = "Shield Bash", cooldown = 12, forever = true },  -- level 12, Pummel is 38
    },
    ROGUE = { { spellId = 1766, name = "Kick", cooldown = 10 } },
    MAGE = { { spellId = 2139, name = "Counterspell", cooldown = 24 } },
    SHAMAN = { { spellId = 8042, name = "Earth Shock", cooldown = 6 } },
    DRUID = {
        { spellId = 16979, name = "Feral Charge", cooldown = 15, tbc = true },
        { spellId = 1238122, name = "Feral Charge", cooldown = 15, forever = true },
    },
    PRIEST = { { spellId = 15487, name = "Silence", cooldown = 45 } },
    HUNTER = { { spellId = 34490, name = "Silencing Shot", cooldown = 20, tbc = true } },
}

-- Known DoT/Debuff spells with their colours and durations
SpellData.dots = {
    -- Warlock - Corruption (all ranks)
    [172] = { name = "Corruption", school = 32, duration = 18 },
    [6222] = { name = "Corruption", school = 32, duration = 18 },
    [6223] = { name = "Corruption", school = 32, duration = 18 },
    [7648] = { name = "Corruption", school = 32, duration = 18 },
    [11671] = { name = "Corruption", school = 32, duration = 18 },
    [11672] = { name = "Corruption", school = 32, duration = 18 },
    [25311] = { name = "Corruption", school = 32, duration = 18 },
    [27216] = { name = "Corruption", school = 32, duration = 18 },

    -- Warlock - Immolate (all ranks)
    [348] = { name = "Immolate", school = 4, duration = 15 },
    [707] = { name = "Immolate", school = 4, duration = 15 },
    [1094] = { name = "Immolate", school = 4, duration = 15 },
    [2941] = { name = "Immolate", school = 4, duration = 15 },
    [11665] = { name = "Immolate", school = 4, duration = 15 },
    [11667] = { name = "Immolate", school = 4, duration = 15 },
    [11668] = { name = "Immolate", school = 4, duration = 15 },
    [25309] = { name = "Immolate", school = 4, duration = 15 },
    [27215] = { name = "Immolate", school = 4, duration = 15 },

    -- Warlock - Curse of Agony (all ranks)
    [980] = { name = "Curse of Agony", school = 32, duration = 24 },
    [1014] = { name = "Curse of Agony", school = 32, duration = 24 },
    [6217] = { name = "Curse of Agony", school = 32, duration = 24 },
    [11711] = { name = "Curse of Agony", school = 32, duration = 24 },
    [11712] = { name = "Curse of Agony", school = 32, duration = 24 },
    [11713] = { name = "Curse of Agony", school = 32, duration = 24 },
    [27218] = { name = "Curse of Agony", school = 32, duration = 24 },

    -- Warlock - Curse of Doom (all ranks)
    [603] = { name = "Curse of Doom", school = 32, duration = 60 },
    [30910] = { name = "Curse of Doom", school = 32, duration = 60 },

    -- Warlock - Unstable Affliction (all ranks)
    [30108] = { name = "Unstable Affliction", school = 32, duration = 18 },
    [30404] = { name = "Unstable Affliction", school = 32, duration = 18 },
    [30405] = { name = "Unstable Affliction", school = 32, duration = 18 },

    -- Warlock - Seed of Corruption
    [27243] = { name = "Seed of Corruption", school = 32, duration = 18 },

    -- Warlock - Siphon Life (all ranks)
    [18265] = { name = "Siphon Life", school = 32, duration = 30 },
    [18879] = { name = "Siphon Life", school = 32, duration = 30 },
    [18880] = { name = "Siphon Life", school = 32, duration = 30 },
    [18881] = { name = "Siphon Life", school = 32, duration = 30 },
    [27264] = { name = "Siphon Life", school = 32, duration = 30 },

    -- Priest - Shadow Word: Pain (all ranks)
    [589] = { name = "Shadow Word: Pain", school = 32, duration = 18 },
    [594] = { name = "Shadow Word: Pain", school = 32, duration = 18 },
    [970] = { name = "Shadow Word: Pain", school = 32, duration = 18 },
    [992] = { name = "Shadow Word: Pain", school = 32, duration = 18 },
    [2767] = { name = "Shadow Word: Pain", school = 32, duration = 18 },
    [10892] = { name = "Shadow Word: Pain", school = 32, duration = 18 },
    [10893] = { name = "Shadow Word: Pain", school = 32, duration = 18 },
    [10894] = { name = "Shadow Word: Pain", school = 32, duration = 18 },
    [25367] = { name = "Shadow Word: Pain", school = 32, duration = 18 },
    [25368] = { name = "Shadow Word: Pain", school = 32, duration = 18 },

    -- Priest - Devouring Plague (all ranks)
    [2944] = { name = "Devouring Plague", school = 32, duration = 24 },
    [19276] = { name = "Devouring Plague", school = 32, duration = 24 },
    [19277] = { name = "Devouring Plague", school = 32, duration = 24 },
    [19278] = { name = "Devouring Plague", school = 32, duration = 24 },
    [19279] = { name = "Devouring Plague", school = 32, duration = 24 },
    [19280] = { name = "Devouring Plague", school = 32, duration = 24 },
    [25467] = { name = "Devouring Plague", school = 32, duration = 24 },

    [15487] = { name = "Silence", school = 32, duration = 5 },

    -- Priest - Holy Fire (all ranks)
    [14914] = { name = "Holy Fire", school = 2, duration = 10 },
    [15262] = { name = "Holy Fire", school = 2, duration = 10 },
    [15263] = { name = "Holy Fire", school = 2, duration = 10 },
    [15264] = { name = "Holy Fire", school = 2, duration = 10 },
    [15265] = { name = "Holy Fire", school = 2, duration = 10 },
    [15266] = { name = "Holy Fire", school = 2, duration = 10 },
    [15267] = { name = "Holy Fire", school = 2, duration = 10 },
    [15261] = { name = "Holy Fire", school = 2, duration = 10 },
    [25384] = { name = "Holy Fire", school = 2, duration = 10 },

    -- Priest - Vampiric Touch (all ranks)
    [34914] = { name = "Vampiric Touch", school = 32, duration = 15 },
    [34916] = { name = "Vampiric Touch", school = 32, duration = 15 },
    [34917] = { name = "Vampiric Touch", school = 32, duration = 15 },

    -- Druid - Moonfire (all ranks)
    [8921] = { name = "Moonfire", school = 64, duration = 12 },
    [8924] = { name = "Moonfire", school = 64, duration = 12 },
    [8925] = { name = "Moonfire", school = 64, duration = 12 },
    [8926] = { name = "Moonfire", school = 64, duration = 12 },
    [8927] = { name = "Moonfire", school = 64, duration = 12 },
    [8928] = { name = "Moonfire", school = 64, duration = 12 },
    [8929] = { name = "Moonfire", school = 64, duration = 12 },
    [9833] = { name = "Moonfire", school = 64, duration = 12 },
    [9834] = { name = "Moonfire", school = 64, duration = 12 },
    [9835] = { name = "Moonfire", school = 64, duration = 12 },
    [26987] = { name = "Moonfire", school = 64, duration = 12 },
    [26988] = { name = "Moonfire", school = 64, duration = 12 },

    -- Druid - Insect Swarm (all ranks)
    [5570] = { name = "Insect Swarm", school = 8, duration = 12 },
    [24974] = { name = "Insect Swarm", school = 8, duration = 12 },
    [24975] = { name = "Insect Swarm", school = 8, duration = 12 },
    [24976] = { name = "Insect Swarm", school = 8, duration = 12 },
    [24977] = { name = "Insect Swarm", school = 8, duration = 12 },
    [27013] = { name = "Insect Swarm", school = 8, duration = 12 },

    -- Druid - Rake (all ranks)
    [1822] = { name = "Rake", school = 1, duration = 9 },
    [1823] = { name = "Rake", school = 1, duration = 9 },
    [1824] = { name = "Rake", school = 1, duration = 9 },
    [9904] = { name = "Rake", school = 1, duration = 9 },
    [27003] = { name = "Rake", school = 1, duration = 9 },

    -- Druid - Rip (all ranks)
    [1079] = { name = "Rip", school = 1, duration = 12 },
    [9492] = { name = "Rip", school = 1, duration = 12 },
    [9493] = { name = "Rip", school = 1, duration = 12 },
    [9752] = { name = "Rip", school = 1, duration = 12 },
    [9894] = { name = "Rip", school = 1, duration = 12 },
    [9896] = { name = "Rip", school = 1, duration = 12 },
    [27008] = { name = "Rip", school = 1, duration = 12 },

    -- Druid - Lacerate
    [33745] = { name = "Lacerate", school = 1, duration = 15 },

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

    -- Mage - Frostbolt (chill effect, all ranks)
    [116] = { name = "Frostbolt", school = 16, duration = 9 },
    [205] = { name = "Frostbolt", school = 16, duration = 9 },
    [837] = { name = "Frostbolt", school = 16, duration = 9 },
    [7322] = { name = "Frostbolt", school = 16, duration = 9 },
    [8406] = { name = "Frostbolt", school = 16, duration = 9 },
    [8407] = { name = "Frostbolt", school = 16, duration = 9 },
    [8408] = { name = "Frostbolt", school = 16, duration = 9 },
    [10179] = { name = "Frostbolt", school = 16, duration = 9 },
    [10180] = { name = "Frostbolt", school = 16, duration = 9 },
    [10181] = { name = "Frostbolt", school = 16, duration = 9 },
    [25304] = { name = "Frostbolt", school = 16, duration = 9 },
    [27071] = { name = "Frostbolt", school = 16, duration = 9 },     -- TBC Rank 12
    [27072] = { name = "Frostbolt", school = 16, duration = 9 },     -- TBC Rank 13

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

    -- Warlock - Curse of Tongues (all ranks)
    [1714] = { name = "Curse of Tongues", school = 32, duration = 30 },
    [11719] = { name = "Curse of Tongues", school = 32, duration = 30 },

    -- Warlock - Curse of the Elements (all ranks)
    [1490] = { name = "Curse of the Elements", school = 32, duration = 300 },
    [11721] = { name = "Curse of the Elements", school = 32, duration = 300 },
    [11722] = { name = "Curse of the Elements", school = 32, duration = 300 },
    [27228] = { name = "Curse of the Elements", school = 32, duration = 300 },

    -- Warlock - Curse of Recklessness (all ranks)
    [704] = { name = "Curse of Recklessness", school = 32, duration = 120 },
    [7658] = { name = "Curse of Recklessness", school = 32, duration = 120 },
    [7659] = { name = "Curse of Recklessness", school = 32, duration = 120 },
    [11717] = { name = "Curse of Recklessness", school = 32, duration = 120 },
    [27226] = { name = "Curse of Recklessness", school = 32, duration = 120 },

    -- Warlock - Curse of Weakness (all ranks)
    [702] = { name = "Curse of Weakness", school = 32, duration = 120 },
    [1108] = { name = "Curse of Weakness", school = 32, duration = 120 },
    [6205] = { name = "Curse of Weakness", school = 32, duration = 120 },
    [7646] = { name = "Curse of Weakness", school = 32, duration = 120 },
    [11707] = { name = "Curse of Weakness", school = 32, duration = 120 },
    [11708] = { name = "Curse of Weakness", school = 32, duration = 120 },
    [27224] = { name = "Curse of Weakness", school = 32, duration = 120 },

    -- Warrior - Deep Wounds (all ranks)
    [12721] = { name = "Deep Wounds", school = 1, duration = 12 },
    [12834] = { name = "Deep Wounds", school = 1, duration = 12 },
    [12849] = { name = "Deep Wounds", school = 1, duration = 12 },

    -- Hunter - Wyvern Sting DoT (all ranks, nature DoT after sleep)
    [24131] = { name = "Wyvern Sting", school = 8, duration = 12 },
    [24134] = { name = "Wyvern Sting", school = 8, duration = 12 },
    [24135] = { name = "Wyvern Sting", school = 8, duration = 12 },
    [27069] = { name = "Wyvern Sting", school = 8, duration = 12 },     -- TBC

    -- Hunter - Explosive Trap DoT (all ranks)
    [13812] = { name = "Explosive Trap", school = 4, duration = 20 },
    [14314] = { name = "Explosive Trap", school = 4, duration = 20 },
    [14315] = { name = "Explosive Trap", school = 4, duration = 20 },
    [27026] = { name = "Explosive Trap", school = 4, duration = 20 },    -- TBC

    -- Rogue - Crippling Poison
    [3409] = { name = "Crippling Poison", school = 8, duration = 12 },

    -- Rogue - Mind-numbing Poison (all ranks)
    [5760] = { name = "Mind-numbing Poison", school = 8, duration = 14 },
    [8692] = { name = "Mind-numbing Poison", school = 8, duration = 14 },
    [11398] = { name = "Mind-numbing Poison", school = 8, duration = 14 },
}

--------------------------------------------------------------------------------
-- Which client an entry belongs to
--------------------------------------------------------------------------------

-- Castborn runs on TBC Anniversary and on WoW Forever, which share most spell IDs but not
-- all. An entry tagged tbc = true exists only on TBC, forever = true only on Forever, and an
-- untagged entry on both. Where the clients disagree about what an ID is (12472 is Icy Veins
-- on TBC but Cold Snap on Forever), the ID appears twice, once per client. Checked against
-- ForeverDB (Forever client 1.60.1.71091).
function SpellData:IsForThisClient(entry)
    if Castborn.isForever then return not entry.tbc end
    return not entry.forever
end

-- The entries of a list that belong to this client. Built once per list and client, so
-- callers get the same table each time.
local clientLists = setmetatable({}, { __mode = "k" })

function SpellData:ForClient(list)
    if not list then return {} end
    local forever = Castborn.isForever and true or false
    local cached = clientLists[list]
    if cached and cached.forever == forever then return cached.list end
    local out = {}
    for _, entry in ipairs(list) do
        if self:IsForThisClient(entry) then out[#out + 1] = entry end
    end
    clientLists[list] = { forever = forever, list = out }
    return out
end

-- Class cooldowns to track by default. Spells added for Forever are tagged forever even when
-- TBC has them too, so the TBC defaults stay as they were.
SpellData.cooldowns = {
    MAGE = {
        { spellId = 45438, name = "Ice Block", tbc = true },
        { spellId = 11426, name = "Ice Barrier" },
        { spellId = 11958, name = "Cold Snap", tbc = true },
        { spellId = 11958, name = "Ice Block", forever = true },
        { spellId = 12472, name = "Icy Veins", tbc = true },
        { spellId = 12472, name = "Cold Snap", forever = true },
        { spellId = 31687, name = "Summon Water Elemental", tbc = true },
        { spellId = 12042, name = "Arcane Power" },
        { spellId = 12043, name = "Presence of Mind" },
        { spellId = 11129, name = "Combustion" },
        { spellId = 12051, name = "Evocation" },
        { spellId = 2139, name = "Counterspell" },
        { spellId = 11113, name = "Blast Wave" },
        { spellId = 31661, name = "Dragon's Breath", tbc = true },
        { spellId = 1312002, name = "Ice Lance", forever = true },
        { spellId = 1953, name = "Blink", forever = true },
        { spellId = 122, name = "Frost Nova", forever = true },
        { spellId = 120, name = "Cone of Cold", forever = true },
        { spellId = 543, name = "Fire Ward", forever = true },
        { spellId = 6143, name = "Frost Ward", forever = true },
        { spellId = 1326079, name = "Arcane Wrath", forever = true },
    },
    WARLOCK = {
        { spellId = 18708, name = "Fel Domination" },
        { spellId = 17962, name = "Conflagrate" },
        { spellId = 18288, name = "Amplify Curse" },
        { spellId = 17877, name = "Shadowburn" },
        { spellId = 18223, name = "Curse of Exhaustion" },
        { spellId = 6789, name = "Death Coil" },
        { spellId = 5484, name = "Howl of Terror" },
        { spellId = 30283, name = "Shadowfury", tbc = true },
        { spellId = 29858, name = "Soul Shatter", tbc = true },
        { spellId = 6353, name = "Soul Fire", forever = true },
        { spellId = 6229, name = "Shadow Ward", forever = true },
        { spellId = 603, name = "Bane of Doom", forever = true },
        { spellId = 403677, name = "Drain Life", forever = true },
        { spellId = 1122, name = "Inferno", forever = true },
        { spellId = 18540, name = "Ritual of Doom", forever = true },
        { spellId = 437169, name = "Portal of Summoning", forever = true },
    },
    PRIEST = {
        { spellId = 6346, name = "Fear Ward" },
        { spellId = 14751, name = "Inner Focus" },
        { spellId = 10060, name = "Power Infusion" },
        { spellId = 15487, name = "Silence" },
        { spellId = 34433, name = "Shadowfiend", tbc = true },
        { spellId = 32379, name = "Shadow Word: Death", tbc = true },
        { spellId = 1309595, name = "Shadow Word: Death", forever = true },
        { spellId = 33206, name = "Pain Suppression", tbc = true },
        { spellId = 8122, name = "Psychic Scream" },
        { spellId = 402174, name = "Penance", forever = true },
        { spellId = 401859, name = "Prayer of Mending", forever = true },
        { spellId = 586, name = "Fade", forever = true },
        { spellId = 13908, name = "Desperate Prayer", forever = true },
        { spellId = 724, name = "Lightwell", forever = true },
        { spellId = 2651, name = "Elune's Grace", forever = true },
        { spellId = 13896, name = "Feedback", forever = true },
        { spellId = 10797, name = "Starshards", forever = true },
        { spellId = 2944, name = "Devouring Plague", forever = true },
        { spellId = 15286, name = "Vampiric Embrace", forever = true },
        { spellId = 1277331, name = "Chastise", forever = true },
        { spellId = 1277455, name = "Confounding Flash", forever = true },
        { spellId = 1277370, name = "Divine Grace", forever = true },
        { spellId = 1277324, name = "Dark Sacrifice", forever = true },
        { spellId = 1277462, name = "Contingency Plan", forever = true },
    },
    PALADIN = {
        { spellId = 31842, name = "Divine Illumination", tbc = true },
        { spellId = 20216, name = "Divine Favor" },
        { spellId = 31884, name = "Avenging Wrath", tbc = true },
        { spellId = 498, name = "Divine Protection" },  -- rank 1; rank 2 (5573) matches by name
        { spellId = 642, name = "Divine Shield" },
        { spellId = 1044, name = "Blessing of Freedom" },
        { spellId = 853, name = "Hammer of Justice" },
        { spellId = 633, name = "Lay on Hands" },
        { spellId = 1022, name = "Blessing of Protection" },
        { spellId = 20925, name = "Holy Shield" },
        { spellId = 31935, name = "Avenger's Shield", tbc = true },
        { spellId = 20066, name = "Repentance" },
        { spellId = 26573, name = "Consecration" },
        { spellId = 879, name = "Exorcism" },  -- rank 1; other ranks match by name
        { spellId = 1310994, name = "Swift Judgement", forever = true },  -- Protection talent, 60s
        { spellId = 1311015, name = "Templar's Bulwark", forever = true },  -- absorb shield, 5 min
        { spellId = 1311606, name = "Holy Shock", forever = true },
        { spellId = 24275, name = "Hammer of Wrath", forever = true },
        { spellId = 2812, name = "Holy Wrath", forever = true },
        { spellId = 1310897, name = "Voice of Truth", forever = true },
        { spellId = 19752, name = "Divine Intervention", forever = true },
        { spellId = 2878, name = "Turn Undead", forever = true },
    },
    DRUID = {
        { spellId = 17116, name = "Nature's Swiftness" },
        { spellId = 29166, name = "Innervate" },
        { spellId = 22812, name = "Barkskin" },
        { spellId = 33831, name = "Force of Nature", tbc = true },
        { spellId = 18562, name = "Swiftmend" },
        { spellId = 16979, name = "Feral Charge", tbc = true },
        { spellId = 1238122, name = "Feral Charge", forever = true },
        { spellId = 16689, name = "Nature's Grasp" },
        { spellId = 5211, name = "Bash", forever = true },
        { spellId = 5217, name = "Tiger's Fury", forever = true },
        { spellId = 1850, name = "Dash", forever = true },
        { spellId = 22842, name = "Frenzied Regeneration", forever = true },
        { spellId = 740, name = "Tranquility", forever = true },
        { spellId = 20484, name = "Rebirth", forever = true },
        { spellId = 5209, name = "Challenging Roar", forever = true },
        { spellId = 5229, name = "Enrage", forever = true },
        { spellId = 408120, name = "Wild Growth", forever = true },
        { spellId = 407995, name = "Primal Bite", forever = true },
        { spellId = 1322605, name = "Shifting Power", forever = true },
    },
    SHAMAN = {
        { spellId = 16188, name = "Nature's Swiftness" },
        { spellId = 16166, name = "Elemental Mastery", tbc = true },
        { spellId = 16166, name = "Lightning Mastery", forever = true },
        { spellId = 30823, name = "Shamanistic Rage", tbc = true },
        { spellId = 2894, name = "Fire Elemental Totem", tbc = true },
        { spellId = 2062, name = "Earth Elemental Totem", tbc = true },
        { spellId = 974, name = "Earth Shield", tbc = true },
        { spellId = 24398, name = "Water Shield", tbc = true },
        { spellId = 32182, name = "Heroism", tbc = true },
        { spellId = 2825, name = "Bloodlust", tbc = true },
        { spellId = 16190, name = "Mana Tide Totem" },
        { spellId = 8177, name = "Grounding Totem" },
        { spellId = 17364, name = "Stormstrike" },
        { spellId = 408521, name = "Riptide", forever = true },
        { spellId = 425336, name = "Rage of the Farseer", forever = true },
        { spellId = 437009, name = "Totemic Call", forever = true },
        { spellId = 2484, name = "Earthbind Totem", forever = true },
        { spellId = 5730, name = "Stoneclaw Totem", forever = true },
        { spellId = 20608, name = "Reincarnation", forever = true },
    },
    HUNTER = {
        { spellId = 19574, name = "Bestial Wrath" },
        { spellId = 23989, name = "Readiness" },
        { spellId = 19263, name = "Deterrence" },
        { spellId = 3045, name = "Rapid Fire" },
        { spellId = 34490, name = "Silencing Shot", tbc = true },
        { spellId = 19577, name = "Intimidation" },
        { spellId = 5384, name = "Feign Death" },
        { spellId = 34477, name = "Misdirection", tbc = true },
        { spellId = 34026, name = "Kill Command", tbc = true },
        { spellId = 19503, name = "Scatter Shot" },
        { spellId = 19386, name = "Wyvern Sting", tbc = true },
        { spellId = 1499, name = "Freezing Trap", forever = true },
        { spellId = 13809, name = "Frost Trap", forever = true },
        { spellId = 13795, name = "Immolation Trap", forever = true },
        { spellId = 13813, name = "Explosive Trap", forever = true },
        { spellId = 3034, name = "Viper Sting", forever = true },
        { spellId = 1310687, name = "Sniper Shot", forever = true },
        { spellId = 5116, name = "Concussive Shot", forever = true },
        { spellId = 1543, name = "Flare", forever = true },
        { spellId = 1513, name = "Scare Beast", forever = true },
        { spellId = 19801, name = "Tranquilizing Shot", forever = true },
    },
    ROGUE = {
        { spellId = 14177, name = "Cold Blood" },
        { spellId = 13750, name = "Adrenaline Rush" },
        { spellId = 13877, name = "Blade Flurry" },
        { spellId = 14185, name = "Preparation" },
        { spellId = 31224, name = "Cloak of Shadows", tbc = true },
        { spellId = 1856, name = "Vanish" },
        { spellId = 5277, name = "Evasion" },
        { spellId = 2983, name = "Sprint" },
        { spellId = 36554, name = "Shadowstep", tbc = true },
        { spellId = 14183, name = "Premeditation" },
        { spellId = 2094, name = "Blind", forever = true },
        { spellId = 408, name = "Kidney Shot", forever = true },
        { spellId = 1776, name = "Gouge", forever = true },
        { spellId = 14278, name = "Ghostly Strike", forever = true },
        { spellId = 1316709, name = "Death Mark", forever = true },
        { spellId = 1329283, name = "Shank", forever = true },
        { spellId = 1725, name = "Distract", forever = true },
    },
    WARRIOR = {
        { spellId = 12292, name = "Death Wish", tbc = true },
        { spellId = 12292, name = "Sweeping Strikes", forever = true },
        { spellId = 12328, name = "Sweeping Strikes", tbc = true },
        { spellId = 12328, name = "Death Wish", forever = true },
        { spellId = 23881, name = "Bloodthirst" },
        { spellId = 12294, name = "Mortal Strike" },
        { spellId = 871, name = "Shield Wall" },
        { spellId = 1719, name = "Recklessness" },
        { spellId = 18499, name = "Berserker Rage" },
        { spellId = 23920, name = "Spell Reflection" },
        { spellId = 20252, name = "Intercept" },
        { spellId = 5246, name = "Intimidating Shout" },
        { spellId = 12975, name = "Last Stand" },
        { spellId = 20230, name = "Retaliation" },
        { spellId = 72, name = "Shield Bash", forever = true },
        { spellId = 402927, name = "Victory Rush", forever = true },
        { spellId = 1240193, name = "Slam", forever = true },
        { spellId = 1310222, name = "Spearing Strike", forever = true },
        { spellId = 12809, name = "Concussion Blow", forever = true },
        { spellId = 676, name = "Disarm", forever = true },
        { spellId = 2687, name = "Bloodrage", forever = true },
        { spellId = 1161, name = "Challenging Shout", forever = true },
        { spellId = 100, name = "Charge", forever = true },
    },
}

-- Racial cooldowns (keyed by race from select(2, UnitRace("player"))). Draenei and Blood
-- Elves are TBC races.
SpellData.racialCooldowns = {
    Draenei = {
        { spellId = 28880, name = "Gift of the Naaru", tbc = true },
        { spellId = 32548, name = "Symbol of Hope", tbc = true },
    },
    Dwarf = {
        { spellId = 20594, name = "Stoneform" },
    },
    Gnome = {
        { spellId = 20589, name = "Escape Artist" },
    },
    NightElf = {
        { spellId = 20580, name = "Shadowmeld" },
    },
    Human = {
        { spellId = 20600, name = "Perception" },
    },
    Orc = {
        { spellId = 20572, name = "Blood Fury" },   -- AP version (warrior, rogue, hunter)
        { spellId = 33697, name = "Blood Fury", tbc = true },   -- SP version (warlock, mage)
        { spellId = 33702, name = "Blood Fury", tbc = true },   -- AP+SP version (shaman)
    },
    Tauren = {
        { spellId = 20549, name = "War Stomp" },
    },
    Troll = {
        { spellId = 20554, name = "Berserking" },
    },
    Scourge = {
        { spellId = 7744, name = "Will of the Forsaken" },
    },
    BloodElf = {
        { spellId = 28730, name = "Arcane Torrent", tbc = true }, -- mana version
        { spellId = 25046, name = "Arcane Torrent", tbc = true }, -- energy version (rogue)
    },
}

function SpellData:GetClassCooldowns(class)
    return self:ForClient(self.cooldowns[class])
end

function SpellData:GetRacialCooldowns(race)
    return self:ForClient(self.racialCooldowns[race])
end

-- Whether a class or racial default belongs only to the other client, so a saved copy of it
-- can go. An ID this client also lists (under any name) is kept.
function SpellData:IsOtherClientOnly(spellId)
    local forever = Castborn.isForever and true or false
    if not self.otherClientOnly or self.otherClientOnly.forever ~= forever then
        local mine, theirs = {}, {}
        local function scan(lists)
            for _, list in pairs(lists) do
                for _, entry in ipairs(list) do
                    if self:IsForThisClient(entry) then
                        mine[entry.spellId] = true
                    else
                        theirs[entry.spellId] = true
                    end
                end
            end
        end
        scan(self.cooldowns)
        scan(self.racialCooldowns)
        for id in pairs(mine) do theirs[id] = nil end
        self.otherClientOnly = { forever = forever, ids = theirs }
    end
    return self.otherClientOnly.ids[spellId] == true
end

-- Cooldowns that only work on some creature types, keyed by every rank's spell ID (a spell
-- dragged in from the spellbook is stored at the rank the player knows). Values list
-- creature type IDs: 3 Demon, 6 Undead. Forever has ranks 1-6; 27138 is TBC only, which is
-- harmless here as no Forever spell has that ID.
local UNDEAD_OR_DEMON = { 3, 6 }
SpellData.targetCreatureTypes = {
    [879] = UNDEAD_OR_DEMON,    -- Exorcism, ranks 1-7
    [5614] = UNDEAD_OR_DEMON,
    [5615] = UNDEAD_OR_DEMON,
    [10312] = UNDEAD_OR_DEMON,
    [10313] = UNDEAD_OR_DEMON,
    [10314] = UNDEAD_OR_DEMON,
    [27138] = UNDEAD_OR_DEMON,
}

-- Absorb shields (keyed by buff spell ID)
-- school field = school-specific absorb (only absorbs that school), nil = absorbs all
SpellData.absorbs = {
    -- Mage - Ice Barrier (all ranks)
    [11426] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
    [13031] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
    [13032] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
    [13033] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
    [27134] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
    [33405] = { name = "Ice Barrier", duration = 60, class = "MAGE" },

    -- Mage - Mana Shield (all ranks)
    [1463]  = { name = "Mana Shield", duration = 60, class = "MAGE" },
    [8494]  = { name = "Mana Shield", duration = 60, class = "MAGE" },
    [8495]  = { name = "Mana Shield", duration = 60, class = "MAGE" },
    [10191] = { name = "Mana Shield", duration = 60, class = "MAGE" },
    [10192] = { name = "Mana Shield", duration = 60, class = "MAGE" },
    [10193] = { name = "Mana Shield", duration = 60, class = "MAGE" },
    [27131] = { name = "Mana Shield", duration = 60, class = "MAGE" },

    -- Mage - Fire Ward (all ranks) — fire only
    [543]   = { name = "Fire Ward", duration = 30, class = "MAGE", school = 4 },
    [8457]  = { name = "Fire Ward", duration = 30, class = "MAGE", school = 4 },
    [8458]  = { name = "Fire Ward", duration = 30, class = "MAGE", school = 4 },
    [10223] = { name = "Fire Ward", duration = 30, class = "MAGE", school = 4 },
    [10225] = { name = "Fire Ward", duration = 30, class = "MAGE", school = 4 },
    [27128] = { name = "Fire Ward", duration = 30, class = "MAGE", school = 4 },

    -- Mage - Frost Ward (all ranks) — frost only
    [6143]  = { name = "Frost Ward", duration = 30, class = "MAGE", school = 16 },
    [8461]  = { name = "Frost Ward", duration = 30, class = "MAGE", school = 16 },
    [8462]  = { name = "Frost Ward", duration = 30, class = "MAGE", school = 16 },
    [10177] = { name = "Frost Ward", duration = 30, class = "MAGE", school = 16 },
    [28609] = { name = "Frost Ward", duration = 30, class = "MAGE", school = 16 },
    [32796] = { name = "Frost Ward", duration = 30, class = "MAGE", school = 16 },

    -- Warlock - Shadow Ward (all ranks) — shadow only
    [6229]  = { name = "Shadow Ward", duration = 30, class = "WARLOCK", school = 32 },
    [11739] = { name = "Shadow Ward", duration = 30, class = "WARLOCK", school = 32 },
    [11740] = { name = "Shadow Ward", duration = 30, class = "WARLOCK", school = 32 },
    [28610] = { name = "Shadow Ward", duration = 30, class = "WARLOCK", school = 32 },

    -- Warlock - Sacrifice / Voidwalker (all ranks)
    [7812]  = { name = "Sacrifice", duration = 30, class = "WARLOCK" },
    [19438] = { name = "Sacrifice", duration = 30, class = "WARLOCK" },
    [19440] = { name = "Sacrifice", duration = 30, class = "WARLOCK" },
    [19441] = { name = "Sacrifice", duration = 30, class = "WARLOCK" },
    [19442] = { name = "Sacrifice", duration = 30, class = "WARLOCK" },
    [19443] = { name = "Sacrifice", duration = 30, class = "WARLOCK" },
    [27273] = { name = "Sacrifice", duration = 30, class = "WARLOCK" },

    -- Priest - Power Word: Shield (all ranks) — can be external
    [17]    = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [592]   = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [600]   = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [3747]  = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [6065]  = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [6066]  = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [10898] = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [10899] = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [10900] = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [10901] = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [25217] = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
    [25218] = { name = "Power Word: Shield", duration = 30, class = "PRIEST" },
}

-- Armor self-buffs by class (buff spell IDs, all ranks)
-- These are mutually exclusive within each class — having any one means "armor is active".
-- The TBC top ranks (27124 and the like) are not on Forever; they never match a buff there,
-- and the icon skips them. Whole entries are tagged as for the cooldowns.
SpellData.armors = {
    MAGE = {
        { name = "Frost Armor", spellIds = {168, 7300, 7301} },
        { name = "Ice Armor", spellIds = {7302, 7320, 10219, 10220, 27124} },
        { name = "Mage Armor", spellIds = {6117, 22782, 22783, 27125} },
        { name = "Molten Armor", spellIds = {30482}, tbc = true },
    },
    WARLOCK = {
        { name = "Demon Skin", spellIds = {687, 696} },
        { name = "Demon Armor", spellIds = {706, 1086, 11733, 11734, 11735, 27260} },
        { name = "Fel Armor", spellIds = {28176, 28189}, tbc = true },
        { name = "Summon Demon", category = "pet", spellIds = {18708} },  -- Fel Domination icon
    },
    PRIEST = {
        { name = "Inner Fire", spellIds = {588, 7128, 602, 1006, 10951, 10952, 25431} },
    },
    PALADIN = {
        { name = "Blessing of Might",      category = "blessing", key = "might",
          spellIds = {19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140,  -- regular (ranks 1-8)
                      25782, 25916, 27141} },                                    -- greater (ranks 1-3)
        { name = "Blessing of Wisdom",     category = "blessing", key = "wisdom",
          spellIds = {19742, 19850, 19852, 19853, 19854, 25290, 27142,          -- regular (ranks 1-7)
                      25894, 25918, 27143} },                                    -- greater (ranks 1-3)
        { name = "Blessing of Kings",      category = "blessing", key = "kings",
          spellIds = {20217,                                                     -- regular
                      25898} },                                                  -- greater
        { name = "Blessing of Sanctuary",  category = "blessing", key = "sanctuary", tbc = true,
          spellIds = {20911, 20912, 20913, 20914, 27168,                        -- regular (ranks 1-5)
                      25899, 27169} },                                           -- greater (ranks 1-2)
        { name = "Righteous Fury",         category = "rf", key = "rf",
          spellIds = {25780},                                                    -- single rank, same cast and buff ID
          talentTab = 2, talentIndex = 7,                                       -- Protection tree, Improved RF
          talentSpellIds = {20468} },                                            -- Improved RF (Forever check; one rank there)
        { name = "Aura",                   category = "aura", key = "aura",
          spellIds = {7294, 10298, 10299, 10300, 10301, 27150,                  -- Retribution Aura (ranks 1-6)
                      19746,                                                     -- Concentration Aura
                      19876, 19895, 19896, 27151,                                -- Shadow Resistance Aura (ranks 1-4)
                      19888, 19897, 19898, 27152,                                -- Frost Resistance Aura (ranks 1-4)
                      19891, 19899, 19900, 27153,                                -- Fire Resistance Aura (ranks 1-4)
                      20218,                                                     -- Sanctity Aura
                      32223,                                                     -- Crusader Aura
                      465, 10290, 643, 10291, 1032, 10292, 10293, 27149} },     -- Devotion Aura (ranks 1-8, last for icon)
    },
}

function SpellData:GetClassArmors(class)
    local armors = self.armors[class]
    return armors and self:ForClient(armors)
end

-- Well Fed, for the armour tracker's food reminder. Every food's buff is called Well Fed, so the
-- reminder matches the name (read from this ID in the client's language) instead of listing
-- every food's buff ID. The ID also supplies the icon.
SpellData.wellFed = { name = "Well Fed", spellIds = {19705} }

-- Paladin seals for the seal tracker. Seals are matched by spell name (resolved from any ID
-- the client knows), so each lists one or two known IDs rather than every rank.
SpellData.seals = {
    { key = "righteousness", spellIds = {21084, 20154} },
    { key = "command",       spellIds = {20375} },
    { key = "crusader",      spellIds = {21082} },
    { key = "justice",       spellIds = {20164} },
    { key = "light",         spellIds = {20165} },
    { key = "wisdom",        spellIds = {20166} },
    { key = "vengeance",     spellIds = {31801}, tbc = true },
    { key = "blood",         spellIds = {31892}, tbc = true },
    { key = "martyr",        spellIds = {348700}, tbc = true },
    { key = "fury",          spellIds = {1311649}, forever = true },   -- 30s
}

function SpellData:GetSeals()
    return self:ForClient(self.seals)
end

-- Spells that share a seal's name but are not a seal cast (Seal of Command's proc hit)
SpellData.sealIgnoreSpellIds = { [20424] = true }

function SpellData:GetAbsorbInfo(spellId)
    return self.absorbs[spellId]
end

function SpellData:GetSchoolColor(school)
    return self.schoolColors[school] or { 0.7, 0.7, 0.7, 1 }
end

function SpellData:GetClassColor(class)
    return self.classColors[class] or { 1, 1, 1, 1 }
end

-- The class's interrupt on this client: the first the player knows, else the first listed
function SpellData:GetInterrupt(class)
    local list = self:ForClient(self.interrupts[class])
    if #list > 1 then
        for _, entry in ipairs(list) do
            if Castborn:IsSpellKnown(entry.spellId) then return entry end
        end
    end
    return list[1]
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

# Changelog

**v5.3.0**

- Proc Tracker grow direction option — choose Grow Right, Grow Left, or Grow from Centre in Proc Tracker settings

**v5.2.1**

- Fixed BigWigs packager producing duplicate CurseForge uploads

**v5.2.0**

- Castbar colour pickers — global and per-castbar bar colour options in the Castbars settings page
- Per-module background colour pickers for all modules
- Frame appearance system — individual background alpha, show/hide borders
- Global bar font picker in Look & Feel options with LSM support
- Global bar texture picker in Look & Feel options with LSM support
- Tutorial consolidated from 19 steps to 13 with interactive checkboxes
- Appearance customisation step in the welcome tutorial
- Frames are now fully click-through when locked (cooldowns, procs, anchored frames)
- Widened drag header padding so longer labels fit comfortably
- DoT and Totem trackers now respect the show borders setting
- Fixed spell icons showing as grey squares without Masque installed
- Fixed bgOpacity migration for interrupt and multi-DoT trackers

**v4.20.0**

- Full Masque skinning support for all icon-bearing modules (CastBars, InterruptTracker, DoTTracker, TotemTracker, MultiDoTTracker, ArmorTracker)
- Each module has its own Masque group for independent skin control

**v4.19.0**

- Added Armor Tracker — shows an alert icon when your armor self-buff is missing (Mage, Warlock, Priest)

**v4.18.1**

- Fixed Masque skinning for Proc Tracker and Absorb Tracker icons

**v4.18.0**

- Added Absorb Tracker step to the welcome tutorial
- Updated positioning tutorial step with Ctrl+Shift+Click hide tip

**v4.17.1**

- Updated README with Absorb Tracker and Ctrl+Shift hide feature

**v4.17.0**

- Ctrl+Shift+Click on a module header while unlocked temporarily hides it, making it easier to position overlapping frames
- Hidden frames restore automatically when locking or on next unlock

**v4.16.1**

- Fixed absorb tracker cooldown sweep flickering rapidly when taking damage

**v4.16.0**

- Absorb Tracker now supports all TBC absorb spells: Mana Shield, Fire Ward, Frost Ward, Shadow Ward, Sacrifice, and Power Word: Shield
- Multiple simultaneous absorbs display as a row of icons with configurable grow direction
- Power Word: Shield from healers is now tracked on any class
- School-specific absorbs (Fire/Frost/Shadow Ward) show spell-school-coloured borders
- Absorb Tracker available for all classes, not just Mage
- Added spacing and grow direction options to Absorb Tracker settings
- Switched release packaging to BigWigs packager for CurseForge + GitHub

**v4.15.1**

- Fixed absorb tracker not updating remaining value when taking damage

**v4.15.0**

- New Absorb Tracker module for Mages — shows Ice Barrier remaining absorb as a circular shield icon with radial sweep drain
- Shield icon dims and border shifts from blue to red as absorb is consumed
- Absorb amount and duration timer displayed on the shield
- Tooltip scanning for accurate absorb values (accounts for spell power)
- Absorb Tracker options page with size slider (Mage only)

**v4.14.0**

- Nameplate indicators now show the DoT spell icon instead of a plain coloured square
- Nameplate indicator default position moved to Bottom to avoid overlapping debuff icons
- Nameplate indicators now disabled by default (opt-in via options)
- Added position dropdown (Top/Bottom/Left/Right) to Nameplate Indicator options
- Fixed water elemental timer briefly renewing on pet despawn

**v4.13.2**

- Arcane Blast stacking debuff now tracked in Proc Tracker for Mages
- Proc Tracker now scans player debuffs in addition to buffs

**v4.13.1**

- Fixed proc icon size slider not working (was writing to wrong DB table)

**v4.13.0**

- Persistent pulsing glow on proc icons for the full buff duration
- Icon size slider (20–56) in Proc Tracker options
- Show Proc Glow toggle in Proc Tracker options

**v4.12.0**

- Water Elemental pet timer in Proc Tracker for Mages — shows a 45s countdown icon when the pet is summoned

**v4.11.1**

- Fixed castbars and module options pages not scrolling properly due to narrow scroll child width
- Options window widened to prevent slider value text from being clipped

**v4.11.0**

- Global background opacity slider in Look & Feel options
- Options window widened for better slider visibility

- Removed per-module opacity slider from DoT tracker (replaced by global setting)

**v4.10.2**

- Sliders now display clean numeric values (e.g. "0.75" instead of raw floats for decimal steps)

**v4.10.1**

- Castbars options page now scrolls when content exceeds container height
- DoT tracker spacing slider now provides immediate visual feedback
- Added bar height and width sliders to DoT tracker options
- Totem tracker bar height and spacing sliders now provide immediate visual feedback
- Added width slider to totem tracker options
- Multi-dot tracker row text no longer overflows at large row heights
- Fixed FSR default width (220) not matching player castbar / GCD default width (250)

**v4.10.0**

- Width and height sliders for target, focus, and target-of-target castbars
- Width and row height sliders for multi-dot tracker
- Player castbar height slider now also updates shield and font sizes

**v4.9.0**

- Trinket cooldown tracking — equipped trinkets with "Use:" effects now show above the cooldown tracker, with a toggle in options

**v4.8.1**

- Added Holy Concentration Clearcasting proc for Priests

**v4.8.0**

- Proc tracker now matches buffs by name as a fallback, handling rank mismatches gracefully

- Fixed Combustion, Vengeance, Seal of Command, Enrage, Flurry, and Slice and Dice procs not appearing (wrong spellIds)
- Removed Thrill of the Hunt from proc tracker (not a trackable buff)

**v4.7.4**

- Fixed Backlash proc not appearing in proc tracker (was using talent spellId instead of buff spellId)

**v4.7.3**

- Fixed newly added procs not appearing for existing users until settings were reset

**v4.7.2**

- Fixed multi-DoT nameplate indicator disappearing after briefly flashing

**v4.7.1**

- Added Symbol of Hope to cooldown tracker for Draenei priests

**v4.7.0**

- Added Gift of the Naaru to cooldown tracker for Draenei characters (all classes)
- Added racial cooldown support system for race-specific abilities

**v4.6.3**

- Fixed totem tracker party member indicators showing all raid members instead of only the shaman's party subgroup

**v4.6.2**

- Fixed Lua error spam when Earth Shield or Water Shield buff was active (incorrect UnitBuff API usage)
- Increased max displayed cooldowns from 8 to 12 to support all class cooldown lists

**v4.6.1**

- Added missing interrupts for Druid (Feral Charge), Priest (Silence), and Hunter (Silencing Shot)
- Added missing cooldowns across all classes: defensive, utility, and PvP abilities
- Added warlock curses (Tongues, Elements, Recklessness, Weakness) to DoT tracker
- Added Deep Wounds, Wyvern Sting DoT, Explosive Trap DoT, Crippling Poison, and Mind-numbing Poison to DoT tracker

**v4.6.0**

- **Cooldown Drag-and-Drop UX**: Massively improved visual feedback when reordering cooldowns
  - Dragged icon now follows cursor instead of being constrained in place
  - Other icons smoothly shift positions in real-time to show where icon will fit
  - Golden glow effect and move cursor overlay on dragged icon for clarity
  - Other icons dim to 40% and desaturate during drag to create clear contrast
  - Enhanced insertion markers: thicker blue line (4px) with glow, plus slot highlight box
- **Shaman Cooldowns**: Added missing spells to default tracker
  - Earth Shield
  - Water Shield
  - Heroism (Alliance)
  - Bloodlust (Horde)

- Drag headers now positioned above frames instead of overlaying content
- Reduced drag header size for less intrusion when unlocked/in test mode

**v4.5.0**

- Cooldown icon order is now customisable: drag icons to reorder in test mode
- Options panel: up/down arrows to reorder cooldowns (replaces alphabetical sorting)
- What's New: animated swap demo for the cooldown reorder feature
- Tutorial: updated Cooldown Tracker step with reorder instructions

**v4.4.0**

- Added "Show Spell Rank" option for player castbar (displays rank like "Frostbolt (Rank 7)")

**v4.3.0**

- Totem Tracker: Added party coverage indicator showing who's in range (●●●○○)
- Green when all party members buffed, yellow for partial, hidden for offensive totems

**v4.2.0**

- Added "Hide Tradeskill Casts" option for player castbar (hides crafting progress)

- Added luacheck static analysis with GitHub Actions CI
- Added unit test framework (busted) with tests for Core, Anchoring, and Profiles
- Fixed code quality issues (removed dead code, improved table-empty checks)

**v4.1.3**

- Added Totem Tracker to onboarding tutorial (Shaman only)

**v4.1.2**

- Fixed `/cb lock` not dismissing the test mode panel

**v4.1.1**

- Totem Tracker now sorts by soonest to expire (most urgent at top)

**v4.1.0**

- Totem Tracker (Shaman): Track active totems with duration bars
- Bar-based UI showing remaining time for each totem element (Fire, Earth, Water, Air)
- Mouseover tooltip shows party members NOT in range of beneficial totems
- Offensive totems (Searing, Magma, etc.) skip party coverage display
- Test mode available for all classes to preview the feature

- Drag indicators now use a compact handle at the top of frames
- Allows tooltips to work while frames are unlocked
- Test mode automatically unlocks frames for positioning

**v4.0.0**

- Profile Management UI: Create, copy, delete, and switch between profiles
- Import/Export: Share profiles with other players via encoded strings
- Per-character profile selection with shared profile storage

**v3.3.1**

- DoT Tracker now uses SpellData for colours instead of duplicated local tables
- Fixed modules listening for non-existent PLAYER_CASTBAR_READY event (now uses PLAYER_CASTBAR_CREATED)

- All modules now use consistent RegisterModule() pattern
- Removed unused global functions from FiveSecondRule and GCDIndicator

**v3.3.0**

- Interrupt Tracker: Track Target/Focus now highlights bar yellow when interrupt opportunity available
- Multi-DoT Tracker: Sort by Time option (enabled by default, sorts by urgency)

- Renamed "Buff Tracker" to "Proc Tracker" in options
- Fixed Proc Tracker "Show Timers" checkbox not working (was saving to wrong key)
- Fixed castbar Show Icon/Time/Spell Name/Latency toggles requiring reload
- All castbar display options now apply immediately when changed

**v3.2.2**

- Multi-DoT nameplate indicator now only shows on the most urgent target (lowest DoT timer)

- Fixed Warlock Shadow Trance (Nightfall) proc not being tracked correctly

**v3.2.1**

- Fixed Lua error in Multi-DoT nameplate indicators

**v3.2.0**

- Multi-DoT Tracker: Added nameplate indicators showing DoT timers directly on enemy nameplates
- Helps identify which mob needs attention when multiple mobs share the same name
- Works with Plater and default nameplates

**v3.1.6**

- Fixed procs and cooldowns not loading correctly when switching between characters of different classes

**v3.1.5**

- Hide ToT castbar when target is self-targeting (prevents redundant castbar display)

**v3.1.4**

- Added Summon Water Elemental to Mage cooldown options

**v3.1.3**

- Improved castbar and GCD state handling during rapid casting/key presses

**v3.1.2**

- Fixed castbar getting stuck on screen when opening the world map during a cast

**v3.1.1**

- Fixed Ice Barrier (and other multi-rank talent spells) not being tracked by the Cooldown Tracker

**v3.1.0**

- Cooldown Tracker: added Icon Size, Spacing, and Grow Left options
- Cooldown Tracker: test mode now shows your actual configured spells
- Module options pages now scroll when content overflows

- Fixed missing cooldowns (Ice Barrier, Icy Veins) not appearing in options or tracker
- Removed dead "Show Icons" option that had no effect

**v3.0.0**

- Cooldown Tracker: per-spell enable/disable checkboxes (replaces unused Min Duration slider)

**v2.8.2**

- Improved default positions: DoT tracker now mirrors cooldowns (right of castbar), Multi-DoT next to it

**v2.8.1**

- Frames now auto-lock when entering combat (prevents getting stuck in test mode)

**v2.8.0**

- Added "Changelog" menu item in options (under Profiles) with scrollable version history
- Multi-DoT Tracker: Ctrl+Click on a row to target that mob (requires visible nameplate)

- Multi-DoT Tracker now shows actual debuff durations instead of hardcoded values (fixes Polymorph showing wrong time)

**v2.7.0**

- Cooldown tracker now auto-merges new default spells when addon updates (no more missing spells after upgrades)
- Added "What's New" overlay that shows changelog when opening `/cb` after an addon update

**v2.6.12**

- Implemented "Anchor to Castbar" for DoT Tracker, Swing Timer, and Proc Tracker
- All anchorable modules now properly follow the player castbar when moved

- Fixed `/cb reset` not resetting Swing Timer and other modules with anchoring

- Reorganised README with clearer sections and added missing commands

**v2.6.11**

- Fixed options sliders sliding vertically instead of horizontally
- Improved slider aesthetics with progress fill bar and native WoW thumb
- Exclude self-casts from non-player castbars (target/ToT/focus no longer show your casts when those units are you)

**v2.6.10**

- Added Fear Ward to Priest cooldown tracking

**v2.6.9**

- Added Holy Fire to Priest Multi-DoT tracking

**v2.6.8**

- Added all ranks of Druid DoTs (Moonfire, Insect Swarm, Rake, Rip)

**v2.6.7**

- Added all ranks of Warlock DoTs (Corruption, Immolate, Curse of Agony, Curse of Doom, Unstable Affliction, Siphon Life)
- Removed Sunfire (not in TBC)

**v2.6.6**

- Added Vampiric Touch to Priest Multi-DoT tracking

**v2.6.5**

- Added all ranks of Shadow Word: Pain and Devouring Plague for Priest Multi-DoT tracking

**v2.6.4**

- Fixed proc tracker icons showing as grey boxes (draw layer issue)

**v2.6.3**

- Proc tracker duration now updates smoothly every 0.1s instead of only on buff changes

**v2.6.2**

- Fixed CurseForge changelog display

**v2.6.1**

- Added Ice Barrier to Mage default cooldowns

**v2.6.0**

- Added default cooldown tracking for Druid, Shaman, Hunter, Rogue, and Warrior
- All 9 classes now have default cooldowns configured

**v2.5.1**

- Added Ice Block to Mage default cooldowns
- Fixed upgrade migration so existing users get new default cooldowns

**v2.5.0**

- Added default cooldown tracking for Mage, Priest, Warlock, and Paladin
- Cooldown tracker now automatically shows class-relevant abilities (Cold Snap, Icy Veins, etc.)

**v2.4.2**

- Profiles section now shows "Coming Soon" (not yet implemented)

**v2.4.1**

- Updated Interface version for TBC Anniversary (2.5.5)

**v2.4.0**

- Removed duplicate "Enabled" checkboxes from individual module settings
- Module enable/disable toggles now only on General screen to avoid confusion

**v2.3.1**

- Fixed CurseForge showing incorrect version number

**v2.3.0**

- Player castbar now uses class colours by default
- Added "Look & Feel" section in options with class colours toggle
- Added divider in options menu to separate module settings from appearance/profiles

**v2.2.0**

- Added option to hide default Blizzard cast bar (under Player Castbar settings)

**v2.1.0**

- Adjusted default positions for target-of-target and focus castbars to avoid overlap with action bars
- Fixed release zip containing lowercase folder name causing addon to fail to load

**v2.0.0**

- Player, target, focus, and target-of-target castbars
- GCD indicator
- Five Second Rule tracker
- Swing timers (mainhand, offhand, ranged)
- DoT tracker
- Multi-DoT tracker
- Cooldown tracker
- Proc tracker
- Interrupt tracker

- Fixed combat log API for TBC Anniversary (use CombatLogGetCurrentEventInfo)
- Fixed options panel sliders not displaying
- Multi-DoT tracker now shows with 1+ targets (was 2+)
- Multi-DoT tracker hides current target (only shows other targets)
- Multi-DoT bar no longer overflows container
- Multi-DoT layout: icons first, then mob name
- Multi-DoT name positioning is now dynamic based on number of dots
- Added Frostbolt slow to tracked spells for Mage
- Added C_Timer.After fallback for addon initialization

- `/cb` - Open options
- `/cb unlock` - Unlock frames
- `/cb lock` - Lock frames
- `/cb test` - Test mode
- `/cb reset` - Reset positions

# Changelog

## v3.1.6

### Fixes
- Fixed procs and cooldowns not loading correctly when switching between characters of different classes

## v3.1.5

### Fixes
- Hide ToT castbar when target is self-targeting (prevents redundant castbar display)

## v3.1.4

### Features
- Added Summon Water Elemental to Mage cooldown options

## v3.1.3

### Fixes
- Improved castbar and GCD state handling during rapid casting/key presses

## v3.1.2

### Fixes
- Fixed castbar getting stuck on screen when opening the world map during a cast

## v3.1.1

### Fixes
- Fixed Ice Barrier (and other multi-rank talent spells) not being tracked by the Cooldown Tracker

## v3.1.0

### Features
- Cooldown Tracker: added Icon Size, Spacing, and Grow Left options
- Cooldown Tracker: test mode now shows your actual configured spells
- Module options pages now scroll when content overflows

### Fixes
- Fixed missing cooldowns (Ice Barrier, Icy Veins) not appearing in options or tracker
- Removed dead "Show Icons" option that had no effect

## v3.0.0

### Features
- Cooldown Tracker: per-spell enable/disable checkboxes (replaces unused Min Duration slider)

## v2.8.2

### Fixes
- Improved default positions: DoT tracker now mirrors cooldowns (right of castbar), Multi-DoT next to it

## v2.8.1

### Fixes
- Frames now auto-lock when entering combat (prevents getting stuck in test mode)

## v2.8.0

### Features
- Added "Changelog" menu item in options (under Profiles) with scrollable version history
- Multi-DoT Tracker: Ctrl+Click on a row to target that mob (requires visible nameplate)

### Fixes
- Multi-DoT Tracker now shows actual debuff durations instead of hardcoded values (fixes Polymorph showing wrong time)

## v2.7.0

### Features
- Cooldown tracker now auto-merges new default spells when addon updates (no more missing spells after upgrades)
- Added "What's New" overlay that shows changelog when opening `/cb` after an addon update

## v2.6.12

### Features
- Implemented "Anchor to Castbar" for DoT Tracker, Swing Timer, and Proc Tracker
- All anchorable modules now properly follow the player castbar when moved

### Fixes
- Fixed `/cb reset` not resetting Swing Timer and other modules with anchoring

### Docs
- Reorganized README with clearer sections and added missing commands

## v2.6.11

### Fixes
- Fixed options sliders sliding vertically instead of horizontally
- Improved slider aesthetics with progress fill bar and native WoW thumb
- Exclude self-casts from non-player castbars (target/ToT/focus no longer show your casts when those units are you)

## v2.6.10

### Fixes
- Added Fear Ward to Priest cooldown tracking

## v2.6.9

### Fixes
- Added Holy Fire to Priest Multi-DoT tracking

## v2.6.8

### Fixes
- Added all ranks of Druid DoTs (Moonfire, Insect Swarm, Rake, Rip)

## v2.6.7

### Fixes
- Added all ranks of Warlock DoTs (Corruption, Immolate, Curse of Agony, Curse of Doom, Unstable Affliction, Siphon Life)
- Removed Sunfire (not in TBC)

## v2.6.6

### Fixes
- Added Vampiric Touch to Priest Multi-DoT tracking

## v2.6.5

### Fixes
- Added all ranks of Shadow Word: Pain and Devouring Plague for Priest Multi-DoT tracking

## v2.6.4

### Fixes
- Fixed proc tracker icons showing as grey boxes (draw layer issue)

## v2.6.3

### Fixes
- Proc tracker duration now updates smoothly every 0.1s instead of only on buff changes

## v2.6.2

### Fixes
- Fixed CurseForge changelog display

## v2.6.1

### Features
- Added Ice Barrier to Mage default cooldowns

## v2.6.0

### Features
- Added default cooldown tracking for Druid, Shaman, Hunter, Rogue, and Warrior
- All 9 classes now have default cooldowns configured

## v2.5.1

### Fixes
- Added Ice Block to Mage default cooldowns
- Fixed upgrade migration so existing users get new default cooldowns

## v2.5.0

### Features
- Added default cooldown tracking for Mage, Priest, Warlock, and Paladin
- Cooldown tracker now automatically shows class-relevant abilities (Cold Snap, Icy Veins, etc.)

## v2.4.2

### Changes
- Profiles section now shows "Coming Soon" (not yet implemented)

## v2.4.1

### Fixes
- Updated Interface version for TBC Anniversary (2.5.5)

## v2.4.0

### Changes
- Removed duplicate "Enabled" checkboxes from individual module settings
- Module enable/disable toggles now only on General screen to avoid confusion

## v2.3.1

### Fixes
- Fixed CurseForge showing incorrect version number

## v2.3.0

### Features
- Player castbar now uses class colors by default
- Added "Look & Feel" section in options with class colors toggle
- Added divider in options menu to separate module settings from appearance/profiles

## v2.2.0

### Features
- Added option to hide default Blizzard cast bar (under Player Castbar settings)

## v2.1.0

### Fixes
- Adjusted default positions for target-of-target and focus castbars to avoid overlap with action bars
- Fixed release zip containing lowercase folder name causing addon to fail to load

## v2.0.0

### Features
- Player, target, focus, and target-of-target castbars
- GCD indicator
- Five Second Rule tracker
- Swing timers (mainhand, offhand, ranged)
- DoT tracker
- Multi-DoT tracker
- Cooldown tracker
- Proc tracker
- Interrupt tracker

### Fixes & Improvements
- Fixed combat log API for TBC Anniversary (use CombatLogGetCurrentEventInfo)
- Fixed options panel sliders not displaying
- Multi-DoT tracker now shows with 1+ targets (was 2+)
- Multi-DoT tracker hides current target (only shows other targets)
- Multi-DoT bar no longer overflows container
- Multi-DoT layout: icons first, then mob name
- Multi-DoT name positioning is now dynamic based on number of dots
- Added Frostbolt slow to tracked spells for Mage
- Added C_Timer.After fallback for addon initialization

### Slash Commands
- `/cb` - Open options
- `/cb unlock` - Unlock frames
- `/cb lock` - Lock frames
- `/cb test` - Test mode
- `/cb reset` - Reset positions

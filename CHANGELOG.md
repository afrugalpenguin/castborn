# Changelog

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

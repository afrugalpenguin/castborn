# Changelog

## v1.0.0

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

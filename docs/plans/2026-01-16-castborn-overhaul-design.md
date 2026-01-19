# Castborn Overhaul Design

**Target:** TBC Anniversary (3 weeks)
**Scope:** Full overhaul - visual polish, new features, better UX, profiles

## Core Philosophy

The castbar is king. All other modules are optional satellites that can attach to it or float independently. Everything is toggleable. Smart defaults that just work, with advanced options hidden but accessible.

## Architecture

```
Castborn (Core)
├── Castbars (heart of the addon)
│   ├── Player Castbar (primary)
│   │   └── 5 Second Rule (anchored ABOVE by default, detachable, thin pulse line)
│   │   └── GCD Indicator (anchored below by default, detachable)
│   ├── Target Castbar
│   ├── Target-of-Target Castbar
│   └── Focus Castbar
├── Combat Modules (toggleable)
│   ├── DoT Tracker (single target - existing)
│   ├── Multi-DoT Tracker (new)
│   ├── Swing Timer (existing)
│   ├── Buff/Proc Tracker (new)
│   ├── Cooldown Tracker (new)
│   └── Interrupt Tracker (new)
└── Systems
    ├── Skin Engine (4 themes)
    ├── Profile Manager
    ├── Grid Positioning System
    └── Options Panel (redesigned)
```

## Skin System

Four themes, switchable instantly:

1. **Minimalist Modern** (default) - Flat colors, thin 1px borders, subtle transparency, micro-animations
2. **Classic WoW** - Blizzard-style textures, gold/bronze borders, familiar feel
3. **Sleek/Futuristic** - Glowing edges, gradients, semi-transparent, animated sparks
4. **Pixel Retro** - Sharp 1px borders, solid block colors, chunky, high-contrast

## Color Modes

User chooses between:
- **Spell school colors** - Frost blue, Fire orange, Shadow purple, Nature green, Arcane pink, Holy yellow, Physical gray
- **Class colors** - Standard WoW class colors
- **Custom** - User picks their own

## New Modules

### Buff/Proc Tracker
- Horizontal or vertical icon bar
- Auto-populated with class-relevant procs (Clearcasting, Nightfall, Vengeance, etc.)
- User can add custom spell IDs
- Shows: icon, duration, stacks
- Glow/pulse on proc fire
- Can anchor to player castbar or float

### Cooldown Tracker
- Row of ability icons with sweep/countdown
- User selects spells to track
- Smart mode suggests key cooldowns per class
- Dims on CD, glows when ready

### Interrupt Tracker
- Your interrupt ability with cooldown
- Enemy school lockout timer on successful interrupt
- Visual feedback on successful kick

### Multi-DoT Tracker
Three display modes:
1. **Nameplate mode** - Icons with timers on nameplates
2. **Panel mode** - List: [target name] [dot icons + timers]
3. **Grid mode** - Rows = targets, columns = DoTs

**Target Cycling Indicator:**
- Prioritized list of targets needing DoT refresh
- Sorted by urgency (red = NOW, yellow = soon, green = healthy)
- Helps with tab-dot rotation

## Default Layout

```
                    ┌─────────────────────────┐
                    │   Target Castbar        │
                    └─────────────────────────┘
                    ┌───────────────────────┐
                    │   Target-of-Target    │
                    └───────────────────────┘

                    │ 5SR ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔ │  ← thin pulse line ABOVE
                    ┌─────────────────────────┐
                    │   Player Castbar        │
                    ├─────────────────────────┤
                    │ GCD ████████░░░░░░░░░░░ │  ← anchored below
                    └─────────────────────────┘

    ┌──────────────┐                         ┌──────────────┐
    │ Swing Timers │                         │  DoT Tracker │
    └──────────────┘                         └──────────────┘

    ┌──────────────┐                         ┌──────────────┐
    │  Cooldowns   │                         │ Buff/Procs   │
    └──────────────┘                         └──────────────┘

                    ┌─────────────────────────┐
                    │   Focus Castbar         │
                    └─────────────────────────┘
```

All positioned towards bottom of screen.

## Class-Specific Defaults (TBC)

| Class | 5SR | Swing | Suggested Procs | Suggested CDs |
|-------|-----|-------|-----------------|---------------|
| Mage | Yes | - | Clearcasting | Icy Veins, Combustion, AP |
| Warlock | Yes | - | Nightfall, Backlash | - |
| Priest | Yes | - | Spirit Tap, Surge of Light | Inner Focus |
| Druid | Yes | Feral | Clearcasting | Innervate |
| Paladin | Yes | Yes | Vengeance | Avenging Wrath |
| Shaman | Yes | Enh | Clearcasting | Bloodlust |
| Hunter | Yes | Ranged | - | Rapid Fire, Bestial Wrath |
| Warrior | - | Yes | Overpower proc | Recklessness, Death Wish |
| Rogue | - | Yes | Sword Spec, Riposte | Blade Flurry, AR |

## Options Panel

```
┌─────────────────────────────────────────────┐
│ Castborn Options                        [X] │
├─────────────┬───────────────────────────────┤
│ ▸ General   │                               │
│   Profiles  │   [Content area]              │
│   Skins     │                               │
│ ▸ Castbars  │                               │
│ ▸ Modules   │                               │
│─────────────│───────────────────────────────│
│ [Advanced ▾]│              [Test Mode] [?]  │
└─────────────┴───────────────────────────────┘
```

- Progressive disclosure: basic options visible, advanced tucked away
- Search/filter to find options
- Profiles: per-character, copy between characters

## Grid Positioning Mode

- "Enter Positioning Mode" button
- Semi-transparent grid overlay (10px/20px/50px options)
- All frames draggable with visible anchors
- Snap-to-grid toggle
- Shows coordinates while dragging

## Anchoring System

- Any module can anchor to any other (top/bottom/left/right)
- Anchored modules move with parent
- Detach creates independent position
- Re-anchor snaps back with last offset

## File Structure

```
Castborn/
├── Castborn.toc
├── Core.lua
├── Modules/
│   ├── CastBars.lua
│   ├── GCDIndicator.lua
│   ├── FiveSecondRule.lua
│   ├── SwingTimer.lua
│   ├── DoTTracker.lua
│   ├── MultiDoTTracker.lua    # NEW
│   ├── BuffTracker.lua        # NEW
│   ├── CooldownTracker.lua    # NEW
│   └── InterruptTracker.lua   # NEW
├── Systems/
│   ├── SkinEngine.lua
│   ├── Profiles.lua
│   ├── Anchoring.lua
│   ├── ClassDefaults.lua
│   └── GridPosition.lua
├── Options/
│   ├── Options.lua
│   └── Widgets.lua
├── Skins/
│   ├── Minimalist.lua
│   ├── Classic.lua
│   ├── Sleek.lua
│   └── Retro.lua
└── Data/
    └── SpellData.lua
```

## Implementation Phases

### Phase 1 - Core Polish
- Anchoring system (5SR + GCD attach to player castbar)
- Skin engine + 4 themes
- Revised default layout
- Profile system

### Phase 2 - New Modules
- Buff/Proc tracker with TBC class defaults
- Cooldown tracker
- Interrupt tracker
- Multi-DoT tracker (panel mode first)

### Phase 3 - UX Polish
- Options panel redesign
- Grid positioning mode
- Search/filter in options
- Target cycling indicator
- Testing across all classes

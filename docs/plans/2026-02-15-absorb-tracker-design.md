# Absorb Tracker MVP — Design

## Summary

A new AbsorbTracker module that shows a draining bar with numeric text when Ice Barrier is active on a mage. Scoped to Ice Barrier only for the MVP, with architecture that supports adding more absorb shields later.

## Visual

- Horizontal StatusBar using the same style as SwingTimer/FSR (CreateBackdrop, inset StatusBar)
- Default icy blue color (0.4, 0.7, 1.0, 1.0)
- Left text: "Ice Barrier"
- Right text: remaining absorb + duration (e.g., "2,847 | 42s")
- Fade in on buff applied, fade out on buff removed (~0.3s)
- Standalone, draggable, percentage-based positioning via Anchoring.lua

## Detection

1. `COMBAT_LOG_EVENT_UNFILTERED` -> `SPELL_AURA_APPLIED` for Ice Barrier (source = player) -> tooltip scan once to get initial absorb value -> show bar with fade in
2. Combat log damage events (`SWING_DAMAGE`, `SPELL_DAMAGE`, `RANGE_DAMAGE`, `SPELL_PERIODIC_DAMAGE`) where dest is player and `absorbed > 0` while Ice Barrier is active -> subtract absorbed amount from remaining -> update bar fill and text
3. `SPELL_AURA_REMOVED` for Ice Barrier -> fade out bar
4. Recast while active: reset bar to new full absorb value and restart duration timer

## Module Structure

- File: `Modules/AbsorbTracker.lua`
- Standard Castborn module pattern (local table, RegisterCallback INIT/READY, RegisterModule)
- DB key: `CastbornDB.absorbs`
- Registers with TestManager for `/cb test` support

## Default Settings

- `enabled` (bool, default true for mages)
- `width` (default 250)
- `barHeight` (default 20)
- `barColor` ({0.4, 0.7, 1.0, 1.0})
- `bgColor`, `borderColor` (standard Castborn defaults)
- `xPct`, `yPct` (percentage positioning)

## Options Panel

- New "Absorb Tracker" section in Options.lua
- Enable/disable checkbox
- Width slider
- Height slider

## Spell Data

Ice Barrier buff spell IDs (all ranks) stored in SpellData.lua under MAGE absorbs section. Initial absorb value obtained via tooltip scan on buff application (handles spell power scaling).

## Scope

- Ice Barrier only (mage class restriction for MVP)
- Self-cast absorbs only
- Architecture supports expanding to Mana Shield, Shadow Ward, PW:S, etc. in future versions

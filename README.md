<p align="center">
  <img src="images/banner.png" width="800" alt="Castborn: castbars and combat tracking for WoW Forever and TBC Anniversary">
</p>

<p align="center">
  <a href="https://github.com/afrugalpenguin/Castborn/releases"><img src="https://img.shields.io/github/v/tag/afrugalpenguin/Castborn?label=version" alt="Version"></a>
  <a href="https://github.com/afrugalpenguin/Castborn/actions/workflows/luacheck.yml"><img src="https://github.com/afrugalpenguin/Castborn/actions/workflows/luacheck.yml/badge.svg" alt="Luacheck"></a>
  <img src="https://img.shields.io/badge/WoW-Forever-8a3fd1" alt="WoW Forever">
  <img src="https://img.shields.io/badge/WoW-TBC%20Anniversary-blue" alt="WoW TBC Anniversary">
  <a href="https://www.curseforge.com/wow/addons/castborn"><img src="https://img.shields.io/curseforge/dt/1437587?label=downloads&color=orange" alt="CurseForge Downloads"></a>
</p>

<p align="center">
  <b>Castbars, cooldowns and combat tracking in one addon.</b><br>
  One download that runs on both WoW Forever and TBC Anniversary.
</p>

---

Castborn replaces a handful of addons with one: castbars, a GCD sweep, a swing timer, cooldown and item tracking, cooldown numbers on your action bars, and reminders for the buffs you forget. It sets itself up for your class, walks you through everything on first login, and stays out of the way.

## One addon, two games

The same files run on WoW Forever and TBC Anniversary. Forever hides some combat data from addons, so a few modules are TBC only, and some work slightly differently.

| Module | TBC | Forever | Notes on Forever |
|---|:---:|:---:|---|
| Castbars (player, target, focus, target of target) | Yes | Yes | No spark or latency overlay when the game hides a cast's timing |
| GCD Indicator | Yes | Yes | |
| Swing Timer | Yes | Yes | Main hand, off hand and ranged, with an out-of-range dim |
| Cooldown Tracker | Yes | Yes | Short cooldowns can also get the ready glow |
| Cooldown Text | | Yes | Styled numbers on your action bars (including Bartender4) and Castborn's icons |
| Interrupt Tracker | Yes | Yes | Cooldown only, no lockout timer |
| Item Tracker | Yes | Yes | |
| Armour Reminder | Yes | Yes | Checks your buffs out of combat; clears straight away when you rebuff in combat |
| Seal Tracker | Yes | Yes | |
| Five Second Rule | Yes | | |
| DoT and Multi-DoT Trackers | Yes | | |
| Proc Tracker | Yes | | |
| Totem Tracker | Yes | | |
| Absorb Tracker | Yes | | |

## Highlights

### A book of settings

The options window is a dark, gilded spellbook: every module on its own page, a bookmark ribbon for the page you're on, and live previews as you change things. Everything is grouped, labelled and explained in plain English.

<p align="center"><img src="images/options.png" width="700" alt="Castborn options window"></p>

### Castbars

Player, target, focus and target-of-target castbars with latency, class colours, spell icons and a shield for casts you can't interrupt. Size, colour and anchor each one separately.

<p align="center"><img src="images/castbars.png" width="687" alt="Castborn castbar casting Holy Light"></p>

### Cooldowns, at a glance

Track the abilities and trinkets that matter, with a ready glow when they come back. On Forever, Castborn also puts countdown numbers on your action bars, colour-coded by time left (white, then yellow under a minute, red under five seconds), and plays a pulse, burst or flash when a cooldown finishes. It works with Blizzard's bars and Bartender4.

<p align="center"><img src="images/cooldowntext.png" width="289" alt="Cooldown numbers on action buttons, coloured by time left"></p>

<p align="center"><img src="images/cooldownstrinkets.png" width="700" alt="Cooldown and trinket tracking"></p>

### Swing timer

Main hand, off hand and ranged swing bars with a glowing spark, a flash when each swing lands, and a dimmed bar when your target is out of range. Haste changes and weapon swaps are handled mid-swing.

<p align="center"><img src="images/swing.png" width="328" alt="Main hand, off hand and ranged swing bars"></p>

### Reminders

The Armour Reminder flags a missing self-buff (mage and warlock armours, Inner Fire, paladin blessings, auras and Righteous Fury), and the Seal Tracker shows your active seal with its time left.

<p align="center"><img src="images/reminders.png" width="644" alt="Seal tracker counting down, with two armour reminders"></p>

## More from TBC Anniversary

<table>
  <tr>
    <td width="50%" align="center">
      <img src="images/procs.png" width="100%"><br>
      <b>Proc tracking</b><br>
      Live icons with remaining duration
    </td>
    <td width="50%" align="center">
      <img src="images/absorb.png" width="100%"><br>
      <b>Absorb tracking</b><br>
      Remaining shield amount and time left
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <img src="images/totems.png" width="100%"><br>
      <b>Totem tracking</b><br>
      Durations, pulse pips and party range checks
    </td>
    <td width="50%" align="center">
      <img src="images/textures.png" width="100%"><br>
      <b>Look and feel</b><br>
      LibSharedMedia bar textures and fonts
    </td>
  </tr>
</table>

## Getting started

1. Install from [CurseForge](https://www.curseforge.com/wow/addons/castborn), or extract to `Interface/AddOns/Castborn`.
2. Log in. A short guided tour starts automatically.
3. Type `/cb` to open the options at any time.

Castborn comes set up for your class, so most people never need to change much.

## Commands

| Command | What it does |
|---|---|
| `/cb` | Open the options |
| `/cb test` | Preview every module so you can position them |
| `/cb unlock` / `/cb lock` | Drag frames into place, then lock them |
| `/cb grid` | Show an alignment grid |
| `/cb reset` | Put every frame back in its default place |
| `/cb tutorial` | Replay the guided tour |

## Features

- **Guided tour**: a step-by-step introduction to each module on first login.
- **Test mode**: see and move everything without being in combat.
- **Alignment grid** and **anchoring**: snap frames into place, or attach modules to your castbar.
- **Profiles**: save, copy and share your setup between characters.
- **Masque** support for Castborn's icons.
- **LibSharedMedia** textures and fonts.
- **Bartender4** support for cooldown numbers on Forever.

## Feedback and support

Found a bug or have an idea?

- [GitHub issues](https://github.com/afrugalpenguin/castborn/issues)
- [CurseForge](https://www.curseforge.com/wow/addons/castborn/issues)

## Credits

Castborn ships two typefaces under the [SIL Open Font License](https://openfontlicense.org): **Cormorant Garamond** by Christian Thalmann (Catharsis Fonts) and **Source Sans 3** by Adobe. Their licences are in `Media/Fonts`.

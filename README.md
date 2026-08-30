<h1 align="center">Caw DPS Meter</h1>

<p align="center">
  <img src="Media/CawBrand_preview.png" alt="Caw DPS Meter" width="460">
</p>

<p align="center">
  Lightweight combat meter for WoW 1.12 &mdash; damage, healing, utility and aura uptime.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.1--rc37-7fbf4d" alt="Version">
  <img src="https://img.shields.io/badge/WoW-1.12%20(Vanilla)-1f6feb" alt="WoW 1.12">
  <img src="https://img.shields.io/badge/license-MIT-3fb950" alt="MIT License">
  <img src="https://img.shields.io/badge/requires-SuperWoW%20%2B%20SuperAPI-d29922" alt="Requires SuperWoW + SuperAPI">
</p>

---

## What it is

Caw DPS Meter is a compact damage/healing/utility meter for the 1.12 client
(Turtle WoW and other Vanilla private servers). It reads `RAW_COMBATLOG` via
SuperWoW, so it tracks combat events the default combat log never exposes, and
it can pull data from other players running the addon to fill in what your
client did not see.

## Features

- **Damage & DPS** with per-spell breakdown and pet / totem attribution
- **Healing** tracking per player and per spell
- **Utility modes:** interrupts, crowd control, CC breaks, dispels, buffs,
  debuffs cast, debuffs received
- **Aura uptime:** group buffs and weapon enchants tracked across the raid
- **Segments:** current fight, last fight, overall session, plus a rolling
  10-fight history (`/cd history`)
- **Caw Sync:** shares combat snapshots with other users over SuperAPI addon
  messages, so late joiners and missed events still get full numbers
- Movable, lockable window with a saved position

## Requirements

| Component | Notes |
|-----------|-------|
| WoW 1.12 client | Turtle WoW / Vanilla private servers |
| [SuperWoW](https://github.com/balakethelock/SuperWoW) | client mod, provides `RAW_COMBATLOG` |
| [SuperAPI](https://github.com/balakethelock/SuperAPI) | addon dependency (declared in the `.toc`) |

Without SuperWoW loaded the meter will not receive raw combat data.

## Installation

1. Download the latest **[release](../../releases)** ZIP.
2. Extract it so the folder is exactly:
   `<WoW>\Interface\AddOns\CawDPSMeter\`
   (the folder must be named `CawDPSMeter`, not `Caw-DPS-Meter-main`).
3. Make sure `SuperAPI` is installed and SuperWoW is active.
4. Restart the client or `/reload`, then type `/cd`.

> GitHub's green **Code -> Download ZIP** button produces a wrongly named
> folder. Use a tagged release, or rename the folder to `CawDPSMeter` after
> extracting.

## Commands

`/cawdps` or `/cd`

| Command | Action |
|---------|--------|
| `/cd` | toggle the window |
| `/cd show` / `/cd hide` | show / hide |
| `/cd lock` / `/cd unlock` | lock / unlock the frame |
| `/cd reset` | clear the current fight |
| `/cd resetoverall` | clear the overall segment |
| `/cd resetpos` | move the window back to the default position |
| `/cd current` / `/cd last` / `/cd overall` | switch segment |
| `/cd history` | print the last fights to chat |
| `/cd damage` \| `healing` \| `interrupts` \| `cc` \| `ccBreaks` \| `dispels` \| `buffs` \| `debuffsCast` \| `debuffsReceived` | switch mode |

## Support

If the addon is useful to you and you want to chip in, there is a Sponsor
button at the top of this repository.

## Contributing

Issues and pull requests are welcome. Keep changes Lua 5.0 compatible (no `#`
length operator, no `%s` gsub tricks that 5.0 lacks) and test against the 1.12
client before opening a PR.

## License

[MIT](LICENSE) &copy; 2026 NovaElysium

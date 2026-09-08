<p align="center">
  <img src=".github/banner.png" alt="Caw DPS Meter" width="600">
</p>

<p align="center">
  Lightweight combat meter for WoW 1.12: damage, healing, utility and aura uptime.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2FNovaElysium%2FCawDPSMeter%2Fmain%2FCawDPSMeter.toc&search=%23%23%20Version%3A%20%28.%2B%29&replace=%241&label=version&color=7fbf4d" alt="Version">
  <img src="https://img.shields.io/badge/WoW-1.12%20(Vanilla)-1f6feb" alt="WoW 1.12">
  <img src="https://img.shields.io/badge/license-MIT-3fb950" alt="MIT License">
  <img src="https://img.shields.io/badge/requires-SuperWoW%20%2B%20SuperAPI-d29922" alt="Requires SuperWoW + SuperAPI">
</p>

---

## Screenshots

<p align="center">
  <img src=".github/screenshot-meter.png" alt="Damage / DPS view with per-player rows" width="410">
  &nbsp;&nbsp;
  <img src=".github/screenshot-modes.png" alt="Mode selector: Damage, Healing, Damage Taken, Deaths, Interrupts, Crowd Control" width="410">
</p>

## What it is

Caw DPS Meter is a compact damage/healing/utility meter for the 1.12 client
(RavenCraft, OctoWoW and other Vanilla private servers). It reads `RAW_COMBATLOG`
via SuperWoW, so it tracks combat events the default combat log never exposes, and
it can pull data from other players running the addon to fill in what your client
did not see. Up to four independent windows share the same combat data.

## Interface in 1.1.0

Left-click a player bar for an ability breakdown with player and segment selection.
Use the sliders icon (or **... > Settings** in a narrow window), right-click a player bar, or type `/cawoptions` for
window scale, size, bar spacing, text, transparency and pfUI docking options.
Each window has its own appearance. New windows fit five bars; existing layouts
are kept. Overall contains completed fights and stays selected when combat starts.
Meters use near-black pfUI-style surfaces, fine borders and muted gold highlights.
Dropdown labels use larger, bright text; window transparency remains adjustable.
Settings use sliders, number fields and checkboxes, with a preview and a window
selector. Player details keep spells, players and segments in separate lists;
the statistics on the right follow the selected spell and mode. Report and reset
are available through their header buttons or the **...** menu in narrow windows.
Small meters keep just the mode, encounter selector and **...** in the header.
Encounter menus fit their entries; scrolling controls appear above and below the
list only when needed. Hover a selector to read the full selected label.
Very narrow player bars show a shortened amount (Threat shows its percentage)
to preserve player names. Widening the meter restores your rate/share settings.
Hover or open player details for the full data.
Footer totals and rates use k/M abbreviations and adapt to the available width.
Their tooltip keeps the full total and DPS/HPS to one decimal, including when
the group reaches millions of damage or healing.

Drag the footer or empty window background to move a meter. **Shift-drag a
player bar** also moves it; an ordinary click still opens player details.
Locked and pfUI-docked windows cannot be moved this way. The bottom-right grip
continues to resize the window.
Whisper reports open an editable recipient field, prefilled from your player target.
In player details, **Talents** beside the search field switches to talent trees.
Your own trees come from the client API. Viewing group members' complete trees
requires this feature on both clients; older clients may supply only point totals.
The view shows current or last received talents, not the build used in an old fight.

**Settings > Threat** adds optional screen glow and a warning sound for your own
high threat or newly gained aggro. Both start disabled. Enable either effect,
adjust the warning threshold (default 90%) and cooldown (default eight seconds),
then use **Test warning** to preview it. Alerts read existing current-target
server data and still work when the meter is hidden. They fire on a new warning
state, rather than repeating continuously, and apply to your character across
all windows. The updated 1.1.0 download includes these controls; existing 1.1.0
users can replace the files and `/reload`.

The optional DPSLog backend needs a compatible DLL installed separately. Collection
and talent sync continue independently of the visible UI. See
[1.1.0 release notes](RELEASE_NOTES_1.1.0.md) for available statistics and validation.

## Features

- **Damage & DPS** and **Healing & HPS**, with per-spell breakdown; pet damage
  and healing fold into the owner, totem damage is attributed to the caster
- **Damage taken** and **Deaths** with killing-blow detail
- **Utility modes:** interrupts, crowd control, CC breaks (with the breaking
  ability and its damage), dispels, buff uptime, debuffs cast, debuffs received
- **Aura tracking:** group buffs, weapon buffs and poisons across the raid
- **Segments:** current fight, last fight, overall session, plus a rolling
  10-fight history (`/cd history`)
- **Caw Sync:** shares damage and healing snapshots with other users over
  SuperAPI addon messages, so late joiners and missed events still get full
  numbers (damage taken and deaths are local to your client)
- **Chat reports** to Say, Party, Raid, Guild or Whisper from the in-window Report button
- Up to **4 independent meter windows**, each with its own mode, segment,
  position, size, scroll offset and lock state
- **Optional pfUI docking:** right-click a window's lock icon to dock it into the
  pfUI right chat; multiple docked windows sit edge-to-edge and follow the chat
  arrow. No pfUI files are modified
- **Threat view** with live server values on supported servers, independent of
  TWThreat. The experimental local model runs alongside it for calibration,
  with automatic peer discovery and talent-rank exchange
- Compact narrow-window layout with adaptive actor-name truncation to keep values
  readable
- Persistent window layout, lock state and selected mode

## Requirements

| Component | Notes |
|-----------|-------|
| WoW 1.12 client | RavenCraft / OctoWoW / Vanilla private servers |
| [SuperWoW](https://github.com/balakethelock/SuperWoW) | client mod, provides `RAW_COMBATLOG` |
| [SuperAPI](https://github.com/balakethelock/SuperAPI) | addon dependency (declared in the `.toc`) |

Without SuperWoW loaded the meter will not receive raw combat data.

## Installation

1. Download the latest **[release](../../releases)** ZIP.
2. Extract it so the folder is exactly:
   `<WoW>\Interface\AddOns\CawDPSMeter\`
   (the folder must be named `CawDPSMeter`, not `CawDPSMeter-main`).
3. Make sure `SuperAPI` is installed and SuperWoW is active.
4. Restart the client after updating to 1.1.0 so the new UI and data modules load;
   `/reload` alone is not enough on the first update. Type `/cd` to show the meter.
   Existing settings are kept.

> GitHub's green **Code** then **Download ZIP** button produces a wrongly named
> folder. Use a tagged release, or rename the folder to `CawDPSMeter` after
> extracting.

## Windows and pfUI

Version 1.1.0 keeps selectors and buttons in a single compact header, gives encounter
names more space, and keeps totals and Threat status in a reserved footer.
A persistent watermark sits behind the player bars without intercepting clicks.

Shift-right-click any lock icon to switch visibility modes for all docked windows.
The default follows chat visibility; alternate mode shows Caw when chat is hidden
and hides Caw when chat is shown. This preference is saved per character. Both
normal hiding and pfUI's alpha-only hiding are supported.

Use the **+** button for additional windows. Each window keeps its own mode, size,
position and scroll offset, and all windows use matching bar dimensions and scroll
controls.

Right-click a window's lock icon to dock or undock it at the pfUI right chat.
Multiple docked windows sit edge-to-edge side by side inside the right chat area,
above its status panel, and follow its arrow visibility. Combat recording and sync
continue while hidden. Free windows remain independent. No pfUI files are
modified; without pfUI the addon works normally.

## Threat and Caw Sync

Damage/healing combat snapshots use Caw Sync. Compatible clients also announce
their presence and capabilities automatically. Threat tooltips distinguish
detected clients, expired replies and actual current talent data. No reply does
not prove that someone has no Caw installed.

Threat is calculated locally and remains experimental. All classes exchange talent
ranks/max ranks by tree and slot. Feral Instinct is currently the only remote
talent applied by the threat engine; other modifiers and several
utility/resource/healing rules remain incomplete. Unknown talents stay unknown.
TWThreat is no longer required for server calibration: Caw can directly query the
API and show a separately labeled server reference while its local engine
continues unchanged.

### Talent synchronization

Talent layouts are sampled once per second, sent on change and refreshed every 30
seconds. Each tree is one bounded packet; packets are spaced by at least 0.2
seconds. A profile becomes usable only after all trees arrive. Profiles expire
after 90 seconds and are removed when the player leaves the group. Layouts contain
ranks and maximum ranks by tree/slot, not localized talent names or inferred
threat formulas. Up to 200 distinct received actor/layout combinations per
calibration session are retained. Talent data is exchanged only with the current
party/raid; nothing is uploaded automatically.

The optional talent viewer also requests names, icons and tree positions from
the selected group member. These separate messages run only on demand, at most
ten packets per second, and stay within 240 bytes. A complete response replaces
the previous displayed tree atomically. Only the most recently viewed remote
tree is cached in memory; the normal calibration packet format is unchanged.
Tooltips currently show the talent name and rank. Prerequisite connections and
full talent descriptions are not included yet.

### Standalone server reference

Caw queries supported servers for hostile NPC combat targets while in a
party/raid. TWThreat is not required, and live display also works when calibration
recording is disabled. The current Threat view shows recent server rows for the
selected target; it does not substitute local estimates when a reply is missing.
The footer shows the target, a waiting state or no server response. History and
Overall remain local. The local model continues independently for comparison.

Requests use `limit=4`, matching the tested TWThreat default request, and recent
snapshots expire after 1.25 seconds. The returned rows are not a guaranteed full
raid table. TWTv4 has no response target/request ID, so target attribution remains
provisional. Timeouts trigger bounded retries; uncertain recordings are marked
accordingly. With TWThreat loaded, Caw pauses its own requests and observes that
addon's replies, displaying them only when a recent observed request matches the
current target context.

## Local calibration recordings

This release records calibration data automatically unless the character has
disabled it. `/cdthreatcal off` disables recording and its automatic startup;
`/cdthreatcal on` enables it again. A startup message confirms active recording.
No files are uploaded automatically. With TWThreat loaded, Caw passively records
its replies; standalone calibration can query eligible combat targets.

The latest 12 sessions are kept, each limited to 12,000 model events, 6,000 casts,
6,000 snapshots, 2,000 actor contexts and bounded supporting traces. Save by
reloading or logging out normally. To report a discrepancy, include version,
target, ability and relevant saved calibration data. Recordings can contain player
names and GUIDs; review them before sharing publicly.

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
| `/cd damage` \| `healing` \| `damageTaken` \| `deaths` \| `interrupts` \| `cc` \| `ccBreaks` \| `dispels` \| `buffs` \| `debuffsCast` \| `debuffsReceived` | switch mode |
| `/cdthreatcal on` / `/cdthreatcal off` / `/cdthreatcal status` | calibration recording and direct server queries |

Chat reports (Say / Party / Raid / Guild / Whisper) go through the **Report** button in the
window, not a slash command. Window menus also select modes and history.

Window settings persist. Current/overall combat data and fight history do not
survive reload/logout. All group clients should update to exchange compatible
data.

## Reporting a bug

For a fight that ends late, merges with another, or shows wrong numbers:

1. `/cdlog on`
2. Reproduce it (a few pulls).
3. `/cdlog save`, then `/reload`.
4. Open an [issue](../../issues) and attach the `CawDPSMeter.lua` from your
   `WTF\Account\<name>\SavedVariables\` folder.

The log records only the combat-end lifecycle and is off unless you turn it on.

See [CHANGELOG.md](CHANGELOG.md) and the [1.1.0 release notes](RELEASE_NOTES_1.1.0.md)
for the full change list and known limits. The regression suite uses mocked WoW
APIs; a live client is still needed for visual and multiplayer verification.

## Support

Caw DPS Meter is free. If it is useful to you and you want to chip in, there is a
Sponsor button at the top of this repository, or:

[![Support on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/huginnandmuginn)

## Contributing

Issues and pull requests are welcome. Keep changes Lua 5.0 compatible (no `#`
length operator, no `%s` gsub tricks that 5.0 lacks) and test against the 1.12
client before opening a PR.

## Credits

Built by **Huginn &amp; Muninn**: [NovaElysium](https://github.com/NovaElysium) and [CawDPSMeter](https://github.com/CawDPSMeter).

## License

[MIT](LICENSE) &copy; 2026 Huginn &amp; Muninn

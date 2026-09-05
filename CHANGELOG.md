# Changelog

This project loosely follows [Keep a Changelog](https://keepachangelog.com/)
and [Semantic Versioning](https://semver.org/).

## [1.0.8] - 2026-09-05

### Added
- Standalone server-reference Threat display and calibration without TWThreat, including normal hostile combat targets. Server display snapshots never overwrite the local threat engine.
- Optional pfUI right-chat docking for each Caw window. Right-click its lock button to dock or undock. Multiple docked windows sit edge-to-edge side by side inside the right chat area, above its status panel and follow its show/hide arrow; combat collection continues while hidden. pfUI itself is unchanged.
- Automatic Caw peer discovery, version/capability reporting and current-data status in Threat tooltips.
- Automatic talent-rank layout exchange for all classes, plus Feral Instinct exchange for the supported threat rule.
- Experimental local Threat view with per-target ability accounting and optional TWThreat/server calibration.
- Bounded diagnostic and calibration recordings, saved locally on reload/logout.

### Fixed
- Dropdown menus retain their own foreground layer above player bars. Narrow rows hide the class icon first to preserve actor-name space and restore it when widened.
- pfUI docking retains UIParent and follows chat visibility explicitly. Previous docking settings reset once to recover inaccessible windows.
- Docked and free windows keep their controls above their backgrounds on an interactive foreground layer; extra windows now display class icons with the primary window's icon and text spacing.
- Extra windows now match the primary bar height, spacing, borders and scrollbar gutter, with visible scroll controls and mouse-wheel support directly over bars.
- Closed-window persistence, pooled-window reuse and tooltip display context.
- Combat sync rejects incompatible enemy snapshots and late packets after combat finalization.
- Pet ownership, first-event target tracking and several interrupt/aura edge cases.
- Feign Death reset/resist handling, selected measured pet Growl values, Bear form and Maul/Swipe factors, and captured Faerie Fire rank-2 aura applications.

### Compatibility and limits
- All participating clients should update. Requires SuperWoW and SuperAPI; pfUI is optional.
- Threat remains experimental and is not a replacement for authoritative server threat. Other talent modifiers, Demoralizing Roar, some refreshes, resource/healing threat and custom ranks remain incomplete.
- Missing peer replies do not prove that Caw is absent. All classes exchange talent ranks/max ranks by tree and slot. Feral Instinct is currently the only remote talent applied by the threat engine; presence alone does not imply complete threat data.
- Calibration starts automatically unless disabled for the character with `/cdthreatcal off`. It can be re-enabled with `/cdthreatcal on`. Recordings stay on the user's computer and are not uploaded automatically. With TWThreat active, Caw observes its replies instead of sending its own calibration queries.
- Current/overall combat data and fight history remain session-only. Settings persist.
- 188 mocked Lua regression checks pass, including two-window docking. The user confirmed the window layout in-client. Six two-client integration scenarios cover discovery, talent layouts, respecs, raid switching, calibration links and message validation; a live multi-client confirmation remains pending.

## [1.0.7] - 2026-09-04

### Added
- Up to four independent meter windows can be open at once. Extra windows keep their own mode, segment, position, size, lock state and scroll position while sharing the same parsed combat data.
- Compact header layout for narrow windows, including compact branding and icon controls.

### Changed
- The minimum window width is smaller for compact layouts.
- Actor names now shorten with an ellipsis before they can overlap the right-hand value at narrow widths.
- Damage Taken, Deaths and aura summary text is shorter in compact layouts.
- Lock/unlock icon state now matches the actual window state.

## [1.0.6] - 2026-09-01

### Fixed
- Expired player buffs such as Drink and First Aid no longer leak into later combat segments.
- Periodic healing/resource combat-log lines are no longer misidentified as buff names.
- HoTs such as Rejuvenation are now recorded correctly in Healing/HPS.
- Aura source attribution now resolves roster players for HoTs and direct buffs such as Power Word: Shield.
- Secondary received debuffs such as Weakened Soul can inherit the correlated caster source.
- Buff Uptime tooltips can attribute HoT healing to individual sources.
- Debuffs Received tooltips can attribute periodic damage to individual sources.
- Aura source lists are capped to the top five entries in tooltips, with remaining sources summarized.
- Manual window edge clamping was refined so the meter can sit at screen edges without native SetClampedToScreen.

## [1.0.4] - 2026-08-31

### Fixed
- `SetClampedToScreen` is no longer used. Native frame-clamping caused
  ACCESS_VIOLATION crashes while dragging on some 1.12 client builds.
- The window position is stored as a resolution-stable centre offset
  (layout v4), so it survives a resolution or UI-scale change instead of
  being treated as off-screen and snapped back to the default spot.
- The window no longer rubber-bands to the centre when you drag it toward
  an edge. On-screen correction now clamps the position (keeping your
  placement) and only runs when the window is actually mostly off screen.

## [1.0.3] - 2026-08-31

### Fixed
- First pass at the window rubber-band fix (superseded by 1.0.4).

## [1.0.2] - 2026-08-30

Combat-end rework. Please report a fight that still ends late or merges by
running `/cdlog on`, reproducing it, then `/cdlog save`, `/reload`, and
attaching the `CawDPSMeter.lua` from your `WTF/Account/<name>/SavedVariables`
folder to the issue.

### Fixed
- A crowd-control target that dies while still controlled no longer blocks
  combat end. The control state is dropped as soon as the target dies.
- Hard ceiling on the combat-end grace: the fight now always closes within a
  few seconds of the player leaving combat, even if a control entry is stuck.
- Re-entering combat only merges with the previous fight if the grace was
  scheduled less than 1.5 s earlier (a real combat-state flicker). A longer
  gap starts a new segment.
- The displayed duration freezes when combat ends, so DPS and HPS no longer
  visibly decay during the grace window.
- Group activity in the first seconds after your fight ends (a healer topping
  the tank off, for example) no longer spawns a phantom fight in the history.

### Added
- `/cdlog` diagnostic log for the combat-end lifecycle. Off by default.
  `on` / `off` / `dump [n]` / `save` / `clear`.

## [1.0.1] - 2026-08-30

### Fixed
- In a group the meter now ends the current segment when the local player
  leaves combat, instead of holding it open until the whole group is idle.
  A grace close scheduled by leaving combat is no longer cancelled by another
  group member's recent activity; re-entering combat still keeps the segment.
- Stale crowd-control entries no longer block combat end. A CC target that
  dies while controlled, or a missed fade line, previously kept the segment
  open until the next fight.

## [1.0] - 2026-08-30

Initial public release.

### Meters
- Damage and DPS, Healing and HPS, with per-spell breakdown.
- Damage taken.
- Deaths with killing-blow detail.
- Pet damage and healing folded into the owner; totem damage attributed to the caster.

### Utility
- Interrupts, crowd control, CC breaks (with the breaking ability and its damage), dispels.
- Buff uptime, debuffs cast, debuffs received.
- Weapon buff and poison tracking.

### Segments and sync
- Current fight, last fight and overall session, plus a rolling 10-fight history.
- Caw Sync shares damage and healing between users over SuperAPI addon messages,
  including continuation from a dead client and combat-end grace handling.
- Damage taken and deaths are observed locally and are not synchronised.

### Interface
- Movable, lockable window with persistent layout, lock state and selected mode.
- Chat reports to Say, Party, Raid or Guild from the Report button.

### Notes
- Overkill is shown only when the server's RAW combat message supplies it.
- Pet damage taken is not shown as a separate ranking entry.

## Standalone server reference

Disable TWThreat and restart the client to load CawServerThreat.lua. With calibration enabled (the default), Caw queries the server for hostile NPC combat targets while in a party/raid. The current Threat view automatically shows `Server reference*` when a recent own-request snapshot passes target/segment checks; otherwise it shows `Local estimate`. History/overall remain local. The tooltip identifies the source and, when matched, the parallel local value.

The request uses `limit=4`, matching the tested TWThreat default request; the display contains the returned rows, not a guaranteed full raid table. The target must have been stable for two seconds at request time; snapshots expire after 1.25 seconds. TWTv4 has no target/request ID, so even accepted context is provisional. After a timeout or parallel-probe ambiguity, server display is suppressed until reload. With TWThreat loaded, Caw keeps passive calibration and local display instead.

`/cdthreatcal off` stops recording and Caw's direct queries, returning the view to local estimates. Recording caps do not freeze an otherwise eligible live server display. Live verification of this standalone release path is still pending.

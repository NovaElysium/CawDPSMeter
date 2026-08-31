# Changelog

This project loosely follows [Keep a Changelog](https://keepachangelog.com/)
and [Semantic Versioning](https://semver.org/).

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

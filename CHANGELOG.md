# Changelog

This project loosely follows [Keep a Changelog](https://keepachangelog.com/)
and [Semantic Versioning](https://semver.org/).

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

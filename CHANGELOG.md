# Changelog

This project loosely follows [Keep a Changelog](https://keepachangelog.com/)
and [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.2] - 2026-09-11

### Added
- `/cddebug icons` lists spell names that fell back to the question-mark icon
  this session (most frequent first, with spell ID when known), to make it
  possible to report real gaps in the bundled icon database instead of guessing.
- Settings > General now offers separate combat parser and damage/healing sync
  switches, saved per character and shared by all windows. Both default to on.
- Pausing the parser closes and preserves the current segment, freezes local
  recording and blocks combat snapshots. Resuming starts a new segment at the
  next combat event. Existing history and Overall remain available.
- Turning only combat sync off keeps local recording active. Talent sharing
  and the live server threat display remain available with either switch off.

### Fixed
- Threat calibration recording could grow the account-wide SavedVariables file
  to tens of megabytes (12 retained sessions x 12,000 events / 6,000 casts /
  6,000 snapshots / 2,000 actor contexts each). A file that large risks a
  truncated write on logout/crash, which corrupts every SavedVariables table
  sharing that file (including window layout), not only the calibration log.
  Caps are lowered to 3 sessions x 2,000 events / 1,500 casts / 800 snapshots /
  300 actor contexts, and a one-time migration trims any oversized history
  already on disk down to the new caps on next login.
- Restored damage/healing snapshot exchange: combat-source selection messages
  no longer get consumed as Caw presence announcements. Existing message formats
  are retained; presence and talent synchronization continue independently.
- Meter dropdowns stay above player bars when the inventory background option
  or Bagshui is active. Newly created encounter entries are layered when opened.
- Unchanged free windows no longer rebuild their entire frame hierarchy on
  every docking poll, avoiding repeated foreground/background transitions.
- The settings panel displays the installed version instead of a fixed 1.1.0 label.

### Changed
- RAW processing caches event-family dispatch in a bounded table, skips damage
  and healing patterns when their required text is absent, and reuses the
  ability captured for CC damage attribution.
- Aura and utility parsing skips impossible interrupt, dispel, cast and aura
  patterns using literal guards. Resource ticks use one shared classification
  instead of repeated searches; existing buff tracking and diagnostics remain intact.
- Opening buff scans use and cache native spell names when a compatible
  GetSpellInfo API is available, reducing hidden tooltip work at combat start.
  Clients without that API retain the existing tooltip fallback.
- Pending combat sync checks run at most four times per second, only in a group
  with sync enabled, instead of repeatedly scanning enemy GUIDs every frame.
- Paused calibration sessions are closed and resumed in a fresh session; live
  server snapshots are not compared against a paused local model.
- Added repeatable parser benchmarks and event-by-event comparisons against an
  unchanged addon checkout, including RAW fallback, DPSLog utility and calibration.
  See `tests/RAW_PARSER_PERFORMANCE.md` for measurements and their limitations.

## [1.1.1] - 2026-09-10

### Added
- Player comparison from the detail view. Select another player of the same
  class to compare totals, ability values, shares and the left-minus-right
  difference in one view. Owned pet contributions remain included with their
  owner.

### Changed
- The comparison view temporarily replaces the player detail window and
  restores the previous player, segment, spell and search context when closed.
- Comparison selectors use compact menus and keep their controls separate from
  the Talents button.
- Added an optional inventory-layer fallback under Settings > pfUI for bag
  addons that do not expose a detectable inventory frame.

### Fixed
- Comparison table headings no longer intersect the divider line or the first
  row on the Vanilla client.
- Hover breakdown labels are vertically centered inside their bars.
- Spell icon lookup includes the expanded local database and runtime spellbook
  fallbacks used by the current client.
- Interrupt tracking now keeps an enemy cast briefly after RavenCraft reports a
  same-frame `UNIT_CASTEVENT FAIL`, so landed Kick/Pummel interrupts are counted
  without turning later failed casts into false interrupts.

### Validation
- 283 combat/data regressions, 158 UI checks, 25 release-UI checks and 38
  threat-alert checks pass against the public package.

## [1.1.0] - 2026-09-08

### Added
- Optional screen glow and sound for high threat or newly gained aggro, with
  character-wide controls under Settings > Threat. Both effects start disabled;
  the default warning threshold is 90% with an eight-second cooldown.
  Alerts use existing server snapshots, work with hidden meters, and include a preview.
- Per-window settings for scale, dimensions, exact row fitting, bar height/gap,
  font size, transparency, watermark, icons, ranks, name colours and rate/share values.
- Clickable player analysis with player/segment navigation, searchable ability
  list, sorting, ability statistics and labelled pet contributions.
- Settings pages for pfUI docking and appearance; header resets require confirmation.
- Native sliders, numeric inputs, checkboxes, a window selector and an appearance preview.
- Optional DPSLog input adapter and event cursors for calibration snapshots.
- Whisper reports with an editable player-target recipient and a frozen report selection.
- A Talents button in player details shows native talent positions, icons and ranks.
  Group members supply tree details on request; both clients need the new viewer.
- Drag meters by their footer or empty background, or Shift-drag a player bar.
  Regular bar clicks, locking, docking and resize grips keep their existing roles.

### Changed
- New windows fit five bars; existing saved dimensions are retained.
- Compact headers keep settings, report, reset and selectors accessible.
- A smaller settings panel keeps General, Window, Bars, Text, Threat and pfUI pages.
- Overall stays selected across combat entry. Automatic Current selection is optional.
- Player analysis reports unavailable statistics explicitly instead of inventing values.
- Charcoal panels, gold selection accents and short English menu labels; player
  details group spells and mode-specific statistics in separate columns.
- Main and additional meters use darker pfUI-style panels and a separate footer.
  Dropdown labels use bright 12-pixel text; narrow mode entries have short labels
  and full-label tooltips while keeping the selector width.
- Player, fight and spell list arrows disable at the ends and when all entries fit.
- Player bars use darker class colours with brighter names, ranks and values
  for contrast, including the additional windows and appearance preview.
- Narrow headers keep usable mode/encounter selectors and group actions under **...**.
  Encounter lists shrink to their entries, with full-width scrolling controls when needed.
- The compact menu's three-dot icon stays centered inside its button without text wrapping.
- Small player bars abbreviate amounts (Threat shows its percentage) and prioritize
  names over icons; larger windows restore saved rate/share settings. Footer totals
  align right, and complete labels and summaries remain available on hover.
- Solid background textures preserve configured opacity without the old tooltip
  texture's additional transparency.
- Includes the intervening local threat, pet and totem fixes; reference recording
  and talent sync remain active. The local maintainer overlay stays excluded.

### Fixed
- Damage and healing tooltips now calculate ability percentages against the full
  player total, including owned pets and totems. Pet and totem contributions also
  show their share of that total in all windows and segments.
- Footer totals and DPS/HPS shorten to k/M values when needed, while their tooltip
  retains full totals. Narrow windows keep text inside the available footer space.
- Meter dropdowns close each other and clear when their window is hidden or Settings opens.
- Hover handlers preserve the shared theme and locked-button highlight.
- Encounter dropdown widths follow their selector in main and additional windows.
- Melee attacks have a sword icon in the spell list and selected-spell details.
- Player bar hover and click handlers no longer capture a loop variable that can
  be nil on the Vanilla client. Each bar keeps its own current row reference.

### Validation
- 279 combat/data regressions, 161 UI checks, 38 alert checks and ten two-client sync scenarios pass
  against the public package. ZIP contents and private-overlay exclusion are verified.
  UI tests use mocked client APIs; see RELEASE_NOTES_1.1.0.md for scope and limitations.

## [1.0.9] - 2026-09-06

### Changed
- Compact single-row header shared by the main and additional windows. Mode and encounter selectors sit beside the action buttons.
- The encounter selector has more space for mob names. The opened mode menu follows its selector width, including its click areas and text.
- Totals and Threat status now occupy a reserved footer below the player rows.
- Persistent Caw watermark above the window background and behind player bars, with no mouse interaction.

### Added
- Optional pfUI chat/meter switching: Shift-right-click a lock icon to alternate between chat and all docked Caw windows. The preference is saved per character. Normal right-click still docks or undocks each window.

### Fixed
- pfUI visibility tracking now handles both frame hiding and alpha-only hiding used by its third-party meter integration.
- Player rows and scrolling respect the footer at supported window sizes.

### Release validation
- 210 mocked Lua regression checks and six two-client sync scenarios pass against the public package. Visual behavior still requires in-game verification.
- The maintainer's local group counter and talent-status overlay are excluded. Automatic peer discovery, talent exchange and calibration remain available.

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

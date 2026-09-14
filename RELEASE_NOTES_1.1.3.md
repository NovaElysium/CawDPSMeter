# Caw DPS Meter 1.1.3

- **DPSLog-powered dispel tracking:** when the structured DPSLog API is active,
  dispels are now recorded straight from the game's own dispel processing
  (self-dispels included) instead of a two-line text-pattern heuristic. Note
  that DPSLog can't see which ability was used to dispel — only what got
  removed — so the "Dispels" breakdown is now keyed by the removed aura's
  name (e.g. "Weakened Soul") rather than the dispelling ability's name (e.g.
  "Purify") in this mode. Raw combat-text mode is unchanged.
- **DPSLog Community Edition recommended:** the README now points to
  [DPSLog Community Edition](https://github.com/NovaElysium/DPSLog-Community),
  a community-maintained continuation of the original (no longer active)
  DPSLog module. It fixes a compiler bug and event-delivery issue that made
  the original build unusable in practice. With it installed you get
  overheal-corrected healing and more reliable dispel/damage/healing numbers
  from structured game data instead of parsed chat text. It's auto-detected
  at login with a full fallback to raw parsing if it isn't present — not a
  hard requirement.
- **Crash fix:** `/cawinput` could crash the client via `GetCombatLogPath`
  (logsessions.dll) — a native access violation `pcall` cannot guard against.
  The call is removed rather than wrapped.
- **Window fix:** `/cd hide`, `/cd show`, and the bare `/cd` toggle now act on
  every open meter window, not just the primary one — hiding the meter no
  longer leaves extra windows sitting on screen.
- **Clearer overheal disclosure:** the healing footer tooltip now notes when
  totals come from raw combat text, which cannot carry an overheal amount, so
  raw-mode healing numbers are not overheal-corrected. This makes that
  limitation visible instead of silently showing a possibly inflated total.

Replace the CawDPSMeter addon folder with the folder inside the ZIP, then
restart the client or use `/reload`. Saved settings are retained. This public
package excludes the maintainer's private Caw-user/talent-status overlay and
contains no collected logs or SavedVariables.

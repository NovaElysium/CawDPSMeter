# Caw DPS Meter 1.0.9

This update brings a more compact layout and a new way to use Caw with pfUI's right chat window.

- Mode and encounter selectors now share one header row with the window buttons, leaving more room for player bars.
- Encounter names get more space, and the opened mode menu matches its selector's width.
- Totals and Threat status sit in a dedicated footer that player bars cannot overlap.
- A subtle, persistent Caw watermark sits behind the bars without intercepting clicks.
- Shift-right-click a lock icon to switch all docked windows between following chat visibility and alternating with chat. In alternate mode, hiding chat shows Caw; showing chat hides Caw. Right-click still docks or undocks each window.
- Docking now detects pfUI's alpha-based chat hiding as well as normal show/hide changes.

The personal maintainer group/talent-status overlay is not included. Automatic talent sync and local calibration recording continue as before; recordings are not uploaded automatically. Threat remains experimental, with the existing calculation limits unchanged.

Requires SuperWoW and SuperAPI. pfUI and TWThreat are optional. Close WoW completely before updating and restart afterward: this release adds `CawHeader.lua`. Existing settings are retained.

Validation: 210 mocked Lua regression checks and six two-client sync scenarios passed against the public package. These tests do not replace in-game visual verification.

# Caw DPS Meter 1.0.8


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

## Installation

Close the game, extract the release ZIP into `Interface/AddOns`, and keep the folder name `CawDPSMeter`. Restart the client to load the added modules. Existing settings are retained. Install SuperAPI and enable SuperWoW separately.

For pfUI docking, right-click the lock icon on each desired Caw window. Right-click again to restore its free position. The pfUI arrow controls all docked windows together; undocked windows remain independent.

## Standalone server reference

Disable TWThreat and restart the client to load CawServerThreat.lua. With calibration enabled (the default), Caw queries the server for hostile NPC combat targets while in a party/raid. The current Threat view automatically shows `Server reference*` when a recent own-request snapshot passes target/segment checks; otherwise it shows `Local estimate`. History/overall remain local. The tooltip identifies the source and, when matched, the parallel local value.

The request uses `limit=4`, matching the tested TWThreat default request; the display contains the returned rows, not a guaranteed full raid table. The target must have been stable for two seconds at request time; snapshots expire after 1.25 seconds. TWTv4 has no target/request ID, so even accepted context is provisional. After a timeout or parallel-probe ambiguity, server display is suppressed until reload. With TWThreat loaded, Caw keeps passive calibration and local display instead.

`/cdthreatcal off` stops recording and Caw's direct queries, returning the view to local estimates. Recording caps do not freeze an otherwise eligible live server display. Live verification of this standalone release path is still pending.

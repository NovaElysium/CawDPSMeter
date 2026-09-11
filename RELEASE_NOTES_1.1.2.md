# Caw DPS Meter 1.1.2

- **Pause the parser:** Settings > General > Enable combat parser. Turning it
  off stops local combat recording and damage/healing sync. Your current fight
  is saved, existing history stays available, and the footer shows Parser paused.
  Resuming starts a new segment with the next combat event.
- **Disable combat sync separately:** Turn off Sync damage and healing to use
  only locally observed damage/healing data. Both settings apply to every Caw
  window on the character and are remembered after reload. Both start enabled.
- **Working combat sync:** Fixed a message dispatch collision that prevented
  selected peers from sending their complete damage/healing snapshot. Updated
  clients still use the existing message format.
- **Less repeated work:** Faster RAW event dispatch, fewer unnecessary text
  searches, cached spell names for opening buff scans where supported, and no
  repeated rebuilding of unchanged window layers. Pending combat sync checks
  are limited to four per second and skipped when solo or disabled.
- **Dropdown fix:** Menus stay above player bars when Caw is behind inventory
  windows, including newly added encounter entries.
- **Version label:** Settings now shows the actual installed version.

Talent sharing and live server threat remain available when the parser or
combat sync is disabled. Pausing also closes the calibration session; resumed
recording uses a fresh session so the missing interval cannot become a local
threat comparison. Existing data already received through sync is retained.

Replace the CawDPSMeter addon folder with the folder inside the ZIP, then
restart the client or use `/reload`. Saved settings are retained. This public
package excludes the maintainer's private Caw-user/talent-status overlay and
contains no collected logs or SavedVariables.

Validation covers combat/data, menus and windows, threat alerts, parser pause
and resume, plus isolated PARTY/RAID clients exchanging real addon-message
payloads through a mock transport. Package bytes and SHA-256 are verified.
These checks use a mocked WoW API and Lua 5.1 with Vanilla iteration adapted
only in the test VM; they do not confirm live-client FPS or eliminate every
possible source of stutter. In-game combat-start testing is still needed.

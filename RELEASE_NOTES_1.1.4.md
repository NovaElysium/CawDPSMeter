# Caw DPS Meter 1.1.4

- **Correct shield damage:** Enemy retaliation such as Jadefire no longer
  counts as your or your pet's damage and inflates DPS. Friendly damage shields
  still count for the unit carrying the shield.
- **Automatic hiding:** Each window can now hide when solo, in a party, in a
  raid, in a battleground, in combat or out of combat. Find these options under
  Window > Automatically hide. Recording and sync continue while hidden.
- **Stable window positions:** Fixed small windows shifting inward after a
  reload, including at 65% scale and with multiple windows.
- **Reopen where you left off:** Closing an extra window with X now remembers
  its position, size and settings. Use + to reopen the last closed window, or
  `/cd show` to reopen them together. Closed extra windows stay closed on reload.
- **More window customization:** Separate top and bottom bar heights, text sizes,
  colours and opacity. Customize player bars, fonts, outlines, shadows, text
  alignment and spacing. Hide the footer, stack bars upwards or choose which
  top-bar buttons to show.
- **Easier settings:** Settings are grouped by the part of the window you want
  to change. Search finds options across every page, including collapsed
  sections. Controls explain what they do and why an option is unavailable.
  Colour pickers and dropdowns stay above the settings window.
- **Targets and healing recipients:** Open a player's details to see damage by
  enemy or healing by recipient. Click a target to see its spells. Pets and
  totems are included, with their spells kept separate. Same-name enemies remain
  separate targets.
- **Overheal:** A new view shows recorded overheal for players and spells,
  including fully overhealed casts, pets, reports and player comparisons.
  Percentages use total healing for events with known overheal. Missing values
  are marked unavailable rather than shown as zero.
- **Extra details through Caw Sync:** Opening Targets or Recipients can request
  missing details from the selected player's compatible Caw client. Replies are
  limited and sent gradually. They supplement the breakdown without increasing
  the normal damage or healing total. The view shows partial coverage and shared
  details. Current fights, retained history and Overall are supported.
- **Pull times:** Saved fights show their local start time instead of a moving
  history number. Everyone sees their own local time; sync remains independent
  of time zones.
- **Wider bars:** Scroll anywhere over the player list with the mouse wheel.
  The separate right-hand scroll controls are removed. DPS/HPS no longer stays
  clipped after widening a window when there is enough space for the values.
- **Less repeated work:** Windows viewing the same data share sorted results,
  unchanged bars and detail lists skip unnecessary redraws, and DPSLog reuses
  its diagnostic status instead of rebuilding it for every event.
- **Clear recording status:** Combat & sync shows whether DPSLog, combat text
  or paused recording is active, plus the separate sync status.
- **Better sync troubleshooting:** `/cawsyncstatus` shows requests, completed
  replies and the last result. A compact diagnostic history survives reloads
  so failed transfers can be investigated from feedback.

## Updating

The ZIP was updated on 17 September 2026 with the damage-shield correction,
window fixes and automatic hiding options above. The version remains 1.1.4; download it again if you
installed the earlier 1.1.4 package.

Replace the CawDPSMeter addon folder with the folder inside the ZIP, then use
`/reload` or restart the client. Existing saved settings are retained. SuperWoW
and SuperAPI requirements are unchanged. DPSLog remains optional and is installed
separately; it is not included in this package.

Overheal and target/recipient details require recorded DPSLog data, either local
or received through Caw Sync. Both clients need 1.1.4 for the new target-detail
exchange. Older clients retain the existing combat sync. Missing observations,
unavailable peers, different retained fights and transfer limits can leave a
partial view; installing DPSLog now cannot reconstruct older unrecorded events.
Local threat estimation is still being calibrated.

## Validation and feedback

Automated checks cover combat data, settings, menus, display caching and isolated
PARTY/RAID clients exchanging the real addon messages through a mocked transport.
Window checks cover repeated reloads at different scales, closing and reopening,
all six hiding conditions and their interaction with pfUI chat docking.
Damage-shield checks cover enemy retaliation against players and pets, friendly
shields, ownership, target totals and duplicate combat text.
Sync checks include interrupted and incomplete transfers, disabled recording,
older peers, saved fights, Overall, packet limits and diagnostics across reloads.
Local gameplay recordings were also checked for DPSLog input, pet damage and
measured overheal. The new target sync still needs broader in-game group testing;
these checks do not establish live-client frame rates or server delivery behavior.

When reporting a sync issue, include your Caw version, whether DPSLog is active,
the selected fight/view and `/cawsyncstatus` output. Use `/reload` before sharing
the saved Caw diagnostics if requested. Other sections of SavedVariables can
contain character names and collected combat data.

The public package contains runtime files, media and documentation. It excludes
collected logs, SavedVariables, development files and the maintainer's private
Caw-user/talent-status overlay. Archive contents and SHA-256 are verified.

# Caw DPS Meter 1.1.5

- **Window settings stay saved:** Fixed inconsistent layouts after reloads,
  relogs and character switches. Window count, appearance and pfUI docking are
  saved together across characters. Hidden windows keep their settings, and
  closed windows stay closed until you reopen them.
- **Copy to all windows:** Now also copies width, height, number of bars and
  the window lock. Each meter keeps its own position, docking and selected view.
- **Reset means reset:** One confirmation clears all combat data in every
  window, including Current, Overall and saved fights. No extra selection menu.
  `/cd reset` does the same. Your window settings are kept.
- **No more Threat chat spam:** Removed the repeated missing server response
  message. Failed requests slow down automatically without filling the chat.
- **Faster Threat on new enemies:** Fighting normal mobs without server replies
  no longer leaves a new elite or boss waiting behind the previous mob's retry
  delay. Requests remain limited across all windows, including during fast target
  switching. Outstanding requests and late replies are handled before moving on.

## Updating

Download `CawDPSMeter-1.1.5.zip` and replace the addon folder with the
`CawDPSMeter` folder inside it. Use `/reload` or restart the game.
Existing saved settings are retained. SuperWoW and SuperAPI are still required;
DPSLog remains optional and is installed separately.

## Validation

Automated regression checks cover window copying, reset confirmation and cancel,
fresh-client reloads, character switches, hidden and closed windows, pfUI docking,
Threat timeouts, delayed replies and rapid target changes. The combat and
multi-client group-sync suites also pass. These tests use a mocked WoW client;
they do not measure live-game FPS or guarantee server responses.

The public ZIP contains runtime files, media and documentation. Collected logs,
SavedVariables and the maintainer's private status overlay are excluded.

# Caw DPS Meter 1.1.6

- **New: Always show my own bar.** Turn it on under **Settings > General** for
  any window (off by default). While your own bar is scrolled out of view, it
  takes the last row and keeps your real rank, so you can always see where you
  stand in a long raid list. A bar that is already in view stays where it is, so
  nobody appears twice, and every player stays reachable by scrolling. It works
  in all windows and in every mode.
- **Reset keeps your view:** Reset no longer switches a window from Overall to
  Current. Each window keeps its Current or Overall selection. Only a window
  that was showing a saved fight moves to Current, because saved fights are
  cleared. Reported by Kadring.
- **Feign Death no longer wipes Hunter Threat when it was resisted:** A resisted
  Feign Death that leaves no combat-log line used to reset your local Threat
  while the server kept it. Caw now takes the reset back for that enemy when it
  still attacks you in melee shortly afterwards, or when a server Threat reply
  shows the value never dropped. Area spells and a swing already in flight do
  not count as proof of failure.

## Updating

Download `CawDPSMeter-1.1.6.zip` and replace the addon folder with the
`CawDPSMeter` folder inside it. Use `/reload` or restart the game.
Existing saved settings are retained. SuperWoW and SuperAPI are still required;
DPSLog remains optional and is installed separately.

## Validation

Automated regression checks cover the pinned own bar in the main and extra
windows (scrolling, reachability, no duplicates, short lists, pets), the Reset
selection behaviour, and the Feign Death rollback, including a case taken from a
recorded boss fight. These tests use a mocked WoW client; they do not measure
live-game FPS or guarantee server responses. The Feign Death rollback was
checked against recorded data, not yet in a new live fight.

The public ZIP contains runtime files, media and documentation. Collected logs,
SavedVariables and the maintainer's private status overlay are excluded.

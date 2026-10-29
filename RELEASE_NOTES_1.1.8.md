# Caw DPS Meter 1.1.8

- **DPSLog stays active next to other addons.** With the DPSLog Community
  Edition installed, another addon or client mod that fires the game's
  combat-log event could make Caw report an "unsupported header" and switch to
  reading the combat text. When that happened during start-up, DPSLog was
  dropped for the whole session and did nothing. Caw now takes DPSLog's events
  only through its own polling channel and ignores unrelated combat-log events,
  so these rejections stop and DPSLog keeps working. The one-time chat warning
  about a rejected event is removed; the counters are still shown by
  `/cawinput`. Reported by Icekronik and Taroven. Installations using the older
  DPSLog DLL are unchanged; if you still see combat text instead of DPSLog,
  updating to the DPSLog Community Edition is recommended.

## Updating

Download `CawDPSMeter-1.1.8.zip` and replace the addon folder with the
`CawDPSMeter` folder inside it. Use `/reload` or restart the game.
Existing saved settings are retained. SuperWoW and SuperAPI are still required;
DPSLog remains optional and is installed separately.

## Validation

Automated regression checks cover the DPSLog producer selection: a foreign
native combat-log event is ignored while polling is available and can no longer
end the start-up probe, polling still selects DPSLog from the first real event
without any rejection, and an older DLL without the polling channel still
delivers through the native event. These tests use a mocked WoW client.

The public ZIP contains runtime files, media and documentation. Collected logs,
SavedVariables and the maintainer's private status overlay are excluded.

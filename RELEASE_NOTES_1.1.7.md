# Caw DPS Meter 1.1.7

- **Thorns and other reflect damage now counts.** Thorns, Retribution Aura and
  item effects that damage attackers were not recorded when Caw reads the combat
  text. They now show up as **Damage Shield (School)** under the player, or the
  owner's pet, who carries the shield, and they add Threat like other damage.
  Enemy shields that hit your group are not counted as player damage. If you use
  DPSLog, nothing changes: DPSLog already reports shield damage itself. Reported
  by worldofwarcraftman.
- **Threat table order fixed.** The server reports each player's Threat as a
  percentage of the pull threshold (110% melee, 130% ranged), so a ranged player
  could hold more raw Threat than the tank and still show 90%, yet be listed
  above the 100% row. The list now follows the percentage you see, like
  TWThreat, and the bars fill to that percentage. Local Threat estimates are
  unchanged. Reported by Kadring.

## Updating

Download `CawDPSMeter-1.1.7.zip` and replace the addon folder with the
`CawDPSMeter` folder inside it. Use `/reload` or restart the game.
Existing saved settings are retained. SuperWoW and SuperAPI are still required;
DPSLog remains optional and is installed separately.

## Validation

Automated regression checks cover reflect lines for yourself, group members and
pets, enemy shields, roster and DPSLog edge cases, and the Threat ordering for
both the main and extra windows. These tests use a mocked WoW client. The
reflect line format follows the standard Vanilla combat text and has not yet been
captured on a live server. If damage from a shield is still missing, type
`/cdunknown` right after the fight and share the lines it prints.

The public ZIP contains runtime files, media and documentation. Collected logs,
SavedVariables and the maintainer's private status overlay are excluded.

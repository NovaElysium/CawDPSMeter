# Display / DPSLog performance checks

Measured 2026-09-16 against the installed pre-change 1.1.3 working copy, including
the recent unpublished appearance and settings changes. This is not a comparison
against the public 1.1.3 ZIP.

## Method

`benchmark_display.py --baseline PATH_TO_PRE_CHANGE_LUA_FILES` loads each version
into a separate Lua 5.1 VM with the mocked WoW API. The shipped sources remain
Lua 5.0. Five paired runs per case, 300 refresh steps (0.21 simulated seconds per
step); initialization and cache priming are outside the timed region.

The fixture has 40 invented players and 10 owned pets. Damage, melee and effective
healing are seeded through the real DPSLog adapter. Live cases feed another 25
structured events per step (7,500 events) with calibration recording enabled.
Visible cases include the player detail window; extra meters show the same
damage segment. Historical data is unchanged throughout the history case.

Actor/spell amounts, hits, critical hits, effective healing, diagnostic event
counts and the rendered primary/detail total labels matched the baseline in
all five paired runs of all four cases.

| Workload | Before, median ms | After, median ms | Sort calls before / after | Bar value writes before / after |
| --- | ---: | ---: | ---: | ---: |
| Finished fight, four meters + details | 486.73 | 36.56 | 1,500 / 0 | 18,300 / 0 |
| Live fight, one meter + details | 400.37 | 406.99 | 600 / 450 | 5,700 / 5,700 |
| Live fight, four meters + details | 602.48 | 585.54 | 1,500 / 450 | 18,300 / 18,300 |
| DPSLog events with calibration, no UI ticks | 91.20 | 82.55 | 0 / 0 | 0 / 0 |

Live cases replaced the DPSLog diagnostic status table 7,500 times before and
zero times after, with the same final event counts. The existing one-second
metadata check and explicit state/error/logout snapshots remain available;
the timed event-only case isolates event handling rather than all frame ticks.

## Interpretation and limits

- The large, repeatable reduction is in unchanged history views. Live timing
  changes are modest: the single-window case was about 1.7% slower in this run,
  so there is no demonstrated general live-combat rendering speedup.
- Value validation still scans actors/spells, so late sync corrections and
  ownership changes remain visible without depending on parser-specific dirty
  flags. Caches avoid repeated sorts and allocations; unchanged timer refreshes
  also skip bar/detail painting. Header/footer updates continue normally.
- Live rates and active aura durations are recalculated. Main/extra threat bars
  never use the paint skip, since percentages can change independently of rows.
- Explicit settings refreshes, mode changes, scrolling and resizing still draw
  immediately. Searches/name sorting do not mutate the value-sorted spell cache.
- The benchmark does not measure native UI rendering, client FPS, Lua 5.0 garbage
  collection pauses, network latency, the private local overlay or real raids.
  It is not a promise of a particular in-game FPS gain.

The display regression group adds 31 behavioral checks. The complete existing
regression suite and the two-client sync integration suite also pass. The next
useful validation is in-game play with DPSLog, multiple windows and a detail
window, including a finished fight while another fight is being recorded.

## Destination recording check (2026-09-16)

The same 300-iteration, five-repeat replay was run against the local copy made
immediately before adding target/recipient counters. Existing totals and visible
spell results matched. This workload exercises recording with the ordinary
spell view open; it does not benchmark a large destination list.

| Scenario | Before, median ms | After, median ms |
| --- | ---: | ---: |
| Finished fight | 49.54 | 46.69 |
| Live, one meter | 524.24 | 509.60 |
| Live, four meters | 710.72 | 739.49 |
| 7,500 events, no visible UI | 97.58 | 109.52 |

Event-only overhead was about 12 ms across 7,500 events in this mock run. Sort
counts, bar writes and status-table replacements remained unchanged. Smaller
timing differences include run-to-run noise. Destination data uses per-target
and per-spell counters, not a list of raw events. Recording itself adds no sync traffic.
Target views cache their rows until their counters, ownership or totals change.

## On-demand destination sync (2026-09-16)

A second 300-iteration, five-repeat comparison used the local copy made just
before destination sync. Totals, sort counts and bar writes matched. Median
times before/after were 44.89/44.69 ms for a finished fight, 484.33/501.98 ms
for one live meter, 735.43/702.73 ms for four, and 103.74/105.38 ms for event
processing alone. This replay does not open the destination tab, so it measures
ordinary meter behavior, not transfer latency or native rendering.

`python -B tests/run_target_sync.py` runs the original two-client integration
suite and 35 destination-sync checks using real addon packets. It verifies
current/history/Overall matching, concurrent local hits, owned pets, measured
overheal, retries, cancellation, malformed/lost packets and sender pacing.
Complete or hidden views send no destination requests; periodic painting never
re-requests them. New requests have a five-second global gap and a 30-second
per-view cooldown. One owner responds at a time, at most one packet per 100 ms,
with a 240-byte packet limit and caps of 16 actors, 80 destinations and 256
spell records. Oversized snapshots are declined as a whole. Transfers expire
after 40 seconds; an Overall request plan expires after 45 seconds and can use
only the fights retained in local history. Ordinary combat packets take priority.

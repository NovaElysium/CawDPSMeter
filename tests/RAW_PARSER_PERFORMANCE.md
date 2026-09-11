# RAW parser measurements

Measured locally on 2026-09-11 against the unchanged 1.1.1 checkout at `fd34fa2`.
The addon still uses its own parser; no ParserLib dependency or DLL was added.

## Changes

- Cache the existing event-family parser order for up to 128 event names.
  Uncached/custom events keep their existing fallback and parsing order. The
  cache stores no combat results, actor identities or spell names.
- Use necessary literal fragments to rule out non-damage/non-healing lines
  before pattern matching. Preserve unknown-event diagnostics.
- Skip self-target damage patterns when the line cannot target `you`.
- Extract the CC-breaking ability together with its source and target instead
  of searching the same line again. Ownership and interrupt accounting use the
  same downstream code as before.

## First-pass results

Seven runs per version, 150 repetitions of each sequence per timed run. Values
are median elapsed processing times in milliseconds, measured with Python's
`perf_counter`. Lua execution and mocked API calls are timed; addon loading,
state serialization and the separate string-search profiler are excluded.

| Corpus | Events per run | Before | After | Time reduction | Pattern searches per sequence, before / after |
| --- | ---: | ---: | ---: | ---: | ---: |
| Synthetic damage, 40 roster actors | 19,350 | 286.182 | 259.072 | 9.5% | 3,781 / 2,575 |
| Synthetic healing, auras and utility | 6,000 | 60.551 | 48.015 | 20.7% | 1,898 / 1,056 |
| Mixed events, including custom subtypes | 50,250 | 700.099 | 636.912 | 9.0% | 11,545 / 7,296 |
| 24 captured RAW text samples | 3,600 | 73.428 | 53.556 | 27.1% | 917 / 571 |

These are Lua 5.1 measurements with the existing mocked Vanilla APIs. Only
legacy table iteration is adapted in memory. Shipped code remains Lua 5.0
compatible. The test does not render frames, emulate the complete game client,
measure in-game FPS, or establish performance in a real raid. Background load
and timing variance affect the percentages; the reduced pattern-search counts
are deterministic. An earlier shorter run measured 18-24% less elapsed time.

The 24 captured samples are unchanged text from private calibration records,
not a complete or representative raid recording. They are replayed as a text
corpus with a fixed mock roster, not used to reconstruct the original fights.
Player names and private SavedVariables are not included in this repository.

## First-pass correctness

After each of 732 events, compare actor totals and spell details, pet ownership,
threat/target state, incoming damage, CC, interrupts, aura tracking, unknown-event
diagnostics and calibration records against the old version. Repeat in three
configurations: RAW, DPSLog active with RAW utility, and RAW with calibration.
All 2,196 state comparisons matched. The calibration configuration checks both
versions with collection enabled; its timing is not used in the table above.

The corpus includes a 204-event boundary sequence covering cache saturation
with 160 custom event names, normal events after saturation, same-frame and
expired failed casts, unresolved targets, overkill and local death.

The final local build also passed 283 combat/data regressions, 158 UI checks,
25 release-UI checks, 38 threat-alert checks, local status-overlay checks and
all ten two-client synchronization checks.

## Utility follow-up

The supplied SuperWoW-aware ParserLib identifies itself as 1.1, revision 16001
(its header still says 15186). Compared with Chronometer's revision 15186, it
adds RAW_COMBATLOG registration/dispatch, corresponding unsubscribe handling,
and a GUID-to-name helper. The pattern cache and literal optimizer are already
present in the older copy. Caw already consumes the SuperWoW RAW stream, so
this adapter does not provide a new combat data source for Caw. Neither copy
of ParserLib is bundled or loaded by this change.

Reference ParserLib.lua SHA-256:
`84e6186ae6f6ee856c60d074c6584d038190cf2b893f66e5fa983e528d7d664d`.

The follow-up adds necessary literal guards around utility pattern groups,
preserving their order and custom-event fallback. Resource gains share one
pattern plus an exact spelling lookup. Pre-combat capture retains its existing
case-insensitive behavior but lowercases each buff once instead of repeatedly.
Unknown-event diagnostics, interrupt correlation, dispels and aura source
backfilling still use the existing recording logic.

No table pool was added. This parsing path already uses scalar captures; the
tables it creates hold pending casts, aura state or recorded events that survive
the current callback. There is no generic disposable result table here like
ParserLib's `self.info`, and no measured reason to add a pooling layer.

### Incremental measurements

Measured against the local build **after the first pass**, not against the
public release. Seven alternating baseline/candidate pairs, 150 repetitions
per timed run. Each sample starts with a fresh VM and one warm-up pass.

Baseline core SHA-256:
`fc9f72390a05f7b20583f5cf2e0814b32bb48a3f9d9fa3398cdd16451e33af4a`.
Candidate core SHA-256:
`708268dc71cd55c6547bdd72370da74807532be81fdee9610b1f8670fc3e6a44`.

| Corpus | Events per run | Before (ms) | After (ms) | Time reduction | Pattern searches per sequence, before / after |
| --- | ---: | ---: | ---: | ---: | ---: |
| Synthetic damage, 40 roster actors | 19,350 | 273.221 | 276.771 | -1.3% | 2,575 / 2,526 |
| Synthetic healing, auras and utility | 6,000 | 64.893 | 57.115 | 12.0% | 1,056 / 524 |
| Mixed events, including custom subtypes | 50,250 | 686.932 | 669.564 | 2.5% | 7,296 / 6,083 |
| 24 captured RAW text samples | 3,600 | 54.889 | 46.792 | 14.8% | 571 / 367 |

The pure-damage median was slightly slower; its sample ranges overlap
(baseline 265.255-297.537 ms, candidate 266.535-301.805 ms), so no improvement is
claimed for that workload. The earlier short run also had mixed timing results.
Host load remains visible even with alternating samples; these figures are
observations, not promised FPS gains. Do not add the two passes' percentages.

### Follow-up correctness

All 3,084 per-event state comparisons matched the pre-utility baseline: the
existing 2,196 comparisons plus 148 additional utility events in six
configurations. These cover all five miss/resist forms, non-damaging interrupts,
outside-roster sources, both explicit interrupt forms, aura origin/backfill,
duplicate dispels, resource capitalization/spacing, malformed text and spell
names containing parser keywords. Each RAW/DPSLog/calibration configuration is
checked with combat initially active and inactive; buff events run first so
pre-combat state is exercised before a utility event can start an encounter.
Snapshots also include pre-combat buffs, self-dispel deduplication and direct
roster aura-cast state.

The full combat/data (283), UI (158), release UI (25), threat alert (38), three
local-overlay groups and ten two-client sync checks passed again. The event
closure remains within Vanilla's 32-upvalue limit. The mocked Lua 5.1 runtime
does not replace an actual Lua 5.0 client or an in-game raid test.

## Reproduce

Install Lupa or use the existing `%TEMP%/caw-review-lupa` dependency. Pass an
unchanged addon directory as `--baseline`; the candidate defaults to this tree.
The baseline and candidate must both contain the public runtime modules.

```text
python tests/benchmark_raw_parser.py --baseline PATH_TO_OLD_ADDON --repeats 7 --rounds 150 --output benchmark.json
```

Optionally add `--saved-variables PATH_TO_CawDPSMeter.lua` to include local RAW
text samples. Without it, synthetic sequences and boundary checks still run.
The JSON report contains measurements and source hashes, not captured text.

Run the existing functional and UI regressions separately:

```text
python tests/run_regressions.py
python tests/run_sync_integration.py
```

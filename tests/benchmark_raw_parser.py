"""Compare RAW event handling against an unmodified addon checkout (Lua 5.1).

Uses mocked Vanilla APIs, deterministic mixed events and optional private RAW
samples. This measures addon processing time, not in-game FPS or real raid performance.
No saved variables or captured player names are written to the report.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import statistics
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(os.environ.get('TEMP', '/tmp')) / 'caw-review-lupa'))
from lupa.lua51 import LuaRuntime, lua_type

MODULES = ('CawDiagnostics.lua', 'CawHeader.lua', 'CawDPSMeter.lua',
           'CawDPSLog.lua', 'CawSpellIcons.lua', 'CawThreat.lua', 'CawThreatSync.lua',
           'CawTalentSync.lua', 'CawThreatCalibration.lua', 'CawServerThreat.lua',
           'CawDiagnosticsCommands.lua', 'CawPfUI.lua', 'CawUI.lua',
           'CawTalentView.lua', 'CawBreakdown.lua')
LEGACY_FOR = r'\b(for\s+\w+(?:\s*,\s*\w+)*\s+in\s+)([\w.]+(?:\[[^\]\n]+\])?)\s+do\b'


def raw(ev, text):
    return ['RAW_COMBATLOG', 'CHAT_MSG_' + ev, text]


def corpus():
    damage = []
    for i in range(1, 41):
        source = f'0x{i:X}'
        damage += [raw('COMBAT_FRIENDLYPLAYER_HITS', f'{source} hits 0xF1 for 120.'),
                   raw('SPELL_PARTY_DAMAGE', f"{source}'s Lightning Bolt crits 0xF1 for 240."),
                   raw('SPELL_PERIODIC_CREATURE_DAMAGE', f"0xF1 suffers 18 Fire damage from {source}'s Flame Shock.")]
    damage += [raw('COMBAT_SELF_HITS', 'You hit 0xF1 for 120. (glancing)'),
               raw('SPELL_SELF_DAMAGE', 'Your Raptor Strike hits 0xF1 for 220.'),
               raw('COMBAT_PET_HITS', '0xB1 hits 0xF1 for 35.'),
               raw('SPELL_PET_DAMAGE', "0xB1's Claw crits 0xF1 for 90."),
               raw('COMBAT_CREATURE_VS_SELF_HITS', '0xF1 hits you for 75.'),
               raw('SPELL_CREATURE_VS_PARTY_DAMAGE', "0xF1's Bolt crits 0x2 for 150."),
               raw('SPELL_PERIODIC_SELF_DAMAGE', "You suffer 25 Shadow damage from 0xF1's Pain."),
               raw('SPELL_PERIODIC_PARTY_DAMAGE', "0x2 suffers 25 Shadow damage from 0xF1's Pain."),
               raw('SPELL_PARTY_DAMAGE', "0xEE's Bolt hits 0xF1 for 90.")]
    utility = [raw('SPELL_CREATURE_VS_SELF_DAMAGE', '0xF1 begins to cast Bolt.'),
               ['UNIT_CASTEVENT', '0xF1', '0x1', 'FAIL', 100],
               raw('SPELL_FRIENDLYPLAYER_DAMAGE', "0x2's Kick hits 0xF1 for 10."),
               raw('SPELL_FRIENDLYPLAYER_DAMAGE', "0x2's Kick interrupts 0xF1's Bolt."),
               raw('SPELL_CREATURE_VS_SELF_DAMAGE', '0xF1 begins to cast Bolt.'),
               raw('SPELL_SELF_DAMAGE', 'Your Kick misses 0xF1.'),
               raw('SPELL_PARTY_DAMAGE', "0x2's Kick was resisted by 0xF1."),
               ['UNIT_CASTEVENT', '0xF1', '0x1', 'CAST', 100],
               raw('SPELL_SELF_DAMAGE', 'Your Kick hits 0xF1 for 10.'),
               raw('SPELL_SELF_DAMAGE', 'You cast Polymorph on 0xF1.'),
               raw('SPELL_PERIODIC_CREATURE_DAMAGE', '0xF1 is afflicted by Polymorph.'),
               raw('SPELL_PARTY_DAMAGE', "0x2's Sinister Strike hits 0xF1 for 60."),
               raw('SPELL_BREAK_AURA', 'Polymorph fades from 0xF1.'),
               raw('SPELL_SELF_BUFF', 'Your Heal critically heals you for 80.'),
               raw('SPELL_FRIENDLYPLAYER_BUFF', "0x4's Heal heals 0x2 for 150."),
               raw('SPELL_PERIODIC_PARTY_BUFFS', "0x2 gains 38 health from 0x4's Renew."),
               raw('SPELL_PERIODIC_SELF_BUFFS', "You gain 38 health from 0x4's Renew."),
               raw('SPELL_PERIODIC_PARTY_BUFFS', '0x2 gains 38 health from your Renew.'),
               raw('SPELL_PERIODIC_SELF_BUFFS', 'You gain 38 health from your Renew.'),
               raw('SPELL_PERIODIC_SELF_BUFFS', 'You gain 38 Mana from Mana Spring.'),
               raw('SPELL_PERIODIC_PARTY_BUFFS', '0x2 gains 38 Rage from Rage.'),
               raw('SPELL_PERIODIC_SELF_BUFFS', 'You gain Blessing of Might.'),
               raw('SPELL_PERIODIC_SELF_BUFFS', 'You gain Zeal (2).'),
               raw('SPELL_PERIODIC_PARTY_BUFFS', '0x2 gains Renew.'),
               raw('SPELL_PERIODIC_SELF_DAMAGE', 'You are afflicted by Pain.'),
               raw('SPELL_AURA_GONE_SELF', 'Zeal (2) fades from you.'),
               raw('SPELL_AURA_GONE_PARTY', 'Renew fades from 0x2.'),
               raw('SPELL_BREAK_AURA', 'Your Pain is removed.'),
               raw('SPELL_SELF_BUFF', 'You cast Purify.'),
               raw('SPELL_PARTY_BUFF', "0x4's Dispel Magic removes Pain from 0x2."),
               raw('SPELL_SELF_DAMAGE', 'You cast Feign Death.'),
               raw('SPELL_PERIODIC_SELF_BUFFS', 'You gain Feign Death.'),
               raw('SPELL_SELF_BUFF', 'You cast Searing Totem.'),
               raw('SPELL_PET_DAMAGE', "0xB2's Searing Bolt hits 0xF1 for 25."),
               raw('COMBAT_FRIENDLY_DEATH', '0xF1 dies.'),
               raw('SPELL_HEAL_CUSTOM', 'Unrecognized healing event.'),
               raw('SPELL_PERIODIC_CUSTOM', 'Unrecognized periodic event.'),
               raw('SPELL_CUSTOM', 'Unrecognized server event.'),
               ['RAW_COMBATLOG', None, 'Your Raptor Strike hits 0xF2 for 15.'],
               ['RAW_COMBATLOG', 'CHAT_MSG_SPELL_SELF_DAMAGE', None]]
    # All fallback forms must still be reachable on unknown/custom subtypes.
    custom = [raw('CUSTOM_EXTENSION', row[2]) for row in damage + utility
              if row[0] == 'RAW_COMBATLOG' and row[2] is not None]
    return {'damage': damage, 'utility': utility, 'mixed': damage + utility + custom}


def boundary_corpus():
    # Unique extension subtypes exceed the bounded route cache. Known events
    # after that still need their original ordering (especially HoTs on BUFFS).
    rows = [raw('SERVER_EXTENSION_' + str(i), "0x2's Bolt hits 0xF1 for 1.")
            for i in range(160)]
    rows += [raw('SPELL_PERIODIC_PARTY_BUFFS', "0x2 gains 38 health from 0x4's Renew."),
             raw('SPELL_PERIODIC_SELF_BUFFS', 'You gain Zeal (3).'),
             raw('SPELL_HEAL_UNKNOWN', 'Unknown event without a healing amount.'),
             raw('SPELL_SELF_DAMAGE', 'Your Raptor Strike crits 0xF1 for 12.'),
             raw('COMBAT_SELF_HITS', 'You hit Unresolved Name for 15.'),
             raw('SPELL_CREATURE_VS_SELF_DAMAGE', '0xF1 begins to cast Long Bolt.'),
             ['UNIT_CASTEVENT', '0xF1', '0x1', 'FAIL', 100]]
    # A delayed Kick must not count as an interrupt of an expired failed cast.
    rows += [raw('SERVER_EXTENSION_IDLE', 'Unrecognized event.') for _ in range(30)]
    rows += [raw('SPELL_FRIENDLYPLAYER_DAMAGE', "0x2's Kick hits 0xF1 for 10."),
             raw('SPELL_CREATURE_VS_SELF_DAMAGE', '0xF1 begins to cast Bolt.'),
             ['UNIT_CASTEVENT', '0xF1', '0x1', 'FAIL', 100],
             raw('SPELL_FRIENDLYPLAYER_DAMAGE', "0x2's Kick hits 0xF1 for 10."),
             raw('SPELL_CREATURE_VS_SELF_DAMAGE', "0xF1's Bolt crits you for 100. (25 overkill)"),
             raw('COMBAT_FRIENDLY_DEATH', 'You die.'),
             raw('SPELL_PERIODIC_SELF_BUFFS', "You gain 38 health from 0x4's Renew.")]
    return rows


def saved_samples(path):
    vm = LuaRuntime()
    vm.execute(path.read_text(encoding='utf-8', errors='replace'))
    rows = []

    def visit(value):
        if lua_type(value) != 'table':
            return
        ev, text = value['event'], value['text']
        if isinstance(ev, str) and ev.startswith('CHAT_MSG_') and isinstance(text, str):
            rows.append(['RAW_COMBATLOG', ev, text])
        for key in sorted(value.keys(), key=lambda k: (str(type(k)), str(k))):
            if lua_type(value[key]) == 'table':
                visit(value[key])

    visit(vm.globals().CawThreatCalibrationDB)
    return rows


def utility_boundaries():
    rows = []
    for source in ['Your', "0x2's", "0xEE's"]:
        for failure in ['misses', 'was dodged by', 'was parried by',
                        'was resisted by', 'is resisted by']:
            rows += [raw('SPELL_CREATURE_VS_SELF_DAMAGE', '0xF1 begins to cast Bolt.'),
                     raw('SPELL_CUSTOM', f'{source} Kick {failure} 0xF1.')]
        for spell in ['Counterspell', 'Spell Lock', 'Polymorph', 'Unrecognized Spell']:
            rows += [raw('SPELL_CREATURE_VS_SELF_DAMAGE', '0xF1 begins to cast Bolt.'),
                     raw('SPELL_CUSTOM', f'{source} {spell} hits 0xF1.')]
    rows += [raw('SPELL_CUSTOM', text) for text in [
        "0x2's Kick interrupts 0xF1.", "0xEE's Kick interrupts 0xF1's Bolt.",
        '0x4 casts Renew on 0x2.', '0xEE casts Renew on 0x2.',
        '0x2 casts Polymorph on 0xF1.', '0xF1 is afflicted by Polymorph.',
        "0x2's Purge dispels Renew from 0xF1.",
        "0xEE's Purge removes Renew from 0xF1.",
        'You cast Purify.', 'You cast Purify.', 'You cast Feign Death.',
        'You cast Renew on 0x2.', 'You cast Unrecognized Spell on 0xF1.']]
    rows += [raw('SPELL_BREAK_AURA', 'Your Pain is removed.'),
             raw('SPELL_SELF_BUFF', 'You cast Purify.'),
             raw('SPELL_BREAK_AURA', 'Your Pain is removed.'),
             raw('SPELL_SELF_BUFF', 'You cast Purify.')]
    # Resource casing/spacing must keep its existing classification, including
    # the deliberately case-insensitive pre-combat capture boundary.
    resources = ['health', 'Health', 'mana', 'Mana', 'rage', 'Rage', 'energy',
                 'Energy', 'MANA', 'hEaLtH', 'Focus', '', 'mana ', ' mana']
    for resource in resources:
        for source in ['You gain', '0x2 gains']:
            rows.append(raw('SPELL_PERIODIC_PARTY_BUFFS',
                            f"{source} 38 {resource} from 0x4's Renew."))
    rows += [raw('SPELL_PERIODIC_SELF_BUFFS', text) for text in [
        'You gain 38 MANA FrOm Spring.', 'You gain 38 mana FROM Spring.',
        'You gain +38 Mana from Spring.', 'You gain 38.5 Mana from Spring.',
        'You gain Blessing of Might.', 'You gain Zeal (3).',
        'You gain 38 mana from.', 'You gain 38 mana from ',
        'You gain 38 mana from .', 'You gain zero mana from Spring.']]
    # Keyword-like spell names and malformed messages must not change pattern
    # precedence or suppress unknown-event diagnostics.
    tricky = ['Your aura is removed', '0xF1 begins to cast Bolt',
              'Renew fades from 0x2', 'You cast', 'You gain',
              "0x2's Kick interrupts 0xF1", 'You are afflicted by',
              'Your Return by Dawn hits 0xF1.', 'You gain Echo hits Shadow.',
              'You gain Dawn fades from Dusk.',
              '0x2 is afflicted by Echo interrupts Silence.',
              'You cast Echo is removed. on 0xF1.',
              "0x2's Return casts Shadow hits 0xF1."]
    for event in ['SPELL_PERIODIC_SELF_BUFFS', 'SPELL_CUSTOM', 'SPELL_BREAK_AURA']:
        rows += [raw(event, text) for text in tricky]
    # Put buffs first so the pre-combat configuration exercises them before a
    # successful interrupt/hostile utility event can open a combat segment.
    return ([row for row in rows if row[1].endswith('BUFFS')]
            + [row for row in rows if not row[1].endswith('BUFFS')])


SETUP = r'''
local D=CAW_DPS_METER
UNITS.pet.guid='0xB1'
GetNumRaidMembers=function() return 40 end
for i=1,40 do
    UNITS['raid'..i]={guid=string.format('0x%X',i),name='Player'..i,
        class=({ 'HUNTER','ROGUE','SHAMAN','PRIEST' })[math.mod(i-1,4)+1]}
end
UNITS.raid1=UNITS.player
PLAYER_COMBAT=true
fire(D.diagBootstrapFrame,'ADDON_LOADED','CawDPSMeter')
fire(D.events,'ADDON_LOADED','CawDPSMeter')
fire(D.events,'PLAYER_ENTERING_WORLD')
D.threatCalEnabled=false
SlashCmdList.CAWDPS('reset')
D.inCombat=true; D.startTime=NOW; D.lastFinalizeAt=0
-- Both VMs get the same clock and event order; native rendering is not timed.
function benchRun(rows,rounds,trace)
    local states={}
    for r=1,rounds do
        for i=1,table.getn(rows) do
            NOW=NOW+0.03125
            fire(D.events,unpack(rows[i],1,5))
            if trace then states[table.getn(states)+1]=benchSnapshot() end
        end
    end
    return states
end
local stateFields={
    'actors','guidToActor','petOwner','summonActors','globalUtility',
    'currentEnemyDamage','currentEnemyNames','currentEnemyBestGuid',
    'currentEnemyBestDamage','currentFightName','deadEnemies','activeCC',
    'activeEnemyCasts','recentInterrupts','recentAuraCasts','recentAuraOrigins',
    'activeAuraSources','activeRosterBuffs','lastIncomingDamage','lastSelfIncomingDamage',
    'lastCCDamage','ccDamageByTarget','pendingSelfTotem','pendingItemSummons',
    'pendingSelfDispel','recentSelfDispelCast','threatPendingCast','threatPendingReset',
    'threatFeignCommitted','threatFeignUndo','rawUnknown','utilityUnknown',
    'rawUnknownCount','utilityUnknownCount','ignoredOutsiders','rawTotal','parsedTotal',
    'lastParsed','lastUtility','inCombat','startTime','segmentSerial','lastRosterCombatActivity',
    'localPlayerDead','dpsLogRawCommitted','threatCalSession',
    'lastPreCombatBuff','lastSelfDispelRecord','recentDirectRosterAuraCasts'
}
local function serialize(value)
    if type(value)~='table' then return type(value)..':'..tostring(value) end
    local keys,out={},{}
    for key in pairs(value) do table.insert(keys,key) end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,key in ipairs(keys) do
        table.insert(out,serialize(key)..'='..serialize(value[key]))
    end
    return '{'..table.concat(out,';')..'}'
end
function benchSnapshot()
    local result={}
    for _,key in ipairs(stateFields) do result[key]=D[key] end
    return serialize(result)
end
function benchProfile(rows)
    local original=string.find
    local counts={pattern=0,plain=0,callers={}}
    string.find=function(...)
        local mode=select(4,...) and 'plain' or 'pattern'
        counts[mode]=counts[mode]+1
        local caller=debug.getinfo(2,'n').name or '?'
        counts.callers[caller]=(counts.callers[caller] or 0)+1
        return original(...)
    end
    benchRun(rows,1,false)
    string.find=original
    return counts
end
'''


def new_vm(addon, dpslog=False, calibration=False):
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute((ROOT / 'tests/mock_wow.lua').read_text(encoding='utf-8'))
    for name in MODULES:
        code = (addon / name).read_text(encoding='utf-8')
        vm.execute(re.sub(LEGACY_FOR, r'\1pairs(\2) do', code), name=name)
    vm.execute(SETUP)
    vm.globals().CAW_DPS_METER.dpsLogActive = dpslog
    vm.globals().CAW_DPS_METER.threatCalEnabled = calibration
    return vm


def trace(addon, rows, dpslog, calibration, precombat=False):
    vm = new_vm(addon, dpslog, calibration)
    if precombat:
        vm.execute('PLAYER_COMBAT=false; CAW_DPS_METER.inCombat=false; CAW_DPS_METER.startTime=0')
    result = vm.globals().benchRun(vm.table_from(rows, recursive=True), 1, True)
    return list(result.values())


def timed_sample(addon, rows, rounds):
    vm = new_vm(addon)
    events = vm.table_from(rows, recursive=True)
    vm.globals().benchRun(events, 1, False)
    vm.execute("collectgarbage('collect')")
    started = time.perf_counter()
    vm.globals().benchRun(events, rounds, False)
    return time.perf_counter() - started


def measurement(addon, rows, rounds, elapsed):
    vm = new_vm(addon)
    counts = vm.globals().benchProfile(vm.table_from(rows, recursive=True))
    return {'median_ms': round(statistics.median(elapsed) * 1000, 3),
            'events_per_run': len(rows) * rounds,
            'samples_ms': [round(e * 1000, 3) for e in elapsed],
            'pattern_calls_per_pass': counts['pattern'], 'plain_calls_per_pass': counts['plain'],
            'callers': dict(sorted(counts['callers'].items(), key=lambda kv: -kv[1]))}


def measure_pair(baseline, candidate, rows, repeats, rounds):
    # Alternate the order within each pair to reduce bias from changing host
    # load. Loading and profiling remain outside all timed sections.
    addons = [baseline, candidate]
    elapsed = [[], []]
    for repeat in range(repeats):
        for index in ([0, 1] if repeat % 2 == 0 else [1, 0]):
            elapsed[index].append(timed_sample(addons[index], rows, rounds))
    return [measurement(addons[index], rows, rounds, elapsed[index]) for index in [0, 1]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, default=ROOT)
    parser.add_argument('--saved-variables', type=Path)
    parser.add_argument('--repeats', type=int, default=5)
    parser.add_argument('--rounds', type=int, default=60)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    sets = corpus()
    if args.saved_variables:
        samples = saved_samples(args.saved_variables)
        if samples:
            sets['captured_raw'] = samples
    report = {'environment': 'Lua 5.1 with mocked Vanilla APIs; no rendering or FPS benchmark',
              'timing_order': 'alternating baseline/candidate pairs',
              'baseline_core_sha256': hashlib.sha256((args.baseline/'CawDPSMeter.lua').read_bytes()).hexdigest(),
              'candidate_core_sha256': hashlib.sha256((args.candidate/'CawDPSMeter.lua').read_bytes()).hexdigest(),
              'results': {}}
    for name, rows in sets.items():
        for dpslog, calibration in [(False, False), (True, False), (False, True)]:
            verify_trace(args.baseline, args.candidate, name, rows, dpslog, calibration)
        before, after = measure_pair(args.baseline, args.candidate, rows, args.repeats, args.rounds)
        result = {'trace_events': len(rows), 'equivalence_modes': 3,
                  'baseline': before, 'candidate': after,
              'time_reduction_percent': round((1-after['median_ms']/before['median_ms'])*100, 1)}
        report['results'][name] = result
        print(f'{name}: {len(rows)} events match after every event in 3 modes; '
              f"{before['median_ms']} -> {after['median_ms']} ms ({result['time_reduction_percent']}% reduction)", flush=True)
    boundary = boundary_corpus()
    for dpslog, calibration in [(False, False), (True, False), (False, True)]:
        verify_trace(args.baseline, args.candidate, 'boundaries', boundary, dpslog, calibration)
    report['boundary_trace_events'] = len(boundary)
    print(f'boundaries: {len(boundary)} events match after every event in 3 modes', flush=True)
    utility = utility_boundaries()
    for precombat in [False, True]:
        for dpslog, calibration in [(False, False), (True, False), (False, True)]:
            verify_trace(args.baseline, args.candidate, 'utility boundaries', utility,
                         dpslog, calibration, precombat)
    report['utility_boundary_trace_events'] = len(utility)
    report['utility_boundary_configurations'] = 6
    print(f'utility boundaries: {len(utility)} events match in 6 configurations', flush=True)
    if args.output:
        args.output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


def verify_trace(baseline, candidate, name, rows, dpslog, calibration, precombat=False):
    before = trace(baseline, rows, dpslog, calibration, precombat)
    after = trace(candidate, rows, dpslog, calibration, precombat)
    assert len(before) == len(after)
    for i, (a, b) in enumerate(zip(before, after)):
        if a != b:
            pos = next((j for j in range(min(len(a),len(b))) if a[j]!=b[j]), min(len(a),len(b)))
            raise AssertionError(f'{name} event {i+1}: state differs (DPSLog={dpslog}, calibration={calibration}, precombat={precombat}); '
                                 f'offset {pos}; baseline={a[max(0,pos-90):pos+90]!r}; candidate={b[max(0,pos-90):pos+90]!r}')


if __name__ == '__main__':
    main()

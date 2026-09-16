"""Synthetic DPSLog + display replay against a local pre-change copy.

Mocked WoW APIs / Lua 5.1; this measures Lua work, not native rendering or FPS.
Only invented actors/events are used. The addon sources remain Lua 5.0.
"""
from pathlib import Path
import argparse
import json
import os
import re
import statistics
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(os.environ.get('TEMP', '/tmp')) / 'caw-review-lupa'))
from lupa.lua51 import LuaRuntime

MODULES = ('CawDiagnostics.lua', 'CawHeader.lua', 'CawDPSMeter.lua',
           'CawTargets.lua', 'CawTargetSync.lua', 'CawDPSLog.lua', 'CawSpellIcons.lua', 'CawThreat.lua', 'CawThreatSync.lua',
           'CawTalentSync.lua', 'CawThreatCalibration.lua', 'CawServerThreat.lua',
           'CawDiagnosticsCommands.lua', 'CawPfUI.lua', 'CawUI.lua',
           'CawTalentView.lua', 'CawBreakdown.lua')
LEGACY_FOR = r'\b(for\s+\w+(?:\s*,\s*\w+)*\s+in\s+)([\w.]+(?:\[[^\]\n]+\])?)\s+do\b'
SETUP = r'''
local D=CAW_DPS_METER
fire(D.events,"ADDON_LOADED","CawDPSMeter")
fire(D.events,"PLAYER_ENTERING_WORLD")
PLAYER_COMBAT=true; fire(D.events,"PLAYER_REGEN_DISABLED")
D.dpsLogActive=true; D.dpsLogProbing=false; D.dpsLogInitialized=true
local sources={}
for i=1,50 do
    local guid=string.format("0x%X",i)
    local pet=i>40
    local info={key=guid,guid=guid,name=string.format("Actor%02d",i),
        isPet=pet,classToken=not pet and "HUNTER" or nil,
        ownerKey=pet and string.format("0x%X",i-40) or nil}
    sources[i]=info; D.guidToActor[guid]=info
end
local function eventFor(n)
    local info=sources[math.mod(n-1,50)+1]
    local spell=math.mod(n,12)+1
    if math.mod(n,5)==0 then
        D.dpsLogReceive("SPELL_HEAL",info.guid,info.name,1,0,"0x1","Actor01",1,0,
            1000+spell,"Heal"..spell,2,180,40,0,"1")
    elseif math.mod(n,3)==0 then
        D.dpsLogReceive("SWING_DAMAGE",info.guid,info.name,1,0,"0xF1","Enemy",64,0,
            100,-1,1,0,0,0,nil)
    else
        D.dpsLogReceive("SPELL_DAMAGE",info.guid,info.name,1,0,"0xF1","Enemy",64,0,
            2000+spell,"Spell"..spell,4,200,-1,4,0,0,0,"1")
    end
end
for i=1,600 do eventFor(i) end
D.mode="damage"; D.segment="current"; D.scrollOffset=0
D.window:SetHeight(420); D.window:Show()
local windows={D.window}
if BENCH_CASE~="live_one" and BENCH_CASE~="events" then
    for i=2,4 do
        local v=D.createMultiWindow(nil)
        v.segment="current"; v.mode="damage"; v.frame:SetHeight(420)
        table.insert(windows,v.frame)
    end
end
if BENCH_CASE=="history" then
    D.inCombat=false; D.lastDuration=30
    D.fightHistory={{actors=D.actors,name="Enemy",duration=30}}
    D.segment="history"; D.segmentIndex=1
    for _,v in pairs(D.multiWindows) do v.segment="history"; v.segmentIndex=1 end
end
D.uiRefreshMeters(); D.openBreakdown(D.actors['0x1'],nil)
if BENCH_CASE=="events" then D.breakdownPanel:Hide() end
if BENCH_CASE~="history" then D.threatCalEnabled=true; D.threatCalNewSession() end
local function tick(f) this=f; f.scripts.OnUpdate() end
-- Prime timer/render caches before counting steady-state work.
for _,f in ipairs(windows) do tick(f) end
if BENCH_CASE~="events" then tick(D.breakdownPanel) end
local paints=0; local sorts=0; local replacements=0
local originalSort=table.sort
table.sort=function(t,fn) sorts=sorts+1; return originalSort(t,fn) end
local function watch(rows)
    for _,row in ipairs(rows) do
        local original=row.bar.SetValue
        row.bar.SetValue=function(self,v) paints=paints+1; original(self,v) end
    end
end
watch(D.rows)
for _,v in pairs(D.multiWindows) do watch(v.rows) end
watch(D.breakdownPanel.spells)
function benchRun(iterations)
    for step=1,iterations do
        NOW=NOW+0.21
        if BENCH_CASE~="history" then
            for j=1,25 do
                local before=D.threatCalSession.dpsLogStatus
                eventFor((step-1)*25+j)
                if before~=D.threatCalSession.dpsLogStatus then replacements=replacements+1 end
            end
        end
        if BENCH_CASE~="events" then
            for _,f in ipairs(windows) do tick(f) end
            tick(D.breakdownPanel)
        end
    end
    return sorts,paints,replacements
end
function benchResult()
    local result={}
    for _,info in ipairs(sources) do
        local a=D.actors[info.key]
        table.insert(result,string.format("%s:%s:%s:%s:%s",a.key,a.damage,a.healing,a.hits,a.heals))
        local names={}
        for name,s in pairs(a.spells) do table.insert(names,name..":"..s.damage..":"..s.hits..":"..s.crits) end
        for name,s in pairs(a.healSpells) do table.insert(names,name..":"..s.healing..":"..s.hits..":"..s.crits) end
        originalSort(names)
        table.insert(result,table.concat(names,","))
    end
    if BENCH_CASE~="events" then
        table.insert(result,D.mainView.summary:GetText())
        table.insert(result,D.breakdownPanel.totalText:GetText())
    end
    local s=D.threatCalSession and D.threatCalSession.dpsLogStatus
    table.insert(result,tostring(s and s.received or D.dpsLogEvents))
    return table.concat(result,"|")
end
'''


def run(root, case, iterations):
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute((ROOT / 'tests/mock_wow.lua').read_text(encoding='utf-8'))
    vm.execute('CawDPSMeterCharDB={parserEnabled=true,combatSyncEnabled=false,threatCalAutoStart=false}')
    for name in MODULES:
        if name in ('CawTargets.lua', 'CawTargetSync.lua') and not (root / name).exists():
            continue  # Older baselines predate destination recording.
        code = (root / name).read_text(encoding='utf-8-sig')
        vm.execute(re.sub(LEGACY_FOR, r'\1pairs(\2) do', code), name=name)
    vm.globals().BENCH_CASE = case
    vm.execute(SETUP)
    vm.execute('collectgarbage("collect")')
    start = time.perf_counter()
    sorts, paints, replacements = vm.globals().benchRun(iterations)
    elapsed = (time.perf_counter() - start) * 1000
    result = vm.globals().benchResult()
    return elapsed, sorts, paints, replacements, result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--iterations', type=int, default=300)
    parser.add_argument('--repeats', type=int, default=5)
    args = parser.parse_args()
    report = {}
    for case in ('history', 'live_one', 'live_four', 'events'):
        samples = {name: [] for name in ('before', 'after')}
        for _ in range(args.repeats):
            before = run(args.baseline, case, args.iterations)
            after = run(ROOT, case, args.iterations)
            assert before[4] == after[4], f'Data/display mismatch in {case}'
            samples['before'].append(before)
            samples['after'].append(after)
        report[case] = {name: {'median_ms': round(statistics.median(r[0] for r in rows), 2),
                              'sorts': rows[0][1], 'bar_value_writes': rows[0][2],
                              'status_table_replacements': rows[0][3]}
                        for name, rows in samples.items()}
    print(json.dumps({'iterations': args.iterations, 'repeats': args.repeats,
                      'data_equal': True, 'cases': report}, indent=2))


if __name__ == '__main__':
    main()

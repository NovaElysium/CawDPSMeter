"""Real addon bus tests for on-demand destination snapshots; also runs base sync tests."""
import run_sync_integration as bus
import json

checks = 0


def check(ok, label):
    global checks
    assert ok, label
    checks += 1
    print('PASS TARGET SYNC ' + label)


def pair(raid=False):
    bus.wire.clear(); bus.sent.clear()
    a = bus.client('Alpha', '0xA', 'PRIEST', 'Bravo', '0xB', 'PRIEST')
    b = bus.client('Bravo', '0xB', 'PRIEST', 'Alpha', '0xA', 'PRIEST')
    bus.a, bus.b = a, b
    bus.clients = {'Alpha': a, 'Bravo': b}
    for vm in (a, b):
        if raid:
            vm.execute('GetNumRaidMembers=function() return 2 end; UNITS.raid1=UNITS.player; UNITS.raid2=UNITS.party1; PARTY_COUNT=0')
        vm.execute('''
        NOW=1000; PLAYER_COMBAT=true
        local d=CAW_DPS_METER
        fire(d.events,'PLAYER_REGEN_DISABLED')
        d.syncRequested=true; d.threatCalEnabled=false; d.dpsLogActive=true; d.dpsLogProbing=false
        function targetDamage(dst,amount,pet)
            return d.dpsLogReceive('SPELL_DAMAGE',pet and '0xCA' or '0xA',nil,1,0,dst,'Same enemy',64,0,
                585,pet and 'Pet strike ~ test%' or 'Smite',2,amount,-1,2,0,0,0,nil)
        end
        function targetHeal(amount,over)
            return d.dpsLogReceive('SPELL_HEAL','0xA',nil,1,0,'0xB','Bravo',1,0,2060,'Heal',2,amount,over,0,nil)
        end
        targetDamage('0xF1',100); targetHeal(100,40)
        d.dpsLogReceive('SPELL_SUMMON','0xA',nil,1,0,'0xCA','Pet',1,0,1,'Pet',1)
        ''')
    a.execute("targetDamage('0xF1',200); targetDamage('0xF2',300); targetDamage('0xF1',50,true); targetHeal(200,200)")
    for i in range(25): bus.tick(1000+i*.1)
    b.execute("SlashCmdList.CAWDPSSYNCDEBUG('retry')")
    for i in range(150):
        bus.tick(1003+i*.05)
        if b.globals().CAW_DPS_METER.syncReceived == 1:
            break
    assert b.globals().CAW_DPS_METER.actors['0xA'].damage == 600
    assert b.globals().CAW_DPS_METER.actors['0xCA'].damage == 50
    return a, b


def open_targets(vm, mode='damage', segment='current'):
    vm.execute(f'''
    local d=CAW_DPS_METER
    d.mode='{mode}'; d.segment='{segment}'; d.segmentIndex=1
    local c=d.breakdownContext(); local actors=d.breakdownActors(c)
    d.openBreakdown(actors['0xA'])
    this=d.breakdownPanel.targetTab; arg1='LeftButton'; this:GetScript('OnClick')()
    ''')


def settle(vm, seconds=42, hook=None):
    start = max(client.globals().NOW for client in bus.clients.values())
    for i in range(int(seconds/.1)):
        bus.tick(start+.1+i*.1)
        if hook:
            hook()
        d = vm.globals().CAW_DPS_METER
        if d.targetSyncRequest is None and d.targetSyncPlan is None:
            vm.execute('CAW_DPS_METER.refreshBreakdown(true)')
            return
    raise AssertionError('target sync did not settle')


a, b = pair()
check(not any(msg.startswith('Y~') for _, msg, _ in bus.sent), 'hidden and ordinary meter views create no destination traffic')
check(b.globals().CAW_DPS_METER.threatSyncPeers['0xA'].targetDetails, 'capability discovery identifies the updated owner')
open_targets(b)
injected = False


def concurrent_hit():
    global injected
    req = b.globals().CAW_DPS_METER.targetSyncRequest
    if req is not None and req.buffer is not None and not injected:
        a.execute("targetDamage('0xF1',25)"); b.execute("targetDamage('0xF1',25)")
        injected = True
    if req is not None:
        b.execute('''
        local d=CAW_DPS_METER; local t,received=d.targetDataForActor(d.actors['0xA'],'damage')
        assert(not received and not t['0xF2'])
        ''')


settle(b, hook=concurrent_hit)
d = b.globals().CAW_DPS_METER
check(injected and d.actors['0xA'].damage == 625, 'snapshot receipt leaves normal combat totals and concurrent local events untouched')
b.execute('''
local d=CAW_DPS_METER; local cache={}
local rows,total=d.targetBreakdownEntries(d.breakdownContext(), '0xA', nil, cache)
assert(total==675 and cache.covered==650 and cache.synced and #rows==2)
local spells,subtotal=d.targetBreakdownEntries(d.breakdownContext(),'0xA','0xF1',{})
assert(subtotal==350 and #spells==2)
assert(d.actors['0xA'].damageTargets['0xF1'].damage==125)
''')
check(True, 'complete owner snapshot fills targets and pet spells without adding overlapping observations or losing local counters')
packets = [(name, msg, ch) for name, msg, ch in bus.sent if msg.startswith('Y~')]
check(all(len(msg.encode()) <= 240 for _, msg, _ in packets), 'all snapshot packets fit the 240-byte limit')
check(sum(msg.startswith('Y~1~Q') for _, msg, _ in packets) == 1, 'one opened view sends one addressed request')
check(d.targetSyncDiagSession.counts.REQUEST_SENT == 1 and d.targetSyncDiagSession.counts.REPLY_RECEIVED == 1
      and a.globals().CAW_DPS_METER.targetSyncDiagSession.counts.REPLY_SENT == 1,
      'requester and responder retain separate diagnostic counts for a complete transfer')
check(any('Pet strike %7E test%25' in msg for _, msg, _ in packets), 'spell names round-trip escaped delimiters and percent signs')
before = len(packets)
for i in range(200):
    bus.tick(b.globals().NOW+.1)
    b.execute('CAW_DPS_METER.refreshBreakdown(true)')
check(len([x for x in bus.sent if x[1].startswith('Y~')]) == before, 'periodic painting never turns an open view into continuous sync')
bus.tick(b.globals().NOW+31)
open_targets(b); settle(b)
b.execute('''
local d=CAW_DPS_METER; local cache={}
local rows,total=d.targetBreakdownEntries(d.breakdownContext(),'0xA',nil,cache)
assert(total==675 and cache.covered==675 and cache.synced)
''')
check(True, 'a later request replaces the old snapshot instead of adding it again')
before = len(bus.sent)
open_targets(b); settle(b)
check(not any(msg.startswith('Y~1~Q') for _, msg, _ in bus.sent[before:]), 'a complete view does not request redundant data')

# The completed fight retains its remote damage details. Healing is requested
# only afterward, with both clients now out of combat, and also updates Overall.
end = max(vm.globals().NOW for vm in (a, b)) + 10
for vm in (a, b):
    vm.globals().NOW = end
    vm.execute("PLAYER_COMBAT=false; fire(CAW_DPS_METER.events,'PLAYER_REGEN_ENABLED')")
for i in range(80): bus.tick(end+i*.1)
check(len(d.fightHistory) == 1, 'fixture finalized its fight')
open_targets(b, 'healing', 'history'); settle(b)
b.execute('''
local d=CAW_DPS_METER; local h=d.fightHistory[1]; local c={segment='history',history=h,mode='overhealing'}
local rows,total=d.targetBreakdownEntries(c,'0xA',nil,{})
assert(total==240 and rows[1].gross==300 and d.overhealPercent(total,rows[1].gross)=='80.0%')
local cache={}; rows,total=d.targetBreakdownEntries({segment='overall',mode='damage'},'0xA',nil,cache)
assert(total==675 and cache.covered==675)
rows,total=d.targetBreakdownEntries({segment='overall',mode='overhealing'},'0xA',nil,{})
assert(total==240 and rows[1].gross==300)
assert(d.overallSegment.actors['0xA'].healing==60)
''')
check(True, 'history matches by fight identity and time; late healing details update Overall exactly once')
open_targets(b, 'overhealing', 'history'); settle(b)
check(d.overallSegment.actors['0xA'].healingTargets['0xB'].overhealing == 240, 'reopening history cannot duplicate Overall corrections')

# Overall requests the actual retained fights, never the peer's unrelated session total.
a, b = pair(raid=True); d = b.globals().CAW_DPS_METER
end = b.globals().NOW+10
for vm in (a, b):
    vm.globals().NOW = end; vm.execute("PLAYER_COMBAT=false; fire(CAW_DPS_METER.events,'PLAYER_REGEN_ENABLED')")
for i in range(80): bus.tick(end+i*.1)
open_targets(b, segment='overall'); settle(b)
b.execute('''
local d=CAW_DPS_METER; local cache={}
d.targetBreakdownEntries({segment='overall',mode='damage'},'0xA',nil,cache)
assert(cache.covered==650 and cache.fullTotal==650)
''')
check(all(ch == 'RAID' for _, msg, ch in bus.sent if msg.startswith('Y~')), 'on-demand snapshots work on RAID and fill Overall through matching individual fights')

# Wrong fight, old peers, controls, interrupted transfers, stale sources and limits.
for case in ('wrong_fight', 'old_peer', 'sync_off', 'parser_off', 'closed', 'dropped', 'malformed', 'incomplete',
             'roster_left', 'reset', 'oversized', 'sync_off_midway', 'parser_off_midway', 'wrong_recipient'):
    a, b = pair(); d = b.globals().CAW_DPS_METER
    if case == 'wrong_fight':
        a.execute('CAW_DPS_METER.setFightStartTime(GetTime()-100)')
    elif case == 'old_peer':
        b.execute("CAW_DPS_METER.threatSyncPeers['0xA'].targetDetails=false")
    elif case == 'sync_off': b.execute('CAW_DPS_METER.setCombatSyncEnabled(false)')
    elif case == 'parser_off': b.execute('CAW_DPS_METER.setParserEnabled(false)')
    elif case == 'oversized':
        a.execute("for i=1,300 do local t=CAW_DPS_METER.actors['0xA'].damageTargets['0xF1']; t.spells['Spell'..i]={damage=1,hits=1,crits=0} end")
    open_targets(b)
    if case == 'closed': b.execute('CAW_DPS_METER.breakdownPanel:Hide()')
    mutated = [False]

    def interrupt():
        req = d.targetSyncRequest
        if req is None or req.buffer is None or mutated[0]: return
        if case == 'dropped': a.execute('CAW_DPS_METER.targetSyncOut=nil')
        elif case == 'incomplete':
            a.execute("local o=CAW_DPS_METER.targetSyncOut; for i=o.index,#o.packets do if string.find(o.packets[i],'Y~1~S',1,true)==1 then table.remove(o.packets,i); break end end")
        elif case == 'malformed':
            nonce = req.nonce
            bus.b.globals().fire(d.events, 'CHAT_MSG_ADDON', d.syncPrefix,
                                f'Y~1~S~0xB~0xA~{nonce}~1~1~1~Broken~~-1~1~0', 'PARTY', 'Alpha')
        elif case == 'roster_left':
            b.execute("UNITS.party1=nil; PARTY_COUNT=0; fire(CAW_DPS_METER.events,'PARTY_MEMBERS_CHANGED')")
        elif case == 'reset': b.execute("CAW_DPS_METER.uiResetData('all')")
        elif case == 'sync_off_midway': b.execute('CAW_DPS_METER.setCombatSyncEnabled(false)')
        elif case == 'parser_off_midway': b.execute('CAW_DPS_METER.setParserEnabled(false)')
        elif case == 'wrong_recipient':
            a.execute("for i,packet in ipairs(CAW_DPS_METER.targetSyncOut.packets) do CAW_DPS_METER.targetSyncOut.packets[i]=string.gsub(packet,'~0xB~0xA~','~0xC~0xA~') end")
        else: return
        mutated[0] = True

    settle(b, hook=interrupt)
    if case == 'reset':
        check(b.eval('next(CAW_DPS_METER.actors)==nil'), 'reset rejects late packets from the previous fight')
    else:
        b.execute('''
        local d=CAW_DPS_METER; local a=d.actors['0xA']
        local targets,received=d.targetDataForActor(a,'damage')
        assert(not received and targets['0xF2']==nil and targets['0xF1'].damage==100)
        ''')
        check(True, case + ' keeps the previous local target data intact')
    if case in ('old_peer', 'sync_off', 'parser_off', 'closed'):
        check(not any(msg.startswith('Y~1~Q') for _, msg, _ in bus.sent), case + ' sends no target request')
    reason = {'wrong_fight':'REMOTE_UNAVAILABLE', 'old_peer':'UNSUPPORTED_PEER', 'sync_off':'SYNC_DISABLED',
              'parser_off':'PARSER_PAUSED', 'closed':'VIEW_CLOSED', 'dropped':'TIMEOUT', 'malformed':'INVALID_REPLY',
              'incomplete':'INCOMPLETE_REPLY', 'oversized':'REMOTE_UNAVAILABLE', 'sync_off_midway':'SYNC_DISABLED',
              'parser_off_midway':'PARSER_PAUSED', 'wrong_recipient':'TIMEOUT'}.get(case)
    if reason:
        check(d.targetSyncDiagSession.counts[reason] is not None,
              case + ' leaves its specific reason in persistent diagnostics')

# A late history response must not repopulate a manually reset Overall session.
a, b = pair(); d = b.globals().CAW_DPS_METER
end = b.globals().NOW+10
for vm in (a, b):
    vm.globals().NOW = end; vm.execute("PLAYER_COMBAT=false; fire(CAW_DPS_METER.events,'PLAYER_REGEN_ENABLED')")
for i in range(80): bus.tick(end+i*.1)
open_targets(b, segment='history')
reset_overall = [False]


def reset_session():
    req = d.targetSyncRequest
    if req is not None and req.buffer is not None and not reset_overall[0]:
        b.execute("CAW_DPS_METER.uiResetData('overall')")
        reset_overall[0] = True


settle(b, hook=reset_session)
check(reset_overall[0] and b.eval('next(CAW_DPS_METER.overallSegment.actors)==nil'),
      'a late history answer cannot put old contributions back into a reset Overall session')

# Source-side replies use one shared sender budget; packet counts and cooldowns
# stay bounded even when multiple users request details at the same time.
a, b = pair(); d = b.globals().CAW_DPS_METER
open_targets(b)
timeline = []
start = b.globals().NOW
for i in range(400):
    old = len(bus.sent); now = start+.02+i*.02; bus.tick(now)
    for name, msg, _ in bus.sent[old:]:
        if name == 'Alpha' and msg.startswith('Y~'):
            timeline.append(now)
    if d.targetSyncRequest is None and d.targetSyncPlan is None: break
check(len(timeline)>1 and all(right-left>=.099 for left, right in zip(timeline,timeline[1:])),
      'the responder sends at most one destination packet per 100 ms')
check(len(timeline)<=2+16+80+256, 'one response is bounded by actor target and spell record limits')

# Same-name/same-GUID enemies in separate pulls must remain separate contributions.
a, b = pair(); d = b.globals().CAW_DPS_METER
end = b.globals().NOW+10
for vm in (a, b):
    vm.globals().NOW = end; vm.execute("PLAYER_COMBAT=false; fire(CAW_DPS_METER.events,'PLAYER_REGEN_ENABLED')")
for i in range(80): bus.tick(end+i*.1)
start = end+100
for vm, amount in ((a, 400), (b, 50)):
    vm.globals().NOW = start
    vm.execute(f"PLAYER_COMBAT=true; fire(CAW_DPS_METER.events,'PLAYER_REGEN_DISABLED'); CAW_DPS_METER.syncRequested=true; targetDamage('0xF1',{amount})")
b.execute("SlashCmdList.CAWDPSSYNCDEBUG('retry')")
for i in range(150):
    bus.tick(start+.05+i*.05)
    if d.syncReceived == 1: break
assert d.actors['0xA'].damage == 400
end = b.globals().NOW+10
for vm in (a, b):
    vm.globals().NOW = end; vm.execute("PLAYER_COMBAT=false; fire(CAW_DPS_METER.events,'PLAYER_REGEN_ENABLED')")
for i in range(80): bus.tick(end+i*.1)
assert len(d.fightHistory) == 2
open_targets(b, segment='overall'); settle(b)
b.execute('''
local d=CAW_DPS_METER; local cache={}
local rows,total=d.targetBreakdownEntries({segment='overall',mode='damage'},'0xA',nil,cache)
assert(total==1050 and cache.covered==1050)
local first=d.fightHistory[1]; local second=d.fightHistory[2]
local r1=d.targetBreakdownEntries({segment='history',history=first,mode='damage'},'0xA',nil,{})
local r2=d.targetBreakdownEntries({segment='history',history=second,mode='damage'},'0xA',nil,{})
assert(#r1==1 and r1[1].value==400 and #r2==2)
''')
check(True, 'Overall retrieves multiple retained pulls separately even when an enemy GUID is reused')

# Serialization/reload, cancellation and bounds use the real SavedVariables table.
def lua_literal(value):
    if value is None: return 'nil'
    if isinstance(value, bool): return str(value).lower()
    if isinstance(value, (str, int, float)): return json.dumps(value)
    return '{' + ','.join('['+lua_literal(k)+']='+lua_literal(v) for k,v in value.items()) + '}'

count = len(bus.sent)
b.execute("fire(CAW_DPS_METER.diagBootstrapFrame,'PLAYER_LOGOUT')")
saved = lua_literal(b.globals().CawDPSMeterErrorLog)
restored = bus.client('Alpha','0xA','PRIEST','Bravo','0xB','PRIEST')
restored.execute('CawDPSMeterErrorLog='+saved)
restored.execute('''
local h=CawDPSMeterErrorLog.targetSync; local s=h.sessions[#h.sessions]
assert(s.endedAt and s.counts.REQUEST_SENT==2 and s.counts.REPLY_RECEIVED==2)
assert(CAW_DPS_METER.targetSyncDiagSession==nil)
local messages={}; DEFAULT_CHAT_FRAME.AddMessage=function(self,text) table.insert(messages,text) end
SlashCmdList.CAWSYNCSTATUS()
assert(string.find(messages[1],'last saved session',1,true))
''')
check(len(bus.sent)==count, 'diagnostics survive serialization and reload without creating extra traffic')
restored.execute('''
local d=CAW_DPS_METER
for session=1,5 do
    d.targetSyncDiagSession=nil
    for event=1,60 do d.targetSyncDiag('TIMEOUT') end
end
local h=CawDPSMeterErrorLog.targetSync
assert(#h.sessions==3 and #h.sessions[3].recent==24 and h.sessions[3].counts.TIMEOUT==60)
for _,s in ipairs(h.sessions) do
    for _,r in ipairs(s.recent) do assert(not r.actor and not r.name and not r.payload and not r.buffer) end
end
SlashCmdList.CAWDPSDEBUG('clear'); d.targetSyncDiag('REQUEST_SENT')
assert(d.targetSyncDiagSession==CawDPSMeterErrorLog.targetSync.sessions[1])
''')
check(True, 'diagnostic storage stays bounded and clearing it does not detach future recordings')
a,b=pair(); d=b.globals().CAW_DPS_METER
open_targets(b)
b.execute("fire(CAW_DPS_METER.diagBootstrapFrame,'PLAYER_LOGOUT')")
check(d.targetSyncDiagSession.last=='RELOAD_INTERRUPTED' and d.targetSyncDiagSession.endedAt is not None,
      'reloading during a queued request records an interruption rather than success')
print(f'Target sync checks: {checks}')

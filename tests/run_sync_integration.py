"""Two isolated WoW/Lua clients exchanging real addon messages through a mock bus."""
import os
from pathlib import Path
import re
import sys
sys.path.insert(0, str(Path(os.environ.get('TEMP', '/tmp')) / 'caw-review-lupa'))
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
ADDON=Path(os.environ.get('CAW_TEST_ADDON_ROOT',ROOT))
wire=[]
sent=[]
def client(name,guid,cls,other,otherguid,otherclass,saved=None):
    vm=LuaRuntime(unpack_returned_tuples=True)
    vm.execute((ROOT/'tests/mock_wow.lua').read_text(encoding='utf-8'))
    if saved:
        vm.execute('CawDPSMeterCharDB={'+saved+'}')
    vm.execute(f'''
    UNITS.player={{name="{name}",guid="{guid}",class="{cls}"}}
    UNITS.party1={{name="{other}",guid="{otherguid}",class="{otherclass}"}}
    PARTY_COUNT=1; TALENT_RANK=3
    GetNumTalentTabs=function() return 2 end
    GetTalentTabInfo=function(tab) return tab==1 and "Feral Combat" or "Restoration" end
    GetNumTalents=function() return 2 end
    GetTalentInfo=function(tab,i)
      if tab==1 and i==1 then return "Feral Instinct","icon",1,1,TALENT_RANK,3 end
      return "Other talent","icon",1,i,1,5
    end
    UnitBuff=function(unit,i) if i==1 and UNITS[unit] and UNITS[unit].class=="DRUID" then return "bear",1,5487 end end
    ''')
    for line in (ADDON/'CawDPSMeter.toc').read_text().splitlines():
        if not line.strip() or line.startswith('#'): continue
        code=(ADDON/line.strip()).read_text(encoding='utf-8')
        code=re.sub(r'\b(for\s+\w+(?:\s*,\s*\w+)*\s+in\s+)([\w.]+(?:\[[^\]\n]+\])?)\s+do\b',r'\1pairs(\2) do',code)
        vm.execute(code)
    vm.execute('fire(CAW_DPS_METER.events,"ADDON_LOADED","CawDPSMeter"); fire(CAW_DPS_METER.events,"PLAYER_ENTERING_WORLD"); CAW_DPS_METER.window:Hide()')
    def send(prefix,msg,channel,*args):
        assert len(msg.encode())<=255, 'addon packet exceeds client limit'
        wire.append((name,prefix,msg,channel)); sent.append((name,msg,channel))
    vm.globals().TEST_SEND=send
    vm.execute('SendAddonMessage=function(prefix,msg,channel,target) return TEST_SEND(prefix,msg,channel,target) end')
    return vm
a=client('Alpha','0xA','DRUID','Bravo','0xB','WARRIOR')
b=client('Bravo','0xB','WARRIOR','Alpha','0xA','DRUID')
clients={'Alpha':a,'Bravo':b}
def tick(t):
    for vm in clients.values():
        vm.globals().NOW=t
        vm.execute('this=CAW_DPS_METER.events; this.scripts.OnUpdate()')
    while wire:
        name,prefix,msg,ch=wire.pop(0)
        receiver=b if name=='Alpha' else a
        receiver.globals().fire(receiver.globals().CAW_DPS_METER.events,'CHAT_MSG_ADDON',prefix,msg,ch,name)
for i in range(20): tick(100+i*.25)
for vm,guid in ((a,'0xB'),(b,'0xA')):
    d=vm.globals().CAW_DPS_METER
    assert d.threatSyncPeers[guid] is not None
    profile=d.talentProfiles[guid]
    assert profile.available and profile.tabs[1][1].rank==3 and profile.tabs[2][2].maxRank==5
assert b.eval('CAW_DPS_METER.threatGlobalModifier({guid="0xA",name="Alpha",classToken="DRUID"})')==1.45
print('PASS both hidden clients discover each other and exchange complete talent layouts; Feral Instinct reaches the remote engine')
a.globals().TALENT_RANK=0
for i in range(12): tick(105+i*.25)
assert b.globals().CAW_DPS_METER.talentProfiles['0xA'].tabs[1][1].rank==0
assert b.eval('CAW_DPS_METER.threatGlobalModifier({guid="0xA",name="Alpha",classToken="DRUID"})')==1.3
print('PASS respec updates generic ranks and the supported threat modifier without a command')
for vm in clients.values(): vm.execute('GetNumRaidMembers=function() return 2 end; UNITS.raid1=UNITS.player; UNITS.raid2=UNITS.party1; PARTY_COUNT=0')
for i in range(8): tick(108+i*.25)
assert any(msg.startswith('K~') and ch=='RAID' for _,msg,ch in sent)
assert b.globals().CAW_DPS_METER.talentProfiles['0xA'].available
print('PASS switching from party to raid refreshes talent messages on the raid channel')
b.execute('''
CAW_DPS_METER.threatCalNewSession(); CAW_DPS_METER.threatCalEnabled=true
local d=CAW_DPS_METER
local id=d.threatCalActorContext('0xA',true)
assert(d.threatCalSession.actorContexts[id].talentLayoutAvailable)
local profileId=d.threatCalSession.actorContexts[id].talentProfileId
assert(d.threatCalSession.talentProfiles[profileId].tabs[1][1].rank==0)
''')
print('PASS received talent layout is linked to saved calibration actor context')
assert not any(msg.startswith('V~') for _,msg,_ in sent)
b.execute('CAW_DPS_METER.requestTalentTrees({guid="0xA",name="Alpha"})')
for i in range(35): tick(110+i*.1)
cache=b.globals().CAW_DPS_METER.talentViewCache
assert cache is not None and cache.guid=='0xA'
assert cache.tabs[1].name=='Feral Combat' and cache.tabs[1].nodes[1].name=='Feral Instinct'
assert cache.tabs[1].nodes[1].rank==0 and cache.tabs[2].nodes[2].column==2
assert all(len(msg.encode())<=240 for _,msg,_ in sent if msg.startswith('V~'))
assert len([msg for _,msg,_ in sent if msg.startswith('V~1~Q')])==1
print('PASS talent names, icons, positions and ranks arrive from the owning client only on request; packets fit 240 bytes')
# A forged/unsolicited tree must never replace the complete snapshot.
b.execute('fire(CAW_DPS_METER.events,"CHAT_MSG_ADDON","CAWDPS2","V~1~B~0xA~0xB~123~8","RAID","Alpha")')
assert b.globals().CAW_DPS_METER.talentViewCache.time==cache.time
print('PASS unsolicited talent tree packets do not replace an accepted snapshot')
b.execute('''
local d=CAW_DPS_METER
local actor={guid="0xA",name="Alpha",key="0xA",classToken="DRUID",damage=10,spells={Melee={damage=10}}}
d.fightHistory={{name="Old fight",duration=10,actors={['0xA']=actor}}}
d.openBreakdown(actor,{segment="history",segmentIndex=1,mode="damage"})
this=d.breakdownPanel.talentButton; this.scripts.OnClick()
assert(d.breakdownPanel.talentPane.trees[1].nodes[1].node.name=="Feral Instinct")
assert(d.breakdownPanel.talentPane.trees[1].nodes[1].node.rank==0)
''')
a.globals().TALENT_RANK=2
for i in range(12): tick(114+i*.1)
b.execute('''
local d=CAW_DPS_METER; d.refreshBreakdown()
assert(d.breakdownPanel.talentPane.trees[1].nodes[1].node.rank==2)
assert(string.find(d.breakdownPanel.talentPane.status:GetText(),"Not a snapshot",1,true))
''')
print('PASS remote tree renders another class and regular rank sync updates a respec without another metadata transfer')
# A correctly addressed but incomplete/corrupt response cannot publish half a tree.
b.execute('''
local d=CAW_DPS_METER
d.requestTalentTrees({guid="0xA",name="Alpha"},true)
local req=d.talentViewRequest; assert(req)
local prefix="V~1~"; local addr="~0xA~0xB~"..req.nonce
fire(d.events,"CHAT_MSG_ADDON","CAWDPS2",prefix.."B"..addr.."~1","RAID","Alpha")
fire(d.events,"CHAT_MSG_ADDON","CAWDPS2",prefix.."T"..addr.."~1~2~Test tree","RAID","Alpha")
fire(d.events,"CHAT_MSG_ADDON","CAWDPS2",prefix.."N"..addr.."~1~1~99~1~1~3~Bad node~icon","RAID","Alpha")
fire(d.events,"CHAT_MSG_ADDON","CAWDPS2",prefix.."E"..addr,"RAID","Alpha")
assert(d.talentViewRequest and d.talentViewCache.tabs[1].name=="Feral Combat")
''')
print('PASS malformed or incomplete requested trees retain the previous complete snapshot')
old=b.globals().CAW_DPS_METER.talentProfiles['0xA'].revision
b.execute('fire(CAW_DPS_METER.events,"CHAT_MSG_ADDON","CAWDPS2","K~1~0xA~999999~1~2~33","PARTY","Alpha")')
assert b.globals().CAW_DPS_METER.talentProfiles['0xA'].revision==old
b.execute('fire(CAW_DPS_METER.events,"CHAT_MSG_ADDON","CAWDPS2","K~1~0xA~999999~2~2~!5","PARTY","Alpha")')
assert b.globals().CAW_DPS_METER.talentProfiles['0xA'].revision==old
print('PASS partial or malformed profile does not replace the complete profile')
for vm in clients.values(): vm.execute('PARTY_COUNT=0; UNITS.party1=nil; GetNumRaidMembers=function() return 0 end; UNITS.raid1=nil; UNITS.raid2=nil')
tick(117)
assert a.globals().CAW_DPS_METER.talentProfiles['0xB'] is None
assert b.globals().CAW_DPS_METER.talentProfiles['0xA'] is None
before=len(sent)
for i in range(8): tick(118+i)
assert len(sent)==before
print('PASS leaving the group clears profiles and stops broadcasts; all packets fit 255 bytes')

# Exercise the complete combat request -> offer -> selection -> snapshot path.
# Injecting H/A/D/E/Z directly cannot catch a dispatch collision at selection.
def combat_sync(extra_windows=False, raid=False):
    global a,b,clients
    wire.clear(); sent.clear()
    a=client('Alpha','0xA','DRUID','Bravo','0xB','WARRIOR')
    b=client('Bravo','0xB','WARRIOR','Alpha','0xA','DRUID')
    clients={'Alpha':a,'Bravo':b}
    for vm,own,other,start in [(a,'0xA1','0xB1',190),(b,'0xB1','0xA1',195)]:
        vm.execute(f'''
        NOW=200; PLAYER_COMBAT=true
        UNITS.pet={{guid='{own}',name='Pet',class='WARRIOR'}}
        UNITS.partypet1={{guid='{other}',name='Other pet',class='WARRIOR'}}
        fire(CAW_DPS_METER.events,'UNIT_PET','player')
        local d=CAW_DPS_METER
        d.inCombat=true; d.startTime={start}; d.syncRequested=true
        d.threatCalEnabled=false
        ''')
        if raid:
            vm.execute('GetNumRaidMembers=function() return 2 end; UNITS.raid1=UNITS.player; UNITS.raid2=UNITS.party1; UNITS.raidpet1=UNITS.pet; UNITS.raidpet2=UNITS.partypet1; PARTY_COUNT=0')
    if extra_windows:
        b.execute('''
        local d=CAW_DPS_METER
        d.createMultiWindow({mode='healing'})
        d.createMultiWindow({mode='threat'})
        d.createMultiWindow({mode='damage',segment='overall'})
        ''')

    def raw(vm,event,text):
        vm.globals().fire(vm.globals().CAW_DPS_METER.events,'RAW_COMBATLOG','CHAT_MSG_'+event,text)

    raw(a,'SPELL_SELF_DAMAGE','Your Wrath hits 0xF1 for 900.')
    raw(a,'SPELL_SELF_BUFF','Your Heal heals 0xB for 300.')
    raw(a,'SPELL_PET_DAMAGE',"0xA1's Claw hits 0xF1 for 120.")
    raw(b,'SPELL_PARTY_DAMAGE',"0xA's Wrath hits 0xF1 for 100.")
    raw(b,'SPELL_PARTY_BUFF',"0xA's Heal heals 0xB for 50.")
    assert a.eval("CAW_DPS_METER.actors['0xA'].damage")==900
    assert b.eval("CAW_DPS_METER.actors['0xA'].damage")==100
    assert a.eval("CAW_DPS_METER.actors['0xA1'].ownerKey")=='0xA'
    b.execute('CAW_DPS_METER.syncRequested=false')
    injected=False; completed_at=None
    for i in range(120):
        t=200+i*.05
        tick(t)
        if b.globals().CAW_DPS_METER.syncIncoming is not None and not injected:
            assert b.eval("CAW_DPS_METER.actors['0xA'].damage")==100
            # Hits observed after the snapshot header must survive its merge.
            raw(a,'SPELL_SELF_DAMAGE','Your Wrath hits 0xF1 for 25.')
            raw(a,'SPELL_SELF_BUFF','Your Heal heals 0xB for 15.')
            raw(b,'SPELL_PARTY_DAMAGE',"0xA's Wrath hits 0xF1 for 25.")
            raw(b,'SPELL_PARTY_BUFF',"0xA's Heal heals 0xB for 15.")
            injected=True
        if b.globals().CAW_DPS_METER.syncReceived:
            completed_at=t
            break
        if injected:
            assert b.eval("CAW_DPS_METER.actors['0xA'].damage")==125, 'partial snapshot applied before its end marker'
    assert completed_at is not None, 'combat selection did not produce a complete snapshot'
    assert injected
    d=b.globals().CAW_DPS_METER
    assert d.syncReceived==1 and d.syncLastSource=='Alpha'
    assert d.actors['0xA'].damage==925 and d.actors['0xA'].healing==315
    assert d.actors['0xA'].spells.Wrath.damage==925
    assert d.actors['0xA'].healSpells.Heal.healing==315
    assert d.actors['0xA1'].damage==120 and d.actors['0xA1'].ownerKey=='0xA' and d.actors['0xA1'].isPet
    assert d.startTime<195
    assert d.threatSyncPeers['0xA'] is not None, 'combat selection swallowed a peer announcement'
    assert d.talentProfiles['0xA'].available, 'talent sync broke during combat transfer'
    trace=list(sent)
    assert len([msg for _,msg,_ in trace if msg.startswith('R~')])==1
    assert len([msg for _,msg,_ in trace if msg.startswith('P~') and not msg.startswith('P~1~')])==1
    for kind in ['H','A','D','E','Z']:
        assert any(msg.startswith(kind+'~') for _,msg,_ in trace), kind
    channel='RAID' if raid else 'PARTY'
    assert all(ch==channel for _,_,ch in trace)

    # A duplicate complete snapshot must not be applied twice.
    complete=[(who,msg,ch) for who,msg,ch in trace if who=='Alpha' and msg.startswith('Z~')]
    for who,msg,ch in complete:
        b.globals().fire(d.events,'CHAT_MSG_ADDON',d.syncPrefix,msg,ch,who)
    assert d.syncReceived==1 and d.actors['0xA'].damage==925
    # A second normal handshake must also leave already complete totals intact.
    b.execute("SlashCmdList.CAWDPSSYNCDEBUG('retry')")
    for i in range(120):
        tick(completed_at+.05+i*.05)
        if d.syncReceived==2: break
    assert d.syncReceived==2 and d.actors['0xA'].damage==925 and d.actors['0xA'].healing==315
    assert d.actors['0xA1'].damage==120

    # The dead client's automatic refresh must traverse the same handshake.
    raw(a,'SPELL_SELF_DAMAGE','Your Wrath hits 0xF1 for 75.')
    b.execute('CAW_DPS_METER.localPlayerDead=true; CAW_DPS_METER.deadSyncLastReceived=GetTime(); CAW_DPS_METER.deadSyncNextRequest=GetTime()')
    dead_at=b.globals().NOW
    requests_before=len([msg for _,msg,_ in sent if msg.startswith('R~')])
    for i in range(160):
        tick(dead_at+.05+i*.05)
        if d.syncReceived==3: break
    assert d.syncReceived==3 and d.actors['0xA'].damage==1000
    assert d.deadSyncLastReceived>dead_at
    assert len([msg for _,msg,_ in sent if msg.startswith('R~')])==requests_before+1

    # Combat-end reconciliation is automatic too, not just /cdsync retry.
    raw(a,'SPELL_SELF_DAMAGE','Your Wrath hits 0xF1 for 40.')
    b.execute("CAW_DPS_METER.localPlayerDead=false; PLAYER_COMBAT=false; fire(CAW_DPS_METER.events,'PLAYER_REGEN_ENABLED')")
    end_at=b.globals().NOW
    for i in range(120):
        tick(end_at+.05+i*.05)
        if d.syncReceived==4: break
    assert d.syncReceived==4 and d.actors['0xA'].damage==1040
    return trace

single=combat_sync()
print('PASS complete hidden-client combat handshake restores damage, healing and owned pet data while preserving newer local events')
print('PASS peer/talent sync coexists with combat selection; snapshots apply atomically and retries do not duplicate totals')
print('PASS a dead client automatically receives the surviving player\'s new damage with one refresh request')
print('PASS combat-end reconciliation requests and merges the final damage snapshot')
multiple=combat_sync(extra_windows=True)
assert single==multiple, 'additional meter windows changed the sync traffic'
print('PASS four meter windows produce the same sync messages as one hidden meter')
combat_sync(raid=True)
print('PASS complete combat handshake also works on RAID')

# Both switches must gate real traffic, including a half-received snapshot.
for setting in ('parserEnabled','combatSyncEnabled'):
    wire.clear(); sent.clear()
    a=client('Alpha','0xA','DRUID','Bravo','0xB','WARRIOR')
    b=client('Bravo','0xB','WARRIOR','Alpha','0xA','DRUID',setting+'=false')
    clients={'Alpha':a,'Bravo':b}
    for vm in clients.values():
        vm.execute('NOW=300; PLAYER_COMBAT=true; fire(CAW_DPS_METER.events,"PLAYER_REGEN_DISABLED")')
        vm.execute('fire(CAW_DPS_METER.events,"RAW_COMBATLOG","CHAT_MSG_COMBAT_SELF_HITS","You hit 0xF1 for 100.")')
    for i in range(30): tick(300+i*.1)
    def combat_packets():
        return [msg for sender,msg,_ in sent if sender=='Bravo'
                and (msg[0] in 'ROHADEZ' or (msg.startswith('P~') and not msg.startswith('P~1~')))]
    assert not combat_packets(), 'disabled client sent combat packets'
    d=b.globals().CAW_DPS_METER
    assert d.talentProfiles['0xA'].available, 'talent sharing stopped with combat recording'
    if setting=='parserEnabled':
        assert not d.inCombat and b.eval('next(CAW_DPS_METER.actors)==nil')
        assert not d.threatCalEnabled, 'saved parser pause restarted calibration at world entry'
        b.execute('CAW_DPS_METER.setParserEnabled(true)')
    else:
        assert d.actors['0xB'].damage==100, 'sync off stopped local damage'
        b.execute('CAW_DPS_METER.setCombatSyncEnabled(true)')
    print('PASS saved '+setting+'=false blocks combat traffic after load while retaining talent sharing')
    b.execute('fire(CAW_DPS_METER.events,"RAW_COMBATLOG","CHAT_MSG_COMBAT_SELF_HITS","You hit 0xF1 for 25.")')
    paused=False
    for i in range(60):
        tick(304+i*.05)
        if d.syncIncoming is not None and not paused:
            setter='setParserEnabled' if setting=='parserEnabled' else 'setCombatSyncEnabled'
            b.execute('CAW_DPS_METER.'+setter+'(false)')
            paused=True
    assert paused, 'fixture did not reach an incoming header'
    assert d.syncIncoming is None and d.syncReceived==0
    assert d.actors['0xA'] is None, 'disabled receiver accepted a partial or late snapshot'
    assert not d.syncNonce and len(d.syncQueue)==0
    print('PASS '+setting+' can stop an in-flight snapshot without applying partial or late data')

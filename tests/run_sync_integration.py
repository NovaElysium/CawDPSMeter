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
def client(name,guid,cls,other,otherguid,otherclass):
    vm=LuaRuntime(unpack_returned_tuples=True)
    vm.execute((ROOT/'tests/mock_wow.lua').read_text(encoding='utf-8'))
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

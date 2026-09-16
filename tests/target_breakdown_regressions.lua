local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS TARGETS '..label) end
local function click(button) this=button; arg1='LeftButton'; button:GetScript('OnClick')() end
local function find(rows,id)
    for _,r in ipairs(rows) do if r.id==id then return r end end
end
CawDPSMeterCharDB.parserEnabled=true; CawDPSMeterCharDB.combatSyncEnabled=false
UNITS.player={guid='0x1',name='Healer',class='PRIEST'}
UNITS.party1={guid='0xB',name='Friend',class='PRIEST'}; PARTY_COUNT=1; UNITS.pet=nil
UNITS.target={guid='0xF1',name='Enemy',hostile=true}
D.uiResetData('all'); D.threatCalEnabled=false; D.localPlayerDead=false; D.lastFinalizeAt=0
NOW=NOW+100; PLAYER_COMBAT=true; fire(D.events,'PLAYER_REGEN_DISABLED')
D.dpsLogActive=true; D.dpsLogProbing=false
local function damage(src,dst,name,amount,spell,periodic)
    if spell then
        return D.dpsLogReceive(periodic and 'SPELL_PERIODIC_DAMAGE' or 'SPELL_DAMAGE',src,nil,1,0,dst,name,64,0,
            585,spell,2,amount,-1,2,0,0,0,nil)
    end
    return D.dpsLogReceive('SWING_DAMAGE',src,nil,1,0,dst,name,64,0,amount,-1,1,0,0,0,nil)
end
local function heal(dst,name,amount,over,spell)
    return D.dpsLogReceive('SPELL_HEAL','0x1',nil,1,0,dst,name,1,0,2060,spell or 'Heal',2,amount,over,0,nil)
end
damage('0x1','0xF1','Same enemy',100)
damage('0x1','0xF1','Same enemy',50,'Smite',true)
damage('0x1','0xF2','Same enemy',200,'Smite')
D.dpsLogReceive('SPELL_SUMMON','0x1',nil,1,0,'0xCA','Pet',1,0,1,'Pet',1)
damage('0xCA','0xF1','Same enemy',30)
local a=D.actors['0x1']; local pet=D.actors['0xCA']
check(a.damage==350 and a.damageTargets['0xF1'].damage==150 and a.damageTargets['0xF2'].damage==200,
    'direct and periodic damage retain separate GUID destinations without changing totals')
local context=D.breakdownContext({mode='damage',segment='current'}); local cache={}
local rows,total=D.targetBreakdownEntries(context,a.key,nil,cache)
check(#rows==2 and total==380 and find(rows,'0xF1').value==180 and find(rows,'0xF2').value==200,
    'owned pet damage joins the owner for each target')
check(find(rows,'0xF1').name=='Same enemy (1)' and find(rows,'0xF2').name=='Same enemy (2)',
    'same-name enemies remain distinguishable and do not merge')
local version=cache.revision; local same=D.targetBreakdownEntries(context,a.key,nil,cache)
check(same==rows and cache.revision==version,'unchanged destination views reuse their cached rows')
local spells,selectedTotal=D.targetBreakdownEntries(context,a.key,'0xF1',{})
check(#spells==3 and selectedTotal==180 and find(spells,'0x1:Melee').value==100 and find(spells,'0xCA:Melee').value==30,
    'target drilldown keeps player and pet melee separate with a target-specific denominator')
local before=a.targetRevision
damage('0x1','0xF1','Same enemy',0)
damage('0xEE','0xF1','Same enemy',999)
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_COMBAT_SELF_HITS','You hit Same enemy for 50.')
check(a.targetRevision==before and a.damageTargets['0xF1'].damage==150,
    'rejected events outsiders and RAW duplicates cannot pollute target counters')
damage('0x1','0xF1','Same enemy',400,'Smite')
rows,total=D.targetBreakdownEntries(context,a.key,nil,cache)
check(rows[1].id=='0xF1' and rows[1].name=='Same enemy (1)' and cache.revision>version,
    'live values reorder bars without renumbering same-name targets')

heal('0xB','Friend',100,20); heal('0xB','Friend',100,100)
heal('0x1','Healer',40,0); heal('0xB','Friend',30,-1,'Unknown coverage')
check(a.healingTargets['0xB'].healing==110 and a.healingTargets['0xB'].overhealing==120
    and a.healingTargets['0xB'].overhealTotal==200,'recipient totals preserve full overheal and measured coverage')
context.mode='healing'
rows,total=D.targetBreakdownEntries(context,a.key,nil,{})
check(total==150 and find(rows,'0xB').value==110 and find(rows,'0xB').gross==200,
    'effective recipient shares include healing with unknown overheal without inventing a denominator')
context.mode='overhealing'
rows,total=D.targetBreakdownEntries(context,a.key,nil,{})
check(total==120 and D.overhealPercent(find(rows,'0xB').value,find(rows,'0xB').gross)=='60.0%',
    'recipient overheal percentages use only measured gross healing')
a.overhealing=a.overhealing+200; cache={}
rows,total=D.targetBreakdownEntries(context,a.key,nil,cache)
check(total==120 and cache.fullTotal==320 and cache.gross==240,
    'synced overheal cannot be divided by the smaller locally observed denominator')
a.overhealing=a.overhealing-200
local missing=a.healing
a.healing=a.healing+75
context.mode='healing'; cache={}; rows,total=D.targetBreakdownEntries(context,a.key,nil,cache)
check(total==225 and cache.covered==150 and find(rows,'0xB').value==110,
    'extra synced healing increases the full total without being assigned to a guessed recipient')
a.healing=missing
local legacy={key='old',guid='old',name='Old data',damage=100,classToken='PRIEST',spells={Smite={damage=100}}}
local history={actors={old=legacy},duration=5}
local oldRows,oldTotal=D.targetBreakdownEntries({segment='history',history=history,mode='damage'},'old',nil,{})
check(#oldRows==0 and oldTotal==100,'old fights expose missing target data without reconstructing it from spell totals')

-- Exercise real view buttons, search, drilldown, comparison return and talents.
D.mode='damage'; D.segment='current'; D.openBreakdown(a,nil); local p=D.breakdownPanel
local tabTop=-p.targetTab.lastPoint[5]; local tabBottom=tabTop+p.targetTab:GetHeight()
check(tabTop>=-p.searchBox.lastPoint[5]+p.searchBox:GetHeight()+3
    and tabBottom<=-p.nameHeader.lastPoint[5]-4
    and p.spellTab.lastPoint[4]+p.spellTab:GetWidth()<p.targetTab.lastPoint[4],
    'destination tabs fit between the toolbar and table headings without overlapping')
click(p.targetTab)
check(p.targetView and p.nameHeader.text:GetText()=='Target' and not p.spells[1].icon:IsShown(),
    'Targets tab renders destination bars without fake spell icons')
local targetButton
for _,b in ipairs(p.spells) do if b.row and b.row.targetKey=='0xF1' then targetButton=b end end
click(targetButton)
check(p.targetKey=='0xF1' and p.total==580 and p.spells[1].icon:IsShown() and p.nameHeader.text:GetText()=='Spell',
    'clicking a target shows its spells in the same window')
check(find(p.entries,'0x1:Smite').value==450 and p.targetCaption:GetText()=='Same enemy (1)',
    'drilldown uses only the selected target while preserving its identity')
click(p.compareButton); local cp=D.comparePanel; cp:Hide()
check(p:IsShown() and p.targetView and p.targetKey=='0xF1' and p.total==580,
    'returning from player comparison restores the target drilldown')
click(p.targetTab)
p.searchBox:SetText('same'); this=p.searchBox; p.searchBox:GetScript('OnTextChanged')()
check(#p.entries==2 and p.searchHint:GetText()=='Search targets...','target search filters destinations')
click(p.spells[1])
check(p.search=='' and #p.entries==3,'entering a target clears the target-name search before showing spells')
click(p.spellTab)
check(not p.targetView and p.total==780 and p.spells[1].icon:IsShown(),'Spells tab restores the full player and pet breakdown')
click(p.targetTab); click(p.talentButton)
check(p.talentPane:IsShown() and not p.targetTab:IsShown(),'talent view hides the destination tabs underneath its pane')
click(p.talentButton)
check(p.targetView and p.targetTab:IsShown(),'closing talents restores the destination view')
local function mode(name)
    for _,f in ipairs(FRAMES) do if f.parent==p.modeMenu and f.mode==name then click(f); return end end
    error('missing mode '..name)
end
mode('healing')
check(p.targetView and not p.targetKey and p.targetTab.text:GetText()=='Recipients'
    and p.nameHeader.text:GetText()=='Recipient','changing to healing shows recipients and resets the target filter')
click(p.spells[1])
check(p.targetKey=='0xB' and p.total==110 and p.metrics[8]:GetText()=='120',
    'recipient spell details include effective healing and overheal')
mode('interrupts')
check(not p.targetView and not p.targetTab:IsShown() and not p.targetKey,'unsupported modes return to their ordinary breakdown')
p:Hide()
D.dpsLogReceive('SPELL_HEAL','0xCA','Pet',1,0,'0xB','Friend',1,0,5394,'Healing Stream',8,50,10,0,nil)
context.mode='healing'
rows,total=D.targetBreakdownEntries(context,a.key,nil,{})
check(total==190 and find(rows,'0xB').value==150,'owned summon healing is grouped under the correct recipient')
spells,selectedTotal=D.targetBreakdownEntries(context,a.key,'0xB',{})
check(selectedTotal==150 and find(spells,'0xCA:Healing Stream').isPet
    and find(spells,'0xCA:Healing Stream').overhealing==10,'recipient drilldown preserves the summon source and its overheal')

-- Saved fights freeze target tables; overall adds values but retains spell IDs.
NOW=NOW+8; PLAYER_COMBAT=false; fire(D.events,'PLAYER_REGEN_ENABLED')
NOW=NOW+2; this=D.events; D.events:GetScript('OnUpdate')()
local finished=D.fightHistory[1]
check(finished.actors['0x1'].damageTargets['0xF1'].damage==550
    and finished.actors['0x1'].healingTargets['0xB'].overhealing==120,'history stores damage and recipient counters')
NOW=NOW+100; PLAYER_COMBAT=true; D.lastFinalizeAt=0; fire(D.events,'PLAYER_REGEN_DISABLED')
damage('0x1','0xF1','Same enemy',10,'Smite'); heal('0xB','Friend',50,10)
check(finished.actors['0x1'].damageTargets['0xF1'].damage==550,'new fights cannot mutate saved target counters')
NOW=NOW+8; PLAYER_COMBAT=false; fire(D.events,'PLAYER_REGEN_ENABLED')
NOW=NOW+2; this=D.events; D.events:GetScript('OnUpdate')()
local overall=D.overallSegment.actors['0x1']
check(overall.damageTargets['0xF1'].damage==560 and overall.damageTargets['0xF1'].spells.Smite.spellId==585
    and overall.healingTargets['0xB'].overhealing==130,'Overall sums counters across fights and preserves spell identity')
print('Target breakdown checks: '..checks)

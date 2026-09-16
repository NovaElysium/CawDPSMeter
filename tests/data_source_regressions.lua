-- Current input state is separate from availability in a selected saved fight.
local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS DATA SOURCE '..label) end
local function contains(text,part) return string.find(text or '',part,1,true)~=nil end
local function click(frame) this=frame; arg1='LeftButton'; frame:GetScript('OnClick')() end
local function page(id)
    for _,button in ipairs(D.optionsPanel.tabs) do if button.page==id then click(button); return end end
end
local function tick(box) NOW=NOW+2; this=box; box:GetScript('OnUpdate')() end
local oldApi,oldRaid=CombatLogGetCurrentEventInfo,GetNumRaidMembers
CawDPSMeterCharDB.parserEnabled=true; CawDPSMeterCharDB.combatSyncEnabled=true
D.dpsLogProbing=false; D.dpsLogActive=false; D.dpsLogInitialized=false; D.dpsLogRawCommitted=false
D.dpsLogFallback=nil; CombatLogGetCurrentEventInfo=nil; PARTY_COUNT=0
D.openOptions(nil); page('General')
local p=D.optionsPanel; local box=p.inputStatus
check(box:IsVisible() and not p.preview:IsShown() and not p.infoNote:IsShown()
    and box.source:GetText()=='Combat text' and box.sync:GetText()=='Waiting for group',
    'recording source and solo sync state appear in the existing settings sidebar')
check(contains(box.detail:GetText(),'Overheal') and contains(box.detail:GetText(),'Caw Sync'),
    'combat text explains where missing optional details can come from')
check(p:GetWidth()==790 and p:GetHeight()==485 and box:GetWidth()==184 and box:GetHeight()==283
    and p.controls.parserEnabled:IsVisible() and p.controls.combatSyncEnabled:IsVisible(),
    'status fits the existing sidebar without covering controls or resizing settings')
D.dpsLogProbing=true; tick(box)
check(box.source:GetText()=='Waiting for DPSLog','an unconfirmed API is not advertised as active DPSLog')
D.dpsLogProbing=false; D.dpsLogActive=true; PARTY_COUNT=1; tick(box)
check(box.source:GetText()=='DPSLog' and box.sync:GetText()=='On'
    and contains(box.detail:GetText(),'when supplied') and contains(box.syncDetail:GetText(),'incomplete'),
    'confirmed DPSLog and grouped sync update live without promising complete data')
PARTY_COUNT=0; GetNumRaidMembers=function() return 20 end; tick(box)
check(box.sync:GetText()=='On','raid membership also enables the grouped sync status')
GetNumRaidMembers=oldRaid
local repaint=0; local original=box.source.SetText
box.source.SetText=function(self,value) repaint=repaint+1; original(self,value) end
local count=#FRAMES; local actors=D.actors; local request=D.targetSyncRequest; local queued=D.targetSyncOut
for i=1,15 do tick(box) end
check(repaint==0 and #FRAMES==count and D.actors==actors and D.targetSyncRequest==request and D.targetSyncOut==queued,
    'unchanged status neither repaints labels nor creates frames or requests')
box.source.SetText=original
CawDPSMeterCharDB.combatSyncEnabled=false; tick(box)
check(box.source:GetText()=='DPSLog' and box.sync:GetText()=='Off','sync off does not mislabel the local recording source')
CawDPSMeterCharDB.parserEnabled=false; tick(box)
check(box.source:GetText()=='Paused' and box.sync:GetText()=='Paused'
    and contains(box.detail:GetText(),'Saved fights'),'recording pause takes precedence over the cached producer and sync preference')
CawDPSMeterCharDB.parserEnabled=true; D.dpsLogActive=false
CombatLogGetCurrentEventInfo=function() error('status must not call native APIs') end
D.dpsLogRawCommitted=true; tick(box)
check(box.source:GetText()=='Combat text' and contains(box.detail:GetText(),'/reload'),
    'a late API explains the reload requirement without invoking the API')
D.dpsLogRawCommitted=false; D.dpsLogFallback='no structured event during RAW probe'; tick(box)
check(box.source:GetText()=='Combat text' and contains(box.detail:GetText(),'/cawinput'),
    'failed input detection retains combat text and offers the existing diagnostic command')
page('Window'); check(not box:IsShown() and p.preview:IsShown(),'appearance pages keep their preview')
p.search:SetText('DPSLog'); this=p.search; p.search:GetScript('OnTextChanged')()
check(box:IsVisible() and p.controls.parserEnabled:IsVisible(),'searching DPSLog finds recording controls and source status')
page('General'); p:Hide(); D.dpsLogActive=true; D.openOptions(nil)
check(box.source:GetText()=='DPSLog','reopening settings updates a source change that happened while hidden')
p:Hide(); D.dpsLogActive=false
local label=box.source:GetText(); tick(box)
check(box.source:GetText()==label,'a hidden settings panel does not refresh its source labels')

-- Data availability comes from records, never from the current input switch.
local a={key='0x1',guid='0x1',name='Healer',classToken='PRIEST',damage=100,healing=100,
    spells={Smite={damage=100,hits=1,crits=0}},healSpells={Heal={healing=100,hits=1,crits=0}}}
D.fightHistory={{actors={['0x1']=a},duration=10,name='Saved fight'}}
D.segment='history'; D.segmentIndex=1; D.mode='healing'; D.dpsLogActive=true
D.openBreakdown(a,nil); local detail=D.breakdownPanel
check(detail.metricLabels[8]:GetText()=='Overheal' and detail.metrics[8]:GetText()=='Not available',
    'enabling DPSLog now does not invent overheal for an older heal')
click(detail.targetTab)
check(contains(detail.foot:GetText(),'No target details available') and not contains(detail.foot:GetText(),'Recorded: 0 / 0'),
    'absent target records are described as unavailable')
detail.context.mode='overhealing'; D.refreshBreakdown()
check(detail.totalText:GetText()=='No overheal data' and not contains(detail.foot:GetText(),'Recorded: 0 / 0'),
    'unknown overheal destinations are not presented as measured zero coverage')
click(detail.spellTab)
check(contains(detail.foot:GetText(),'unavailable') and contains(detail.foot:GetText(),'Caw Sync'),
    'unknown spell overheal explains the data requirement')
a.overhealing=0; a.overhealTotal=100; a.overhealHits=1; a.overhealCrits=0
local heal=a.healSpells.Heal; heal.overhealing=0; heal.overhealTotal=100; heal.overhealHits=1; heal.overhealCrits=0
D.recordTargetAmount(a,'healing','0x2','Recipient','Heal',100,false,2060,0)
D.dpsLogActive=false; CawDPSMeterCharDB.parserEnabled=false
detail.context.mode='healing'; D.refreshBreakdown()
check(detail.metrics[8]:GetText()=='0' and detail.metrics[9]:GetText()=='0.0%',
    'measured zero overheal remains visible with recording paused and DPSLog inactive')
detail.context.mode='overhealing'; click(detail.targetTab)
check(detail.entryCache.hasData and detail.totalText:GetText()=='Total: 0 | 0.0%'
    and contains(detail.foot:GetText(),'Recorded: 0 / 0'),
    'actual zero-overheal target observations are distinguished from missing records')
detail.context.mode='damage'; D.recordTargetAmount(a,'damage','0xF1','Enemy','Smite',40,false,585)
D.refreshBreakdown()
check(contains(detail.foot:GetText(),'Recorded: 40 / 100 (partial)') and detail.total==100,
    'partial target coverage is labeled without reducing the full combat total')
a.targetHasSynced={D=true}; D.refreshBreakdown()
check(contains(detail.foot:GetText(),'Includes Caw Sync details.'),
    'retained shared target data is identified even when combat sync is now paused')
detail:Hide(); CombatLogGetCurrentEventInfo=oldApi; GetNumRaidMembers=oldRaid
print('Data source checks: '..checks)

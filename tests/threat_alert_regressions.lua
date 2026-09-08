local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS ALERT '..label) end
local original={units=UNITS,party=PARTY_COUNT,raid=GetNumRaidMembers,combat=UnitAffectingCombat,dead=UnitIsDead,
    ghost=UnitIsDeadOrGhost,sound=PlaySoundFile,actors=D.actors,roster=D.guidToActor,settings=CawDPSMeterCharDB.threatAlerts}
local sounds={}
PlaySoundFile=function(path) table.insert(sounds,path) end
UNITS={player={guid='0xA1',name='AlertPlayer',class='HUNTER'},pet={guid='0xA2',name='Wolf'},target={guid='0xF9',name='Elite',hostile=true}}
PARTY_COUNT=1; GetNumRaidMembers=function() return 0 end
local fighting,dead=true,false
UnitAffectingCombat=function() return fighting end
UnitIsDead=function() return dead end; UnitIsDeadOrGhost=function() return dead end
D.actors={}; D.guidToActor={}; D.threatAlertLastAt=nil; D.threatAlertEpisode=nil
D.savedVariablesReady=true; CawDPSMeterCharDB.threatAlerts=nil
local function publish(pct,tank,amount)
    local state=D.threatCalObserveTarget()
    D.serverThreatPublish({{name='AlertPlayer',threat=amount or 100,percent=pct,tank=tank or false,melee=false},
        {name='Wolf',threat=200,percent=100,tank=not tank,melee=true}},
        {serial=1,sentAt=NOW,targetGuid=state.guid,targetGeneration=state.generation,segmentSerial=state.segmentSerial},state)
end
local function tick(pct,tank,amount)
    NOW=NOW+0.2
    if pct then publish(pct,tank,amount) end
    D.threatAlertNext=nil; D.threatAlertTick()
end
local c=D.threatAlertSettings()
check(not c.glow and not c.sound and c.threshold==90 and c.cooldown==8,'new characters start with optional effects disabled')
tick(99)
check(#sounds==0 and not D.threatAlertFrame,'disabled alerts allocate no glow and play no sound')
c.glow=true; c.sound=true
tick(89); check(#sounds==0,'below-threshold threat stays quiet')
tick(90)
check(#sounds==1 and D.threatAlertFrame:IsShown(),'fresh own server threat at the threshold starts both effects')
local frame=D.threatAlertFrame; local frameCount=#FRAMES
check(frame.mouseEnabled==false and frame:GetFrameStrata()=='FULLSCREEN_DIALOG','screen border cannot intercept mouse input')
check(sounds[1]=='Interface\\AddOns\\CawDPSMeter\\Media\\CawWarning.wav','sound uses the bundled Caw warning asset')
NOW=NOW+1; this=frame; frame:GetScript('OnUpdate')()
check(frame:GetAlpha()>0 and frame:GetAlpha()<1,'glow fades after the warning')
NOW=NOW+2; this=frame; frame:GetScript('OnUpdate')()
check(not frame:IsShown(),'glow ends after two seconds')
NOW=NOW+10; tick(98); tick(89)
check(#sounds==1,'unchanged high threat and small threshold fluctuations do not repeat warnings')
tick(84); tick(95)
check(#sounds==2 and #FRAMES==frameCount,'dropping below hysteresis rearms a warning and reuses the border')
tick(84); tick(95)
check(#sounds==2,'cooldown blocks a rapid second threshold crossing')
NOW=NOW+10; tick(95,true)
check(#sounds==3,'gaining aggro after the cooldown raises a new warning')
NOW=NOW+10; tick(100,true)
check(#sounds==3,'continuing to tank does not repeat the warning')
NOW=NOW+2; tick()
check(not frame:IsShown() and #sounds==3,'expired server data cannot trigger an alert')
tick(100,true)
check(#sounds==3,'a fresh reply after a gap does not restart the same warning')
tick(0,false,0); NOW=NOW+10; tick(92)
check(#sounds==4,'zero threat clears the old episode so a later rise can warn')
local old=D.serverThreatSnapshot
UNITS.target.guid='0xFA'; NOW=NOW+0.2; D.threatAlertNext=nil; D.threatAlertTick()
check(not frame:IsShown() and #sounds==4,'changing target rejects the previous target snapshot')
NOW=NOW+10; tick(92)
check(#sounds==5,'a fresh snapshot for a different target can warn')
tick(84); NOW=NOW+10; publish(99)
D.serverThreatSnapshot.actors[1].isPet=true
D.threatAlertNext=nil; D.threatAlertTick()
check(#sounds==5,'a pet row cannot stand in for the player')
local snapshot={actors={{name='AlertPlayer',_serverThreatValue=1},{name='AlertPlayer',isPet=true,_serverThreatValue=1}}}
check(not D.threatAlertOwnRow(snapshot),'duplicate names are not used as an ambiguous player identity')
snapshot.actors[1].guid='0xA1'
check(D.threatAlertOwnRow(snapshot)==snapshot.actors[1],'an exact player GUID resolves a duplicate name')
snapshot.actors[1].guid='0xOTHER'; snapshot.actors[2]=nil
check(not D.threatAlertOwnRow(snapshot),'a conflicting GUID is never accepted just by name')
for _,reason in ipairs({'combat','death','group','target-death'}) do
    fighting=reason~='combat'; dead=reason=='death'; PARTY_COUNT=reason=='group' and 0 or 1
    if reason=='target-death' then UnitIsDead=function(unit) return unit=='target' end end
    tick(99)
    check(#sounds==5 and not frame:IsShown(),'no alerts with invalid '..reason..' state')
    UnitIsDead=function() return dead end
end
fighting=true; dead=false; PARTY_COUNT=1
NOW=NOW+10; c.glow=false; tick(99)
check(#sounds==6 and not frame:IsShown(),'sound works with the screen effect disabled')
tick(0,false,0); NOW=NOW+10; c.glow=true; c.sound=false; tick(99)
check(#sounds==6 and frame:IsShown(),'screen effect works with sound disabled')
tick(0,false,0); NOW=NOW+10; D.window:Hide(); D.mode='healing'; D.segment='overall'; publish(99)
D.threatAlertNext=nil; this=D.events; D.events:GetScript('OnUpdate')()
check(frame:IsShown() and D.threatAlertEpisode.level==1,'always-on tick warns while all meter data views are unrelated or hidden')
c.glow=false; tick(99)
check(not frame:IsShown(),'disabling the last effect stops an active warning')
-- Configure through the real menu; settings belong to the character, not a view.
local function click(b) this=b; arg1='LeftButton'; b:GetScript('OnClick')() end
D.openOptions(D.multiWindows[2]); local p=D.optionsPanel
for _,b in ipairs(p.tabs) do if b.page=='Threat' then click(b) end end
check(p.page=='Threat' and not p.preview:IsShown() and not p.target:IsShown() and not p.copyButton:IsShown(),
    'Threat settings clearly separate character-wide alerts from per-window appearance')
local b=p.controls.glow.check; b:SetChecked(true); click(b)
check(D.threatAlertSettings().glow and p.threatTest:IsEnabled(),'screen checkbox enables the shared setting and preview')
local input=p.controls.threshold.input; input:SetText('101'); this=input; input:GetScript('OnEnterPressed')()
check(c.threshold==100,'threshold input clamps to the server percentage range')
input=p.controls.cooldown.input; input:SetText('0'); this=input; input:GetScript('OnEnterPressed')()
check(c.cooldown==2,'cooldown input keeps a minimum warning interval')
input:SetText('bad'); this=input; input:GetScript('OnEnterPressed')()
check(c.cooldown==2 and input:GetText()=='2','invalid numeric input restores the saved setting')
local before=#sounds; click(p.threatTest)
check(frame:IsShown() and #sounds==before,'Test warning previews only the enabled effects')
D.openOptions(nil); check(D.threatAlertSettings()==c,'opening settings from another window keeps the same alert preferences')
for _,f in ipairs(FRAMES) do if f.parent==p and f.kind=='Button' and f.text and type(f.text)=='table' and f.text:GetText()=='Defaults' then click(f); break end end
check(not D.threatAlertSettings().glow and not D.threatAlertSettings().sound and not frame:IsShown(),'Threat defaults reset only alert settings and stop the preview')
p:Hide(); D.window:Show()
UNITS=original.units; PARTY_COUNT=original.party; GetNumRaidMembers=original.raid; UnitAffectingCombat=original.combat
UnitIsDead=original.dead; UnitIsDeadOrGhost=original.ghost; PlaySoundFile=original.sound
D.actors=original.actors; D.guidToActor=original.roster; CawDPSMeterCharDB.threatAlerts=original.settings
D.serverThreatSnapshot=nil; D.threatAlertEpisode=nil; D.threatAlertPreviewUntil=nil; D.threatAlertStop()
print('Threat alert checks: '..checks)

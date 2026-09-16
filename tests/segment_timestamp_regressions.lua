local D=CAW_DPS_METER
local checks=0
local function check(v,label) assert(v,label); checks=checks+1; print("PASS TIMESTAMP "..label) end
local oldTime,oldDate=time,date
local zone=7200; local base=1700000000
time=function() return base+math.floor(NOW) end
date=function(format,stamp)
    if format~="%H:%M:%S" then return "test-session" end
    local seconds=math.mod(stamp+zone,86400)
    return string.format("%02d:%02d:%02d",math.floor(seconds/3600),math.floor(math.mod(seconds,3600)/60),math.mod(seconds,60))
end
local function click(f) local previous=this; this=f; f.scripts.OnClick(); this=previous end
local function finish()
    NOW=NOW+12; PLAYER_COMBAT=false; fire(D.events,"PLAYER_REGEN_ENABLED")
    NOW=NOW+2; local previous=this; this=D.events; D.events.scripts.OnUpdate(); this=previous
end
PARTY_COUNT=0; UNITS.party1=nil; UNITS.target={guid="0xF1",name="Animated Oil",hostile=true}
CawDPSMeterCharDB.parserEnabled=true; CawDPSMeterCharDB.combatSyncEnabled=false
D.threatCalEnabled=false; D.dpsLogActive=true; D.dpsLogProbing=false; D.localPlayerDead=false
fire(D.events,"PARTY_MEMBERS_CHANGED"); D.uiResetData("all")
NOW=50000; PLAYER_COMBAT=true; D.lastFinalizeAt=0
local info=D.guidToActor[UNITS.player.guid]
D.dpsLogReceive("SWING_DAMAGE",info.guid,info.name,1,0,"0xF1","Animated Oil",64,0,100,-1,1,0,0,0,nil)
local started=D.fightStartedAt; local startClock=D.startTime
check(started==time(),"first DPSLog hit records the pull wall clock")
NOW=NOW+1; fire(D.events,"PLAYER_REGEN_DISABLED")
check(D.fightStartedAt==started and D.startTime==startClock,"later combat flag does not overwrite the initial pull time")
finish()
local first=D.fightHistory[1]
check(first and first.startedAt==started and first.duration==13,"history saves pull time rather than the delayed combat-end time")
check(D.historyLabel(first,1)==date("%H:%M:%S",started).." - Animated Oil","history label starts with local hours minutes and seconds")
local originalLabel=D.historyLabel(first,1)
NOW=NOW+100; PLAYER_COMBAT=true; fire(D.events,"PLAYER_REGEN_DISABLED")
local secondStart=D.fightStartedAt
check(secondStart>started,"a new pull gets its own timestamp")
D.dpsLogReceive("SWING_DAMAGE",info.guid,info.name,1,0,"0xF1","Animated Oil",64,0,50,-1,1,0,0,0,nil)
finish()
check(#D.fightHistory==2 and D.historyLabel(first,2)==originalLabel
    and D.historyLabel(D.fightHistory[1],1)~=originalLabel,"same-name fights stay distinct and labels stay stable as history moves")
D.mode="damage"; D.uiSelectMain("history",2)
check(D.reportSegmentName()==originalLabel,"main reports identify the selected timestamp")
local v=D.multiWindows[2] or D.createMultiWindow(nil)
v.segment="history"; v.segmentIndex=2; v.mode="damage"; v.frame:Show(); D.updateMultiWindow(v)
check(D.multiReportSegmentName(v)==originalLabel and D.multiViewSegmentLabel(v)==originalLabel,
    "extra windows and reports use the same pull time")
local lines=D.buildReportLines(nil)
check(lines and string.find(lines[1],originalLabel,1,true),"report header carries the original pull time")
D.window:SetWidth(210); D.uiRefresh(nil)
click(D.mainView.segmentButton)
local found
for _,b in ipairs(D.mainView.segmentMenu.buttons) do
    if b:IsShown() and b.kind=="history" and b.historyIndex==2 then found=b end
end
check(found and found.cawMenuLabel==originalLabel and found.text:GetStringWidth()<=found.text:GetWidth(),
    "compact dropdown fits the label and preserves the full timestamp/name tooltip")
click(found)
check(D.segmentIndex==2,"timestamp labels preserve the selected encounter identity")
v.rebuildSegments()
check(v.segmentMenu.buttons[3].cawMenuLabel==originalLabel,"extra-window dropdown labels match primary history")
local a=first.actors[info.key]; D.openBreakdown(a,nil)
local p=D.breakdownPanel
check(string.find(p.contextText:GetText(),originalLabel,1,true) and p.segmentsData[4].label==originalLabel,
    "detail heading and sidebar identify the same timed encounter")
check(p.segments[4].text:GetStringWidth()<=p.segments[4].text:GetWidth(),"detail sidebar clips long labels inside the button")
p:Hide()
-- Reconcile the original wall-clock anchor, even if a computer clock was adjusted.
D.uiResetData("current"); PLAYER_COMBAT=true; NOW=NOW+100; fire(D.events,"PLAYER_REGEN_DISABLED")
local before=D.fightStartedAt; local clock=D.startTime
base=base+3600; NOW=NOW+4; D.setFightStartTime(clock-25)
check(D.fightStartedAt==before-25 and D.startTime==clock-25,"earlier synced start adjusts the original clock anchor instead of using receipt time")
check(D.historyLabel({name="Legacy"},3)=="3. Legacy","records without a known timestamp keep an honest fallback")
local midnight={name="Night mob",startedAt=86400-zone+2}
check(D.historyLabel(midnight)=="00:00:02 - Night mob","clock formatting wraps cleanly across local midnight")
time=oldTime; date=oldDate
print("Segment timestamp checks: "..checks)

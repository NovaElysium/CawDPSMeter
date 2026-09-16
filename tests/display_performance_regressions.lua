local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print("PASS DISPLAY "..label) end
local function actor(key,name,amount,pet,owner)
    return {key=key,guid=key,name=name,classToken=not pet and "HUNTER" or nil,isPet=pet,ownerKey=owner,
        damage=amount,healing=0,spells={Shot={damage=amount,hits=1,crits=0}},healSpells={}}
end
local a=actor("0xA1","Archer",100)
local b=actor("0xA2","Other",140)
local pet=actor("0xA3","Wolf",60,true,a.key)
local actors={[a.key]=a,[b.key]=b,[pet.key]=pet}
local sort=table.sort; local sorts=0
table.sort=function(t,fn) sorts=sorts+1; return sort(t,fn) end
local rows,n,cache=D.meterSortedRows(actors,"damage")
check(n==2 and rows[1].actor==a and rows[1].value==160,"cached damage includes owned pets")
local firstRow=rows[1]; local version=cache.revision; sorts=0
for i=1,20 do D.meterSortedRows(actors,"damage") end
check(sorts==0 and cache.revision==version and rows[1]==firstRow,"unchanged views reuse rows without sorting")
local savedActors=D.actors; D.actors=actors
local same,_,sameCache=D.multiViewSortedActors({mode="damage",segment="current"})
check(same==rows and sameCache==cache,"identical meter views share the same sorted cache")
a.healing=700
local heals=D.meterSortedRows(actors,"healing")
check(heals[1].value==700 and rows[1].value==160,"healing and damage caches cannot overwrite each other")
pet.ownerKey=b.key
D.meterSortedRows(actors,"damage")
check(rows[1].actor==b and rows[1].value==200 and rows[2].value==100,"pet ownership corrections update both owners")
a.damage=250; D.meterSortedRows(actors,"damage")
check(rows[1].actor==a and rows[1].value==250,"late amount corrections immediately reorder cached rows")
version=cache.revision; a.classToken="MAGE"; a.name="Renamed"
D.meterSortedRows(actors,"damage")
check(cache.revision>version,"late name and class data invalidate painted rows")
actors[b.key]=nil; actors[pet.key]=nil; a.damage=0
local empty,emptyCount=D.meterSortedRows(actors,"damage")
check(emptyCount==0 and #empty==0,"removed and zero-valued actors leave no stale bars")
a.damage=100; pet.ownerKey=a.key; actors[pet.key]=pet
D.meterSortedRows(actors,"damage")
table.sort=sort

CawDPSMeterCharDB.parserEnabled=true
D.segment="current"; D.segmentIndex=0; D.mode="damage"
D.inCombat=true; NOW=NOW+100; D.startTime=NOW-10; D.lastDuration=0
D.pendingCombatEndAt=0; D.pendingCombatEndStopTime=0
D.appearance=D.uiCopySettings(nil)
D.window:Show(); D.uiRefreshMeters()
local v=D.multiWindows[2] or D.createMultiWindow(nil)
v.frame:Show(); v.mode="damage"; v.segment="current"; v.scrollOffset=0
D.updateMultiWindow(v)
local paints=0; local setValue=D.rows[1].bar.SetValue
D.rows[1].bar.SetValue=function(self,value) paints=paints+1; return setValue(self,value) end
local extraPaints=0; local extraSet=v.rows[1].bar.SetValue
v.rows[1].bar.SetValue=function(self,value) extraPaints=extraPaints+1; return extraSet(self,value) end
local function tick(f)
    local previous=this; this=f; f.nextUpdate=0; f.scripts.OnUpdate(); this=previous
end
tick(D.window); tick(v.frame)
check(paints==0 and extraPaints==0,"timer skips unchanged main and extra window rows")
local before=D.rows[1].right:GetText(); NOW=NOW+1
tick(D.window); tick(v.frame)
check(paints==1 and extraPaints==1 and D.rows[1].right:GetText()~=before,"live DPS continues changing without a new hit")
D.inCombat=false; D.lastDuration=11; tick(D.window); tick(v.frame)
paints=0; extraPaints=0; NOW=NOW+3; tick(D.window); tick(v.frame)
check(paints==0 and extraPaints==0,"finished Current stops repainting unchanged bars")
a.damage=125; tick(D.window); tick(v.frame)
check(paints==1 and extraPaints==1,"late data repaints every affected window")
paints=0; extraPaints=0; D.uiRefreshMeters()
check(paints==1 and extraPaints==1,"explicit settings refresh always repaints")
paints=0; D.window:SetWidth(D.window:GetWidth()+10); tick(D.window)
check(paints==1,"resizing invalidates row layout even with unchanged data")
v.mode="healing"; D.updateMultiWindow(v,true)
check(v.rows[1].bar:GetValue()==700,"mode switch cannot reuse damage row values")
D.rows[1].bar.SetValue=setValue; v.rows[1].bar.SetValue=extraSet
local tc={revision=1}
check(not D.meterRowsUnchanged(v.frame,tc,11,0,"threat",true)
    and not D.meterRowsUnchanged(v.frame,tc,11,0,"threat",true),"threat percentages are never frozen by the row paint guard")

local historic={actors=actors,duration=11,name="Old enemy"}
D.fightHistory={historic}; D.segment="history"; D.segmentIndex=1
D.openBreakdown(a,nil)
local p=D.breakdownPanel; local context=p.context
local detailPaints=0; local detailSet=p.spells[1].bar.SetValue
p.spells[1].bar.SetValue=function(self,value) detailPaints=detailPaints+1; return detailSet(self,value) end
sorts=0; table.sort=function(t,fn) sorts=sorts+1; return sort(t,fn) end
NOW=NOW+5; D.refreshBreakdown(true)
check(detailPaints==0 and sorts==0,"unchanged history details reuse spell and sidebar lists without repainting")
local cached=p.entryCache; local cachedRows=cached.rows; local entry=cachedRows[1]
a.spells.Shot.hits=2; D.refreshBreakdown(true)
check(detailPaints>0 and cachedRows==cached.rows and cachedRows[1]==entry
    and p.metrics[3]:GetText()=="2","hit-only updates refresh metrics while reusing spell records")
detailPaints=0; a.damage=500; D.refreshBreakdown(true)
check(detailPaints>0 and p.total==560,"synced total-only corrections update contributions")
detailPaints=0; a.classToken="ROGUE"; D.refreshBreakdown(true)
check(detailPaints>0,"class metadata changes refresh detail colours")
detailPaints=0; historic.name="Corrected enemy"; D.refreshBreakdown(true)
check(detailPaints>0 and p.segmentsData[3].label=="1. Corrected enemy","renamed history entries refresh the segment sidebar")
detailPaints=0; actors[b.key]=b; D.refreshBreakdown(true)
check(detailPaints>0 and #p.playersData==2,"new players refresh the sidebar even if selected spells did not change")
p.sort="name"; D.refreshBreakdown(); p.sort="value"; D.refreshBreakdown()
check(p.entries[1].value>=p.entries[2].value,"name sorting never mutates the shared value order")
p.search="wolf"; D.refreshBreakdown()
check(#p.entries==1 and p.entries[1].source=="Wolf","search filters cached pet entries correctly")
p.search=""; D.refreshBreakdown()
check(#p.entries==2,"clearing search restores the full cached list")
pet.spells={}; a.spells={}; D.refreshBreakdown(true)
check(#p.entries==0 and not p.spells[1]:IsShown(),"removed spells leave no stale detail bars")
table.sort=sort; p.spells[1].bar.SetValue=detailSet
p:Hide()
check(p.entryCache==nil and p.playerCache==nil and p.entriesSource==nil,"closing details releases its cached encounter references")

local auraEntry={count=1,total=0,active={target=NOW},targets={target=true}}
a.buffs={Renew=auraEntry}; D.inCombat=true; D.startTime=NOW-10
D.segment="current"; D.mode="buffs"; D.openBreakdown(a,nil)
local uptime=p.entries[1].value; NOW=NOW+2; D.refreshBreakdown(true)
check(p.entries[1].value>uptime,"active aura durations continue growing through the cache")
p:Hide()

local session={}; D.threatCalEnabled=true; D.threatCalSession=session
D.dpsLogActive=true; D.dpsLogProbing=false; D.dpsLogSaveStatus(session)
local status=session.dpsLogStatus; local modules=status.modules
local received=D.dpsLogEvents
NOW=NOW+2
D.dpsLogReceive("SPELL_CAST_SUCCESS","0xEEEE","Outsider",1,0,"0xF1","Mob",64,0,133,"Fireball",4)
check(status==session.dpsLogStatus and status.received==received+1
    and status.modules==modules,"events update exact counters without reallocating the diagnostic snapshot")
D.dpsLogLastError="sample error"; D.dpsLogSaveStatus(session)
check(status==session.dpsLogStatus and status.error=="sample error" and status.modules~=modules,
    "full status refresh retains the table and refreshes metadata")
D.dpsLogLastError=nil; D.dpsLogSaveStatus(session)
check(status.error==nil,"recovered errors do not linger in the reused status table")
D.threatCalEnabled=false; D.actors=savedActors
print("Display performance checks: "..checks)

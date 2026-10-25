local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print("PASS THREAT ORDER "..label) end
-- The server reports each player's percentage of the pull threshold (110% melee,
-- 130% ranged). A ranged player can hold more raw threat than the tank and still
-- show less than 100%, so the table must follow the percentage like TWThreat.
local savedMode,savedSegment,savedActors=D.mode,D.segment,D.actors
local savedSettings=D.savedVariablesReady
D.savedVariablesReady=true
D.mode="threat"; D.segment="current"; D.segmentIndex=0
D.window:Show()
local v=D.multiWindows[2] or D.createMultiWindow(nil)
v.frame:Show(); v.mode="threat"; v.segment="current"; v.scrollOffset=0
local function publish(rows)
    NOW=NOW+0.2
    local state=D.threatCalObserveTarget()
    D.serverThreatPublish(rows,{serial=1,sentAt=NOW,targetGuid=state.guid,targetGeneration=state.generation,segmentSerial=state.segmentSerial},state)
    D.uiRefreshMeters()
end
local function names(rows) local out={}; local i=1; while rows[i] and rows[i].actor do table.insert(out,rows[i].actor.name); i=i+1 end; return out end
local function painted(rowset)
    local out={}; local i=1
    while rowset[i] do if rowset[i].actor then table.insert(out,rowset[i].actor.name) end; i=i+1 end
    return out
end

publish({
    {name='Hunter',threat=1170,percent=90,tank=false,melee=false},
    {name='Tank',threat=1000,percent=100,tank=true,melee=true},
    {name='Rogue',threat=500,percent=45.5,tank=false,melee=true}})
local sorted=D.meterSortedRows(D.serverThreatActors(),"threat")
local order=names(sorted)
check(order[1]=='Tank' and order[2]=='Hunter' and order[3]=='Rogue',"server threat is ordered by percentage, not raw threat")
local main=painted(D.rows)
check(main[1]=='Tank' and main[2]=='Hunter' and main[3]=='Rogue',"main window paints the tank first despite lower raw threat")
D.updateMultiWindow(v)
local extra=painted(v.rows)
check(extra[1]=='Tank' and extra[2]=='Hunter' and extra[3]=='Rogue',"extra window uses the same percentage order")
check(D.rows[1].bar:GetValue()==100 and D.rows[1].bar.maximum==100 and D.rows[2].bar:GetValue()==90 and D.rows[2].bar.maximum==100,"bars show the server percentage on a 100% scale")
check(D.rows[2].right:GetText()~=nil and string.find(D.rows[2].right:GetText(),"90",1,true)~=nil,"displayed percentage matches the row position")

-- Percentages above 100 (aggro pulled) never overflow the bar and keep sorting first.
publish({
    {name='Tank',threat=1000,percent=100,tank=true,melee=true},
    {name='Rogue',threat=1200,percent=109,tank=false,melee=true}})
order=names(D.meterSortedRows(D.serverThreatActors(),"threat"))
check(order[1]=='Rogue' and order[2]=='Tank',"a player past the pull threshold sorts above the tank")
check(D.rows[1].bar:GetValue()==100 and D.rows[1].bar.maximum==100,"bars never exceed full width")

-- Equal percentages fall back to raw threat, then to a stable name key.
publish({
    {name='Alpha',threat=300,percent=50,tank=false,melee=true},
    {name='Bravo',threat=400,percent=50,tank=false,melee=true},
    {name='Tank',threat=1000,percent=100,tank=true,melee=true}})
order=names(D.meterSortedRows(D.serverThreatActors(),"threat"))
check(order[1]=='Tank' and order[2]=='Bravo' and order[3]=='Alpha',"equal percentages order by raw threat")

-- Local (non-server) threat estimates keep ordering by value and scale to the top row.
D.actors={}; D.segment="overall"
local local1={key='0xL1',guid='0xL1',name='LocalHigh',classToken='WARRIOR',damage=0,healing=0,fake=900}
local local2={key='0xL2',guid='0xL2',name='LocalLow',classToken='ROGUE',damage=0,healing=0,fake=300}
local oldValue=D.threatValueForActor
D.threatValueForActor=function(a) return a.fake or 0 end
local rows=D.meterSortedRows({['0xL1']=local1,['0xL2']=local2},"threat")
D.threatValueForActor=oldValue
local localOrder=names(rows)
check(localOrder[1]=='LocalHigh' and localOrder[2]=='LocalLow' and rows[1].sortKey==nil,"local threat estimates keep ordering by value")
local barV,barM=D.uiBarFill("threat",local1,900,900)
check(barV==900 and barM==900,"local threat bars still scale to the top value")
local sv,sm=D.uiBarFill("damage",{_serverThreatValue=5,_serverThreatPercent=50},700,1000)
check(sv==700 and sm==1000,"non-threat modes ignore server percentages")

D.mode=savedMode; D.segment=savedSegment; D.actors=savedActors; D.savedVariablesReady=savedSettings
D.serverThreatSnapshot=nil
D.uiRefreshMeters()
print("Threat order checks: "..checks)

local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS THREAT RETRY '..label) end
local oldSend,oldMessage,oldClass,oldCombat,oldLoaded=SendAddonMessage,DEFAULT_CHAT_FRAME.AddMessage,
    UnitClassification,UnitAffectingCombat,IsAddOnLoaded
local requests,chat={},{}
local targetCombat=true
UnitClassification=function() return UNITS.target and UNITS.target.classification or 'normal' end
UnitAffectingCombat=function(unit) return unit~='target' or targetCombat end
IsAddOnLoaded=function() return false end
DEFAULT_CHAT_FRAME.AddMessage=function(_,msg) table.insert(chat,msg) end
SendAddonMessage=function(prefix,payload,channel)
    if prefix=='TWT_UDTSv4' then table.insert(requests,{time=NOW,guid=UNITS.target.guid}) end
    return oldSend(prefix,payload,channel)
end
local function target(guid,classification)
    if guid then UNITS.target={guid=guid,name='Enemy',hostile=true,classification=classification or 'normal'}
    else UNITS.target=nil end
    fire(D.threatCalFrame,'PLAYER_TARGET_CHANGED')
end
local function tick(t)
    NOW=t; this=D.threatCalFrame; this.scripts.OnUpdate()
    assert(#D.threatCalPendingRequests<=1,'parallel requests after changing target')
end
local function advance(seconds)
    local start=NOW
    for i=1,math.ceil(seconds*60) do tick(start+i/60) end
end
local function reply(value)
    fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT ','TWTv4=Hunter:1:'..value..':100:1','PARTY','Hunter')
end
local function fresh()
    NOW=NOW+100; PARTY_COUNT=1; PLAYER_COMBAT=true; targetCombat=true
    UNITS.target={guid='0xF1',name='Normal mob',hostile=true,classification='normal'}
    D.threatCalEnabled=false; D.threatCalStart(); requests={}
end
fresh()
for i=1,5 do
    tick(math.max(NOW,D.threatCalNextRequest)+0.01)
    assert(#D.threatCalPendingRequests==1)
    tick(NOW+1.51)
end
local normalRetry=D.threatCalApiRetryAt
check(D.threatCalTimeoutStreak==5 and normalRetry-NOW==30,'normal mob reaches the 30-second failure delay')
advance(2)
local switchAt=NOW; local before=#requests
target('0xE1','elite'); advance(0.5)
check(#requests==before+1 and requests[#requests].guid=='0xE1' and requests[#requests].time-switchAt<=0.5,
    'elite target is queried within half a second instead of inheriting the normal mob delay')
check(D.threatCalTargetRetries['0xF1'].untilTime==normalRetry and D.threatCalTimeoutStreak==0,
    'new target has independent failure state while the old delay is retained')
reply(123)
check(D.serverThreatCurrent() and D.serverThreatCurrent().guid=='0xE1'
    and D.serverThreatCurrent().actors[1]._serverThreatValue==123,'fresh elite response resumes live threat display')
before=#requests
target('0xF1'); advance(0.6)
check(#requests==before and D.threatCalTimeoutStreak==5 and D.threatCalApiRetryAt==normalRetry,
    'tabbing back to the failed mob cannot reset its delay')
target(nil); advance(0.3); target('0xF1'); advance(0.3)
check(#requests==before and D.threatCalApiRetryAt==normalRetry,'clearing and reacquiring the target preserves its delay')
D.segmentSerial=(D.segmentSerial or 0)+1; D.threatCalObserveTarget(); advance(0.3)
check(#requests==before and D.threatCalApiRetryAt==normalRetry,'a segment change does not bypass the same-target backoff')
switchAt=NOW; target('0xB1','worldboss'); advance(0.5)
check(#requests==before+1 and requests[#requests].time-switchAt<=0.5,'a new boss gets the same prompt initial query')
reply(250); before=#requests; advance(0.6)
check(#requests==before+1,'successful new-target reply resumes the normal polling interval')

fresh(); tick(NOW)
local firstSent=NOW
NOW=NOW+0.1; target('0xE2','elite'); advance(0.5)
check(#requests==1 and D.threatCalPendingRequests[1].targetGuid=='0xF1',
    'target switch preserves the outstanding old request until it can be resolved')
advance(2)
check(#requests==2 and requests[2].guid=='0xE2' and requests[2].time-firstSent<=2.6,
    'unanswered old request expires and the new elite is queried after the short quarantine')
check(D.threatCalTargetRetries['0xF1'].streak==1 and D.threatCalTimeoutStreak==0,
    'timeout of the old request is charged only to its original target')
reply(300)
check(D.serverThreatCurrent() and D.serverThreatCurrent().guid=='0xE2','new elite recovers after the old request times out')

fresh(); tick(NOW); firstSent=NOW
NOW=NOW+0.1; target('0xE3','elite'); advance(0.25); reply(999)
check(not D.serverThreatCurrent(),'old-target reply is not displayed on the new elite')
advance(1.2)
check(#requests==1,'old-target response keeps a short guard before the new request')
reply(998)
check(not D.serverThreatCurrent(),'duplicate old-target reply cannot restore the old snapshot')
advance(1)
check(#requests==2 and requests[2].time>=firstSent+2 and requests[2].time<=firstSent+2.6,
    'new request waits for the previous response window without a long backoff')
reply(400)
check(D.serverThreatCurrent() and D.serverThreatCurrent().actors[1]._serverThreatValue==400,
    'fresh response after guarded handover displays the new target value')

fresh(); tick(NOW); firstSent=NOW
NOW=NOW+0.1; target('0xE6','elite')
-- Simulate a reply arriving between OnUpdate ticks, just after the request's
-- response deadline. It must not consume the timeout/quarantine bookkeeping.
NOW=firstSent+1.3; reply(997)
check(#D.threatCalPendingRequests==1 and not D.serverThreatCurrent(),
    'expired reply leaves the original request pending for timeout handling')
tick(NOW)
check(D.threatCalTargetRetries['0xF1'].streak==1 and #requests==1,
    'expired reply still records the old-target timeout before retrying')
advance(0.5)
check(#requests==1,'expired reply cannot bypass the shared quarantine')
advance(0.6)
check(#requests==2 and requests[2].guid=='0xE6','new target recovers promptly after an expired reply')

fresh()
local start=NOW
for i=0,5*60 do
    NOW=start+i/60; target('0xFAST'..i,'elite'); tick(NOW)
end
check(#requests<=3,'rapid target cycling without replies cannot flood the server')
-- Exercise cache eviction with many different failing targets, not unbounded
-- GUID retention over a long grinding session.
for i=1,40 do
    NOW=NOW+4; target('0xFAIL'..i); advance(3)
end
local entries=0; for _ in pairs(D.threatCalTargetRetries) do entries=entries+1 end
check(entries<=16 and entries>0,'failed-target memory stays bounded during long sessions')

fresh(); targetCombat=false; target('0xE4','elite'); advance(1)
check(#requests==0,'out-of-combat targets are not queried by an early wake-up')
targetCombat=true; switchAt=NOW; advance(0.6)
check(#requests==1 and requests[1].time-switchAt<=0.6,'pulling the selected elite starts querying promptly')
reply(450); before=#requests
IsAddOnLoaded=function(name) return name=='TWThreat' end
target('0xE5','elite'); advance(3)
check(#requests==before,'target wake-up never adds requests when TWThreat owns polling')
IsAddOnLoaded=function() return false end

fresh()
local failures=0
SendAddonMessage=function() failures=failures+1; error('test transport unavailable') end
start=NOW
for i=0,10*60 do
    NOW=start+i/60; target('0xERROR'..i,'elite'); tick(NOW)
end
check(failures<=6,'changing targets cannot bypass the shared transport-error rate limit')
check(#chat==0,'target changes, failures and recovery stay silent in chat')
SendAddonMessage=oldSend; DEFAULT_CHAT_FRAME.AddMessage=oldMessage
UnitClassification=oldClass; UnitAffectingCombat=oldCombat; IsAddOnLoaded=oldLoaded
print('Threat retry checks: '..checks)

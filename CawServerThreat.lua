-- Server reference is a display-only snapshot, never written into local actors.
local D=CAW_DPS_METER
function D.serverThreatPublish(rows,req,state)
    if not req or not req.serial or not state or not state.guid then return end
    if GetTime()-req.sentAt>1.25 or GetTime()<req.sentAt or req.targetGuid~=state.guid or req.targetGeneration~=state.generation or req.segmentSerial~=state.segmentSerial then return end
    local actors={}; local i,r
    for i,r in rows do
        local token,unit,unitIsPet=D.threatCalClassForName(r.name)
        local localActor,count,ambiguous=D.threatCalActorByName(r.name,state.guid)
        local guid=not ambiguous and localActor and localActor.guid or nil
        local ownerClass=nil
        if unitIsPet and unit then
            local ownerUnit=unit=="pet" and "player" or string.gsub(unit,"pet","")
            local _,class=UnitClass(ownerUnit); ownerClass=class
        end
        actors[i]={key="server:"..i,name=r.name,classToken=token,guid=guid,
            isPet=unitIsPet or (localActor and localActor.isPet) or false,
            ownerKey=localActor and localActor.ownerKey,petOwnerClass=ownerClass,
            _serverThreatValue=r.threat,_serverThreatPercent=r.percent,
            _serverLocalValue=localActor and localActor.threat and localActor.threat[state.guid],
            _serverTarget=state.name,_serverTank=r.tank,_serverMelee=r.melee}
    end
    D.serverThreatSnapshot={actors=actors,time=GetTime(),guid=state.guid,generation=state.generation,segmentSerial=state.segmentSerial}
end

function D.serverThreatCurrent()
    local s=D.serverThreatSnapshot
    if not s or GetTime()-s.time>1.25 then return nil end
    local state=D.threatCalObserveTarget()
    if not state or state.guid~=s.guid or state.generation~=s.generation or state.segmentSerial~=s.segmentSerial then return nil end
    if UnitIsDead and UnitIsDead("target") then return nil end
    if UnitCanAttack and not UnitCanAttack("player","target") then return nil end
    return s
end

function D.serverThreatActors()
    local s=D.serverThreatCurrent()
    -- Never silently present incomplete local estimates as the live server meter.
    return s and s.actors or {}
end

function D.serverThreatLabel()
    local snapshot=D.serverThreatCurrent()
    if snapshot then return "Threat | "..D.serverThreatTargetName() end
    local guid=D.threatCalTarget()
    if not guid then return "No target" end
    if (D.threatCalTimeoutStreak or 0)>0 then return "No server response" end
    return "Waiting for threat data"
end

function D.serverThreatTargetName()
    local guid,name=D.threatCalTarget()
    return guid and name or "No target"
end

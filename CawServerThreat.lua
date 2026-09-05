-- Server reference is a display-only snapshot, never written into local actors.
local D=CAW_DPS_METER
function D.serverThreatPublish(rows,req,state,uncertain)
    if uncertain or not req or not req.serial or not state or not state.guid then return end
    if req.targetGuid~=state.guid or req.targetGeneration~=state.generation or req.segmentSerial~=state.segmentSerial or req.sentAt-state.since<2 then return end
    local actors={}; local i,r
    for i,r in rows do
        local token,unit=D.threatCalClassForName(r.name)
        local localActor,count,ambiguous=D.threatCalActorByName(r.name,state.guid)
        local guid=not ambiguous and localActor and localActor.guid or nil
        actors[i]={key="server:"..i,name=r.name,classToken=token,guid=guid,
            isPet=localActor and localActor.isPet or false,
            _serverThreatValue=r.threat,_serverThreatPercent=r.percent,
            _serverLocalValue=localActor and localActor.threat and localActor.threat[state.guid],
            _serverTarget=state.name}
    end
    D.serverThreatSnapshot={actors=actors,time=GetTime(),guid=state.guid,generation=state.generation,segmentSerial=state.segmentSerial}
end

function D.serverThreatCurrent()
    if not D.threatCalEnabled or D.threatCalAttributionUncertain then return nil end
    local s=D.serverThreatSnapshot
    if not s or GetTime()-s.time>1.25 then return nil end
    local state=D.threatCalObserveTarget()
    if not state or state.guid~=s.guid or state.generation~=s.generation or state.segmentSerial~=s.segmentSerial then return nil end
    if UnitIsDead and UnitIsDead("target") then return nil end
    return s
end

function D.serverThreatActors()
    local s=D.serverThreatCurrent()
    return s and s.actors or D.actors
end

function D.serverThreatLabel()
    return D.serverThreatCurrent() and "Server reference*" or "Local estimate"
end

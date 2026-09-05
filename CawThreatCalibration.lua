-- Caw Threat Calibration Logger RC37
-- Collects compact server-vs-model comparison data on RavenCraft/Turtle Threat API v4.
-- This module records the displayed threat model without replacing its calculations.
CAW_DPS_METER = CAW_DPS_METER or {}
local D = CAW_DPS_METER

D.threatCalibrationVersion = "RC37-10"
D.threatCalEnabled = false
D.threatCalNextRequest = 0
D.threatCalRequests = 0
D.threatCalResponses = 0
D.threatCalDuplicateResponses = 0
D.threatCalLastPayload = nil
D.threatCalLastPayloadAt = 0
D.threatCalSession = nil
D.threatCalMaxEvents = 12000
D.threatCalMaxSnapshots = 6000
D.threatCalMaxCasts = 6000
D.threatCalPendingRequests = {}
D.threatCalRequestSerial = 0
D.threatCalUnmatchedResponses = 0
D.threatCalTimedOutRequests = 0
D.threatCalLastTimeoutAt = 0

function D.threatCalNow()
    return GetTime and GetTime() or 0
end

function D.threatCalStamp()
    if date then return date("%Y-%m-%d %H:%M:%S") end
    return ""
end

function D.threatCalTarget()
    if not UnitExists or not UnitExists("target") then return nil,nil,nil end
    if UnitIsPlayer and UnitIsPlayer("target") then return nil,nil,nil end
    local guid=nil
    local ok,exists,g=pcall(UnitExists,"target")
    if ok and exists then guid=g end
    local name=(UnitName and UnitName("target")) or "?"
    local cls=(UnitClassification and UnitClassification("target")) or "unknown"
    return guid,name,cls
end

function D.threatCalApiEligible()
    if not D.threatCalEnabled then return false,"logger off" end
    local channel=nil
    if GetNumRaidMembers and GetNumRaidMembers()>0 then channel="RAID"
    elseif GetNumPartyMembers and GetNumPartyMembers()>0 then channel="PARTY" end
    if not channel then return false,"not in party/raid" end
    if not UnitExists or not UnitExists("target") then return false,"no target" end
    if UnitIsDead and UnitIsDead("target") then return false,"target dead" end
    if UnitIsPlayer and UnitIsPlayer("target") then return false,"target is player" end
    if UnitCanAttack and not UnitCanAttack("player","target") then return false,"target not hostile" end
    if UnitAffectingCombat and not UnitAffectingCombat("target") then return false,"target not in combat" end
    return true,channel
end

function D.threatCalActorByName(name,targetGuid)
    if not name or not D.actors then return nil,0,false end
    local seen={}; local count=0; local match=nil; local key,a
    for key,a in D.actors do
        if a and a.name==name then
            local identity=a.guid or a.key or key
            if not seen[identity] then seen[identity]=true; count=count+1; match=a end
        end
    end
    -- An unobserved same-name roster pet is also an ambiguous identity.
    for key,a in D.guidToActor do
        if a and a.name==name then
            local identity=a.guid or a.key or key
            if not seen[identity] then seen[identity]=true; count=count+1 end
        end
    end
    if count==1 then return match,1,false end
    return nil,count,count>1
end

function D.threatCalClassForName(name)
    if not name then return nil end
    local units={"player","pet"}
    local i
    if GetNumPartyMembers then
        for i=1,GetNumPartyMembers() do
            table.insert(units,"party"..i)
            table.insert(units,"partypet"..i)
        end
    end
    if GetNumRaidMembers then
        for i=1,GetNumRaidMembers() do
            table.insert(units,"raid"..i)
            table.insert(units,"raidpet"..i)
        end
    end
    local _,u
    for _,u in units do
        if UnitName and UnitName(u)==name then
            local _,classToken=UnitClass(u)
            return classToken,u
        end
    end
    return nil,nil
end

function D.threatCalEnsureDB()
    CawThreatCalibrationDB=CawThreatCalibrationDB or {}
    CawThreatCalibrationDB.schema=1
    CawThreatCalibrationDB.loggerVersion=D.threatCalibrationVersion
    CawThreatCalibrationDB.sessions=CawThreatCalibrationDB.sessions or {}
    return CawThreatCalibrationDB
end

function D.threatCalNewSession()
    local db=D.threatCalEnsureDB()
    local s={
        id=D.threatCalStamp().."-"..tostring(math.floor(D.threatCalNow()*1000)),
        startedAt=D.threatCalStamp(),
        startedGameTime=D.threatCalNow(),
        addonVersion=D.version,
        modelVersion=D.threatModelVersion,
        loggerVersion=D.threatCalibrationVersion,
        player=(UnitName and UnitName("player")) or "?",
        events={},casts={},snapshots={},transport={},feignRaw={},targets={},requestContexts={},actorContexts={},
        droppedEvents=0,droppedCasts=0,droppedSnapshots=0,
        requests=0,responses=0,duplicateResponses=0
    }
    table.insert(db.sessions,s)
    -- Keep a practical rolling history. Older sessions can be supplied separately if needed.
    while table.getn(db.sessions)>12 do table.remove(db.sessions,1) end
    D.threatCalSession=s
    D.threatCalActorContextCache={}
    return s
end

function D.threatCalUnitForGUID(guid)
    if not guid or not UnitExists then return nil end
    local units={"player","pet"}; local i,u
    local n=GetNumRaidMembers and GetNumRaidMembers() or 0
    if n>0 then
        for i=1,n do table.insert(units,"raid"..i); table.insert(units,"raidpet"..i) end
    else
        n=GetNumPartyMembers and GetNumPartyMembers() or 0
        for i=1,n do table.insert(units,"party"..i); table.insert(units,"partypet"..i) end
    end
    for i,u in units do
        local ok,exists,g=pcall(UnitExists,u)
        if ok and exists and g==guid then return u end
    end
end

function D.threatCalReadNumber(fn,unit)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,unit)
    if ok and type(v)=="number" then return v end
end

function D.threatCalActorContext(guid,force)
    if not D.threatCalEnabled or not D.threatCalSession or not guid then return nil end
    local now=D.threatCalNow()
    D.threatCalActorContextCache=D.threatCalActorContextCache or {}
    local previous=D.threatCalActorContextCache[guid]
    if not force and previous and now-previous.time<1 then return previous.id end
    local s=D.threatCalSession; s.actorContexts=s.actorContexts or {}
    if table.getn(s.actorContexts)>=2000 then
        s.actorContextOmitted=(s.actorContextOmitted or 0)+1
        return nil -- never link fresh data to a stale context after the cap
    end
    local unit=D.threatCalUnitForGUID(guid)
    local info=D.guidToActor and D.guidToActor[guid]
    local rec={guid=guid,unit=unit,t=now-(s.startedGameTime or 0),segmentSerial=D.segmentSerial or 0,available=unit and true or false,remoteTalents="unknown",buffs={}}
    rec.ownerGuid=info and info.ownerKey or nil
    local profile=info and D.talentProfileFor and D.talentProfileFor(info)
    rec.talentLayoutAvailable=profile and profile.available and true or false
    if profile and profile.available then
        if D.threatCalTalentProfileSession~=s then D.threatCalTalentProfileSession=s; D.threatCalTalentProfileCache={} end
        local key=guid..":"..profile.signature
        local id=D.threatCalTalentProfileCache[key]
        s.talentProfiles=s.talentProfiles or {}
        if not id and table.getn(s.talentProfiles)<200 then
            id=table.getn(s.talentProfiles)+1
            s.talentProfiles[id]={guid=guid,class=info.classToken,tabs=profile.tabs,t=rec.t}
            D.threatCalTalentProfileCache[key]=id
        end
        rec.talentProfileId=id
    end
    if info and D.threatPeerStatus then
        rec.cawPeerState,rec.cawThreatDataState,rec.cawPeerVersion=D.threatPeerStatus(info)
    end
    local owner=rec.ownerGuid and D.threatCalUnitForGUID(rec.ownerGuid)
    if owner then rec.ownerLevel=D.threatCalReadNumber(UnitLevel,owner) end
    if unit then
        rec.level=D.threatCalReadNumber(UnitLevel,unit)
        rec.powerType=D.threatCalReadNumber(UnitPowerType,unit)
        rec.modelModifier=info and D.threatGlobalModifier and D.threatGlobalModifier(info) or nil
        if info and info.classToken=="DRUID" and D.threatDruidModifiers then
            rec.formModifier,rec.talentModifier,rec.modifierKnowledge=D.threatDruidModifiers(info)
            if rec.modifierKnowledge=="caw-sync" then rec.remoteTalents="caw-sync" end
        end
        if UnitAttackPower then
            local ok,base,pos,neg=pcall(UnitAttackPower,unit)
            if ok then rec.attackPowerBase=tonumber(base); rec.attackPowerPositive=tonumber(pos); rec.attackPowerNegative=tonumber(neg) end
        end
        if unit=="player" then rec.localForm=D.threatCalReadNumber(GetShapeshiftForm) end
        if unit=="pet" then rec.happiness=D.threatCalReadNumber(GetPetHappiness) end
        if UnitBuff then
            rec.buffScanComplete=true
            local i
            for i=1,32 do
                local ok,texture,count,spellId=pcall(UnitBuff,unit,i)
                if not ok then rec.buffScanComplete=false; break end
                if not texture then break end
                local name=nil
                if not spellId and D.getUnitBuffName then
                    local good,value=pcall(D.getUnitBuffName,unit,i,spellId)
                    if good then name=value end
                end
                table.insert(rec.buffs,{spellId=tonumber(spellId),name=name,texture=texture,count=count})
                if i==32 then rec.buffScanComplete=false end
            end
        end
    end
    table.insert(s.actorContexts,rec)
    local id=table.getn(s.actorContexts)
    D.threatCalActorContextCache[guid]={id=id,time=now}
    return id
end

-- Default on for this calibration build; an explicit manual off survives login.
function D.threatCalStart()
    if D.threatCalEnabled then return end
    D.serverThreatSnapshot=nil
    if D.threatApiProbeEnabled or (D.threatApiLastRequestAt and D.threatApiLastRequestAt>0 and D.threatCalNow()-D.threatApiLastRequestAt<2) then D.threatCalAttributionUncertain=true end
    D.threatApiProbeEnabled=false
    if D.threatCalPendingRequests and next(D.threatCalPendingRequests) then D.threatCalAttributionUncertain=true end
    D.threatCalRequests=0; D.threatCalResponses=0; D.threatCalDuplicateResponses=0; D.threatCalUnmatchedResponses=0; D.threatCalTimedOutRequests=0
    D.threatCalLastPayload=nil; D.threatCalLastPayloadAt=0; D.threatCalNextRequest=0; D.threatCalPendingRequests={}; D.threatCalRequestSerial=0; D.threatCalLastTimeoutAt=0
    D.threatCalNewSession()
    D.threatCalEnabled=true
    D.threatCalApiRetryAt=0; D.threatCalTimeoutStreak=0
    D.threatCalTargetState=nil; D.threatCalObservedRequest=nil
    D.threatCalObserveTarget()
    D.threatCalInstallObserver()
end

function D.threatCalObserveTarget()
    if not D.threatCalEnabled or not D.threatCalSession then return end
    local guid,name,classification=D.threatCalTarget()
    local now=D.threatCalNow(); local state=D.threatCalTargetState
    if not state or state.guid~=guid or state.segmentSerial~=(D.segmentSerial or 0) then
        state={guid=guid,name=name,classification=classification,since=now,generation=(state and state.generation or 0)+1,segmentSerial=D.segmentSerial or 0}
        D.threatCalTargetState=state
        local s=D.threatCalSession
        s.targets=s.targets or {}
        if table.getn(s.targets)<6000 then
            table.insert(s.targets,{t=now-(s.startedGameTime or 0),guid=guid,name=name,generation=state.generation,segmentSerial=state.segmentSerial})
        else s.droppedTargetContexts=(s.droppedTargetContexts or 0)+1 end
    end
    return state
end

function D.threatCalObserveRequest(prefix,payload,channel)
    if not D.threatCalEnabled or not D.threatCalSession then return end
    if prefix~="TWT_UDTSv4" and prefix~="TWT_UDTSv4_TM" then return end
    local state=D.threatCalObserveTarget(); local now=D.threatCalNow()
    local s=D.threatCalSession
    s.observedRequests=(s.observedRequests or 0)+1
    local rec={serial=s.observedRequests,t=now-(s.startedGameTime or 0),sentAt=now,prefix=prefix,payload=string.sub(tostring(payload or ""),1,80),channel=channel,targetGuid=state.guid,target=state.name,targetGeneration=state.generation,segmentSerial=state.segmentSerial,stableFor=now-state.since}
    D.threatCalObservedRequest=rec
    s.requestContexts=s.requestContexts or {}
    if table.getn(s.requestContexts)<6000 then table.insert(s.requestContexts,rec)
    else s.droppedRequestContexts=(s.droppedRequestContexts or 0)+1 end
end

-- Observe the existing transport; never issue extra requests or change arguments.
function D.threatCalInstallObserver()
    if D.threatCalSendObserver or not SendAddonMessage then return end
    local original=SendAddonMessage
    D.threatCalSendObserver=function(prefix,payload,channel,target)
        -- Diagnostic failure must not prevent another addon's request.
        local ok,err=pcall(D.threatCalObserveRequest,prefix,payload,channel)
        if not ok and D.diagWarn then D.diagWarn("CAL_OBSERVER",tostring(err)) end
        return original(prefix,payload,channel,target)
    end
    SendAddonMessage=D.threatCalSendObserver
end

function D.threatCalLimit(field,code)
    local s=D.threatCalSession
    s[field]=(s[field] or 0)+1
    if s[field]==1 and D.diagCal then D.diagCal(code,"Calibration limit reached; further entries counted but omitted.") end
end

function D.threatCalTrace(kind,rec)
    if not D.threatCalEnabled or not D.threatCalSession then return end
    local s=D.threatCalSession
    s[kind]=s[kind] or {}
    if table.getn(s[kind])>=200 then s[kind.."Dropped"]=(s[kind.."Dropped"] or 0)+1; return end
    rec.t=D.threatCalNow()-(s.startedGameTime or 0)
    rec.segmentSerial=D.segmentSerial or 0
    table.insert(s[kind],rec)
end

function D.threatCalRecordRaw(ev,text)
    if not D.threatCalEnabled or not text then return end
    if string.find(text,"Faerie Fire",1,true) or string.find(text,"Demoralizing Roar",1,true) then
        D.threatCalTrace("druidRaw",{event=ev,text=string.sub(text,1,400)})
    end
    local named=string.find(string.lower(text),"feign death",1,true)
    if named or D.threatCalNow()<=(D.threatCalFeignUntil or 0) then
        D.threatCalTrace("feignRaw",{event=ev,text=string.sub(text,1,400)})
    end
end

function D.threatCalRecordEvent(rec)
    if not D.threatCalEnabled or not D.threatCalSession then return end
    local t=D.threatCalSession.events
    if table.getn(t)>=D.threatCalMaxEvents then D.threatCalLimit("droppedEvents","CAL_EVENT_LIMIT"); return end
    rec.t=D.threatCalNow()-(D.threatCalSession.startedGameTime or 0)
    rec.segmentSerial=D.segmentSerial or 0
    rec.actorContextId=D.threatCalActorContext(rec.guid,rec.source=="Growl")
    table.insert(t,rec)
end

function D.threatCalRecordCast(casterGuid,targetGuid,castType,spellId)
    if not D.threatCalEnabled or not D.threatCalSession then return end
    if castType=="MAINHAND" or castType=="OFFHAND" then
        D.threatCalSession.filteredSwings=(D.threatCalSession.filteredSwings or 0)+1
        return
    end
    if tonumber(spellId)==5384 then
        D.threatCalFeignUntil=D.threatCalNow()+2
        D.threatCalTrace("feignRaw",{event="UNIT_CASTEVENT",casterGuid=casterGuid,targetGuid=targetGuid,castType=castType,spellId=5384})
    end
    local t=D.threatCalSession.casts
    if table.getn(t)>=D.threatCalMaxCasts then D.threatCalLimit("droppedCasts","CAL_CAST_LIMIT"); return end
    local info=D.guidToActor and D.guidToActor[casterGuid]
    table.insert(t,{
        t=D.threatCalNow()-(D.threatCalSession.startedGameTime or 0),
        casterGuid=casterGuid,caster=info and info.name or nil,
        targetGuid=targetGuid,target=(D.threatCalcTargetName and D.threatCalcTargetName(targetGuid)) or nil,
        castType=castType,spellId=tonumber(spellId),
        actorContextId=D.threatCalActorContext(casterGuid,false)
    })
end

function D.threatCalParseResponse(msg)
    if not msg then return nil end
    local p=string.find(msg,"TWTv4=",1,true)
    if not p then return nil end
    local body=string.sub(msg,p+6)
    local rows={}
    local chunk
    for chunk in string.gfind(body,"([^;]+)") do
        local _,_,name,tank,threat,perc,melee,extra=string.find(chunk,"^([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):?(.*)$")
        if name and tank and threat and perc and melee then
            table.insert(rows,{name=name,tank=(tank=="1"),threat=tonumber(threat) or 0,percent=tonumber(perc) or 0,melee=(melee=="1"),extra=extra})
        end
    end
    return rows
end

function D.threatCalQueueRequest(targetGuid,targetName,classification,channel)
    local state=D.threatCalObserveTarget()
    D.threatCalPendingRequests=D.threatCalPendingRequests or {}
    D.threatCalRequestSerial=(D.threatCalRequestSerial or 0)+1
    table.insert(D.threatCalPendingRequests,{
        serial=D.threatCalRequestSerial, sentAt=D.threatCalNow(),
        segmentSerial=D.segmentSerial or 0,
        targetGeneration=state and state.generation or nil,
        targetGuid=targetGuid,target=targetName,classification=classification,channel=channel
    })
    -- Keep only a tiny recent queue. Responses are expected within one polling interval.
    while table.getn(D.threatCalPendingRequests)>8 do table.remove(D.threatCalPendingRequests,1) end
end

function D.threatCalTakeRequestForResponse()
    local q=D.threatCalPendingRequests or {}
    local now=D.threatCalNow()
    while table.getn(q)>0 do
        local r=table.remove(q,1)
        if r and now-(r.sentAt or 0)<=1.25 then return r end
        D.threatCalAttributionUncertain=true
    end
    return nil
end

function D.threatCalRecordSnapshot(msg,prefix,channel,sender)
    if not D.threatCalEnabled or not D.threatCalSession then return end
    local now=D.threatCalNow()
    local state=D.threatCalObserveTarget()
    local observed=D.threatCalObservedRequest
    local contextReason="no-observed-request"
    local stable=false
    if observed then
        if now-observed.sentAt>1.25 then contextReason="observed-request-expired"
        elseif observed.segmentSerial~=state.segmentSerial then contextReason="segment-changed"
        elseif observed.targetGeneration~=state.generation or observed.targetGuid~=state.guid then contextReason="target-changed"
        elseif not state.guid then contextReason="no-target"
        elseif observed.stableFor<2 then contextReason="target-settling"
        else stable=true; contextReason="stable-observed-target-provisional" end
    end
    local pending=D.threatCalPendingRequests and D.threatCalPendingRequests[1]
    -- The reference client does not require the response channel to equal the
    -- outgoing group channel. Keep rows, but do not claim exact attribution.
    local channelMismatch=pending and channel and channel~=pending.channel
    -- TWThreat may be running in parallel, so identical server snapshots can arrive twice.
    if D.threatCalLastPayload==msg and now-(D.threatCalLastPayloadAt or 0)<0.20 then
        D.threatCalDuplicateResponses=(D.threatCalDuplicateResponses or 0)+1
        D.threatCalSession.duplicateResponses=(D.threatCalSession.duplicateResponses or 0)+1
        return
    end
    D.threatCalLastPayload=msg; D.threatCalLastPayloadAt=now
    local rows=D.threatCalParseResponse(msg)
    if not rows then return end
    local snaps=D.threatCalSession.snapshots
    local req=D.threatCalTakeRequestForResponse()
    if not req then
        D.threatCalUnmatchedResponses=(D.threatCalUnmatchedResponses or 0)+1
        if D.threatCalSession then D.threatCalSession.unmatchedResponses=(D.threatCalSession.unmatchedResponses or 0)+1 end
        -- Passive capture is needed when TWThreat owns the requests. Never
        -- substitute the player's current target for an unknown response target.
        req={segmentSerial=D.segmentSerial or 0}
    end
    local tg,tn,tc=req.targetGuid,req.target,req.classification
    local uncertain=not req.serial or channelMismatch or D.threatCalAttributionUncertain or req.segmentSerial~=(D.segmentSerial or 0) or req.targetGuid~=state.guid or (req.targetGeneration and req.targetGeneration~=state.generation) or (IsAddOnLoaded and IsAddOnLoaded("TWThreat"))

    if D.serverThreatPublish then D.serverThreatPublish(rows,req,state,uncertain) end
    if table.getn(snaps)>=D.threatCalMaxSnapshots then D.threatCalLimit("droppedSnapshots","CAL_SNAPSHOT_LIMIT"); return end
    local out={t=now-(D.threatCalSession.startedGameTime or 0),requestSerial=req.serial,requestAge=now-(req.sentAt or now),targetGuid=tg,target=tn,classification=tc,rows={}}
    out.prefix=prefix; out.channel=channel; out.sender=sender
    out.segmentSerial=req.segmentSerial
    out.requestTargetGuid=tg; out.requestTarget=tn
    out.targetAttribution="request-context-only"
    out.comparisonProvisional=true
    out.captureMode=req.serial and "own-request" or "passive"
    out.channelMismatch=channelMismatch and true or false
    out.observedRequestSerial=observed and observed.serial or nil
    out.observedRequestTargetGuid=observed and observed.targetGuid or nil
    out.observedRequestAge=observed and now-observed.sentAt or nil
    out.receiveTargetGuid=state.guid
    out.receiveTargetGeneration=state.generation
    out.contextReason=contextReason
    out.stableTargetCandidate=stable
    if uncertain then
        out.targetGuid=nil; out.target=nil; out.classification=nil
        out.targetAttribution="unmatched-risk-after-timeout-or-parallel-probe"
        if not req.serial then out.targetAttribution="no-correlated-request"; out.requestAge=nil end
    end
    local _,r
    for _,r in rows do
        local actor,matchCount,ambiguous=D.threatCalActorByName(r.name,tg)
        local classToken,unit=nil,nil
        if not ambiguous then classToken,unit=D.threatCalClassForName(r.name) end
        if ambiguous and D.diagCal then D.diagCal("ACTOR_AMBIGUOUS","Threat API actor name matched multiple local actors: "..tostring(r.name),"target="..tostring(tn).." guid="..tostring(tg)) end
        local calc=nil
        if not uncertain and actor and actor.threat and tg then calc=actor.threat[tg] or 0 end
        table.insert(out.rows,{
            name=r.name,server=r.threat,percent=r.percent,tank=r.tank,melee=r.melee,
            caw=calc,diff=(calc~=nil) and (calc-r.threat) or nil,
            -- Separate candidate data from exact/protocol-correlated comparisons.
            observedModel=(stable and not ambiguous and actor and actor.threat) and actor.threat[state.guid] or nil,
            actorMatchCount=matchCount or 0,ambiguousActor=ambiguous and true or false,
            class=classToken or (actor and actor.classToken) or nil,
            unit=unit,
            guid=actor and actor.guid or nil,
            isPet=actor and actor.isPet or false,
            ownerKey=actor and actor.ownerKey or nil,
            actorContextId=not ambiguous and actor and D.threatCalActorContext(actor.guid,false) or nil
        })
    end
    table.insert(snaps,out)
    D.threatCalResponses=(D.threatCalResponses or 0)+1
    D.threatCalSession.responses=(D.threatCalSession.responses or 0)+1
    D.threatCalTimeoutStreak=0; D.threatCalApiRetryAt=0
end

function D.threatCalSendRequest()
    if IsAddOnLoaded and IsAddOnLoaded("TWThreat") then
        D.threatCalAttributionUncertain=true
        return false,"parallel TWThreat: API sampling paused"
    end
    -- Keep at most one request in flight. Without a request id in TWTv4, a
    -- dropped response would otherwise shift the queue and silently bind the
    -- next server snapshot to the wrong mob.
    local now=D.threatCalNow()
    D.threatCalPendingRequests=D.threatCalPendingRequests or {}
    if table.getn(D.threatCalPendingRequests)>0 then
        local pending=D.threatCalPendingRequests[1]
        if now-(pending.sentAt or now)<=1.25 then return false,"awaiting response" end
        table.remove(D.threatCalPendingRequests,1)
        D.threatCalTimedOutRequests=(D.threatCalTimedOutRequests or 0)+1
        D.threatCalLastTimeoutAt=now
        D.threatCalAttributionUncertain=true
        D.threatCalTimeoutStreak=(D.threatCalTimeoutStreak or 0)+1
        D.threatCalApiRetryAt=now+math.min(60,2^math.min(D.threatCalTimeoutStreak,6))
        if D.threatCalSession then D.threatCalSession.timedOutRequests=(D.threatCalSession.timedOutRequests or 0)+1 end
        D.threatCalTrace("transport",{kind="timeout",serial=pending.serial,targetGuid=pending.targetGuid,retryIn=D.threatCalApiRetryAt-now})
        if D.threatCalTimeoutStreak==1 and D.diagCal then D.diagCal("API_TIMEOUT","Threat API request timed out; retries use bounded backoff.") end
        if D.threatCalTimeoutStreak==3 and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Caw:|r No matching server threat response. Local recording continues; API retries slowed.") end
        return false,"request timeout"
    end
    -- Short quarantine after a timeout reduces the chance that a very late
    -- response is mistaken for the next request.
    if now-(D.threatCalLastTimeoutAt or 0)<0.75 then return false,"timeout quarantine" end
    if now<(D.threatCalApiRetryAt or 0) then return false,"timeout backoff" end
    local ok,channel=D.threatCalApiEligible()
    if not ok then return false,channel end
    local sender=nil
    if SendAddonMessage then sender=SendAddonMessage
    elseif C_ChatInfo and C_ChatInfo.SendAddonMessage then sender=C_ChatInfo.SendAddonMessage end
    if not sender then if D.diagWarn then D.diagWarn("API_TRANSPORT","No SendAddonMessage API available.") end; return false,"no SendAddonMessage" end
    local tg,tn,tc=D.threatCalTarget()
    if not tg then if D.diagCal then D.diagCal("TARGET_GUID","Eligible threat target has no usable GUID.") end; return false,"target guid unavailable" end
    -- TWThreat 1.3.0 defaults to five visible bars and requests visibleBars-1.
    local success,err=pcall(sender,"TWT_UDTSv4","limit=4",channel)
    if not success then if D.diagWarn then D.diagWarn("API_SEND_ERROR",tostring(err),"channel="..tostring(channel)) end; return false,tostring(err) end
    D.threatCalQueueRequest(tg,tn,tc,channel)
    D.threatCalTrace("transport",{kind="request",prefix="TWT_UDTSv4",payload="limit=4",channel=channel,targetGuid=tg,target=tn,serial=D.threatCalRequestSerial})
    D.threatCalRequests=(D.threatCalRequests or 0)+1
    if D.threatCalSession then D.threatCalSession.requests=(D.threatCalSession.requests or 0)+1 end
    return true,nil
end

-- Wrap RC26's calculator at the lowest common point. Every modeled threat delta is
-- captured together with the actor/target/source and model total before/after.
if D.threatAdd and not D.threatCalOriginalThreatAdd then
    D.threatCalOriginalThreatAdd=D.threatAdd
    D.threatAdd=function(actor,targetGuid,amount,source,baseAmount,kind)
        local before=0
        if actor and actor.threat and targetGuid then before=actor.threat[targetGuid] or 0 end
        D.threatCalOriginalThreatAdd(actor,targetGuid,amount,source,baseAmount,kind)
        local after=before
        if actor and actor.threat and targetGuid then after=actor.threat[targetGuid] or before end
        if D.threatCalEnabled and after~=before then
            D.threatCalRecordEvent({
                actor=actor and actor.name or nil,guid=actor and actor.guid or nil,
                class=actor and actor.classToken or nil,isPet=actor and actor.isPet or false,ownerKey=actor and actor.ownerKey or nil,
                targetGuid=targetGuid,target=(D.threatCalcTargetName and D.threatCalcTargetName(targetGuid)) or nil,
                source=source,kind=kind,requested=tonumber(amount) or 0,base=tonumber(baseAmount) or 0,
                before=before,after=after,delta=after-before,
                modifier=(actor and D.threatGlobalModifier and D.threatGlobalModifier(actor)) or 1
            })
        end
    end
end

-- Threat resets (Feign Death and any future full resets) bypass threatAdd(), so
-- capture their actual before/after deltas explicitly for calibration.
if D.threatResetActor and not D.threatCalOriginalThreatResetActor then
    D.threatCalOriginalThreatResetActor=D.threatResetActor
    D.threatResetActor=function(actor,source)
        local before={}
        local tg,v
        if actor and actor.threat then for tg,v in actor.threat do if v and v~=0 then before[tg]=v end end end
        D.threatCalOriginalThreatResetActor(actor,source)
        if D.threatCalEnabled then
            for tg,v in before do
                local after=0
                if actor and actor.threat then after=actor.threat[tg] or 0 end
                if after~=v then
                    D.threatCalRecordEvent({
                        actor=actor and actor.name or nil,guid=actor and actor.guid or nil,
                        class=actor and actor.classToken or nil,isPet=actor and actor.isPet or false,ownerKey=actor and actor.ownerKey or nil,
                        targetGuid=tg,target=(D.threatCalcTargetName and D.threatCalcTargetName(tg)) or nil,
                        source=source or "Threat reset",kind="reset",requested=after-v,base=0,
                        before=v,after=after,delta=after-v,modifier=1
                    })
                end
            end
        end
    end
end

D.threatCalFrame=D.threatCalFrame or CreateFrame("Frame","CawThreatCalibrationFrame",UIParent)
local F=D.threatCalFrame
F:RegisterEvent("ADDON_LOADED")
F:RegisterEvent("PLAYER_ENTERING_WORLD")
F:RegisterEvent("CHAT_MSG_ADDON")
F:RegisterEvent("UNIT_CASTEVENT")
F:RegisterEvent("PLAYER_LOGOUT")
F:RegisterEvent("PLAYER_TARGET_CHANGED")
F:SetScript("OnEvent",function()
    if event=="ADDON_LOADED" then
        if arg1=="CawDPSMeter" or arg1==nil then D.threatCalEnsureDB() end
    elseif event=="PLAYER_ENTERING_WORLD" then
        CawDPSMeterCharDB=CawDPSMeterCharDB or {}
        if CawDPSMeterCharDB.threatCalAutoStart==nil then CawDPSMeterCharDB.threatCalAutoStart=true end
        if CawDPSMeterCharDB.threatCalAutoStart and not D.threatCalEnabled then
            D.threatCalStart()
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r Automatic calibration recording active. Data is saved on normal logout/exit; API comparisons remain provisional.") end
        end
    elseif event=="CHAT_MSG_ADDON" then
        if D.threatCalEnabled and ((arg1 and string.find(string.lower(tostring(arg1)),"twt",1,true)) or (arg2 and string.find(tostring(arg2),"TWTv",1,true))) then
            D.threatCalTrace("transport",{kind="candidate-response",prefix=arg1,channel=arg3,sender=arg4,payload=string.sub(tostring(arg2 or ""),1,400)})
        end
        if D.threatCalEnabled and arg2 and string.find(tostring(arg2),"TWTv4=",1,true) then D.threatCalRecordSnapshot(tostring(arg2),arg1,arg3,arg4) end
    elseif event=="PLAYER_TARGET_CHANGED" then
        D.threatCalObserveTarget()
    elseif event=="UNIT_CASTEVENT" then
        if D.threatCalEnabled then D.threatCalRecordCast(arg1,arg2,arg3,arg4) end
    elseif event=="PLAYER_LOGOUT" then
        if D.threatCalSession and D.threatCalEnabled then
            D.threatCalSession.endedAt=D.threatCalStamp()
            D.threatCalSession.stopReason="logout"
        end
    end
end)

F:SetScript("OnUpdate",function()
    if D.threatCalEnabled and D.threatCalNow()>=(D.threatCalNextRequest or 0) then
        D.threatCalNextRequest=D.threatCalNow()+0.50
        D.threatCalObserveTarget()
        D.threatCalSendRequest()
    end
end)

SLASH_CAWDPSTHREATCAL1="/cdthreatcal"
SlashCmdList["CAWDPSTHREATCAL"]=function(msg)
    msg=string.lower(tostring(msg or ""))
    if msg=="status" then
        local s=D.threatCalSession
        local ev=s and table.getn(s.events or {}) or 0
        local ca=s and table.getn(s.casts or {}) or 0
        local sn=s and table.getn(s.snapshots or {}) or 0
        if DEFAULT_CHAT_FRAME then
            if D.threatCalAttributionUncertain then DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Caw:|r Target attribution uncertain; target/diff claims suppressed until reload.") end
            if IsAddOnLoaded and IsAddOnLoaded("TWThreat") then DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Caw:|r Passive capture of TWThreat responses; own requests paused.") end
            DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r Threat calibration "..(D.threatCalEnabled and "|cff00ff00ON|r" or "OFF").." | requests "..tostring(D.threatCalRequests or 0).." | API snapshots "..tostring(D.threatCalResponses or 0).." | duplicate snapshots "..tostring(D.threatCalDuplicateResponses or 0).." | unmatched "..tostring(D.threatCalUnmatchedResponses or 0).." | timeouts "..tostring(D.threatCalTimedOutRequests or 0))
            DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r stored model events "..tostring(ev).." | casts "..tostring(ca).." | snapshots "..tostring(sn).." | dropped "..tostring((s and s.droppedEvents or 0)+(s and s.droppedCasts or 0)+(s and s.droppedSnapshots or 0)))
        end
        return
    end
    if msg=="clear" then
        if D.threatCalEnabled then
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r Stop calibration before clearing: /cdthreatcal off") end
            return
        end
        CawThreatCalibrationDB={schema=1,loggerVersion=D.threatCalibrationVersion,sessions={}}
        D.threatCalSession=nil
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r Threat calibration database cleared.") end
        return
    end
    if msg=="off" or (msg=="" and D.threatCalEnabled) then
        CawDPSMeterCharDB=CawDPSMeterCharDB or {}
        CawDPSMeterCharDB.threatCalAutoStart=false
        if D.threatCalEnabled then
            D.threatCalEnabled=false
            if D.threatCalPendingRequests and next(D.threatCalPendingRequests) then D.threatCalAttributionUncertain=true end
            if D.threatCalSession then
                D.threatCalSession.endedAt=D.threatCalStamp()
                D.threatCalSession.stopReason="manual"
            end
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r Threat calibration stopped. Use /reload before copying WTF/Account/.../SavedVariables/CawDPSMeter.lua.")
                DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r Data table: CawThreatCalibrationDB")
            end
        end
        return
    end
    if msg=="on" or msg=="" then
        CawDPSMeterCharDB=CawDPSMeterCharDB or {}
        CawDPSMeterCharDB.threatCalAutoStart=true
        if D.threatCalEnabled then return end
        D.threatCalStart()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r Threat calibration started. API comparisons are provisional: TWTv4 has no response target ID.")
            if D.threatCalAttributionUncertain then DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Caw:|r Target attribution is uncertain after pending/expired requests. Server rows are retained without target/diff claims until reload.") end
            DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r Threat model stays active in parallel; casts + model deltas + TWTv4 snapshots are stored.")
        end
        return
    end
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r /cdthreatcal on | off | status | clear") end
end

-- On-demand, addressed destination snapshots. Never modify combat totals or
-- add two observers' counts together. Only a complete, more comprehensive
-- snapshot from the actor's owner can replace the local view of that actor.
local D=CAW_DPS_METER
local remote=setmetatable({},{__mode="k"})
local applied=setmetatable({},{__mode="k"})
local attempts=setmetatable({},{__mode="k"})
local localSums=setmetatable({},{__mode="k"})
local replyAfter={}
local serial=math.mod(math.floor(GetTime()*1000),900000000)
local MAX_ACTORS,MAX_TARGETS,MAX_ROWS=16,80,256
local function diagnose(code,job) if D.targetSyncDiag then D.targetSyncDiag(code,job) end end
local fields={"damage","healing","hits","crits","overhealing","overhealTotal","overhealHits","overhealCrits"}
local function integer(s,lo,hi)
    local n=tonumber(s)
    if n and n==n and n>=lo and n<=hi and n==math.floor(n) then return n end
end
local function guid(s) return type(s)=="string" and string.len(s)<=18 and string.find(s,"^0x[%x]+$") and not string.find(s,"^0x0+$") end
local function selfGuid() local _,g=UnitExists("player"); return g end
local function fieldFor(kind) return kind=="D" and "damageTargets" or "healingTargets" end
local function modeFor(kind) return kind=="D" and "damage" or "healing" end
local function escape(s)
    s=string.gsub(tostring(s or ""),"%%","%%25"); s=string.gsub(s,"~","%%7E")
    s=string.gsub(s,"|",""); s=string.gsub(s,"[%c]"," "); return s
end
local function unescape(s,maximum)
    if type(s)~="string" or string.len(s)>maximum then return end
    s=string.gsub(s,"%%(%x%x)",function(hex) return string.char(tonumber(hex,16)) end)
    if s=="" or string.find(s,"[|%c]") then return end
    return s
end
local function sum(targets)
    local result={}
    for _,t in pairs(targets or {}) do
        for _,field in ipairs(fields) do if t[field]~=nil then result[field]=(result[field] or 0)+t[field] end end
    end
    return result
end
function D.targetDataForActor(actor,mode)
    local kind=mode=="damage" and "D" or "H"; local field=fieldFor(kind)
    local snapshot=remote[actor] and remote[actor][kind]
    if not snapshot then return actor[field],false end
    local cached=localSums[actor]
    if not cached or cached.version~=actor.targetRevision then
        cached={version=actor.targetRevision}; localSums[actor]=cached
    end
    if not cached[kind] then cached[kind]=sum(actor[field]) end
    local own=cached[kind]; local other=snapshot.totals; local amount=modeFor(kind)
    -- Keep each snapshot internally coherent, including known overheal coverage.
    -- A response ahead of the normal totals stays cached until those catch up.
    local better=false
    for _,key in ipairs(kind=="D" and {"damage"} or {"healing","overhealing","overhealTotal"}) do
        local o,r=own[key],other[key]
        if (r or 0)<(o or 0) or (r or 0)>(actor[key] or 0)+0.01 then return actor[field],false end
        if (r or 0)>(o or 0) or (r~=nil and o==nil) then better=true end
    end
    if better and (other[amount] or 0)>=(own[amount] or 0) then return snapshot.targets,true end
    return actor[field],false
end
local function enemies(context)
    if context.segment=="history" then return context.history and context.history.targetSyncEnemies end
    local list={}
    for g,value in pairs(D.currentEnemyDamage or {}) do if guid(g) then table.insert(list,{g=g,value=value}) end end
    table.sort(list,function(a,b) return a.value>b.value end)
    local out={}
    for i=1,math.min(3,table.getn(list)) do out[i]=list[i].g end
    return table.concat(out,",")
end
local function startTime(context)
    if context.segment=="history" then return context.history and context.history.targetSyncStart end
    if context.segment=="current" and context.serial==D.segmentSerial and D.startTime and D.startTime>0 then return D.startTime end
end
local function overlaps(a,b)
    if not a or not b or a=="" or b=="" then return false end
    for g in string.gfind(a,"0x[%x]+") do if string.find(","..b..",",","..g..",",1,true) then return true end end
    return false
end
local function eligibleActors(context,key)
    local actors=D.breakdownActors(context); local a=actors[key]
    if not a then return end
    return actors,a
end
local function owns(a,owner) return a and (a.guid==owner or (a.isPet and a.ownerKey==owner)) end
local function validRequest(req)
    if not req or not D.combatSyncEnabled() then return false end
    local actors,a=eligibleActors(req.context,req.key)
    return actors==req.actors and a==req.actor and D.threatPeerUnit(req.owner,req.name)
end
local function accumulate(dst,source,sign)
    for g,t in pairs(source or {}) do
        local d=dst[g]
        if not d then d={spells={}}; dst[g]=d end
        d.name=t.name or d.name; d.classToken=t.classToken or d.classToken
        for _,field in ipairs(fields) do if t[field]~=nil then d[field]=(d[field] or 0)+sign*t[field] end end
        for spell,s in pairs(t.spells or {}) do
            local e=d.spells[spell]
            if not e then e={}; d.spells[spell]=e end
            e.spellId=s.spellId or e.spellId
            for _,field in ipairs(fields) do if s[field]~=nil then e[field]=(e[field] or 0)+sign*s[field] end end
            if (e.hits or 0)<=0 then d.spells[spell]=nil end
        end
        if (d.hits or 0)<=0 then dst[g]=nil end
    end
end
local function reconcileHistory(h)
    if not h or h.targetSyncEpoch~=D.overallSegment.targetSyncEpoch then return end
    for key,a in pairs(h.actors) do
        local overall=D.overallSegment.actors[key]
        if overall then
            applied[a]=applied[a] or {}
            for _,kind in ipairs({"D","H"}) do
                local field=fieldFor(kind); local chosen,isRemote=D.targetDataForActor(a,modeFor(kind))
                local previous=applied[a][kind] or a[field]
                if chosen~=previous then
                    overall[field]=overall[field] or {}
                    accumulate(overall[field],previous,-1); accumulate(overall[field],chosen,1)
                    overall.targetRevision=(overall.targetRevision or 0)+1
                    if isRemote then
                        overall.targetHasSynced=overall.targetHasSynced or {}; overall.targetHasSynced[kind]=true
                    end
                    applied[a][kind]=chosen
                end
            end
        end
    end
end
function D.targetSyncSaveFight(h)
    h.targetSyncStart=D.startTime; h.targetSyncSerial=D.segmentSerial; h.targetSyncEnemies=enemies({segment="current"})
    D.overallSegment.targetSyncEpoch=D.overallSegment.targetSyncEpoch or {}
    h.targetSyncEpoch=D.overallSegment.targetSyncEpoch
    for key,a in pairs(h.actors) do
        local r=remote[D.actors[key]]; if r then remote[a]={D=r.D,H=r.H} end
    end
end
function D.targetSyncFinishFight(h) reconcileHistory(h) end

local function missing(context,key,kind)
    local actors,a=eligibleActors(context,key)
    if not a then return false end
    for _,source in pairs(actors) do
        if source==a or (not a.isPet and source.isPet and source.ownerKey==a.key) then
            local targets=D.targetDataForActor(source,modeFor(kind)); local totals=sum(targets)
            if (totals[modeFor(kind)] or 0)+0.01<(source[modeFor(kind)] or 0) then return true end
            if kind=="H" and (totals.overhealTotal or 0)+0.01<(source.overhealTotal or 0) then return true end
        end
    end
    return false
end
local function makeJob(context,key,kind)
    local actors,a=eligibleActors(context,key)
    if not a or not missing(context,key,kind) then return nil,"ALREADY_COVERED" end
    local owner=a.isPet and a.ownerKey or a.guid
    local peer=owner and D.threatSyncPeers[owner]
    local start=startTime(context); local enemy=enemies(context)
    if owner==selfGuid() then return nil,"LOCAL_PLAYER" end
    if not guid(owner) or not guid(a.guid) then return nil,"UNKNOWN_OWNER" end
    if not peer or GetTime()-peer.time>45 or not D.threatPeerUnit(owner,peer.name) then return nil,"PEER_UNAVAILABLE" end
    if not peer.targetDetails then return nil,"UNSUPPORTED_PEER" end
    if not start or not enemy or enemy=="" then return nil,"FIGHT_UNAVAILABLE" end
    return {context=context,key=key,kind=kind,actors=actors,actor=a,owner=owner,name=peer.name}
end
function D.cancelTargetSync()
    if D.targetSyncRequest or D.targetSyncPlan or D.targetSyncOut then
        diagnose(not D.parserEnabled() and "PARSER_PAUSED" or (not D.combatSyncEnabled() and "SYNC_DISABLED" or "CANCELLED"),
            D.targetSyncRequest or D.targetSyncOut)
    end
    D.targetSyncRequest=nil; D.targetSyncPlan=nil; D.targetSyncOut=nil
end
function D.targetSyncCloseView()
    if D.targetSyncRequest or D.targetSyncPlan then diagnose("VIEW_CLOSED",D.targetSyncRequest) end
    D.targetSyncRequest=nil; D.targetSyncPlan=nil
end
function D.targetSyncViewStatus(context,key,allowRequest)
    if not D.combatSyncEnabled() then
        if allowRequest then diagnose(D.parserEnabled() and "SYNC_DISABLED" or "PARSER_PAUSED",{context=context}) end
        return "Combat sync is off."
    end
    local actors,a=eligibleActors(context,key); if not a then return end
    local kind=context.mode=="damage" and "D" or "H"
    local active=D.targetSyncPlan
    if active and (active.viewActor~=a or active.kind~=kind) then D.targetSyncCloseView() end
    local state=attempts[a] and attempts[a][kind]
    if allowRequest and not D.targetSyncPlan and (not state or GetTime()-state.time>=30) then
        local jobs={}; local reason="NO_RETAINED_FIGHTS"
        if context.segment=="overall" then
            for _,h in ipairs(D.fightHistory) do
                if h.targetSyncEpoch==D.overallSegment.targetSyncEpoch then
                    local c={segment="history",history=h,mode=context.mode}
                    local job,why=makeJob(c,key,kind); reason=why; if job then table.insert(jobs,job) end
                end
            end
        else
            local job,why=makeJob(context,key,kind); reason=why; if job then table.insert(jobs,job) end
        end
        if table.getn(jobs)>0 then
            state={time=GetTime(),text="Requesting missing details..."}
            attempts[a]=attempts[a] or {}; attempts[a][kind]=state
            D.targetSyncPlan={jobs=jobs,index=1,state=state,deadline=GetTime()+45,viewActor=a,kind=kind}
        else
            -- Remember failed capability checks too; opening/painting a view
            -- repeatedly must not fill diagnostics with the same decision.
            state={time=GetTime()}; attempts[a]=attempts[a] or {}; attempts[a][kind]=state
            if reason~="ALREADY_COVERED" and reason~="LOCAL_PLAYER" then
                diagnose(reason or "FIGHT_UNAVAILABLE",{context=context,kind=kind})
            end
        end
    end
    return state and state.text or nil
end
local function finish(text,code)
    if code then diagnose(code,D.targetSyncRequest) end
    local plan=D.targetSyncPlan; D.targetSyncRequest=nil
    if plan then
        plan.state.text=text; plan.index=plan.index+1; plan.nextRequest=GetTime()+5
        if plan.index>table.getn(plan.jobs) then D.targetSyncPlan=nil end
    end
end
local function prefix(action,dest,owner,nonce)
    return "Y~1~"..action.."~"..dest.."~"..owner.."~"..nonce
end
local function findFight(enemy,age,duration)
    local found=nil
    local candidates={{segment="current",serial=D.segmentSerial}}
    for _,h in ipairs(D.fightHistory) do table.insert(candidates,{segment="history",history=h}) end
    for _,context in ipairs(candidates) do
        local start=startTime(context)
        local length=context.history and context.history.duration or D.uiDuration()
        if start and overlaps(enemy,enemies(context)) and math.abs(GetTime()-start-age)<=8
            and math.abs((GetTime()-start-length)-(age-duration))<=8 then
            -- Current may still display the most recently finished history entry.
            if found and start~=startTime(found) then return end
            if not found or context.history then found=context end
        end
    end
    return found
end
local function buildReply(req,context)
    local actors=D.breakdownActors(context); local root=actors[req.key]
    if not owns(root,req.owner) then return end
    local packets={}; local actorCount,targetCount,rowCount=0,0,0
    local function put(action,suffix)
        local packet=prefix(action,req.dest,req.owner,req.nonce)..suffix
        if string.len(packet)>240 then return false end
        table.insert(packets,packet); return true
    end
    for _,a in pairs(actors) do
        if a==root or (not root.isPet and a.isPet and a.ownerKey==root.key) then
            local targets=a[fieldFor(req.kind)]
            if targets and next(targets) then
                actorCount=actorCount+1
                if actorCount>MAX_ACTORS or not guid(a.guid) or not put("A","~"..actorCount.."~"..a.guid) then return end
                for g,t in pairs(targets) do
                    targetCount=targetCount+1
                    if targetCount>MAX_TARGETS or not guid(g) or not put("T","~"..actorCount.."~"..targetCount.."~"..g.."~"..escape(t.name or "Unknown target")) then return end
                    for spell,s in pairs(t.spells or {}) do
                        rowCount=rowCount+1
                        if rowCount>MAX_ROWS then return end
                        local tail="~"..actorCount.."~"..targetCount.."~"..rowCount.."~"..escape(spell).."~"..(s.spellId or "")
                            .."~"..(s[modeFor(req.kind)] or 0).."~"..(s.hits or 0).."~"..(s.crits or 0)
                        if req.kind=="H" then
                            for _,field in ipairs({"overhealing","overhealTotal","overhealHits","overhealCrits"}) do tail=tail.."~"..(s[field] or "") end
                        end
                        if not put("S",tail) then return end
                    end
                end
            end
        end
    end
    table.insert(packets,1,prefix("B",req.dest,req.owner,req.nonce).."~"..actorCount.."~"..targetCount.."~"..rowCount)
    put("E","")
    return packets
end
function D.targetSyncReceive(sender,p,channel)
    if not D.combatSyncEnabled() or (channel~="PARTY" and channel~="RAID") or p[2]~="1"
        or table.getn(p)>18 or not guid(p[4]) or not guid(p[5]) or not integer(p[6],1,999999999) then return end
    local me=selfGuid(); local now=GetTime(); local action=p[3]
    if action=="Q" then
        if p[5]~=me or not D.threatPeerUnit(p[4],sender) or not guid(p[8]) or (p[7]~="D" and p[7]~="H") then return end
        if now<(replyAfter[p[4]] or 0) then return end
        replyAfter[p[4]]=now+5
        if D.targetSyncOut then diagnose("REPLY_BUSY"); return end
        local age=integer(p[10],0,864000); local duration=integer(p[11],0,864000)
        if not age or not duration or duration>age+80 or not p[9] or string.len(p[9])>56 then return end
        local context=findFight(p[9],age/10,duration/10)
        local req={dest=p[4],owner=me,nonce=p[6],kind=p[7],key=p[8]}
        local packets=context and buildReply(req,context)
        diagnose(not context and "NO_MATCHING_FIGHT" or (not packets and "REPLY_UNAVAILABLE" or "REPLY_STARTED"),
            {kind=req.kind,context=context,channel=channel})
        if not packets then packets={prefix("N",p[4],me,p[6])} end
        D.targetSyncOut={packets=packets,index=1,channel=channel,dest=p[4],name=sender,deadline=now+40,kind=req.kind,context=context}
        return
    end
    local req=D.targetSyncRequest
    if not req or p[4]~=me or p[5]~=req.owner or p[6]~=req.nonce or sender~=req.name
        or channel~=req.channel or not validRequest(req) or now>req.deadline then return end
    if action=="N" then finish("No matching target details available.","REMOTE_UNAVAILABLE"); return end
    if action=="B" then
        if req.buffer then req.invalid=true; return end
        local ac=integer(p[7],0,MAX_ACTORS); local tc=integer(p[8],0,MAX_TARGETS); local rc=integer(p[9],0,MAX_ROWS)
        if not ac or not tc or not rc then req.invalid=true; return end
        req.buffer={actors={},targets={},rows={},ac=ac,tc=tc,rc=rc,actorsSeen=0,targetsSeen=0,rowsSeen=0}
        return
    end
    local b=req.buffer; if not b or req.invalid then return end
    local ai=integer(p[7],1,b.ac)
    if action=="A" then
        if not ai or b.actors[ai] or not guid(p[8]) then req.invalid=true; return end
        local a=req.actors[p[8]]
        if not owns(a,req.owner) or (a~=req.actor and (req.actor.isPet or a.ownerKey~=req.actor.key)) then req.invalid=true; return end
        for _,entry in pairs(b.actors) do if entry.actor==a then req.invalid=true; return end end
        b.actors[ai]={actor=a,targets={}}; b.actorsSeen=b.actorsSeen+1
    elseif action=="T" then
        local ti=integer(p[8],1,b.tc); local name=unescape(p[10],160); local a=ai and b.actors[ai]
        if not ti or b.targets[ti] or not a or not guid(p[9]) or not name or a.targets[p[9]] then req.invalid=true; return end
        local target={name=name,spells={}}; a.targets[p[9]]=target
        b.targets[ti]={actor=ai,data=target}; b.targetsSeen=b.targetsSeen+1
    elseif action=="S" then
        local ti=integer(p[8],1,b.tc); local ri=integer(p[9],1,b.rc); local target=ti and b.targets[ti]
        local name=unescape(p[10],160); local id=p[11]=="" and nil or integer(p[11],1,99999999)
        local amount=integer(p[12],0,1000000000000); local hits=integer(p[13],1,1000000000); local crits=integer(p[14],0,1000000000)
        if not ri or b.rows[ri] or not target or target.actor~=ai or not name or target.data.spells[name]
            or (p[11]~="" and not id) or not amount or not hits or not crits or crits>hits then req.invalid=true; return end
        local row={hits=hits,crits=crits,spellId=id}; row[modeFor(req.kind)]=amount
        if req.kind=="H" and p[15]~="" then
            local over=integer(p[15],0,1000000000000); local gross=integer(p[16],0,1000000000000)
            local oh=integer(p[17],1,hits); local oc=integer(p[18],0,crits)
            if not over or not gross or gross<over or gross-over>amount or not oh or not oc or oc>oh then req.invalid=true; return end
            row.overhealing=over; row.overhealTotal=gross; row.overhealHits=oh; row.overhealCrits=oc
        elseif req.kind=="H" and (p[16]~="" or p[17]~="" or p[18]~="") then req.invalid=true; return end
        target.data.spells[name]=row
        for _,field in ipairs(fields) do if row[field]~=nil then target.data[field]=(target.data[field] or 0)+row[field] end end
        b.rows[ri]=true; b.rowsSeen=b.rowsSeen+1
    elseif action=="E" then
        if b.actorsSeen~=b.ac or b.targetsSeen~=b.tc or b.rowsSeen~=b.rc then finish("Incomplete target details; keeping existing data.","INCOMPLETE_REPLY"); return end
        for _,target in pairs(b.targets) do if not next(target.data.spells) then finish("Incomplete target details; keeping existing data.","INCOMPLETE_REPLY"); return end end
        for _,entry in pairs(b.actors) do
            remote[entry.actor]=remote[entry.actor] or {}
            local previous=remote[entry.actor][req.kind]; local totals=sum(entry.targets); local keep=true
            if previous then
                for _,field in ipairs(fields) do
                    if previous.totals[field]~=nil and (totals[field]==nil or totals[field]<previous.totals[field]) then keep=false end
                end
            end
            if keep then remote[entry.actor][req.kind]={targets=entry.targets,totals=totals} end
            entry.actor.targetRevision=(entry.actor.targetRevision or 0)+1
        end
        if req.context.history then reconcileHistory(req.context.history)
        else
            for _,h in ipairs(D.fightHistory) do
                if h.targetSyncSerial==req.context.serial then
                    for _,entry in pairs(b.actors) do
                        local a=h.actors[entry.actor.key]
                        if a then
                            remote[a]=remote[a] or {}; remote[a][req.kind]=remote[entry.actor][req.kind]
                            a.targetRevision=(a.targetRevision or 0)+1
                        end
                    end
                    reconcileHistory(h); break
                end
            end
        end
        finish("Caw Sync details received.","REPLY_RECEIVED")
    end
end
function D.targetSyncTick(send,channel)
    if not D.targetSyncRequest and not D.targetSyncPlan and not D.targetSyncOut then return end
    if not D.combatSyncEnabled() then D.cancelTargetSync(); return end
    if not channel then
        diagnose("GROUP_LEFT",D.targetSyncRequest or D.targetSyncOut)
        D.targetSyncRequest=nil; D.targetSyncPlan=nil; D.targetSyncOut=nil; return
    end
    local now=GetTime(); local req=D.targetSyncRequest; local plan=D.targetSyncPlan
    if req and (not validRequest(req) or now>req.deadline or req.invalid) then
        finish("Target details unavailable; keeping existing data.",req.invalid and "INVALID_REPLY" or (now>req.deadline and "TIMEOUT" or "SOURCE_OR_FIGHT_CHANGED")); req=nil
    end
    if plan and now>plan.deadline then
        diagnose("PLAN_TIMEOUT",D.targetSyncRequest); plan.state.text="Some target details are still missing."
        D.targetSyncPlan=nil; D.targetSyncRequest=nil; plan=nil
    end
    if now<(D.targetSyncNextSend or 0) or table.getn(D.syncQueue or {})>0 then return end
    local out=D.targetSyncOut
    if out then
        if now>out.deadline or out.channel~=channel or not D.threatPeerUnit(out.dest,out.name) then
            diagnose(now>out.deadline and "REPLY_TIMEOUT" or "RECIPIENT_LEFT",out); D.targetSyncOut=nil; return
        end
        if send(out.packets[out.index],channel) then out.index=out.index+1 end
        D.targetSyncNextSend=now+0.10
        if out.index>table.getn(out.packets) then diagnose("REPLY_SENT",out); D.targetSyncOut=nil end
        return
    end
    plan=D.targetSyncPlan
    if not D.targetSyncRequest and plan and now>=(plan.nextRequest or 0) and now>=(D.targetSyncEarliestRequest or 0) then
        local job=plan.jobs[plan.index]
        if not validRequest(job) or not missing(job.context,job.key,job.kind) then finish("Available target details are up to date."); return end
        serial=serial+1; job.nonce=tostring(serial); job.channel=channel; job.deadline=now+40
        local start=startTime(job.context); local length=D.breakdownDuration(job.context)
        if not start then finish("This fight is no longer available."); return end
        local message=prefix("Q",selfGuid(),job.owner,job.nonce).."~"..job.kind.."~"..job.actor.guid.."~"..enemies(job.context)
            .."~"..math.floor((now-start)*10).."~"..math.floor(length*10)
        if string.len(message)<=240 and send(message,channel) then
            diagnose("REQUEST_SENT",job)
            D.targetSyncRequest=job; plan.state.text="Requesting missing details..."
            D.targetSyncEarliestRequest=now+5
        else finish("Target details unavailable; keeping existing data.","SEND_FAILED") end
        D.targetSyncNextSend=now+0.10
    end
end

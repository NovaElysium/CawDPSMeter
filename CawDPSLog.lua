-- Optional DPSLog input for the vanilla client. This API starts with subevent,
-- NOT the timestamp/hideCaster prefix used by other CLEU implementations.
local D=CAW_DPS_METER
D.dpsLogVersion="2"
D.dpsLogEvents=0
D.dpsLogRejected=0
local moduleCache,moduleCacheAt
local function moduleDiagnostics()
    local now=GetTime()
    if moduleCache and now-moduleCacheAt<1 then return moduleCache end
    local result={versionApiType=type(GetWeirdUtilsVersion),
        moduleTableType=type(WeirdUtils),getSpellInfoType=type(GetSpellInfo),
        castingApiType=type(UnitCastingInfo),channelApiType=type(UnitChannelInfo),
        logPathApiType=type(GetCombatLogPath),versions={}}
    local names={"dpslog","healtextfix","customassets","logsessions"}
    local i,name
    for i=1,table.getn(names) do
        name=names[i]
        if type(GetWeirdUtilsVersion)=="function" then
            local ok,value=pcall(GetWeirdUtilsVersion,name)
            if ok then
                result.versions[name]=type(value)=="string" and value or "not reported"
            else result.versions[name]="query failed" end
        elseif type(WeirdUtils)=="table" and type(WeirdUtils[name])=="string" then
            result.versions[name]=WeirdUtils[name]
        end
    end
    moduleCache=result; moduleCacheAt=now
    return result
end
local damage={SWING_DAMAGE=1,SPELL_DAMAGE=4,SPELL_PERIODIC_DAMAGE=4,
    RANGE_DAMAGE=4,DAMAGE_SHIELD=4,DAMAGE_SPLIT=4}
local healing={SPELL_HEAL=true,SPELL_PERIODIC_HEAL=true}
local power={SPELL_ENERGIZE=true,SPELL_PERIODIC_ENERGIZE=true,
    SPELL_DRAIN=true,SPELL_PERIODIC_DRAIN=true,SPELL_LEECH=true,SPELL_PERIODIC_LEECH=true}
local function guid(value)
    return type(value)=="string" and string.find(value,"^0x[%x]+$")
        and not string.find(value,"^0x0+$")
end
local function number(value)
    return type(value)=="number" and value==value and value>=0 and value<math.huge
end
local function truth(value) return value==true or value==1 or value=="1" end
function D.dpsLogSaveStatus(session)
    local s=session or (D.threatCalEnabled and D.threatCalSession)
    if s then
        s.combatInput=D.dpsLogActive and "DPSLog+RAW-utility" or "RAW"
        s.dpsLogStatus={received=D.dpsLogEvents,rejected=D.dpsLogRejected,
            error=D.dpsLogLastError,fallback=D.dpsLogFallback,
            adapterVersion=D.dpsLogVersion,apiType=type(CombatLogGetCurrentEventInfo),
            initialApiType=D.dpsLogInitialApiType,probing=D.dpsLogProbing or false,
            registered=D.dpsLogRegistered or false,rawCommitted=D.dpsLogRawCommitted or false,
            initializationAttempts=D.dpsLogInitAttempts or 0,
            registrationError=D.dpsLogRegistrationError,
            modules=moduleDiagnostics()}
    end
end
local status=D.dpsLogSaveStatus
local function choose(active,reason)
    D.dpsLogProbing=false; D.dpsLogActive=active; D.dpsLogFallback=reason
    local queued=D.dpsLogQueue or {}; D.dpsLogQueue={}
    local i
    for i=1,table.getn(queued) do D.parseRawReplay(queued[i][1],queued[i][2]) end
    status()
end
function D.dpsLogRawGate(ev,text)
    -- A DLL may publish its Lua functions after addon loading. Recheck before
    -- handling the first amount, not only on a timer after it has been counted.
    if not D.dpsLogInitialized and not D.dpsLogRawCommitted
        and type(CombatLogGetCurrentEventInfo)=="function" then D.dpsLogInitialize() end
    if not D.dpsLogProbing then return false end
    if table.getn(D.dpsLogQueue)>=128 then choose(false,"probe queue limit"); return false end
    if not D.dpsLogProbeAt then D.dpsLogProbeAt=GetTime() end
    table.insert(D.dpsLogQueue,{ev,text})
    return true
end
local function reject(reason)
    D.dpsLogRejected=D.dpsLogRejected+1; D.dpsLogLastError=reason
    if D.dpsLogProbing then choose(false,reason) end
    status()
    if D.dpsLogRejected==1 and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Caw: DPSLog event rejected ("..reason.."). See /cawinput.")
    end
    return false
end
local function spellName(id,name)
    if type(name)=="string" and name~="" then return name end
    if type(GetSpellInfo)=="function" and type(id)=="number" then
        local ok,n=pcall(GetSpellInfo,id)
        if ok and type(n)=="string" and n~="" then return n end
    end
    return "Spell #"..tostring(id or "?")
end
function D.dpsLogReceive(sub,src,srcName,srcFlags,srcRaid,dst,dstName,dstFlags,dstRaid,
    a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12)
    if not D.dpsLogActive and not D.dpsLogProbing then return false end
    if type(src)=="string" and string.find(src,"^0x0+$") then src=nil end
    if type(dst)=="string" and string.find(dst,"^0x0+$") then dst=nil end
    if type(sub)~="string" or not string.find(sub,"^[A-Z_]+$")
        or (src~=nil and not guid(src)) or (dst~=nil and not guid(dst)) then
        return reject("unsupported header")
    end
    if D.dpsLogProbing then choose(true) end
    D.dpsLogEvents=D.dpsLogEvents+1
    status()
    local info=src and D.guidToActor[src]
    -- Membership comes from our roster or a proven summon chain, not just a
    -- friendly flag. Never pull unrelated nearby players into group totals.
    if sub=="SPELL_SUMMON" then
        if not info or not guid(dst) then return false end
        local owner=info.ownerKey or info.key
        local name=dstName or spellName(a1,a2)
        local summoned=D.guidToActor[dst] or {key=dst,guid=dst}
        summoned.name=name; summoned.ownerKey=owner; summoned.isPet=true
        summoned.classToken=nil
        summoned.isTotem=string.find(name,"Totem",1,true)~=nil
        D.guidToActor[dst]=summoned; D.summonActors[dst]=summoned; D.petOwner[dst]=owner
        if D.threatCalRecordEvent then D.threatCalRecordEvent({kind="summon",guid=src,
            target=dst,source=a2,spellId=a1,summonName=name,owner=owner,input="DPSLog"}) end
        return true
    end
    if not info then return false end
    if srcName and srcName~="" then info.name=srcName end
    local offset=damage[sub]
    if offset or healing[sub] then
        if not guid(dst) then return reject("missing amount target") end
        local amount,over,critical,spell,id
        if offset==1 then
            amount=a1; over=a2; critical=a7; spell="Melee"
        else
            amount=a4; over=a5; id=a1; spell=spellName(a1,a2)
            critical=healing[sub] and a7 or a10
        end
        if not number(amount) or (over~=nil and (type(over)~="number" or over~=over)) then
            return reject("invalid amount suffix")
        end
        local effective=amount
        if healing[sub] then effective=math.max(0,amount-math.max(0,over or 0)) end
        -- Enrich existing bounded calibration events, not a second raw recorder.
        D.dpsLogCurrent={subevent=sub,sourceGuid=src,destGuid=dst,spellId=id,
            amount=amount,overAmount=over,sourceFlags=srcFlags,destFlags=dstFlags,
            sourceRaidFlags=srcRaid,destRaidFlags=dstRaid,spellSchool=offset==1 and nil or a3,
            critical=truth(critical)}
        if healing[sub] then D.dpsLogCurrent.absorbed=a6
        elseif offset==1 then
            D.dpsLogCurrent.resisted=a4; D.dpsLogCurrent.blocked=a5; D.dpsLogCurrent.absorbed=a6
            D.dpsLogCurrent.glancing=truth(a8); D.dpsLogCurrent.crushing=truth(a9)
        else
            D.dpsLogCurrent.resisted=a7; D.dpsLogCurrent.blocked=a8; D.dpsLogCurrent.absorbed=a9
            D.dpsLogCurrent.glancing=truth(a11); D.dpsLogCurrent.crushing=truth(a12)
        end
        local ok,result=pcall(D.acceptStructuredAmount,healing[sub] and "healing" or "damage",
            info,dst,dstName,spell,effective,truth(critical),id)
        D.dpsLogCurrent=nil; D.threatEventTarget=nil
        if not ok then return reject("amount handler: "..tostring(result)) end
        return result
    end
    if power[sub] and guid(dst) and number(a4) then
        if D.threatCalRecordEvent then D.threatCalRecordEvent({kind="power-observation",guid=src,
            target=dst,source=a2,spellId=a1,amount=a4,powerType=a5,extraAmount=a6,
            subevent=sub,input="DPSLog"}) end
        return true -- Observation only: no invented mana/grounding threat formula.
    end
    if sub=="SPELL_INTERRUPT" and guid(dst) and D.recordInterrupt then
        return D.recordInterrupt(info,spellName(a1,a2),dst,spellName(a4,a5))
    end
    return false -- Remaining utility/casts/deaths retain the existing RAW path.
end
local f=CreateFrame("Frame")
D.dpsLogFrame=f
function D.dpsLogInitialize()
    -- Probe event delivery before selecting the producer. Queue the first RAW
    -- lines briefly so event ordering cannot duplicate the first attack. Once
    -- selected, the producer is stable until reload, including late CLEU events.
    if D.dpsLogInitialized then status(); return end
    D.dpsLogInitAttempts=(D.dpsLogInitAttempts or 0)+1
    D.dpsLogInitialApiType=D.dpsLogInitialApiType or type(CombatLogGetCurrentEventInfo)
    D.dpsLogActive=false
    D.dpsLogQueue={}; D.dpsLogProbeAt=nil; D.dpsLogProbing=false
    if type(CombatLogGetCurrentEventInfo)~="function" then
        D.dpsLogFallback="CombatLogGetCurrentEventInfo unavailable; waiting for API"
        status(); return -- Missing at load is not a permanent initialization.
    end
    if D.dpsLogRawCommitted then
        D.dpsLogFallback="API appeared after RAW amounts; reload required to avoid double counting"
        status(); return
    end
    local ok,err=pcall(f.RegisterEvent,f,"COMBAT_LOG_EVENT_UNFILTERED")
    D.dpsLogRegistered=ok; D.dpsLogProbing=ok
    if ok then
        D.dpsLogInitialized=true; D.dpsLogFallback=nil; D.dpsLogRegistrationError=nil
    else
        D.dpsLogFallback="COMBAT_LOG_EVENT_UNFILTERED registration failed"
        D.dpsLogRegistrationError=tostring(err)
    end
    status()
end
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent",function()
    if event=="PLAYER_ENTERING_WORLD" then D.dpsLogInitialize()
    elseif event=="COMBAT_LOG_EVENT_UNFILTERED" and (D.dpsLogActive or D.dpsLogProbing) then
        local ok,err=pcall(function() D.dpsLogReceive(CombatLogGetCurrentEventInfo()) end)
        if not ok then reject("event API: "..tostring(err)) end
    end
end)
f:SetScript("OnUpdate",function()
    if D.dpsLogProbing and D.dpsLogProbeAt and GetTime()-D.dpsLogProbeAt>=0.5 then
        choose(false,"no structured event during RAW probe")
    end
    if GetTime()>=(D.dpsLogNextCheck or 0) then
        D.dpsLogNextCheck=GetTime()+1
        if not D.dpsLogInitialized then D.dpsLogInitialize() else status() end
    end
end)
-- Initial attempt plus world-entry/timer/first-RAW retries for late Lua APIs.
D.dpsLogInitialize()
SLASH_CAWINPUT1="/cawinput"
SlashCmdList.CAWINPUT=function()
    DEFAULT_CHAT_FRAME:AddMessage("Caw input: "..(D.dpsLogProbing and "waiting for DPSLog event" or (D.dpsLogActive and "DPSLog damage/healing + RAW utility" or "SuperWoW RAW"))
        .." | Events: "..D.dpsLogEvents.." | Rejected: "..D.dpsLogRejected)
    if D.dpsLogLastError then DEFAULT_CHAT_FRAME:AddMessage(D.dpsLogLastError) end
    if D.dpsLogFallback then DEFAULT_CHAT_FRAME:AddMessage(D.dpsLogFallback) end
    if type(GetCombatLogPath)=="function" then
        local ok,path=pcall(GetCombatLogPath)
        if ok and path then DEFAULT_CHAT_FRAME:AddMessage("LogSessions reports: "..tostring(path)) end
    end
end

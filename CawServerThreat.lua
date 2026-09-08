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

-- Character-wide alerts read existing server snapshots; they never request data.
D.threatAlertDefaults={glow=false,sound=false,threshold=90,cooldown=8}
D.threatAlertRanges={threshold={50,100},cooldown={2,30}}
function D.threatAlertSettings()
    CawDPSMeterCharDB=CawDPSMeterCharDB or {}
    local c=CawDPSMeterCharDB.threatAlerts
    if type(c)~="table" then c={}; CawDPSMeterCharDB.threatAlerts=c end
    for key,default in pairs(D.threatAlertDefaults) do
        if type(default)=="boolean" then
            if type(c[key])~="boolean" then c[key]=default end
        else
            local n=tonumber(c[key]); local range=D.threatAlertRanges[key]
            if not n or n~=n then n=default end
            c[key]=math.max(range[1],math.min(range[2],n))
        end
    end
    return c
end
function D.threatAlertStop()
    if D.threatAlertFrame then D.threatAlertFrame:Hide() end
end
function D.threatAlertPulse(glow,sound)
    if sound and PlaySoundFile then
        pcall(PlaySoundFile,"Interface\\AddOns\\CawDPSMeter\\Media\\CawWarning.wav")
    end
    if not glow then return end
    local f=D.threatAlertFrame
    if not f then
        f=CreateFrame("Frame",nil,UIParent); D.threatAlertFrame=f
        f:SetAllPoints(UIParent); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(false)
        -- Transparent strips make a soft edge without copying another addon's art.
        for i=0,11 do
            local inset=i*6; local alpha=0.40*(1-i/12)
            for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
                local t=f:CreateTexture(nil,"OVERLAY")
                t:SetTexture("Interface\\Buttons\\WHITE8X8"); t:SetVertexColor(1,0.10,0.03,alpha)
                if edge=="TOP" then
                    t:SetHeight(6); t:SetPoint("TOPLEFT",f,"TOPLEFT",0,-inset); t:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,-inset)
                elseif edge=="BOTTOM" then
                    t:SetHeight(6); t:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,inset); t:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,inset)
                elseif edge=="LEFT" then
                    t:SetWidth(6); t:SetPoint("TOPLEFT",f,"TOPLEFT",inset,0); t:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",inset,0)
                else
                    t:SetWidth(6); t:SetPoint("TOPRIGHT",f,"TOPRIGHT",-inset,0); t:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-inset,0)
                end
            end
        end
        f:SetScript("OnUpdate",function()
            local age=GetTime()-this.startedAt
            if age>=2 or age<0 then this:Hide() else this:SetAlpha(1-age/2) end
        end)
    end
    f.startedAt=GetTime(); f:SetAlpha(1); f:Show()
end
function D.threatAlertTest()
    local c=D.threatAlertSettings()
    D.threatAlertPreviewUntil=GetTime()+2
    D.threatAlertPulse(c.glow,c.sound)
end
function D.threatAlertOwnRow(snapshot)
    local _,guid=UnitExists("player"); local name=UnitName("player")
    local exact,match=nil,nil; local exactCount,nameCount=0,0
    for _,a in pairs(snapshot.actors or {}) do
        if guid and a.guid==guid and not a.isPet then exact=a; exactCount=exactCount+1 end
        if name and a.name==name then
            nameCount=nameCount+1
            if not a.isPet and (not a.guid or a.guid==guid) then match=a end
        end
    end
    if exactCount==1 then return exact end
    if exactCount==0 and nameCount==1 then return match end
end
function D.threatAlertTick()
    if not D.savedVariablesReady then return end
    local now=GetTime()
    if now<(D.threatAlertNext or 0) then return end
    D.threatAlertNext=now+0.10
    local c=D.threatAlertSettings()
    if not c.glow and not c.sound then
        D.threatAlertEpisode=nil; D.threatAlertPreviewUntil=nil; D.threatAlertStop(); return
    end
    if not c.glow then D.threatAlertStop() end
    if now<(D.threatAlertPreviewUntil or 0) then return end
    local dead=(UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) or (UnitIsDead and UnitIsDead("player"))
    local combat=D.inCombat
    if UnitAffectingCombat then combat=UnitAffectingCombat("player") end
    if dead or not combat or not D.threatCalApiEligible() then
        D.threatAlertEpisode=nil; D.threatAlertStop(); return
    end
    local snapshot=D.serverThreatCurrent()
    local own=snapshot and D.threatAlertOwnRow(snapshot)
    local pct=own and tonumber(own._serverThreatPercent)
    local value=own and tonumber(own._serverThreatValue)
    if not snapshot or not pct or pct~=pct or pct<0 or pct>1e9 or not value or value~=value or value<0 or value>1e30 then
        -- A missing/stale reply must not re-arm the same high-threat episode.
        D.threatAlertStop(); return
    end
    if value==0 then D.threatAlertEpisode=nil; D.threatAlertStop(); return end
    local episode=D.threatAlertEpisode
    if not episode or episode.guid~=snapshot.guid or episode.generation~=snapshot.generation or episode.serial~=snapshot.segmentSerial then
        episode={guid=snapshot.guid,generation=snapshot.generation,serial=snapshot.segmentSerial,level=0}
        D.threatAlertEpisode=episode
    end
    local level=0
    if own._serverTank then level=2
    elseif pct>=c.threshold or (episode.level==1 and pct>c.threshold-5) then level=1 end
    local previous=episode.level; episode.level=level
    if level==0 then D.threatAlertStop(); return end
    if level<=previous then return end
    if D.threatAlertLastAt and now-D.threatAlertLastAt<c.cooldown then return end
    D.threatAlertLastAt=now
    D.threatAlertPulse(c.glow,c.sound)
end

-- Complete local talent rank layouts, independent of class-specific threat rules.
-- Each slot carries rank/maxRank; tab/slot identities are client-layout specific.
local D=CAW_DPS_METER
local digits="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
D.talentProfiles={}; D.talentIncoming={}

function D.readTalentLayout()
    if not GetNumTalentTabs or not GetNumTalents or not GetTalentInfo then return nil end
    local ok,n=pcall(GetNumTalentTabs)
    if not ok or type(n)~="number" or n<1 or n>8 or n~=math.floor(n) then return nil end
    local tabs={}; local tab,i
    for tab=1,n do
        local good,count=pcall(GetNumTalents,tab)
        if not good or type(count)~="number" or count<1 or count>64 or count~=math.floor(count) then return nil end
        local encoded=""
        for i=1,count do
            local success,name,icon,tier,column,rank,maxRank=pcall(GetTalentInfo,tab,i)
            if not success or not name or type(rank)~="number" or type(maxRank)~="number" or rank<0 or maxRank<1 or maxRank>35 or rank>maxRank or rank~=math.floor(rank) or maxRank~=math.floor(maxRank) then return nil end
            encoded=encoded..string.sub(digits,rank+1,rank+1)..string.sub(digits,maxRank+1,maxRank+1)
        end
        tabs[tab]=encoded
    end
    return tabs
end

function D.talentProfileFor(actor)
    local p=actor and D.talentProfiles[actor.guid]
    if p and GetTime()-p.time<=90 and D.threatPeerUnit(actor.guid,p.name) then return p end
    if actor then D.talentProfiles[actor.guid]=nil end
end

function D.talentSyncReceive(sender,p,channel)
    if channel~="PARTY" and channel~="RAID" then return end
    local guid=p[3]
    if p[2]~="1" or not guid or not D.threatPeerUnit(guid,sender) then return end
    local rev,tab,total=tonumber(p[4]),tonumber(p[5]),tonumber(p[6])
    if not rev or rev<0 or rev~=math.floor(rev) or not tab or not total then return end
    local current=D.talentProfiles[guid]; local pending=D.talentIncoming[guid]
    if current and rev<=current.revision then return end
    if pending and rev<pending.revision then return end
    if tab==0 and total==0 and p[7]=="-" then
        D.talentProfiles[guid]={name=sender,revision=rev,time=GetTime(),available=false,tabs={}}
        D.talentIncoming[guid]=nil
        return
    end
    local data=p[7]
    if total<1 or total>8 or tab<1 or tab>total or total~=math.floor(total) or tab~=math.floor(tab) or not data or string.len(data)<2 or string.len(data)>128 or math.mod(string.len(data),2)~=0 then return end
    local ranks={}; local i
    for i=1,string.len(data),2 do
        local rank=string.find(digits,string.sub(data,i,i),1,true)
        local maxRank=string.find(digits,string.sub(data,i+1,i+1),1,true)
        if not rank or not maxRank or maxRank<=1 or rank>maxRank then return end
        table.insert(ranks,{rank=rank-1,maxRank=maxRank-1})
    end
    if not pending or pending.revision~=rev then pending={name=sender,revision=rev,time=GetTime(),total=total,tabs={},codes={}}; D.talentIncoming[guid]=pending end
    if pending.total~=total then return end
    pending.tabs[tab]=ranks
    pending.codes[tab]=data
    for i=1,total do if not pending.tabs[i] then return end end
    pending.signature=table.concat(pending.codes,"/"); pending.codes=nil
    pending.available=true; pending.time=GetTime()
    D.talentProfiles[guid]=pending; D.talentIncoming[guid]=nil
end

function D.talentSyncTick(send,channel)
    local now=GetTime()
    if now>=(D.talentNextRead or 0) then
        D.talentNextRead=now+1
        local guid,p
        for guid,p in D.talentProfiles do if not channel or now-p.time>90 or not D.threatPeerUnit(guid,p.name) then D.talentProfiles[guid]=nil end end
        for guid,p in D.talentIncoming do if not channel or now-p.time>10 or not D.threatPeerUnit(guid,p.name) then D.talentIncoming[guid]=nil end end
        if not channel then D.talentOut=nil; D.talentLastLayout=nil; D.talentLastChannel=nil; return end
        local exists,pg=UnitExists("player")
        if not exists or not pg then return end
        local tabs=D.readTalentLayout()
        local signature=tabs and table.concat(tabs,"/") or "unknown"
        if signature~=D.talentLastLayout or channel~=D.talentLastChannel or now-(D.talentLastCycle or 0)>=30 then
            local rev=math.floor(now*1000); local packets={}; local i
            if tabs then
                for i=1,table.getn(tabs) do packets[i]="K~1~"..pg.."~"..rev.."~"..i.."~"..table.getn(tabs).."~"..tabs[i] end
            else packets[1]="K~1~"..pg.."~"..rev.."~0~0~-" end
            D.talentOut={packets=packets,index=1,channel=channel}
            D.talentLastLayout=signature; D.talentLastChannel=channel; D.talentLastCycle=now
        end
    end
    local out=D.talentOut
    if not channel or not out or out.channel~=channel or now<(D.talentNextSend or 0) then return end
    D.talentNextSend=now+0.2
    if send(out.packets[out.index],channel) then
        out.index=out.index+1
        if out.index>table.getn(out.packets) then D.talentOut=nil end
    end
end

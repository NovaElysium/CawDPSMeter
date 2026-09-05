-- Small, automatic self-talent announcements over Caw Sync. Session-only state.
local D=CAW_DPS_METER
D.threatSyncTalents={}
D.threatSyncPeers={}

function D.threatPeerUnit(guid,name)
    local unit=D.threatDruidUnit({guid=guid})
    if unit and unit~="player" and UnitName(unit)==name then return unit end
end

function D.threatPeerReceive(sender,p,channel)
    if channel~="PARTY" and channel~="RAID" then return end
    if p[2]~="1" or not p[3] or not D.threatPeerUnit(p[3],sender) then return end
    if not p[4] or string.len(p[4])>40 or not string.find(p[4],"^[%w%.%-]+$") then return end
    if p[5]~="fi1" and p[5]~="none" then return end
    D.threatSyncPeers[p[3]]={name=sender,version=p[4],capability=p[5],talentLayouts=p[6]=="layout1",time=GetTime()}
    if p[5]=="none" then D.threatSyncTalents[p[3]]=nil end
end

function D.threatPeerStatus(actor)
    if not actor or actor.isPet then return "not-applicable","unknown" end
    local unit=D.threatDruidUnit(actor)
    if unit=="player" then return "local","local-api",D.threatModelVersion end
    local peer=D.threatSyncPeers[actor.guid]
    if not peer or not D.threatPeerUnit(actor.guid,peer.name) then return "not-detected","unknown" end
    if GetTime()-peer.time>45 then return "stale","unknown",peer.version end
    local rank=D.threatSyncedFeralInstinct(actor)
    if rank then return "detected","feral-instinct-current",peer.version end
    return "detected",peer.capability=="fi1" and "feral-instinct-unavailable" or "unsupported",peer.version
end

function D.threatPeerTick(send,channel)
    local now=GetTime()
    if now<(D.threatPeerNextCheck or 0) then return end
    D.threatPeerNextCheck=now+1
    local guid,peer
    for guid,peer in D.threatSyncPeers do
        if not channel or not D.threatPeerUnit(guid,peer.name) then D.threatSyncPeers[guid]=nil end
    end
    if not channel then D.threatPeerLastChannel=nil; return end
    if channel==D.threatPeerLastChannel and now-(D.threatPeerLastSent or 0)<15 then return end
    local exists,pg=UnitExists("player")
    if not exists or not pg then return end
    local _,class=UnitClass("player")
    local msg="P~1~"..pg.."~"..D.threatModelVersion.."~"..(class=="DRUID" and "fi1" or "none").."~layout1"
    if send(msg,channel) then D.threatPeerLastChannel=channel; D.threatPeerLastSent=now end
end

function D.threatSyncRosterUnit(guid,name)
    local unit=D.threatDruidUnit({guid=guid})
    if not unit or unit=="player" or UnitName(unit)~=name then return nil end
    local _,class=UnitClass(unit)
    if class=="DRUID" then return unit end
end

function D.threatSyncReceive(sender,p,channel)
    if channel~="PARTY" and channel~="RAID" then return end
    if p[2]~="1" or not p[3] or not D.threatSyncRosterUnit(p[3],sender) then return end
    if p[4]=="unknown" then
        D.threatSyncTalents[p[3]]=nil
        local peer=D.threatSyncPeers[p[3]]
        D.threatSyncPeers[p[3]]={name=sender,version=peer and peer.version,talentLayouts=peer and peer.talentLayouts,capability="fi1",time=GetTime()}
        return
    end
    local rank,maxRank=tonumber(p[4]),tonumber(p[5])
    if not rank or (maxRank~=3 and maxRank~=5) or rank<0 or rank>maxRank or rank~=math.floor(rank) then return end
    D.threatSyncTalents[p[3]]={name=sender,rank=rank,maxRank=maxRank,time=GetTime()}
    local peer=D.threatSyncPeers[p[3]]
    D.threatSyncPeers[p[3]]={name=sender,version=peer and peer.version,talentLayouts=peer and peer.talentLayouts,capability="fi1",time=GetTime()}
end

function D.threatSyncedFeralInstinct(actor)
    if not actor or actor.classToken~="DRUID" then return nil end
    local entry=D.threatSyncTalents[actor.guid]
    if not entry then return nil end
    if GetTime()-entry.time>45 or not D.threatSyncRosterUnit(actor.guid,entry.name) then
        D.threatSyncTalents[actor.guid]=nil
        return nil
    end
    return entry.rank,entry.maxRank
end

function D.threatSyncTick(send,channel)
    local now=GetTime()
    if now<(D.threatSyncNextCheck or 0) then return end
    D.threatSyncNextCheck=now+1
    local guid,entry
    for guid,entry in D.threatSyncTalents do
        if not channel or now-entry.time>45 or not D.threatSyncRosterUnit(guid,entry.name) then D.threatSyncTalents[guid]=nil end
    end
    if not channel then D.threatSyncLastMessage=nil; D.threatSyncLastChannel=nil; return end
    local _,class=UnitClass("player")
    if class~="DRUID" then return end
    local exists,pg=UnitExists("player")
    if not exists or not pg then return end
    local rank,maxRank=D.threatLocalFeralInstinct()
    local msg="T~1~"..pg.."~"..(rank and tostring(rank) or "unknown").."~"..tostring(maxRank or 0)
    if msg~=D.threatSyncLastMessage or channel~=D.threatSyncLastChannel or now-(D.threatSyncLastSent or 0)>=15 then
        if send(msg,channel) then
            D.threatSyncLastMessage=msg; D.threatSyncLastChannel=channel; D.threatSyncLastSent=now
        end
    end
end

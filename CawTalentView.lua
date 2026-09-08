-- Read-only talent trees. Metadata comes from the owning client, never a
-- guessed class template. Requests are made only while opening/refreshing a view.
local D=CAW_DPS_METER
local function integer(v,lo,hi)
    v=tonumber(v); if v and v==math.floor(v) and v>=lo and v<=hi then return v end
end
local function clean(s,n)
    if type(s)~="string" then return "" end
    s=string.gsub(s,"[%c~|]"," "); return string.sub(s,1,n)
end
local function iconName(icon)
    if type(icon)~="string" then return "INV_Misc_QuestionMark" end
    icon=string.gsub(icon,"^.*[\\/]","")
    if string.len(icon)>64 or not string.find(icon,"^[%w_]+$") then return "INV_Misc_QuestionMark" end
    return icon
end
function D.readTalentTrees()
    if not GetNumTalentTabs or not GetTalentTabInfo or not GetNumTalents or not GetTalentInfo then return nil end
    local ok,count=pcall(GetNumTalentTabs); count=ok and integer(count,1,8)
    if not count then return nil end
    local tabs={}
    for tab=1,count do
        local good,name=pcall(GetTalentTabInfo,tab)
        local valid,n=pcall(GetNumTalents,tab); n=valid and integer(n,1,64)
        if not good or type(name)~="string" or not n then return nil end
        local tree={name=clean(name,60),nodes={}}; tabs[tab]=tree
        local positions={}
        for i=1,n do
            local success,label,icon,tier,col,rank,maxRank=pcall(GetTalentInfo,tab,i)
            tier=integer(tier,1,12); col=integer(col,1,4); rank=integer(rank,0,35); maxRank=integer(maxRank,1,35)
            if not success or type(label)~="string" or not tier or not col or not rank or not maxRank or rank>maxRank then return nil end
            local pos=tier*10+col; if positions[pos] then return nil end; positions[pos]=true
            tree.nodes[i]={name=clean(label,70),icon=iconName(icon),tier=tier,column=col,rank=rank,maxRank=maxRank}
        end
    end
    return tabs
end
function D.requestTalentTrees(actor,force)
    if not actor or actor.isPet or not actor.guid then return end
    local _,self=UnitExists("player"); if actor.guid==self then return end
    local peer=D.talentProfileFor(actor)
    if not peer or not peer.available then return end
    local now=GetTime(); local pending=D.talentViewRequest; local cache=D.talentViewCache
    if pending and pending.guid==actor.guid and now-pending.time<60 then return end
    if not force and cache and cache.guid==actor.guid and now-cache.time<60 then return end
    if now<(D.talentViewNextRequest or 0) then return end
    D.talentViewNextRequest=now+2
    D.talentViewRequest={guid=actor.guid,name=peer.name,nonce=tostring(math.floor(now*1000)),time=now}
end
function D.talentViewReceive(sender,p,channel)
    if (channel~="PARTY" and channel~="RAID") or p[2]~="1" then return end
    local _,self=UnitExists("player"); local now=GetTime()
    if p[3]=="Q" then
        if p[4]~=self or not D.threatPeerUnit(p[5],sender) or not integer(p[6],0,999999999999) then return end
        if D.talentViewOut or now<(D.talentViewNextReply or 0) then return end
        local tabs=D.readTalentTrees(); if not tabs then return end
        local prefix="V~1~"; local address="~"..self.."~"..p[5].."~"..p[6]
        local packets={prefix.."B"..address.."~"..table.getn(tabs)}
        for tab,tree in ipairs(tabs) do
            table.insert(packets,prefix.."T"..address.."~"..tab.."~"..table.getn(tree.nodes).."~"..tree.name)
            for i,node in ipairs(tree.nodes) do
                table.insert(packets,prefix.."N"..address.."~"..tab.."~"..i.."~"..node.tier.."~"..node.column.."~"..node.rank.."~"..node.maxRank.."~"..node.name.."~"..node.icon)
            end
        end
        table.insert(packets,prefix.."E"..address)
        for _,packet in ipairs(packets) do if string.len(packet)>240 then return end end
        D.talentViewOut={packets=packets,index=1,channel=channel,guid=p[5],name=sender,time=now}
        D.talentViewNextReply=now+10
        return
    end
    local req=D.talentViewRequest
    if not req or now-req.time>60 or p[4]~=req.guid or p[5]~=self or p[6]~=req.nonce or not D.threatPeerUnit(p[4],sender) then return end
    if p[3]=="B" then
        local count=integer(p[7],1,8)
        if count then req.tabs={}; req.count=count end
    elseif p[3]=="T" and req.tabs then
        local tab=integer(p[7],1,req.count); local count=integer(p[8],1,64)
        if tab and count and p[9] and string.len(p[9])<=60 then req.tabs[tab]={name=clean(p[9],60),count=count,nodes={}} end
    elseif p[3]=="N" and req.tabs then
        local tab=integer(p[7],1,req.count); local tree=tab and req.tabs[tab]
        local i=tree and integer(p[8],1,tree.count)
        local tier,col,rank,maxRank=integer(p[9],1,12),integer(p[10],1,4),integer(p[11],0,35),integer(p[12],1,35)
        if not i or not tier or not col or not rank or not maxRank or rank>maxRank or not p[13] or string.len(p[13])>70 or not p[14] or iconName(p[14])~=p[14] then return end
        tree.nodes[i]={name=clean(p[13],70),icon=p[14],tier=tier,column=col,rank=rank,maxRank=maxRank}
    elseif p[3]=="E" and req.tabs then
        for tab=1,req.count do
            local tree=req.tabs[tab]; if not tree then return end
            local positions={}
            for i=1,tree.count do
                local node=tree.nodes[i]; if not node then return end
                local pos=node.tier*10+node.column; if positions[pos] then return end; positions[pos]=true
            end
        end
        D.talentViewCache={guid=req.guid,time=now,tabs=req.tabs}; D.talentViewRequest=nil
    end
end
function D.talentViewTick(send,channel)
    local now=GetTime(); local req=D.talentViewRequest; local out=D.talentViewOut
    if not channel then D.talentViewRequest=nil; D.talentViewOut=nil; return end
    if req then
        if now-req.time>(req.tabs and 60 or 15) or not D.threatPeerUnit(req.guid,req.name) then D.talentViewRequest=nil
        elseif not req.sent then
            local _,self=UnitExists("player")
            if self and send("V~1~Q~"..req.guid.."~"..self.."~"..req.nonce,channel) then req.sent=true end
        end
    end
    if not out then return end
    if out.channel~=channel or now-out.time>60 or not D.threatPeerUnit(out.guid,out.name) then D.talentViewOut=nil; return end
    if now<(D.talentViewNextSend or 0) then return end
    D.talentViewNextSend=now+0.1
    if send(out.packets[out.index],channel) then
        out.index=out.index+1; if out.index>table.getn(out.packets) then D.talentViewOut=nil end
    end
end
local function dataFor(actor)
    if not actor or actor.isPet then return nil,"Talent trees are available for players." end
    local _,self=UnitExists("player")
    if self and actor.guid==self then
        local now=GetTime()
        if not D.localTalentTreeAt or now-D.localTalentTreeAt>=1 then D.localTalentTrees=D.readTalentTrees(); D.localTalentTreeAt=now end
        local tabs=D.localTalentTrees
        return tabs,tabs and "Current talents from your client." or "Talent information is unavailable on this client."
    end
    local cache=D.talentViewCache; local ranks=D.talentProfileFor(actor)
    if cache and cache.guid==actor.guid then
        -- The regular, small rank packets keep a received tree current. Require
        -- identical slot counts and maximum ranks before pairing the two layouts.
        local match=ranks and ranks.available and ranks.time>=cache.time and table.getn(ranks.tabs)==table.getn(cache.tabs)
        if match then
            for t,tree in ipairs(cache.tabs) do
                if table.getn(tree.nodes)~=table.getn(ranks.tabs[t]) then match=false; break end
                for i,node in ipairs(tree.nodes) do if node.maxRank~=ranks.tabs[t][i].maxRank then match=false; break end end
            end
        end
        if match then
            for t,tree in ipairs(cache.tabs) do for i,node in ipairs(tree.nodes) do node.rank=ranks.tabs[t][i].rank end end
            return cache.tabs,"Current synced talents. Not a snapshot of the selected fight."
        end
        return cache.tabs,"Last received talents. Use Refresh for a new snapshot."
    end
    local req=D.talentViewRequest
    if req and req.guid==actor.guid and GetTime()-req.time<15 then return nil,"Requesting talent trees from "..req.name.."..." end
    if ranks and ranks.available then
        local totals={}; for t,tree in ipairs(ranks.tabs) do local n=0; for _,node in ipairs(tree) do n=n+node.rank end; totals[t]=tostring(n) end
        return nil,"Points received: "..table.concat(totals," / ")..".\nTree details need a Caw version with talent viewing on both clients."
    end
    return nil,"No current talent data. The player must be in your group with Caw talent sync available."
end
function D.createTalentPane(p)
    p.talentButton=D.uiButton(p,"Talents",696,-55,112,function()
        p.showTalents=not p.showTalents; p.talentPage=0
        if p.showTalents then D.requestTalentTrees(p.selectedActor) end
        D.refreshBreakdown()
    end)
    local f=CreateFrame("Frame",nil,p); p.talentPane=f
    f:SetPoint("TOPLEFT",p,"TOPLEFT",215,-96); f:SetWidth(738); f:SetHeight(462)
    f:SetFrameLevel(p:GetFrameLevel()+12); f:EnableMouse(true); D.uiPanel(f); f:SetBackdropColor(0.065,0.07,0.08,1)
    f.message=D.uiText(f,"",20,-120,698,14); f.message:SetHeight(100)
    f.status=D.uiText(f,"",12,-428,595,11); f.status:SetHeight(29)
    f.refresh=D.uiButton(f,"Refresh",631,-430,95,function()
        D.localTalentTreeAt=nil; D.requestTalentTrees(p.selectedActor,true); D.refreshBreakdown()
    end)
    f.previous=D.uiButton(f,"<",12,-7,24,function() p.talentPage=math.max(0,(p.talentPage or 0)-1); D.refreshBreakdown() end)
    f.next=D.uiButton(f,">",702,-7,24,function() p.talentPage=(p.talentPage or 0)+1; D.refreshBreakdown() end)
    f.caption=D.uiText(f,"Current talents",46,-12,645,12)
    f.trees={}
    for t=1,3 do
        local tree=CreateFrame("Frame",nil,f); tree:SetWidth(234); tree:SetHeight(378)
        tree:SetPoint("TOPLEFT",f,"TOPLEFT",9+(t-1)*243,-41); D.uiPanel(tree); tree:SetBackdropColor(0.045,0.05,0.06,1)
        tree.title=D.uiText(tree,"",10,-9,214,13); tree.title:SetJustifyH("CENTER")
        tree.pointText=D.uiText(tree,"",10,-29,214,11); tree.pointText:SetJustifyH("CENTER"); tree.nodes={}; f.trees[t]=tree
    end
    f:Hide()
end
function D.refreshTalentPane(p,actor)
    p.selectedActor=actor
    if not p.showTalents then p.talentPane:Hide(); p.searchBox:Show(); p.talentButton.text:SetText("Talents"); return end
    p.talentPane:Show(); p.searchBox:Hide(); p.talentButton.text:SetText("Spells")
    local tabs,status=dataFor(actor); local f=p.talentPane
    f.status:SetText(tabs and status or "Current talents; independent of the selected fight.")
    f.message:SetText(not tabs and (status or "Talent information is unavailable on this client.") or "")
    local count=tabs and table.getn(tabs) or 0; local pages=math.max(1,math.ceil(count/3))
    p.talentPage=math.max(0,math.min(p.talentPage or 0,pages-1))
    D.uiEnableButton(f.previous,p.talentPage>0); D.uiEnableButton(f.next,p.talentPage<pages-1)
    if pages>1 then f.previous:Show(); f.next:Show() else f.previous:Hide(); f.next:Hide() end
    local req=D.talentViewRequest
    D.uiEnableButton(f.refresh,not (req and actor and req.guid==actor.guid and GetTime()-req.time<60))
    for t,tree in ipairs(f.trees) do
        local data=tabs and tabs[t+p.talentPage*3]
        if data then
            tree:Show(); tree.title:SetText(data.name)
            local points,maxTier=0,7
            for _,node in ipairs(data.nodes) do points=points+node.rank; maxTier=math.max(maxTier,node.tier) end
            tree.pointText:SetText(points.." points")
            local step=math.min(46,310/maxTier); local size=math.min(32,step-4)
            for i,node in ipairs(data.nodes) do
                local b=tree.nodes[i]
                if not b then
                    b=CreateFrame("Button",nil,tree); D.uiPanel(b); tree.nodes[i]=b
                    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOPLEFT",b,"TOPLEFT",2,-2)
                    b.icon:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-2,2); b.icon:SetTexCoord(0.08,0.92,0.08,0.92)
                    b.rank=D.uiText(b,"",-4,-24,40,11); b.rank:SetJustifyH("RIGHT")
                    b.rank:SetShadowColor(0,0,0,1); b.rank:SetShadowOffset(1,-1)
                    b:SetScript("OnEnter",function()
                        local node=this.node; if not node then return end
                        local tt=D.getControlTooltip(); tt:SetOwner(this,"ANCHOR_RIGHT")
                        tt:SetText(node.name,1,1,1); tt:AddLine("Rank "..node.rank.." / "..node.maxRank,0.85,0.8,0.65); tt:Show()
                    end)
                    b:SetScript("OnLeave",function() if D.controlTooltip then D.controlTooltip:Hide() end end)
                end
                b.node=node; b:SetWidth(size); b:SetHeight(size); b:ClearAllPoints()
                b:SetPoint("TOPLEFT",tree,"TOPLEFT",22+(node.column-1)*50,-58-(node.tier-1)*step)
                b.icon:SetTexture("Interface\\Icons\\"..node.icon); b.icon:SetAlpha(node.rank>0 and 1 or 0.3)
                b.rank:ClearAllPoints(); b.rank:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",4,-3)
                b.rank:SetText(node.rank.."/"..node.maxRank); b.rank:SetTextColor(node.rank==node.maxRank and 1 or 0.65,0.86,0.5)
                b:SetBackdropBorderColor(node.rank>0 and 0.5 or 0.18,0.4,0.22,1); b:Show()
            end
            for i=table.getn(data.nodes)+1,table.getn(tree.nodes) do tree.nodes[i].node=nil; tree.nodes[i]:Hide() end
        else tree:Hide() end
    end
end

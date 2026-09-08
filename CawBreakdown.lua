-- Clickable actor analysis over existing meter data. No extra combat recording.
local D=CAW_DPS_METER
local modes={"damage","healing","damageTaken","threat","deaths","interrupts","cc","ccBreaks","dispels","buffs","debuffsCast","debuffsReceived"}
local labels={damage="Damage",healing="Healing",damageTaken="Damage taken",threat="Threat",deaths="Deaths",
    interrupts="Interrupts",cc="Crowd control",ccBreaks="CC breaks",dispels="Dispels",buffs="Buffs",debuffsCast="Debuffs cast",debuffsReceived="Debuffs received"}
local aura={buffs=true,debuffsCast=true,debuffsReceived=true}
local function actorId(a,k) return a.guid or (a._serverThreatValue and ("name:"..a.name)) or a.key or k end
function D.breakdownContext(v)
    local segment=v and v.segment or D.segment
    local index=v and v.segmentIndex or D.segmentIndex
    return {segment=segment,history=segment=="history" and D.fightHistory[index or 1] or nil,
        mode=v and v.mode or D.mode,serial=D.segmentSerial}
end
function D.breakdownActors(context)
    if context.segment=="history" then return context.history and context.history.actors or {} end
    if context.segment=="overall" then return D.overallSegment.actors end
    if context.serial~=D.segmentSerial then return {} end
    if context.mode=="threat" and D.serverThreatActors then return D.serverThreatActors() end
    return D.actors
end
function D.breakdownDuration(context)
    if context.segment=="history" then return context.history and context.history.duration or 0 end
    if context.segment=="overall" then return D.overallSegment.duration or 0 end
    return D.uiDuration()
end
function D.breakdownEntries(context,key)
    local actors=D.breakdownActors(context); local actor=actors[key]
    if not actor then for k,a in pairs(actors) do if actorId(a,k)==key then actor=a; break end end end
    local rows={}; local total=0; local mode=context.mode
    if not actor then return rows,total,nil end
    local function add(a)
        local field=mode=="damage" and "spells" or (mode=="healing" and "healSpells" or (mode=="damageTaken" and "damageTakenSpells" or (mode=="deaths" and "deathCauses" or mode)))
        if mode=="threat" then
            if a._serverThreatValue~=nil then
                rows[1]={id="server",name=a._serverTarget or "Current target",value=a._serverThreatValue,source=a.name,localValue=a._serverLocalValue}
                total=a._serverThreatValue
            else
                for guid,value in pairs(a.threat or {}) do
                    table.insert(rows,{id=guid,name=(D.currentEnemyNames and D.currentEnemyNames[guid]) or guid,value=value,source=a.name})
                    total=total+value
                end
            end
            return
        end
        for name,s in pairs(a[field] or {}) do
            if type(s)~="table" then s={count=tonumber(s)} end
            local value
            if aura[mode] then value=D.uiAuraDuration(s)
            elseif mode=="damage" or mode=="damageTaken" then value=s.damage
            elseif mode=="healing" then value=s.healing
            else value=type(s)=="table" and s.count or tonumber(s) end
            if value then
                local row={id=tostring(a.key)..":"..name,name=name,value=value,source=a.name,isPet=a.isPet,
                    hits=s.hits,crits=s.crits,count=s.count}
                if mode=="damageTaken" then row.critDamage=s.critDamage; row.maxCrit=s.maxCrit end
                if aura[mode] then row.sources=D.auraSourceText and D.auraSourceText(s) end
                table.insert(rows,row); total=total+value
            end
        end
    end
    add(actor)
    if (mode=="damage" or mode=="healing") and not actor.isPet then
        for _,a in pairs(actors) do if a.isPet and a.ownerKey==actor.key then add(a) end end
    end
    -- Synced cumulative totals may be more complete than the spell breakdown.
    if mode=="damage" or mode=="healing" or mode=="damageTaken" or mode=="deaths" then
        if type(actor[mode])=="number" then
            total=actor[mode]
            if (mode=="damage" or mode=="healing") and not actor.isPet then
                for _,a in pairs(actors) do if a.isPet and a.ownerKey==actor.key then total=total+(a[mode] or 0) end end
            end
        end
    end
    table.sort(rows,function(a,b) if a.value==b.value then return a.id<b.id end; return a.value>b.value end)
    return rows,total,actor
end
local function numeric(n,decimals)
    if n==nil then return "--" end
    return string.format(decimals and "%.1f" or "%.0f",n)
end
local function segmentLabel(c)
    if c.segment=="history" then return c.history and c.history.name or "Expired segment" end
    if c.segment=="overall" then return "Overall" end
    return "Current"
end
local function scroll(p,key,delta,count,visible)
    p[key]=math.max(0,math.min(math.max(0,count-visible),(p[key] or 0)+delta)); D.refreshBreakdown()
end
local function scrollState(up,down,offset,count,visible)
    D.uiEnableButton(up,offset>0); D.uiEnableButton(down,offset<math.max(0,count-visible))
end
local spellIcons={}
local function scanSpellIcons()
    if type(GetSpellName)~="function" or type(GetSpellTexture)~="function" then return end
    for _,book in ipairs({"spell","pet"}) do
        for i=1,1024 do
            local ok,name=pcall(GetSpellName,i,book)
            if not ok or not name then break end
            local success,icon=pcall(GetSpellTexture,i,book)
            if success and type(icon)=="string" then spellIcons[name]=icon end
        end
    end
end
local function spellIcon(name)
    if name=="Melee" then return "Interface\\Icons\\INV_Sword_04" end
    if spellIcons[name] then return spellIcons[name] end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function valueText(n,timed)
    return timed and (numeric(n,true).."s") or D.uiNumber(n)
end
function D.refreshBreakdown()
    local p=D.breakdownPanel; if not p or not p.context then return end
    local c=p.context
    local rows,total,actor=D.breakdownEntries(c,p.actorKey)
    if p.selectedActor~=actor and p.showTalents then D.requestTalentTrees(actor) end
    D.refreshTalentPane(p,actor)
    local covered,largest=0,1
    for _,entry in ipairs(rows) do covered=covered+entry.value; largest=math.max(largest,entry.value) end
    if p.search and p.search~="" then
        local filtered={}
        for _,entry in ipairs(rows) do
            if string.find(string.lower(entry.name.." "..entry.source),p.search,1,true) then table.insert(filtered,entry) end
        end
        rows=filtered
    end
    if p.sort=="name" then table.sort(rows,function(a,b) return a.name<b.name end) end
    p.entries=rows; p.total=total
    local duration=D.breakdownDuration(c)
    local minutes=math.floor(duration/60); local seconds=math.floor(duration-minutes*60)
    p.contextText:SetText(segmentLabel(c).."  |  "..string.format("%d:%02d",minutes,seconds))
    p.modeButton.text:SetText(labels[c.mode] or c.mode)
    p.title:SetText((actor and actor.name or "Player details").." - "..(labels[c.mode] or c.mode))
    p.totalText:SetText("Total: "..valueText(total,aura[c.mode]))
    p.empty:SetText(not actor and "No data for this player."
        or (table.getn(rows)==0 and (p.search~="" and "No spells found." or "No spell data recorded.") or ""))
    p.foot:SetText(c.segment=="current" and c.serial~=D.segmentSerial and "This fight has ended. Select Current to view the new fight."
        or (c.mode=="threat" and "Server threat is available as a total for each target."
        or (math.abs(covered-total)>0.01 and "Some spell data is missing. The player's full total is shown above." or "")))
    p.spellOffset=math.max(0,math.min(p.spellOffset or 0,math.max(0,table.getn(rows)-14)))
    scrollState(p.spellUp,p.spellDown,p.spellOffset,table.getn(rows),14)
    local selected=nil
    for _,r in ipairs(rows) do if r.id==p.spellId then selected=r; break end end
    if not selected then selected=rows[1]; p.spellId=selected and selected.id end
    local cr,cg,cb=D.uiClassColor(actor)
    p.nameHeader.text:SetText(c.mode=="threat" and "Target" or "Spell")
    p.valueHeader.text:SetText(aura[c.mode] and "Uptime" or (c.mode=="damage" and "Damage" or (c.mode=="healing" and "Healing" or "Total")))
    for i=1,14 do
        local b=p.spells[i]; local row=rows[i+p.spellOffset]
        if row then
            b.row=row; b:Show()
            b.bar:SetMinMaxValues(0,largest); b.bar:SetValue(row.value)
            b.bar:SetStatusBarColor(cr,cg,cb,row==selected and 0.42 or 0.19)
            b.icon:SetTexture(spellIcon(row.name))
            b.nameText:SetText((row.isPet and (row.source..": ") or "")..row.name)
            b.value:SetText(valueText(row.value,aura[c.mode]))
            b.share:SetText(string.format("%.1f%%",total>0 and row.value/total*100 or 0))
            D.uiSelectButton(b,row==selected)
        else b.row=nil; b:Hide() end
    end
    p.spellTitle:SetText(selected and selected.name or "Select a spell")
    p.spellIcon:SetTexture(selected and spellIcon(selected.name) or "Interface\\Icons\\INV_Misc_QuestionMark")
    p.source:SetText(selected and selected.source or "")
    local vals={}; local names={}
    if selected then
        vals[1]=valueText(selected.value,aura[c.mode]); names[1]=aura[c.mode] and "Uptime" or "Total"
        vals[2]=numeric(total>0 and 100*selected.value/total or 0,true).."%"; names[2]="Contribution"
        if c.mode=="damage" or c.mode=="healing" or c.mode=="damageTaken" then
            vals[3]=numeric(selected.hits); names[3]=c.mode=="healing" and "Heals" or "Hits"
            vals[4]=numeric(selected.crits); names[4]="Critical hits"
            local rate=selected.hits and selected.hits>0 and selected.crits and 100*selected.crits/selected.hits or nil
            vals[5]=rate and (numeric(rate,true).."%") or "--"; names[5]="Crit rate"
            vals[6]=numeric(selected.hits and selected.hits>0 and selected.value/selected.hits or nil,true)
            names[6]=c.mode=="healing" and "Average heal" or "Average hit"
            if c.mode~="damageTaken" then
                vals[7]=numeric(duration>0 and selected.value/duration or nil,true); names[7]=c.mode=="healing" and "HPS" or "DPS"
            end
            if selected.critDamage then vals[9]=D.uiNumber(selected.critDamage); names[9]="Critical damage" end
        elseif c.mode=="threat" then
            if selected.localValue~=nil then vals[10]=D.uiNumber(selected.localValue); names[10]="Local estimate" end
        else
            vals[8]=numeric(selected.count); names[8]=aura[c.mode] and "Applications" or "Count"
        end
    end
    local y=-276
    for i=1,10 do
        local text=p.metrics[i]; local label=p.metricLabels[i]
        if names[i] then
            text:Show(); label:Show(); text:SetText(vals[i]); label:SetText(names[i])
            if i>2 then
                label:ClearAllPoints(); label:SetPoint("TOPLEFT",p,"TOPLEFT",696,y)
                text:ClearAllPoints(); text:SetPoint("TOPLEFT",p,"TOPLEFT",861,y); y=y-36
            end
        else text:Hide(); label:Hide() end
    end
    p.sourceExtra:SetText(selected and selected.sources or "")
    local players={}
    for k,a in pairs(D.breakdownActors(c)) do
        if not a.isPet or c.mode=="threat" then table.insert(players,{key=actorId(a,k),name=a.name or k,actor=a}) end
    end
    table.sort(players,function(a,b) return a.name<b.name end); p.playersData=players
    p.playerOffset=math.max(0,math.min(p.playerOffset or 0,math.max(0,table.getn(players)-7)))
    scrollState(p.playerUp,p.playerDown,p.playerOffset,table.getn(players),7)
    for i=1,7 do
        local b=p.players[i]; local a=players[p.playerOffset+i]
        if a then
            b.playerKey=a.key; b.text:SetText(a.name); b:Show(); D.uiSelectButton(b,a.key==p.actorKey)
            local r,g,blue=D.uiClassColor(a.actor); b.text:SetTextColor(r,g,blue)
            b.actor=a.actor; D.setBarActorIcon(b)
            if a.actor.classToken or a.actor.isPet then b.classIcon:Show() else b.classIcon:Hide() end
        else b:Hide() end
    end
    local segments={{segment="current",label="Current"},{segment="overall",label="Overall"}}
    for i,h in ipairs(D.fightHistory) do table.insert(segments,{segment="history",history=h,label=i..". "..(h.name or "Fight")}) end
    p.segmentsData=segments
    p.segmentOffset=math.max(0,math.min(p.segmentOffset or 0,math.max(0,table.getn(segments)-6)))
    scrollState(p.segmentUp,p.segmentDown,p.segmentOffset,table.getn(segments),6)
    for i=1,6 do
        local b=p.segments[i]; local entry=segments[p.segmentOffset+i]
        if entry then
            b.entry=entry; b.text:SetText(entry.label); b:Show()
            D.uiSelectButton(b,entry.segment==c.segment and (entry.segment~="history" or entry.history==c.history))
        else b:Hide() end
    end
end
function D.openBreakdown(actor,v)
    local p=D.breakdownPanel
    if not p then
        p=D.uiDialog("CawBreakdownPanel","Player details",970,586); D.breakdownPanel=p
        D.uiBlock(p,1,-96,205,462,0.075,0.08,0.09); D.uiBlock(p,206,-96,1,462,0.23,0.24,0.27)
        D.uiBlock(p,682,-96,271,462,0.12,0.125,0.14)
        D.uiBlock(p,1,-558,968,1,0.23,0.24,0.27)
        p.contextText=D.uiText(p,"",220,-61,238,13)
        p.searchBox=D.uiInput(p,470,-55,194)
        D.createTalentPane(p)
        p.searchHint=D.uiText(p.searchBox,"Search spells...",8,-5,175,12); p.searchHint:SetTextColor(0.49,0.50,0.53)
        p.searchBox:SetScript("OnEnterPressed",function() this:ClearFocus() end)
        p.searchBox:SetScript("OnTextChanged",function()
            p.search=string.lower(this:GetText() or ""); p.spellOffset=0
            if p.search=="" then p.searchHint:Show() else p.searchHint:Hide() end
            if p.context then D.refreshBreakdown() end
        end)
        p.modeButton=D.uiListButton(p,16,-55,178,function()
            if p.modeMenu:IsShown() then p.modeMenu:Hide() else p.modeMenu:Show() end
        end)
        D.uiText(p.modeButton,"v",159,-5,10,10)
        p.modeMenu=CreateFrame("Frame",nil,p); p.modeMenu:SetWidth(178); p.modeMenu:SetHeight(12*26+8)
        p.modeMenu:SetPoint("TOPLEFT",p.modeButton,"BOTTOMLEFT",0,-3); p.modeMenu:SetFrameLevel(120)
        p.modeMenu:EnableMouse(true); D.uiPanel(p.modeMenu); p.modeMenu:Hide()
        for i,mode in ipairs(modes) do
            local b=D.uiListButton(p.modeMenu,4,-4-(i-1)*26,170,function()
                p.context.mode=this.mode; p.spellOffset=0; p.spellId=nil; p.modeMenu:Hide(); D.refreshBreakdown()
            end)
            b.mode=mode; b.text:SetText(labels[mode])
        end
        D.uiText(p,"Players",16,-105,170,13):SetTextColor(0.78,0.71,0.54)
        D.uiText(p,"Segments",16,-325,170,13):SetTextColor(0.78,0.71,0.54)
        p.spells={}; p.players={}; p.segments={}; p.metrics={}; p.metricLabels={}
        for i=1,7 do
            local b=D.uiListButton(p,12,-131-(i-1)*26,185,function()
                p.actorKey=this.playerKey; p.spellId=nil; p.spellOffset=0; D.refreshBreakdown()
            end)
            b.classIcon=b:CreateTexture(nil,"OVERLAY"); b.classIcon:SetWidth(18); b.classIcon:SetHeight(18)
            b.classIcon:SetPoint("LEFT",b,"LEFT",5,0)
            b.text:ClearAllPoints(); b.text:SetPoint("LEFT",b,"LEFT",29,0); b.text:SetWidth(149)
            b:EnableMouseWheel(true); b:SetScript("OnMouseWheel",function() scroll(p,"playerOffset",arg1>0 and -1 or 1,table.getn(p.playersData),7) end)
            p.players[i]=b
        end
        p.playerUp=D.uiButton(p,"^",148,-100,22,function() scroll(p,"playerOffset",-1,table.getn(p.playersData),7) end)
        p.playerDown=D.uiButton(p,"v",175,-100,22,function() scroll(p,"playerOffset",1,table.getn(p.playersData),7) end)
        for i=1,6 do
            local b=D.uiListButton(p,12,-353-(i-1)*26,185,function()
                local e=this.entry; p.context={segment=e.segment,history=e.history,mode=p.context.mode,serial=D.segmentSerial}
                p.spellOffset=0; p.spellId=nil; D.refreshBreakdown()
            end)
            b:EnableMouseWheel(true); b:SetScript("OnMouseWheel",function() scroll(p,"segmentOffset",arg1>0 and -1 or 1,table.getn(p.segmentsData),6) end)
            p.segments[i]=b
        end
        p.segmentUp=D.uiButton(p,"^",148,-320,22,function() scroll(p,"segmentOffset",-1,table.getn(p.segmentsData),6) end)
        p.segmentDown=D.uiButton(p,"v",175,-320,22,function() scroll(p,"segmentOffset",1,table.getn(p.segmentsData),6) end)
        p.nameHeader=D.uiListButton(p,220,-106,263,function() p.sort="name"; D.refreshBreakdown() end)
        p.valueHeader=D.uiButton(p,"Damage",485,-106,95,function() p.sort="value"; D.refreshBreakdown() end)
        D.uiButton(p,"%",582,-106,82,function() p.sort="value"; D.refreshBreakdown() end)
        for i=1,14 do
            local b=D.uiButton(p,"",220,-140-(i-1)*27,444,function()
                if this.row then p.spellId=this.row.id; D.refreshBreakdown() end
            end)
            b:SetHeight(25)
            b.bar=CreateFrame("StatusBar",nil,b); b.bar:SetWidth(417); b.bar:SetHeight(23)
            b.bar:SetPoint("TOPLEFT",b,"TOPLEFT",26,-1); b.bar:SetFrameLevel(b:GetFrameLevel())
            b.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8"); b.bar:EnableMouse(false)
            b.icon=b:CreateTexture(nil,"OVERLAY"); b.icon:SetWidth(23); b.icon:SetHeight(23)
            b.icon:SetPoint("TOPLEFT",b,"TOPLEFT",1,-1); b.icon:SetTexCoord(0.08,0.92,0.08,0.92)
            b.nameText=D.uiText(b.bar,"",7,-4,225,12)
            b.value=D.uiText(b.bar,"",236,-4,91,12); b.value:SetJustifyH("RIGHT")
            b.share=D.uiText(b.bar,"",340,-4,70,12); b.share:SetJustifyH("RIGHT")
            b:EnableMouseWheel(true); b:SetScript("OnMouseWheel",function() scroll(p,"spellOffset",arg1>0 and -1 or 1,table.getn(p.entries),14) end)
            p.spells[i]=b
        end
        p.totalText=D.uiText(p,"",224,-535,340,13)
        p.spellUp=D.uiButton(p,"^",607,-529,25,function() scroll(p,"spellOffset",-1,table.getn(p.entries),14) end)
        p.spellDown=D.uiButton(p,"v",639,-529,25,function() scroll(p,"spellOffset",1,table.getn(p.entries),14) end)
        p.empty=D.uiText(p,"",238,-189,400,13); p.empty:SetHeight(40)
        p.spellIcon=p:CreateTexture(nil,"ARTWORK"); p.spellIcon:SetWidth(36); p.spellIcon:SetHeight(36)
        p.spellIcon:SetPoint("TOPLEFT",p,"TOPLEFT",696,-111); p.spellIcon:SetTexCoord(0.08,0.92,0.08,0.92)
        p.spellTitle=D.uiText(p,"",744,-110,193,16); p.spellTitle:SetHeight(44)
        p.source=D.uiText(p,"",696,-162,238,12); p.source:SetTextColor(0.62,0.63,0.65)
        for i=1,10 do
            p.metricLabels[i]=D.uiText(p,"",696,-276,162,12)
            p.metrics[i]=D.uiText(p,"",861,-276,76,12); p.metrics[i]:SetJustifyH("RIGHT")
        end
        for i=1,2 do
            local x=i==1 and 696 or 828
            p.metricLabels[i]:ClearAllPoints(); p.metricLabels[i]:SetPoint("TOPLEFT",p,"TOPLEFT",x,-195); p.metricLabels[i]:SetWidth(115)
            p.metricLabels[i]:SetTextColor(0.62,0.63,0.65)
            p.metrics[i]:ClearAllPoints(); p.metrics[i]:SetPoint("TOPLEFT",p,"TOPLEFT",x,-218)
            p.metrics[i]:SetFont(D.uiFont,23); p.metrics[i]:SetWidth(118); p.metrics[i]:SetHeight(29); p.metrics[i]:SetJustifyH("LEFT")
        end
        D.uiBlock(p,696,-258,243,1,0.26,0.265,0.29)
        p.sourceExtra=D.uiText(p,"",696,-493,240,11); p.sourceExtra:SetHeight(47)
        p.foot=D.uiText(p,"",18,-567,931,11); p.foot:SetTextColor(0.64,0.62,0.55)
        p:SetScript("OnUpdate",function()
            if GetTime()<(p.nextRefresh or 0) then return end
            p.nextRefresh=GetTime()+0.4; D.refreshBreakdown()
        end)
        p:SetScript("OnHide",function()
            p.modeMenu:Hide(); p.context=nil; p.entries={}; p.playersData={}; p.segmentsData={}
            p.showTalents=false; p.talentPane:Hide()
        end)
    end
    scanSpellIcons()
    p.context=D.breakdownContext(v); p.actorKey=actorId(actor); p.spellId=nil
    p.showTalents=false
    p.search=""; p.searchBox:SetText(""); p.searchHint:Show()
    p.playerOffset=0; p.segmentOffset=0; p.spellOffset=0; p.sort="value"
    D.refreshBreakdown(); p:Show()
end

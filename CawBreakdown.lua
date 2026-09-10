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
                    hits=s.hits,crits=s.crits,count=s.count,spellId=s.spellId}
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
local spellIcons=D.spellIconDatabase or {}
local spellIconFallbacks=D.spellIconFallbacks or {}
local spellIdFallbacks=D.spellIdFallbacks or {}
local spellIconCache={}
local questionIcon="Interface\\Icons\\INV_Misc_QuestionMark"
local function normalizeSpellIcon(icon)
    if type(icon)~="string" or icon=="" or icon=="Temp" then return nil end
    if string.sub(icon,1,10)=="Interface\\" then return icon end
    if string.find(icon,"\\",1,true) then return icon end
    return "Interface\\Icons\\"..icon
end
local function rememberSpellIcon(name,icon)
    icon=normalizeSpellIcon(icon)
    if icon and name and name~="" then spellIcons[name]=icon; spellIconCache[name]=icon end
    return icon
end
local function scanSpellIcons()
    if type(GetSpellName)~="function" or type(GetSpellTexture)~="function" then return end
    for _,book in ipairs({"spell","pet"}) do
        for i=1,1024 do
            local ok,name=pcall(GetSpellName,i,book)
            if ok and name then
                local success,icon=pcall(GetSpellTexture,i,book)
                if success then rememberSpellIcon(name,icon) end
            end
        end
    end
end
local function spellTextureByName(name)
    if type(name)~="string" or name=="" or type(GetSpellTexture)~="function" then return nil end
    for _,book in ipairs({"spell","pet"}) do
        local ok,icon=pcall(GetSpellTexture,name,book)
        icon=ok and normalizeSpellIcon(icon) or nil
        if icon then return icon end
    end
    return nil
end
local function spellIconLookup(name)
    local icon=spellIconFallbacks[name] or spellIcons[name]
    if not icon and type(name)=="string" then
        -- Combat-log names sometimes carry a rank suffix while the bundled
        -- database stores the base spell name.
        local base=string.gsub(name," %(Rank %d+%)$","")
        if base==name then base=string.gsub(name," [IVX]+$","") end
        icon=spellIconFallbacks[base] or spellIcons[base]
        if not icon then
            local lower=string.lower(base); local key
            for key in pairs(spellIconFallbacks) do
                if string.lower(key)==lower then icon=spellIconFallbacks[key]; break end
            end
            if not icon then
                for key in pairs(spellIcons) do
                    if string.lower(key)==lower then icon=spellIcons[key]; break end
                end
            end
        end
    end
    return icon
end
local function spellIcon(name,spellId)
    if name=="Melee" then return "Interface\\Icons\\INV_Sword_04" end
    if spellIconCache[name] then return spellIconCache[name] end
    local id=tonumber(spellId)
    if not id and type(name)=="string" then
        local base=string.gsub(name," %(Rank %d+%)$","")
        if base==name then base=string.gsub(name," [IVX]+$","") end
        id=tonumber(spellIdFallbacks[name] or spellIdFallbacks[base])
        if not id then
            local lower=string.lower(base)
            for key in pairs(spellIdFallbacks) do
                if string.lower(key)==lower then id=tonumber(spellIdFallbacks[key]); break end
            end
        end
    end
    if id and type(GetSpellInfo)=="function" then
        local ok,_,_,icon=pcall(GetSpellInfo,id)
        if ok then
            icon=rememberSpellIcon(name,icon)
            if icon then return icon end
        end
    end
    if id and _G and _G.CleveRoidsNampowerAPI
        and type(_G.CleveRoidsNampowerAPI.GetSpellIconTextureBySpellId)=="function" then
        local ok,icon=pcall(_G.CleveRoidsNampowerAPI.GetSpellIconTextureBySpellId,id)
        icon=ok and rememberSpellIcon(name,icon) or nil
        if icon then return icon end
    end
    -- Nampower also accepts a spell name.  This catches custom abilities in
    -- the local spellbook even when the combat-log row predates spell IDs.
    local liveIcon=spellTextureByName(name)
    if liveIcon then return rememberSpellIcon(name,liveIcon) end
    local icon=spellIconLookup(name)
    icon=rememberSpellIcon(name,icon)
    return icon or questionIcon
end
D.spellIcon=spellIcon

-- Compact mouseover details.  The old GameTooltip presentation used separate
-- player, pet and totem sections, which made a busy fight hard to scan.  Keep
-- one sorted list and merge equal ability names before drawing the bars. Melee
-- remains source-specific because a player's swing and a pet's swing are not
-- the same contribution.
local actorHoverLabels={damage="Damage",healing="Healing"}
local function mergedHoverEntries(actor,mode)
    if not actor or not actorHoverLabels[mode] then return nil,0 end
    local context=D.breakdownContext({segment=D.segment,segmentIndex=D.segmentIndex,mode=mode})
    local rows,total=D.breakdownEntries(context,actorId(actor))
    local grouped={}; local list={}
    for _,row in ipairs(rows or {}) do
        local name=row.name or "Unknown"
        -- Melee is emitted by both the player and pets. Keep those sources
        -- distinct in the compact hover instead of presenting one misleading
        -- combined total; equal named spells can still share a row.
        local separateMelee=name=="Melee"
        local groupKey=separateMelee and ("Melee:"..tostring(row.id)) or name
        local displayName=(separateMelee and row.isPet)
            and ((row.source and row.source..": ") or "Pet: ")..name or name
        local entry=grouped[groupKey]
        if not entry then
            entry={id=groupKey,name=name,displayName=displayName,value=0,hits=0,crits=0,spellId=row.spellId}
            grouped[groupKey]=entry; table.insert(list,entry)
        end
        if not entry.spellId and row.spellId then entry.spellId=row.spellId end
        entry.value=entry.value+(tonumber(row.value) or 0)
        entry.hits=entry.hits+(tonumber(row.hits) or 0)
        entry.crits=entry.crits+(tonumber(row.crits) or 0)
    end
    table.sort(list,function(a,b)
        if a.value==b.value then return a.name<b.name end
        return a.value>b.value
    end)
    return list,total
end

local function ensureActorHover()
    local h=D.actorHoverFrame
    if h then return h end
    h=CreateFrame("Frame","CawDPSMeterActorHover",UIParent)
    h:SetWidth(300); h:SetHeight(54); h:EnableMouse(false)
    if h.SetFrameStrata then h:SetFrameStrata("TOOLTIP") end
    if h.SetFrameLevel then h:SetFrameLevel(200) end
    D.uiPanel(h,0.98)
    h.title=D.uiText(h,"",9,-6,282,13)
    h.summary=D.uiText(h,"",9,-23,282,11)
    h.rows={}
    local i=1
    while i<=10 do
        local row=CreateFrame("Frame",nil,h); row:SetWidth(288); row:SetHeight(18)
        row:SetPoint("TOPLEFT",h,"TOPLEFT",6,-40-(i-1)*20)
        D.uiBlock(row,0,0,288,18,0.035,0.038,0.045,0.96)
        local bar=CreateFrame("StatusBar",nil,row); bar:SetPoint("TOPLEFT",row,"TOPLEFT",1,-1); bar:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-1,1)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8"); bar:SetMinMaxValues(0,1); bar:SetValue(0); bar:EnableMouse(false)
        local bg=bar:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(bar); bg:SetTexture("Interface\\Buttons\\WHITE8X8"); bg:SetVertexColor(0.035,0.038,0.045,0.96)
        local icon=bar:CreateTexture(nil,"OVERLAY"); icon:SetWidth(16); icon:SetHeight(16); icon:SetPoint("LEFT",bar,"LEFT",3,0); icon:SetTexCoord(0.08,0.92,0.08,0.92)
        -- Keep every label inside the 16px status bar.  The old -3px offset
        -- put the font baseline above the fill on some client font scales.
        local name=D.uiText(bar,"",23,-1,158,11)
        local value=D.uiText(bar,"",184,-1,52,11); value:SetJustifyH("RIGHT")
        local share=D.uiText(bar,"",242,-1,39,11); share:SetJustifyH("RIGHT")
        row.bar=bar; row.icon=icon; row.name=name; row.value=value; row.share=share; h.rows[i]=row
        i=i+1
    end
    D.actorHoverFrame=h
    return h
end

function D.hideActorHover()
    if D.actorHoverFrame then D.actorHoverFrame:Hide() end
end

function D.showActorHover(source,actor)
    local mode=D.mode
    if not source or not actor or not actorHoverLabels[mode] then return false end
    local rows,total=mergedHoverEntries(actor,mode)
    local h=ensureActorHover()
    local cr,cg,cb=D.uiClassColor(actor); h.title:SetText(actor.name or "Player"); h.title:SetTextColor(cr,cg,cb)
    local duration=D.breakdownDuration({segment=D.segment,history=D.segment=="history" and D.fightHistory[D.segmentIndex or 1] or nil,mode=mode,serial=D.segmentSerial})
    local rate=duration and duration>0 and total/duration or 0
    h.summary:SetText(actorHoverLabels[mode].." "..D.uiNumber(total).."  |  "..string.format("%.1f %s",rate,mode=="damage" and "DPS" or "HPS"))
    h.summary:SetTextColor(0.82,0.82,0.84)
    local largest=1; local i
    for i=1,table.getn(rows or {}) do if rows[i].value>largest then largest=rows[i].value end end
    local shown=math.min(10,table.getn(rows or {})); h:SetHeight(47+shown*20)
    for i=1,10 do
        local row=h.rows[i]; local entry=rows and rows[i]
        if entry then
            row:Show(); row.bar:SetMinMaxValues(0,largest); row.bar:SetValue(entry.value)
            local br,bg,bb=D.uiBarColour(cr,cg,cb); row.bar:SetStatusBarColor(br,bg,bb,0.78)
            row.icon:SetTexture(spellIcon(entry.name,entry.spellId)); row.name:SetText(entry.displayName or entry.name)
            row.name:SetTextColor(1,1,1); row.value:SetText(D.uiNumber(entry.value))
            row.share:SetText(string.format("%.1f%%",total>0 and entry.value/total*100 or 0))
        else row:Hide() end
    end
    -- A docked meter deliberately sits below Bagshui. Keep its auxiliary
    -- hover on that same strata as well, otherwise the details popup could
    -- still cover the bag even though the meter itself no longer does.
    local docked=false; local parent=source
    while parent do
        if parent.cawDockedLayer then docked=true; break end
        parent=parent.GetParent and parent:GetParent() or nil
    end
    local bagVisible=D.bagshuiWindowVisible and D.bagshuiWindowVisible() or false
    if h.SetFrameStrata then h:SetFrameStrata(bagVisible and "BACKGROUND" or (docked and "MEDIUM" or "TOOLTIP")) end
    if h.SetFrameLevel then h:SetFrameLevel(bagVisible and 0 or (docked and 5 or 200)) end
    h:ClearAllPoints()
    local sourceLeft=source.GetLeft and source:GetLeft(); local sourceRight=source.GetRight and source:GetRight()
    local sourceTop=source.GetTop and source:GetTop(); local sourceBottom=source.GetBottom and source:GetBottom()
    local screenRight=UIParent.GetRight and UIParent:GetRight(); local screenTop=UIParent.GetTop and UIParent:GetTop()
    -- WoW's vertical coordinates grow upward from the bottom edge. Prefer the
    -- space above the meter, but use the side with more room when the bar is
    -- close to an edge so the popup never hangs outside the screen.
    local roomAbove=screenTop and sourceTop and screenTop-sourceTop or nil
    local roomBelow=sourceBottom
    local above=(roomAbove==nil or roomAbove>=h:GetHeight()+8
        or roomAbove>=(roomBelow or -1))
    if above then
        if sourceLeft and screenRight and sourceLeft+h:GetWidth()>screenRight then
            h:SetPoint("BOTTOMRIGHT",source,"TOPRIGHT",0,8)
        else
            h:SetPoint("BOTTOMLEFT",source,"TOPLEFT",0,8)
        end
    elseif sourceRight and screenRight and sourceRight>=h:GetWidth() then
        h:SetPoint("TOPRIGHT",source,"BOTTOMRIGHT",0,-8)
    else
        h:SetPoint("TOPLEFT",source,"BOTTOMLEFT",0,-8)
    end
    h:Show()
    return true
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
    if p.compareButton then
        D.uiEnableButton(p.compareButton,actor and not actor.isPet and actor.classToken~=nil)
    end
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
            b.icon:SetTexture(spellIcon(row.name,row.spellId))
            b.nameText:SetText((row.isPet and (row.source..": ") or "")..row.name)
            b.value:SetText(valueText(row.value,aura[c.mode]))
            b.share:SetText(string.format("%.1f%%",total>0 and row.value/total*100 or 0))
            D.uiSelectButton(b,row==selected)
        else b.row=nil; b:Hide() end
    end
    p.spellTitle:SetText(selected and selected.name or "Select a spell")
    p.spellIcon:SetTexture(selected and spellIcon(selected.name,selected.spellId) or questionIcon)
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

-- Side-by-side comparison for two players in the same class.  The combat
-- data is already stored per actor; this view only presents a second
-- selection and a merged spell table, so it does not add any recording cost.
local function comparisonPlayers(context,actor,excludeKey)
    local list={}
    if not actor or not actor.classToken then return list end
    local actors=D.breakdownActors(context)
    for k,a in pairs(actors or {}) do
        local key=actorId(a,k)
        if a and not a.isPet and a.classToken==actor.classToken and key~=excludeKey then
            table.insert(list,{key=key,name=a.name or k,actor=a})
        end
    end
    table.sort(list,function(x,y) return x.name<y.name end)
    return list
end

local function comparisonRowLabel(row)
    if row.isPet then return (row.source and row.source..": " or "Pet: ")..row.name end
    return row.name
end

local function comparisonRows(context,leftKey,rightKey)
    local leftRows,leftTotal,leftActor=D.breakdownEntries(context,leftKey)
    local rightRows,rightTotal,rightActor=D.breakdownEntries(context,rightKey)
    local merged={}; local list={}
    local function add(rows,side)
        for _,row in ipairs(rows or {}) do
            local label=comparisonRowLabel(row); local entry=merged[label]
            if not entry then
                entry={label=label,name=row.name,valueLeft=0,valueRight=0,
                    hitsLeft=0,hitsRight=0,critsLeft=0,critsRight=0,
                    spellId=row.spellId}
                merged[label]=entry; table.insert(list,entry)
            end
            if not entry.spellId and row.spellId then entry.spellId=row.spellId end
            entry[side]=entry[side]+(tonumber(row.value) or 0)
            entry[side=="valueLeft" and "hitsLeft" or "hitsRight"]=
                entry[side=="valueLeft" and "hitsLeft" or "hitsRight"]+(tonumber(row.hits) or 0)
            entry[side=="valueLeft" and "critsLeft" or "critsRight"]=
                entry[side=="valueLeft" and "critsLeft" or "critsRight"]+(tonumber(row.crits) or 0)
        end
    end
    add(leftRows,"valueLeft"); add(rightRows,"valueRight")
    table.sort(list,function(a,b)
        local av=(a.valueLeft or 0)+(a.valueRight or 0); local bv=(b.valueLeft or 0)+(b.valueRight or 0)
        if av==bv then return a.label<b.label end
        return av>bv
    end)
    return list,leftTotal,rightTotal,leftActor,rightActor
end

local function signedValue(value)
    value=tonumber(value) or 0
    if value>0 then return "+"..D.uiNumber(value) end
    if value<0 then return "-"..D.uiNumber(-value) end
    return "0"
end

local function comparisonPercent(value,total)
    if not total or total<=0 then return "0.0%" end
    return string.format("%.1f%%",value/total*100)
end

local function comparisonMenuRefresh(cp,column)
    local menu=column==1 and cp.leftMenu or cp.rightMenu
    local choices=column==1 and cp.leftChoices or cp.rightChoices
    local visible=8; local count=table.getn(choices or {}); local shown=math.min(visible,count)
    local maxOffset=math.max(0,count-visible); menu.offset=math.max(0,math.min(maxOffset,menu.offset or 0))
    local top=count>visible and 20 or 4
    local i
    for i=1,visible do
        local b=menu.buttons[i]; local choice=choices[menu.offset+i]
        if choice then
            b.actorKey=choice.key; b.text:SetText(choice.name); b:Show()
            D.uiSelectButton(b,choice.key==(column==1 and cp.leftKey or cp.rightKey))
        else b.actorKey=nil; b:Hide() end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",menu,"TOPLEFT",4,-top-(i-1)*22)
    end
    menu:SetHeight(top+shown*22+(count>visible and 20 or 4))
    if count>visible then
        menu.up:Show(); menu.down:Show(); menu.up:SetPoint("TOPLEFT",menu,"TOPLEFT",4,-3); menu.down:SetPoint("BOTTOMLEFT",menu,"BOTTOMLEFT",4,3)
        D.uiEnableButton(menu.up,menu.offset>0); D.uiEnableButton(menu.down,menu.offset<maxOffset)
    else menu.up:Hide(); menu.down:Hide() end
end

local function comparisonMenuOpen(cp,column)
    local menu=column==1 and cp.leftMenu or cp.rightMenu
    if menu:IsShown() then menu:Hide(); return end
    D.refreshComparePanel(cp)
    cp.leftMenu:Hide(); cp.rightMenu:Hide()
    comparisonMenuRefresh(cp,column); menu:Show()
end

function D.refreshComparePanel(cp)
    if not cp or not cp.context then return end
    local c=cp.context
    local _,_,leftActor=D.breakdownEntries(c,cp.leftKey)
    if not leftActor or leftActor.isPet or not leftActor.classToken then
        cp.message:SetText("Select a player with known class data."); cp.message:Show()
        cp.leftChoices={}; cp.rightChoices={}; cp.leftMenu:Hide(); cp.rightMenu:Hide()
        for _,row in ipairs(cp.rows) do row:Hide() end
        return
    end
    local available=comparisonPlayers(c,leftActor,cp.leftKey)
    local rightActor
    if cp.rightKey then _,_,rightActor=D.breakdownEntries(c,cp.rightKey) end
    local validRight=false
    for _,choice in ipairs(available) do if choice.key==cp.rightKey then validRight=true; break end end
    if not validRight then cp.rightKey=available[1] and available[1].key or nil end
    if cp.rightKey then _,_,rightActor=D.breakdownEntries(c,cp.rightKey) end
    cp.leftChoices=comparisonPlayers(c,leftActor,cp.rightKey)
    cp.rightChoices=rightActor and comparisonPlayers(c,rightActor,cp.leftKey) or {}
    comparisonMenuRefresh(cp,1); comparisonMenuRefresh(cp,2)
    local rows,leftTotal,rightTotal,left,right=comparisonRows(c,cp.leftKey,cp.rightKey)
    local duration=D.breakdownDuration(c); local modeLabel=labels[c.mode] or c.mode
    cp.title:SetText("Compare players - "..modeLabel)
    cp.contextText:SetText(segmentLabel(c).."  |  "..string.format("%d:%02d",math.floor(duration/60),math.floor(duration-math.floor(duration/60)*60)))
    cp.leftButton.text:SetText(left and left.name or "Select player")
    cp.rightButton.text:SetText(right and right.name or "No same-class player")
    local leftRate=duration>0 and leftTotal/duration or 0; local rightRate=duration>0 and rightTotal/duration or 0
    cp.leftTotal:SetText(D.uiNumber(leftTotal).."  |  "..string.format("%.1f",leftRate))
    cp.rightTotal:SetText(D.uiNumber(rightTotal).."  |  "..string.format("%.1f",rightRate))
    local lr,lg,lb=D.uiClassColor(left)
    local rr,rg,rb=D.uiClassColor(right or left)
    cp.leftTotal:SetTextColor(lr,lg,lb); cp.rightTotal:SetTextColor(rr,rg,rb)
    cp.modeValue:SetText(modeLabel)
    cp.message:SetText(right and "" or "No other player of the same class is available in this segment.")
    if right then cp.message:Hide() else cp.message:Show() end
    local totalRows=math.min(14,table.getn(rows)); local i
    for i=1,14 do
        local row=cp.rows[i]; local entry=rows[i]
        if entry and right then
            row:Show(); row.icon:SetTexture(spellIcon(entry.name,entry.spellId)); row.name:SetText(entry.label)
            row.left:SetText(D.uiNumber(entry.valueLeft).."  "..comparisonPercent(entry.valueLeft,leftTotal))
            row.right:SetText(D.uiNumber(entry.valueRight).."  "..comparisonPercent(entry.valueRight,rightTotal))
            row.diff:SetText(signedValue(entry.valueLeft-entry.valueRight))
            if entry.valueLeft>entry.valueRight then row.diff:SetTextColor(0.65,0.90,0.55)
            elseif entry.valueRight>entry.valueLeft then row.diff:SetTextColor(1,0.72,0.45)
            else row.diff:SetTextColor(0.78,0.78,0.80) end
        else row:Hide() end
    end
    cp.footer:SetText("Totals include the selected player's owned pets. Difference is left minus right.")
end

function D.openCompare(context,primaryKey)
    if not context then return false end
    local cp=D.comparePanel
    if not cp then
        cp=D.uiDialog("CawComparePanel","Compare players",970,586); D.comparePanel=cp
        cp.contextText=D.uiText(cp,"",18,-54,320,13)
        cp.modeValue=D.uiText(cp,"",774,-54,170,13); cp.modeValue:SetJustifyH("RIGHT")
        cp.leftButton=D.uiListButton(cp,18,-78,420,function() comparisonMenuOpen(cp,1) end)
        cp.rightButton=D.uiListButton(cp,532,-78,420,function() comparisonMenuOpen(cp,2) end)
        D.uiText(cp,"v",401,-83,12,10); D.uiText(cp,"v",915,-83,12,10)
        cp.leftTotal=D.uiText(cp,"",18,-103,420,13); cp.rightTotal=D.uiText(cp,"",532,-103,420,13)
        cp.leftTotal:SetJustifyH("RIGHT"); cp.rightTotal:SetJustifyH("RIGHT")
        -- Leave a full line of breathing room between the totals and the
        -- table headings.  The old heading y-position put the divider through
        -- the font glyphs on the Vanilla client.
        D.uiBlock(cp,18,-148,934,1,0.26,0.265,0.29)
        D.uiText(cp,"Ability",48,-126,315,12); D.uiText(cp,"Player 1",365,-126,190,12):SetJustifyH("RIGHT")
        D.uiText(cp,"Player 2",575,-126,190,12):SetJustifyH("RIGHT"); D.uiText(cp,"Difference",785,-126,160,12):SetJustifyH("RIGHT")
        cp.message=D.uiText(cp,"",22,-151,920,13); cp.message:SetTextColor(0.84,0.72,0.45); cp.message:Hide()
        cp.rows={}
        local i=1
        while i<=14 do
            local row=CreateFrame("Frame",nil,cp); row:SetWidth(934); row:SetHeight(25); row:SetPoint("TOPLEFT",cp,"TOPLEFT",18,-157-(i-1)*27)
            D.uiBlock(row,0,0,934,25,0.075,0.078,0.09,0.96)
            row.icon=row:CreateTexture(nil,"OVERLAY"); row.icon:SetWidth(23); row.icon:SetHeight(23); row.icon:SetPoint("TOPLEFT",row,"TOPLEFT",1,-1); row.icon:SetTexCoord(0.08,0.92,0.08,0.92)
            row.name=D.uiText(row,"",30,-4,320,12); row.left=D.uiText(row,"",342,-4,190,12); row.left:SetJustifyH("RIGHT")
            row.right=D.uiText(row,"",552,-4,190,12); row.right:SetJustifyH("RIGHT"); row.diff=D.uiText(row,"",762,-4,160,12); row.diff:SetJustifyH("RIGHT")
            cp.rows[i]=row; i=i+1
        end
        cp.footer=D.uiText(cp,"",18,-535,934,11); cp.footer:SetTextColor(0.64,0.62,0.55)
        cp.leftChoices={}; cp.rightChoices={}
        -- Use a function parameter for the column.  Vanilla's Lua 5.0 keeps
        -- generic-for variables shared between closures, which would make
        -- both selector menus write to the right-hand player.
        local function createComparisonMenu(column)
            local menu=CreateFrame("Frame",nil,cp); menu:SetWidth(420); menu:SetHeight(200); menu:SetFrameLevel(125); menu:EnableMouse(true); D.uiPanel(menu); menu:Hide()
            menu.buttons={}; menu.offset=0; menu.up=D.uiButton(menu,"^",4,-3,412,function() menu.offset=math.max(0,menu.offset-1); comparisonMenuRefresh(cp,column) end); menu.down=D.uiButton(menu,"v",4,-3,412,function() menu.offset=menu.offset+1; comparisonMenuRefresh(cp,column) end)
            for i=1,8 do
                local b=D.uiListButton(menu,4,-4-(i-1)*22,412,function()
                    local selected=this.actorKey
                    if not selected then return end
                    if column==1 then cp.leftKey=selected else cp.rightKey=selected end
                    menu:Hide(); cp.leftMenu:Hide(); cp.rightMenu:Hide(); D.refreshComparePanel(cp)
                end)
                b:SetHeight(22); menu.buttons[i]=b
            end
            if column==1 then cp.leftMenu=menu else cp.rightMenu=menu end
        end
        createComparisonMenu(1); createComparisonMenu(2)
        cp:SetScript("OnHide",function()
            cp.leftMenu:Hide(); cp.rightMenu:Hide(); cp.context=nil; cp.leftKey=nil; cp.rightKey=nil
            local p=cp.returnPanel; local context=cp.returnContext; local actorKey=cp.returnActorKey
            local spellId=cp.returnSpellId; local search=cp.returnSearch; local showTalents=cp.returnShowTalents
            local talentPage=cp.returnTalentPage
            cp.returnPanel=nil; cp.returnContext=nil; cp.returnActorKey=nil; cp.returnSpellId=nil
            cp.returnSearch=nil; cp.returnShowTalents=nil; cp.returnTalentPage=nil
            if p and context then
                -- Restore the exact detail view that opened the comparison.
                -- The comparison temporarily replaces it, so the two large
                -- dialogs never compete for the same screen space.
                p.context=context; p.actorKey=actorKey; p.spellId=spellId
                p.search=search or ""; p.showTalents=showTalents and true or false; p.talentPage=talentPage or 0
                p:Show(); p.searchBox:SetText(p.search)
                if p.search=="" then p.searchHint:Show() else p.searchHint:Hide() end
                D.refreshBreakdown()
            end
        end)
    end
    local p=D.breakdownPanel
    if p and p:IsShown() and p.context then
        cp.returnPanel=p; cp.returnContext=p.context; cp.returnActorKey=p.actorKey; cp.returnSpellId=p.spellId
        cp.returnSearch=p.search; cp.returnShowTalents=p.showTalents; cp.returnTalentPage=p.talentPage
        p.suppressCompareHide=true; p:Hide(); p.suppressCompareHide=nil
    end
    cp.context=context; cp.leftKey=primaryKey; cp.rightKey=nil; cp.leftMenu:Hide(); cp.rightMenu:Hide(); cp:Show(); D.refreshComparePanel(cp)
    return true
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
        p.compareButton=D.uiButton(p,"Compare",818,-55,110,function()
            if p.context then D.openCompare(p.context,p.actorKey) end
        end)
        D.uiTooltip(p.compareButton,"Compare with another player of the same class.")
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
            if D.comparePanel and not p.suppressCompareHide then D.comparePanel:Hide() end
        end)
    end
    scanSpellIcons()
    if D.comparePanel then D.comparePanel:Hide() end
    p.context=D.breakdownContext(v); p.actorKey=actorId(actor); p.spellId=nil
    p.showTalents=false
    p.search=""; p.searchBox:SetText(""); p.searchHint:Show()
    p.playerOffset=0; p.segmentOffset=0; p.spellOffset=0; p.sort="value"
    D.refreshBreakdown(); p:Show()
end

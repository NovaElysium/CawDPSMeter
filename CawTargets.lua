-- Aggregated destinations from accepted DPSLog events. Local observations stay
-- separate from received owner snapshots and cumulative actor/spell sync totals.
local D=CAW_DPS_METER
local function addAmount(row,kind,amount,crit,over)
    row[kind]=(row[kind] or 0)+amount
    row.hits=(row.hits or 0)+1; row.crits=(row.crits or 0)+(crit and 1 or 0)
    if kind=="healing" and over~=nil then
        row.overhealing=(row.overhealing or 0)+over
        row.overhealTotal=(row.overhealTotal or 0)+amount+over
        row.overhealHits=(row.overhealHits or 0)+1
        row.overhealCrits=(row.overhealCrits or 0)+(crit and 1 or 0)
    end
end
function D.recordTargetAmount(actor,kind,guid,name,spell,amount,crit,spellId,over)
    if not actor or not guid or (kind~="damage" and kind~="healing") then return end
    local field=kind=="damage" and "damageTargets" or "healingTargets"
    local targets=actor[field]
    if not targets then targets={}; actor[field]=targets end
    local target=targets[guid]
    if not target then target={spells={}}; targets[guid]=target end
    if type(name)=="string" and name~="" and not string.find(name,"^0x[%x]+$") then target.name=name end
    local info=D.guidToActor[guid]
    if info then target.name=target.name or info.name; target.classToken=info.classToken end
    target.name=target.name or (D.currentEnemyNames and D.currentEnemyNames[guid])
    spell=spell or (kind=="damage" and "Melee" or "Healing")
    local entry=target.spells[spell]
    if not entry then entry={spellId=spellId}; target.spells[spell]=entry end
    if not entry.spellId then entry.spellId=spellId end
    addAmount(target,kind,amount,crit,over); addAmount(entry,kind,amount,crit,over)
    actor.targetRevision=(actor.targetRevision or 0)+1
end
function D.supportsTargetBreakdown(mode)
    return mode=="damage" or mode=="healing" or mode=="overhealing"
end

local function include(owner,a)
    return a==owner or (not owner.isPet and a.isPet and a.ownerKey==owner.key)
end
local function addRow(rows,id,name,source,record,mode,targetKey)
    local value=record[mode]
    if value==nil then return end
    local row=rows[id]
    if not row then
        row={id=id,name=name,source=source.name or "Player",isPet=not targetKey and source.isPet or nil,
            targetKey=targetKey,spellId=record.spellId,value=0,hits=0,crits=0}
        rows[id]=row
    end
    row.value=row.value+value
    row.hits=row.hits+((mode=="overhealing" and record.overhealHits or record.hits) or 0)
    row.crits=row.crits+((mode=="overhealing" and record.overhealCrits or record.crits) or 0)
    if record.overhealTotal~=nil then
        row.gross=(row.gross or 0)+record.overhealTotal
        row.overhealing=(row.overhealing or 0)+(record.overhealing or 0)
    end
end
function D.targetBreakdownEntries(context,key,targetKey,cache)
    cache=cache or {}
    local actors=D.breakdownActors(context); local owner=actors[key]
    if not owner then
        for k,a in pairs(actors) do if (a.guid or a.key or k)==key then owner=a; break end end
    end
    local mode=context.mode; local changed=false
    if cache.actors~=actors or cache.key~=key or cache.mode~=mode or cache.targetKey~=targetKey then
        cache.actors=actors; cache.key=key; cache.mode=mode; cache.targetKey=targetKey
        cache.stamps={}; changed=true
    end
    cache.pass=(cache.pass or 0)+1
    local fullTotal=0; local sources={}; local synced=false
    cache.selectedTargets=cache.selectedTargets or {}
    if owner then
        for _,a in pairs(actors) do
            if include(owner,a) then
                fullTotal=fullTotal+(a[mode] or 0); table.insert(sources,a)
                local targets,remote
                if D.targetDataForActor then targets,remote=D.targetDataForActor(a,mode) end
                targets=targets or a[mode=="damage" and "damageTargets" or "healingTargets"]
                cache.selectedTargets[a]=targets
                if remote or (a.targetHasSynced and a.targetHasSynced[mode=="damage" and "D" or "H"]) then synced=true end
                local stamp=cache.stamps[a]
                if not stamp then stamp={}; cache.stamps[a]=stamp; changed=true end
                if stamp.version~=a.targetRevision or stamp.name~=a.name or stamp.targets~=targets then changed=true end
                stamp.version=a.targetRevision; stamp.name=a.name; stamp.targets=targets; stamp.pass=cache.pass
            end
        end
    end
    for a,stamp in pairs(cache.stamps) do
        if stamp.pass~=cache.pass then cache.stamps[a]=nil; cache.selectedTargets[a]=nil; changed=true end
    end
    if cache.fullTotal~=fullTotal or cache.actor~=owner or cache.synced~=synced then changed=true end
    if changed then
        local map={}; local covered=0; local gross=nil; local targetName=nil; local hasData=false
        local destinations=targetKey and {} or nil
        for _,a in ipairs(sources) do
            for guid,target in pairs(cache.selectedTargets[a] or {}) do
                if target[mode]~=nil then hasData=true end
                covered=covered+(target[mode] or 0)
                if destinations and target[mode]~=nil then
                    destinations[guid]=target.name or destinations[guid] or "Unknown target"
                end
                if not targetKey or guid==targetKey then
                    if target.overhealTotal~=nil then gross=(gross or 0)+target.overhealTotal end
                    local name=target.name or "Unknown target"
                    if targetKey then
                        for spell,record in pairs(target.spells or {}) do
                            addRow(map,tostring(a.key)..":"..spell,spell,a,record,mode)
                        end
                    else
                        addRow(map,guid,name,owner,target,mode,guid)
                        -- Another source may have resolved an initially unknown name.
                        if target.name and map[guid] then map[guid].name=target.name end
                    end
                end
            end
        end
        local rows={}; local localTotal=0
        for _,row in pairs(map) do table.insert(rows,row); localTotal=localTotal+row.value end
        if destinations then
            targetName=destinations[targetKey]
            if targetName then
                local count,index=0,1
                for guid,name in pairs(destinations) do
                    if name==targetName then count=count+1; if guid<targetKey then index=index+1 end end
                end
                if count>1 then targetName=targetName.." ("..index..")" end
            end
        end
        if not targetKey then
            -- Distinct GUIDs stay distinct, including same-name enemies. Assign
            -- stable suffixes before sorting by changing combat amounts.
            table.sort(rows,function(a,b) if a.name==b.name then return a.id<b.id end; return a.name<b.name end)
            local counts={}; local seen={}
            for _,row in ipairs(rows) do counts[row.name]=(counts[row.name] or 0)+1 end
            for _,row in ipairs(rows) do
                local name=row.name; seen[name]=(seen[name] or 0)+1
                row.baseName=name
                if counts[name]>1 then row.name=name.." ("..seen[name]..")" end
            end
        end
        table.sort(rows,function(a,b) if a.value==b.value then return a.id<b.id end; return a.value>b.value end)
        cache.rows=rows; cache.fullTotal=fullTotal; cache.covered=covered; cache.gross=gross
        -- Overheal rates must use the same selected coverage as their denominator;
        -- a larger synced overheal total has no corresponding target breakdown.
        cache.total=(targetKey or mode=="overhealing") and localTotal or fullTotal
        cache.targetName=targetName; cache.actor=owner; cache.revision=(cache.revision or 0)+1
        cache.synced=synced
        cache.hasData=hasData
    end
    return cache.rows or {},cache.total or 0,owner
end

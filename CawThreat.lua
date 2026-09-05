-- Caw Threat Engine - experimental RavenCraft/Vanilla 1.12 threat model.
-- Reimplemented from observed Vanilla threat rules and cross-checked against
-- KLH Threat Meter / DPSMate behavior. No GPL source code is embedded here.
CAW_DPS_METER = CAW_DPS_METER or {}
local D = CAW_DPS_METER

D.threatModelVersion = "CawThreat-0.20"
D.threatPendingCast = D.threatPendingCast or {}

-- Conservative spell multipliers that are independent of rank.
D.threatSpellMultiplier = {
    ["Searing Pain"] = 2.0,
    ["Earth Shock"] = 2.0,
    ["Mind Blast"] = 2.0,
    ["Holy Shield"] = 1.2,
    -- RavenCraft capture: relative to the same actor's melee modifier.
    ["Maul"] = 1.50,
    ["Swipe"] = 1.40,
}

-- Rank-specific flat threat values. These are kept by spell ID so RavenCraft's
-- UNIT_CASTEVENT can identify the exact rank without locale/rank text parsing.
-- A flat value is only committed after a matching landed/damage event; a CAST
-- alone never proves success. Distracting Shot ranks 1-3 use RavenCraft values
-- measured in live aggro-boundary tests; ranks 4-6 remain unverified Vanilla fallbacks.
D.threatFlatBySpellId = {
    -- RavenCraft measured rank 2: 108 * 1.45 = 156.6 (156/157 server steps).
    [17390]=108,
    -- Distracting Shot ranks 1-6
    [20736]=220, [14274]=360, [15629]=550, [15630]=350, [15631]=465, [15632]=600,
    -- Sunder Armor ranks 1-5
    [7386]=52, [7405]=104, [8380]=156, [11596]=208, [11597]=260,
    -- Shield Bash ranks 1-3
    [72]=60, [1671]=120, [1672]=180,
    -- Shield Slam ranks 1-4
    [23922]=62, [23923]=125, [23924]=187, [23925]=250,
    -- Revenge ranks 1-6
    [6572]=59, [6574]=118, [7379]=177, [11600]=236, [11601]=315, [25288]=355,
    -- Cleave ranks 1-5
    [845]=20, [7369]=40, [11608]=60, [11609]=80, [11610]=100,
    -- Feint ranks 1-5 (threat reduction)
    [1966]=-150, [6768]=-240, [8637]=-390, [11303]=-600, [25302]=-800,
    -- Cower ranks 1-3 (threat reduction)
    [8998]=-240, [9000]=-390, [9892]=-600,
    -- Heroic Strike ranks 8-9: known bonus threat. Lower ranks deliberately
    -- omitted rather than guessed; RavenCraft/custom ranks can be added after validation.
    [11567]=145, [25286]=173,
}

D.threatFlatNameBySpellId = {
    [17390]="Faerie Fire (Feral)",
    [20736]="Distracting Shot", [14274]="Distracting Shot", [15629]="Distracting Shot", [15630]="Distracting Shot", [15631]="Distracting Shot", [15632]="Distracting Shot",
    [7386]="Sunder Armor", [7405]="Sunder Armor", [8380]="Sunder Armor", [11596]="Sunder Armor", [11597]="Sunder Armor",
    [72]="Shield Bash", [1671]="Shield Bash", [1672]="Shield Bash",
    [23922]="Shield Slam", [23923]="Shield Slam", [23924]="Shield Slam", [23925]="Shield Slam",
    [6572]="Revenge", [6574]="Revenge", [7379]="Revenge", [11600]="Revenge", [11601]="Revenge", [25288]="Revenge",
    [845]="Cleave", [7369]="Cleave", [11608]="Cleave", [11609]="Cleave", [11610]="Cleave",
    [1966]="Feint", [6768]="Feint", [8637]="Feint", [11303]="Feint", [25302]="Feint",
    [8998]="Cower", [9000]="Cower", [9892]="Cower",
    [11567]="Heroic Strike", [25286]="Heroic Strike",
}

function D.threatDisplayTargetGUID()
    if D.segment=="history" then
        local h=D.threatHistoryFight and D.threatHistoryFight()
        return h and h.enemyGuid or nil
    end
    if UnitExists then
        local ok,exists,guid=pcall(UnitExists,"target")
        if ok and exists and guid and string.find(guid,"^0x") then return guid end
    end
    return D.currentEnemyBestGuid
end

function D.threatDisplayTargetName()
    if D.segment=="history" then
        local h=D.threatHistoryFight and D.threatHistoryFight()
        return h and (h.enemyName or h.name) or "No target"
    end
    local guid=D.threatDisplayTargetGUID()
    if not guid then return "No target" end
    if D.currentEnemyNames and D.currentEnemyNames[guid] then return D.currentEnemyNames[guid] end
    if D.enemyNameFromGUID then return D.enemyNameFromGUID(guid) or "Current Target" end
    return "Current Target"
end

function D.threatAggroHolderGUID()
    if D.segment~="current" then return nil end
    local targetGuid=D.threatDisplayTargetGUID()
    if not targetGuid or not UnitExists then return nil end
    local ok,exists,guid=pcall(UnitExists,"target")
    if not ok or not exists or guid~=targetGuid then return nil end
    local ok2,ttExists,ttGuid=pcall(UnitExists,"targettarget")
    if ok2 and ttExists and ttGuid and D.guidToActor and D.guidToActor[ttGuid] then return ttGuid end
    return nil
end

function D.threatReferenceForDisplay()
    local guid=D.threatDisplayTargetGUID(); if not guid then return 0,nil end
    local holder=D.threatAggroHolderGUID()
    if holder and D.guidToActor then
        local info=D.guidToActor[holder]
        local a=info and D.actors and D.actors[info.key]
        local v=a and a.threat and (a.threat[guid] or 0) or 0
        if v>0 then return v,holder end
    end
    return D.threatTopForDisplay and D.threatTopForDisplay() or 0,nil
end

function D.threatPercentForActor(actor)
    if actor and actor._serverThreatValue then return actor._serverThreatPercent or 0 end
    local v=D.threatValueForActor(actor)
    local ref=D.threatReferenceForDisplay()
    if ref and ref>0 then return (v/ref)*100 end
    return 0
end

function D.threatResetActor(actor,source)
    if not actor or not actor.threat then return end
    local tg,v
    for tg,v in actor.threat do
        if v and v>0 then
            local before=v
            actor.threat[tg]=0
            actor.threatBase=actor.threatBase or {}; actor.threatBase[tg]=0
            actor.threatModifier=actor.threatModifier or {}; actor.threatModifier[tg]=0
            actor.threatSpecial=actor.threatSpecial or {}; actor.threatSpecial[tg]=0
            actor.threatAbilities=actor.threatAbilities or {}; actor.threatAbilities[tg]=actor.threatAbilities[tg] or {}
            actor.threatAbilities[tg][source or "Threat reset"]=(actor.threatAbilities[tg][source or "Threat reset"] or 0)-before
            D.threatCalcLog((actor.name or "Unknown").." -> "..D.threatCalcTargetName(tg).." | "..(source or "Threat reset").." | "..string.format("%.1f",before).." -> 0.0")
        end
    end
end

function D.threatDruidUnit(actor)
    if not actor or not actor.guid or not UnitExists then return nil end
    local ok,exists,guid=pcall(UnitExists,"player")
    if ok and exists and guid==actor.guid then return "player" end
    local raid=GetNumRaidMembers and GetNumRaidMembers() or 0
    local count=raid>0 and raid or (GetNumPartyMembers and GetNumPartyMembers() or 0)
    local i
    for i=1,count do
        local unit=(raid>0 and "raid" or "party")..i
        ok,exists,guid=pcall(UnitExists,unit)
        if ok and exists and guid==actor.guid then return unit end
    end
end

function D.threatDruidBearForm(unit)
    if not unit or not UnitBuff then return nil end
    local i
    for i=1,32 do
        local ok,texture,count,spellId=pcall(UnitBuff,unit,i)
        if not ok then return nil end
        if not texture then return false end
        if spellId==5487 or spellId==9634 then return true end
    end
    return nil
end

function D.threatLocalFeralInstinct()
    if not GetNumTalentTabs or not GetNumTalents or not GetTalentInfo then return nil end
    local ok,tabs=pcall(GetNumTalentTabs)
    if not ok or type(tabs)~="number" then return nil end
    local tab,i
    for tab=1,tabs do
        local good,n=pcall(GetNumTalents,tab)
        if not good or type(n)~="number" then return nil end
        for i=1,n do
            local success,name,icon,tier,column,rank,maxRank=pcall(GetTalentInfo,tab,i)
            if success and (name=="Feral Instinct" or name=="Instinkt der Wildnis") then
                if (maxRank==3 or maxRank==5) and type(rank)=="number" and rank>=0 and rank<=maxRank then return rank,maxRank end
                return nil -- do not reinterpret a custom talent layout
            end
        end
    end
end

function D.threatDruidModifiers(actor)
    local unit=D.threatDruidUnit(actor)
    local bear=D.threatDruidBearForm(unit)
    if not bear then return 1,0,bear==false and "not-bear" or "form-unknown" end
    local rank,maxRank=nil,nil
    local knowledge="talent-unknown"
    if unit=="player" then
        -- Short cache avoids scanning the talent tree for each damage tick.
        if not D.threatFeralTalentAt or GetTime()-D.threatFeralTalentAt>1 then
            D.threatFeralTalentRank,D.threatFeralTalentMax=D.threatLocalFeralInstinct()
            D.threatFeralTalentAt=GetTime()
        end
        rank=D.threatFeralTalentRank
        maxRank=D.threatFeralTalentMax
        if rank then knowledge="local-talent" end
    else
        if D.threatSyncedFeralInstinct then rank,maxRank=D.threatSyncedFeralInstinct(actor) end
        if rank then knowledge="caw-sync" end
    end
    return 1.30,rank and rank*(0.15/maxRank) or 0,knowledge
end

function D.threatGlobalModifier(actor)
    -- Druid form comes from roster buffs; talents from local API or Caw Sync.
    if not actor or actor.isPet then return 1 end
    if actor.classToken=="DRUID" then
        local form,talent=D.threatDruidModifiers(actor)
        return form+talent
    end
    if actor.classToken=="ROGUE" then return 0.80 end
    local pg=nil
    if UnitExists then local ok,ex,g=pcall(UnitExists,"player"); if ok and ex then pg=g end end
    if not pg or actor.guid~=pg then return 1 end
    local _,class=UnitClass("player")
    if class=="WARRIOR" and GetShapeshiftForm then
        local ok,stance=pcall(GetShapeshiftForm)
        if ok then
            if stance==2 then return 1.30 end -- Defensive Stance
            if stance==1 or stance==3 then return 0.80 end -- Battle/Berserker
        end
    elseif class=="ROGUE" then
        return 0.80
    end
    return 1
end

function D.threatCalcTargetName(targetGuid)
    if not targetGuid then return "Unknown target" end
    if D.currentEnemyNames and D.currentEnemyNames[targetGuid] then return D.currentEnemyNames[targetGuid] end
    if D.enemyNameFromGUID then return D.enemyNameFromGUID(targetGuid) or tostring(targetGuid) end
    return tostring(targetGuid)
end

function D.threatCalcLog(line)
    if not D.threatCalcDebugEnabled then return end
    D.threatCalcDebugLines=D.threatCalcDebugLines or {}
    D.threatCalcDebugCount=(D.threatCalcDebugCount or 0)+1
    if table.getn(D.threatCalcDebugLines)<300 then
        table.insert(D.threatCalcDebugLines,string.format("%.2f | %s",GetTime(),tostring(line)))
    end
end

function D.threatAdd(actor,targetGuid,amount,source,baseAmount,kind)
    amount=tonumber(amount) or 0
    if not actor or not targetGuid or amount==0 then return end
    local validationBefore=nil
    if D.threatCalcDebugEnabled and D.threatValidationSnapshot then validationBefore=D.threatValidationSnapshot(targetGuid) end
    actor.threat=actor.threat or {}
    actor.threatAbilities=actor.threatAbilities or {}
    actor.threatBase=actor.threatBase or {}
    actor.threatModifier=actor.threatModifier or {}
    actor.threatSpecial=actor.threatSpecial or {}
    local old=actor.threat[targetGuid] or 0
    local nv=old+amount
    if nv<0 then nv=0 end
    amount=nv-old -- reductions cannot drive total threat below zero
    if amount==0 then return end
    actor.threat[targetGuid]=nv
    actor.threatAbilities[targetGuid]=actor.threatAbilities[targetGuid] or {}
    local ab=actor.threatAbilities[targetGuid]
    source=source or "Other"
    ab[source]=(ab[source] or 0)+amount

    baseAmount=tonumber(baseAmount) or 0
    if kind=="special" then
        actor.threatSpecial[targetGuid]=(actor.threatSpecial[targetGuid] or 0)+amount
    else
        actor.threatBase[targetGuid]=(actor.threatBase[targetGuid] or 0)+baseAmount
        actor.threatModifier[targetGuid]=(actor.threatModifier[targetGuid] or 0)+(amount-baseAmount)
    end

    D.threatCalcLog((actor.name or "Unknown").." -> "..D.threatCalcTargetName(targetGuid).." | "..source.." | +"..string.format("%.1f",amount).." threat"..(baseAmount>0 and (" | base "..string.format("%.1f",baseAmount)) or ""))
    if D.threatCalcDebugEnabled and D.threatValidationSnapshot then
        D.threatValidationLastEvent=D.threatValidationLastEvent or {}
        D.threatValidationLastEvent[targetGuid]={
            time=GetTime(),
            text=(actor.name or "Unknown").." | "..source.." | +"..string.format("%.1f",amount),
            before=validationBefore or "no calculated threat",
            after=D.threatValidationSnapshot(targetGuid)
        }
    end
end

function D.threatPendingKey(spellId,targetGuid)
    return tostring(spellId or 0).."@"..tostring(targetGuid or "")
end

function D.threatSameSpell(a,b)
    if a==b then return true end
    return (a=="Faerie Fire" and b=="Faerie Fire (Feral)") or (b=="Faerie Fire" and a=="Faerie Fire (Feral)")
end

function D.threatCommitPendingFlat(actor,targetGuid,spell)
    if not actor or not actor.guid or not targetGuid or not spell then return false end
    local bucket=D.threatPendingCast and D.threatPendingCast[actor.guid]
    if not bucket then return false end
    local now=GetTime(); local key,p; local best=nil
    for key,p in bucket do
        if now-(p.time or 0)>2 then bucket[key]=nil
        elseif not p.committed and p.target==targetGuid and D.threatSameSpell(spell,p.name or D.threatFlatNameBySpellId[p.spellId]) then
            if not best or p.time>best.time then best=p end
        end
    end
    if not best then return false end
    best.committed=true
    local sid=best.spellId
    local flat=D.threatFlatBySpellId[sid]
    if flat then
        D.threatAdd(actor,targetGuid,flat*D.threatGlobalModifier(actor),spell.." bonus",0,"special")
    elseif D.threatGrowlById[sid] then
        D.threatAdd(actor,targetGuid,D.threatGrowlValue(actor,sid),"Growl",0,"special")
    elseif sid==355 or sid==6795 then
        local top=0; local k,a
        for k,a in D.actors do
            local v=a.threat and a.threat[targetGuid] or 0
            if v>top then top=v end
        end
        local cur=actor.threat and actor.threat[targetGuid] or 0
        if top>cur then D.threatAdd(actor,targetGuid,top-cur,(sid==6795 and "Growl (Druid)" or "Taunt"),0,"special") end
    end
    return true
end

-- RavenCraft reports first Faerie Fire application without a caster in RAW.
-- Correlate only an exact spell/target CAST within 0.5 seconds. Ambiguous
-- candidates are left unresolved, including already committed candidates.
function D.threatOnAuraLanded(targetGuid,spell)
    if not D.threatSameSpell(spell,"Faerie Fire (Feral)") then return false end
    local now=GetTime(); local caster=nil; local cg,bucket,key,p
    for cg,bucket in D.threatPendingCast do
        for key,p in bucket do
            if p.spellId==17390 and p.target==targetGuid and now-p.time>=0 and now-p.time<=0.5 then
                if caster then return false end
                caster=cg
            end
        end
    end
    if caster then return D.threatOnSpellLanded(caster,targetGuid,spell) end
    return false
end

function D.threatOnSpellLanded(casterGuid,targetGuid,spell)
    if spell=="Feign Death" then return D.threatOnFeignSuccess(casterGuid) end
    if not casterGuid or not targetGuid then return false end
    local info=D.guidToActor and D.guidToActor[casterGuid]
    if not info then return false end
    local bucket=D.threatPendingCast and D.threatPendingCast[casterGuid]
    if not bucket or not next(bucket) then return false end
    local actor=D.getActor(info.key,info.name,info.guid,info.ownerKey,info.isPet,info.classToken)
    return D.threatCommitPendingFlat(actor,targetGuid,spell)
end

function D.threatOnSpellFailed(casterGuid,targetGuid,spell)
    if not casterGuid or not D.threatPendingCast then return end
    local bucket=D.threatPendingCast[casterGuid]
    if not bucket then return end
    local now=GetTime(); local key,p
    for key,p in bucket do
        if p and (now-(p.time or 0))<=2.0 and ((not targetGuid) or p.target==targetGuid) then
            local sid=tonumber(p.spellId); local expected=p.name or (sid and D.threatFlatNameBySpellId[sid])
            if (not spell) or (not expected) or D.threatSameSpell(spell,expected) then
                D.threatCalcLog((D.guidToActor and D.guidToActor[casterGuid] and D.guidToActor[casterGuid].name or "Unknown").." -> "..D.threatCalcTargetName(p.target).." | "..tostring(expected or spell or "Special").." | failed - no flat threat committed")
                bucket[key]=nil
            end
        end
    end
end

function D.threatOnDamage(actor,amount,spell,crit,targetGuid)
    if not actor or not targetGuid then return end
    local mult=D.threatSpellMultiplier[spell or ""] or 1
    local threat=(tonumber(amount) or 0)*mult*D.threatGlobalModifier(actor)
    D.threatAdd(actor,targetGuid,threat,spell or "Damage",tonumber(amount) or 0,"normal")
    D.threatCommitPendingFlat(actor,targetGuid,spell)
end

function D.threatOnHealing(actor,amount,spell)
    -- Healing threat is intentionally conservative in Alpha: apply the Vanilla
    -- 0.5 coefficient to the currently dominant hostile target only. Multi-mob
    -- splitting and overheal need RavenCraft validation before release.
    local targetGuid=D.currentEnemyBestGuid
    if not targetGuid or (D.deadEnemies and D.deadEnemies[targetGuid]) then return end
    local threat=(tonumber(amount) or 0)*0.5*D.threatGlobalModifier(actor)
    D.threatAdd(actor,targetGuid,threat,"Healing",(tonumber(amount) or 0)*0.5,"normal")
end

-- Only supported roster casts enter the pending table. RAW success commits them.
D.threatGrowlById={[2649]=50,[14916]=65,[14917]=110,[14918]=170,[14919]=240,[14920]=320,[14921]=415}
-- Measured RavenCraft combinations only; no extrapolation to other levels.
D.threatGrowlByLevel={[14917]={[29]=146},[14918]={[33]=182}}

function D.threatPetLevelAtUnit(guid,unit)
    if not UnitExists or not UnitLevel then return nil end
    local ok,exists,unitGuid=pcall(UnitExists,unit)
    if not ok or not exists or unitGuid~=guid then return nil end
    local good,level=pcall(UnitLevel,unit)
    if good and type(level)=="number" and level>0 then return level end
end

function D.threatGrowlValue(actor,spellId)
    local fallback=D.threatGrowlById[spellId]
    local measured=D.threatGrowlByLevel[spellId]
    if not measured or not actor or not actor.isPet or not actor.guid then return fallback end
    local level=D.threatPetLevelAtUnit(actor.guid,"pet")
    local i
    if not level then
        local raid=GetNumRaidMembers and GetNumRaidMembers() or 0
        if raid>0 then
            for i=1,raid do
                level=D.threatPetLevelAtUnit(actor.guid,"raidpet"..i)
                if level then break end
            end
        else
            local party=GetNumPartyMembers and GetNumPartyMembers() or 0
            for i=1,party do
                level=D.threatPetLevelAtUnit(actor.guid,"partypet"..i)
                if level then break end
            end
        end
    end
    return (level and measured[level]) or fallback
end
D.threatPendingReset={}
D.threatFeignEarly={}
D.threatFeignCommitted={}
D.threatFeignUndo={}
function D.threatPrunePending()
    local now=GetTime(); local guid,bucket; local key,p
    for guid,bucket in D.threatPendingCast do
        for key,p in bucket do if now-(p.time or 0)>2 then bucket[key]=nil end end
        if not next(bucket) then D.threatPendingCast[guid]=nil end
    end
    for guid,p in D.threatPendingReset do if now-p>2 then D.threatPendingReset[guid]=nil end end
    for guid,p in D.threatFeignEarly do if now-p>0.5 then D.threatFeignEarly[guid]=nil end end
    for guid,p in D.threatFeignCommitted do if now-p>2 then D.threatFeignCommitted[guid]=nil end end
    for guid,p in D.threatFeignUndo do if now-p.time>2 then D.threatFeignUndo[guid]=nil end end
end

-- A completed FD cast is observable on RavenCraft even when no RAW success is
-- emitted. Keep a short per-target baseline to reverse explicit failure/resist.
function D.threatFeignRestore(casterGuid,targetGuid)
    local saved=D.threatFeignUndo[casterGuid]
    if not saved or GetTime()-saved.time>2 then return false end
    local info=D.guidToActor[casterGuid]
    local actor=info and D.actors[info.key]
    if actor~=saved.actor then return false end
    local tg,v; local restored=false
    for tg,v in saved.targets do
        if not targetGuid or tg==targetGuid then
            local before=actor.threat[tg] or 0
            actor.threat[tg]=before+v.total
            actor.threatBase[tg]=(actor.threatBase[tg] or 0)+v.base
            actor.threatModifier[tg]=(actor.threatModifier[tg] or 0)+v.modifier
            actor.threatSpecial[tg]=(actor.threatSpecial[tg] or 0)+v.special
            local ab=actor.threatAbilities[tg]
            ab["Feign Death resisted"]=(ab["Feign Death resisted"] or 0)+v.total
            if D.threatCalRecordEvent then D.threatCalRecordEvent({kind="reset-reversal",source="Feign Death failed/resisted",actor=actor.name,guid=actor.guid,targetGuid=tg,before=before,after=actor.threat[tg],delta=v.total}) end
            saved.targets[tg]=nil; restored=true
        end
    end
    return restored
end

function D.threatFeignRawFailure(text)
    if not text or not string.find(text,"Feign Death",1,true) then return end
    local _,_,target=string.find(text,"^Your Feign Death was resisted by (0x[%x]+)%.")
    if not target then _,_,target=string.find(text,"^Your Feign Death is resisted by (0x[%x]+)%.") end
    local _,_,caster,remoteTarget=string.find(text,"^(0x[%x]+)'s Feign Death was resisted by (0x[%x]+)%.")
    if not caster then _,_,caster,remoteTarget=string.find(text,"^(0x[%x]+)'s Feign Death is resisted by (0x[%x]+)%.") end
    if caster then D.threatFeignRestore(caster,remoteTarget)
    elseif target and UnitExists then
        local ok,exists,guid=pcall(UnitExists,"player")
        if ok and exists and guid then D.threatFeignRestore(guid,target) end
    end
end

function D.threatOnFeignSuccess(casterGuid)
    if not casterGuid or not D.guidToActor[casterGuid] then return false end
    if D.threatFeignCommitted[casterGuid] and GetTime()-D.threatFeignCommitted[casterGuid]<2 then return false end
    local pending=D.threatPendingReset[casterGuid]
    if not pending or GetTime()-pending>2 then D.threatFeignEarly[casterGuid]=GetTime(); return false end
    D.threatPendingReset[casterGuid]=nil
    local info=D.guidToActor[casterGuid]
    local actor=info and D.actors[info.key]
    if not actor then return false end
    D.threatFeignEarly[casterGuid]=nil
    D.threatFeignCommitted[casterGuid]=GetTime()
    local saved={time=GetTime(),actor=actor,targets={}}
    local tg,v; local threats=actor.threat or {}
    for tg,v in threats do
        if v>0 then saved.targets[tg]={total=v,base=actor.threatBase and actor.threatBase[tg] or 0,modifier=actor.threatModifier and actor.threatModifier[tg] or 0,special=actor.threatSpecial and actor.threatSpecial[tg] or 0} end
    end
    D.threatFeignUndo[casterGuid]=saved
    D.threatResetActor(actor,"Feign Death")
    return true
end

function D.threatOnCast(casterGuid,targetGuid,castType,spellId)
    if not casterGuid then return end
    local sid=tonumber(spellId)
    local info=D.guidToActor and D.guidToActor[casterGuid]
    if not info or not sid then return end
    if castType=="FAIL" then
        if sid==5384 then D.threatFeignRestore(casterGuid); D.threatPendingReset[casterGuid]=nil; D.threatFeignEarly[casterGuid]=nil end
        local bucket=D.threatPendingCast[casterGuid]
        if bucket then bucket[D.threatPendingKey(sid,targetGuid)]=nil end
        return
    end
    if castType~="CAST" then return end
    D.threatPrunePending()
    if sid==5384 then
        if D.threatFeignCommitted[casterGuid] and GetTime()-D.threatFeignCommitted[casterGuid]<2 then return end
        D.threatPendingReset[casterGuid]=GetTime()
        D.threatOnFeignSuccess(casterGuid)
        return
    end
    local specialName=nil
    if D.threatGrowlById[sid] or sid==6795 then specialName="Growl"
    elseif sid==355 then specialName="Taunt" end
    if not specialName and not D.threatFlatBySpellId[sid] then return end
    if not targetGuid or not string.find(targetGuid,"^0x[%x]+$") or D.guidToActor[targetGuid] then return end
    if UnitCanAttack then
        local ok,attack=pcall(UnitCanAttack,"player",targetGuid)
        if ok and not attack then return end
    end
    if D.ensureStarted then
        D.threatOpeningCastActive=true
        local ok,opened=pcall(D.ensureStarted)
        D.threatOpeningCastActive=false
        if not ok then error(opened) end
        if opened==false then return end
    end
    D.threatPendingCast[casterGuid]=D.threatPendingCast[casterGuid] or {}
    local bucket=D.threatPendingCast[casterGuid]
    local key=D.threatPendingKey(sid,targetGuid)
    -- Repeated CAST notifications must not re-arm an already committed cast.
    if bucket[key] and GetTime()-(bucket[key].time or 0)<0.20 then return end
    bucket[key]={target=targetGuid,spellId=sid,time=GetTime(),name=specialName}
end

function D.threatValueForActor(actor)
    if actor and actor._serverThreatValue then return actor._serverThreatValue end
    if not actor or not actor.threat then return 0 end
    local guid=D.threatDisplayTargetGUID()
    if not guid then return 0 end
    return actor.threat[guid] or 0
end

function D.threatTopForDisplay()
    local guid=D.threatDisplayTargetGUID(); if not guid then return 0 end
    local top=0; local k,a
    local actors=D.threatDisplayActors and D.threatDisplayActors() or D.actors
    if actors then for k,a in actors do if a.threat and (a.threat[guid] or 0)>top then top=a.threat[guid] end end end
    return top
end

-- RC17 validation: correlate Caw's calculated threat with the mob's actually
-- observed target. This never invents server threat; it records the point at
-- which RavenCraft changes aggro so the model can be checked afterwards.
D.threatValidationLastTarget = D.threatValidationLastTarget or {}
D.threatValidationLastSnapshot = D.threatValidationLastSnapshot or {}
D.threatValidationLastEvent = D.threatValidationLastEvent or {}
D.threatValidationNext = D.threatValidationNext or 0

function D.threatValidationSnapshot(enemyGuid)
    if not enemyGuid then return "no calculated target" end
    local rows={}; local k,a
    if D.actors then
        for k,a in D.actors do
            local v=(a.threat and a.threat[enemyGuid]) or 0
            if v>0 then table.insert(rows,{name=a.name or k,value=v}) end
        end
    end
    table.sort(rows,function(x,y) return x.value>y.value end)
    local top=(rows[1] and rows[1].value) or 0
    local out=""; local i=1
    while i<=table.getn(rows) and i<=6 do
        local pct=(top>0) and (rows[i].value/top*100) or 0
        if out~="" then out=out.."; " end
        out=out..rows[i].name.."="..string.format("%.1f",rows[i].value).." ("..string.format("%.1f",pct).."%)"
        i=i+1
    end
    if out=="" then return "no calculated threat" end
    return out
end

function D.threatValidationTick()
    if not D.threatCalcDebugEnabled then return end
    local now=GetTime()
    if now<(D.threatValidationNext or 0) then return end
    D.threatValidationNext=now+0.10
    if not UnitExists or not UnitName then return end
    local ok,exists,enemyGuid=pcall(UnitExists,"target")
    if not ok or not exists or not enemyGuid then return end

    -- Validation is only meaningful when the selected unit is an enemy. Never
    -- treat the player, a party/raid member, or a roster pet as the threat target.
    if D.guidToActor and D.guidToActor[enemyGuid] then return end
    if UnitCanAttack then
        local okAttack,canAttack=pcall(UnitCanAttack,"player","target")
        if okAttack and not canAttack then return end
    end

    local enemyName=UnitName("target") or D.threatCalcTargetName(enemyGuid)
    local ok2,ttExists,ttGuid=pcall(UnitExists,"targettarget")
    if not ok2 then return end
    if not ttExists then ttGuid=nil end

    local currentSnapshot=D.threatValidationSnapshot(enemyGuid)
    local previousSnapshot=D.threatValidationLastSnapshot[enemyGuid] or "no previous snapshot"
    local old=D.threatValidationLastTarget[enemyGuid]
    if old~=ttGuid then
        D.threatValidationLastTarget[enemyGuid]=ttGuid
        local oldName="none"; local newName="none"
        if old and D.guidToActor and D.guidToActor[old] then oldName=D.guidToActor[old].name or old end
        if ttGuid and D.guidToActor and D.guidToActor[ttGuid] then newName=D.guidToActor[ttGuid].name or ttGuid
        elseif ttGuid then newName=UnitName("targettarget") or tostring(ttGuid) end
        local ev=D.threatValidationLastEvent and D.threatValidationLastEvent[enemyGuid]
        if ev and (now-(ev.time or 0))<=1.00 then
            D.threatCalcLog("AGGRO CHANGE | "..tostring(enemyName).." | "..tostring(oldName).." -> "..tostring(newName).." | trigger: "..tostring(ev.text).." | before event: "..tostring(ev.before).." | after event: "..tostring(ev.after).." | observed now: "..tostring(currentSnapshot).." | pull refs: melee 110%, ranged 130%")
        else
            D.threatCalcLog("AGGRO CHANGE | "..tostring(enemyName).." | "..tostring(oldName).." -> "..tostring(newName).." | before poll: "..tostring(previousSnapshot).." | observed now: "..tostring(currentSnapshot).." | no recent threat event | pull refs: melee 110%, ranged 130%")
        end
    end
    D.threatValidationLastSnapshot[enemyGuid]=currentSnapshot
end

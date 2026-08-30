-- Caw DPS Meter v1.0.1 Stability RC37 CC Segment Preserve
-- RavenCraft/Octo / WoW 1.12 + SuperWoW/SuperAPI
-- Lua 5.0 compatible. RAW_COMBATLOG based damage + utility meter.

CAW_DPS_METER = CAW_DPS_METER or {}
local D = CAW_DPS_METER
D.version = "1.0.1-rc37"
D.inCombat = false
D.startTime = 0
D.lastDuration = 0
D.rawTotal = 0
D.parsedTotal = 0
D.lastParsed = "none"
D.actors = {}
D.guidToActor = {}
D.petOwner = {}
D.history = {}
D.maxHistory = 10
D.segment = "current"
D.segmentIndex = 0
D.fightHistory = {}
D.currentEnemyDamage = {}
D.currentEnemyNames = {}
D.currentEnemyBestGuid = nil
D.currentEnemyBestDamage = 0
D.currentFightName = "Current"
D.overallSegment = {actors={}, duration=0, fights=0}
D.mode = "damage"
D.scrollOffset = 0
D.rawUnknown = {}
D.rawUnknownCount = 0
D.rawDebugEnabled = false
D.rawDebugLines = {}
D.rawDebugCount = 0
D.utilityUnknown = {}
D.utilityUnknownCount = 0
D.ignoredOutsiders = 0
D.globalUtility = {buffs={}, debuffsReceived={}, debuffsCast={}, cc={}, ccBreaks={}, interrupts={}, dispels={}}
D.recentAuraCasts = {}
D.activeAuraSources = {}
D.activeRosterBuffs = {}
D.weaponBuffState = {main=nil,off=nil}
D.pendingSelfTotem = nil
D.activeCC = {}
D.lastCCDamage = nil
D.lastCCBreak = nil
D.combatStateCheckAt = 0
D.outOfCombatSince = 0
D.weaponBuffKeywords = {
    "Poison",
    "Rockbiter",
    "Flametongue",
    "Frostbrand",
    "Windfury",
    "Shadow Oil",
    "Wizard Oil",
    "Mana Oil",
    "Sharpening Stone",
    "Weightstone"
}

D.getWeaponBuffName = function(slot,label)
    if not CreateFrame then return nil end
    if not D.weaponTooltip then
        D.weaponTooltip=CreateFrame("GameTooltip","CawDPSMeterWeaponTooltip",UIParent,"GameTooltipTemplate")
        if D.weaponTooltip.SetOwner then D.weaponTooltip:SetOwner(UIParent,"ANCHOR_NONE") end
    end

    local tt=D.weaponTooltip
    if tt.ClearLines then tt:ClearLines() end
    if not tt.SetInventoryItem then return nil end
    local ok=pcall(tt.SetInventoryItem,tt,"player",slot)
    if not ok then return nil end

    local i=1
    local n=tt.NumLines and tt:NumLines() or 0
    while i<=n do
        local fs=getglobal and getglobal("CawDPSMeterWeaponTooltipTextLeft"..tostring(i)) or nil
        local line=fs and fs.GetText and fs:GetText() or nil
        if line and line~="" then
            local k=1
            while k<=table.getn(D.weaponBuffKeywords) do
                if string.find(line,D.weaponBuffKeywords[k],1,true) then
                    local name=line
                    local _,_,trim=string.find(name,"^(.-) %(")
                    if trim and trim~="" then name=trim end
                    return label..": "..name
                end
                k=k+1
            end
        end
        i=i+1
    end
    return nil
end

D.scanWeaponBuffs = function()
    if not GetWeaponEnchantInfo then return end

    -- Remove only weapon entries; ordinary aura-scan entries stay untouched.
    local key,b
    local remove={}
    for key,b in D.activeRosterBuffs do
        if b and b.weaponBuff then table.insert(remove,key) end
    end
    local i=1
    while i<=table.getn(remove) do
        D.activeRosterBuffs[remove[i]]=nil
        i=i+1
    end

    -- Own player: preserve Vanilla/SuperWoW's original six-value form because
    -- it contains remaining duration/charges rather than enchant names.
    local ok,hasMain,mainExp,mainCharges,hasOff,offExp,offCharges=pcall(GetWeaponEnchantInfo)
    if ok then
        local mainName=nil
        local offName=nil
        if hasMain then mainName=D.getWeaponBuffName(16,"Main Hand") or "Main Hand: Weapon Enchant" end
        if hasOff then offName=D.getWeaponBuffName(17,"Off Hand") or "Off Hand: Weapon Enchant" end
        D.weaponBuffState.main=mainName
        D.weaponBuffState.off=offName
        if mainName then
            D.activeRosterBuffs["player|"..mainName]={target="player",spell=mainName,weaponBuff=true,weaponSlot="main",unit="player"}
        end
        if offName then
            D.activeRosterBuffs["player|"..offName]={target="player",spell=offName,weaponBuff=true,weaponSlot="off",unit="player"}
        end
    end

    -- SuperWoW extension: GetWeaponEnchantInfo(friendlyUnit) returns the
    -- temporary enchant NAMES for that unit's main hand and off hand.
    -- Scan only the active group roster; no name heuristics or proc inference.
    local raidCount=GetNumRaidMembers and GetNumRaidMembers() or 0
    local maxCount=raidCount
    local prefix="raid"
    if raidCount<=0 then
        maxCount=GetNumPartyMembers and GetNumPartyMembers() or 0
        prefix="party"
    end

    i=1
    while i<=maxCount do
        local unit=prefix..tostring(i)
        local exists,guid=UnitExists(unit)
        if exists and guid then
            local wok,mainEnchant,offEnchant=pcall(GetWeaponEnchantInfo,unit)
            if wok then
                if mainEnchant and mainEnchant~="" then
                    local mainName="Main Hand: "..tostring(mainEnchant)
                    D.activeRosterBuffs[tostring(guid).."|"..mainName]={target=guid,spell=mainName,weaponBuff=true,weaponSlot="main",unit=unit}
                end
                if offEnchant and offEnchant~="" then
                    local offName="Off Hand: "..tostring(offEnchant)
                    D.activeRosterBuffs[tostring(guid).."|"..offName]={target=guid,spell=offName,weaponBuff=true,weaponSlot="off",unit=unit}
                end
            end
        end
        i=i+1
    end
end

D.buffSpellNames = {
    [19740]="Blessing of Might",
    [20217]="Blessing of Kings",
    [1038]="Blessing of Salvation",
    [20911]="Blessing of Sanctuary",
    [19742]="Blessing of Wisdom",
    [19746]="Concentration Aura",
    [465]="Devotion Aura",
    [7294]="Retribution Aura",
    [19876]="Shadow Resistance Aura",
    [19888]="Frost Resistance Aura",
    [19891]="Fire Resistance Aura",
    [1243]="Power Word: Fortitude",
    [21562]="Prayer of Fortitude",
    [14752]="Divine Spirit",
    [27681]="Prayer of Spirit",
    [976]="Shadow Protection",
    [27683]="Prayer of Shadow Protection",
    [1459]="Arcane Intellect",
    [23028]="Arcane Brilliance",
    [1126]="Mark of the Wild",
    [21849]="Gift of the Wild",
    [467]="Thorns"
}

D.playerBuffScanState = {}

D.getUnitBuffName = function(unit,index,spellId)
    if spellId and D.buffSpellNames[spellId] then return D.buffSpellNames[spellId] end

    -- RavenCraft's UnitBuff exposes the spell ID as return #3 but not the
    -- localized aura name. Read the first line of Blizzard's buff tooltip so
    -- item buffs, Aspects, Paladin auras and other unknown spell IDs do not
    -- require a hardcoded lookup table.
    if not CreateFrame then return nil end
    if not D.buffScanTooltip then
        D.buffScanTooltip=CreateFrame("GameTooltip","CawDPSMeterBuffScanTooltip",UIParent,"GameTooltipTemplate")
        if D.buffScanTooltip.SetOwner then D.buffScanTooltip:SetOwner(UIParent,"ANCHOR_NONE") end
    end

    local tt=D.buffScanTooltip
    if not tt.SetUnitBuff then return nil end
    if tt.ClearLines then tt:ClearLines() end
    local ok=pcall(tt.SetUnitBuff,tt,unit,index)
    if not ok then return nil end

    local fs=getglobal and getglobal("CawDPSMeterBuffScanTooltipTextLeft1") or nil
    local name=fs and fs.GetText and fs:GetText() or nil
    if name and name~="" then
        if spellId then D.buffSpellNames[spellId]=name end
        return name
    end
    return nil
end

D.scanUnitBuffs = function(unit,targetKey,current)
    if not UnitBuff or not unit or not targetKey then return end
    local i
    for i=1,32 do
        local ok,texture,count,spellId=pcall(UnitBuff,unit,i)
        if not ok then return end
        if not texture then break end

        local name=D.getUnitBuffName(unit,i,spellId)
        if name and name~="" then
            if current then current[name]=true end
            D.activeRosterBuffs[targetKey.."|"..name]={target=targetKey,spell=name}
        end
    end
end

D.scanPlayerBuffs = function(applyLive)
    if not UnitBuff then return end

    local current={}
    D.scanUnitBuffs("player","player",current)

    if applyLive and D.inCombat then
        local pg=nil
        if UnitExists then
            local exists,guid=UnitExists("player")
            if exists and guid then pg=guid end
        end
        local ti=D.guidToActor[pg or D.selfKey]
        if ti and D.applyLivePlayerAuraDiff then
            D.applyLivePlayerAuraDiff(ti,current)
        end
    end

    D.playerBuffScanState=current
end

D.scanGroupBuffs = function()
    if not UnitBuff or not UnitExists then return end

    -- Player is kept as the stable "player" target because the live
    -- PLAYER_AURAS_CHANGED path uses that key.
    D.scanPlayerBuffs(false)

    local raidCount=GetNumRaidMembers and GetNumRaidMembers() or 0
    local i=1
    if raidCount>0 then
        while i<=raidCount do
            local unit="raid"..tostring(i)
            local exists,guid=UnitExists(unit)
            if exists and guid then D.scanUnitBuffs(unit,guid,nil) end
            i=i+1
        end
    else
        while i<=4 do
            local unit="party"..tostring(i)
            local exists,guid=UnitExists(unit)
            if exists and guid then D.scanUnitBuffs(unit,guid,nil) end
            i=i+1
        end
    end
end

D.activeEnemyCasts = {}
D.pendingSelfDispel = nil
D.recentSelfDispelCast = nil
D.lastSelfDispelRecord = nil

-- Caw Sync v1: current-fight snapshot exchange between party/raid members.
-- The sync is intentionally conservative: no per-hit network spam. A client
-- entering an already-running fight requests one cumulative snapshot and then
-- continues from its own RAW_COMBATLOG.
D.syncPrefix = "CAWDPS1"
D.syncNonce = nil
D.syncRequested = false
D.syncReceived = 0
D.syncLastSource = "none"
D.syncBestAge = 0
D.syncQueue = {}
D.syncQueueDropped = 0
D.syncQueueMax = 1000
D.syncNextSend = 0
D.syncSent = 0
D.syncAddonEvents = 0
D.syncRequestsSeen = 0
D.syncSendAttempts = 0
D.syncRequestSent = false
D.syncLastError = "none"
D.syncLastChannel = "none"
D.syncAPI = "unknown"
D.syncOffers = {}
D.syncOfferDeadline = 0
D.syncSelectedSource = nil
D.syncIncoming = nil
D.syncRejectedSources = 0

-- Short combat-end grace window:
-- keeps brief combat drops in one segment and gives Caw Sync time for one
-- final reconciliation snapshot before the fight is committed.
D.pendingCombatEndAt = 0
D.pendingCombatEndStopTime = 0
D.combatEndGrace = 1.50

local requestCombatSync = nil
local finalizeSyncOfferSelection = nil

-- Persistent settings -------------------------------------------------------
-- IMPORTANT for Vanilla 1.12/custom clients:
-- SavedVariables are guaranteed to be available only when ADDON_LOADED fires.
-- Do NOT bind a local DB reference at file-load time; otherwise the client may
-- later replace the global SavedVariables table and our local reference would
-- point at an orphan table that is never written to disk.
local DB = nil
local CharDB = nil
D.savedVariablesReady = false
D.locked = false


local function skinCawHoverTooltip(tt)
    if not tt or not tt.SetBackdrop then return end
    tt:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8",
        tile=false,
        edgeSize=1,
        insets={left=1,right=1,top=1,bottom=1}
    })
    tt:SetBackdropColor(0.035,0.035,0.045,0.97)
    tt:SetBackdropBorderColor(0.22,0.22,0.26,1)
end

local playerTooltip=nil
local function getPlayerTooltip()
    if not playerTooltip then
        playerTooltip=CreateFrame("GameTooltip","CawDPSMeterPlayerTooltip",UIParent,"GameTooltipTemplate")
        skinCawHoverTooltip(playerTooltip)
    end
    return playerTooltip
end

function D.getControlTooltip()
    if not D.controlTooltip then
        D.controlTooltip=CreateFrame("GameTooltip","CawDPSMeterControlTooltip",UIParent,"GameTooltipTemplate")
        skinCawHoverTooltip(D.controlTooltip)
    end
    return D.controlTooltip
end

local function initializeSavedVariables()
    if D.savedVariablesReady then return end
    if not CawDPSMeterDB then CawDPSMeterDB = {} end
    if not CawDPSMeterCharDB then CawDPSMeterCharDB = {} end
    DB = CawDPSMeterDB
    CharDB = CawDPSMeterCharDB

    -- One-time legacy SavedVariables migration; all active state uses CawDPSMeterDB.
    if not DB.migratedFromDetails and DetailsRavenDB then
        if DB.width == nil then DB.width = DetailsRavenDB.width end
        if DB.height == nil then DB.height = DetailsRavenDB.height end
        if DB.point == nil then DB.point = DetailsRavenDB.point end
        if DB.relativePoint == nil then DB.relativePoint = DetailsRavenDB.relativePoint end
        if DB.x == nil then DB.x = DetailsRavenDB.x end
        if DB.y == nil then DB.y = DetailsRavenDB.y end
        if DB.left == nil then DB.left = DetailsRavenDB.left end
        if DB.top == nil then DB.top = DetailsRavenDB.top end
        if DB.locked == nil then DB.locked = DetailsRavenDB.locked end
        DB.migratedFromDetails = true
    end

    if DB.locked == nil then DB.locked = false end
    D.locked = DB.locked and true or false

    -- Restore the last selected meter mode. Keep validation explicit so a
    -- stale/invalid SavedVariable can never break the mode selector.
    local savedMode=nil
    if CharDB and CharDB.mode then savedMode=CharDB.mode
    elseif DB and DB.mode then savedMode=DB.mode end
    if savedMode=="damage" or savedMode=="healing" or savedMode=="interrupts"
        or savedMode=="cc" or savedMode=="ccBreaks" or savedMode=="dispels"
        or savedMode=="buffs" or savedMode=="debuffsCast" or savedMode=="debuffsReceived" then
        D.mode=savedMode
    end

    D.savedVariablesReady = true
end


local CLASS_COLORS = {
    WARRIOR={0.78,0.61,0.43}, MAGE={0.41,0.80,0.94}, ROGUE={1.00,0.96,0.41},
    DRUID={1.00,0.49,0.04}, HUNTER={0.67,0.83,0.45}, SHAMAN={0.00,0.44,0.87},
    PRIEST={1.00,1.00,1.00}, WARLOCK={0.58,0.51,0.79}, PALADIN={0.96,0.55,0.73}
}

-- Blizzard's classic class-icon atlas. Keeping this on a built-in WoW texture
-- avoids shipping nine separate icon files and works on the 1.12 client.
local CLASS_ICON_TEXTURE="Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_ICON_TCOORDS={
    WARRIOR={0.000000,0.250000,0.000000,0.250000},
    MAGE={0.250000,0.496094,0.000000,0.250000},
    ROGUE={0.496094,0.742188,0.000000,0.250000},
    DRUID={0.742188,0.988281,0.000000,0.250000},
    HUNTER={0.000000,0.250000,0.250000,0.500000},
    SHAMAN={0.250000,0.496094,0.250000,0.500000},
    PRIEST={0.496094,0.742188,0.250000,0.500000},
    WARLOCK={0.742188,0.988281,0.250000,0.500000},
    PALADIN={0.000000,0.250000,0.500000,0.750000}
}

local CC_SPELLS = {
    ["Polymorph"]=true, ["Sap"]=true, ["Blind"]=true, ["Gouge"]=true,
    ["Fear"]=true, ["Psychic Scream"]=true, ["Intimidating Shout"]=true,
    ["Seduction"]=true, ["Banish"]=true, ["Hibernate"]=true,
    ["Freezing Trap Effect"]=true, ["Freezing Trap"]=true, ["Scatter Shot"]=true,
    ["Wyvern Sting"]=true, ["Scare Beast"]=true, ["Repentance"]=true,
    ["Entangling Roots"]=true, ["Frost Nova"]=true, ["Hammer of Justice"]=true,
    ["Cheap Shot"]=true, ["Kidney Shot"]=true, ["Bash"]=true, ["Pounce"]=true,
    ["War Stomp"]=true, ["Death Coil"]=true
}

local function chat(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter|r: " .. tostring(msg))
    end
end

local function comma(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local len = string.len(s)
    if len <= 3 then return s end
    local out = ""
    local first = len - math.floor((len - 1) / 3) * 3
    out = string.sub(s, 1, first)
    local i = first + 1
    while i <= len do out = out .. "," .. string.sub(s, i, i + 2); i = i + 3 end
    return out
end

local function clearTable(t) local k; for k in t do t[k] = nil end end
local function currentFightDuration()
    if D.startTime == 0 then return D.lastDuration or 0 end
    if D.inCombat then local t=GetTime()-D.startTime; if t<0 then t=0 end; return t end
    return D.lastDuration or 0
end
local function getSelectedHistoryFight()
    if D.segment~="history" then return nil end
    local idx=D.segmentIndex or 1
    return D.fightHistory[idx]
end
local function getDisplayActors()
    local h=getSelectedHistoryFight()
    if h and h.actors then return h.actors end
    if D.segment=="overall" and D.overallSegment and D.overallSegment.actors then return D.overallSegment.actors end
    return D.actors
end
local function getDuration()
    local h=getSelectedHistoryFight()
    if h then return h.duration or 0 end
    if D.segment=="overall" and D.overallSegment then return D.overallSegment.duration or 0 end
    return currentFightDuration()
end

local function newCounterTable() return {} end
local function newActor(key,name,guid,ownerKey,isPet,classToken)
    local a={key=key,name=name or key,guid=guid,ownerKey=ownerKey,isPet=isPet,classToken=classToken,
        damage=0,hits=0,crits=0,spells={},healing=0,heals=0,healCrits=0,healSpells={},
        buffs=newCounterTable(),debuffsReceived=newCounterTable(),debuffsCast=newCounterTable(),
        interrupts=newCounterTable(),cc=newCounterTable(),ccBreaks=newCounterTable(),dispels=newCounterTable()}
    -- Backward-compatible alias used by older tooltip/debug code.
    a.debuffs=a.debuffsReceived
    D.actors[key]=a; return a
end
local function getActor(key,name,guid,ownerKey,isPet,classToken)
    -- Damage events only contain GUIDs. Pull the class from the current party/raid
    -- roster when the caller did not explicitly pass it. This is what makes
    -- group members use their real class colour instead of the grey fallback.
    if not classToken and guid and D.guidToActor and D.guidToActor[guid] then
        classToken=D.guidToActor[guid].classToken
    end
    if not classToken and key and D.guidToActor and D.guidToActor[key] then
        classToken=D.guidToActor[key].classToken
    end
    local a=D.actors[key]; if not a then a=newActor(key,name,guid,ownerKey,isPet,classToken) end
    if name then a.name=name end; if guid then a.guid=guid end; if ownerKey then a.ownerKey=ownerKey end
    if isPet~=nil then a.isPet=isPet end; if classToken then a.classToken=classToken end
    local meta=nil
    if guid and D.guidToActor then meta=D.guidToActor[guid] end
    if not meta and key and D.guidToActor then meta=D.guidToActor[key] end
    if meta and meta.isTotem then a.isTotem=true end
    return a
end
local function addCount(tbl,name,amount)
    if not name or name=="" then name="Unknown" end
    local e=tbl[name]; if not e then e={count=0}; tbl[name]=e end
    e.count=e.count+(amount or 1); return e
end

-- Aura uptime helpers. Each aura keeps independent active timers per target so
-- multi-target debuffs can be measured without losing applications.
local function auraEntry(tbl,name)
    if not name or name=="" then name="Unknown" end
    local e=tbl[name]
    if not e then e={count=0,total=0,active={},targets={}}; tbl[name]=e end
    if not e.active then e.active={} end
    if not e.targets then e.targets={} end
    if not e.total then e.total=0 end
    if not e.count then e.count=0 end
    return e
end
local function auraClock()
    if D.inCombat then return GetTime() end
    if D.startTime and D.startTime>0 and D.lastDuration and D.lastDuration>0 then return D.startTime+D.lastDuration end
    return GetTime()
end
local function startAura(tbl,spell,targetKey)
    if not tbl or not spell then return nil end
    targetKey=targetKey or "self"
    local e=auraEntry(tbl,spell)
    if not e.active[targetKey] then
        e.active[targetKey]=auraClock()
        e.count=e.count+1
        if not e.targets then e.targets={} end
        if e.targets[targetKey]==nil then e.targets[targetKey]=0 end
    end
    return e
end
local function stopAura(tbl,spell,targetKey,stopTime)
    if not tbl or not spell then return false end
    local e=tbl[spell]; if not e or not e.active then return false end
    targetKey=targetKey or "self"
    local st=e.active[targetKey]
    if st then
        local et=stopTime or auraClock()
        if et>st then
            local delta=et-st
            e.total=(e.total or 0)+delta
            if not e.targets then e.targets={} end
            e.targets[targetKey]=(e.targets[targetKey] or 0)+delta
        end
        e.active[targetKey]=nil
        return true
    end
    return false
end
local function auraEntryDuration(e)
    if not e then return 0 end
    local total=e.total or 0; local now=auraClock(); local k,st
    if e.active then for k,st in e.active do if st and now>st then total=total+(now-st) end end end
    return total
end
local function auraTableDuration(tbl)
    local total=0; if not tbl then return 0 end; local k,e; for k,e in tbl do total=total+auraEntryDuration(e) end; return total
end
local function auraUniqueCount(tbl) local n=0; if not tbl then return 0 end; local k,e; for k,e in tbl do n=n+1 end; return n end
local function auraTargetCount(e)
    if not e then return 1 end
    local n=0; local k,v
    if e.targets then for k,v in e.targets do n=n+1 end end
    if e.active then for k,v in e.active do if not e.targets or e.targets[k]==nil then n=n+1 end end end
    if n<1 then n=1 end
    return n
end
local function auraExposureCount(tbl)
    if not tbl then return 0 end
    local n=0; local k,e
    for k,e in tbl do n=n+auraTargetCount(e) end
    return n
end
local function rememberAuraCast(sourceInfo,spell,target)
    if not sourceInfo or not spell or not target then return end
    D.recentAuraCasts[target.."|"..spell]={source=sourceInfo,time=GetTime()}
end
local function recentAuraCaster(target,spell)
    local r=D.recentAuraCasts[target.."|"..spell]; if not r then return nil end
    if GetTime()-(r.time or 0)>4 then D.recentAuraCasts[target.."|"..spell]=nil; return nil end
    return r.source
end
local function clearRecentAuraCast(target,spell)
    if not target or not spell then return end
    D.recentAuraCasts[target.."|"..spell]=nil
end
local function resetFight()
    clearTable(D.actors); D.startTime=0; D.lastDuration=0; D.parsedTotal=0; D.lastParsed="none"
    D.rawUnknown={}; D.rawUnknownCount=0; D.utilityUnknown={}; D.utilityUnknownCount=0; D.ignoredOutsiders=0
    D.globalUtility={buffs={},debuffsReceived={},debuffsCast={},cc={},ccBreaks={},interrupts={},dispels={}}
    D.pendingSelfTotem=nil
    D.activeCC={}; D.lastCCDamage=nil; D.lastCCBreak=nil
    D.combatStateCheckAt=0; D.outOfCombatSince=0
    D.recentAuraCasts={}; D.activeAuraSources={}
    D.pendingSelfDispel=nil; D.recentSelfDispelCast=nil; D.lastSelfDispelRecord=nil
    D.currentEnemyDamage={}; D.currentEnemyNames={}; D.currentEnemyBestGuid=nil; D.currentEnemyBestDamage=0; D.currentFightName="Current"
    clearTable(D.activeEnemyCasts)
    D.syncNonce=nil; D.syncRequested=false; D.syncRequestSent=false; D.syncReceived=0; D.syncLastSource="none"; D.syncBestAge=0
    D.syncLastError="none"; D.syncLastChannel="none"
    D.syncOffers={}; D.syncOfferDeadline=0; D.syncSelectedSource=nil; D.syncIncoming=nil; D.syncRejectedSources=0
    D.pendingCombatEndAt=0; D.pendingCombatEndStopTime=0
end
local function ensureStarted()
    -- A roster damage/heal event can arrive before this client receives
    -- PLAYER_REGEN_DISABLED. If the previous fight is already closed,
    -- start a fresh segment *before* counting this first RAW event.
    local opened=false
    if not D.inCombat then
        resetFight()
        D.inCombat=true
        D.startTime=GetTime()
        opened=true
        if D.seedActiveRosterBuffs then D.seedActiveRosterBuffs() end
    elseif D.startTime==0 then
        D.startTime=GetTime()
        opened=true
    end
    if opened and requestCombatSync then requestCombatSync() end
end
local function addSpell(a,spell,amount,crit)
    spell=spell or "Melee"; local s=a.spells[spell]
    if not s then s={damage=0,hits=0,crits=0}; a.spells[spell]=s end
    s.damage=s.damage+amount; s.hits=s.hits+1; if crit then s.crits=s.crits+1 end
end
local function addDamage(actorKey,actorName,guid,ownerKey,isPet,amount,spell,crit,sourceEvent)
    amount=tonumber(amount); if not amount or amount<=0 then return false end; ensureStarted()
    local a=getActor(actorKey,actorName,guid,ownerKey,isPet)
    a.damage=a.damage+amount; a.hits=a.hits+1; if crit then a.crits=a.crits+1 end
    addSpell(a,spell,amount,crit); D.parsedTotal=D.parsedTotal+1
    D.lastParsed=tostring(sourceEvent).." "..tostring(a.name).." "..tostring(spell).." +"..tostring(amount); return true
end


local function addHealSpell(a,spell,amount,crit)
    spell=spell or "Healing"; local h=a.healSpells[spell]
    if not h then h={healing=0,hits=0,crits=0}; a.healSpells[spell]=h end
    h.healing=h.healing+amount; h.hits=h.hits+1; if crit then h.crits=h.crits+1 end
end
local function addHealing(actorKey,actorName,guid,ownerKey,isPet,amount,spell,crit,sourceEvent)
    amount=tonumber(amount); if not amount or amount<=0 then return false end; ensureStarted()
    local a=getActor(actorKey,actorName,guid,ownerKey,isPet)
    a.healing=a.healing+amount; a.heals=a.heals+1; if crit then a.healCrits=a.healCrits+1 end
    addHealSpell(a,spell,amount,crit); D.parsedTotal=D.parsedTotal+1
    D.lastParsed=tostring(sourceEvent).." "..tostring(a.name).." "..tostring(spell).." +"..tostring(amount).." heal"; return true
end

local function safeUnitGUID(unit)
    if UnitExists then local ok,exists,guid=pcall(UnitExists,unit); if ok and exists and guid and guid~="" then return guid end end
    if UnitGUID then local ok,guid=pcall(UnitGUID,unit); if ok and guid and guid~="" then return guid end end
    return nil
end
local function safeUnitName(unit)
    if not unit or not UnitName then return nil end
    local ok,name=pcall(UnitName,unit)
    if ok and name and name~="" and name~="Unknown" and name~="UNKNOWN" then return name end
    return nil
end

local function enemyNameFromGUID(guid)
    if not guid then return nil end
    local name=safeUnitName(guid)
    if name then return name end
    local units={"target","mouseover","targettarget"}
    local i=1
    while i<=table.getn(units) do
        local u=units[i]
        local ug=safeUnitGUID(u)
        if ug and ug==guid then
            name=safeUnitName(u)
            if name then return name end
        end
        i=i+1
    end
    return nil
end

local function noteEnemyTarget(guid,amount)
    if not guid or not string.find(guid,"^0x") then return end
    amount=tonumber(amount) or 0

    local total=(D.currentEnemyDamage[guid] or 0)+amount
    D.currentEnemyDamage[guid]=total

    if not D.currentEnemyNames[guid] then
        D.currentEnemyNames[guid]=enemyNameFromGUID(guid)
    end

    -- Incremental dominant-target cache. Damage totals only ever increase
    -- during a segment, so a full scan of every enemy on every hit is not
    -- necessary.
    if not D.currentEnemyBestGuid or total>D.currentEnemyBestDamage then
        D.currentEnemyBestGuid=guid
        D.currentEnemyBestDamage=total
    end

    local bestGuid=D.currentEnemyBestGuid
    if bestGuid then
        local bestName=D.currentEnemyNames[bestGuid] or enemyNameFromGUID(bestGuid)
        if bestName then
            D.currentEnemyNames[bestGuid]=bestName
            D.currentFightName=bestName
        elseif D.currentFightName=="Current" then
            D.currentFightName="Unknown Enemy"
        end
    end
end

local function isHostileUnit(unit)
    if not unit or not UnitCanAttack then return false end
    local ok,hostile=pcall(UnitCanAttack,"player",unit)
    return ok and hostile and true or false
end

local function currentFightLabel()
    if D.currentFightName and D.currentFightName~="" and D.currentFightName~="Current" then return D.currentFightName end
    -- Only use the current target as a fallback when it is actually hostile.
    -- This prevents healing-only fights from being named after a friendly target.
    if isHostileUnit("target") then
        local tn=safeUnitName("target")
        if tn then return tn end
    end
    return "Current"
end

local function safeClass(unit)
    if not UnitClass then return nil end
    local ok,localized,token=pcall(UnitClass,unit)
    if not ok then return nil end
    if token and CLASS_COLORS[token] then return token end
    -- Some 1.12/SuperWoW builds only expose the localized class name.
    -- Normalize the common English return value to the class token used above.
    if localized then
        local up=string.upper(localized)
        if CLASS_COLORS[up] then return up end
        local names={Krieger="WARRIOR",Magier="MAGE",Schurke="ROGUE",Druide="DRUID",Jaeger="HUNTER",Jager="HUNTER",Schamane="SHAMAN",Priester="PRIEST",Hexenmeister="WARLOCK",Paladin="PALADIN"}
        if names[localized] then return names[localized] end
    end
    return token or localized
end
local function addRosterUnit(unit,ownerKey,isPet)
    if not UnitExists or not UnitExists(unit) then return end
    local name=UnitName(unit) or unit; local guid=safeUnitGUID(unit); local key=guid or unit
    local classToken=nil; if not isPet then classToken=safeClass(unit) end
    D.guidToActor[guid or key]={key=key,name=name,guid=guid,ownerKey=ownerKey,isPet=isPet,classToken=classToken}
    if isPet and ownerKey then D.petOwner[guid or key]=ownerKey end
end
local function refreshRoster()
    clearTable(D.guidToActor); clearTable(D.petOwner)
    local pg=safeUnitGUID("player"); local pn=UnitName("player") or "You"; local pk=pg or "player"; D.selfKey=pk
    D.guidToActor[pg or pk]={key=pk,name=pn,guid=pg,isPet=false,classToken=safeClass("player")}
    addRosterUnit("pet",pk,true)
    local i=1
    while i<=4 do local u="party"..tostring(i); if UnitExists and UnitExists(u) then
        local g=safeUnitGUID(u); local k=g or u; addRosterUnit(u,nil,false); addRosterUnit("partypet"..tostring(i),k,true)
    end; i=i+1 end
    i=1
    while i<=40 do local u="raid"..tostring(i); if UnitExists and UnitExists(u) then
        local g=safeUnitGUID(u); local k=g or u; addRosterUnit(u,nil,false); addRosterUnit("raidpet"..tostring(i),k,true)
    end; i=i+1 end
    -- Refresh metadata for actors that already exist (for example when joining
    -- a party during a session or after a roster update).
    local ak,av
    for ak,av in D.actors do
        local ri=D.guidToActor[av.guid or ak]
        if ri then
            av.name=ri.name or av.name
            av.classToken=ri.classToken or av.classToken
            av.ownerKey=ri.ownerKey or av.ownerKey
            av.isPet=ri.isPet
        end
    end
end

-- Caw Sync -----------------------------------------------------------------
local function syncChannel()
    if GetNumRaidMembers and GetNumRaidMembers()>0 then return "RAID" end
    if GetNumPartyMembers and GetNumPartyMembers()>0 then return "PARTY" end
    return nil
end

local function syncRosterSender(sender)
    if not sender or sender=="" then return false end
    local me=UnitName("player")
    if me and sender==me then return true end
    local i=1
    while i<=4 do
        local u="party"..tostring(i)
        if UnitExists and UnitExists(u) and UnitName(u)==sender then return true end
        i=i+1
    end
    i=1
    while i<=40 do
        local u="raid"..tostring(i)
        if UnitExists and UnitExists(u) and UnitName(u)==sender then return true end
        i=i+1
    end
    return false
end

local function syncField(v)
    local s=tostring(v or "")
    s=string.gsub(s,"~","/")
    s=string.gsub(s,"|","/")
    s=string.gsub(s,"\n"," ")
    return s
end

local function splitSync(msg)
    local out={}; local n=0; local pos=1
    while true do
        local a,b=string.find(msg,"~",pos,true)
        if not a then n=n+1; out[n]=string.sub(msg,pos); break end
        n=n+1; out[n]=string.sub(msg,pos,a-1); pos=b+1
    end
    return out
end

local function queueSync(message,channel,target)
    if not message or string.len(message)>240 then return end
    if table.getn(D.syncQueue)>=(D.syncQueueMax or 1000) then
        D.syncQueueDropped=(D.syncQueueDropped or 0)+1
        D.syncLastError="Sync queue limit reached"
        return
    end
    table.insert(D.syncQueue,{message=message,channel=channel,target=target})
end

local function getAddonSender()
    if type(SendAddonMessage)=="function" then
        D.syncAPI="SendAddonMessage"
        return SendAddonMessage
    end
    if C_ChatInfo and type(C_ChatInfo.SendAddonMessage)=="function" then
        D.syncAPI="C_ChatInfo.SendAddonMessage"
        return C_ChatInfo.SendAddonMessage
    end
    D.syncAPI="missing"
    return nil
end

local function sendSyncNow(message,channel,target)
    D.syncSendAttempts=(D.syncSendAttempts or 0)+1
    D.syncLastChannel=tostring(channel or "none")
    local sender=getAddonSender()
    if not sender then
        D.syncLastError="No addon-message API available"
        return false
    end
    if not channel then
        D.syncLastError="No PARTY/RAID channel available"
        return false
    end

    local ok,err
    if channel=="WHISPER" then
        ok,err=pcall(sender,D.syncPrefix,message,channel,target)
    else
        ok,err=pcall(sender,D.syncPrefix,message,channel)
    end
    if ok then
        D.syncSent=(D.syncSent or 0)+1
        D.syncLastError="none"
        return true
    end
    D.syncLastError=tostring(err or "unknown send error")
    return false
end

local function flushSyncQueue()
    if table.getn(D.syncQueue)<=0 or not getAddonSender() then return end
    local now=GetTime()
    if now<(D.syncNextSend or 0) then return end
    local item=table.remove(D.syncQueue,1)
    if item then sendSyncNow(item.message,item.channel,item.target) end
    D.syncNextSend=now+0.04
end

local function dominantEnemyGUID()
    return D.currentEnemyBestGuid or ""
end

local function buildSyncSnapshot(nonce,target)
    if not D.inCombat or not nonce or not target then return end
    local replyChannel=syncChannel()
    if not replyChannel then return end
    local age=0
    if D.startTime and D.startTime>0 then age=GetTime()-D.startTime end
    if age<0 then age=0 end

    -- Snapshot values are read now and queued immediately after the header.
    -- The receiver buffers the complete snapshot and merges it atomically at Z.
    queueSync("H~"..syncField(nonce).."~"..tostring(math.floor(age*10)).."~"..syncField(dominantEnemyGUID()).."~"..syncField(currentFightLabel()),replyChannel,nil)

    local key,a
    for key,a in D.actors do
        queueSync("A~"..syncField(nonce).."~"..syncField(a.key or key).."~"..syncField(a.name).."~"..syncField(a.guid).."~"..syncField(a.ownerKey).."~"..(a.isPet and "1" or "0").."~"..syncField(a.classToken).."~"..tostring(math.floor(a.damage or 0)).."~"..tostring(math.floor(a.healing or 0)).."~"..tostring(math.floor(a.hits or 0)).."~"..tostring(math.floor(a.crits or 0)).."~"..tostring(math.floor(a.heals or 0)).."~"..tostring(math.floor(a.healCrits or 0)),replyChannel,nil)
        local spell,s
        for spell,s in a.spells do
            queueSync("D~"..syncField(nonce).."~"..syncField(a.key or key).."~"..syncField(spell).."~"..tostring(math.floor(s.damage or 0)).."~"..tostring(math.floor(s.hits or 0)).."~"..tostring(math.floor(s.crits or 0)),replyChannel,nil)
        end
        local hname,h
        for hname,h in a.healSpells do
            queueSync("E~"..syncField(nonce).."~"..syncField(a.key or key).."~"..syncField(hname).."~"..tostring(math.floor(h.healing or 0)).."~"..tostring(math.floor(h.hits or 0)).."~"..tostring(math.floor(h.crits or 0)),replyChannel,nil)
        end
    end
    queueSync("Z~"..syncField(nonce),replyChannel,nil)
end

local function syncOfferCount()
    local n=0; local k,v
    for k,v in D.syncOffers do n=n+1 end
    return n
end

local function captureSyncBaseline()
    local base={actors={}}
    local key,a
    for key,a in D.actors do
        local b={
            damage=a.damage or 0, healing=a.healing or 0,
            hits=a.hits or 0, crits=a.crits or 0,
            heals=a.heals or 0, healCrits=a.healCrits or 0,
            spells={}, healSpells={}
        }
        local spell,s
        for spell,s in a.spells do
            b.spells[spell]={damage=s.damage or 0,hits=s.hits or 0,crits=s.crits or 0}
        end
        local hname,h
        for hname,h in a.healSpells do
            b.healSpells[hname]={healing=h.healing or 0,hits=h.hits or 0,crits=h.crits or 0}
        end
        base.actors[key]=b
    end
    return base
end

local function syncNumber(v)
    return tonumber(v) or 0
end

local function syncMergedValue(remote,baseline,current)
    remote=syncNumber(remote); baseline=syncNumber(baseline); current=syncNumber(current)
    local floorValue=baseline
    if remote>floorValue then floorValue=remote end
    local delta=current-baseline
    if delta<0 then delta=0 end
    return floorValue+delta
end

local function applyBufferedSnapshot(incoming)
    if not incoming or not incoming.actors then return false end
    local baseline=incoming.baseline or {actors={}}
    local key,r
    for key,r in incoming.actors do
        local a=getActor(key,r.name,r.guid,r.ownerKey,r.isPet,r.classToken)
        local b=baseline.actors[key] or {spells={},healSpells={}}
        a.damage=syncMergedValue(r.damage,b.damage,a.damage)
        a.healing=syncMergedValue(r.healing,b.healing,a.healing)
        a.hits=syncMergedValue(r.hits,b.hits,a.hits)
        a.crits=syncMergedValue(r.crits,b.crits,a.crits)
        a.heals=syncMergedValue(r.heals,b.heals,a.heals)
        a.healCrits=syncMergedValue(r.healCrits,b.healCrits,a.healCrits)

        local spell,rs
        for spell,rs in r.spells do
            local live=a.spells[spell]
            if not live then live={damage=0,hits=0,crits=0}; a.spells[spell]=live end
            local bs=b.spells and b.spells[spell] or nil
            if not bs then bs={damage=0,hits=0,crits=0} end
            live.damage=syncMergedValue(rs.damage,bs.damage,live.damage)
            live.hits=syncMergedValue(rs.hits,bs.hits,live.hits)
            live.crits=syncMergedValue(rs.crits,bs.crits,live.crits)
        end

        local hname,rh
        for hname,rh in r.healSpells do
            local live=a.healSpells[hname]
            if not live then live={healing=0,hits=0,crits=0}; a.healSpells[hname]=live end
            local bh=b.healSpells and b.healSpells[hname] or nil
            if not bh then bh={healing=0,hits=0,crits=0} end
            live.healing=syncMergedValue(rh.healing,bh.healing,live.healing)
            live.hits=syncMergedValue(rh.hits,bh.hits,live.hits)
            live.crits=syncMergedValue(rh.crits,bh.crits,live.crits)
        end

        -- Keep aggregate actor totals consistent with the spell breakdown
        -- after independent baseline+delta network merges.
        local sumDamage=0; local sumHits=0; local sumCrits=0
        local sn,sv
        for sn,sv in a.spells do
            sumDamage=sumDamage+(sv.damage or 0)
            sumHits=sumHits+(sv.hits or 0)
            sumCrits=sumCrits+(sv.crits or 0)
        end
        a.damage=sumDamage; a.hits=sumHits; a.crits=sumCrits

        local sumHealing=0; local sumHeals=0; local sumHealCrits=0
        for sn,sv in a.healSpells do
            sumHealing=sumHealing+(sv.healing or 0)
            sumHeals=sumHeals+(sv.hits or 0)
            sumHealCrits=sumHealCrits+(sv.crits or 0)
        end
        a.healing=sumHealing; a.heals=sumHeals; a.healCrits=sumHealCrits
    end

    -- Preserve the older source's fight age. Time spent receiving the snapshot
    -- is added so DPS/HPS duration does not become artificially short.
    local remoteAge=incoming.remoteAge or 0
    if incoming.headerReceivedAt then remoteAge=remoteAge+(GetTime()-incoming.headerReceivedAt) end
    local localAge=0
    if D.startTime and D.startTime>0 then localAge=GetTime()-D.startTime end
    if remoteAge>localAge and remoteAge>D.syncBestAge then
        D.startTime=GetTime()-remoteAge
        D.syncBestAge=remoteAge
    end
    if incoming.fightName and incoming.fightName~="" and (not D.currentFightName or D.currentFightName=="Current" or D.currentFightName=="Unknown Enemy") then
        D.currentFightName=incoming.fightName
    end
    return true
end

requestCombatSync=function(force)
    if D.syncRequested and not force then return end
    if not D.inCombat and not force then return end
    local ch=syncChannel()
    D.syncRequested=true
    D.syncRequestSent=false
    D.syncOffers={}
    D.syncOfferDeadline=0
    D.syncSelectedSource=nil
    D.syncIncoming=nil
    if not ch then
        D.syncLastError="Not in PARTY/RAID"
        D.syncLastChannel="none"
        return
    end
    D.syncNonce=tostring(math.floor(GetTime()*1000)).."-"..syncField(UnitName("player") or "player")
    if sendSyncNow("R~"..D.syncNonce,ch,nil) then
        D.syncRequestSent=true
    end
end

finalizeSyncOfferSelection=function()
    if not D.syncNonce or D.syncSelectedSource or (D.syncOfferDeadline or 0)<=0 then return end
    if GetTime()<D.syncOfferDeadline then return end

    local bestName=nil; local bestAge=-1; local name,offer
    for name,offer in D.syncOffers do
        local age=offer.age or 0
        if age>bestAge then bestAge=age; bestName=name end
    end
    D.syncOfferDeadline=0
    if not bestName then return end

    D.syncSelectedSource=bestName
    local ch=syncChannel()
    if ch then
        queueSync("P~"..syncField(D.syncNonce).."~"..syncField(bestName),ch,nil)
    end
end

local function applySyncMessage(sender,msg)
    if not syncRosterSender(sender) then return end
    local p=splitSync(msg)
    local kind=p[1]
    local selfName=UnitName("player") or ""

    -- Phase 1: responders advertise only their current fight age. This avoids
    -- every Caw client blasting a full snapshot into a raid simultaneously.
    if kind=="R" then
        D.syncRequestsSeen=(D.syncRequestsSeen or 0)+1
        local nonce=p[2]
        if sender==selfName then return end
        if nonce and D.inCombat and D.startTime and D.startTime>0 then
            local age=GetTime()-D.startTime; if age<0 then age=0 end
            local ch=syncChannel()
            if ch then
                queueSync("O~"..syncField(nonce).."~"..tostring(math.floor(age*10)).."~"..syncField(dominantEnemyGUID()).."~"..syncField(currentFightLabel()),ch,nil)
            end
        end
        return
    end

    -- Phase 2: requester gathers offers for 0.30s and then chooses the oldest
    -- available source. Other responders remain silent.
    if kind=="O" then
        if not D.syncNonce or p[2]~=D.syncNonce or sender==selfName then return end
        D.syncOffers[sender]={age=(tonumber(p[3]) or 0)/10,enemy=p[4],fightName=p[5]}
        if (D.syncOfferDeadline or 0)<=0 then D.syncOfferDeadline=GetTime()+0.30 end
        return
    end

    if kind=="P" then
        local nonce=p[2]; local selected=p[3]
        if nonce and selected and selected==selfName and sender~=selfName and D.inCombat and D.startTime and D.startTime>0 then
            buildSyncSnapshot(nonce,sender)
        end
        return
    end

    if not D.syncNonce or p[2]~=D.syncNonce then return end
    if not D.syncSelectedSource or sender~=D.syncSelectedSource then
        D.syncRejectedSources=(D.syncRejectedSources or 0)+1
        return
    end

    -- Phase 3: buffer one selected source atomically.
    if kind=="H" then
        D.syncIncoming={
            source=sender,
            remoteAge=(tonumber(p[3]) or 0)/10,
            enemy=p[4],
            fightName=p[5],
            headerReceivedAt=GetTime(),
            baseline=captureSyncBaseline(),
            actors={}
        }
        D.syncLastSource=sender
        return
    end

    local incoming=D.syncIncoming
    if not incoming or incoming.source~=sender then return end

    if kind=="A" then
        local key=p[3]; if not key or key=="" then return end
        local guid=p[5]; if guid=="" then guid=nil end
        local owner=p[6]; if owner=="" then owner=nil end
        local classToken=p[8]; if classToken=="" then classToken=nil end
        local r=incoming.actors[key]
        if not r then r={spells={},healSpells={}}; incoming.actors[key]=r end
        r.name=p[4]; r.guid=guid; r.ownerKey=owner; r.isPet=(p[7]=="1"); r.classToken=classToken
        r.damage=p[9]; r.healing=p[10]; r.hits=p[11]; r.crits=p[12]; r.heals=p[13]; r.healCrits=p[14]
        return
    end

    if kind=="D" then
        local key=p[3]; local spell=p[4]; if not key or not spell then return end
        local r=incoming.actors[key]
        if not r then r={spells={},healSpells={}}; incoming.actors[key]=r end
        r.spells[spell]={damage=p[5],hits=p[6],crits=p[7]}
        return
    end

    if kind=="E" then
        local key=p[3]; local spell=p[4]; if not key or not spell then return end
        local r=incoming.actors[key]
        if not r then r={spells={},healSpells={}}; incoming.actors[key]=r end
        r.healSpells[spell]={healing=p[5],hits=p[6],crits=p[7]}
        return
    end

    if kind=="Z" then
        if applyBufferedSnapshot(incoming) then
            D.syncReceived=(D.syncReceived or 0)+1
            D.syncLastSource=sender
        end
        D.syncIncoming=nil
        return
    end
end

local function actorFromSourceToken(token)
    if token=="You" or token=="your" or token=="Your" then return D.guidToActor[safeUnitGUID("player") or D.selfKey] end
    return D.guidToActor[token]
end
local function ignoreOutsideRoster(source)
    if source and string.find(source,"^0x") and not D.guidToActor[source] then D.ignoredOutsiders=D.ignoredOutsiders+1; return true end
    return false
end
local function isCritText(text)
    if string.find(text," crits ",1,true) or string.find(text," crit ",1,true) or string.find(text," critically ",1,true) then return true end
    return false
end
local function ringCapture(tbl,countField,ev,text)
    D[countField]=D[countField]+1; local idx=math.mod(D[countField]-1,20)+1; tbl[idx]=tostring(ev).." | "..tostring(text)
end
local function captureUnknown(ev,text) ringCapture(D.rawUnknown,"rawUnknownCount",ev,text) end
local function captureUtilityUnknown(ev,text) ringCapture(D.utilityUnknown,"utilityUnknownCount",ev,text) end

local function captureRawDebug(ev,text)
    if not D.rawDebugEnabled then return end
    D.rawDebugCount=D.rawDebugCount+1
    if D.rawDebugCount<=80 then
        D.rawDebugLines[D.rawDebugCount]=tostring(ev).." | "..tostring(text)
    end
end

-- Interrupt abilities supported by the Vanilla/RavenCraft ruleset.
-- RAW_COMBATLOG often does not emit a separate "interrupts" line, so a landed
-- interrupt ability is correlated with the target's current "begins to cast" entry.
local INTERRUPT_SPELLS = {
    ["Kick"]=true,
    ["Pummel"]=true,
    ["Shield Bash"]=true,
    ["Counterspell"]=true,
    ["Earth Shock"]=true,
    ["Feral Charge"]=true,
    ["Feral Charge - Bear"]=true,
    ["Spell Lock"]=true,
    ["Silence"]=true
}

-- Common Vanilla/RavenCraft dispel/cleanse abilities. RavenCraft can log a
-- successful self-dispel as "Your <aura> is removed." followed by "You cast X."
-- rather than an explicit "X dispels Y" combat-log line.
local DISPEL_SPELLS = {
    ["Purify"]=true,
    ["Cleanse"]=true,
    ["Dispel Magic"]=true,
    ["Purge"]=true,
    ["Remove Curse"]=true,
    ["Remove Lesser Curse"]=true,
    ["Abolish Disease"]=true,
    ["Cure Disease"]=true,
    ["Abolish Poison"]=true,
    ["Cure Poison"]=true,
    ["Devour Magic"]=true
}

local function rememberEnemyCast(target,spell)
    if not target or not spell then return end
    D.activeEnemyCasts[target]={spell=spell,time=GetTime()}
end
local function clearEnemyCast(target)
    if target then D.activeEnemyCasts[target]=nil end
end
local function clearEnemyCastOnResult(source,spell)
    if not source or not spell then return end
    local cast=D.activeEnemyCasts[source]
    if cast and cast.spell==spell then D.activeEnemyCasts[source]=nil end
end

local function utilityActor(info)
    if not info then return nil end
    return getActor(info.key,info.name,info.guid,info.ownerKey,info.isPet,info.classToken)
end

D.tryClaimSelfTotemSource = function(source,spell,ev)
    if not source or not spell or ev~="CHAT_MSG_SPELL_PET_DAMAGE" then return nil end
    if D.guidToActor[source] then return D.guidToActor[source] end

    local p=D.pendingSelfTotem
    if not p or not p.time or (GetTime()-p.time)>12 then return nil end

    local owner=D.guidToActor[safeUnitGUID("player") or D.selfKey]
    if not owner then return nil end

    local info={
        key=source,
        name=p.name or "Totem",
        guid=source,
        ownerKey=owner.key,
        isPet=true,
        classToken=nil,
        isTotem=true
    }
    D.guidToActor[source]=info
    D.petOwner[source]=owner.key
    D.pendingSelfTotem=nil
    return info
end

D.applyLivePlayerAuraDiff = function(ti,current)
    if not ti or not current then return end
    local a=utilityActor(ti)
    local tk=a and (a.guid or a.key) or nil
    if not a or not tk then return end

    local name,v
    for name,v in current do
        if not D.playerBuffScanState[name] then startAura(a.buffs,name,tk) end
    end
    for name,v in D.playerBuffScanState do
        if not current[name] then
            stopAura(a.buffs,name,tk)
            D.activeRosterBuffs["player|"..name]=nil
        end
    end
end
local function recordUtility(kind,sourceInfo,spell,targetToken)
    ensureStarted(); local targetInfo=targetToken and D.guidToActor[targetToken] or nil
    local a=utilityActor(sourceInfo)
    if a and a[kind] then addCount(a[kind],spell,1) else addCount(D.globalUtility[kind],spell,1) end
    D.lastUtility=(a and a.name or "Global").." "..kind.." "..tostring(spell)..(targetInfo and (" -> "..targetInfo.name) or "")
    return true
end

D.handleUnitCastCC = function(casterGUID,targetGUID,eventType,spellId)
    if not casterGUID or not targetGUID or not eventType or not spellId then return end
    if eventType~="CAST" then return end
    if not SpellInfo then return end

    local ok,spell=pcall(SpellInfo,spellId)
    if not ok or not spell or not CC_SPELLS[spell] then return end

    local si=actorFromSourceToken(casterGUID)
    if not si then return end

    -- UNIT_CASTEVENT supplies the source GUID that the RAW aura line lacks.
    -- Do not count here: the actual "is afflicted by" line proves the CC landed
    -- and avoids counting resisted/immune/failed casts.
    rememberAuraCast(si,spell,targetGUID)
end

D.captureCCDamageCandidate = function(ev,text)
    if not D.inCombat or not ev or not text then return end

    local source=nil
    local target=nil

    -- Self melee/spell damage.
    local _,_,selfTarget=string.find(text,"^You hit (0x[%x]+) for ")
    if not selfTarget then _,_,selfTarget=string.find(text,"^You crit (0x[%x]+) for ") end
    if not selfTarget then _,_,selfTarget=string.find(text,"^Your .- hits (0x[%x]+) for ") end
    if not selfTarget then _,_,selfTarget=string.find(text,"^Your .- crits (0x[%x]+) for ") end
    if selfTarget then
        source=D.guidToActor[safeUnitGUID("player") or D.selfKey]
        target=selfTarget
    else
        -- Group melee/spell damage. This is deliberately roster-only.
        local _,_,guid,guidTarget=string.find(text,"^(0x[%x]+) hits (0x[%x]+) for ")
        if not guid then _,_,guid,guidTarget=string.find(text,"^(0x[%x]+) crits (0x[%x]+) for ") end
        if not guid then _,_,guid,guidTarget=string.find(text,"^(0x[%x]+)'s .- hits (0x[%x]+) for ") end
        if not guid then _,_,guid,guidTarget=string.find(text,"^(0x[%x]+)'s .- crits (0x[%x]+) for ") end
        if guid then
            source=actorFromSourceToken(guid)
            target=guidTarget
        end
    end

    if source and target then
        D.lastCCDamage={source=source,target=target,time=GetTime()}
    end
end

local function tryRecordInterrupt(sourceInfo,ability,target)
    if not sourceInfo or not ability or not target or not INTERRUPT_SPELLS[ability] then return false end
    local cast=D.activeEnemyCasts[target]
    if not cast then return false end
    local age=GetTime()-(cast.time or 0)
    if age<0 or age>8 then
        D.activeEnemyCasts[target]=nil
        return false
    end
    local interruptedSpell=cast.spell or "Unknown Spell"
    D.activeEnemyCasts[target]=nil
    return recordUtility("interrupts",sourceInfo,interruptedSpell,target)
end

local function parseSelf(ev,text)
    local crit=isCritText(text); local _,_,amount; local spell

    if ev=="CHAT_MSG_SPELL_SELF_BUFF" then
        local _,_,totemName=string.find(text,"^You cast (.- Totem)%.")
        if totemName then
            D.pendingSelfTotem={name=totemName,time=GetTime()}
            return false
        end
    end
    if ev=="CHAT_MSG_COMBAT_SELF_HITS" then
        local target
        _,_,target,amount=string.find(text,"^You hit (0x[%x]+) for ([0-9]+)")
        if not amount then _,_,target,amount=string.find(text,"^You crit (0x[%x]+) for ([0-9]+)") end
        if not amount then _,_,amount=string.find(text," for ([0-9]+)") end
        if amount then if target then noteEnemyTarget(target,amount) end; return addDamage(D.selfKey,UnitName("player") or "You",safeUnitGUID("player"),nil,false,amount,"Melee",crit,ev) end
    elseif ev=="CHAT_MSG_SPELL_SELF_DAMAGE" then
        local target
        _,_,spell,target,amount=string.find(text,"Your (.-) hits (0x[%x]+) for ([0-9]+)")
        if not amount then _,_,spell,target,amount=string.find(text,"Your (.-) crits (0x[%x]+) for ([0-9]+)") end
        if amount then noteEnemyTarget(target,amount); local si=D.guidToActor[safeUnitGUID("player") or D.selfKey]; if si then rememberAuraCast(si,spell,target); tryRecordInterrupt(si,spell,target) end; return addDamage(D.selfKey,UnitName("player") or "You",safeUnitGUID("player"),nil,false,amount,spell or "Spell",crit,ev) end
    elseif ev=="CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
        local target
        _,_,target,amount,spell=string.find(text,"^(0x[%x]+) suffers ([0-9]+) .- damage from your (.-)%.")
        if amount then noteEnemyTarget(target,amount); local si=D.guidToActor[safeUnitGUID("player") or D.selfKey]; if si then rememberAuraCast(si,spell,target); local a=utilityActor(si); startAura(a.debuffsCast,spell,target); D.activeAuraSources[target.."|"..spell]=a.key end; return addDamage(D.selfKey,UnitName("player") or "You",safeUnitGUID("player"),nil,false,amount,spell or "DoT",false,ev) end
    elseif ev=="CHAT_MSG_COMBAT_PET_HITS" or ev=="CHAT_MSG_SPELL_PET_DAMAGE" then
        local pg=safeUnitGUID("pet"); local pi=D.guidToActor[pg or "pet"]; if not pi then return false end
        local target
        _,_,target,amount=string.find(text," (0x[%x]+) for ([0-9]+)")
        if not amount then _,_,amount=string.find(text," for ([0-9]+)") end
        if amount then
            if target then noteEnemyTarget(target,amount) end
            spell="Melee"; local _,_,s=string.find(text,"'s (.-) hits "); if s then spell=s end
            local _,_,cs=string.find(text,"'s (.-) crits "); if cs then spell=cs end
            return addDamage(pi.key,pi.name,pi.guid,pi.ownerKey,true,amount,spell,crit,ev)
        end
    end
    return false
end
local function parseGeneric(ev,text)
    local crit=isCritText(text); local _,_,source,spell,amount
    local meleeTarget
    _,_,source,meleeTarget,amount=string.find(text,"^(0x[%x]+) hits (0x[%x]+) for ([0-9]+)")
    if not amount then _,_,source,meleeTarget,amount=string.find(text,"^(0x[%x]+) crits (0x[%x]+) for ([0-9]+)") end
    if amount then local a=actorFromSourceToken(source); if a then noteEnemyTarget(meleeTarget,amount); return addDamage(a.key,a.name,a.guid,a.ownerKey,a.isPet,amount,"Melee",crit,ev) end; if ignoreOutsideRoster(source) then return true end end
    local hitTarget
    _,_,source,spell,hitTarget,amount=string.find(text,"^(0x[%x]+)'s (.-) hits (0x[%x]+) for ([0-9]+)")
    if not amount then _,_,source,spell,hitTarget,amount=string.find(text,"^(0x[%x]+)'s (.-) crits (0x[%x]+) for ([0-9]+)") end
    if amount then
        local a=actorFromSourceToken(source)
        if not a and D.tryClaimSelfTotemSource then a=D.tryClaimSelfTotemSource(source,spell,ev) end
        if a then
            noteEnemyTarget(hitTarget,amount)
            rememberAuraCast(a,spell,hitTarget)
            tryRecordInterrupt(a,spell,hitTarget)
            return addDamage(a.key,a.name,a.guid,a.ownerKey,a.isPet,amount,spell,crit,ev)
        end
        if ignoreOutsideRoster(source) then return true end
    end
    local target
    _,_,target,amount,source,spell=string.find(text,"^(0x[%x]+) suffers ([0-9]+) .- damage from (0x[%x]+)'s (.-)%.")
    if amount then local a=actorFromSourceToken(source); if a then noteEnemyTarget(target,amount); rememberAuraCast(a,spell,target); local aa=utilityActor(a); startAura(aa.debuffsCast,spell,target); D.activeAuraSources[target.."|"..spell]=aa.key; return addDamage(a.key,a.name,a.guid,a.ownerKey,a.isPet,amount,spell,false,ev) end; if ignoreOutsideRoster(source) then return true end end
    return false
end


local function parseHealing(ev,text)
    local crit=isCritText(text); local _,_,source,spell,target,amount

    -- Self direct heals. Check the critical form first: the generic
    -- "heals" pattern would otherwise capture "Spell critically" as the name.
    _,_,spell,amount=string.find(text,"^Your (.-) critically heals .- for ([0-9]+)")
    if not amount then _,_,spell,amount=string.find(text,"^Your (.-) heals .- for ([0-9]+)") end
    if amount then return addHealing(D.selfKey,UnitName("player") or "You",safeUnitGUID("player"),nil,false,amount,spell,crit,ev) end

    -- Generic direct heals from a player/pet GUID.
    _,_,source,spell,target,amount=string.find(text,"^(0x[%x]+)'s (.-) critically heals (0x[%x]+) for ([0-9]+)")
    if not amount then _,_,source,spell,target,amount=string.find(text,"^(0x[%x]+)'s (.-) heals (0x[%x]+) for ([0-9]+)") end
    if amount then
        local a=actorFromSourceToken(source); if a then return addHealing(a.key,a.name,a.guid,a.ownerKey,a.isPet,amount,spell,crit,ev) end
        if ignoreOutsideRoster(source) then return true end
    end

    -- HoT forms: target gains 123 health from source's Rejuvenation.
    _,_,target,amount,source,spell=string.find(text,"^(0x[%x]+) gains ([0-9]+) health from (0x[%x]+)'s (.-)%.")
    if amount then
        local a=actorFromSourceToken(source); if a then return addHealing(a.key,a.name,a.guid,a.ownerKey,a.isPet,amount,spell,false,ev) end
        if ignoreOutsideRoster(source) then return true end
    end

    -- Your HoT on anyone / yourself.
    _,_,target,amount,spell=string.find(text,"^(0x[%x]+) gains ([0-9]+) health from your (.-)%.")
    if amount then return addHealing(D.selfKey,UnitName("player") or "You",safeUnitGUID("player"),nil,false,amount,spell,false,ev) end
    _,_,amount,spell=string.find(text,"^You gain ([0-9]+) health from your (.-)%.")
    if amount then return addHealing(D.selfKey,UnitName("player") or "You",safeUnitGUID("player"),nil,false,amount,spell,false,ev) end

    -- Some 1.12 clients phrase self-target direct heals as 'Your X heals you for N'.
    _,_,spell,amount=string.find(text,"^Your (.-) critically heals you for ([0-9]+)")
    if not amount then _,_,spell,amount=string.find(text,"^Your (.-) heals you for ([0-9]+)") end
    if amount then return addHealing(D.selfKey,UnitName("player") or "You",safeUnitGUID("player"),nil,false,amount,spell,crit,ev) end

    if string.find(ev,"HEAL",1,true) then captureUtilityUnknown(ev,text) end
    return false
end

local function selfSourceInfo()
    return D.guidToActor[safeUnitGUID("player") or D.selfKey]
end

local function selfDispelAlreadyRecorded(spell,aura)
    local r=D.lastSelfDispelRecord
    if not r then return false end
    if GetTime()-(r.time or 0)>0.75 then return false end
    return r.spell==spell and r.aura==aura
end

local function recordSelfDispel(spell,aura)
    if not spell or not DISPEL_SPELLS[spell] then return false end
    if selfDispelAlreadyRecorded(spell,aura) then return true end
    local si=selfSourceInfo()
    if not si then return false end
    D.lastSelfDispelRecord={spell=spell,aura=aura,time=GetTime()}
    return recordUtility("dispels",si,spell,si.guid or si.key)
end

-- Utility parser. Vanilla combat log formats vary; source-GUID formats get actor attribution,
-- target-only aura lines are still tracked globally/at target and kept diagnosable.
D.seedActiveRosterBuffs = function()
    if D.scanGroupBuffs then D.scanGroupBuffs() else D.scanPlayerBuffs(false) end
    D.scanWeaponBuffs()
    local key,b
    for key,b in D.activeRosterBuffs do
        if b and b.target and b.spell then
            local targetKey=b.target
            local ti=nil
            if targetKey=="player" then
                local pg=safeUnitGUID("player")
                ti=D.guidToActor[pg or D.selfKey]
                if ti then targetKey=ti.guid or ti.key end
            else
                ti=D.guidToActor[targetKey]
            end
            if ti then
                local a=utilityActor(ti)
                if a then startAura(a.buffs,b.spell,targetKey) end
            end
        end
    end
end

D.updateWeaponBuffs = function()
    if not D.inCombat or not GetWeaponEnchantInfo then return end

    -- Snapshot the current weapon cache, rebuild it for the full friendly
    -- roster, then apply only the actual additions/removals to aura uptime.
    local old={}
    local key,b
    for key,b in D.activeRosterBuffs do
        if b and b.weaponBuff then old[key]=b end
    end

    D.scanWeaponBuffs()

    for key,b in old do
        if not D.activeRosterBuffs[key] and b and b.target and b.spell then
            local ti=nil
            local tk=b.target
            if tk=="player" then
                local pg=safeUnitGUID("player")
                ti=D.guidToActor[pg or D.selfKey]
                if ti then tk=ti.guid or ti.key end
            else
                ti=D.guidToActor[tk]
            end
            if ti then
                local a=utilityActor(ti)
                if a then stopAura(a.buffs,b.spell,tk) end
            end
        end
    end

    for key,b in D.activeRosterBuffs do
        if b and b.weaponBuff and not old[key] and b.target and b.spell then
            local ti=nil
            local tk=b.target
            if tk=="player" then
                local pg=safeUnitGUID("player")
                ti=D.guidToActor[pg or D.selfKey]
                if ti then tk=ti.guid or ti.key end
            else
                ti=D.guidToActor[tk]
            end
            if ti then
                local a=utilityActor(ti)
                if a then startAura(a.buffs,b.spell,tk) end
            end
        end
    end
end


local function parseUtility(ev,text)
    local _,_,source,spell,target,removed

    -- Enemy cast start, e.g. "0xF130... begins to cast Lizard Bolt."
    _,_,target,spell=string.find(text,"^(0x[%x]+) begins to cast (.-)%.")
    if target and spell then
        rememberEnemyCast(target,spell)
        return true
    end

    -- Failed interrupt attempts must never count. More importantly, they also
    -- invalidate the remembered cast so a later successful Kick/Pummel cannot
    -- be incorrectly credited to this old cast.
    _,_,spell,target=string.find(text,"^Your (.-) misses (0x[%x]+)%.")
    if not spell then _,_,spell,target=string.find(text,"^Your (.-) was dodged by (0x[%x]+)%.") end
    if not spell then _,_,spell,target=string.find(text,"^Your (.-) was parried by (0x[%x]+)%.") end
    if not spell then _,_,spell,target=string.find(text,"^Your (.-) was resisted by (0x[%x]+)%.") end
    if not spell then _,_,spell,target=string.find(text,"^Your (.-) is resisted by (0x[%x]+)%.") end
    if spell and target then
        local si=D.guidToActor[safeUnitGUID("player") or D.selfKey]
        if INTERRUPT_SPELLS[spell] then clearEnemyCast(target) end
        clearRecentAuraCast(target,spell)
        if si then return true end
    end

    _,_,source,spell,target=string.find(text,"^(0x[%x]+)'s (.-) misses (0x[%x]+)%.")
    if not source then _,_,source,spell,target=string.find(text,"^(0x[%x]+)'s (.-) was dodged by (0x[%x]+)%.") end
    if not source then _,_,source,spell,target=string.find(text,"^(0x[%x]+)'s (.-) was parried by (0x[%x]+)%.") end
    if not source then _,_,source,spell,target=string.find(text,"^(0x[%x]+)'s (.-) was resisted by (0x[%x]+)%.") end
    if not source then _,_,source,spell,target=string.find(text,"^(0x[%x]+)'s (.-) is resisted by (0x[%x]+)%.") end
    if source and spell and target then
        local si=actorFromSourceToken(source)
        if si then
            if INTERRUPT_SPELLS[spell] then clearEnemyCast(target) end
            clearRecentAuraCast(target,spell)
            return true
        end
        if ignoreOutsideRoster(source) then return true end
    end

    -- Non-damaging interrupt abilities such as Counterspell/Spell Lock can
    -- appear as a plain hit without a numeric damage amount.
    _,_,spell,target=string.find(text,"^Your (.-) hits (0x[%x]+)%.")
    if spell and target and INTERRUPT_SPELLS[spell] then
        local si=D.guidToActor[safeUnitGUID("player") or D.selfKey]
        if si then tryRecordInterrupt(si,spell,target); return true end
    end
    _,_,source,spell,target=string.find(text,"^(0x[%x]+)'s (.-) hits (0x[%x]+)%.")
    if source and spell and INTERRUPT_SPELLS[spell] then
        local si=actorFromSourceToken(source)
        if si then tryRecordInterrupt(si,spell,target); return true end
        if ignoreOutsideRoster(source) then return true end
    end
    -- Interrupts: GUID's Kick interrupts GUID's Spell.
    _,_,source,spell,target=string.find(text,"^(0x[%x]+)'s (.-) interrupts (0x[%x]+)'s .-%.")
    if source then local si=actorFromSourceToken(source); if si then return recordUtility("interrupts",si,spell,target) end; if ignoreOutsideRoster(source) then return true end end
    _,_,source,spell,target=string.find(text,"^(0x[%x]+)'s (.-) interrupts (0x[%x]+)%.")
    if source then local si=actorFromSourceToken(source); if si then return recordUtility("interrupts",si,spell,target) end; if ignoreOutsideRoster(source) then return true end end

    -- RavenCraft self-dispel form observed live:
    -- CHAT_MSG_SPELL_BREAK_AURA | Your Decayed Strength is removed.
    -- followed immediately by one or more duplicate "You cast Purify." lines.
    local removedAura
    _,_,removedAura=string.find(text,"^Your (.-) is removed%.")
    if removedAura and ev=="CHAT_MSG_SPELL_BREAK_AURA" then
        local recent=D.recentSelfDispelCast
        if recent and GetTime()-(recent.time or 0)<=1.0 and DISPEL_SPELLS[recent.spell] then
            D.recentSelfDispelCast=nil
            return recordSelfDispel(recent.spell,removedAura)
        end
        D.pendingSelfDispel={aura=removedAura,time=GetTime()}
        return true
    end

    _,_,spell=string.find(text,"^You cast (.-)%.")
    if spell and DISPEL_SPELLS[spell] then
        local pending=D.pendingSelfDispel
        if pending and GetTime()-(pending.time or 0)<=1.0 then
            D.pendingSelfDispel=nil
            D.recentSelfDispelCast=nil
            return recordSelfDispel(spell,pending.aura)
        end
        -- Keep a short reverse-order cache as some RavenCraft spell logs can
        -- arrive before the corresponding BREAK_AURA line.
        D.recentSelfDispelCast={spell=spell,time=GetTime()}
        return true
    end

    -- Explicit dispel/remove forms with source.
    _,_,source,spell,target,removed=string.find(text,"^(0x[%x]+)'s (.-) removes (.-) from (0x[%x]+)%.")
    if source then local si=actorFromSourceToken(source); if si then return recordUtility("dispels",si,spell,target) end; if ignoreOutsideRoster(source) then return true end end
    _,_,source,spell,target=string.find(text,"^(0x[%x]+)'s (.-) dispels (.-) from (0x[%x]+)%.")
    if source then local si=actorFromSourceToken(source); if si then return recordUtility("dispels",si,spell,target) end; if ignoreOutsideRoster(source) then return true end end

    -- Casts are cached for a few seconds. Vanilla aura-application messages often
    -- omit the caster, so the subsequent 'is afflicted by' line is correlated
    -- back to this source/target/spell tuple.
    _,_,spell,target=string.find(text,"^You cast (.-) on (0x[%x]+)%.")
    if spell and target then local si=D.guidToActor[safeUnitGUID("player") or D.selfKey]; if si then rememberAuraCast(si,spell,target); if CC_SPELLS[spell] then recordUtility("cc",si,spell,target) end; return true end end
    _,_,source,spell,target=string.find(text,"^(0x[%x]+) casts (.-) on (0x[%x]+)%.")
    if source then
        local si=actorFromSourceToken(source)
        if si then rememberAuraCast(si,spell,target); if CC_SPELLS[spell] then recordUtility("cc",si,spell,target) end; return true end
        if ignoreOutsideRoster(source) then return true end
    end
    _,_,source,spell,target=string.find(text,"^(0x[%x]+)'s (.-) hits (0x[%x]+)%.")
    if source and CC_SPELLS[spell] then local si=actorFromSourceToken(source); if si then rememberAuraCast(si,spell,target); return recordUtility("cc",si,spell,target) end; if ignoreOutsideRoster(source) then return true end end

    -- Helpful aura gained by a roster member. RavenCraft uses *_BUFFS (plural)
    -- for lines such as "You gain Blessing of Might.". Only parse "gain" as a
    -- buff when the RAW subtype itself is a buff event, so XP gain cannot leak
    -- into Buff Uptime.
    if ev and string.find(ev,"_BUFF",1,true) then
        _,_,target,spell=string.find(text,"^(0x[%x]+) gains (.-)%.")
        if target and spell then
            local ti=D.guidToActor[target]
            if ti then
                D.activeRosterBuffs[target.."|"..spell]={target=target,spell=spell}
                if D.inCombat then
                    local ta=utilityActor(ti); startAura(ta.buffs,spell,target); D.lastUtility=ta.name.." buff "..spell
                end
            end
            return true
        end
        _,_,spell=string.find(text,"^You gain (.-)%.")
        if spell then
            -- Resource gains are not buffs.
            if string.find(spell,"^[0-9]+ Mana from ") or string.find(spell,"^[0-9]+ Rage from ") or string.find(spell,"^[0-9]+ Energy from ") then
                return true
            end

            -- RavenCraft stack updates arrive as separate names such as
            -- "Zeal (2)" / "Zeal (3)". Keep one aura entry instead.
            local _,_,baseSpell=string.find(spell,"^(.-) %([0-9]+%)$")
            if baseSpell then spell=baseSpell end

            D.activeRosterBuffs["player|"..spell]={target="player",spell=spell}
            if D.inCombat then
                local si=D.guidToActor[safeUnitGUID("player") or D.selfKey]
                if si then
                    local a=utilityActor(si); local tk=a.guid or a.key
                    startAura(a.buffs,spell,tk); D.lastUtility=a.name.." buff "..spell
                end
            end
            return true
        end
    end

    -- Harmful aura applied. Always track it as Received when the target is in
    -- our roster, and as Cast when a recent source can be correlated.
    _,_,target,spell=string.find(text,"^(0x[%x]+) is afflicted by (.-)%.")
    if target and spell then
        local ti=D.guidToActor[target]
        if ti then local ta=utilityActor(ti); startAura(ta.debuffsReceived,spell,target) end
        local si=recentAuraCaster(target,spell)
        if si then
            local sa=utilityActor(si); startAura(sa.debuffsCast,spell,target); D.activeAuraSources[target.."|"..spell]=sa.key
            clearRecentAuraCast(target,spell)
            if CC_SPELLS[spell] then
                addCount(sa.cc,spell,1)
                D.activeCC[target]={spell=spell,sourceKey=sa.key,time=GetTime()}
            end
        end
        if not ti and not si then addCount(D.globalUtility.debuffsReceived,spell,1) end
        D.lastUtility=(si and si.name or "Unknown").." debuff "..spell
        return true
    end
    _,_,spell=string.find(text,"^You are afflicted by (.-)%.")
    if spell then local si=D.guidToActor[safeUnitGUID("player") or D.selfKey]; if si then local a=utilityActor(si); startAura(a.debuffsReceived,spell,a.guid or a.key) end; if CC_SPELLS[spell] then addCount(D.globalUtility.cc,spell,1) end; return true end

    -- Aura fades. Close both the target-side timer and the source-side Debuffs
    -- Cast timer when we know who applied it.
    _,_,spell,target=string.find(text,"^(.-) fades from (0x[%x]+)%.")
    if spell and target then
        local ti=D.guidToActor[target]
        if ti then D.activeRosterBuffs[target.."|"..spell]=nil; local ta=utilityActor(ti); stopAura(ta.buffs,spell,target); stopAura(ta.debuffsReceived,spell,target) end
        local sourceKey=D.activeAuraSources[target.."|"..spell]
        if sourceKey and D.actors[sourceKey] then stopAura(D.actors[sourceKey].debuffsCast,spell,target); D.activeAuraSources[target.."|"..spell]=nil end
        if CC_SPELLS[spell] then
            local active=D.activeCC[target]
            local hit=D.lastCCDamage
            if active and hit and hit.target==target and GetTime()-(hit.time or 0)<=0.75 then
                local breaker=utilityActor(hit.source)
                if breaker then
                    addCount(breaker.ccBreaks,spell,1)
                    D.lastUtility=breaker.name.." ccBreaks "..spell
                    D.lastCCBreak=breaker.name.." | "..spell.." | "..target
                else
                    addCount(D.globalUtility.ccBreaks,spell,1)
                    D.lastCCBreak="Global | "..spell.." | "..target
                end
            end
            D.activeCC[target]=nil
        end
        return true
    end
    _,_,spell=string.find(text,"^(.-) fades from you%.")
    if spell then local _,_,baseSpell=string.find(spell,"^(.-) %([0-9]+%)$"); if baseSpell then spell=baseSpell end; D.activeRosterBuffs["player|"..spell]=nil; local si=D.guidToActor[safeUnitGUID("player") or D.selfKey]; if si then local a=utilityActor(si); local tk=a.guid or a.key; D.activeRosterBuffs[tk.."|"..spell]=nil; stopAura(a.buffs,spell,tk); stopAura(a.debuffsReceived,spell,tk) end; if CC_SPELLS[spell] and ev=="CHAT_MSG_SPELL_BREAK_AURA" then addCount(D.globalUtility.ccBreaks,spell,1) end; return true end

    if string.find(ev,"AURA",1,true) or string.find(ev,"BUFF",1,true) or string.find(ev,"PERIODIC",1,true) or string.find(ev,"BREAK",1,true) then captureUtilityUnknown(ev,text) end
    return false
end

local function parseRaw(rawEvent,text)
    if not text then return end
    local ev=rawEvent or ""

    -- Conservative dispatch: only specialize event families whose purpose is
    -- unambiguous. Unknown/custom RavenCraft events still use the exact proven
    -- full parser chain at the bottom.
    if string.find(ev,"HEAL",1,true) then
        if parseHealing(ev,text) then return end
        if parseUtility(ev,text) then return end
        if parseSelf(ev,text) then return end
        parseGeneric(ev,text)
        return
    end

    if string.find(ev,"AURA_GONE",1,true)
        or string.find(ev,"BREAK_AURA",1,true)
        or string.find(ev,"_BUFF",1,true) then
        if parseUtility(ev,text) then return end
        if parseSelf(ev,text) then return end
        if parseGeneric(ev,text) then return end
        parseHealing(ev,text)
        return
    end

    if string.find(ev,"COMBAT_SELF_HITS",1,true)
        or string.find(ev,"SPELL_SELF_DAMAGE",1,true)
        or string.find(ev,"COMBAT_PET_HITS",1,true) then
        if parseSelf(ev,text) then return end
        if parseGeneric(ev,text) then return end
        parseUtility(ev,text)
        return
    end

    if string.find(ev,"FRIENDLYPLAYER_HITS",1,true)
        or string.find(ev,"CREATURE_VS_CREATURE_DAMAGE",1,true)
        or string.find(ev,"PERIODIC_CREATURE_DAMAGE",1,true) then
        if parseGeneric(ev,text) then return end
        if parseSelf(ev,text) then return end
        parseUtility(ev,text)
        return
    end

    -- Exact RC18 fallback for every unknown/custom subtype.
    if parseSelf(ev,text) then return end
    if parseGeneric(ev,text) then return end
    if parseHealing(ev,text) then return end
    parseUtility(ev,text)
end

local function deepCopyTable(src)
    if type(src)~="table" then return src end
    local dst={}; local k,v
    for k,v in src do
        if k~="debuffs" then
            if type(v)=="table" then dst[k]=deepCopyTable(v) else dst[k]=v end
        end
    end
    if dst.debuffsReceived then dst.debuffs=dst.debuffsReceived end
    return dst
end

local function mergeNumericTable(dst,src)
    if not src then return end
    local k,v
    for k,v in src do
        if k~="active" and k~="debuffs" then
            if type(v)=="number" then
                dst[k]=(dst[k] or 0)+v
            elseif type(v)=="table" then
                if not dst[k] then dst[k]={} end
                mergeNumericTable(dst[k],v)
            elseif dst[k]==nil then
                dst[k]=v
            end
        end
    end
end

local function mergeOverallActors(srcActors)
    local key,a
    for key,a in srcActors do
        local dst=D.overallSegment.actors[key]
        if not dst then
            dst=deepCopyTable(a)
            -- Overall auras must not carry active timers between fights.
            local kinds={"buffs","debuffsCast","debuffsReceived"}; local i=1
            while i<=table.getn(kinds) do
                local tbl=dst[kinds[i]]; local spell,e
                if tbl then for spell,e in tbl do e.active={} end end
                i=i+1
            end
            D.overallSegment.actors[key]=dst
        else
            local preservedName=dst.name; local preservedClass=dst.classToken
            mergeNumericTable(dst,a)
            dst.name=a.name or preservedName
            dst.classToken=a.classToken or preservedClass
            dst.guid=a.guid or dst.guid
            dst.ownerKey=a.ownerKey or dst.ownerKey
            dst.isPet=a.isPet
            if a.isTotem then dst.isTotem=true end
            if dst.debuffsReceived then dst.debuffs=dst.debuffsReceived end
        end
    end
end

local function snapshotFinishedFight()
    local total=0; local k,a
    for k,a in D.actors do total=total+(a.damage or 0)+(a.healing or 0) end
    if total<=0 then return end
    local entry={
        actors=deepCopyTable(D.actors),
        duration=D.lastDuration or 0,
        name=currentFightLabel(),
        when=GetTime()
    }
    table.insert(D.fightHistory,1,entry)
    while table.getn(D.fightHistory)>10 do table.remove(D.fightHistory) end
    mergeOverallActors(D.actors)
    D.overallSegment.duration=(D.overallSegment.duration or 0)+(D.lastDuration or 0)
    D.overallSegment.fights=(D.overallSegment.fights or 0)+1
end

local function totalDamage()
    local total=0; local k,a; local actors=getDisplayActors()
    for k,a in actors do total=total+(a.damage or 0) end
    return total
end
local function actorDisplayDamage(a)
    if not a then return 0 end
    local val=a.damage or 0; local actors=getDisplayActors()
    if not a.isPet then local k,p; for k,p in actors do if p.isPet and p.ownerKey==a.key then val=val+(p.damage or 0) end end end
    return val
end
local function totalHealing()
    local total=0; local k,a; local actors=getDisplayActors()
    for k,a in actors do total=total+(a.healing or 0) end
    return total
end
local function actorDisplayHealing(a)
    if not a then return 0 end
    local val=a.healing or 0; local actors=getDisplayActors()
    if not a.isPet then local k,p; for k,p in actors do if p.isPet and p.ownerKey==a.key then val=val+(p.healing or 0) end end end
    return val
end
local function utilityTotal(a,kind)
    if not a or not a[kind] then return 0 end
    if kind=="buffs" or kind=="debuffsCast" or kind=="debuffsReceived" then return auraTableDuration(a[kind]) end
    local t=0; local k,e; for k,e in a[kind] do t=t+(e.count or 0) end; return t
end
D.auraEntryCount = function(tbl)
    if not tbl then return 0 end
    local n=0
    local k,v
    for k,v in tbl do n=n+1 end
    return n
end

local function auraAverageUptime(a,kind)
    if not a or not a[kind] then return 0 end
    local dur=getDuration(); local exposures=auraExposureCount(a[kind]); if dur<=0 or exposures<=0 then return 0 end
    local pct=(auraTableDuration(a[kind])/(dur*exposures))*100
    if pct<0 then pct=0 end
    if pct>100 then pct=100 end
    return pct
end
local function sortedActors()
    local list={}; local n=0; local k,a; local actors=getDisplayActors()
    local petTotals=nil

    -- Damage/healing rows fold pets into their owners. Previously every
    -- table.sort comparison rescanned the entire actor table for matching pets.
    -- In a 40-player raid that turns one UI refresh into many redundant scans.
    -- Build owner pet totals once, then sort cached row values.
    if D.mode=="damage" or D.mode=="healing" then
        petTotals={}
        for k,a in actors do
            if a.isPet and a.ownerKey then
                local pv
                if D.mode=="damage" then pv=a.damage or 0 else pv=a.healing or 0 end
                petTotals[a.ownerKey]=(petTotals[a.ownerKey] or 0)+pv
            end
        end
    end

    for k,a in actors do
        if not a.isPet then
            local val
            if D.mode=="damage" then val=(a.damage or 0)+(petTotals[a.key] or 0)
            elseif D.mode=="healing" then val=(a.healing or 0)+(petTotals[a.key] or 0)
            elseif D.mode=="buffs" or D.mode=="debuffsCast" or D.mode=="debuffsReceived" then val=D.auraEntryCount(a[D.mode])
            else val=utilityTotal(a,D.mode) end
            a._cawDisplayValue=val
            if val>0 then n=n+1; list[n]=a end
        end
    end

    table.sort(list,function(x,y)
        return (x._cawDisplayValue or 0)>(y._cawDisplayValue or 0)
    end)
    return list,n
end
local function sortedTable(tbl,field)
    local list={}; local n=0; if not tbl then return list,0 end; local name,s
    for name,s in tbl do local value=s[field or "count"] or 0; if field=="duration" then value=auraEntryDuration(s) end; n=n+1; list[n]={name=name,value=value,count=s.count or 0,hits=s.hits or 0,crits=s.crits or 0,damage=s.damage or 0,targetCount=auraTargetCount(s)} end
    table.sort(list,function(x,y) return x.value>y.value end); return list,n
end
local function sortedSpells(a)
    local list={}; local n=0; if not a then return list,0 end; local name,s
    for name,s in a.spells do n=n+1; list[n]={name=name,damage=s.damage,hits=s.hits,crits=s.crits,value=s.damage} end
    table.sort(list,function(x,y) return x.damage>y.damage end); return list,n
end
local function sortedHeals(a)
    local list={}; local n=0; if not a then return list,0 end; local name,h
    for name,h in a.healSpells do n=n+1; list[n]={name=name,healing=h.healing,hits=h.hits,crits=h.crits,value=h.healing} end
    table.sort(list,function(x,y) return x.healing>y.healing end); return list,n
end
local function classColor(a)
    if a and a.classToken and CLASS_COLORS[a.classToken] then return CLASS_COLORS[a.classToken][1],CLASS_COLORS[a.classToken][2],CLASS_COLORS[a.classToken][3] end
    return 0.45,0.45,0.45
end

local MODE_LABELS={damage="Damage / DPS",healing="Healing / HPS",interrupts="Interrupts",cc="Crowd Control",ccBreaks="CC Breaks",dispels="Dispels",buffs="Buff Uptime",debuffsCast="Debuffs Cast",debuffsReceived="Debuffs Received"}

-- UI -----------------------------------------------------------------------
local frame=CreateFrame("Frame","CawDPSMeterWindow",UIParent); D.window=frame
frame:SetWidth(440); frame:SetHeight(260); frame:EnableMouse(true)
if frame.SetClampedToScreen then pcall(frame.SetClampedToScreen,frame,true) end
-- The window must be movable/resizable before any drag handler can ever run.
-- Do this during base-frame creation; applyWindowLock later only toggles it.
if frame.SetMovable then frame:SetMovable(true) end
if frame.SetResizable then frame:SetResizable(true) end
frame:SetPoint("CENTER",UIParent,"CENTER",260,0)
D.layoutRestored=false

-- Keep account-wide and per-character layout copies for custom-client reliability.
-- Some 1.12/custom clients are inconsistent about one SavedVariables scope, so
-- either copy can restore the window. Restore is deliberately delayed until
-- PLAYER_ENTERING_WORLD, when UIParent has its final dimensions/scale.
local function layoutIsValid(t)
    if not t then return false end
    if t.layoutSaved and t.width and t.height then
        if (t.left ~= nil and t.top ~= nil) or (t.point and t.x ~= nil and t.y ~= nil) then return true end
    end
    -- Accept pre-v1.13 settings as a migration source as well.
    if t.width and t.height and ((t.left ~= nil and t.top ~= nil) or (t.point and t.x ~= nil and t.y ~= nil)) then return true end
    return false
end

local function copyLayout(src,dst)
    if not src or not dst then return end
    dst.width=src.width; dst.height=src.height
    dst.point=src.point; dst.relativePoint=src.relativePoint
    dst.x=src.x; dst.y=src.y
    dst.left=src.left; dst.top=src.top
    dst.locked=src.locked and true or false
    dst.layoutVersion=3; dst.layoutSaved=true
end

local function resetWindowPosition()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER",UIParent,"CENTER",260,0)
    if frame:GetWidth()<330 or frame:GetWidth()>900 then frame:SetWidth(440) end
    if frame:GetHeight()<110 or frame:GetHeight()>700 then frame:SetHeight(260) end
end

local function ensureWindowOnScreen()
    local sw=UIParent and UIParent:GetWidth() or 0
    local sh=UIParent and UIParent:GetHeight() or 0
    local l=frame:GetLeft(); local r=frame:GetRight(); local t=frame:GetTop(); local b=frame:GetBottom()
    if sw<=0 or sh<=0 or not l or not r or not t or not b then return false end
    -- Keep at least ~40 px of the meter reachable after resolution/UI-scale changes.
    if r<40 or l>(sw-40) or t<40 or b>(sh-40) then
        resetWindowPosition()
        return true
    end
    return false
end

local function restoreWindowState()
    initializeSavedVariables()
    local src=nil
    -- The meter layout is shared. Prefer the account-wide copy so a stale
    -- per-character layout from another client/older build cannot reset or
    -- override the position that was just saved on the other character.
    if layoutIsValid(DB) then src=DB elseif layoutIsValid(CharDB) then src=CharDB end
    if src then
        if src.width and src.width>=330 and src.width<=900 then frame:SetWidth(src.width) end
        if src.height and src.height>=110 and src.height<=700 then frame:SetHeight(src.height) end
        frame:ClearAllPoints()
        if src.left ~= nil and src.top ~= nil then
            frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",src.left,src.top)
        elseif src.point and src.x ~= nil and src.y ~= nil then
            frame:SetPoint(src.point,UIParent,src.relativePoint or src.point,src.x,src.y)
        else
            frame:SetPoint("CENTER",UIParent,"CENTER",260,0)
        end
        D.locked=src.locked and true or false
        copyLayout(src,DB); copyLayout(src,CharDB)
    else
        frame:ClearAllPoints(); frame:SetPoint("CENTER",UIParent,"CENTER",260,0)
        frame:SetWidth(440); frame:SetHeight(260)
    end
    ensureWindowOnScreen()
    D.layoutRestored=true
end

if frame.SetMinResize then pcall(frame.SetMinResize,frame,330,110) end
if frame.SetMaxResize then pcall(frame.SetMaxResize,frame,900,700) end

local function writeWindowState(dst)
    if not dst then return end
    local w=frame:GetWidth(); local h=frame:GetHeight()
    if w and w>0 then dst.width=w end
    if h and h>0 then dst.height=h end
    local point,relativeTo,relativePoint,x,y=frame:GetPoint()
    if point then
        dst.point=point; dst.relativePoint=relativePoint or point; dst.x=x or 0; dst.y=y or 0
    end
    local left=frame:GetLeft(); local top=frame:GetTop()
    if left ~= nil then dst.left=left end
    if top ~= nil then dst.top=top end
    dst.locked=D.locked and true or false
    dst.mode=D.mode
    dst.layoutVersion=3
    dst.layoutSaved=true
end

local function saveWindowState()
    initializeSavedVariables()
    -- Re-bind to the globals immediately before every write. This is deliberate:
    -- if a custom client swapped the SavedVariables table during loading, we
    -- always write into the exact table WoW will serialize on logout.
    DB = CawDPSMeterDB
    CharDB = CawDPSMeterCharDB
    writeWindowState(DB)
    writeWindowState(CharDB)
end

frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart",function() if not D.locked then this:StartMoving() end end)
frame:SetScript("OnDragStop",function()
    this:StopMovingOrSizing()
    ensureWindowOnScreen()
    saveWindowState()
end)

-- Clean pfUI/ElvUI-inspired shell: square corners, very dark panels and
-- restrained one-pixel separators instead of Blizzard's ornate borders.
local FLAT_TEX="Interface\\Tooltips\\UI-Tooltip-Background"
local function flatPanel(f,r,g,b,a,border)
    f:SetBackdrop({bgFile=FLAT_TEX,tile=true,tileSize=16,insets={left=0,right=0,top=0,bottom=0}})
    f:SetBackdropColor(r or 0.035,g or 0.035,b or 0.035,a or 0.96)
    local br=border or 0.20
    local t=f:CreateTexture(nil,"BORDER"); t:SetTexture(FLAT_TEX); t:SetVertexColor(br,br,br,1); t:SetPoint("TOPLEFT",f,"TOPLEFT",0,0); t:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0); t:SetHeight(1)
    local btm=f:CreateTexture(nil,"BORDER"); btm:SetTexture(FLAT_TEX); btm:SetVertexColor(br,br,br,1); btm:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0); btm:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0); btm:SetHeight(1)
    local l=f:CreateTexture(nil,"BORDER"); l:SetTexture(FLAT_TEX); l:SetVertexColor(br,br,br,1); l:SetPoint("TOPLEFT",f,"TOPLEFT",0,0); l:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0); l:SetWidth(1)
    local rr=f:CreateTexture(nil,"BORDER"); rr:SetTexture(FLAT_TEX); rr:SetVertexColor(br,br,br,1); rr:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0); rr:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0); rr:SetWidth(1)
end
flatPanel(frame,0.025,0.025,0.025,0.98,0.18)

-- Top title bar, based on the approved Caw mockup.
local header=frame:CreateTexture(nil,"ARTWORK"); header:SetTexture(FLAT_TEX); header:SetVertexColor(0.035,0.035,0.035,1); header:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-1); header:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-1,-1); header:SetHeight(26)
local headerLine=frame:CreateTexture(nil,"ARTWORK"); headerLine:SetTexture(FLAT_TEX); headerLine:SetVertexColor(0.18,0.18,0.18,1); headerLine:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-27); headerLine:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-1,-27); headerLine:SetHeight(1)
-- Branded header artwork: the attack-claw and stylized CAW DPS METER wordmark
-- are baked into one transparent texture so the header stays compact and crisp.
local brand=frame:CreateTexture(nil,"OVERLAY"); brand:SetTexture("Interface\\AddOns\\CawDPSMeter\\Media\\CawBrand.tga"); brand:SetWidth(168); brand:SetHeight(21); brand:SetPoint("TOPLEFT",frame,"TOPLEFT",6,-3)

-- Second toolbar: mode selector left, clearly labelled total right.
local toolbar=frame:CreateTexture(nil,"ARTWORK"); toolbar:SetTexture(FLAT_TEX); toolbar:SetVertexColor(0.065,0.065,0.065,1); toolbar:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-28); toolbar:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-1,-28); toolbar:SetHeight(22)
local toolbarLine=frame:CreateTexture(nil,"ARTWORK"); toolbarLine:SetTexture(FLAT_TEX); toolbarLine:SetVertexColor(0.18,0.18,0.18,1); toolbarLine:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-50); toolbarLine:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-1,-50); toolbarLine:SetHeight(1)
local summary=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); summary:SetPoint("RIGHT",frame,"TOPRIGHT",-8,-39); summary:SetJustifyH("RIGHT"); summary:SetTextColor(0.90,0.90,0.90)

local updateUI
local segmentMenu=nil
local segmentText=nil
local segmentButton=nil
local segmentMenuButtons={}
local SEGMENT_MENU_VISIBLE=6
local segmentMenuOffset=0
local segmentItems={}
local segmentItemCount=0

local function shortFightName(name)
    if not name or name=="" then return "Unknown Enemy" end
    if string.len(name)<=14 then return name end

    -- Prefer the common addon style: abbreviate earlier words and keep the
    -- final creature name readable, e.g. "Thunderhawk Hatchling" -> "T. Hatchling".
    local _,_,prefix,last=string.find(name,"^(.*) ([^ ]+)$")
    if prefix and last then
        local initials=string.sub(prefix,1,1).."."
        local pos=1
        while true do
            local s=string.find(prefix," ",pos,true)
            if not s then break end
            if s<string.len(prefix) then
                initials=initials.." "..string.sub(prefix,s+1,s+1).."."
            end
            pos=s+1
        end
        local compact=initials.." "..last
        if string.len(compact)<=16 then return compact end

        -- If the final word itself is unusually long, keep the initials and
        -- trim only the tail rather than chopping the whole name arbitrarily.
        local room=16-string.len(initials)-1
        if room>=4 then return initials.." "..string.sub(last,1,room-2)..".." end
    end

    -- Single very long word fallback.
    return string.sub(name,1,14)..".."
end

local function selectedSegmentLabel()
    if D.segment=="overall" then return "Overall" end
    if D.segment=="history" then
        local h=D.fightHistory[D.segmentIndex or 1]
        if h then return shortFightName(h.name) end
        return "Previous Fight"
    end
    local name=currentFightLabel()
    if name=="Current" then return "Current" end
    return shortFightName(name)
end

local function selectSegment(kind,index)
    D.segment=kind
    D.segmentIndex=index or 0
    D.scrollOffset=0
    if segmentMenu then segmentMenu:Hide() end
    if updateUI then updateUI() end
end

local function buildSegmentItems()
    segmentItems={}
    segmentItemCount=0
    segmentItemCount=segmentItemCount+1
    segmentItems[segmentItemCount]={kind="current",label=(currentFightLabel()=="Current" and "Current" or ("Current - "..shortFightName(currentFightLabel())))}
    local i=1
    while i<=table.getn(D.fightHistory) and i<=10 do
        local h=D.fightHistory[i]
        segmentItemCount=segmentItemCount+1
        segmentItems[segmentItemCount]={kind="history",index=i,label=tostring(i)..". "..shortFightName(h.name)}
        i=i+1
    end
    segmentItemCount=segmentItemCount+1
    segmentItems[segmentItemCount]={kind="overall",label="Overall ("..tostring(D.overallSegment.fights or 0)..")"}
end

local function clampSegmentOffset()
    local maxOffset=segmentItemCount-SEGMENT_MENU_VISIBLE
    if maxOffset<0 then maxOffset=0 end
    if segmentMenuOffset<0 then segmentMenuOffset=0 end
    if segmentMenuOffset>maxOffset then segmentMenuOffset=maxOffset end
end

local refreshSegmentMenu

segmentButton=CreateFrame("Button",nil,frame)
segmentButton:SetWidth(118); segmentButton:SetHeight(17); segmentButton:SetPoint("LEFT",frame,"TOPLEFT",145,-39)
flatPanel(segmentButton,0.065,0.065,0.065,1,0.25)
segmentButton:SetBackdropColor(0.08,0.08,0.08,1)
segmentText=segmentButton:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
segmentText:SetPoint("LEFT",segmentButton,"LEFT",6,0); segmentText:SetWidth(94); segmentText:SetJustifyH("LEFT"); segmentText:SetText("Current")
local segmentArrow=segmentButton:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
segmentArrow:SetPoint("RIGHT",segmentButton,"RIGHT",-6,0); segmentArrow:SetText("v")

segmentMenu=CreateFrame("Frame",nil,frame)
segmentMenu:SetWidth(178); segmentMenu:SetHeight((SEGMENT_MENU_VISIBLE*20)+30)
segmentMenu:SetPoint("TOPLEFT",segmentButton,"BOTTOMLEFT",0,-1)
flatPanel(segmentMenu,0.035,0.035,0.045,0.98,0.28)
segmentMenu:SetFrameStrata("DIALOG")
segmentMenu:EnableMouseWheel(true)
segmentMenu:Hide()

local segUp=CreateFrame("Button",nil,segmentMenu)
segUp:SetWidth(22); segUp:SetHeight(18); segUp:SetPoint("TOPRIGHT",segmentMenu,"TOPRIGHT",-4,-4)
local segUpText=segUp:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); segUpText:SetPoint("CENTER",segUp,"CENTER",0,0); segUpText:SetText("^")

local segDown=CreateFrame("Button",nil,segmentMenu)
segDown:SetWidth(22); segDown:SetHeight(18); segDown:SetPoint("BOTTOMRIGHT",segmentMenu,"BOTTOMRIGHT",-4,4)
local segDownText=segDown:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); segDownText:SetPoint("CENTER",segDown,"CENTER",0,0); segDownText:SetText("v")

refreshSegmentMenu=function()
    buildSegmentItems()
    clampSegmentOffset()
    local i=1
    while i<=SEGMENT_MENU_VISIBLE do
        local b=segmentMenuButtons[i]
        local item=segmentItems[segmentMenuOffset+i]
        if b and item then
            b.kind=item.kind
            b.historyIndex=item.index
            b.text:SetText(item.label)
            local active=(D.segment==item.kind and (item.kind~="history" or D.segmentIndex==item.index))
            if active then
                b.bg:SetVertexColor(0.34,0.24,0.08,0.95)
                b.text:SetTextColor(1.00,0.82,0.35)
            else
                b.bg:SetVertexColor(0.12,0.12,0.12,0)
                b.text:SetTextColor(0.92,0.92,0.92)
            end
            b:Show()
        elseif b then
            b.kind=nil
            b.historyIndex=nil
            b:Hide()
        end
        i=i+1
    end
    if segmentMenuOffset>0 then segUp:Enable(); segUpText:SetTextColor(1,1,1) else segUp:Disable(); segUpText:SetTextColor(0.4,0.4,0.4) end
    if segmentMenuOffset+SEGMENT_MENU_VISIBLE<segmentItemCount then segDown:Enable(); segDownText:SetTextColor(1,1,1) else segDown:Disable(); segDownText:SetTextColor(0.4,0.4,0.4) end
end

local si=1
while si<=SEGMENT_MENU_VISIBLE do
    local b=CreateFrame("Button",nil,segmentMenu)
    b:SetHeight(20)
    b:SetPoint("TOPLEFT",segmentMenu,"TOPLEFT",4,-4-((si-1)*20))
    b:SetPoint("RIGHT",segmentMenu,"RIGHT",-30,0)
    b.bg=b:CreateTexture(nil,"BACKGROUND"); b.bg:SetTexture(FLAT_TEX); b.bg:SetAllPoints(b); b.bg:SetVertexColor(0.12,0.12,0.12,0)
    b.text=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b.text:SetPoint("LEFT",b,"LEFT",6,0); b.text:SetPoint("RIGHT",b,"RIGHT",-4,0); b.text:SetJustifyH("LEFT")
    b:SetScript("OnClick",function() if this.kind then selectSegment(this.kind,this.historyIndex) end end)
    b:SetScript("OnEnter",function() this.bg:SetVertexColor(0.22,0.22,0.22,0.95) end)
    b:SetScript("OnLeave",function()
        local active=(D.segment==this.kind and (this.kind~="history" or D.segmentIndex==this.historyIndex))
        if active then this.bg:SetVertexColor(0.34,0.24,0.08,0.95) else this.bg:SetVertexColor(0.12,0.12,0.12,0) end
    end)
    segmentMenuButtons[si]=b
    si=si+1
end

local function scrollSegmentMenu(delta)
    buildSegmentItems()
    if delta>0 then segmentMenuOffset=segmentMenuOffset-1 else segmentMenuOffset=segmentMenuOffset+1 end
    clampSegmentOffset()
    refreshSegmentMenu()
end

segmentMenu:SetScript("OnMouseWheel",function() scrollSegmentMenu(arg1 or 0) end)
segUp:SetScript("OnClick",function() scrollSegmentMenu(1) end)
segDown:SetScript("OnClick",function() scrollSegmentMenu(-1) end)

segmentButton:SetScript("OnClick",function()
    if segmentMenu:IsShown() then
        segmentMenu:Hide()
    else
        buildSegmentItems()
        if D.segment=="history" and D.segmentIndex and D.segmentIndex>0 then
            segmentMenuOffset=D.segmentIndex-2
        elseif D.segment=="overall" then
            segmentMenuOffset=segmentItemCount-SEGMENT_MENU_VISIBLE
        else
            segmentMenuOffset=0
        end
        clampSegmentOffset()
        refreshSegmentMenu()
        segmentMenu:Show()
    end
end)
segmentButton:SetScript("OnEnter",function() segmentButton:SetBackdropColor(0.14,0.14,0.14,1) end)
segmentButton:SetScript("OnLeave",function() segmentButton:SetBackdropColor(0.08,0.08,0.08,1) end)

-- MODE_LABELS is declared once above the UI section.
local MODE_ORDER={"damage","healing","interrupts","cc","ccBreaks","dispels","buffs","debuffsCast","debuffsReceived"}
local modeMenu

local modeButton=CreateFrame("Button",nil,frame)
modeButton:SetWidth(132); modeButton:SetHeight(17); modeButton:SetPoint("TOPLEFT",frame,"TOPLEFT",7,-31)
flatPanel(modeButton,0.065,0.065,0.065,1,0.25)
modeButton:SetBackdropColor(0.08,0.08,0.08,1)
local modeText=modeButton:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); modeText:SetPoint("LEFT",modeButton,"LEFT",7,0); modeText:SetJustifyH("LEFT")
-- Always render a valid initial selection even before PLAYER_ENTERING_WORLD/updateUI.
modeText:SetText(MODE_LABELS[D.mode] or "Damage / DPS")
local modeArrow=modeButton:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); modeArrow:SetPoint("RIGHT",modeButton,"RIGHT",-6,0); modeArrow:SetText("v")

modeMenu=CreateFrame("Frame",nil,frame)
-- Keep the mode selector compact. Only a subset of entries is shown at once;
-- the rest can be reached with the mouse wheel or the arrow buttons.
local MODE_MENU_VISIBLE=6
local modeMenuOffset=0
local modeMenuButtons={}
modeMenu:SetWidth(152); modeMenu:SetHeight((MODE_MENU_VISIBLE*20)+30); modeMenu:SetPoint("TOPLEFT",modeButton,"BOTTOMLEFT",0,-1)
flatPanel(modeMenu,0.025,0.025,0.025,0.99,0.25)
modeMenu:SetBackdropColor(0.025,0.025,0.025,0.99)
if modeMenu.SetFrameStrata then modeMenu:SetFrameStrata("DIALOG") end
if modeMenu.EnableMouseWheel then modeMenu:EnableMouseWheel(true) end
modeMenu:Hide()

local function setMode(mode)
    D.mode=mode
    D.scrollOffset=0
    initializeSavedVariables()
    DB=CawDPSMeterDB
    CharDB=CawDPSMeterCharDB
    if DB then DB.mode=mode end
    if CharDB then CharDB.mode=mode end
    if modeMenu then modeMenu:Hide() end
    if updateUI then updateUI() end
end

local function clampModeMenuOffset()
    local maxOffset=table.getn(MODE_ORDER)-MODE_MENU_VISIBLE
    if maxOffset<0 then maxOffset=0 end
    if modeMenuOffset<0 then modeMenuOffset=0 end
    if modeMenuOffset>maxOffset then modeMenuOffset=maxOffset end
end

local function refreshModeMenu()
    clampModeMenuOffset()
    local i=1
    while i<=MODE_MENU_VISIBLE do
        local b=modeMenuButtons[i]
        local idx=modeMenuOffset+i
        local m=MODE_ORDER[idx]
        if m then
            b.mode=m
            b.text:SetText(MODE_LABELS[m] or m)
            if m==D.mode then
                b.hi:SetVertexColor(0.34,0.24,0.08,0.95)
                b.text:SetTextColor(1.00,0.82,0.35)
            else
                b.hi:SetVertexColor(0.24,0.24,0.24,0)
                b.text:SetTextColor(0.92,0.92,0.92)
            end
            b:Show()
        else
            b.mode=nil
            b:Hide()
        end
        i=i+1
    end
end

local function scrollModeMenu(delta)
    if not delta or delta==0 then return end
    if delta>0 then modeMenuOffset=modeMenuOffset-1 else modeMenuOffset=modeMenuOffset+1 end
    refreshModeMenu()
end

local modeUp=CreateFrame("Button",nil,modeMenu)
modeUp:SetWidth(144); modeUp:SetHeight(13); modeUp:SetPoint("TOPLEFT",modeMenu,"TOPLEFT",4,-3)
local modeUpHi=modeUp:CreateTexture(nil,"BACKGROUND"); modeUpHi:SetAllPoints(modeUp); modeUpHi:SetTexture(FLAT_TEX); modeUpHi:SetVertexColor(0.24,0.24,0.24,0)
local modeUpText=modeUp:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); modeUpText:SetPoint("CENTER",modeUp,"CENTER",0,0); modeUpText:SetText("^")
modeUp:SetScript("OnClick",function() scrollModeMenu(1) end)
modeUp:SetScript("OnEnter",function() modeUpHi:SetVertexColor(0.24,0.24,0.24,0.85) end)
modeUp:SetScript("OnLeave",function() modeUpHi:SetVertexColor(0.24,0.24,0.24,0) end)

local mi=1
while mi<=MODE_MENU_VISIBLE do
    local b=CreateFrame("Button",nil,modeMenu)
    b:SetWidth(144); b:SetHeight(19); b:SetPoint("TOPLEFT",modeMenu,"TOPLEFT",4,-16-((mi-1)*20))
    local hi=b:CreateTexture(nil,"BACKGROUND"); hi:SetAllPoints(b); hi:SetTexture(FLAT_TEX); hi:SetVertexColor(0.24,0.24,0.24,0)
    local fs=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); fs:SetPoint("LEFT",b,"LEFT",6,0)
    b.hi=hi; b.text=fs
    b:SetScript("OnClick",function() if this.mode then setMode(this.mode) end end)
    b:SetScript("OnEnter",function() this.hi:SetVertexColor(0.24,0.24,0.24,0.85) end)
    b:SetScript("OnLeave",function()
        if this.mode==D.mode then
            this.hi:SetVertexColor(0.34,0.24,0.08,0.95)
            this.text:SetTextColor(1.00,0.82,0.35)
        else
            this.hi:SetVertexColor(0.24,0.24,0.24,0)
            this.text:SetTextColor(0.92,0.92,0.92)
        end
    end)
    modeMenuButtons[mi]=b
    mi=mi+1
end

local modeDown=CreateFrame("Button",nil,modeMenu)
modeDown:SetWidth(144); modeDown:SetHeight(13); modeDown:SetPoint("BOTTOMLEFT",modeMenu,"BOTTOMLEFT",4,3)
local modeDownHi=modeDown:CreateTexture(nil,"BACKGROUND"); modeDownHi:SetAllPoints(modeDown); modeDownHi:SetTexture(FLAT_TEX); modeDownHi:SetVertexColor(0.24,0.24,0.24,0)
local modeDownText=modeDown:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); modeDownText:SetPoint("CENTER",modeDown,"CENTER",0,0); modeDownText:SetText("v")
modeDown:SetScript("OnClick",function() scrollModeMenu(-1) end)
modeDown:SetScript("OnEnter",function() modeDownHi:SetVertexColor(0.24,0.24,0.24,0.85) end)
modeDown:SetScript("OnLeave",function() modeDownHi:SetVertexColor(0.24,0.24,0.24,0) end)

modeMenu:SetScript("OnMouseWheel",function() scrollModeMenu(arg1) end)
modeButton:SetScript("OnClick",function()
    if modeMenu:IsVisible() then
        modeMenu:Hide()
    else
        -- Open around the current selection where possible, so the active mode
        -- is visible even when it is near the bottom of the list.
        local currentIndex=1
        local i=1
        while i<=table.getn(MODE_ORDER) do
            if MODE_ORDER[i]==D.mode then currentIndex=i; break end
            i=i+1
        end
        if currentIndex>MODE_MENU_VISIBLE then modeMenuOffset=currentIndex-MODE_MENU_VISIBLE else modeMenuOffset=0 end
        refreshModeMenu()
        modeMenu:Show()
    end
end)
modeButton:SetScript("OnEnter",function() modeButton:SetBackdropColor(0.14,0.14,0.14,1) end)
modeButton:SetScript("OnLeave",function() modeButton:SetBackdropColor(0.08,0.08,0.08,1) end)

-- Explicit text buttons: much clearer than the former single-letter controls.
local resetButton=CreateFrame("Button",nil,frame)
resetButton:SetWidth(56); resetButton:SetHeight(17); resetButton:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-25,-5)
flatPanel(resetButton,0.065,0.065,0.065,1,0.25)
resetButton:SetBackdropColor(0.08,0.08,0.08,1)
local resetText=resetButton:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); resetText:SetPoint("CENTER",resetButton,"CENTER",0,0); resetText:SetText("Reset")
resetButton:SetScript("OnClick",function() resetFight(); D.inCombat=false; D.scrollOffset=0; if updateUI then updateUI() end end)
resetButton:SetScript("OnEnter",function() this:SetBackdropColor(0.15,0.15,0.15,1) end)
resetButton:SetScript("OnLeave",function() this:SetBackdropColor(0.08,0.08,0.08,1) end)

local closeButton=CreateFrame("Button",nil,frame)
closeButton:SetWidth(17); closeButton:SetHeight(17); closeButton:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-5,-5)
flatPanel(closeButton,0.065,0.065,0.065,1,0.25)
closeButton:SetBackdropColor(0.08,0.08,0.08,1)
local closeText=closeButton:CreateFontString(nil,"OVERLAY","GameFontHighlight"); closeText:SetPoint("CENTER",closeButton,"CENTER",0,0); closeText:SetText("x"); closeText:SetTextColor(1.00,0.25,0.25,1)
closeButton:SetScript("OnClick",function() frame:Hide() end)
closeButton:SetScript("OnEnter",function() this:SetBackdropColor(0.28,0.08,0.08,1) end)
closeButton:SetScript("OnLeave",function() this:SetBackdropColor(0.08,0.08,0.08,1) end)

local sizeGrip
local lockButton=CreateFrame("Button",nil,frame)
lockButton:SetWidth(56); lockButton:SetHeight(17); lockButton:SetPoint("RIGHT",resetButton,"LEFT",-4,0)
flatPanel(lockButton,0.065,0.065,0.065,1,0.25)
local lockText=lockButton:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); lockText:SetPoint("CENTER",lockButton,"CENTER",0,0)
local function applyWindowLock()
    -- UI construction happens before ADDON_LOADED. Never dereference DB here
    -- until SavedVariables have actually been initialized.
    if D.savedVariablesReady and DB then DB.locked=D.locked and true or false end
    if D.savedVariablesReady and CharDB then CharDB.locked=D.locked and true or false end
    if frame.SetMovable then frame:SetMovable(not D.locked) end
    if frame.SetResizable then frame:SetResizable(not D.locked) end
    if sizeGrip then
        if D.locked then
            sizeGrip:Hide()
        else
            sizeGrip:Show()
            if sizeGrip.SetAlpha then sizeGrip:SetAlpha(0.92) end
        end
    end
    if D.locked then
        lockText:SetText("Unlock"); lockButton:SetBackdropColor(0.22,0.15,0.05,1)
    else
        lockText:SetText("Lock"); lockButton:SetBackdropColor(0.08,0.08,0.08,1)
    end
end
lockButton:SetScript("OnClick",function() D.locked=not D.locked; saveWindowState(); applyWindowLock() end)
lockButton:SetScript("OnEnter",function()
    local tt=D.getControlTooltip()
    if tt then
        tt:SetOwner(this,"ANCHOR_TOP")
        if D.locked then tt:SetText("Unlock position and size",1,1,1)
        else tt:SetText("Lock position and size",1,1,1) end
        tt:Show()
    end
end)
lockButton:SetScript("OnLeave",function() if D.controlTooltip then D.controlTooltip:Hide() end end)

function D.buildReportUI()
    D.reportButton=CreateFrame("Button",nil,frame)
    D.reportButton:SetWidth(56)
    D.reportButton:SetHeight(17)
    D.reportButton:SetPoint("RIGHT",lockButton,"LEFT",-4,0)
    flatPanel(D.reportButton,0.065,0.065,0.065,1,0.25)
    D.reportButton:SetBackdropColor(0.08,0.08,0.08,1)

    D.reportText=D.reportButton:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    D.reportText:SetPoint("CENTER",D.reportButton,"CENTER",0,0)
    D.reportText:SetText("Report")

    D.reportMenu=CreateFrame("Frame",nil,frame)
    D.reportMenu:SetWidth(96)
    D.reportMenu:SetHeight(86)
    D.reportMenu:SetPoint("TOPRIGHT",D.reportButton,"BOTTOMRIGHT",0,-2)
    flatPanel(D.reportMenu,0.025,0.025,0.025,0.99,0.25)
    D.reportMenu:SetBackdropColor(0.025,0.025,0.025,0.99)
    if D.reportMenu.SetFrameStrata then D.reportMenu:SetFrameStrata("DIALOG") end
    D.reportMenu:Hide()

    local channels={
        {label="Say",channel="SAY"},
        {label="Party",channel="PARTY"},
        {label="Raid",channel="RAID"},
        {label="Guild",channel="GUILD"}
    }
    local i=1
    while i<=table.getn(channels) do
        local info=channels[i]
        local b=CreateFrame("Button",nil,D.reportMenu)
        b:SetWidth(88)
        b:SetHeight(18)
        b:SetPoint("TOPLEFT",D.reportMenu,"TOPLEFT",4,-4-((i-1)*20))
        local hi=b:CreateTexture(nil,"BACKGROUND")
        hi:SetAllPoints(b)
        hi:SetTexture(FLAT_TEX)
        hi:SetVertexColor(0.24,0.24,0.24,0)
        local fs=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        fs:SetPoint("LEFT",b,"LEFT",7,0)
        fs:SetText(info.label)
        b.channel=info.channel
        b.hi=hi
        b:SetScript("OnClick",function()
            D.reportMenu:Hide()
            D.sendReport(this.channel)
        end)
        b:SetScript("OnEnter",function()
            this.hi:SetVertexColor(0.24,0.24,0.24,0.85)
        end)
        b:SetScript("OnLeave",function()
            this.hi:SetVertexColor(0.24,0.24,0.24,0)
        end)
        i=i+1
    end

    D.reportButton:SetScript("OnClick",function()
        if D.reportMenu:IsShown() then
            D.reportMenu:Hide()
        else
            if modeMenu then modeMenu:Hide() end
            if segmentMenu then segmentMenu:Hide() end
            D.reportMenu:Show()
        end
    end)
    D.reportButton:SetScript("OnEnter",function()
        D.reportButton:SetBackdropColor(0.14,0.14,0.14,1)
    end)
    D.reportButton:SetScript("OnLeave",function()
        D.reportButton:SetBackdropColor(0.08,0.08,0.08,1)
    end)
end

D.buildReportUI()

sizeGrip=CreateFrame("Button",nil,frame)
-- Classic Details-style resize marker: three visible diagonal slashes.
-- The hit area remains larger than the artwork so resizing is easy.
sizeGrip:SetWidth(24); sizeGrip:SetHeight(24); sizeGrip:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,1)

local gripSlash1=sizeGrip:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
gripSlash1:SetText("/")
gripSlash1:SetPoint("BOTTOMRIGHT",sizeGrip,"BOTTOMRIGHT",-3,1)
gripSlash1:SetTextColor(0.72,0.72,0.72,1)

local gripSlash2=sizeGrip:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
gripSlash2:SetText("/")
gripSlash2:SetPoint("BOTTOMRIGHT",sizeGrip,"BOTTOMRIGHT",-7,1)
gripSlash2:SetTextColor(0.72,0.72,0.72,1)

local gripSlash3=sizeGrip:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
gripSlash3:SetText("/")
gripSlash3:SetPoint("BOTTOMRIGHT",sizeGrip,"BOTTOMRIGHT",-11,1)
gripSlash3:SetTextColor(0.72,0.72,0.72,1)

sizeGrip.gripSlash1=gripSlash1
sizeGrip.gripSlash2=gripSlash2
sizeGrip.gripSlash3=gripSlash3
local function setGripSlashColor(r,g,b,a)
    if sizeGrip.gripSlash1 then sizeGrip.gripSlash1:SetTextColor(r,g,b,a) end
    if sizeGrip.gripSlash2 then sizeGrip.gripSlash2:SetTextColor(r,g,b,a) end
    if sizeGrip.gripSlash3 then sizeGrip.gripSlash3:SetTextColor(r,g,b,a) end
end
sizeGrip:RegisterForDrag("LeftButton")
sizeGrip:SetScript("OnDragStart",function() if not D.locked and frame.StartSizing then frame:StartSizing("BOTTOMRIGHT") end end)
sizeGrip:SetScript("OnDragStop",function()
    frame:StopMovingOrSizing()
    ensureWindowOnScreen()
    saveWindowState()
    if updateUI then updateUI() end
end)
sizeGrip:SetScript("OnEnter",function()
    setGripSlashColor(1.00,0.82,0.35,1)
    if not D.locked and this.SetAlpha then this:SetAlpha(1) end
    local tt=D.getControlTooltip()
    if tt then
        tt:SetOwner(this,"ANCHOR_TOP")
        if D.locked then tt:SetText("Window is locked - click Unlock to resize",1,1,1)
        else tt:SetText("Drag this corner to resize",1,1,1) end
        tt:Show()
    end
end)
sizeGrip:SetScript("OnLeave",function()
    setGripSlashColor(0.72,0.72,0.72,1)
    if this.SetAlpha then this:SetAlpha(0.92) end
    if D.controlTooltip then D.controlTooltip:Hide() end
end)
applyWindowLock()

D.rows={}
local MAX_ROWS=20
local ROW_HEIGHT=23
local ROW_STEP=26
local LIST_TOP=55
local SCROLL_W=12
local i=1
while i<=MAX_ROWS do
    local rowFrame=CreateFrame("Frame",nil,frame); rowFrame:SetHeight(ROW_HEIGHT); rowFrame:SetPoint("TOPLEFT",frame,"TOPLEFT",6,-LIST_TOP-((i-1)*ROW_STEP)); rowFrame:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-(8+SCROLL_W),-LIST_TOP-((i-1)*ROW_STEP))
    flatPanel(rowFrame,0.055,0.055,0.055,0.96,0.16)
    local bar=CreateFrame("StatusBar",nil,rowFrame); bar:SetPoint("TOPLEFT",rowFrame,"TOPLEFT",1,-1); bar:SetPoint("BOTTOMRIGHT",rowFrame,"BOTTOMRIGHT",-1,1); bar:SetStatusBarTexture(FLAT_TEX); bar:SetMinMaxValues(0,1); bar:SetValue(0); bar:EnableMouse(true)
    if bar.EnableMouseWheel then bar:EnableMouseWheel(true) end
    local bg=bar:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(bar); bg:SetTexture(FLAT_TEX); bg:SetVertexColor(0.06,0.06,0.06,0.96)
    local shade=bar:CreateTexture(nil,"ARTWORK"); shade:SetAllPoints(bar); shade:SetTexture(FLAT_TEX); shade:SetVertexColor(0,0,0,0.10)

    -- Class icon lives inside the player bar. The actor's classToken already
    -- comes from the party/raid roster, the same source used for class colours.
    local classIcon=bar:CreateTexture(nil,"OVERLAY")
    classIcon:SetTexture(CLASS_ICON_TEXTURE)
    classIcon:SetWidth(18); classIcon:SetHeight(18)
    classIcon:SetPoint("LEFT",bar,"LEFT",3,0)
    classIcon:Hide()

    local rank=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); rank:SetPoint("LEFT",bar,"LEFT",24,0); rank:SetWidth(23); rank:SetJustifyH("RIGHT")
    local left=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); left:SetPoint("LEFT",rank,"RIGHT",7,0); left:SetJustifyH("LEFT")
    local right=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); right:SetPoint("RIGHT",bar,"RIGHT",-6,0); right:SetJustifyH("RIGHT")
    local hover=bar:CreateTexture(nil,"HIGHLIGHT"); hover:SetAllPoints(bar); hover:SetTexture(FLAT_TEX); hover:SetVertexColor(1,1,1,0.06)
    bar:SetScript("OnEnter",function()
        local row=this.detailsRow; local a=row and row.actor
        local tt=getPlayerTooltip()
        if not a or not tt then return end
        local cr,cg,cb=classColor(a)
        tt:SetOwner(this,"ANCHOR_RIGHT")
        tt:ClearLines()
        tt:SetText(a.name,cr,cg,cb)
        local dur=getDuration()

        if D.mode=="damage" then
            local dmg=actorDisplayDamage(a); local dps=0
            if dur>0 then dps=dmg/dur end
            tt:AddDoubleLine("Damage",comma(dmg).."  |  "..string.format("%.1f DPS",dps),0.78,0.78,0.78,1,1,1)

            local spells,sn=sortedSpells(a); local x=1
            if sn>0 then tt:AddLine(" "); tt:AddLine("Damage abilities",1,0.82,0) end
            while x<=sn and x<=8 do
                local sp=spells[x]; local pct=0
                if (a.damage or 0)>0 then pct=(sp.damage/a.damage)*100 end
                local critPct=0
                if (sp.hits or 0)>0 then critPct=((sp.crits or 0)/(sp.hits or 1))*100 end
                tt:AddDoubleLine(sp.name,comma(sp.damage).."  "..string.format("%.1f%%",pct).."  |  "..string.format("%.0f%% crit",critPct),1,1,1,0.88,0.88,0.88)
                x=x+1
            end

        elseif D.mode=="healing" then
            local heal=actorDisplayHealing(a); local hps=0
            if dur>0 then hps=heal/dur end
            tt:AddDoubleLine("Healing",comma(heal).."  |  "..string.format("%.1f HPS",hps),0.55,0.90,0.55,0.75,1,0.75)

            local heals,hn=sortedHeals(a); local x=1
            if hn>0 then tt:AddLine(" "); tt:AddLine("Healing abilities",1,0.82,0) end
            while x<=hn and x<=8 do
                local sp=heals[x]; local pct=0
                if (a.healing or 0)>0 then pct=(sp.healing/a.healing)*100 end
                local critPct=0
                if (sp.hits or 0)>0 then critPct=((sp.crits or 0)/(sp.hits or 1))*100 end
                tt:AddDoubleLine(sp.name,comma(sp.healing).."  "..string.format("%.1f%%",pct).."  |  "..string.format("%.0f%% crit",critPct),1,1,1,0.88,0.88,0.88)
                x=x+1
            end

        elseif D.mode=="buffs" or D.mode=="debuffsCast" or D.mode=="debuffsReceived" then
            local auraLabels={buffs="Buff Uptime",debuffsCast="Debuffs Cast",debuffsReceived="Debuffs Received"}
            local auraCount=D.auraEntryCount(a[D.mode])
            if D.mode=="buffs" then
                tt:AddDoubleLine(auraLabels[D.mode] or D.mode,tostring(auraCount).." buffs",1,0.82,0,1,0.82,0)
            else
                tt:AddDoubleLine(auraLabels[D.mode] or D.mode,tostring(auraCount).." debuffs",1,0.82,0,1,0.82,0)
            end

            local al,an=sortedTable(a[D.mode],"duration"); local ax=1
            while ax<=an and ax<=8 do
                local ae=al[ax]; local pct=0
                local exposure=(ae.targetCount or 1)
                if dur>0 and exposure>0 then pct=(ae.value/(dur*exposure))*100 end
                if pct>100 then pct=100 end
                tt:AddDoubleLine(ae.name,string.format("%.1fs | %.1f%% | %dx",ae.value,pct,ae.count or 0),1,1,1,0.86,0.86,0.86)
                ax=ax+1
            end

        else
            local labels={interrupts="Interrupts",cc="Crowd Control",ccBreaks="CC Breaks",dispels="Dispels"}
            local total=utilityTotal(a,D.mode)
            tt:AddDoubleLine(labels[D.mode] or D.mode,tostring(total),1,0.82,0,1,0.82,0)
            local ul,un=sortedTable(a[D.mode],"count"); local ux=1
            while ux<=un and ux<=8 do
                tt:AddDoubleLine(ul[ux].name,tostring(ul[ux].value),1,1,1,0.86,0.86,0.86)
                ux=ux+1
            end
        end

        local petDmg=0; local petHeal=0; local totemDmg=0; local totemHeal=0
        local actors=getDisplayActors(); local k,p
        local totemGroups={}
        for k,p in actors do
            if p.isPet and p.ownerKey==a.key then
                if p.isTotem then
                    totemDmg=totemDmg+(p.damage or 0)
                    totemHeal=totemHeal+(p.healing or 0)
                    local tn=p.name or "Totem"
                    local tg=totemGroups[tn]
                    if not tg then tg={damage=0,healing=0,spells={},healSpells={}}; totemGroups[tn]=tg end
                    tg.damage=tg.damage+(p.damage or 0)
                    tg.healing=tg.healing+(p.healing or 0)
                    local sn,se
                    if p.spells then
                        for sn,se in p.spells do
                            local dst=tg.spells[sn]
                            if not dst then dst={damage=0}; tg.spells[sn]=dst end
                            dst.damage=dst.damage+(se.damage or 0)
                        end
                    end
                    if p.healSpells then
                        for sn,se in p.healSpells do
                            local dst=tg.healSpells[sn]
                            if not dst then dst={healing=0}; tg.healSpells[sn]=dst end
                            dst.healing=dst.healing+(se.healing or 0)
                        end
                    end
                else
                    petDmg=petDmg+(p.damage or 0)
                    petHeal=petHeal+(p.healing or 0)
                end
            end
        end

        if D.mode=="damage" then
            if petDmg>0 then
                tt:AddLine(" "); tt:AddDoubleLine("Pet contribution",comma(petDmg),1,0.82,0,1,0.75,0.25)
            end
            if totemDmg>0 then
                tt:AddLine(" "); tt:AddDoubleLine("Totem contribution",comma(totemDmg),1,0.82,0,1,0.75,0.25)
                local tn,tg
                for tn,tg in totemGroups do
                    if (tg.damage or 0)>0 then
                        tt:AddDoubleLine(tn,comma(tg.damage or 0),1,1,1,0.86,0.86,0.86)
                    end
                end
            end
        elseif D.mode=="healing" then
            if petHeal>0 then
                tt:AddLine(" "); tt:AddDoubleLine("Pet contribution",comma(petHeal),1,0.82,0,0.7,1,0.7)
            end
            if totemHeal>0 then
                tt:AddLine(" "); tt:AddDoubleLine("Totem contribution",comma(totemHeal),1,0.82,0,0.7,1,0.7)
                local tn,tg
                for tn,tg in totemGroups do
                    if (tg.healing or 0)>0 then
                        tt:AddDoubleLine(tn,comma(tg.healing or 0),1,1,1,0.86,0.86,0.86)
                    end
                end
            end
        end

        skinCawHoverTooltip(tt)
        tt:Show()
    end)
    bar:SetScript("OnLeave",function() local tt=getPlayerTooltip(); if tt then tt:Hide() end end)
    bar:SetScript("OnMouseWheel",function() if D.scrollBy then if arg1 and arg1>0 then D.scrollBy(-1) else D.scrollBy(1) end end end)
    local row={frame=rowFrame,bar=bar,classIcon=classIcon,rank=rank,left=left,right=right,actor=nil}; bar.detailsRow=row; D.rows[i]=row; i=i+1
end

local function shortNumber(n)
    n=tonumber(n) or 0
    if n>=1000000 then return string.format("%.1fm",n/1000000) end
    if n>=10000 then return string.format("%.1fk",n/1000) end
    return comma(n)
end

-- Chat report --------------------------------------------------------------
function D.reportSegmentName()
    if D.segment=="overall" then return "Overall" end
    if D.segment=="history" then
        local h=getSelectedHistoryFight()
        if h and h.name and h.name~="" then return h.name end
        return "Previous Fight"
    end
    local name=currentFightLabel()
    if name and name~="" then return name end
    return "Current"
end

function D.reportLineForActor(a,rank,dur)
    if D.mode=="damage" then
        local value=actorDisplayDamage(a); local rate=0
        if dur>0 then rate=value/dur end
        return tostring(rank)..". "..tostring(a.name).." - "..comma(value).." ("..string.format("%.1f",rate).." DPS)"
    elseif D.mode=="healing" then
        local value=actorDisplayHealing(a); local rate=0
        if dur>0 then rate=value/dur end
        return tostring(rank)..". "..tostring(a.name).." - "..comma(value).." ("..string.format("%.1f",rate).." HPS)"
    elseif D.mode=="buffs" or D.mode=="debuffsCast" or D.mode=="debuffsReceived" then
        local value=utilityTotal(a,D.mode)
        return tostring(rank)..". "..tostring(a.name).." - "..string.format("%.1fs",value).." ("..string.format("%.1f%%",auraAverageUptime(a,D.mode))..")"
    end
    return tostring(rank)..". "..tostring(a.name).." - "..tostring(utilityTotal(a,D.mode))
end

function D.reportTotalLine(list,count,dur)
    local total=0; local i=1
    if D.mode=="damage" then
        while i<=count do total=total+actorDisplayDamage(list[i]); i=i+1 end
        local rate=0; if dur>0 then rate=total/dur end
        return "Total: "..comma(total).." ("..string.format("%.1f",rate).." DPS)"
    elseif D.mode=="healing" then
        while i<=count do total=total+actorDisplayHealing(list[i]); i=i+1 end
        local rate=0; if dur>0 then rate=total/dur end
        return "Total: "..comma(total).." ("..string.format("%.1f",rate).." HPS)"
    else
        while i<=count do total=total+utilityTotal(list[i],D.mode); i=i+1 end
        if D.mode=="buffs" or D.mode=="debuffsCast" or D.mode=="debuffsReceived" then
            return "Total active: "..string.format("%.1fs",total)
        end
        return "Total: "..tostring(total)
    end
end

function D.sendReport(channel)
    if not channel or not SendChatMessage then
        chat("Chat reporting is unavailable on this client.")
        return
    end

    if channel=="PARTY" then
        local inParty=GetNumPartyMembers and GetNumPartyMembers()>0
        local inRaid=GetNumRaidMembers and GetNumRaidMembers()>0
        if not inParty and not inRaid then chat("You are not in a party."); return end
    end
    if channel=="RAID" and ((not GetNumRaidMembers) or GetNumRaidMembers()<=0) then
        chat("You are not in a raid.")
        return
    end
    if channel=="GUILD" and IsInGuild and not IsInGuild() then
        chat("You are not in a guild.")
        return
    end

    local list,count=sortedActors()
    if count<=0 then
        chat("Nothing to report for the selected mode/segment.")
        return
    end

    local dur=getDuration()
    local label=MODE_LABELS[D.mode] or tostring(D.mode)
    local header="Caw DPS Meter - "..label.." - "..D.reportSegmentName()
    if dur>0 then header=header.." - "..string.format("%.1fs",dur) end

    local ok,err=pcall(SendChatMessage,header,channel)
    if not ok then chat("Report failed: "..tostring(err)); return end

    local limit=count
    if limit>5 then limit=5 end
    local i=1
    while i<=limit do
        local sent,sendErr=pcall(SendChatMessage,D.reportLineForActor(list[i],i,dur),channel)
        if not sent then chat("Report failed: "..tostring(sendErr)); return end
        i=i+1
    end
    pcall(SendChatMessage,D.reportTotalLine(list,count,dur),channel)
end

local function visibleRowCount()
    local h=frame:GetHeight() or 280
    local n=math.floor((h-(LIST_TOP+8))/ROW_STEP)
    if n<1 then n=1 end; if n>MAX_ROWS then n=MAX_ROWS end
    return n
end

-- Scroll controls. The row pool stays small, while the sorted actor list can
-- contain the full 40-player raid. Mouse wheel and the slim right-hand bar move
-- a window over that list.
local scrollTrack=CreateFrame("Frame",nil,frame)
scrollTrack:SetWidth(SCROLL_W); scrollTrack:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-3,-LIST_TOP); scrollTrack:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-3,20)
local trackTex=scrollTrack:CreateTexture(nil,"BACKGROUND"); trackTex:SetAllPoints(scrollTrack); trackTex:SetTexture(FLAT_TEX); trackTex:SetVertexColor(0.10,0.10,0.10,0.95)
local scrollThumb=scrollTrack:CreateTexture(nil,"ARTWORK"); scrollThumb:SetTexture(FLAT_TEX); scrollThumb:SetVertexColor(0.48,0.48,0.48,1); scrollThumb:SetWidth(SCROLL_W-2); scrollThumb:SetHeight(24); scrollThumb:SetPoint("TOP",scrollTrack,"TOP",0,0)

local scrollUp=CreateFrame("Button",nil,frame); scrollUp:SetWidth(12); scrollUp:SetHeight(12); scrollUp:SetPoint("BOTTOM",scrollTrack,"TOP",0,2)
flatPanel(scrollUp,0.06,0.06,0.06,1,0.22)
local upText=scrollUp:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); upText:SetPoint("CENTER",scrollUp,"CENTER",0,0); upText:SetText("^")
local scrollDown=CreateFrame("Button",nil,frame); scrollDown:SetWidth(12); scrollDown:SetHeight(12); scrollDown:SetPoint("TOP",scrollTrack,"BOTTOM",0,-2)
flatPanel(scrollDown,0.06,0.06,0.06,1,0.22)
local downText=scrollDown:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); downText:SetPoint("CENTER",scrollDown,"CENTER",0,0); downText:SetText("v")

local function clampScroll(total)
    local maxOffset=total-visibleRowCount(); if maxOffset<0 then maxOffset=0 end
    if D.scrollOffset<0 then D.scrollOffset=0 end
    if D.scrollOffset>maxOffset then D.scrollOffset=maxOffset end
    return maxOffset
end
local function scrollBy(delta)
    local list,total=sortedActors(); local maxOffset=clampScroll(total)
    D.scrollOffset=D.scrollOffset+delta
    if D.scrollOffset<0 then D.scrollOffset=0 end
    if D.scrollOffset>maxOffset then D.scrollOffset=maxOffset end
    if updateUI then updateUI() end
end
D.scrollBy=scrollBy
scrollUp:SetScript("OnClick",function() scrollBy(-1) end)
scrollDown:SetScript("OnClick",function() scrollBy(1) end)

local wheelArea=CreateFrame("Frame",nil,frame); wheelArea:SetPoint("TOPLEFT",frame,"TOPLEFT",4,-LIST_TOP); wheelArea:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-16,4); wheelArea:EnableMouse(true)
if wheelArea.EnableMouseWheel then wheelArea:EnableMouseWheel(true) end
wheelArea:SetScript("OnMouseWheel",function() if arg1 and arg1>0 then scrollBy(-1) else scrollBy(1) end end)
if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
frame:SetScript("OnMouseWheel",function() if arg1 and arg1>0 then scrollBy(-1) else scrollBy(1) end end)
-- Keep row frames above the mouse-wheel catcher so hover tooltips still work.
if wheelArea.SetFrameLevel then wheelArea:SetFrameLevel(frame:GetFrameLevel()+1) end
local ri=1; while ri<=MAX_ROWS do if D.rows[ri].frame.SetFrameLevel then D.rows[ri].frame:SetFrameLevel(frame:GetFrameLevel()+2) end; ri=ri+1 end

local function updateScrollVisual(total)
    local visible=visibleRowCount(); local maxOffset=clampScroll(total)
    if total<=visible then scrollTrack:Hide(); scrollUp:Hide(); scrollDown:Hide(); return end
    scrollTrack:Show(); scrollUp:Show(); scrollDown:Show()
    local th=scrollTrack:GetHeight() or 100; if th<24 then th=24 end
    local thumbH=math.floor(th*(visible/total)); if thumbH<18 then thumbH=18 end; if thumbH>th then thumbH=th end
    scrollThumb:SetHeight(thumbH)
    local travel=th-thumbH; local y=0; if maxOffset>0 then y=math.floor(travel*(D.scrollOffset/maxOffset)) end
    scrollThumb:ClearAllPoints(); scrollThumb:SetPoint("TOP",scrollTrack,"TOP",0,-y)
end

updateUI=function()
    local dur=getDuration(); local list,count=sortedActors(); local top=1
    if segmentText then segmentText:SetText(selectedSegmentLabel()) end
    if count>0 then top=list[1]._cawDisplayValue or 0 end; if top<=0 then top=1 end
    modeText:SetText(MODE_LABELS[D.mode] or D.mode)
    if D.mode=="damage" then
        local total=totalDamage(); local totalDPS=0; if dur>0 then totalDPS=total/dur end
        summary:SetText("Total: "..shortNumber(total).." | "..string.format("%.1f",totalDPS).." DPS")
    elseif D.mode=="healing" then
        local total=totalHealing(); local totalHPS=0; if dur>0 then totalHPS=total/dur end
        summary:SetText("Total: "..shortNumber(total).." | "..string.format("%.1f",totalHPS).." HPS")
    else
        if D.mode=="buffs" or D.mode=="debuffsCast" or D.mode=="debuffsReceived" then
            local auraTotal=0; local ui=1
            while ui<=count do auraTotal=auraTotal+D.auraEntryCount(list[ui][D.mode]); ui=ui+1 end
            if D.mode=="buffs" then summary:SetText("Tracked buffs: "..tostring(auraTotal))
            else summary:SetText("Tracked debuffs: "..tostring(auraTotal)) end
        else
            local utilTotal=0; local ui=1; while ui<=count do utilTotal=utilTotal+utilityTotal(list[ui],D.mode); ui=ui+1 end
            summary:SetText("Total: "..tostring(utilTotal))
        end
    end
    local rowsVisible=visibleRowCount(); clampScroll(count); updateScrollVisual(count)
    local r=1
    while r<=MAX_ROWS do
        local row=D.rows[r]; local absoluteIndex=D.scrollOffset+r; local a=nil
        if r<=rowsVisible then a=list[absoluteIndex] end
        if a then
            row.actor=a; row.frame:Show(); local value
            value=a._cawDisplayValue or 0
            row.bar:SetMinMaxValues(0,top); row.bar:SetValue(value); local cr,cg,cb=classColor(a); row.bar:SetStatusBarColor(cr,cg,cb)
            local tc=a.classToken and CLASS_ICON_TCOORDS[a.classToken] or nil
            if tc then
                if row.lastClassToken~=a.classToken then
                    row.classIcon:SetTexture(CLASS_ICON_TEXTURE)
                    row.classIcon:SetTexCoord(tc[1],tc[2],tc[3],tc[4])
                    row.lastClassToken=a.classToken
                end
                row.classIcon:Show()
            else
                row.lastClassToken=nil
                row.classIcon:Hide()
            end
            row.rank:SetText(tostring(absoluteIndex).."."); row.left:SetText(tostring(a.name)); row.left:SetTextColor(cr,cg,cb)
            if D.mode=="damage" then local dps=0; if dur>0 then dps=value/dur end; row.right:SetText(shortNumber(value).." | "..string.format("%.1f",dps).." DPS")
            elseif D.mode=="healing" then local hps=0; if dur>0 then hps=value/dur end; row.right:SetText(shortNumber(value).." | "..string.format("%.1f",hps).." HPS")
            elseif D.mode=="buffs" then row.right:SetText(tostring(value).." buffs")
            elseif D.mode=="debuffsCast" or D.mode=="debuffsReceived" then row.right:SetText(tostring(value).." debuffs")
            else row.right:SetText(tostring(value)) end
        else row.actor=nil; row.lastClassToken=nil; if row.classIcon then row.classIcon:Hide() end; row.frame:Hide() end
        r=r+1
    end
end
frame:SetScript("OnUpdate",function()
    if not this.nextUpdate or GetTime()>=this.nextUpdate then
        this.nextUpdate=GetTime()+0.20
        updateUI()
    end
end)

local function finalizeAuraTimers(stopTime)
    local k,a; for k,a in D.actors do
        local kinds={"buffs","debuffsCast","debuffsReceived"}; local i=1
        while i<=table.getn(kinds) do local tbl=a[kinds[i]]; local spell,e; if tbl then for spell,e in tbl do local tk,st; if e.active then for tk,st in e.active do stopAura(tbl,spell,tk,stopTime) end end end end; i=i+1 end
    end
end

local function saveHistory() end

local function finalizePendingCombatEnd()
    if not D.pendingCombatEndAt or D.pendingCombatEndAt<=0 then return end
    if GetTime()<D.pendingCombatEndAt then return end

    -- Sap and similar crowd control can be applied before WoW considers the
    -- player "in combat". Caw already opened a utility segment for the landed
    -- CC, so do not close that segment while the CC is still active. Otherwise
    -- the later damage event would start a fresh segment and the recorded Sap
    -- would appear to vanish exactly when it was broken.
    local ccTarget,ccData
    for ccTarget,ccData in D.activeCC do
        if ccData then
            D.pendingCombatEndAt=GetTime()+0.50
            return
        end
    end

    local stopTime=D.pendingCombatEndStopTime
    if not stopTime or stopTime<=0 then stopTime=GetTime() end

    if D.startTime>0 then
        D.lastDuration=stopTime-D.startTime
        if D.lastDuration<0 then D.lastDuration=0 end
    end
    finalizeAuraTimers(stopTime)
    D.inCombat=false
    D.pendingCombatEndAt=0
    D.pendingCombatEndStopTime=0
    snapshotFinishedFight()
    D.startTime=0
    saveHistory()
    updateUI()
end

-- Events -------------------------------------------------------------------
local events=CreateFrame("Frame","CawDPSMeterEvents",UIParent); D.events=events
-- Sync timing must not depend on the meter window being visible. Hidden frames
-- do not receive OnUpdate on the 1.12 client, so drive sync from this always-on frame.
events:SetScript("OnUpdate",function()
    if finalizeSyncOfferSelection and D.syncNonce and not D.syncSelectedSource
        and (D.syncOfferDeadline or 0)>0 then
        finalizeSyncOfferSelection()
    end
    if table.getn(D.syncQueue)>0 then flushSyncQueue() end
    if D.pendingCombatEndAt and D.pendingCombatEndAt>0 then finalizePendingCombatEnd() end

    -- RavenCraft/custom-client safety net: PLAYER_REGEN_ENABLED can
    -- occasionally be missed on one client. While a fight is open, confirm
    -- the player's actual combat state four times per second. Only schedule
    -- the normal 1.5s grace close after being out of combat for 0.5s, so brief
    -- combat-state flicker does not split an encounter.
    if D.inCombat and UnitAffectingCombat then
        local now=GetTime()
        if now>=(D.combatStateCheckAt or 0) then
            D.combatStateCheckAt=now+0.25
            if UnitAffectingCombat("player") then
                D.outOfCombatSince=0
            else
                if not D.outOfCombatSince or D.outOfCombatSince<=0 then
                    D.outOfCombatSince=now
                elseif now-D.outOfCombatSince>=0.50
                    and (not D.pendingCombatEndAt or D.pendingCombatEndAt<=0) then
                    D.pendingCombatEndStopTime=D.outOfCombatSince
                    D.pendingCombatEndAt=now+(D.combatEndGrace or 1.50)
                    if requestCombatSync then requestCombatSync(true) end
                end
            end
        end
    end
end)
local function reg(ev) local ok=pcall(events.RegisterEvent,events,ev); if ev=="RAW_COMBATLOG" then D.rawRegistered=ok end end
reg("ADDON_LOADED"); reg("RAW_COMBATLOG"); reg("UNIT_CASTEVENT"); reg("CHAT_MSG_ADDON"); reg("PLAYER_REGEN_DISABLED"); reg("PLAYER_REGEN_ENABLED"); reg("PLAYER_ENTERING_WORLD"); reg("PARTY_MEMBERS_CHANGED"); reg("RAID_ROSTER_UPDATE"); reg("UNIT_PET"); reg("UNIT_INVENTORY_CHANGED"); reg("PLAYER_AURAS_CHANGED"); reg("PLAYER_LOGOUT")
refreshRoster()
events:SetScript("OnEvent",function()
    if event=="ADDON_LOADED" then
        if arg1=="CawDPSMeter" or arg1==nil then initializeSavedVariables() end
    elseif event=="UNIT_INVENTORY_CHANGED" then
        -- SuperWoW exposes friendly players' temporary weapon enchants too.
        -- Re-scan on any roster inventory-change event; the event is infrequent
        -- and the updater diffs the cache before touching uptime timers.
        if D.updateWeaponBuffs then D.updateWeaponBuffs() end
    elseif event=="PLAYER_AURAS_CHANGED" then
        if D.scanPlayerBuffs then D.scanPlayerBuffs(true) end
    elseif event=="PLAYER_REGEN_DISABLED" then
        D.outOfCombatSince=0
        D.combatStateCheckAt=0
        -- Re-entering combat during the short grace window means this is still
        -- the same encounter; cancel the pending close instead of resetting.
        if D.pendingCombatEndAt and D.pendingCombatEndAt>0 then
            D.pendingCombatEndAt=0
            D.pendingCombatEndStopTime=0
        end

        -- RAW_COMBATLOG can reach us before this client fires PLAYER_REGEN_DISABLED.
        -- In that case ensureStarted() has already opened the group fight.
        refreshRoster()
        local opened=false
        if not D.inCombat or D.startTime==0 then
            resetFight()
            D.inCombat=true
            D.startTime=GetTime()
            opened=true
        end
        if opened then
            if D.seedActiveRosterBuffs then D.seedActiveRosterBuffs() end
            if requestCombatSync then requestCombatSync() end
        end
        D.segment="current"; D.segmentIndex=0; D.scrollOffset=0
        updateUI()
    elseif event=="PLAYER_REGEN_ENABLED" then
        D.outOfCombatSince=GetTime()
        D.combatStateCheckAt=0
        -- Keep the current fight alive briefly. During this window Caw performs
        -- one final sync pass, trailing RAW events remain attached to the fight,
        -- and very short Vanilla combat drops do not fragment the segment.
        local stopTime=GetTime()
        D.pendingCombatEndStopTime=stopTime
        D.pendingCombatEndAt=stopTime+(D.combatEndGrace or 1.50)
        if requestCombatSync then requestCombatSync(true) end
        updateUI()
    elseif event=="UNIT_CASTEVENT" then
        if D.handleUnitCastCC then D.handleUnitCastCC(arg1,arg2,arg3,arg4) end
    elseif event=="RAW_COMBATLOG" then
        D.rawTotal=D.rawTotal+1
        captureRawDebug(arg1,arg2)
        if D.captureCCDamageCandidate then D.captureCCDamageCandidate(arg1,arg2) end

        -- Pre-combat long buffs must survive until the next segment starts.
        -- Capture the observed RavenCraft self-buff form directly at the RAW
        -- boundary so it cannot be lost in later parser routing:
        -- CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS | You gain Blessing of Might.
        if arg1 and arg2 and string.find(arg1,"_BUFF",1,true) then
            local _,_,preBuff=string.find(arg2,"^You gain (.-)%.")
            if preBuff then
                if not string.find(preBuff,"^[0-9]+ Mana from ")
                    and not string.find(preBuff,"^[0-9]+ Rage from ")
                    and not string.find(preBuff,"^[0-9]+ Energy from ") then
                    local _,_,baseBuff=string.find(preBuff,"^(.-) %([0-9]+%)$")
                    if baseBuff then preBuff=baseBuff end
                    D.activeRosterBuffs["player|"..preBuff]={target="player",spell=preBuff}
                    D.lastPreCombatBuff=preBuff
                end
            end
        end

        parseRaw(arg1,arg2)
    elseif event=="CHAT_MSG_ADDON" then
        if arg1==D.syncPrefix and arg2 then
            D.syncAddonEvents=(D.syncAddonEvents or 0)+1
            applySyncMessage(arg4,arg2)
        end
    elseif event=="PLAYER_LOGOUT" then saveWindowState()
    elseif event=="PLAYER_ENTERING_WORLD" then restoreWindowState(); refreshRoster(); if applyWindowLock then applyWindowLock() end; updateUI()
    elseif event=="PARTY_MEMBERS_CHANGED" or event=="RAID_ROSTER_UPDATE" or event=="UNIT_PET" then refreshRoster() end
end)

-- Commands -----------------------------------------------------------------
SLASH_CAWDPS1="/cawdps"
SLASH_CAWDPS2="/cd"
SlashCmdList["CAWDPS"]=function(msg)
    if msg=="hide" then frame:Hide() elseif msg=="show" then frame:Show()
    elseif msg=="reset" then resetFight(); D.inCombat=false; D.segment="current"; updateUI(); chat("Current combat data reset. Window layout kept.")
    elseif msg=="resetpos" then resetWindowPosition(); saveWindowState(); updateUI(); chat("Window position reset.")
    elseif msg=="resetoverall" then D.overallSegment={actors={},duration=0,fights=0}; updateUI(); chat("Overall segment reset.")
    elseif msg=="current" then D.segment="current"; D.segmentIndex=0; D.scrollOffset=0; updateUI()
    elseif msg=="last" then if D.fightHistory[1] then D.segment="history"; D.segmentIndex=1; D.scrollOffset=0; updateUI() end
    elseif msg=="overall" then D.segment="overall"; D.segmentIndex=0; D.scrollOffset=0; updateUI()
    elseif msg=="damage" or msg=="healing" or msg=="interrupts" or msg=="cc" or msg=="ccBreaks" or msg=="dispels" or msg=="buffs" or msg=="debuffsCast" or msg=="debuffsReceived" then setMode(msg)
    elseif msg=="lock" then D.locked=true; saveWindowState(); applyWindowLock(); chat("Window locked.")
    elseif msg=="unlock" then D.locked=false; saveWindowState(); applyWindowLock(); chat("Window unlocked.")
    elseif msg=="history" then
        chat("Last fights:")
        local i=1
        while i<=table.getn(D.fightHistory) do
            local h=D.fightHistory[i]
            local dmg=0; local heal=0; local k,a
            if h and h.actors then
                for k,a in h.actors do
                    dmg=dmg+(a.damage or 0)
                    heal=heal+(a.healing or 0)
                end
            end
            local dps=0
            if h and h.duration and h.duration>0 then dps=dmg/h.duration end
            chat(tostring(i)..": "..tostring((h and h.name) or "Fight").." - "..comma(dmg).." dmg, "..comma(heal).." heal, "..string.format("%.1fs",(h and h.duration) or 0)..", "..string.format("%.1f DPS",dps))
            i=i+1
        end
    else if frame:IsVisible() then frame:Hide() else frame:Show() end end
end
SLASH_CAWDPSDEBUG1="/cddebug"
SlashCmdList["CAWDPSDEBUG"]=function(msg)
    chat("Caw DPS Meter v"..D.version)
    chat("Client: WoW 1.12 / RavenCraft-Octo compatibility mode")
    chat("SuperAPI RAW_COMBATLOG: "..tostring(D.rawRegistered).." | RAW events: "..tostring(D.rawTotal))
    getAddonSender()
    chat("Caw Sync: requested "..tostring(D.syncRequested).." | request sent "..tostring(D.syncRequestSent).." | received "..tostring(D.syncReceived or 0).." | source "..tostring(D.syncLastSource or "none"))
    chat("Caw Sync API: "..tostring(D.syncAPI or "unknown").." | last error "..tostring(D.syncLastError or "none"))
    chat("Caw Sync transport: addon events "..tostring(D.syncAddonEvents or 0).." | requests seen "..tostring(D.syncRequestsSeen or 0).." | sent "..tostring(D.syncSent or 0))
    chat("SavedVariables: "..tostring(D.savedVariablesReady).." | layout saved: "..tostring(CawDPSMeterDB and CawDPSMeterDB.layoutSaved).." | locked: "..tostring(D.locked))
    chat("Segment: "..tostring(D.segment).." | selected history: "..tostring(D.segmentIndex or 0).." | current target: "..tostring(currentFightLabel()).." | stored fights: "..tostring(table.getn(D.fightHistory)).." | overall fights: "..tostring(D.overallSegment and D.overallSegment.fights or 0))
    chat("Parsed hits: "..tostring(D.parsedTotal).." | last parsed: "..tostring(D.lastParsed))
    chat("Last utility: "..tostring(D.lastUtility or "none").." | ignored outsiders: "..tostring(D.ignoredOutsiders or 0))
    local list,actorCount=sortedActors(); local mapCount=0; local k,v; for k,v in D.guidToActor do mapCount=mapCount+1 end
    chat("Displayed actors: "..tostring(actorCount).." | roster GUIDs: "..tostring(mapCount).." | damage: "..tostring(totalDamage()).." | healing: "..tostring(totalHealing()))
end
SLASH_CAWDPSSYNCDEBUG1="/cdsync"
SlashCmdList["CAWDPSSYNCDEBUG"]=function(msg)
    if msg=="retry" or msg=="test" then
        requestCombatSync(true)
        chat("Sync manual send attempted.")
    end
    getAddonSender()
    chat("Sync requested: "..tostring(D.syncRequested).." | request sent: "..tostring(D.syncRequestSent).." | snapshots received: "..tostring(D.syncReceived or 0).." | source: "..tostring(D.syncLastSource or "none").." | adopted age: "..string.format("%.1fs",D.syncBestAge or 0))
    chat("Sync transport: API "..tostring(D.syncAPI or "unknown").." | attempts "..tostring(D.syncSendAttempts or 0).." | sent "..tostring(D.syncSent or 0).." | addon events "..tostring(D.syncAddonEvents or 0).." | requests seen "..tostring(D.syncRequestsSeen or 0).." | queued "..tostring(table.getn(D.syncQueue)))
    chat("Sync last: channel "..tostring(D.syncLastChannel or "none").." | error: "..tostring(D.syncLastError or "none"))
    chat("Sync wire format: tilde delimiter (chat-safe)")
    chat("Sync source selection: offers "..tostring(syncOfferCount()).." | selected "..tostring(D.syncSelectedSource or "none").." | rejected packets "..tostring(D.syncRejectedSources or 0))
    chat("Sync queue: "..tostring(table.getn(D.syncQueue)).." / "..tostring(D.syncQueueMax or 1000).." | dropped "..tostring(D.syncQueueDropped or 0))
    local graceLeft=0
    if D.pendingCombatEndAt and D.pendingCombatEndAt>GetTime() then graceLeft=D.pendingCombatEndAt-GetTime() end
    if graceLeft>0 then
        chat("Combat-end reconcile: pending "..string.format("%.2fs",graceLeft))
    else
        chat("Combat-end reconcile: idle")
    end
end

SLASH_CAWDPSDAMAGEDEBUG1="/cddamage"
SlashCmdList["CAWDPSDAMAGEDEBUG"]=function(msg)
    local actors=getDisplayActors()
    chat("Damage debug for selected segment:")
    local k,a
    for k,a in actors do
        if a and (a.damage or 0)>0 and not a.isPet then
            chat(tostring(a.name)..": "..tostring(a.damage or 0))
            local spell,entry
            for spell,entry in a.spells do
                if entry and (entry.damage or 0)>0 then
                    chat("  "..tostring(spell)..": "..tostring(entry.damage or 0))
                end
            end
            local petDamage=0
            local pk,pa
            for pk,pa in actors do
                if pa and pa.isPet and pa.ownerKey==a.key then
                    if pa.isTotem then
                        chat("  Totem "..tostring(pa.name or "Totem")..": "..tostring(pa.damage or 0))
                        local ts,te
                        for ts,te in pa.spells do
                            if te and (te.damage or 0)>0 then chat("    "..tostring(ts)..": "..tostring(te.damage or 0)) end
                        end
                    else
                        petDamage=petDamage+(pa.damage or 0)
                    end
                end
            end
            if petDamage>0 then chat("  Pet: "..tostring(petDamage)) end
        end
    end
end

SLASH_CAWDPSCCDEBUG1="/cdcc"
SlashCmdList["CAWDPSCCDEBUG"]=function()
    chat("CC debug:")
    local n=0; local target,c
    for target,c in D.activeCC do
        n=n+1
        chat("active "..tostring(n)..": "..tostring(c and c.spell).." | target "..tostring(target).." | source "..tostring(c and c.sourceKey))
    end
    if n==0 then chat("active CC: none") end
    local h=D.lastCCDamage
    if h then
        chat("last damage: "..tostring(h.source and h.source.name or "?").." -> "..tostring(h.target).." | age "..string.format("%.2f",GetTime()-(h.time or 0)))
    else
        chat("last damage: none")
    end
    chat("last break: "..tostring(D.lastCCBreak or "none"))
end

SLASH_CAWDPSGROUPAURADEBUG1="/cdgroupscan"
SlashCmdList["CAWDPSGROUPAURADEBUG"]=function()
    if D.scanGroupBuffs then D.scanGroupBuffs() end
    chat("Group aura cache:")
    local key,b
    local n=0
    for key,b in D.activeRosterBuffs do
        if b and b.target and b.spell then
            n=n+1
            chat(tostring(b.target).." | "..tostring(b.spell))
            if n>=80 then chat("... output capped at 80 entries"); break end
        end
    end
    if n==0 then chat("No roster buffs found.") end
end

SLASH_CAWDPSAURASCANDEBUG1="/cdaurascan"
SlashCmdList["CAWDPSAURASCANDEBUG"]=function()
    chat("Player aura scan:")
    if not UnitBuff then chat("UnitBuff unavailable."); return end
    local i
    for i=1,32 do
        local ok,texture,count,spellId=pcall(UnitBuff,"player",i)
        if not ok or not texture then break end
        local name=D.getUnitBuffName("player",i,spellId)
        chat(tostring(i)..": "..tostring(name or "unknown").." | spellId "..tostring(spellId or "nil"))
    end
end

SLASH_CAWDPSWEAPONDEBUG1="/cdweapon"
SlashCmdList["CAWDPSWEAPONDEBUG"]=function()
    D.scanWeaponBuffs()
    chat("Weapon buff debug:")
    chat("Player Main Hand: "..tostring(D.weaponBuffState.main))
    chat("Player Off Hand: "..tostring(D.weaponBuffState.off))
    local n=0; local key,b
    for key,b in D.activeRosterBuffs do
        if b and b.weaponBuff then
            n=n+1
            chat(tostring(n)..": "..tostring(b.unit or "?").." | "..tostring(b.target or "?").." | "..tostring(b.spell or "?"))
        end
    end
    if n==0 then chat("Weapon cache: empty") end
end

SLASH_CAWDPSBUFFDEBUG1="/cdbuffs"
SlashCmdList["CAWDPSBUFFDEBUG"]=function()
    chat("Buff debug:")
    chat("inCombat="..tostring(D.inCombat).." | startTime="..tostring(D.startTime).." | selfKey="..tostring(D.selfKey))
    local pg=safeUnitGUID("player")
    chat("playerGUID="..tostring(pg).." | rosterSelf="..tostring(D.guidToActor[pg or D.selfKey]~=nil))
    chat("last RAW self-buff="..tostring(D.lastPreCombatBuff or "none"))
    local n=0; local k,b
    for k,b in D.activeRosterBuffs do
        n=n+1
        chat("cache "..tostring(n)..": "..tostring(k).." -> "..tostring(b and b.spell).." / target "..tostring(b and b.target))
    end
    if n==0 then chat("cache: empty") end
    local si=D.guidToActor[pg or D.selfKey]
    local a=si and D.actors[si.key] or nil
    if not a then
        chat("current actor: none")
    else
        local bn=0; local spell,e
        for spell,e in a.buffs do
            bn=bn+1
            chat("actor buff "..tostring(bn)..": "..tostring(spell).." | count "..tostring(e.count or 0).." | duration "..string.format("%.1f",auraEntryDuration(e)))
        end
        if bn==0 then chat("actor buffs: empty") end
    end
end

SLASH_CAWDPSHEALINGDEBUG1="/cdhealing"
SlashCmdList["CAWDPSHEALINGDEBUG"]=function(msg)
    local actors=getDisplayActors()
    chat("Healing debug for selected segment:")
    local k,a
    for k,a in actors do
        if a and (a.healing or 0)>0 and not a.isPet then
            chat(tostring(a.name)..": "..tostring(a.healing or 0))
            local spell,entry
            for spell,entry in a.healSpells do
                if entry and (entry.healing or 0)>0 then
                    local hits=entry.hits or 0
                    local crits=entry.crits or 0
                    local critPct=0
                    if hits>0 then critPct=(crits/hits)*100 end
                    chat("  "..tostring(spell)..": "..tostring(entry.healing or 0)..
                        " | heals "..tostring(hits)..
                        " | crits "..tostring(crits)..
                        " ("..string.format("%.1f%%",critPct)..")")
                end
            end
            local petHealing=0
            local pk,pa
            for pk,pa in actors do
                if pa and pa.isPet and pa.ownerKey==a.key then
                    petHealing=petHealing+(pa.healing or 0)
                end
            end
            if petHealing>0 then chat("  Pet: "..tostring(petHealing)) end
        end
    end
end

SLASH_CAWDPSRAWDEBUG1="/cdraw"
SlashCmdList["CAWDPSRAWDEBUG"]=function(msg)
    if not D.rawDebugEnabled then
        D.rawDebugLines={}
        D.rawDebugCount=0
        D.rawDebugEnabled=true
        chat("RAW capture started. Perform the interrupt, then type /cdraw again.")
    else
        D.rawDebugEnabled=false
        chat("RAW capture stopped. Captured "..tostring(D.rawDebugCount).." lines (showing up to 80):")
        local n=table.getn(D.rawDebugLines)
        local i=1
        while i<=n do
            chat("["..tostring(i).."] "..tostring(D.rawDebugLines[i]))
            i=i+1
        end
        if D.rawDebugCount>80 then
            chat("More than 80 RAW lines occurred; capture was truncated.")
        end
    end
end
SLASH_CAWDPSRAWUNKNOWN1="/cdunknown"
SlashCmdList["CAWDPSRAWUNKNOWN"]=function(msg) chat("Recent unparsed RAW lines (up to 20):"); local n=table.getn(D.rawUnknown); local i=1; while i<=n do chat("["..tostring(i).."] "..tostring(D.rawUnknown[i])); i=i+1 end end
SLASH_CAWDPSUTILITYUNKNOWN1="/cdutilityunknown"
SlashCmdList["CAWDPSUTILITYUNKNOWN"]=function(msg) chat("Recent unclassified aura/utility lines (up to 20):"); local n=table.getn(D.utilityUnknown); local i=1; while i<=n do chat("["..tostring(i).."] "..tostring(D.utilityUnknown[i])); i=i+1 end end
SLASH_CAWDPSROSTER1="/cdroster"
SlashCmdList["CAWDPSROSTER"]=function(msg) refreshRoster(); chat("Roster GUID map:"); local count=0; local guid,info; for guid,info in D.guidToActor do count=count+1; chat(tostring(info.name).." = "..tostring(guid)..(info.classToken and (" ["..info.classToken.."]") or "")..(info.isPet and " [pet]" or "")) end; chat("Mapped units: "..tostring(count)) end
SLASH_CAWDPSBOOT1="/cdboot"
SlashCmdList["CAWDPSBOOT"]=function(msg) chat("Caw DPS Meter v"..D.version.." loaded; RAW_COMBATLOG="..tostring(D.rawRegistered)) end

updateUI()

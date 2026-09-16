-- Caw DPS Meter diagnostics commands (loaded last)
CAW_DPS_METER = CAW_DPS_METER or {}
local D = CAW_DPS_METER
local oldDebug=SlashCmdList and SlashCmdList["CAWDPSDEBUG"] or nil
local function say(s) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r "..tostring(s)) end end
SLASH_CAWSYNCSTATUS1="/cawsyncstatus"
SlashCmdList.CAWSYNCSTATUS=function()
    local history=CawDPSMeterErrorLog and CawDPSMeterErrorLog.targetSync
    local sessions=history and history.sessions or {}
    local s=D.targetSyncDiagSession or sessions[table.getn(sessions)]
    if not s then say("No target sync activity recorded yet."); return end
    local c=s.counts
    say("Target sync ("..(s==D.targetSyncDiagSession and "this session" or "last saved session")
        ..", "..tostring(s.version).."): requests sent "..(c.REQUEST_SENT or 0)..", complete replies received "..(c.REPLY_RECEIVED or 0)
        ..", replies sent "..(c.REPLY_SENT or 0)..".")
    say("Last result: "..string.lower(string.gsub(s.last or "none","_"," ")).." ("..tostring(s.updatedAt)..").")
    say("A complete transfer does not guarantee complete combat coverage. Diagnostics are saved on /reload or logout.")
end
local function diagStatus()
    local db=D.diagEnsureDB and D.diagEnsureDB() or CawDPSMeterErrorLog
    local e=db and db.entries or {}
    local errors,warns,cals=0,0,0
    local i,r
    for i,r in e do
        if r.level=="ERROR" then errors=errors+1 elseif r.level=="WARN" then warns=warns+1 elseif r.level=="CAL" then cals=cals+1 end
    end
    say("Diagnostics: "..tostring(table.getn(e)).." stored entries | errors "..errors.." | warnings "..warns.." | calibration "..cals.." | total observed "..tostring(db and db.total or 0).." | rolled off "..tostring(db and db.dropped or 0))
    if table.getn(e)>0 then
        r=e[table.getn(e)]
        say("Last: ["..tostring(r.level).."]["..tostring(r.code).."] "..tostring(r.message)..((r.count or 1)>1 and (" (x"..tostring(r.count)..")") or ""))
    else say("No Caw diagnostic entries recorded.") end
end
local function diagDump()
    local db=D.diagEnsureDB and D.diagEnsureDB() or CawDPSMeterErrorLog
    local e=db and db.entries or {}
    local n=table.getn(e)
    say("Last diagnostic entries (max 20 shown):")
    local first=n-19; if first<1 then first=1 end
    local i,r
    for i=first,n do
        r=e[i]
        say("#"..tostring(i).." "..tostring(r.stamp or "").." ["..tostring(r.level).."]["..tostring(r.code).."] "..tostring(r.message)..((r.count or 1)>1 and (" x"..tostring(r.count)) or ""))
    end
end
local function diagIcons()
    local m=D.missingSpellIcons or {}
    local list={}
    local k,v
    for k,v in pairs(m) do table.insert(list,{name=k,count=v.count,spellId=v.spellId}) end
    if table.getn(list)==0 then say("No missing spell icons recorded this session."); return end
    table.sort(list,function(a,b) return (a.count or 0)>(b.count or 0) end)
    say("Missing spell icons this session, most frequent first (report these to extend the icon database):")
    local i
    for i=1,math.min(20,table.getn(list)) do
        local e=list[i]
        say(" - "..tostring(e.name).." x"..tostring(e.count)..(e.spellId and (" [id "..tostring(e.spellId).."]") or " [no id]"))
    end
end
SLASH_CAWDPSDEBUG1="/cddebug"
SlashCmdList["CAWDPSDEBUG"]=function(msg)
    msg=string.lower(tostring(msg or ""))
    if msg=="status" then diagStatus(); return end
    if msg=="clear" then
        CawDPSMeterErrorLog={schema=1,loggerVersion=D.diagVersion,entries={},total=0,dropped=0}
        D.targetSyncDiagSession=nil
        say("Persistent diagnostic log cleared.")
        return
    end
    if msg=="dump" then diagDump(); return end
    if msg=="icons" then diagIcons(); return end
    if msg=="help" then
        say("/cddebug = existing runtime status | /cddebug status | /cddebug dump | /cddebug icons | /cddebug clear")
        return
    end
    if oldDebug then oldDebug(msg) else diagStatus() end
end

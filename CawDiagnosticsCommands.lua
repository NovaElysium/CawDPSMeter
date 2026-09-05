-- Caw DPS Meter diagnostics commands (loaded last)
CAW_DPS_METER = CAW_DPS_METER or {}
local D = CAW_DPS_METER
local oldDebug=SlashCmdList and SlashCmdList["CAWDPSDEBUG"] or nil
local function say(s) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf4dCaw DPS Meter:|r "..tostring(s)) end end
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
SLASH_CAWDPSDEBUG1="/cddebug"
SlashCmdList["CAWDPSDEBUG"]=function(msg)
    msg=string.lower(tostring(msg or ""))
    if msg=="status" then diagStatus(); return end
    if msg=="clear" then
        CawDPSMeterErrorLog={schema=1,loggerVersion=D.diagVersion,entries={},total=0,dropped=0}
        say("Persistent diagnostic log cleared.")
        return
    end
    if msg=="dump" then diagDump(); return end
    if msg=="help" then
        say("/cddebug = existing runtime status | /cddebug status | /cddebug dump | /cddebug clear")
        return
    end
    if oldDebug then oldDebug(msg) else diagStatus() end
end

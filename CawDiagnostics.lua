-- Caw DPS Meter persistent diagnostics bootstrap (RC37)
-- Loaded first so Caw load-time Lua errors can be retained until SavedVariables are ready.
CAW_DPS_METER = CAW_DPS_METER or {}
local D = CAW_DPS_METER
D.diagVersion = "RC37-1"
D.diagMaxEntries = 400
D.diagBuffer = D.diagBuffer or {}
D.diagInHandler = false
D.diagSession = tostring({})

function D.diagStamp()
    if date then return date("%Y-%m-%d %H:%M:%S") end
    return ""
end

function D.diagNow()
    return GetTime and GetTime() or 0
end

function D.diagEnsureDB()
    CawDPSMeterErrorLog = CawDPSMeterErrorLog or {}
    -- RC34 accidentally treated the diagnostics handler's own stack frame as
    -- proof that every Lua error belonged to Caw. Drop that polluted RC34 log
    -- once on upgrade so RC35 starts with trustworthy data.
    if CawDPSMeterErrorLog.loggerVersion=="RC34-1" then
        CawDPSMeterErrorLog.entries={}
        CawDPSMeterErrorLog.total=0
        CawDPSMeterErrorLog.dropped=0
    end
    CawDPSMeterErrorLog.schema = 1
    CawDPSMeterErrorLog.loggerVersion = D.diagVersion
    CawDPSMeterErrorLog.entries = CawDPSMeterErrorLog.entries or {}
    CawDPSMeterErrorLog.total = CawDPSMeterErrorLog.total or 0
    CawDPSMeterErrorLog.dropped = CawDPSMeterErrorLog.dropped or 0
    return CawDPSMeterErrorLog
end

function D.diagInsert(rec)
    if not rec then return end
    local db = CawDPSMeterErrorLog
    if not db or not db.entries then
        table.insert(D.diagBuffer, rec)
        while table.getn(D.diagBuffer) > 80 do table.remove(D.diagBuffer,1) end
        return
    end
    local entries = db.entries
    local n = table.getn(entries)
    local last = n > 0 and entries[n] or nil
    -- Collapse identical warnings/errors that repeat rapidly (timeouts, ambiguous pets, etc.).
    if last and last.session==rec.session and last.level==rec.level and last.code==rec.code and last.message==rec.message
        and last.context==rec.context and last.stack==rec.stack
        and (rec.gameTime or 0)-(last.gameTime or 0)>=0 and (rec.gameTime or 0)-(last.gameTime or 0)<=10 then
        last.count=(last.count or 1)+1
        last.lastSeen=rec.stamp
        last.gameTime=rec.gameTime
        db.total=(db.total or 0)+1
        return
    end
    table.insert(entries,rec)
    db.total=(db.total or 0)+1
    while table.getn(entries) > (D.diagMaxEntries or 400) do
        table.remove(entries,1)
        db.dropped=(db.dropped or 0)+1
    end
end

function D.diagLog(level,code,message,context,stack)
    local rec={
        session=D.diagSession,
        stamp=D.diagStamp(), gameTime=D.diagNow(),
        level=level or "INFO", code=code or "GENERAL",
        message=tostring(message or ""), context=context,
        stack=stack, addonVersion=D.version or "load-time", count=1
    }
    D.diagInsert(rec)
end
function D.diagWarn(code,message,context) D.diagLog("WARN",code,message,context,nil) end
function D.diagCal(code,message,context) D.diagLog("CAL",code,message,context,nil) end
function D.diagError(code,message,context,stack) D.diagLog("ERROR",code,message,context,stack) end

function D.diagFlushBuffer()
    D.diagEnsureDB()
    local i=1
    while i<=table.getn(D.diagBuffer) do D.diagInsert(D.diagBuffer[i]); i=i+1 end
    D.diagBuffer={}
end

-- Preserve Blizzard's/current client's error presentation while passively recording Caw errors.
if geterrorhandler and seterrorhandler and not D.diagErrorHandlerInstalled then
    D.diagPreviousErrorHandler=geterrorhandler()
    D.diagErrorHandlerInstalled=true
    seterrorhandler(function(err)
        if D.diagInHandler then return end
        D.diagInHandler=true
        local msg=tostring(err or "unknown Lua error")
        local stack=nil
        if debugstack then
            local ok,s=pcall(debugstack,2,12,12)
            if ok then stack=s end
        end
        -- The handler itself necessarily appears in debugstack(). RC34 searched
        -- the whole stack for "CawDPSMeter", so CawDiagnostics.lua caused errors
        -- from unrelated addons to be recorded as ours. Ignore our handler line
        -- and inspect the actual error message / remaining stack only.
        local cleanStack=tostring(stack or "")
        cleanStack=string.gsub(cleanStack,"[^\n]*CawDiagnostics%.lua[^\n]*\n?","")
        local hay=msg.."\n"..cleanStack
        if string.find(hay,"Interface\\AddOns\\CawDPSMeter\\",1,true) or string.find(msg,"CawDPSMeter",1,true) or string.find(msg,"CawThreat",1,true) or string.find(msg,"CAW_DPS_METER",1,true) then
            D.diagError("LUA",msg,nil,stack)
        end
        local prev=D.diagPreviousErrorHandler
        if prev then pcall(prev,err) end
        D.diagInHandler=false
    end)
end



-- RC36 one-time SavedVariables housekeeping.
-- CawDPSMeterLog is still retained as a declared SavedVariable because the
-- old developer commands can intentionally populate it.  We only delete the
-- stale pre-RC36 payload once, then mark the migration complete so a freshly
-- captured developer log survives later reloads.  Empty calibration sessions
-- are safe to discard; sessions containing any captured data are preserved.
function D.cleanupLegacySavedVariables()
    CawDPSMeterDB=CawDPSMeterDB or {}
    if (CawDPSMeterDB.savedVariablesCleanupVersion or 0) >= 1 then return end

    local clearedLegacyLog=false
    local removedEmptyCalibration=0

    if CawDPSMeterLog~=nil then
        CawDPSMeterLog=nil
        clearedLegacyLog=true
    end

    if CawThreatCalibrationDB and CawThreatCalibrationDB.sessions then
        local kept={}
        local i=1
        while i<=table.getn(CawThreatCalibrationDB.sessions) do
            local sess=CawThreatCalibrationDB.sessions[i]
            local hasData=false
            if sess then
                if (sess.requests or 0)>0 or (sess.responses or 0)>0 then hasData=true end
                if sess.events and table.getn(sess.events)>0 then hasData=true end
                if sess.casts and table.getn(sess.casts)>0 then hasData=true end
                if sess.snapshots and table.getn(sess.snapshots)>0 then hasData=true end
            end
            if hasData then
                table.insert(kept,sess)
            else
                removedEmptyCalibration=removedEmptyCalibration+1
            end
            i=i+1
        end
        CawThreatCalibrationDB.sessions=kept
    end

    CawDPSMeterDB.savedVariablesCleanupVersion=1
    CawDPSMeterDB.savedVariablesCleanupAt=D.diagStamp()
    D.diagLog("INFO","SV_CLEANUP","legacy SavedVariables cleanup",
        "legacyLog="..(clearedLegacyLog and "cleared" or "none")..
        " emptyCalibrationSessions="..tostring(removedEmptyCalibration),nil)
end

D.diagBootstrapFrame=D.diagBootstrapFrame or CreateFrame("Frame")
D.diagBootstrapFrame:RegisterEvent("ADDON_LOADED")
D.diagBootstrapFrame:RegisterEvent("PLAYER_LOGOUT")
D.diagBootstrapFrame:SetScript("OnEvent",function()
    if event=="ADDON_LOADED" and (arg1=="CawDPSMeter" or arg1==nil) then
        D.diagFlushBuffer()
        D.cleanupLegacySavedVariables()
    elseif event=="PLAYER_LOGOUT" then
        D.diagFlushBuffer()
    end
end)

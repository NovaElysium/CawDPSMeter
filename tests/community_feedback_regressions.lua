local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS COMMUNITY '..label) end
local function click(f) this=f; arg1='LeftButton'; f.scripts.OnClick() end
for i=2,D.multiWindowMax do if D.multiWindows[i] then D.removeMultiWindow(D.multiWindows[i]) end end
CawDPSMeterCharDB.closedWindows={}; CawDPSMeterCharDB.pfDockMain=false
CawDPSMeterCharDB.pfDockRevision=2; pfUI=nil; D.pfDockDetach(D.window)
D.appearance=D.uiCopySettings(nil); D.uiSetMeterShown(D.window,true)
local extra=D.createMultiWindow({mode='threat',width=180,height=125,centerX=120,centerY=-90})
local second=D.createMultiWindow({mode='healing',width=240,height=160,centerX=-170,centerY=80})
local third=D.createMultiWindow({mode='damageTaken',width=300,height=180,centerX=20,centerY=20})
local positions={}
for i,v in ipairs({D.mainView,extra,second,third}) do
    v.frame.GetCenter=function(f)
        local ux,uy=UIParent:GetCenter(); local factor=UIParent:GetEffectiveScale()/f:GetEffectiveScale()
        return ux*factor+f.lastPoint[4],uy*factor+f.lastPoint[5]
    end
    v.frame.GetPoint=function(f) return unpack(f.lastPoint) end
    D.uiAnchorCenter(v.frame,i*30,-i*20)
    positions[v.frame]={D.uiCenterOffset(v.frame)}
end
for _,source in ipairs({D.mainView,extra}) do
    local v=nil
    if source~=D.mainView then v=source end
    local s=D.uiSettings(v)
    s.scale=v and 0.8 or 0.65; s.rowHeight=v and 19 or 27; s.rowGap=3
    s.headerHeight=32; s.footerHeight=25; s.showFooter=true
    s.barColour={0.3,0.4,0.5}; s.classBars=false
    local rows=v and 3 or 9; local width=v and 335 or 610
    source.frame:SetWidth(width); source.frame:SetHeight(D.uiHeightForRows(v,rows))
    D.uiSetLock(v,not v); D.openOptions(v); click(D.optionsPanel.copyButton)
    for _,dest in ipairs({D.mainView,extra,second,third}) do
        local settings=D.uiSettings(dest)
        check(dest.frame:GetWidth()==width and D.uiVisibleRows(dest,dest.frame)==rows
            and dest.frame:GetScale()==s.scale,'copy from '..source.id..' applies width, bar count and scale to '..dest.id)
        local locked=dest.locked
        if dest==D.mainView then locked=D.locked end
        check(locked==(not v),
            'copy from '..source.id..' applies lock to '..dest.id)
        local x,y=D.uiCenterOffset(dest.frame); local pos=positions[dest.frame]
        check(math.abs(x-pos[1])<0.0001 and math.abs(y-pos[2])<0.0001,'copy preserves position of '..dest.id)
        assert(settings.rowHeight==s.rowHeight and settings.headerHeight==32 and settings.footerHeight==25)
    end
    check(extra.mode=='threat' and second.mode=='healing' and third.mode=='damageTaken',
        'copy preserves independently selected meter modes')
    check(D.appearance~=extra.appearance and extra.appearance~=second.appearance
        and D.appearance.barColour~=extra.appearance.barColour,'copied colours and settings are independent tables')
end
for _,v in ipairs({D.mainView,extra,second,third}) do v.frame.GetCenter=nil; v.frame.GetPoint=nil end

local function data()
    D.actors={['0x1']={key='0x1',guid='0x1',name='Hunter',classToken='HUNTER',damage=15,spells={}}}
    D.overallSegment={actors={['0x1']=D.actors['0x1']},duration=30,fights=2}
    D.fightHistory={{name='Saved fight',duration=20,actors={}}}
    D.segment='current'; D.segmentIndex=0
    extra.segment='history'; extra.segmentIndex=1
    return D.actors,D.overallSegment,D.fightHistory
end
local current,overall,history=data()
click(D.mainView.resetButton)
local dialog=D.resetDialog
check(dialog:IsShown() and not dialog.scopes,'reset opens one confirmation without extra choices')
click(dialog.cancelButton)
check(D.actors==current and next(D.actors) and D.overallSegment==overall and D.fightHistory==history,
    'cancel keeps all combat data')
local appearance=D.appearance; local width=D.window:GetWidth()
for _,view in ipairs({D.mainView,extra}) do
    for _,overflow in ipairs({false,true}) do
        data()
        if overflow then click(view.overflowButton); click(view.overflowMenu.buttons[4])
        else click(view.resetButton) end
        check(next(D.actors) and next(D.overallSegment.actors) and #D.fightHistory==1,
            'opening reset does not delete data before confirmation')
        click(dialog.confirmButton)
        check(not next(D.actors) and not next(D.overallSegment.actors) and D.overallSegment.fights==0
            and #D.fightHistory==0 and D.segment=='current' and extra.segment=='current' and extra.segmentIndex==0,
            'reset clears Current, Overall and history from window '..view.id..' overflow='..tostring(overflow))
    end
end
data(); SlashCmdList.CAWDPS('reset')
check(not next(D.actors) and not next(D.overallSegment.actors) and #D.fightHistory==0
    and D.segment=='current' and extra.segment=='current','slash reset also clears all combat data and window selections')
check(D.appearance==appearance and D.window:GetWidth()==width and extra.mode=='threat'
    and not dialog:IsShown(),'combat reset preserves window settings and closes the dialog')
for _,b in ipairs({dialog.confirmButton,dialog.cancelButton}) do
    local x,y=b.lastPoint[4],-b.lastPoint[5]
    check(x>=0 and x+b:GetWidth()<=dialog:GetWidth() and y+b:GetHeight()<=dialog:GetHeight(),
        'reset control fits inside the dialog: '..b.text:GetText())
end

-- Drive the actual OnUpdate handler at 60 FPS, with no server replies.
PARTY_COUNT=1; PLAYER_COMBAT=true; NOW=NOW+100
UNITS.target={guid='0xF1',name='Enemy',hostile=true}
IsAddOnLoaded=function() return false end
D.setParserEnabled(true); D.threatCalEnabled=false; D.threatCalStart()
local oldMessage,oldSend=DEFAULT_CHAT_FRAME.AddMessage,SendAddonMessage
local chat,requests={},{}
DEFAULT_CHAT_FRAME.AddMessage=function(_,msg) table.insert(chat,msg) end
SendAddonMessage=function(prefix,...)
    if prefix=='TWT_UDTSv4' then table.insert(requests,NOW) end
    return oldSend(prefix,unpack(arg))
end
local send=D.threatCalSendRequest; local attempts=0
D.threatCalSendRequest=function() attempts=attempts+1; return send() end
local function tick(t)
    NOW=t; this=D.threatCalFrame; this.scripts.OnUpdate()
    assert(#D.threatCalPendingRequests<=1,'multiple simultaneous threat requests')
end
local start=NOW
for i=0,180*60 do tick(start+i/60) end
check(#requests<=10 and attempts<50,'three minutes of missing replies cause bounded requests and sparse retry processing')
check(#chat==0,'repeated threat timeouts produce no chat messages')
check(D.threatCalTimeoutStreak>=5 and D.threatCalApiRetryAt-D.threatCalLastTimeoutAt==30,
    'repeated failures back off to 30 seconds')
for i=6,#requests do assert(requests[i]-requests[i-1]>=30) end
check(true,'requests remain at least 30 seconds apart during sustained failures')

-- An unrelated or expired response must not reset failure throttling, including
-- when calibration recording is active (the old second reset lived there).
local streak,retry=D.threatCalTimeoutStreak,D.threatCalApiRetryAt
local failedGuid=UNITS.target.guid
UNITS.target.guid='0xF2'
fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT ','TWTv4=Hunter:1:99:100:1','PARTY','Hunter')
check(D.threatCalTargetRetries[failedGuid].streak==streak and D.threatCalTargetRetries[failedGuid].untilTime==retry,
    'unmatched response cannot cancel the previous target backoff while recording')
tick(math.max(NOW+2,retry+0.01))
check(#D.threatCalPendingRequests==1,'automatic retry continues after backoff')
NOW=NOW+0.05
fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT ','TWTv4=Hunter:1:100:100:1','PARTY','Hunter')
check(D.threatCalTimeoutStreak==0 and D.serverThreatCurrent()
    and D.serverThreatCurrent().actors[1]._serverThreatValue==100,'matching reply restores live threat and normal polling')
local before=#requests
tick(NOW+0.51)
check(#requests==before+1,'healthy replies restore the normal polling interval')
start=NOW
for i=1,80*60 do tick(start+i/60) end
check(#chat==0 and D.threatCalTimeoutStreak>=5,'another timeout episode stays silent and slows requests again')

-- A throwing transport also gets backoff instead of a 0.5-second error loop.
D.threatCalPendingRequests={}; D.threatCalTimeoutStreak=0; D.threatCalApiRetryAt=0; D.threatCalNextRequest=0
local failures=0
SendAddonMessage=function() failures=failures+1; error('test transport unavailable') end
start=NOW+2
for i=0,120*60 do tick(start+i/60) end
check(failures<=9 and #D.threatCalPendingRequests==0 and not D.threatCalObservedRequest,
    'transport exceptions back off and release pending requests')
check(#chat==0,'transport retry handling stays silent in chat')
DEFAULT_CHAT_FRAME.AddMessage=oldMessage; SendAddonMessage=oldSend; D.threatCalSendRequest=send
print('Community feedback checks: '..checks)

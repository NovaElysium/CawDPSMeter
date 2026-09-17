-- Realistic frame coordinates catch scale/clamp ordering that the basic UI mock cannot.
local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS WINDOW STATE '..label) end
local function near(a,b) return math.abs(a-b)<0.00001 end
local function click(f) this=f; arg1='LeftButton'; f.scripts.OnClick() end
local function clearWindows()
    for i=2,D.multiWindowMax do if D.multiWindows[i] then D.removeMultiWindow(D.multiWindows[i]) end end
    CawDPSMeterCharDB.closedWindows={}
end
clearWindows()
pfUI=nil; CawDPSMeterCharDB.pfDockMain=false; CawDPSMeterCharDB.pfDockRevision=2
D.pfDockDetach(D.window); D.appearance=D.uiCopySettings(nil); D.uiSetMeterShown(D.window,true)
local original={}
local function geometry(f)
    if original[f] then return end
    local names={'GetCenter','GetLeft','GetRight','GetTop','GetBottom','GetPoint'}
    original[f]={}
    for _,name in ipairs(names) do original[f][name]=rawget(f,name) or false end
    f.GetPoint=function(self) return unpack(self.lastPoint) end
    f.GetCenter=function(self)
        local p=self.lastPoint
        assert(p and p[1]=='CENTER' and p[3]=='CENTER','expected a free center anchor')
        local x,y=UIParent:GetCenter(); local factor=UIParent:GetEffectiveScale()/self:GetEffectiveScale()
        return x*factor+p[4],y*factor+p[5]
    end
    f.GetLeft=function(self) local x=self:GetCenter(); return x-self:GetWidth()/2 end
    f.GetRight=function(self) local x=self:GetCenter(); return x+self:GetWidth()/2 end
    f.GetTop=function(self) local _,y=self:GetCenter(); return y+self:GetHeight()/2 end
    f.GetBottom=function(self) local _,y=self:GetCenter(); return y-self:GetHeight()/2 end
end
local parentMethods={}
for _,name in ipairs({'GetCenter','GetLeft','GetRight','GetTop','GetBottom'}) do parentMethods[name]=rawget(UIParent,name) or false end
UIParent.GetCenter=function() return 960/UIParent:GetScale(),540/UIParent:GetScale() end
UIParent.GetLeft=function() return 0 end; UIParent.GetBottom=function() return 0 end
UIParent.GetRight=function() return 1920/UIParent:GetScale() end
UIParent.GetTop=function() return 1080/UIParent:GetScale() end
geometry(D.window)
local oldClamp=D.clampMultiWindow
D.clampMultiWindow=function(f) geometry(f); return oldClamp(f) end
local restore=upvalue(D.events.scripts.OnEvent,'restoreWindowState')
for _,parentScale in ipairs({1,0.8}) do
    UIParent:SetScale(parentScale)
    for _,scale in ipairs({0.65,1.4}) do
        for _,edge in ipairs({'left','right','top','bottom'}) do
            local w,h=440,178
            local ux,uy=UIParent:GetCenter()
            local x=edge=='left' and -ux+w*scale/2+3 or (edge=='right' and ux-w*scale/2-3 or 0)
            local y=edge=='bottom' and -uy+h*scale/2+3 or (edge=='top' and uy-h*scale/2-3 or 0)
            D.appearance=D.uiCopySettings({scale=scale}); CawDPSMeterDB.appearance=D.uiCopySettings(D.appearance)
            D.window:SetWidth(w); D.window:SetHeight(h); D.window:SetScale(scale); D.uiAnchorCenter(D.window,x,y)
            for i=1,10 do
                D.uiSaveMain(); D.window:SetScale(1); D.appearance=nil
                restore(); D.applyCompactWindowLayout()
                local ax,ay=D.uiCenterOffset(D.window)
                assert(near(ax,x) and near(ay,y),'main reload drift '..edge..' scale '..scale)
            end
            check(true,'10 main reloads preserve '..edge..' position at '..scale..' / UI scale '..parentScale)
            -- Force a fresh frame once, then exercise pooled restoration at a different prior scale.
            clearWindows(); D.multiWindowPool={}
            local saved={width=w,height=h,centerX=x,centerY=y,appearance={scale=scale}}
            local v=D.createMultiWindow(saved)
            for i=1,10 do
                local ax,ay=D.uiCenterOffset(v.frame)
                assert(near(ax,x) and near(ay,y),'extra reload drift '..edge..' scale '..scale)
                local snapshot=D.multiWindowSnapshot(v)
                D.removeMultiWindow(v); v.frame:SetScale(1.2); v=D.createMultiWindow(snapshot)
            end
            check(true,'fresh and 10 pooled restores preserve '..edge..' at '..scale..' / UI scale '..parentScale)
        end
    end
end
-- The correction still brings truly off-screen windows back into reach.
D.uiAnchorCenter(D.window,-3000,3000); D.uiClamp(D.window)
local ratio=D.window:GetEffectiveScale()/UIParent:GetEffectiveScale()
check(near(D.window:GetLeft()*ratio,-8) and near(D.window:GetTop()*ratio,UIParent:GetTop()+8),'off-screen recovery still clamps to the screen')
clearWindows(); UIParent:SetScale(1)
local v=D.createMultiWindow({mode='threat',width=382,height=222,centerX=-760,centerY=-240,
    locked=true,appearance={scale=0.65,rowHeight=27,hideRaid=true}})
local oldFrame=v.frame
click(v.closeButton)
check(v.closed and not D.multiWindows[2] and CawDPSMeterCharDB.extraWindowCount==0,'X closes an extra without keeping it in the active list')
D.multiWindowsRestored=false; D.restoreMultiWindows()
check(not D.multiWindows[2] and #CawDPSMeterCharDB.closedWindows==1,'reload does not reopen a closed window or discard its saved layout')
v=D.createMultiWindow(nil)
local x,y=D.uiCenterOffset(v.frame)
check(v.frame==oldFrame and near(x,-760) and near(y,-240) and v.frame:GetWidth()==382
    and v.frame:GetHeight()==222 and v.appearance.scale==0.65 and v.appearance.rowHeight==27
    and v.appearance.hideRaid and v.locked and v.mode=='threat','Add window restores the complete last closed layout')
D.removeMultiWindow(v); D.multiWindowPool={} -- Frames do not survive an actual reload.
D.multiWindowsRestored=false; D.restoreMultiWindows(); SlashCmdList.CAWDPS('show')
v=D.multiWindows[2]; x,y=D.uiCenterOffset(v.frame)
check(v and near(x,-760) and near(y,-240) and v.appearance.scale==0.65 and #CawDPSMeterCharDB.closedWindows==0,
    'explicit show restores closed layouts even without the old frame pool')
local second=D.createMultiWindow({mode='healing',centerX=160,centerY=-80,appearance={scale=1.1}})
D.removeMultiWindow(v); D.removeMultiWindow(second); SlashCmdList.CAWDPS('show')
check(D.multiWindows[2].mode=='healing' and D.multiWindows[3].mode=='threat'
    and #CawDPSMeterCharDB.closedWindows==0,'show reopens multiple closed meters with their individual settings')
D.uiAnchorCenter(D.window,-710,190); local mainScale=D.window:GetScale()
click(D.mainView.closeButton); SlashCmdList.CAWDPS('show'); x,y=D.uiCenterOffset(D.window)
check(near(x,-710) and near(y,190) and D.window:GetScale()==mainScale,'closing and showing the main meter keeps its scaled position')
clearWindows()
-- Leave geometry out of context/docking checks, which use other anchor types.
D.clampMultiWindow=oldClamp
for f,methods in pairs(original) do for name,value in pairs(methods) do f[name]=value or nil end end
for name,value in pairs(parentMethods) do UIParent[name]=value or nil end
local oldParty,oldRaid,oldInstance,oldBattlefield=GetNumPartyMembers,GetNumRaidMembers,IsInInstance,GetBattlefieldStatus
local party,raid,instance,queue=0,0,nil,nil
GetNumPartyMembers=function() return party end; GetNumRaidMembers=function() return raid end
IsInInstance=function() return instance~=nil,instance end
GetBattlefieldStatus=function(i) if i==2 then return queue end end
local function context(ev) fire(D.uiVisibilityEvents,ev or 'PARTY_MEMBERS_CHANGED') end
D.appearance=D.uiCopySettings(nil); context(); D.uiRefresh(nil); D.uiSetMeterShown(D.window,true)
v=D.createMultiWindow({appearance={hideParty=true}})
check(D.window:IsShown() and v.frame:IsShown(),'all automatic hiding defaults off')
D.openOptions(nil)
local p=D.optionsPanel
local control=p.controls.hideSolo.check; control:SetChecked(true); click(control)
check(not D.window:IsShown() and v.frame:IsShown() and CawDPSMeterDB.appearance.hideSolo,
    'solo checkbox hides only the selected window and persists immediately')
party=1; context()
check(D.window:IsShown() and not v.frame:IsShown(),'joining a party applies independent rules to both windows')
D.saveMultiWindows()
check(CawDPSMeterCharDB.extraWindowCount==1 and CawDPSMeterCharDB.extraWindows[1].appearance.hideParty,
    'auto-hidden extra windows survive saving')
local saved=CawDPSMeterCharDB.extraWindows[1]
D.removeMultiWindow(v); CawDPSMeterCharDB.closedWindows={}; v=D.createMultiWindow(saved)
check(not v.frame:IsShown() and v.frame.cawHiddenByContext,'restoring an auto-hidden extra applies its rule immediately')
raid=10; D.uiSettings().hideRaid=true; context('RAID_ROSTER_UPDATE')
check(not D.window:IsShown() and v.frame:IsShown(),'raid membership takes precedence over party membership')
instance='pvp'; context('ZONE_CHANGED_NEW_AREA')
check(D.window:IsShown() and v.frame:IsShown(),'battleground uses its own rule instead of the raid rule')
D.uiSettings().hideBattleground=true; D.uiRefresh(nil)
check(not D.window:IsShown(),'battleground checkbox applies immediately')
instance=nil; raid=0; party=0; D.uiSettings().hideSolo=false; queue='queued'; context('UPDATE_BATTLEFIELD_STATUS')
check(D.window:IsShown(),'a battleground queue is not treated as being inside')
queue='confirm'; context('UPDATE_BATTLEFIELD_STATUS'); check(D.window:IsShown(),'a battleground invitation keeps the solo rule')
IsInInstance=nil; queue='active'; context('UPDATE_BATTLEFIELD_STATUS')
check(not D.window:IsShown(),'Vanilla battlefield status detects battlegrounds without IsInInstance')
queue=nil; context('PLAYER_ENTERING_WORLD'); check(D.window:IsShown(),'leaving the battleground restores the solo window')
-- Hiding a window must not change combat input or the data it already holds.
local actors,parser,sync=D.actors,D.parserEnabled(),CawDPSMeterCharDB.combatSyncEnabled
D.uiSettings().hideSolo=true; D.uiRefresh(nil)
check(D.actors==actors and D.parserEnabled()==parser and CawDPSMeterCharDB.combatSyncEnabled==sync,
    'auto-hiding leaves recording, sync and combat data untouched')
SlashCmdList.CAWDPS('hide'); party=1; context()
check(not D.window:IsShown() and not v.frame:IsShown(),'manual hide while already auto-hidden stays hidden after context changes')
SlashCmdList.CAWDPS('show')
check(D.window:IsShown() and not v.frame:IsShown(),'manual show still respects automatic hiding')
-- Context rules and pfUI chat visibility must never reveal each other's hidden windows.
v.appearance.hideParty=false; v.pfDock=true; CawDPSMeterCharDB.pfDockMain=true
CawDPSMeterCharDB.pfDockAlternate=false; pfUI={chat={right=CreateFrame('Frame',nil,UIParent)}}
D.pfDockUpdate(); check(D.window:IsShown() and v.frame:IsShown(),'eligible docked meters follow visible chat')
pfUI.chat.right:Hide(); D.pfDockUpdate(); party=0; context()
check(not D.window:IsShown() and not v.frame:IsShown(),'chat and solo hiding can be active together')
pfUI.chat.right:Show(); D.pfDockUpdate()
check(not D.window:IsShown() and v.frame:IsShown() and v.frame.lastPoint[2]==pfUI.chat.right,
    'showing chat does not reveal a solo-hidden meter or leave a gap in the dock')
pfUI.chat.right:Hide(); D.pfDockUpdate(); party=1; context()
check(not D.window:IsShown() and not v.frame:IsShown(),'leaving solo does not reveal meters while chat remains hidden')
pfUI.chat.right:Show(); D.pfDockUpdate()
check(D.window:IsShown() and v.frame:IsShown(),'both meters reappear when all hiding reasons clear')
SlashCmdList.CAWDPS('hide'); pfUI.chat.right:Hide(); D.pfDockUpdate(); pfUI.chat.right:Show(); D.pfDockUpdate()
check(not D.window:IsShown() and not v.frame:IsShown(),'chat switching cannot reopen manually hidden meters')
SlashCmdList.CAWDPS('show'); party=0; context(); D.pfDockToggle(nil)
check(not D.window:IsShown(),'undocking keeps an automatic hiding rule active')
v.appearance.hideSolo=true; D.uiRefresh(v); D.pfDockToggle(v)
check(not v.frame:IsShown(),'undocking an extra also respects automatic hiding')
pfUI=nil; D.pfDockUpdate()
local shows,hides,reads=0,0,0
local show,hide=D.window.Show,D.window.Hide
D.window.Show=function(self) shows=shows+1; show(self) end
D.window.Hide=function(self) hides=hides+1; hide(self) end
GetNumPartyMembers=function() reads=reads+1; return party end
for i=1,100 do D.pfDockUpdate() end
check(shows==0 and hides==0 and reads==0,'unchanged docking ticks reuse context without repeated Show/Hide or roster queries')
D.window.Show=show; D.window.Hide=hide
-- Combat state follows the player, not the parser's delayed segment finalization.
D.appearance=D.uiCopySettings(nil); v.appearance=D.uiCopySettings(nil)
D.uiSettings().hideInCombat=true; v.appearance.hideOutOfCombat=true
context('PLAYER_REGEN_ENABLED')
check(D.window:IsShown() and not v.frame:IsShown(),'out-of-combat hiding is independent for each window')
D.inCombat=false; context('PLAYER_REGEN_DISABLED')
check(not D.window:IsShown() and v.frame:IsShown(),'combat start applies player combat state even before a meter segment opens')
D.inCombat=true; context('PLAYER_REGEN_ENABLED')
check(D.window:IsShown() and not v.frame:IsShown(),'combat end restores visibility without waiting for the meter end grace period')
party=1; v.appearance.hideParty=true; context(); context('PLAYER_REGEN_DISABLED')
check(not v.frame:IsShown(),'combat visibility cannot override a matching group hiding rule')
D.uiSettings().hideOutOfCombat=true; context('PLAYER_REGEN_ENABLED')
check(not D.window:IsShown(),'both combat hiding options keep the window hidden outside combat')
context('PLAYER_REGEN_DISABLED'); check(not D.window:IsShown(),'both combat hiding options keep the window hidden in combat')
D.uiSettings().hideInCombat=false; D.uiSettings().hideOutOfCombat=false; D.uiRefresh(nil)
check(D.window:IsShown(),'disabling combat hiding while in combat restores an eligible window')
pfUI={chat={right=CreateFrame('Frame',nil,UIParent)}}; CawDPSMeterCharDB.pfDockMain=true
pfUI.chat.right:Hide(); D.pfDockUpdate(); context('PLAYER_REGEN_ENABLED')
check(not D.window:IsShown(),'a combat transition does not reveal a chat-hidden docked meter')
D.uiSettings().hideInCombat=true; pfUI.chat.right:Show(); context('PLAYER_REGEN_DISABLED')
check(not D.window:IsShown(),'visible chat does not reveal an in-combat-hidden meter')
context('PLAYER_REGEN_ENABLED'); check(D.window:IsShown(),'ending combat restores an eligible docked meter')
D.pfDockToggle(nil); pfUI=nil
local oldCombat=UnitAffectingCombat
UnitAffectingCombat=function() return true end
context('PLAYER_ENTERING_WORLD'); check(not D.window:IsShown(),'reload while already in combat initializes the combat hiding rule')
UnitAffectingCombat=function() return false end
context('PLAYER_ENTERING_WORLD'); check(D.window:IsShown(),'reload out of combat uses the current player state')
UnitAffectingCombat=oldCombat
party=0; D.appearance=D.uiCopySettings({hideSolo=true}); v.appearance=D.uiCopySettings({hideSolo=true})
context(); D.uiRefresh(nil)
-- Existing settings copy/reset/search should include the new options.
D.openOptions(v); p.page='Window'; D.refreshOptions(); click(p.copyButton)
check(D.uiSettings().hideSolo and CawDPSMeterDB.appearance.hideSolo,'Copy to all windows includes visibility settings')
click(p.resetButton)
check(not v.appearance.hideSolo and v.frame:IsShown() and D.uiSettings().hideSolo,'Reset page restores visibility only for the selected window')
D.openOptions(nil)
check(p:IsShown(),'settings remain accessible through the command while the main meter is hidden')
click(D.mainView.closeButton); D.uiSettings().hideSolo=false; D.uiRefresh(nil)
check(not D.window:IsShown(),'X on an auto-hidden main meter remains a manual hide')
SlashCmdList.CAWDPS('show'); check(D.window:IsShown(),'explicit show reopens the main meter')
GetNumPartyMembers,GetNumRaidMembers,IsInInstance,GetBattlefieldStatus=oldParty,oldRaid,oldInstance,oldBattlefield
D.uiGroupContext=nil; clearWindows(); D.appearance=D.uiCopySettings(nil); D.uiRefresh(nil); p:Hide()
print('Window state checks: '..checks)

-- Optional docking. Keep UIParent; explicitly follow pfUI's arrow visibility.
local D=CAW_DPS_METER
function D.pfDockLayerTree(f,level,strata,docked,behindBag)
    docked=docked or f.cawDockedLayer
    if f.cawDropdown then
        -- A docked meter must sit below inventory windows such as Bagshui. Keep
        -- its menus on the same MEDIUM strata so opening a bag never covers the
        -- bag with a Caw dropdown. Free meters retain their foreground menu.
        if behindBag then strata="BACKGROUND"; level=0
        elseif docked then strata="MEDIUM"; level=30 else strata="DIALOG"; level=60 end
    end
    f:SetFrameStrata(strata); f:SetFrameLevel(level)
    if not f.GetChildren then return end
    local children={f:GetChildren()}; local i
    for i=1,table.getn(children) do
        local child=children[i]
        local layer=child:GetFrameStrata()
        -- Dropdown controls must follow their docked menu. Leaving the
        -- buttons on DIALOG would put them above Bagshui even though the
        -- menu frame itself is correctly below it.
        if behindBag or (docked and f.cawDropdown) or (layer~="DIALOG" and layer~="TOOLTIP") then layer=strata end
        D.pfDockLayerTree(child,level+2,layer,docked,behindBag)
    end
end

function D.pfDockRaise(f,rows)
    if f.cawInputLayersReady then return end
    D.pfDockLayerTree(f,20,"HIGH")
    -- Rows stay above the primary mouse-wheel catcher, which is a sibling.
    local i
    if rows then for i=1,table.getn(rows) do D.pfDockLayerTree(rows[i].frame,24,"HIGH") end end
    f.cawInputLayersReady=true
end
function D.pfDockDetach(f)
    local pos=f and f.cawDockFree
    f.cawDockedLayer=nil
    if not pos then D.pfDockLayerTree(f,20,"HIGH"); return end
    D.pfDockLayerTree(f,20,"HIGH")
    f:SetParent(UIParent); f:ClearAllPoints()
    if D.uiAnchorCenter then D.uiAnchorCenter(f,pos.x,pos.y) else f:SetPoint("CENTER",UIParent,"CENTER",pos.x,pos.y) end
    if pos.hiddenByDock then f:Show() end
    f.cawDockFree=nil
end

function D.pfDockToggle(v)
    D.pfDockMigrate()
    CawDPSMeterCharDB=CawDPSMeterCharDB or {}
    local active=v and v.pfDock or (not v and CawDPSMeterCharDB.pfDockMain)
    if not active and not (pfUI and pfUI.chat and pfUI.chat.right) then
        DEFAULT_CHAT_FRAME:AddMessage("Caw: Enable the pfUI right chat module to dock this window.")
        return
    end
    if v then v.pfDock=not active else CawDPSMeterCharDB.pfDockMain=not active end
    D.pfDockUpdate()
    if v then D.saveMultiWindows() end
end

function D.pfDockButton(button,v)
    if not button or button.cawDockHook then return end
    button.cawDockHook=true
    button:RegisterForClicks("LeftButtonUp","RightButtonUp")
    local click=button:GetScript("OnClick")
    button:SetScript("OnClick",function()
        if arg1=="RightButton" and IsShiftKeyDown and IsShiftKeyDown() then D.pfDockToggleVisibility()
        elseif arg1=="RightButton" then D.pfDockToggle(v)
        elseif click then click() end
    end)
    local enter=button:GetScript("OnEnter")
    button:SetScript("OnEnter",function()
        if enter then enter() end
        if D.getControlTooltip then
            local tt=D.getControlTooltip()
            tt:AddLine("Right-click: dock / undock at pfUI right chat",0.8,0.8,0.8)
            tt:AddLine("Shift-right-click: change visibility for all docked windows",0.8,0.8,0.8)
            local alternate=CawDPSMeterCharDB and CawDPSMeterCharDB.pfDockAlternate
            tt:AddLine(alternate and "Docked: alternate between chat and Caw" or "Docked: show / hide together with chat",1,0.82,0.35); tt:Show()
        end
    end)
end

function D.pfDockToggleVisibility()
    CawDPSMeterCharDB=CawDPSMeterCharDB or {}
    CawDPSMeterCharDB.pfDockAlternate=not CawDPSMeterCharDB.pfDockAlternate
    D.pfDockUpdate()
    DEFAULT_CHAT_FRAME:AddMessage(CawDPSMeterCharDB.pfDockAlternate
        and "Caw: Docked windows now appear when the pfUI right chat is hidden. Use the chat arrow to switch."
        or "Caw: Docked windows now show and hide together with the pfUI right chat.")
end

function D.pfDockPlace(f,enabled,target,previous)
    if not enabled or not target then D.pfDockDetach(f); return previous end
    if not f.cawDockedLayer then
        f.cawDockedLayer=true
        D.pfDockLayerTree(f,0,"MEDIUM",true)
    end
    if not f.cawDockFree then
        local x,y=f:GetCenter(); local ux,uy=UIParent:GetCenter()
        if D.uiCenterOffset then local dx,dy=D.uiCenterOffset(f); x=ux+dx; y=uy+dy end
        f.cawDockFree={x=(x or ux)-ux,y=(y or uy)-uy,
            strata=f:GetFrameStrata(),level=f:GetFrameLevel()}
        f:SetParent(UIParent)
    end
    local pos=f.cawDockFree
    -- pfUI's normal arrow hides the frame, while thirdparty.meters:Toggle()
    -- leaves it shown and switches its alpha between zero and one.
    local showDocked=target:IsVisible()
    if showDocked and target.GetAlpha and target:GetAlpha()==0 then showDocked=false end
    if CawDPSMeterCharDB and CawDPSMeterCharDB.pfDockAlternate then showDocked=not showDocked end
    if showDocked then
        if pos.hiddenByDock then pos.hiddenByDock=nil; f:Show() end
    elseif f:IsShown() then pos.hiddenByDock=true; f:Hide() end
    local inset=0; local panelAttached=false
    local panel=pfUI and pfUI.panel and pfUI.panel.right
    if panel and panel:GetParent()==target and panel:IsShown() then panelAttached=true end
    -- pfUI's panel can be anchored to the chat while parented to UIParent.
    if panel and panel:IsShown() and panel.GetPoint then
        local _,relative=panel:GetPoint(1)
        if relative==target then panelAttached=true end
    end
    if panelAttached then
        local ps=panel.GetEffectiveScale and panel:GetEffectiveScale() or 1
        local ts=target.GetEffectiveScale and target:GetEffectiveScale() or 1
        local fs=f.GetEffectiveScale and f:GetEffectiveScale() or 1
        local top,bottom=panel:GetTop(),target:GetBottom()
        if top and bottom and fs>0 then inset=math.max(0,(top*ps-bottom*ts)/fs) end
    end
    f:ClearAllPoints()
    if previous then
        -- A direct edge anchor avoids accumulating widths in different scales.
        f:SetPoint("BOTTOMRIGHT",previous,"BOTTOMLEFT",0,0)
    else
        -- pfUI draws its border outside this frame; its edge is the interior edge.
        f:SetPoint("BOTTOMRIGHT",target,"BOTTOMRIGHT",0,inset)
    end
    if f:IsShown() or pos.hiddenByDock then return f end
    return previous
end

function D.pfDockMigrate()
    if not D.savedVariablesReady or not CawDPSMeterCharDB or CawDPSMeterCharDB.pfDockRevision==2 then return end
    CawDPSMeterCharDB.pfDockRevision=2
    local restore=CawDPSMeterCharDB.pfDockMain
    CawDPSMeterCharDB.pfDockMain=false
    D.pfDockDetach(D.window)
    local i
    for i=2,D.multiWindowMax do
        local v=D.multiWindows[i]
        if v and not v.closed and v.pfDock then
            restore=true; v.pfDock=false; D.pfDockDetach(v.frame); v.frame:Show()
        end
    end
    if restore then
        D.window:Show(); D.saveMultiWindows()
        DEFAULT_CHAT_FRAME:AddMessage("Caw: Previous pfUI docking reset to restore window access. Right-click a lock icon to dock again.")
    end
end

function D.pfDockUpdate()
    if not D.savedVariablesReady or not D.window or not D.multiWindowsRestored then return end
    D.pfDockMigrate()
    local target=pfUI and pfUI.chat and pfUI.chat.right
    local offset=nil
    D.pfDockButton(D.mainLockButton,nil)
    D.pfDockRaise(D.window,D.rows)
    offset=D.pfDockPlace(D.window,CawDPSMeterCharDB and CawDPSMeterCharDB.pfDockMain,target,offset)
    local i
    for i=2,D.multiWindowMax do
        local v=D.multiWindows[i]
        if v and not v.closed then
            D.pfDockButton(v.lockButton,v)
            D.pfDockRaise(v.frame,v.rows)
            offset=D.pfDockPlace(v.frame,v.pfDock,target,offset)
        end
    end
end

-- Bagshui's inventory frames are regular MEDIUM-strata windows. A free Caw
-- frame normally uses HIGH so it stays interactive over the game world, which
-- would put it in front of an open bag. Track the three inventory windows that
-- can cover the meter and temporarily move all Caw children to BACKGROUND.
D.bagshuiWindowVisible=function()
    if type(Bagshui)~="table" or type(Bagshui.components)~="table" then return false end
    local names={"Bags","Bank","Keyring"}; local i
    for i=1,table.getn(names) do
        local component=Bagshui.components[names[i]]
        local f=component and component.uiFrame
        if f then
            local visible=false
            if f.IsVisible then visible=f:IsVisible()
            elseif f.IsShown then visible=f:IsShown() end
            if visible then return true end
        end
    end
    return false
end

D.pfBagLayerTick=function()
    local behind=D.bagshuiWindowVisible and D.bagshuiWindowVisible() or false
    local i,v,f,state,dockedState,expectedStrata
    local views={D.mainView}
    for i=2,D.multiWindowMax do
        v=D.multiWindows[i]
        if v and not v.closed then table.insert(views,v) end
    end
    for i=1,table.getn(views) do
        v=views[i]; f=v.id==1 and D.window or v.frame
        if f then
            state=behind and true or false
            dockedState=f.cawDockedLayer and true or false
            expectedStrata=dockedState and "MEDIUM" or (behind and "BACKGROUND" or "HIGH")
            if f.cawBagLayerState~=state or f.cawBagLayerDockedState~=dockedState
                or (f.GetFrameStrata and f:GetFrameStrata()~=expectedStrata) then
                f.cawBagLayerState=state
                f.cawBagLayerDockedState=dockedState
                if behind and not dockedState then D.pfDockLayerTree(f,0,"BACKGROUND",false,true)
                elseif not behind and not dockedState then D.pfDockLayerTree(f,20,"HIGH")
                elseif dockedState then D.pfDockLayerTree(f,0,"MEDIUM",true) end
            end
        end
    end
end

D.pfDockFrame=CreateFrame("Frame",nil,UIParent)
D.pfDockFrame:SetScript("OnUpdate",function()
    if GetTime()<(D.pfDockNext or 0) then return end
    D.pfDockNext=GetTime()+0.25
    D.pfDockUpdate()
    if D.pfBagLayerTick then D.pfBagLayerTick() end
end)

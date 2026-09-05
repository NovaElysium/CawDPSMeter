-- Optional docking. Keep UIParent; explicitly follow pfUI's arrow visibility.
local D=CAW_DPS_METER
function D.pfDockLayerTree(f,level,strata)
    if f.cawDropdown then strata="DIALOG"; level=60 end
    f:SetFrameStrata(strata); f:SetFrameLevel(level)
    if not f.GetChildren then return end
    local children={f:GetChildren()}; local i
    for i=1,table.getn(children) do
        local child=children[i]
        local layer=child:GetFrameStrata()
        if layer~="DIALOG" and layer~="TOOLTIP" then layer=strata end
        D.pfDockLayerTree(child,level+2,layer)
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
    if not pos then return end
    f:SetParent(UIParent); f:ClearAllPoints()
    f:SetPoint("CENTER",UIParent,"CENTER",pos.x,pos.y)
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
        if arg1=="RightButton" then D.pfDockToggle(v)
        elseif click then click() end
    end)
    local enter=button:GetScript("OnEnter")
    button:SetScript("OnEnter",function()
        if enter then enter() end
        if D.getControlTooltip then
            local tt=D.getControlTooltip()
            tt:AddLine("Right-click: dock / undock at pfUI right chat",0.8,0.8,0.8); tt:Show()
        end
    end)
end

function D.pfDockPlace(f,enabled,target,previous)
    if not enabled or not target then D.pfDockDetach(f); return previous end
    if not f.cawDockFree then
        local x,y=f:GetCenter(); local ux,uy=UIParent:GetCenter()
        f.cawDockFree={x=(x or ux)-ux,y=(y or uy)-uy,
            strata=f:GetFrameStrata(),level=f:GetFrameLevel()}
        f:SetParent(UIParent)
    end
    local pos=f.cawDockFree
    if target:IsVisible() then
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

D.pfDockFrame=CreateFrame("Frame",nil,UIParent)
D.pfDockFrame:SetScript("OnUpdate",function()
    if GetTime()<(D.pfDockNext or 0) then return end
    D.pfDockNext=GetTime()+0.25
    D.pfDockUpdate()
end)

-- Shared appearance and native Vanilla configuration panels. No combat producer.
local D=CAW_DPS_METER
local TEX="Interface\\Buttons\\WHITE8X8"
local FONT="Fonts\\ARIALN.TTF"
D.uiFont=FONT
D.uiAccent={0.72,0.64,0.43}
D.uiDefaults={scale=1,rowHeight=23,rowGap=3,fontSize=11,opacity=0.94,barOpacity=0.85,
    watermark=0.40,icons=true,ranks=true,classNames=false,rate=true,percent=false,
    autoCurrent=false,hover=true}
local ranges={scale={0.6,1.6},rowHeight={14,36},rowGap={0,10},fontSize={8,16},
    opacity={0,1},barOpacity={0.1,1},watermark={0,0.8}}

function D.uiCopySettings(src)
    local out={}; local k,default
    for k,default in pairs(D.uiDefaults) do
        local value=src and src[k]
        if type(default)=="boolean" then
            if type(value)~="boolean" then value=default end
        else
            value=tonumber(value)
            if not value or value~=value then value=default end
            value=math.max(ranges[k][1],math.min(ranges[k][2],value))
        end
        out[k]=value
    end
    return out
end
function D.uiSettings(v)
    if v and v.id~=1 then
        if not v.appearance then v.appearance=D.uiCopySettings(nil) end
        return v.appearance
    end
    if not D.appearance then D.appearance=D.uiCopySettings(CawDPSMeterDB and CawDPSMeterDB.appearance) end
    return D.appearance
end
function D.uiHeightForRows(v,n)
    local s=D.uiSettings(v)
    return 29+n*s.rowHeight+math.max(0,n-1)*s.rowGap+22
end
function D.uiCenterOffset(f)
    local x,y=f:GetCenter(); local ux,uy=UIParent:GetCenter()
    local fs=f.GetEffectiveScale and f:GetEffectiveScale() or 1
    local us=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    return (x or 0)*fs/us-(ux or 0),(y or 0)*fs/us-(uy or 0)
end
function D.uiAnchorCenter(f,x,y)
    local fs=f.GetEffectiveScale and f:GetEffectiveScale() or 1
    local us=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"CENTER",x*us/fs,y*us/fs)
end
function D.uiClamp(f)
    local fs=f.GetEffectiveScale and f:GetEffectiveScale() or 1
    local us=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local l,r,b,t=f:GetLeft(),f:GetRight(),f:GetBottom(),f:GetTop()
    local pl,pr,pb,pt=UIParent:GetLeft(),UIParent:GetRight(),UIParent:GetBottom(),UIParent:GetTop()
    if not l or not r or not b or not t or not pl or not pr or not pb or not pt then return false end
    l=l*fs/us; r=r*fs/us; b=b*fs/us; t=t*fs/us
    local dx,dy=0,0
    if l<pl-8 then dx=pl-8-l elseif r>pr+8 then dx=pr+8-r end
    if b<pb-8 then dy=pb-8-b elseif t>pt+8 then dy=pt+8-t end
    if dx~=0 or dy~=0 then local x,y=D.uiCenterOffset(f); D.uiAnchorCenter(f,x+dx,y+dy); return true end
    return false
end
function D.uiVisibleRows(v,f)
    local s=D.uiSettings(v)
    return math.max(1,math.min(20,math.floor((f:GetHeight()-51+s.rowGap)/(s.rowHeight+s.rowGap))))
end
function D.uiPanel(f,alpha)
    f:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1,insets={left=1,right=1,top=1,bottom=1}})
    f:SetBackdropColor(0.10,0.105,0.12,alpha or 0.98)
    f:SetBackdropBorderColor(0.23,0.24,0.27,1)
end
function D.uiText(parent,text,x,y,w,size)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    t:SetFont(FONT,size or 11); t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    t:SetWidth(w); t:SetHeight((size or 11)+5); t:SetJustifyH("LEFT")
    t:SetTextColor(0.88,0.88,0.89); t:SetText(text or "")
    return t
end
function D.uiButton(parent,label,x,y,w,fn)
    local b=CreateFrame("Button",nil,parent); b:SetWidth(w); b:SetHeight(24)
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); D.uiPanel(b)
    b.text=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    b.text:SetPoint("CENTER",b,"CENTER",0,0); b.text:SetWidth(w-8); b.text:SetHeight(16)
    b.text:SetFont(FONT,12); b.text:SetText(label); b.text:SetTextColor(0.9,0.9,0.91)
    b:SetScript("OnClick",fn)
    b:SetScript("OnEnter",function() if not this.selected then this:SetBackdropColor(0.23,0.23,0.25,1) end end)
    b:SetScript("OnLeave",function() D.uiSelectButton(this,this.selected) end)
    return b
end
function D.uiBlock(parent,x,y,w,h,r,g,b,a,layer)
    local t=parent:CreateTexture(nil,layer or "BACKGROUND"); t:SetTexture(TEX)
    t:SetWidth(w); t:SetHeight(h); t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    t:SetVertexColor(r,g,b,a or 1); return t
end
function D.uiSelectButton(b,selected)
    b.selected=selected and true or false
    if selected then b:SetBackdropColor(0.28,0.26,0.21,1); b:SetBackdropBorderColor(0.47,0.42,0.30,1)
    else b:SetBackdropColor(0.14,0.145,0.16,1); b:SetBackdropBorderColor(0.23,0.24,0.27,1) end
end
function D.uiSection(parent,label,x,y,w)
    local t=D.uiText(parent,label,x,y,w,13); t:SetTextColor(0.78,0.71,0.54)
    D.uiBlock(parent,x,y-24,w,1,0.26,0.265,0.29)
    return t
end
function D.uiTooltip(f,text)
    f:SetScript("OnEnter",function()
        local tt=D.getControlTooltip(); tt:SetOwner(this,"ANCHOR_RIGHT"); tt:SetText(text,0.9,0.9,0.9); tt:Show()
    end)
    f:SetScript("OnLeave",function() if D.controlTooltip then D.controlTooltip:Hide() end end)
end
function D.uiInput(parent,x,y,w,commit)
    local e=CreateFrame("EditBox",nil,parent); e:SetWidth(w); e:SetHeight(24)
    e:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); D.uiPanel(e)
    e:SetBackdropColor(0.075,0.08,0.09,1); e:SetFont(FONT,12); e:SetAutoFocus(false)
    e:SetTextInsets(7,7,0,0)
    e:SetScript("OnEscapePressed",function() this:ClearFocus() end)
    if commit then
        e:SetScript("OnEnterPressed",function() commit(this:GetText()); this:ClearFocus() end)
        e:SetScript("OnEditFocusLost",function() commit(this:GetText()) end)
    end
    return e
end
function D.uiListButton(parent,x,y,w,fn)
    local b=D.uiButton(parent,"",x,y,w,fn)
    b.text:ClearAllPoints(); b.text:SetPoint("LEFT",b,"LEFT",8,0)
    b.text:SetWidth(w-16); b.text:SetJustifyH("LEFT")
    return b
end
function D.uiDialog(name,title,w,h)
    local f=CreateFrame("Frame",name,UIParent); f:SetWidth(w); f:SetHeight(h)
    f:SetPoint("CENTER",UIParent,"CENTER",0,0); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(80)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton"); D.uiPanel(f)
    f:SetScript("OnDragStart",function() this:StartMoving() end)
    f:SetScript("OnDragStop",function() this:StopMovingOrSizing(); D.clampMultiWindow(this) end)
    D.uiBlock(f,1,-1,w-2,38,0.15,0.15,0.17)
    D.uiBlock(f,1,-39,w-2,1,0.36,0.32,0.24)
    local icon=f:CreateTexture(nil,"ARTWORK"); icon:SetTexture("Interface\\AddOns\\CawDPSMeter\\Media\\CawClaw.tga")
    icon:SetWidth(28); icon:SetHeight(28); icon:SetPoint("TOPLEFT",f,"TOPLEFT",11,-6)
    f.title=D.uiText(f,title,47,-11,w-100,16)
    local close=D.uiButton(f,"",w-34,-8,24,function() f:Hide() end)
    close.icon=close:CreateTexture(nil,"OVERLAY"); close.icon:SetTexture("Interface\\AddOns\\CawDPSMeter\\Media\\CawClose.tga")
    close.icon:SetWidth(14); close.icon:SetHeight(14); close.icon:SetPoint("CENTER",close,"CENTER",0,0)
    if UISpecialFrames then table.insert(UISpecialFrames,name) end
    -- Fit smaller displays without using native frame clamping on this client.
    local sw=UIParent:GetWidth(); local sh=UIParent:GetHeight()
    f:SetScale(math.min(1,math.max(0.5,(sw-30)/w),math.max(0.5,(sh-30)/h)))
    return f
end
local function whisperTarget()
    if UnitIsPlayer and UnitIsPlayer("target") then return D.reportRecipient(UnitName("target")) end
end
function D.openWhisperReport(v)
    if v and v.id==1 then v=nil end
    D.uiCloseMeterMenus(v or D.mainView)
    local lines,err=D.buildReportLines(v)
    if not lines then DEFAULT_CHAT_FRAME:AddMessage("Caw: "..err); return end
    local f=D.whisperDialog
    if not f then
        f=D.uiDialog("CawWhisperDialog","Whisper report",430,236); D.whisperDialog=f
        f.summary=D.uiText(f,"",18,-52,394,12); f.summary:SetHeight(35)
        D.uiText(f,"Character name",18,-96,280,12)
        f.recipient=D.uiInput(f,18,-117,276); f.recipient:SetMaxLetters(64)
        f.targetButton=D.uiButton(f,"Use target",304,-117,108,function()
            local name=whisperTarget()
            if name then f.recipient:SetText(name); f.error:SetText("")
            else f.error:SetText("Target a player first.") end
        end)
        f.error=D.uiText(f,"",18,-151,394,12); f.error:SetHeight(32); f.error:SetTextColor(1,0.5,0.42)
        local function send()
            local name=D.reportRecipient(f.recipient:GetText())
            if not name then f.error:SetText("Enter a character name."); return end
            local ok,message=D.sendReportLines(f.reportLines,"WHISPER",name)
            if ok then f:Hide() else f.error:SetText(message or "Report could not be sent.") end
        end
        f.sendButton=D.uiButton(f,"Send",304,-194,108,send)
        f.cancelButton=D.uiButton(f,"Cancel",186,-194,108,function() f:Hide() end)
        f.recipient:SetScript("OnEnterPressed",send)
        f.recipient:SetScript("OnEscapePressed",function() f:Hide() end)
        f:SetScript("OnHide",function() f.recipient:ClearFocus(); f.reportLines=nil end)
    end
    -- Snapshot both the report and initial recipient; changing targets or views
    -- while typing must not redirect an already-open report.
    f.reportLines=lines; f.summary:SetText(string.gsub(lines[1],"^Caw DPS Meter: ",""))
    f.recipient:SetText(whisperTarget() or ""); f.error:SetText(""); f:Show(); f.recipient:SetFocus()
end
function D.uiEnableButton(b,enabled)
    b.cawDisabled=not enabled
    if enabled then b:Enable(); b:SetAlpha(1) else b:Disable(); b:SetAlpha(0.3) end
end
local function meterButtonSelected(b)
    local v=b.cawThemeView
    if not v then return false end
    local current=v.id==1 and D or v
    if b.cawThemeRole=="lock" then return current.locked end
    if b.cawThemeRole=="mode" then return b.mode and b.mode==current.mode end
    if b.cawThemeRole=="segment" then
        return b.kind and b.kind==current.segment and (b.kind~="history" or b.historyIndex==current.segmentIndex)
    end
    return false
end
function D.uiPaintMeterButton(b)
    b.selected=meterButtonSelected(b) and true or false
    local item=b.cawThemeRole=="mode" or b.cawThemeRole=="segment" or b.cawThemeRole=="report"
    if b.selected then
        b:SetBackdropColor(0.14,0.125,0.085,1); b:SetBackdropBorderColor(0.35,0.30,0.20,1)
    else
        if b.cawMeterHover then b:SetBackdropColor(0.095,0.10,0.11,1)
        else b:SetBackdropColor(0.04,0.044,0.05,1) end
        b:SetBackdropBorderColor(0.15,0.16,0.18,item and 0 or 1)
    end
    if b.hi then b.hi:Hide() end
    if b.bg then b.bg:Hide() end
    local text=b.text or b.cawThemeText
    if text then
        if b.selected then text:SetTextColor(1,0.9,0.66) else text:SetTextColor(0.96,0.96,0.97) end
    end
end
function D.uiThemeMeterButton(b,v,role)
    if not b then return end
    b.cawThemeView=v; b.cawThemeRole=role
    if not b.cawMeterThemeHook then
        b.cawMeterThemeHook=true; D.uiPanel(b)
        b.cawMeterOnEnter=b:GetScript("OnEnter"); b.cawMeterOnLeave=b:GetScript("OnLeave")
        b:SetScript("OnEnter",function()
            local button=this; button.cawMeterHover=true
            if button.cawMeterOnEnter then button.cawMeterOnEnter() end
            D.uiPaintMeterButton(button)
            if button.cawMenuClipped and button.cawMenuLabel then
                local tt=D.getControlTooltip(); tt:SetOwner(button,"ANCHOR_RIGHT"); tt:SetText(button.cawMenuLabel,1,1,1); tt:Show()
            end
        end)
        b:SetScript("OnLeave",function()
            local button=this; button.cawMeterHover=false
            if button.cawMeterOnLeave then button.cawMeterOnLeave() end
            D.uiPaintMeterButton(button)
            if button.cawMenuClipped and D.controlTooltip then D.controlTooltip:Hide() end
        end)
    end
    D.uiPaintMeterButton(b)
end
function D.uiCloseMeterMenus(v,except)
    if not v then return end
    for _,key in ipairs({"modeMenu","segmentMenu","reportMenu","overflowMenu"}) do
        local menu=v[key]
        if menu and menu~=except then menu:Hide() end
    end
end
function D.uiEnsureOverflowButton(v)
    if v.overflowButton then return v.overflowButton end
    local b=D.uiButton(v.frame,"",0,0,17,function()
        local menu=this.cawOverflowView.overflowMenu
        if menu:IsShown() then menu:Hide() else menu:Show() end
    end)
    v.overflowButton=b; b.cawOverflowView=v
    -- A text ellipsis can wrap inside this 17px button on the native client.
    -- Draw the three dots as a centered glyph, independent of font metrics.
    b.text:Hide()
    for i=1,3 do
        local dot=D.uiBlock(b,0,0,2,2,0.90,0.90,0.92,1,"OVERLAY")
        dot:ClearAllPoints(); dot:SetPoint("CENTER",b,"CENTER",(i-2)*4,0)
    end
    D.uiTooltip(b,"Window actions")
    local menu=CreateFrame("Frame",nil,v.frame); v.overflowMenu=menu
    menu:SetWidth(124); menu:SetHeight(140); menu:SetPoint("TOPRIGHT",b,"BOTTOMRIGHT",0,-2)
    menu.cawDropdown=true; menu:SetFrameStrata("DIALOG"); menu:SetFrameLevel(60); menu:EnableMouse(true)
    menu.buttons={}; menu.cawOverflowView=v
    for i,entry in ipairs({{"options","Settings"},{"add","New window"},{"report","Report"},{"reset","Reset"},{"lock","Lock"},{"close","Close"}}) do
        local item=D.uiListButton(menu,4,-4-(i-1)*22,116,function()
            local item=this; local view=item.cawOverflowView
            D.uiCloseMeterMenus(view)
            local target=view[item.action.."Button"]; local fn=target and target:GetScript("OnClick")
            if fn then local previous=this; this=target; fn(); this=previous end
        end)
        item:SetHeight(21); item.text:SetText(entry[2]); item.action=entry[1]; item.cawOverflowView=v
        menu.buttons[i]=item
    end
    menu:SetScript("OnShow",function()
        local view=this.cawOverflowView; local locked=view.id==1 and D.locked or view.locked
        for _,item in ipairs(this.buttons) do
            if item.action=="lock" then item.text:SetText(locked and "Unlock" or "Lock") end
            if item.action=="add" then
                local free=false; for i=2,D.multiWindowMax do if not D.multiWindows[i] then free=true; break end end
                D.uiEnableButton(item,free)
            end
        end
    end)
    D.uiStyleMeterMenu(v,menu,"action"); menu:Hide()
    return b
end
local menuLabels={damage="Damage / DPS",healing="Healing / HPS",threat="Threat",damageTaken="Damage Taken",
    deaths="Deaths",interrupts="Interrupts",cc="Crowd Control",ccBreaks="CC Breaks",dispels="Dispels",
    buffs="Buff Uptime",debuffsCast="Debuffs Cast",debuffsReceived="Debuffs Received"}
local menuShort={damage="DPS",healing="HPS",damageTaken="Taken",interrupts="Interrupts",cc="CC",ccBreaks="CC Breaks",
    buffs="Buffs",debuffsCast="Cast",debuffsReceived="Received"}
function D.uiStyleMeterMenu(v,menu,kind)
    if not menu then return end
    menu.cawThemeView=v; menu.cawThemeRole=kind
    if not menu.cawMenuThemeHook then
        menu.cawMenuThemeHook=true; D.uiPanel(menu)
        menu.cawMeterOnShow=menu:GetScript("OnShow")
        menu:SetScript("OnShow",function()
            local popup=this
            D.uiCloseMeterMenus(popup.cawThemeView,popup)
            if popup.cawMeterOnShow then popup.cawMeterOnShow() end
            D.uiStyleMeterMenu(popup.cawThemeView,popup,popup.cawThemeRole)
        end)
    end
    menu:SetBackdropColor(0.025,0.027,0.032,0.99); menu:SetBackdropBorderColor(0.15,0.16,0.18,1)
    for _,b in ipairs(menu.buttons or {}) do
        D.uiThemeMeterButton(b,v,kind)
        if b.text then
            b.text:SetFont(FONT,12); b.text:SetHeight(16)
            b.text:SetShadowColor(0,0,0,1); b.text:SetShadowOffset(1,-1)
            if kind=="report" then b.text:SetWidth(b:GetWidth()-12) end
            local label=kind=="mode" and menuLabels[b.mode] or b.text:GetText()
            if label then
                b.text:SetText(label); b.cawMenuLabel=label
                b.cawMenuClipped=b.text:GetStringWidth()>b.text:GetWidth()
                if kind=="mode" and b.cawMenuClipped then
                    local short=menuShort[b.mode] or label
                    b.text:SetText(short)
                    while string.len(short)>1 and b.text:GetStringWidth()>b.text:GetWidth() do
                        short=string.sub(short,1,-2); b.text:SetText(short.."...")
                    end
                end
            end
        end
    end
    D.uiThemeMeterButton(menu.up,v); D.uiThemeMeterButton(menu.down,v)
end
function D.uiStopMeterDrag(handle)
    if not handle or not handle.cawDragging then return end
    local v=handle.cawDragView; local f=v.frame
    handle.cawDragging=nil; f.cawDragHandle=nil; f:StopMovingOrSizing()
    if not f.cawDockFree and not v.closed then
        D.uiClamp(f)
        if v.id==1 then D.uiSaveMain() else D.saveMultiWindows() end
    end
end
function D.uiAttachMeterDrag(handle,v,shift)
    if not handle then return end
    handle.cawDragView=v; handle.cawDragShift=shift
    if handle.cawDragHook then return end
    handle.cawDragHook=true; handle:RegisterForDrag("LeftButton")
    handle.cawDragMouseDown=handle:GetScript("OnMouseDown")
    handle.cawDragMouseUp=handle:GetScript("OnMouseUp")
    handle:SetScript("OnMouseDown",function()
        this.cawSkipClick=nil
        if this.cawDragMouseDown then this.cawDragMouseDown() end
    end)
    handle:SetScript("OnDragStart",function()
        local h=this; local view=h.cawDragView; local f=view.frame
        local locked=view.id==1 and D.locked or view.locked
        if locked or view.closed or f.cawDockFree then return end
        if h.cawDragShift and (not IsShiftKeyDown or not IsShiftKeyDown()) then return end
        D.uiCloseMeterMenus(view)
        if D.controlTooltip then D.controlTooltip:Hide() end
        h.cawDragging=true; h.cawSkipClick=true; f.cawDragHandle=h; f:StartMoving()
    end)
    handle:SetScript("OnDragStop",function() D.uiStopMeterDrag(this) end)
    handle:SetScript("OnMouseUp",function()
        local h=this; D.uiStopMeterDrag(h)
        if h.cawSkipClick then h.cawSkipClick=nil; return end
        if h.cawDragMouseUp then h.cawDragMouseUp() end
    end)
end
function D.uiFooterRegion(v,role,left,width)
    v.footerRegions=v.footerRegions or {}
    local h=v.footerRegions[role]
    if not h then
        h=CreateFrame("Frame",nil,v.footerHandle); v.footerRegions[role]=h
        h.cawFooterRole=role; h:SetHeight(18); h:EnableMouse(true)
        h:SetScript("OnEnter",function()
            local view=this.cawDragView
            if view.frame.cawDragHandle then return end
            local tt=D.getControlTooltip(); tt:SetOwner(this,"ANCHOR_TOP")
            if this.cawFooterRole=="summary" then
                tt:SetText(view.footerText or "Caw",1,1,1)
            elseif D.localSyncFooterTooltip then
                D.localSyncFooterTooltip(view,tt,this.cawFooterRole)
            end
            local locked=view.id==1 and D.locked or view.locked
            tt:AddLine(view.frame.cawDockFree and "Undock this window to move it." or (locked and "Unlock this window to move it." or "Drag to move. Shift-drag also works on player bars."),0.8,0.8,0.8)
            tt:Show()
        end)
        h:SetScript("OnLeave",function() if D.controlTooltip then D.controlTooltip:Hide() end end)
        D.uiAttachMeterDrag(h,v,false)
    end
    h:ClearAllPoints(); h:SetPoint("BOTTOMLEFT",v.frame,"BOTTOMLEFT",left,1)
    h:SetWidth(math.max(1,width)); h:SetFrameLevel(v.footerHandle:GetFrameLevel()+1)
    return h
end
function D.uiFooterNumber(n)
    if n<1000 then return tostring(n) end
    local divisor,suffix=1000,"k"
    if n>=999995 then divisor=1000000; suffix="M" end
    local text=string.format("%.2f",n/divisor)
    text=string.gsub(string.gsub(text,"0+$",""),"%.$","")
    return text..suffix
end
function D.uiFitMeterSummary(v,preferRate)
    local text=v.summary; local label=v.footerText or text:GetText() or ""
    local current=v.id==1 and D or v
    -- Preserve names and numbers in Threat target labels verbatim.
    if current.mode~="threat" then
        label=string.gsub(label,"[%d,]+%.?%d*",function(number)
            local n=tonumber((string.gsub(number,",","")))
            if n and n>=1000 then return D.uiFooterNumber(n) end
            return number
        end)
    end
    local function fits(value)
        text:SetText(value)
        return not text.GetStringWidth or text:GetStringWidth()<=text:GetWidth()
    end
    if not preferRate and fits(label) then return end
    local _,_,rate=string.find(label,"| (.+)$")
    if not preferRate and fits((string.gsub(label,"^Total: ",""))) then return end
    label=rate or string.gsub(label,"^Total: ","")
    if fits(label) then return end
    if rate then
        -- Drop fractional precision before the unit, then retain the value alone.
        local rounded=string.gsub(label,"%d+%.%d+",function(n) return string.format("%.0f",tonumber(n)) end)
        if fits(rounded) then return end
        label=string.gsub(label," [DH]PS$","")
        if fits(label) then return end
        label=string.gsub(label,"%d+%.%d+",function(n) return string.format("%.0f",tonumber(n)) end)
        if fits(label) then return end
    end
    while string.len(label)>0 do
        label=string.sub(label,1,-2)
        if fits(label.."...") then return end
    end
    if not fits("...") then text:SetText("") end
end
function D.uiLayoutMeterFooter(v)
    if not v or not v.footerHandle then return end
    local w=v.frame:GetWidth()
    v.footerHandle:SetWidth(math.max(1,w-28))
    v.summary:ClearAllPoints(); v.summary:SetPoint("BOTTOMRIGHT",v.frame,"BOTTOMRIGHT",-27,3)
    v.summary:SetWidth(math.max(1,w-33)); v.summary:SetJustifyH("RIGHT")
    v.summary:SetText(v.footerText or v.summary:GetText() or "")
    D.uiFooterRegion(v,"summary",3,w-28)
    local private=D.localSyncFooterLayout and D.localSyncFooterLayout(v)
    D.uiFitMeterSummary(v,private and w<300)
end
function D.uiUpdateMeterFooter(v)
    if not v then return end
    v.footerText=v.summary:GetText() or ""
    local current=v.id==1 and D or v
    v.modeButton.cawMenuLabel=menuLabels[current.mode]; v.modeButton.cawMenuClipped=true
    v.segmentButton.cawMenuLabel=v.id==1 and D.reportSegmentName() or D.multiReportSegmentName(v)
    v.segmentButton.cawMenuClipped=true
    D.uiLayoutMeterFooter(v)
end
function D.uiStyleMeterShell(v,s)
    local f=v.frame
    if not f.cawMeterShell then
        f.cawMeterShell=true; D.uiPanel(f,s.opacity)
        v.footer=D.uiBlock(f,0,0,1,17,0.018,0.020,0.024)
        v.footer:ClearAllPoints(); v.footer:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",1,1)
        v.footerLine=D.uiBlock(f,0,0,1,1,0.13,0.14,0.16)
        v.footerLine:ClearAllPoints(); v.footerLine:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",1,19)
        v.footerHandle=CreateFrame("Frame",nil,f); v.footerHandle:SetHeight(18)
        v.footerHandle:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",3,1); v.footerHandle:EnableMouse(true)
        D.uiAttachMeterDrag(v.footerHandle,v,false)
        f.cawThemeView=v; f.cawMeterOnHide=f:GetScript("OnHide")
        f:SetScript("OnHide",function()
            local window=this; D.uiCloseMeterMenus(window.cawThemeView)
            D.uiStopMeterDrag(window.cawDragHandle)
            if window.cawMeterOnHide then window.cawMeterOnHide() end
        end)
    end
    f:SetBackdropColor(0.025,0.027,0.032,s.opacity); f:SetBackdropBorderColor(0.15,0.16,0.18,1)
    v.header:SetVertexColor(0.045,0.048,0.055,1); v.headerLine:SetVertexColor(0.20,0.18,0.13,1)
    v.footer:SetWidth(f:GetWidth()-2); v.footer:SetAlpha(s.opacity)
    v.footerLine:SetWidth(f:GetWidth()-2); v.summary:SetTextColor(0.74,0.75,0.77)
    v.footerHandle:SetFrameLevel(f:GetFrameLevel()+6)
    D.uiLayoutMeterFooter(v)
    if v.id==1 then D.uiAttachMeterDrag(D.mainWheelArea,v,false) end
    v.modeButton.cawThemeText=v.modeText; v.segmentButton.cawThemeText=v.segmentText
    for _,key in ipairs({"closeButton","resetButton","reportButton","addButton","optionsButton","modeButton","segmentButton","overflowButton"}) do
        D.uiThemeMeterButton(v[key],v)
    end
    D.uiThemeMeterButton(v.lockButton,v,"lock")
    D.uiStyleMeterMenu(v,v.modeMenu,"mode"); D.uiStyleMeterMenu(v,v.segmentMenu,"segment")
    D.uiStyleMeterMenu(v,v.reportMenu,"report")
    local sc=v.id==1 and D.mainScroll or v
    if sc then
        if sc.scrollBackground then sc.scrollBackground:SetVertexColor(0.045,0.048,0.055,1) end
        if sc.scrollThumb then sc.scrollThumb:SetVertexColor(0.32,0.30,0.25,1) end
        D.uiThemeMeterButton(sc.scrollUp,v); D.uiThemeMeterButton(sc.scrollDown,v)
    end
end
function D.uiStyleView(v)
    local s=D.uiSettings(v); local f=v.frame
    local minimum=D.uiHeightForRows(v,1)
    if f:GetHeight()<minimum then f:SetHeight(minimum) end
    if f.SetMinResize then pcall(f.SetMinResize,f,160,minimum) end
    if (f.GetScale and f:GetScale() or 1)~=s.scale then
        local x,y=D.uiCenterOffset(f); f:SetScale(s.scale)
        if not f.cawDockFree then D.uiAnchorCenter(f,x,y) end
    end
    D.uiStyleMeterShell(v,s)
    local rows=v.id==1 and D.rows or v.rows
    local i,row
    for i,row in ipairs(rows or {}) do
        row.view=v.id~=1 and v or nil
        row.frame:SetHeight(s.rowHeight); row.frame:ClearAllPoints()
        local y=-29-(i-1)*(s.rowHeight+s.rowGap)
        row.frame:SetPoint("TOPLEFT",f,"TOPLEFT",6,y)
        row.frame:SetPoint("TOPRIGHT",f,"TOPRIGHT",-20,y)
        local fontSize=math.min(s.fontSize,s.rowHeight-4)
        row.left:SetFont(FONT,fontSize); row.right:SetFont(FONT,fontSize); row.rank:SetFont(FONT,fontSize)
        row.left:SetHeight(s.rowHeight-2); row.right:SetHeight(s.rowHeight-2); row.rank:SetHeight(s.rowHeight-2)
        row.left:SetShadowColor(0,0,0,1); row.left:SetShadowOffset(1,-1)
        row.right:SetShadowColor(0,0,0,1); row.right:SetShadowOffset(1,-1)
        row.rank:SetShadowColor(0,0,0,1); row.rank:SetShadowOffset(1,-1)
        local icon=math.min(18,s.rowHeight-4); row.classIcon:SetWidth(icon); row.classIcon:SetHeight(icon)
        if not row.cawRowTheme then
            row.cawRowTheme=true; D.uiPanel(row.frame,1)
            row.frame:SetBackdropColor(0.04,0.044,0.05,1); row.frame:SetBackdropBorderColor(0.12,0.13,0.15,1)
            if row.background then row.background:SetVertexColor(0.04,0.044,0.05,1) end
            if row.shade then row.shade:Hide() end
            if row.hover then row.hover:Hide() end
        end
        if not row.cawDetailsHook then
            row.cawDetailsHook=true
            -- Vanilla's Lua 5.0 loop variable is shared by these callbacks.
            -- Keep the row on the bar so reused rows always open their current actor.
            row.bar.cawViewRow=row
            row.bar.cawOriginalEnter=row.bar:GetScript("OnEnter")
            row.bar.cawOriginalLeave=row.bar:GetScript("OnLeave")
            row.bar:SetScript("OnMouseUp",function()
                local r=this and this.cawViewRow
                if not r then return end
                if arg1=="RightButton" then D.openOptions(r.view)
                elseif arg1=="LeftButton" and r.actor and D.openBreakdown then D.openBreakdown(r.actor,r.view) end
            end)
            row.bar:SetScript("OnEnter",function()
                local r=this and this.cawViewRow
                if r then r.frame:SetBackdropBorderColor(0.35,0.30,0.20,1) end
                if r and D.uiSettings(r.view).hover and this.cawOriginalEnter then this.cawOriginalEnter() end
            end)
            row.bar:SetScript("OnLeave",function()
                local r=this and this.cawViewRow
                if r then r.frame:SetBackdropBorderColor(0.12,0.13,0.15,1) end
                if this and this.cawOriginalLeave then this.cawOriginalLeave() end
            end)
        end
        D.uiAttachMeterDrag(row.bar,v,true)
    end
    if v.brand then v.brand:SetAlpha(s.watermark) end
end
local barColours={}
local function linearColour(c)
    if c<=0.04045 then return c/12.92 end
    return ((c+0.055)/1.055)^2.4
end
function D.uiBarColour(r,g,b)
    local key=r..":"..g..":"..b; local colour=barColours[key]
    if not colour then
        -- Keep the class hue, but darken large fills for readable light text.
        -- The luminance limit also covers white Priest and yellow Rogue bars.
        local shade=0.72
        while 0.2126*linearColour(r*shade)+0.7152*linearColour(g*shade)+0.0722*linearColour(b*shade)>0.16 do
            shade=shade*0.95
        end
        colour={r*shade,g*shade,b*shade}; barColours[key]=colour
    end
    return colour[1],colour[2],colour[3]
end
function D.uiCompactNumber(value)
    if value>=1000000 then return string.format("%.1fm",value/1000000) end
    if value>=1000 then return string.format("%.1fk",value/1000) end
    return string.format("%.0f",value)
end
function D.uiFormatRow(row,value,duration,total,mode)
    local s=D.uiSettings(row.view)
    local cr,cg,cb=D.uiClassColor(row.actor)
    local br,bg,bb=D.uiBarColour(cr,cg,cb)
    row.bar:SetStatusBarColor(br,bg,bb,s.barOpacity)
    if s.classNames then row.left:SetTextColor(cr,cg,cb) else row.left:SetTextColor(1,1,1) end
    row.right:SetTextColor(1,1,1); row.rank:SetTextColor(1,1,1)
    local compact=row.bar:GetWidth()<220
    if mode=="damage" or mode=="healing" then
        local text=compact and D.uiCompactNumber(value) or D.uiNumber(value)
        if s.rate and not compact then text=text.." | "..string.format("%.1f",duration>0 and value/duration or 0) end
        if s.percent and not compact then text=text.." | "..string.format("%.1f%%",total>0 and 100*value/total or 0) end
        row.right:SetText(text)
    elseif compact and mode=="damageTaken" then row.right:SetText(D.uiCompactNumber(value))
    elseif compact and mode=="threat" and D.threatPercentForActor then
        row.right:SetText(string.format("%.0f%%",D.threatPercentForActor(row.actor) or 0))
    end
end
function D.uiPersist()
    if not D.savedVariablesReady then return end
    CawDPSMeterDB.appearance=D.uiCopySettings(D.uiSettings())
    D.uiSaveMain(); D.saveMultiWindows()
end
function D.uiRefresh(v)
    if v then D.layoutMultiWindow(v) else D.applyCompactWindowLayout() end
    D.uiRefreshMeters(); if D.pfDockUpdate then D.pfDockUpdate() end
    if D.pfBagLayerTick then D.pfBagLayerTick() end
    D.uiPersist()
end

local pages={"General","Window","Bars","Text","Threat","pfUI"}
-- Keep stable control IDs: appearance is shared with saved windows.
local controls={
    {"Window","scale","Scale",0.05,"number"},{"Window","width","Width",1,"size"},
    {"Window","height","Height",1,"size"},{"Window","rows","Visible bars",1,"rows"},
    {"Window","opacity","Background opacity",0.01,"number"},{"Window","watermark","Watermark opacity",0.01,"number"},
    {"Bars","rowHeight","Height",1,"number"},{"Bars","rowGap","Spacing",1,"number"},
    {"Text","fontSize","Font size",1,"number"},{"Bars","barOpacity","Opacity",0.01,"number"},
    {"Bars","icons","Show class and pet icons",0,"bool"},{"Bars","ranks","Show rank numbers",0,"bool"},
    {"Text","classNames","Use class colours for names",0,"bool"},{"Text","rate","Show DPS / HPS",0,"bool"},
    {"Text","percent","Show percentages",0,"bool"},{"General","autoCurrent","Switch to Current when combat starts",0,"bool"},
    {"General","hover","Show tooltips on player bars",0,"bool"},{"Window","locked","Lock window",0,"lock"},
    {"pfUI","docked","Dock to the right chat panel",0,"dock"},{"pfUI","alternate","Show meters when chat is hidden",0,"alternate"},
    {"pfUI","behindInventory","Keep Caw behind inventory windows",0,"behindInventory"},
    {"Threat","glow","Screen glow",0,"alertBool"},{"Threat","sound","Warning sound",0,"alertBool"},
    {"Threat","threshold","Warning threshold (%)",1,"alertNumber"},
    {"Threat","cooldown","Warning cooldown (sec)",1,"alertNumber"}
}
local descriptions={
    General="Choose how your meter behaves.",Window="Set the size and appearance of this window.",
    Bars="Adjust the player bars.",Text="Choose the information shown on each bar.",
    pfUI="Share the right chat panel with Caw.",
    Threat="Aggro warnings for your character, shared by all Caw windows."
}
local function optionValue(p,c)
    local v=p.view; local f=v and v.frame or D.window; local key=c[2]; local kind=c[5]
    if kind=="alertBool" or kind=="alertNumber" then return D.threatAlertSettings()[key] end
    if kind=="size" then if key=="width" then return f:GetWidth() else return f:GetHeight() end end
    if kind=="rows" then return D.uiVisibleRows(v,f) end
    if kind=="lock" then if v then return v.locked else return D.locked end end
    if kind=="dock" then if v then return v.pfDock else return CawDPSMeterCharDB and CawDPSMeterCharDB.pfDockMain end end
    if kind=="alternate" then return CawDPSMeterCharDB and CawDPSMeterCharDB.pfDockAlternate end
    if kind=="behindInventory" then return CawDPSMeterCharDB and CawDPSMeterCharDB.bagLayerAlwaysBehind end
    return D.uiSettings(v)[key]
end
local function optionRange(p,c)
    if c[5]=="alertNumber" then return D.threatAlertRanges[c[2]][1],D.threatAlertRanges[c[2]][2] end
    if c[5]=="size" then return c[2]=="width" and 160 or D.uiHeightForRows(p.view,1),900 end
    if c[5]=="rows" then
        local s=D.uiSettings(p.view)
        return 1,math.min(20,math.floor((900-51+s.rowGap)/(s.rowHeight+s.rowGap)))
    end
    return ranges[c[2]][1],ranges[c[2]][2]
end
local function setOption(p,c,value)
    local v=p.view; if v and v.closed then return end
    local f=v and v.frame or D.window; local key=c[2]; local kind=c[5]
    local old=optionValue(p,c)
    if kind=="number" or kind=="size" or kind=="rows" or kind=="alertNumber" then
        value=tonumber(value); if not value or value~=value then D.refreshOptions(); return end
        local lo,hi=optionRange(p,c)
        value=math.max(lo,math.min(hi,math.floor(value/c[4]+0.5)*c[4]))
    end
    if kind=="alertBool" or kind=="alertNumber" then
        D.threatAlertSettings()[key]=value
        D.threatAlertEpisode=nil; D.threatAlertPreviewUntil=nil; D.threatAlertStop()
    elseif kind=="lock" then D.uiSetLock(v,value)
    elseif kind=="dock" then if (old and true or false)~=value then D.pfDockToggle(v) end
    elseif kind=="alternate" then if (old and true or false)~=value then D.pfDockToggleVisibility() end
    elseif kind=="behindInventory" then
        CawDPSMeterCharDB=CawDPSMeterCharDB or {}; CawDPSMeterCharDB.bagLayerAlwaysBehind=value and true or false
        if D.pfBagLayerTick then D.pfBagLayerTick() end
    elseif kind=="size" then if key=="width" then f:SetWidth(value) else f:SetHeight(value) end
    elseif kind=="rows" then f:SetHeight(D.uiHeightForRows(v,value))
    else D.uiSettings(v)[key]=value end
    D.uiRefresh(v); D.refreshOptions()
end
local function updatePreview(p)
    local preview=p.preview; local s=D.uiSettings(p.view)
    preview:SetBackdropColor(0.025,0.027,0.032,s.opacity)
    preview.brand:SetAlpha(s.watermark)
    preview.caption:SetText("Preview")
    local demo={{"Hunter",0.67,0.83,0.45,1,"HUNTER"},{"Warrior",0.78,0.61,0.43,0.72,"WARRIOR"},{"Mage",0.41,0.80,0.94,0.46,"MAGE"}}
    for i,b in ipairs(preview.rows) do
        local d=demo[i]; local y=-32-(i-1)*(s.rowHeight+s.rowGap)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",preview,"TOPLEFT",7,y)
        local br,bg,bb=D.uiBarColour(d[2],d[3],d[4])
        b:SetHeight(s.rowHeight); b:SetStatusBarColor(br,bg,bb,s.barOpacity)
        b:SetMinMaxValues(0,1); b:SetValue(d[5])
        local fontSize=math.min(s.fontSize,s.rowHeight-4)
        local start=s.icons and 26 or 5
        b.name:ClearAllPoints(); b.name:SetPoint("LEFT",b,"LEFT",start,0); b.name:SetWidth(94-start)
        b.name:SetHeight(s.rowHeight-2); b.value:SetHeight(s.rowHeight-2)
        b.name:SetFont(FONT,fontSize); b.name:SetText((s.ranks and (i..".  ") or "")..d[1])
        b.actor={classToken=d[6]}; D.setBarActorIcon(b)
        b.classIcon:SetWidth(math.min(18,s.rowHeight-4)); b.classIcon:SetHeight(math.min(18,s.rowHeight-4))
        if s.icons then b.classIcon:Show() else b.classIcon:Hide() end
        b.name:SetTextColor(s.classNames and d[2] or 1,s.classNames and d[3] or 1,s.classNames and d[4] or 1)
        b.value:SetTextColor(1,1,1); b.value:SetShadowColor(0,0,0,1); b.value:SetShadowOffset(1,-1)
        b.value:SetFont(FONT,fontSize); b.value:SetText(s.percent and (math.floor(d[5]*100).."%") or (s.rate and "120 | 20" or "120"))
    end
    preview:SetHeight(39+3*s.rowHeight+2*s.rowGap)
end
function D.refreshOptions()
    local p=D.optionsPanel; if not p then return end
    if p.view and p.view.closed then p.view=nil end
    p.target.text:SetText("Window "..tostring(p.view and p.view.id or 1))
    p.heading:SetText(p.page); p.description:SetText(descriptions[p.page])
    for _,b in ipairs(p.tabs) do D.uiSelectButton(b,b.page==p.page); b.mark:SetAlpha(b.page==p.page and 1 or 0) end
    local y=-125
    p.updating=true
    for i,c in ipairs(controls) do
        local r=p.controls[i]
        if c[1]==p.page then
            r:ClearAllPoints(); r:SetPoint("TOPLEFT",p,"TOPLEFT",180,y); r:Show()
            local value=optionValue(p,c)
            if r.slider then
                local lo,hi=optionRange(p,c); r.slider:SetMinMaxValues(lo,hi); r.slider:SetValue(value)
                r.input:SetText(string.format("%.0f",value*r.factor))
                y=y-46
            else r.check:SetChecked(value and 1 or nil); y=y-36 end
        else r:Hide() end
    end
    p.updating=false
    for _,b in ipairs(p.actions) do if b.page==p.page then b:Show() else b:Hide() end end
    if p.page=="Threat" then
        p.preview:Hide(); p.target:Hide(); p.editing:Hide(); p.copyButton:Hide(); p.threatNote:Show()
        local c=D.threatAlertSettings(); D.uiEnableButton(p.threatTest,c.glow or c.sound)
    else
        p.preview:Show(); updatePreview(p); p.target:Show(); p.editing:Show(); p.copyButton:Show(); p.threatNote:Hide()
    end
    p.pfNote:SetText(p.page=="pfUI" and "Chat switching applies to all docked windows. Enable the inventory option for bag addons Caw cannot identify automatically." or "")
end
function D.uiConfirmReset(kind)
    if not D.resetDialog then
        local f=D.uiDialog("CawResetDialog","Reset data",390,158); D.resetDialog=f
        f.label=D.uiText(f,"",18,-58,354,12); f.label:SetHeight(35)
        D.uiButton(f,"Cancel",166,-116,94,function() f:Hide() end)
        D.uiButton(f,"Reset",270,-116,100,function() D.uiResetData(f.kind); f:Hide() end)
    end
    D.resetDialog.kind=kind
    local label=kind=="all" and "all combat data" or (kind=="overall" and "Overall" or "Current")
    D.resetDialog.label:SetText("Clear "..label.." in all windows?")
    D.resetDialog:Show()
end
function D.openOptions(v)
    if v and v.id==1 then v=nil end
    D.uiCloseMeterMenus(v or D.mainView)
    local p=D.optionsPanel
    if not p then
        p=D.uiDialog("CawOptionsPanel","Caw Settings",790,485); D.optionsPanel=p
        p:SetScale(math.min(p:GetScale(),0.85))
        p.page="Window"; p.controls={}; p.tabs={}; p.actions={}
        D.uiBlock(p,1,-40,155,399,0.075,0.08,0.09)
        D.uiBlock(p,156,-40,1,399,0.23,0.24,0.27)
        D.uiBlock(p,1,-439,788,1,0.23,0.24,0.27)
        D.uiText(p,"SETTINGS",18,-59,122,10):SetTextColor(0.49,0.50,0.53)
        for i,name in ipairs(pages) do
            local b=D.uiListButton(p,12,-87-(i-1)*34,132,function() p.page=this.page; p.targetMenu:Hide(); D.refreshOptions() end)
            b.page=name; b.text:SetText(name); b:SetHeight(29)
            b.mark=D.uiBlock(b,0,-1,2,27,0.72,0.64,0.43,1,"OVERLAY")
            p.tabs[i]=b
        end
        local brand=p:CreateTexture(nil,"ARTWORK"); brand:SetTexture("Interface\\AddOns\\CawDPSMeter\\Media\\CawBrand.tga")
        brand:SetWidth(132); brand:SetHeight(17); brand:SetPoint("TOPLEFT",p,"TOPLEFT",12,-381); brand:SetAlpha(0.70)
        D.uiText(p,"1.1.0",60,-410,54,10):SetTextColor(0.48,0.49,0.51)
        p.heading=D.uiText(p,"",180,-59,580,19)
        p.description=D.uiText(p,"",180,-88,580,12); p.description:SetTextColor(0.58,0.59,0.62)
        p.pfNote=D.uiText(p,"",180,-216,365,12); p.pfNote:SetHeight(65)
        p.threatNote=D.uiText(p,"Requires current server threat data for your target. Warnings also work when the meter is hidden.\n\nEnable either effect, then use Test warning to preview it. Sound follows your game volume.",180,-303,570,12)
        p.threatNote:SetHeight(100); p.threatNote:SetTextColor(0.68,0.69,0.72); p.threatNote:Hide()
        p.preview=CreateFrame("Frame",nil,p); p.preview:SetWidth(184); p.preview:SetHeight(160)
        p.preview:SetPoint("TOPLEFT",p,"TOPLEFT",584,-145); D.uiPanel(p.preview)
        p.preview.caption=D.uiText(p.preview,"Preview",0,26,184,12); p.preview.caption:SetTextColor(0.62,0.63,0.65)
        p.preview.brand=p.preview:CreateTexture(nil,"ARTWORK"); p.preview.brand:SetTexture("Interface\\AddOns\\CawDPSMeter\\Media\\CawClaw.tga")
        p.preview.brand:SetWidth(90); p.preview.brand:SetHeight(90); p.preview.brand:SetPoint("CENTER",p.preview,"CENTER",0,0)
        D.uiText(p.preview,"Damage",7,-8,90,11); D.uiText(p.preview,"Overall",112,-8,66,11)
        p.preview.rows={}
        for i=1,3 do
            local b=CreateFrame("StatusBar",nil,p.preview); b:SetWidth(170); b:SetStatusBarTexture(TEX)
            b.name=D.uiText(b,"",5,-4,92,11); b.value=D.uiText(b,"",97,-4,68,11); b.value:SetJustifyH("RIGHT")
            b.value:ClearAllPoints(); b.value:SetPoint("RIGHT",b,"RIGHT",-5,0)
            b.classIcon=b:CreateTexture(nil,"OVERLAY"); b.classIcon:SetPoint("LEFT",b,"LEFT",4,0)
            b.name:SetShadowColor(0,0,0,1); b.name:SetShadowOffset(1,-1)
            p.preview.rows[i]=b
        end
        for i,c in ipairs(controls) do
            local r=CreateFrame("Frame",nil,p); r:SetWidth(378); r:SetHeight(36); r.control=c
            p.controls[i]=r; p.controls[c[2]]=r
            local numeric=c[5]=="number" or c[5]=="size" or c[5]=="rows" or c[5]=="alertNumber"
            if numeric then
                D.uiText(r,c[3],0,-5,157,12)
                r.factor=c[4]<1 and 100 or 1
                r.slider=CreateFrame("Slider",nil,r); r.slider:SetOrientation("HORIZONTAL")
                r.slider:SetWidth(128); r.slider:SetHeight(20); r.slider:SetPoint("TOPLEFT",r,"TOPLEFT",162,-1)
                r.slider.controlRow=r; r.slider:SetValueStep(c[4])
                D.uiBlock(r.slider,0,-9,128,3,0.29,0.29,0.31)
                r.slider:SetThumbTexture(TEX); r.slider:GetThumbTexture():SetWidth(9); r.slider:GetThumbTexture():SetHeight(18)
                r.slider:GetThumbTexture():SetVertexColor(0.72,0.64,0.43,1)
                r.slider:SetScript("OnValueChanged",function()
                    if not p.updating then local row=this.controlRow; setOption(p,row.control,this:GetValue()) end
                end)
                r.input=D.uiInput(r,304,0,54); r.input.controlRow=r
                r.input:SetScript("OnEnterPressed",function()
                    local row=this.controlRow; local value=tonumber(this:GetText())
                    setOption(p,row.control,value and value/row.factor); this:ClearFocus()
                end)
                r.input:SetScript("OnEditFocusLost",function()
                    if p.updating then return end
                    local row=this.controlRow; local value=tonumber(this:GetText())
                    setOption(p,row.control,value and value/row.factor)
                end)
                if r.factor==100 then D.uiText(r,"%",361,-5,15,11) end
            else
                r.check=CreateFrame("CheckButton",nil,r); r.check:SetWidth(20); r.check:SetHeight(20)
                r.check:SetPoint("TOPLEFT",r,"TOPLEFT",0,-1); D.uiPanel(r.check); r.check.controlRow=r
                r.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
                r.check:SetScript("OnClick",function()
                    local row=this.controlRow; setOption(p,row.control,this:GetChecked() and true or false)
                end)
                D.uiText(r,c[3],29,-4,347,12)
            end
        end
        local function action(page,label,x,y,w,fn)
            local b=D.uiButton(p,label,x,y,w,fn); b.page=page; table.insert(p.actions,b); return b
        end
        action("General","New window",180,-238,174,function()
            local new=D.createMultiWindow(nil); if new then p.view=new end; D.saveMultiWindows(); D.refreshOptions()
        end)
        action("General","Show main window",366,-238,174,function() D.window:Show() end)
        p.threatTest=action("Threat","Test warning",584,-145,184,function() D.threatAlertTest() end)
        p.editing=D.uiText(p,"Editing",18,-453,64,12)
        p.target=D.uiListButton(p,78,-449,158,function()
            if p.targetMenu:IsShown() then p.targetMenu:Hide(); return end
            local n=0
            for i=1,D.multiWindowMax do
                local b=p.targetMenu.buttons[i]
                if i==1 or D.multiWindows[i] then
                    b:ClearAllPoints(); b:SetPoint("TOPLEFT",p.targetMenu,"TOPLEFT",4,-4-n*27); b:Show(); n=n+1
                    D.uiSelectButton(b,(p.view and p.view.id or 1)==i)
                else b:Hide() end
            end
            p.targetMenu:SetHeight(8+n*27); p.targetMenu:Show()
        end)
        D.uiText(p.target,"v",140,-5,10,10)
        p.targetMenu=CreateFrame("Frame",nil,p); p.targetMenu:SetWidth(158); p.targetMenu:SetHeight(150)
        p.targetMenu:SetPoint("BOTTOMLEFT",p.target,"TOPLEFT",0,3); p.targetMenu:SetFrameLevel(120)
        p.targetMenu:EnableMouse(true); D.uiPanel(p.targetMenu); p.targetMenu.buttons={}; p.targetMenu:Hide()
        for i=1,D.multiWindowMax do
            local b=D.uiListButton(p.targetMenu,4,-4,150,function()
                p.view=this.windowId~=1 and D.multiWindows[this.windowId] or nil; p.targetMenu:Hide(); D.refreshOptions()
            end)
            b.windowId=i; b.text:SetText("Window "..i); p.targetMenu.buttons[i]=b
        end
        p.copyButton=D.uiButton(p,"Copy to all windows",368,-449,160,function()
            local source=D.uiCopySettings(D.uiSettings(p.view)); D.appearance=D.uiCopySettings(source)
            for _,view in pairs(D.multiWindows) do view.appearance=D.uiCopySettings(source); D.layoutMultiWindow(view) end
            D.uiRefresh(nil); D.refreshOptions()
        end)
        D.uiButton(p,"Defaults",539,-449,105,function()
            if p.page=="Threat" then
                CawDPSMeterCharDB.threatAlerts=nil; D.threatAlertEpisode=nil; D.threatAlertPreviewUntil=nil; D.threatAlertStop()
            elseif p.view then p.view.appearance=D.uiCopySettings(nil) else D.appearance=D.uiCopySettings(nil) end
            D.uiRefresh(p.view); D.refreshOptions()
        end)
        D.uiButton(p,"Close",663,-449,105,function() p:Hide() end)
        p:SetScript("OnHide",function() p.targetMenu:Hide() end)
    end
    p.view=v; D.refreshOptions(); p:Show()
end
function D.uiEnsureOptionsButton(v)
    if not v.optionsButton then
        local b=D.uiButton(v.frame,"",0,0,17,function() D.openOptions(this.meterView.id~=1 and this.meterView or nil) end)
        v.optionsButton=b; b.meterView=v
        -- A small sliders glyph stays legible at the narrow header size.
        for i=1,3 do
            local line=D.uiBlock(b,0,0,9,1,0.85,0.85,0.87,1,"OVERLAY")
            line:ClearAllPoints(); line:SetPoint("CENTER",b,"CENTER",0,4-(i-1)*4)
            local knob=D.uiBlock(b,0,0,2,3,0.85,0.85,0.87,1,"OVERLAY")
            knob:ClearAllPoints(); knob:SetPoint("CENTER",b,"CENTER",i==2 and 2 or -2,4-(i-1)*4)
        end
        b:SetScript("OnEnter",function()
            local tt=D.getControlTooltip(); tt:SetOwner(this,"ANCHOR_TOP"); tt:SetText("Settings",1,1,1); tt:Show()
        end)
        b:SetScript("OnLeave",function() if D.controlTooltip then D.controlTooltip:Hide() end end)
    end
    return v.optionsButton
end
SLASH_CAWOPTIONS1="/cawoptions"
SlashCmdList.CAWOPTIONS=function() D.openOptions(nil) end

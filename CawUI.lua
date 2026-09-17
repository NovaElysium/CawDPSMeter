-- Shared appearance and native Vanilla configuration panels. No combat producer.
local D=CAW_DPS_METER
local TEX="Interface\\Buttons\\WHITE8X8"
local FONT="Fonts\\ARIALN.TTF"
D.uiFont=FONT
D.uiAccent={0.72,0.64,0.43}
D.uiDefaults={scale=1,rowHeight=23,rowGap=3,fontSize=11,opacity=0.94,barOpacity=0.85,
    watermark=0.40,icons=true,ranks=true,classNames=false,rate=true,percent=false,
    autoCurrent=false,hover=true,hideSolo=false,hideParty=false,hideRaid=false,hideBattleground=false,
    hideInCombat=false,hideOutOfCombat=false,
    headerHeight=24,headerFontSize=11,headerOpacity=1,
    footerHeight=20,footerFontSize=9,footerOpacity=0.94,showFooter=true,
    fontFace=1,fontOutline=1,textShadow=true,nameAlign=1,namePadding=7,valuePadding=6,columnGap=10,textOffset=0,
    barTexture=1,classBars=true,growUp=false,buttonSide=1,alwaysOverflow=false,
    showClose=true,showLock=true,showSettings=true,showReset=true,showReport=true,showNew=true,
    windowColour={0.025,0.027,0.032},borderColour={0.15,0.16,0.18},headerColour={0.045,0.048,0.055},
    footerColour={0.018,0.020,0.024},barColour={0.28,0.39,0.46},rowColour={0.04,0.044,0.05},
    textColour={1,1,1},shadowColour={0,0,0}}
local ranges={scale={0.6,1.6},rowHeight={14,36},rowGap={0,10},fontSize={8,16},
    opacity={0,1},barOpacity={0.1,1},watermark={0,0.8},
    headerHeight={18,48},headerFontSize={8,16},headerOpacity={0,1},
    footerHeight={14,40},footerFontSize={8,16},footerOpacity={0,1},
    fontFace={1,4},fontOutline={1,3},nameAlign={1,3},namePadding={0,24},valuePadding={0,24},
    columnGap={4,32},textOffset={-8,8},barTexture={1,2},buttonSide={1,2}}
local choices={fontFace={"Arial Narrow","Friz Quadrata","Morpheus","Skurri"},
    fontOutline={"None","Outline","Thick outline"},nameAlign={"Left","Centre","Right"},
    barTexture={"Flat","Blizzard"},buttonSide={"Right","Left"}}
local fonts={FONT,"Fonts\\FRIZQT__.TTF","Fonts\\MORPHEUS.TTF","Fonts\\SKURRI.TTF"}
local textures={TEX,"Interface\\TargetingFrame\\UI-StatusBar"}
local outlines={"","OUTLINE","THICKOUTLINE"}
local alignments={"LEFT","CENTER","RIGHT"}
function D.uiWindowFont(v) return fonts[D.uiSettings(v).fontFace] or FONT end
function D.uiApplyTextStyle(text,s,size)
    text:SetFont(fonts[s.fontFace] or FONT,size,outlines[s.fontOutline] or "")
    text:SetShadowColor(s.shadowColour[1],s.shadowColour[2],s.shadowColour[3],s.textShadow and 1 or 0)
    text:SetShadowOffset(s.textShadow and 1 or 0,s.textShadow and -1 or 0)
end

function D.uiCopySettings(src)
    local out={}; local k,default
    for k,default in pairs(D.uiDefaults) do
        local value=src and src[k]
        if type(default)=="boolean" then
            if type(value)~="boolean" then value=default end
        elseif type(default)=="table" then
            local colour={}
            for i=1,3 do
                local n=type(value)=="table" and tonumber(value[i]) or nil
                colour[i]=n and n==n and math.max(0,math.min(1,n)) or default[i]
            end
            value=colour
        else
            value=tonumber(value)
            if not value or value~=value then value=default end
            value=math.max(ranges[k][1],math.min(ranges[k][2],value))
            if choices[k] then value=math.floor(value) end
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
-- Visibility only affects the meter frames. Recording and sync keep running.
-- Battlegrounds have their own rule, even when their roster is a raid.
function D.uiDetectGroupContext()
    if IsInInstance then
        local inside,kind=IsInInstance()
        if inside and kind=="pvp" then return "hideBattleground" end
    end
    if GetBattlefieldStatus then
        for i=1,(MAX_BATTLEFIELD_QUEUES or 3) do
            if GetBattlefieldStatus(i)=="active" then return "hideBattleground" end
        end
    end
    if GetNumRaidMembers and GetNumRaidMembers()>0 then return "hideRaid" end
    if GetNumPartyMembers and GetNumPartyMembers()>0 then return "hideParty" end
    return "hideSolo"
end
function D.uiApplyMeterVisibility(f)
    if not f then return end
    local v=f.cawThemeView
    local hidden=f.cawManuallyHidden or f.cawHiddenByContext or (v and v.closed)
        or (f.cawDockFree and f.cawDockFree.hiddenByDock)
    f.cawApplyingVisibility=true
    if hidden then
        if f:IsShown() then f:Hide() end
    elseif not f:IsShown() then f:Show() end
    f.cawApplyingVisibility=nil
end
function D.uiUpdateWindowVisibility(v)
    if not v or v.closed then return end
    if not D.uiGroupContext then D.uiGroupContext=D.uiDetectGroupContext() end
    if D.uiPlayerInCombat==nil then D.uiPlayerInCombat=UnitAffectingCombat and UnitAffectingCombat("player") and true or false end
    local s=D.uiSettings(v)
    v.frame.cawHiddenByContext=(s[D.uiGroupContext] or (D.uiPlayerInCombat and s.hideInCombat)
        or (not D.uiPlayerInCombat and s.hideOutOfCombat)) and true or nil
    D.uiApplyMeterVisibility(v.frame)
end
function D.uiUpdateVisibility()
    if not D.savedVariablesReady then return end
    D.uiUpdateWindowVisibility(D.mainView)
    for i=2,D.multiWindowMax do D.uiUpdateWindowVisibility(D.multiWindows[i]) end
end
function D.uiSetMeterShown(f,shown)
    -- Also remember a manual hide when the window is already auto-hidden.
    f.cawManuallyHidden=not shown or nil
    if f.cawThemeView then D.uiUpdateWindowVisibility(f.cawThemeView)
    else D.uiApplyMeterVisibility(f) end
end
-- Keep rows, scrolling and exact row fitting on the same content rectangle.
function D.uiWindowInsets(v)
    local s=D.uiSettings(v)
    return s.headerHeight+5,(s.showFooter and s.footerHeight or 0)+2
end
function D.uiFooterMetrics(v)
    local s=D.uiSettings(v)
    local size=math.min(s.footerFontSize,s.footerHeight-6)
    return s.footerHeight,size,math.floor((s.footerHeight-size-3)/2)
end
function D.uiHeightForRows(v,n)
    local s=D.uiSettings(v); local top,bottom=D.uiWindowInsets(v)
    return top+n*s.rowHeight+math.max(0,n-1)*s.rowGap+bottom
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
    -- Small epsilon guards against sub-pixel height rounding from this custom
    -- 1.12 client's UI-scale conversion (see the edge-clamp comment below for
    -- the same class of quirk), which could otherwise floor() a full row's
    -- worth of height down to one fewer visible bar than was actually set.
    local top,bottom=D.uiWindowInsets(v)
    return math.max(1,math.min(20,math.floor((f:GetHeight()-top-bottom+s.rowGap)/(s.rowHeight+s.rowGap)+0.1)))
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
    for i,entry in ipairs({{"options","Settings"},{"add","Add window"},{"report","Report"},{"reset","Reset"},{"lock","Lock"},{"close","Close"}}) do
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
local menuLabels={damage="Damage / DPS",healing="Healing / HPS",overhealing="Overheal",threat="Threat",damageTaken="Damage Taken",
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
                b.text:SetText(label); b.cawMenuLabel=(kind=="segment" and b.cawSegmentFullLabel) or label
                b.cawMenuClipped=b.text:GetStringWidth()>b.text:GetWidth() or b.cawMenuLabel~=label
                if kind=="segment" then D.uiFitSelector(b.text,label) end
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
    -- New history entries can create buttons after the window was layered.
    -- Refresh this popup when it is styled/opened instead of rebuilding every
    -- window's complete frame tree on each docking poll.
    if D.pfDockLayerTree and v and v.frame then
        local f=v.frame
        D.pfDockLayerTree(menu,60,"DIALOG",f.cawDockedLayer,f:GetFrameStrata()=="BACKGROUND")
    end
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
                local current=view.id==1 and D or view
                if current.mode=="healing" and not D.dpsLogActive then
                    tt:AddLine("Raw combat text mode: totals are not overheal-corrected.",0.8,0.8,0.8)
                elseif current.mode=="overhealing" then
                    tt:AddLine("Overheal / total healing for events with recorded overheal data.",0.8,0.8,0.8)
                    tt:AddLine("Requires DPSLog data, recorded locally or received through Caw sync.",0.8,0.8,0.8)
                end
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
    h:SetHeight(D.uiSettings(v).footerHeight-2)
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
    local s=D.uiSettings(v)
    if not s.showFooter then
        v.footer:Hide(); v.footerLine:Hide(); v.footerHandle:Hide(); v.summary:Hide()
        return
    end
    v.footer:Show(); v.footerLine:Show(); v.footerHandle:Show(); v.summary:Show()
    local height,fontSize,textY=D.uiFooterMetrics(v)
    v.footer:SetHeight(height-3); v.footer:SetAlpha(s.footerOpacity)
    v.footerLine:ClearAllPoints(); v.footerLine:SetPoint("BOTTOMLEFT",v.frame,"BOTTOMLEFT",1,height-1)
    v.footerLine:SetAlpha(s.footerOpacity)
    local w=v.frame:GetWidth()
    v.footerHandle:SetHeight(height-2); v.footerHandle:SetWidth(math.max(1,w-28))
    D.uiApplyTextStyle(v.summary,s,fontSize); v.summary:SetHeight(fontSize+3)
    v.summary:ClearAllPoints(); v.summary:SetPoint("BOTTOMRIGHT",v.frame,"BOTTOMRIGHT",-27,textY)
    v.summary:SetWidth(math.max(1,w-33)); v.summary:SetJustifyH("RIGHT")
    v.summary:SetText(v.footerText or v.summary:GetText() or "")
    D.uiFooterRegion(v,"summary",3,w-28)
    local private=D.localSyncFooterLayout and D.localSyncFooterLayout(v)
    D.uiFitMeterSummary(v,private and w<300)
end
function D.uiUpdateMeterFooter(v)
    if not v then return end
    local current=v.id==1 and D or v
    if not D.parserEnabled() and current.mode~="threat" then v.summary:SetText("Parser paused") end
    v.footerText=v.summary:GetText() or ""
    v.modeButton.cawMenuLabel=menuLabels[current.mode]; v.modeButton.cawMenuClipped=true
    v.segmentButton.cawMenuLabel=v.id==1 and D.reportSegmentName() or D.multiReportSegmentName(v)
    v.segmentButton.cawMenuClipped=true
    D.uiFitSelector(v.modeText,menuLabels[current.mode] or v.modeText:GetText(),menuShort[current.mode])
    D.uiFitSelector(v.segmentText,v.segmentText:GetText())
    D.uiLayoutMeterFooter(v)
end
function D.uiFitSelector(text,label,short)
    label=label or ""; text:SetText(label)
    if text:GetStringWidth()<=text:GetWidth() then return end
    if short then label=short; text:SetText(label) end
    local n=string.len(label)
    while n>0 and text:GetStringWidth()>text:GetWidth() do
        n=n-1; text:SetText(n>0 and (string.sub(label,1,n).."...") or "")
    end
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
        f.cawThemeView=v; f.cawMeterOnHide=f:GetScript("OnHide"); f.cawMeterOnShow=f:GetScript("OnShow")
        f:SetScript("OnHide",function()
            local window=this; D.uiCloseMeterMenus(window.cawThemeView)
            if not window.cawApplyingVisibility then window.cawManuallyHidden=true end
            D.uiStopMeterDrag(window.cawDragHandle)
            if window.cawMeterOnHide then window.cawMeterOnHide() end
        end)
        f:SetScript("OnShow",function()
            local window=this
            if not window.cawApplyingVisibility then
                window.cawManuallyHidden=nil; D.uiUpdateWindowVisibility(window.cawThemeView)
            end
            if window.cawMeterOnShow then window.cawMeterOnShow() end
        end)
    end
    f:SetBackdropColor(s.windowColour[1],s.windowColour[2],s.windowColour[3],s.opacity)
    f:SetBackdropBorderColor(s.borderColour[1],s.borderColour[2],s.borderColour[3],1)
    v.header:SetVertexColor(s.headerColour[1],s.headerColour[2],s.headerColour[3],s.headerOpacity)
    v.headerLine:SetVertexColor(0.20,0.18,0.13,s.headerOpacity)
    v.footer:SetVertexColor(s.footerColour[1],s.footerColour[2],s.footerColour[3],1)
    v.footer:SetWidth(f:GetWidth()-2); v.footer:SetAlpha(s.footerOpacity)
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
    local top,bottom=D.uiWindowInsets(v)
    if v.id==1 and D.mainWheelArea then
        D.mainWheelArea:ClearAllPoints()
        D.mainWheelArea:SetPoint("TOPLEFT",f,"TOPLEFT",4,-top)
        D.mainWheelArea:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-4,bottom)
    end
    local rows=v.id==1 and D.rows or v.rows
    local i,row
    for i,row in ipairs(rows or {}) do
        row.view=v.id~=1 and v or nil
        row.frame:SetHeight(s.rowHeight); row.frame:ClearAllPoints()
        local y=-top-(i-1)*(s.rowHeight+s.rowGap)
        if s.growUp then y=-f:GetHeight()+bottom+s.rowHeight+(i-1)*(s.rowHeight+s.rowGap) end
        row.frame:SetPoint("TOPLEFT",f,"TOPLEFT",6,y)
        -- Without a footer, leave the existing resize-corner clearance.
        row.frame:SetPoint("TOPRIGHT",f,"TOPRIGHT",s.showFooter and -6 or -28,y)
        local fontSize=math.min(s.fontSize,s.rowHeight-4)
        D.uiApplyTextStyle(row.left,s,fontSize); D.uiApplyTextStyle(row.right,s,fontSize); D.uiApplyTextStyle(row.rank,s,fontSize)
        row.left:SetJustifyH(alignments[s.nameAlign] or "LEFT")
        row.bar:SetStatusBarTexture(textures[s.barTexture] or TEX)
        row.left:SetHeight(s.rowHeight-2); row.right:SetHeight(s.rowHeight-2); row.rank:SetHeight(s.rowHeight-2)
        local icon=math.min(18,s.rowHeight-4); row.classIcon:SetWidth(icon); row.classIcon:SetHeight(icon)
        if not row.cawRowTheme then
            row.cawRowTheme=true; D.uiPanel(row.frame,1)
            row.frame:SetBackdropColor(0.04,0.044,0.05,1); row.frame:SetBackdropBorderColor(0.12,0.13,0.15,1)
            if row.background then row.background:SetVertexColor(0.04,0.044,0.05,1) end
            if row.shade then row.shade:Hide() end
            if row.hover then row.hover:Hide() end
        end
        row.frame:SetBackdropColor(s.rowColour[1],s.rowColour[2],s.rowColour[3],1)
        if row.background then row.background:SetVertexColor(s.rowColour[1],s.rowColour[2],s.rowColour[3],1) end
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
function D.uiFitRowText(row,fullName)
    local s=D.uiSettings(row.view); local bw=row.bar:GetWidth() or 0
    -- Native font measurements can reflect the previous constrained width.
    -- Release that constraint before measuring a longer DPS/HPS value, then
    -- round up and reserve a few pixels for glyph/shadow edges at UI scales.
    local maxRight=math.max(1,bw-s.valuePadding-20)
    row.right:SetWidth(maxRight)
    local rightWidth=row.right:GetStringWidth() or 0
    rightWidth=math.min(math.ceil(rightWidth)+4,maxRight)
    local icon=D.setBarActorIcon(row) and s.icons
    local rankWidth=s.ranks and math.min(23,(row.rank:GetStringWidth() or 19)+4) or 0
    row.left:SetText(fullName)
    if bw-rightWidth-s.valuePadding-s.columnGap<80 or (bw<220 and row.left:GetStringWidth()>
        bw-24-rankWidth-s.namePadding-rightWidth-s.valuePadding-s.columnGap) then icon=false end
    if icon then row.classIcon:Show() else row.classIcon:Hide() end
    local start=icon and 24 or 3
    if not s.ranks then row.rank:SetText("") end
    local height=math.min(s.fontSize,s.rowHeight-4)+2
    local limit=math.max(0,(s.rowHeight-height)/2)
    local y=math.max(-limit,math.min(limit,s.textOffset))
    row.rank:ClearAllPoints(); row.rank:SetPoint("LEFT",row.bar,"LEFT",start,y); row.rank:SetWidth(rankWidth)
    row.left:ClearAllPoints(); row.left:SetPoint("LEFT",row.bar,"LEFT",start+rankWidth+s.namePadding,y)
    row.right:ClearAllPoints(); row.right:SetPoint("RIGHT",row.bar,"RIGHT",-s.valuePadding,y); row.right:SetWidth(rightWidth)
    row.left:SetHeight(height); row.right:SetHeight(height); row.rank:SetHeight(height)
    local available=math.max(0,bw-start-rankWidth-s.namePadding-rightWidth-s.valuePadding-s.columnGap)
    row.left:SetWidth(available); row.left:SetText(fullName)
    if available<12 then row.left:SetText(""); return end
    local n=string.len(fullName)
    while n>0 and row.left:GetStringWidth()>available do
        n=n-1; row.left:SetText(n>0 and (string.sub(fullName,1,n).."...") or "")
    end
end
function D.uiFormatRow(row,value,duration,total,mode)
    local s=D.uiSettings(row.view)
    local cr,cg,cb=D.uiClassColor(row.actor)
    local br,bg,bb=D.uiBarColour(cr,cg,cb)
    if not s.classBars then br,bg,bb=unpack(s.barColour) end
    row.bar:SetStatusBarColor(br,bg,bb,s.barOpacity)
    if s.classNames then row.left:SetTextColor(cr,cg,cb) else row.left:SetTextColor(unpack(s.textColour)) end
    row.right:SetTextColor(unpack(s.textColour)); row.rank:SetTextColor(unpack(s.textColour))
    local compact=row.bar:GetWidth()<220
    if mode=="damage" or mode=="healing" then
        local text=compact and D.uiCompactNumber(value) or D.uiNumber(value)
        if s.rate and not compact then text=text.." | "..string.format("%.1f",duration>0 and value/duration or 0) end
        if s.percent and not compact then text=text.." | "..string.format("%.1f%%",total>0 and 100*value/total or 0) end
        row.right:SetText(text)
    elseif mode=="overhealing" then
        row.right:SetText(compact and D.uiCompactNumber(value) or (D.uiNumber(value).." | "..D.overhealPercent(value,row.overhealTotal)))
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
    D.uiUpdateVisibility()
    D.uiRefreshMeters(); if D.pfDockUpdate then D.pfDockUpdate() end
    if D.pfBagLayerTick then D.pfBagLayerTick() end
    D.uiPersist()
end

local pages={"Window","Bars","Text","Header","Footer","General","Threat","pfUI"}
local pageLabels={Window="Window",Bars="Player bars",Text="Text",Header="Top bar",Footer="Bottom bar",
    General="Combat & sync",Threat="Aggro alerts",pfUI="Docking & bags"}
local descriptions={Window="Choose the size, background and when this window is shown.",Bars="Change the size and appearance of player bars.",
    Text="Choose the font and the numbers shown on each bar.",Header="Customize the top bar and its buttons.",
    Footer="Customize the bottom bar that shows your totals.",General="Choose how combat is recorded and shared.",
    Threat="Get a warning when you are close to pulling aggro.",pfUI="Fit Caw around your chat and inventory windows."}
-- Control keys stay unchanged so existing saved appearances are preserved.
local controls={}
local function optionsGroup(page,group,advanced,entries)
    for _,e in ipairs(entries) do table.insert(controls,{page,e[1],e[2],e[3],e[4],group,e[5],advanced}) end
end
optionsGroup("Window","Size",false,{
    {"scale","Window scale",0.05,"number","Makes the whole meter larger or smaller. 100% is the original size."},
    {"width","Window width",1,"size"},{"rows","Number of bars",1,"rows","Resizes the window to fit this many player bars, including the top and bottom bars."},
    {"locked","Lock window in place",0,"lock","Prevents moving or resizing this window."}})
optionsGroup("Window","Automatically hide",false,{
    {"hideSolo","When solo",0,"bool","Hides this window when you are not in a party or raid. Combat recording and sync continue. Use /cawoptions to change this while hidden."},
    {"hideParty","In a party",0,"bool","Hides this window in a party, including dungeons. Raids and battlegrounds use their own settings."},
    {"hideRaid","In a raid",0,"bool","Hides this window in a raid group outside battlegrounds."},
    {"hideBattleground","In a battleground",0,"bool","Hides this window inside a battleground. This rule replaces the solo, party and raid rules there; joining the queue does not hide it."},
    {"hideInCombat","In combat",0,"bool","Hides this window while your character is in combat. Applies in addition to the group rules. Combat recording and sync continue."},
    {"hideOutOfCombat","Out of combat",0,"bool","Hides this window while your character is out of combat. Applies in addition to the group rules. Enabling both combat options keeps it hidden at all times."}})
optionsGroup("Window","Background",false,{
    {"windowColour","Background colour",0,"colour"},{"opacity","Background opacity",0.01,"number","0% is transparent; 100% is solid. Player bars keep their own opacity."},
    {"borderColour","Border colour",0,"colour"},{"watermark","Logo opacity",0.01,"number","Controls how visible the Caw logo is behind the bars. Set to 0% to hide it."}})
optionsGroup("Window","Exact height",true,{
    {"height","Window height",1,"size","Sets the exact height in pixels. Use Number of bars for an easier fit."}})
optionsGroup("Bars","Size and style",false,{
    {"rowHeight","Bar height",1,"number"},{"rowGap","Gap between bars",1,"number"},
    {"barTexture","Bar texture",0,"choice"},{"barOpacity","Bar opacity",0.01,"number","How solid the filled part of each bar looks."}})
optionsGroup("Bars","Colours",false,{
    {"classBars","Use class colours",0,"bool","Colours each player's bar by class. Turn this off to choose one colour for all bars."},
    {"barColour","Custom bar colour",0,"colour","Used when Use class colours is turned off."},{"rowColour","Empty bar colour",0,"colour","Colours the unfilled part of each bar."}})
optionsGroup("Bars","Display",false,{
    {"icons","Show class and pet icons",0,"bool"},{"ranks","Show rank numbers",0,"bool"},
    {"growUp","Stack bars from the bottom",0,"bool","Places rank 1 at the bottom of the window and stacks the other players above it."}})
optionsGroup("Text","Font",false,{
    {"fontFace","Font",0,"choice","The font is shared by player names, values and the top and bottom bars."},
    {"fontSize","Bar text size",1,"number","Top and bottom bar text sizes are set on their own pages."},
    {"fontOutline","Text outline",0,"choice"},{"textShadow","Add a text shadow",0,"bool"}})
optionsGroup("Text","Colours",false,{
    {"textColour","Text colour",0,"colour"},{"classNames","Use class colours for names",0,"bool","Only changes player names. Numbers keep the text colour chosen above."},
    {"shadowColour","Shadow colour",0,"colour","Used when Add a text shadow is turned on."}})
optionsGroup("Text","Numbers",false,{
    {"rate","Show DPS / HPS",0,"bool","Shows the per-second rate beside damage or healing. Very narrow bars shorten the display to keep names readable."},
    {"percent","Show share of total (%)",0,"bool","Shows each player's share of the group's damage or healing. Very narrow bars may hide this extra value."}})
optionsGroup("Text","Text position",true,{
    {"nameAlign","Name alignment",0,"choice"},{"namePadding","Space before name",1,"number","Distance between the icon/rank and the player name."},
    {"valuePadding","Space after numbers",1,"number","Distance from the numbers to the right edge of the bar."},
    {"columnGap","Name-to-number gap",1,"number","Minimum space between the player name and the numbers."},
    {"textOffset","Move text up / down",1,"number","Positive values move text up; negative values move it down. Text stays inside the bar."}})
optionsGroup("Header","Appearance",false,{
    {"headerHeight","Top bar height",1,"number"},{"headerFontSize","Text size",1,"number"},
    {"headerColour","Background colour",0,"colour"},{"headerOpacity","Background opacity",0.01,"number","0% is transparent; 100% is solid."}})
optionsGroup("Header","Buttons",true,{
    {"buttonSide","Buttons on the",0,"choice"},{"alwaysOverflow","Put all buttons in the ... menu",0,"bool","Keeps just the mode, fight selector and actions menu visible. Narrow windows always use this layout."}})
optionsGroup("Header","Buttons",true,{
    {"showSettings","Show Settings",0,"bool"},{"showNew","Show Add window",0,"bool"},
    {"showReport","Show Report",0,"bool"},{"showReset","Show Reset",0,"bool"},
    {"showLock","Show Lock",0,"bool"},{"showClose","Show Close",0,"bool"}})
optionsGroup("Footer","Display",false,{{"showFooter","Show bottom bar",0,"bool","Shows the strip with totals at the bottom of the meter."}})
optionsGroup("Footer","Appearance",false,{
    {"footerHeight","Bottom bar height",1,"number"},{"footerFontSize","Text size",1,"number"},
    {"footerColour","Background colour",0,"colour"},{"footerOpacity","Background opacity",0.01,"number","0% is transparent; 100% is solid."}})
optionsGroup("General","All windows",false,{
    {"parserEnabled","Record combat",0,"parser","Records combat using DPSLog when available, or combat text. The data source is shown on the right. Off pauses local recording and combat sync. Existing fights stay available; resuming starts a new fight."},
    {"combatSyncEnabled","Share data with other Caw users",0,"combatSync","Sync off keeps local recording active. Server threat and talent sharing remain available. Data sharing pauses while Record combat is off."}})
optionsGroup("General","Selected window",false,{
    {"autoCurrent","Switch to Current at combat start",0,"bool","Automatically selects the current fight in this window when combat starts."},
    {"hover","Show player details on hover",0,"bool","Shows the ability breakdown when you move the mouse over a player bar."}})
optionsGroup("Threat","Warning effects",false,{
    {"glow","Flash the screen edges",0,"alertBool"},{"sound","Play a warning sound",0,"alertBool"}})
optionsGroup("Threat","When to warn",false,{
    {"threshold","Warn at threat",1,"alertNumber","Warning threshold on the server threat scale. Requires current server threat data for your target."},
    {"cooldown","Time between warnings",1,"alertNumber","Minimum delay in seconds between repeated warnings."}})
optionsGroup("pfUI","Chat docking",false,{
    {"docked","Attach this meter to pfUI chat",0,"dock","Fits the selected meter to pfUI's right chat panel. Requires pfUI."},
    {"alternate","Show meters when chat is hidden",0,"alternate","Applies to all docked meters. When off, they follow the chat panel's visibility."}})
optionsGroup("pfUI","Inventory windows",false,{
    {"behindInventory","Keep meters behind bags",0,"behindInventory","Applies to all Caw windows. Helps with bag addons Caw cannot identify automatically; pfUI is not required."}})
local function optionDisabled(p,c)
    local s=D.uiSettings(p.view); local key=c[2]
    if key=="barColour" and s.classBars then return "Turn off Use class colours to choose a custom bar colour." end
    if key=="shadowColour" and not s.textShadow then return "Turn on Add a text shadow to change its colour." end
    if c[1]=="Footer" and key~="showFooter" and not s.showFooter then return "Turn on Show bottom bar to adjust its appearance." end
    if c[1]=="Header" and string.find(key,"^show") and s.alwaysOverflow then return "Turn off Put all buttons in the ... menu to show individual buttons." end
end
local function optionMatches(c,query)
    if query=="" then return true end
    local text=string.lower(table.concat({pageLabels[c[1]],c[1],c[2],c[3],c[6],c[7] or ""}," "))
    if string.find(string.lower(c[2]),"opacity",1,true) or c[2]=="watermark" then text=text.." transparency" end
    for word in string.gfind(query,"%S+") do
        word=string.gsub(word,"color","colour")
        if not string.find(text,word,1,true) then return false end
    end
    return true
end
local function optionValue(p,c)
    local v=p.view; local f=v and v.frame or D.window; local key=c[2]; local kind=c[5]
    if kind=="alertBool" or kind=="alertNumber" then return D.threatAlertSettings()[key] end
    if kind=="size" then if key=="width" then return f:GetWidth() else return f:GetHeight() end end
    if kind=="rows" then return D.uiVisibleRows(v,f) end
    if kind=="lock" then if v then return v.locked else return D.locked end end
    if kind=="dock" then if v then return v.pfDock else return CawDPSMeterCharDB and CawDPSMeterCharDB.pfDockMain end end
    if kind=="alternate" then return CawDPSMeterCharDB and CawDPSMeterCharDB.pfDockAlternate end
    if kind=="behindInventory" then return CawDPSMeterCharDB and CawDPSMeterCharDB.bagLayerAlwaysBehind end
    if kind=="parser" then return D.parserEnabled() end
    if kind=="combatSync" then return not CawDPSMeterCharDB or CawDPSMeterCharDB.combatSyncEnabled~=false end
    return D.uiSettings(v)[key]
end
local function optionRange(p,c)
    if c[5]=="alertNumber" then return D.threatAlertRanges[c[2]][1],D.threatAlertRanges[c[2]][2] end
    if c[5]=="size" then return c[2]=="width" and 160 or D.uiHeightForRows(p.view,1),900 end
    if c[5]=="rows" then
        local s=D.uiSettings(p.view)
        local top,bottom=D.uiWindowInsets(p.view)
        return 1,math.min(20,math.floor((900-top-bottom+s.rowGap)/(s.rowHeight+s.rowGap)))
    end
    return ranges[c[2]][1],ranges[c[2]][2]
end
local function setOption(p,c,value)
    local v=p.view; if v and v.closed then return end
    if optionDisabled(p,c) then D.refreshOptions(); return end
    local f=v and v.frame or D.window; local key=c[2]; local kind=c[5]
    local old=optionValue(p,c)
    if kind=="number" or kind=="size" or kind=="rows" or kind=="alertNumber" or kind=="choice" then
        value=tonumber(value); if not value or value~=value then D.refreshOptions(); return end
        local lo,hi=optionRange(p,c)
        local step=kind=="choice" and 1 or c[4]
        value=math.max(lo,math.min(hi,math.floor(value/step+0.5)*step))
    end
    if kind=="alertBool" or kind=="alertNumber" then
        D.threatAlertSettings()[key]=value
        D.threatAlertEpisode=nil; D.threatAlertPreviewUntil=nil; D.threatAlertStop()
    elseif kind=="parser" then D.setParserEnabled(value)
    elseif kind=="combatSync" then D.setCombatSyncEnabled(value)
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
local function popupTree(frame,entries,parent)
    local entry={frame=frame,strata=frame:GetFrameStrata(),level=frame:GetFrameLevel(),parent=parent}
    table.insert(entries,entry)
    if frame.GetChildren then
        for _,child in ipairs({frame:GetChildren()}) do popupTree(child,entries,entry) end
    end
end
local function raisePopup(entries,strata,base)
    -- Capture first, then change the entire tree. Vanilla/pfUI children may
    -- retain explicit strata or levels when only their parent is raised.
    for _,entry in ipairs(entries) do
        local parent=entry.parent; local level=base
        if parent then
            local behind=entry.frame==parent.frame.backdrop or entry.frame==parent.frame.backdrop_shadow
                or entry.strata=="BACKGROUND"
            level=parent.raisedLevel+(behind and -1 or 2)
        end
        entry.raisedLevel=level
        entry.frame:SetFrameStrata(strata); entry.frame:SetFrameLevel(math.max(0,level))
    end
end
function D.uiCloseSettingsMenus(p,except)
    for _,menu in pairs({p.choiceMenu,p.targetMenu}) do if menu~=except then menu:Hide() end end
    if ColorPickerFrame and ColorPickerFrame~=except and ColorPickerFrame.cawOwner==p then ColorPickerFrame:Hide() end
end
function D.uiShowSettingsMenu(p,menu)
    D.uiCloseSettingsMenus(p,menu); menu:Show()
    local entries={}; popupTree(menu,entries)
    raisePopup(entries,"DIALOG",p:GetFrameLevel()+30)
end
local function restoreColourPicker(picker)
    local state=picker.cawPopupState; picker.cawPopupState=nil; picker.cawOwner=nil
    if not state then return end
    for _,entry in ipairs(state.entries) do
        entry.frame:SetFrameStrata(entry.strata); entry.frame:SetFrameLevel(entry.level)
    end
    picker:SetScale(state.scale); picker:ClearAllPoints()
    for _,point in ipairs(state.points) do picker:SetPoint(unpack(point)) end
end
local function showColourPicker(p,picker)
    if not picker.cawHideHook then
        picker.cawHideHook=true
        local previous=picker:GetScript("OnHide")
        picker:SetScript("OnHide",function()
            local frame=this; restoreColourPicker(frame)
            if previous then previous() end
        end)
    end
    D.uiCloseSettingsMenus(p,picker)
    picker:Show() -- Let skins finish OnShow before capturing and raising children.
    local state={entries={},points={},scale=picker:GetScale()}
    popupTree(picker,state.entries)
    local count=picker.GetNumPoints and picker:GetNumPoints() or 1
    for i=1,count do table.insert(state.points,{picker:GetPoint(i)}) end
    picker.cawPopupState=state; picker.cawOwner=p
    raisePopup(state.entries,"FULLSCREEN_DIALOG",40)
    local parent=picker:GetParent(); local parentScale=parent and parent:GetEffectiveScale() or 1
    local uiScale=UIParent:GetEffectiveScale()
    local scale=math.min(p:GetEffectiveScale(),uiScale*(UIParent:GetWidth()-24)/math.max(1,picker:GetWidth()),
        uiScale*(UIParent:GetHeight()-24)/math.max(1,picker:GetHeight()))
    picker:SetScale(math.max(0.1,scale)/parentScale)
    picker:ClearAllPoints(); picker:SetPoint("CENTER",p,"CENTER",0,0)
    D.uiClamp(picker)
end
local function openChoice(p,row)
    if optionDisabled(p,row.control) then return end
    local menu=p.choiceMenu
    if not menu then
        menu=CreateFrame("Frame",nil,p); p.choiceMenu=menu; D.uiPanel(menu)
        menu:SetFrameStrata("DIALOG"); menu:SetFrameLevel(p:GetFrameLevel()+30); menu:EnableMouse(true)
        menu:SetWidth(196); menu.buttons={}
        for i=1,4 do
            local b=D.uiListButton(menu,4,-4-(i-1)*25,188,function()
                local selected=this; local control=menu.control; menu:Hide()
                setOption(p,control,selected.choice)
            end)
            b:SetHeight(24); b.choice=i; menu.buttons[i]=b
        end
        menu:Hide()
    end
    if menu:IsShown() and menu.control==row.control then menu:Hide(); return end
    menu.control=row.control; menu:ClearAllPoints()
    -- Open upwards near the bottom of the clipped settings area.
    local options=choices[row.control[2]]; local height=8+table.getn(options)*25
    local y=(row.optionOffset or 0)-(p.controlsOffset or 0)
    if y+height+24>p.controlsViewport:GetHeight() then menu:SetPoint("BOTTOMLEFT",row.select,"TOPLEFT",0,2)
    else menu:SetPoint("TOPLEFT",row.select,"BOTTOMLEFT",0,-2) end
    for i,b in ipairs(menu.buttons) do
        if options[i] then b:Show(); b.text:SetText(options[i]); D.uiSelectButton(b,optionValue(p,row.control)==i)
        else b:Hide() end
    end
    menu:SetHeight(height); D.uiShowSettingsMenu(p,menu)
end
local function openColour(p,row)
    if optionDisabled(p,row.control) then return end
    local picker=ColorPickerFrame; if not picker then return end
    local view=p.view; local key=row.control[2]; local old=D.uiSettings(view)[key]
    local original={old[1],old[2],old[3]}
    picker:Hide(); picker.func=nil; picker.cancelFunc=nil; picker.opacityFunc=nil
    picker.hasOpacity=false; picker:SetColorRGB(unpack(original))
    local function apply(colour)
        if view and view.closed then return end
        D.uiSettings(view)[key]=colour; D.uiRefresh(view); D.refreshOptions()
    end
    picker.func=function() local r,g,b=picker:GetColorRGB(); apply({r,g,b}) end
    picker.cancelFunc=function() apply({original[1],original[2],original[3]}) end
    picker.previousValues=original
    showColourPicker(p,picker)
end
function D.uiScrollOptions(p,offset)
    local maximum=math.max(0,(p.controlsHeight or 0)-p.controlsViewport:GetHeight())
    p.controlsOffset=math.max(0,math.min(maximum,offset or 0))
    p.controlsViewport:SetVerticalScroll(p.controlsOffset)
    if p.choiceMenu then p.choiceMenu:Hide() end
    if not p.scrollUpdating then
        p.scrollUpdating=true; p.controlsScroll:SetMinMaxValues(0,maximum); p.controlsScroll:SetValue(p.controlsOffset)
        p.scrollUpdating=false
    end
    if maximum>0 then p.controlsScroll:Show() else p.controlsScroll:Hide() end
end
local function updatePreview(p)
    local preview=p.preview; local s=D.uiSettings(p.view)
    preview:SetBackdropColor(s.windowColour[1],s.windowColour[2],s.windowColour[3],s.opacity)
    preview:SetBackdropBorderColor(s.borderColour[1],s.borderColour[2],s.borderColour[3],1)
    preview.brand:SetAlpha(s.watermark)
    preview.caption:SetText("Preview")
    preview.header:SetHeight(s.headerHeight); preview.header:SetAlpha(s.headerOpacity)
    preview.header:SetVertexColor(unpack(s.headerColour)); preview.footer:SetVertexColor(unpack(s.footerColour))
    local headerFont=math.min(s.headerFontSize,s.headerHeight-8)
    for _,label in ipairs({preview.mode,preview.segment}) do
        D.uiApplyTextStyle(label,s,headerFont); label:SetHeight(headerFont+3)
    end
    preview.mode:ClearAllPoints(); preview.mode:SetPoint("LEFT",preview.header,"LEFT",7,0)
    preview.segment:ClearAllPoints(); preview.segment:SetPoint("RIGHT",preview.header,"RIGHT",-7,0)
    local footerHeight,footerFont=D.uiFooterMetrics(p.view)
    preview.footer:SetHeight(footerHeight); preview.footer:SetAlpha(s.footerOpacity)
    D.uiApplyTextStyle(preview.total,s,footerFont); preview.total:SetHeight(footerFont+3)
    if s.showFooter then preview.footer:Show(); preview.total:Show() else preview.footer:Hide(); preview.total:Hide() end
    local demo={{"Hunter",0.67,0.83,0.45,1,"HUNTER"},{"Warrior",0.78,0.61,0.43,0.72,"WARRIOR"},{"Mage",0.41,0.80,0.94,0.46,"MAGE"}}
    for i,b in ipairs(preview.rows) do
        local d=demo[i]; local index=s.growUp and 3-i or i-1
        local y=-s.headerHeight-8-index*(s.rowHeight+s.rowGap)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",preview,"TOPLEFT",7,y)
        local br,bg,bb=D.uiBarColour(d[2],d[3],d[4])
        if not s.classBars then br,bg,bb=unpack(s.barColour) end
        b:SetHeight(s.rowHeight); b:SetStatusBarColor(br,bg,bb,s.barOpacity)
        b:SetStatusBarTexture(textures[s.barTexture]); b.background:SetVertexColor(unpack(s.rowColour))
        b:SetMinMaxValues(0,1); b:SetValue(d[5])
        local fontSize=math.min(s.fontSize,s.rowHeight-4)
        local start=s.icons and 26 or 5
        b.name:ClearAllPoints(); b.name:SetPoint("LEFT",b,"LEFT",start,0); b.name:SetWidth(94-start)
        b.name:SetHeight(s.rowHeight-2); b.value:SetHeight(s.rowHeight-2)
        D.uiApplyTextStyle(b.name,s,fontSize); b.name:SetJustifyH(alignments[s.nameAlign])
        b.name:SetText((s.ranks and (i..".  ") or "")..d[1])
        b.actor={classToken=d[6]}; D.setBarActorIcon(b)
        b.classIcon:SetWidth(math.min(18,s.rowHeight-4)); b.classIcon:SetHeight(math.min(18,s.rowHeight-4))
        if s.icons then b.classIcon:Show() else b.classIcon:Hide() end
        b.name:SetTextColor(s.classNames and d[2] or s.textColour[1],s.classNames and d[3] or s.textColour[2],s.classNames and d[4] or s.textColour[3])
        b.value:SetTextColor(unpack(s.textColour)); D.uiApplyTextStyle(b.value,s,fontSize)
        b.value:SetText(s.percent and (math.floor(d[5]*100).."%") or (s.rate and "120 | 20" or "120"))
        local offset=math.max(-(s.rowHeight-fontSize-2)/2,math.min((s.rowHeight-fontSize-2)/2,s.textOffset))
        b.name:ClearAllPoints(); b.name:SetPoint("LEFT",b,"LEFT",start+s.namePadding-7,offset)
        b.value:ClearAllPoints(); b.value:SetPoint("RIGHT",b,"RIGHT",-s.valuePadding,offset)
        b.name:SetHeight(fontSize+2); b.value:SetHeight(fontSize+2)
        b.name:SetWidth(math.max(1,170-start-s.namePadding+7-68-s.valuePadding-s.columnGap))
    end
    preview:SetHeight(s.headerHeight+15+3*s.rowHeight+2*s.rowGap+(s.showFooter and footerHeight or 0))
end
local function optionTooltip(frame,row)
    frame.cawOptionRow=row
    frame:SetScript("OnEnter",function()
        local row=this.cawOptionRow; local c=row.control
        local tt=D.getControlTooltip(); tt:SetOwner(this,"ANCHOR_RIGHT"); tt:SetText(c[3],1,1,1)
        if c[7] then tt:AddLine(c[7],0.85,0.85,0.85,1) end
        if row.disabledReason then tt:AddLine(row.disabledReason,1,0.82,0.4,1) end
        if c[1]=="Header" and string.find(c[2],"^show") then tt:AddLine("Hidden buttons remain available in the ... menu.",0.85,0.85,0.85,1) end
        tt:Show()
    end)
    frame:SetScript("OnLeave",function() if D.controlTooltip then D.controlTooltip:Hide() end end)
end
local function optionsHeading(p,key,title,advanced,y,searching)
    local h=p.groupHeaders[key]
    if not h then
        h=D.uiListButton(p.controlsContent,0,0,358,function()
            if this.advanced and p.searchQuery=="" then
                p.expandedGroups[this.groupKey]=not p.expandedGroups[this.groupKey]; D.refreshOptions()
            end
        end)
        h:SetHeight(22); h.text:SetFont(FONT,11)
        h.groupKey=key; h.advanced=advanced; p.groupHeaders[key]=h
        h:SetScript("OnEnter",nil); h:SetScript("OnLeave",nil)
    end
    local open=not advanced or p.expandedGroups[key] or searching
    h:ClearAllPoints(); h:SetPoint("TOPLEFT",p.controlsContent,"TOPLEFT",0,y)
    h:EnableMouse(advanced and not searching)
    h:SetBackdropColor(0.12,0.12,0.13,advanced and 0.8 or 0)
    h:SetBackdropBorderColor(0.25,0.25,0.27,advanced and 1 or 0)
    h.text:SetTextColor(0.78,0.71,0.54)
    h.text:SetText((advanced and not searching and (open and "v  " or ">  ") or "")..title)
    h:Show(); return open
end
local function updateInputStatus(p)
    local box=p.inputStatus
    if not box or not box:IsVisible() then return end
    local source,detail,sync,syncDetail=D.combatInputStatus()
    -- A source/roster change updates these labels without rebuilding settings,
    -- moving the scroll position or interrupting an open control.
    if box.source:GetText()~=source then box.source:SetText(source) end
    if box.detail:GetText()~=detail then box.detail:SetText(detail) end
    if box.sync:GetText()~=sync then box.sync:SetText(sync) end
    if box.syncDetail:GetText()~=syncDetail then box.syncDetail:SetText(syncDetail) end
end
function D.refreshOptions()
    local p=D.optionsPanel; if not p then return end
    if p.view and p.view.closed then p.view=nil end
    local query=p.searchQuery or ""; local searching=query~=""
    p.target.text:SetText("Window "..tostring(p.view and p.view.id or 1))
    p.heading:SetText(searching and "Search results" or pageLabels[p.page])
    p.description:SetText(descriptions[p.page])
    for _,b in ipairs(p.tabs) do
        local selected=not searching and b.page==p.page
        D.uiSelectButton(b,selected); b.mark:SetAlpha(selected and 1 or 0)
    end
    for _,h in pairs(p.groupHeaders) do h:Hide() end
    local y=0; local lastGroup; local open=true; local found=0
    p.updating=true
    for i,c in ipairs(controls) do
        local r=p.controls[i]
        local matches=(searching or c[1]==p.page) and optionMatches(c,query)
        if matches then
            found=found+1
            local key=c[1]..":"..c[6]
            if key~=lastGroup then
                if lastGroup then y=y-10 end
                local title=searching and (pageLabels[c[1]].." / "..c[6]) or c[6]
                open=optionsHeading(p,key,title,c[8],y,searching); y=y-28; lastGroup=key
            end
        end
        if matches and open then
            r:ClearAllPoints(); r:SetPoint("TOPLEFT",p.controlsContent,"TOPLEFT",0,y); r.optionOffset=-y; r:Show()
            local value=optionValue(p,c)
            r.disabledReason=optionDisabled(p,c); r:SetAlpha(r.disabledReason and 0.6 or 1)
            if r.slider then
                local lo,hi=optionRange(p,c); r.slider:SetMinMaxValues(lo,hi); r.slider:SetValue(value)
                r.input:SetText(string.format("%.0f",value*r.factor))
                r.slider:EnableMouse(not r.disabledReason); r.input:EnableMouse(not r.disabledReason)
                if r.disabledReason then r.input:ClearFocus() end
                y=y-40
            elseif r.select then
                D.uiEnableButton(r.select,not r.disabledReason); r.select:SetAlpha(1)
                if c[5]=="choice" then r.select.text:SetText(choices[c[2]][value])
                else r.swatch:SetVertexColor(unpack(value)) end
                y=y-34
            else
                D.uiEnableButton(r.check,not r.disabledReason); r.check:SetAlpha(1)
                r.check:SetChecked(value and 1 or nil); y=y-32
            end
        else r:Hide() end
    end
    p.updating=false
    p.controlsHeight=-y; p.controlsContent:SetHeight(math.max(1,-y))
    local scrollKey=p.page..":"..query
    if p.scrollPage~=scrollKey then p.controlsOffset=0; p.scrollPage=scrollKey end
    D.uiScrollOptions(p,p.controlsOffset)
    if searching then p.description:SetText(found..(found==1 and " setting found" or " settings found").." across all sections.") end
    if found==0 then p.noResults:Show() else p.noResults:Hide() end
    if searching then p.searchPlaceholder:Hide(); p.searchClear:Show() else p.searchPlaceholder:Show(); p.searchClear:Hide() end
    local allWindows=p.page=="Threat" and not searching
    p.scope:SetText(allWindows and "Applies to all windows on this character. Changes are saved automatically."
        or ("Editing Window "..tostring(p.view and p.view.id or 1)..". Changes are saved automatically."))
    for _,b in ipairs(p.actions) do if not searching and b.page==p.page then b:Show() else b:Hide() end end
    if allWindows then
        p.target:Hide(); p.editing:Hide()
        local c=D.threatAlertSettings(); D.uiEnableButton(p.threatTest,c.glow or c.sound)
    else p.target:Show(); p.editing:Show() end
    if searching or p.page=="General" or p.page=="Threat" or p.page=="pfUI" then p.copyButton:Hide() else p.copyButton:Show() end
    if searching then p.resetButton:Hide() else p.resetButton:Show() end
    local notes={Threat="Requires current server threat data for your target.\n\nWarnings also work when the meter is hidden. Use Test warning to try your chosen effects.",
        pfUI="Chat docking requires pfUI's right chat panel.\n\nThe bag setting works with other inventory addons too, without pfUI."}
    local showInput=(not searching and p.page=="General") or (searching
        and (p.controls.parserEnabled:IsShown() or p.controls.combatSyncEnabled:IsShown()))
    if showInput then
        p.preview:Hide(); p.infoNote:Hide(); p.inputStatus:Show(); updateInputStatus(p)
    elseif not searching and notes[p.page] then
        p.inputStatus:Hide()
        p.preview:Hide(); p.infoNote:SetText(notes[p.page]); p.infoNote:Show()
        p.infoNote:ClearAllPoints(); p.infoNote:SetPoint("TOPLEFT",p,"TOPLEFT",584,p.page=="Threat" and -187 or -145)
    else p.inputStatus:Hide(); p.infoNote:Hide(); p.preview:Show(); updatePreview(p) end
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
        p.groupHeaders={}; p.expandedGroups={}; p.searchQuery=""
        p.title:SetWidth(300)
        p.search=D.uiInput(p,470,-8,270); p.search:SetTextInsets(7,29,0,0)
        p.searchPlaceholder=D.uiText(p.search,"Search settings...",7,-5,220,12)
        p.searchPlaceholder:SetTextColor(0.55,0.56,0.58)
        p.searchClear=D.uiButton(p.search,"x",244,-2,22,function()
            p.search:SetText(""); p.searchQuery=""; D.refreshOptions(); p.search:ClearFocus()
        end)
        p.searchClear:SetHeight(20); p.searchClear:Hide()
        p.search:SetScript("OnTextChanged",function()
            p.searchQuery=string.lower(string.gsub(string.gsub(this:GetText() or "","^%s+",""),"%s+$",""))
            D.refreshOptions()
        end)
        p.search:SetScript("OnEscapePressed",function()
            this:SetText(""); p.searchQuery=""; D.refreshOptions(); this:ClearFocus()
        end)
        D.uiBlock(p,1,-40,155,399,0.075,0.08,0.09)
        D.uiBlock(p,156,-40,1,399,0.23,0.24,0.27)
        D.uiBlock(p,1,-439,788,1,0.23,0.24,0.27)
        D.uiText(p,"SETTINGS",18,-59,122,10):SetTextColor(0.49,0.50,0.53)
        for i,name in ipairs(pages) do
            local b=D.uiListButton(p,12,-87-(i-1)*34,132,function()
                p.page=this.page; p.searchQuery=""; p.search:SetText(""); p.search:ClearFocus()
                p.targetMenu:Hide(); D.refreshOptions()
            end)
            b.page=name; b.text:SetText(pageLabels[name]); b:SetHeight(29)
            b.mark=D.uiBlock(b,0,-1,2,27,0.72,0.64,0.43,1,"OVERLAY")
            p.tabs[i]=b
        end
        local brand=p:CreateTexture(nil,"ARTWORK"); brand:SetTexture("Interface\\AddOns\\CawDPSMeter\\Media\\CawBrand.tga")
        brand:SetWidth(132); brand:SetHeight(17); brand:SetPoint("TOPLEFT",p,"TOPLEFT",12,-381); brand:SetAlpha(0.70)
        D.uiText(p,D.version,60,-410,54,10):SetTextColor(0.48,0.49,0.51)
        p.heading=D.uiText(p,"",180,-59,580,19)
        p.description=D.uiText(p,"",180,-88,580,12); p.description:SetTextColor(0.58,0.59,0.62)
        p.scope=D.uiText(p,"",180,-108,580,10); p.scope:SetTextColor(0.65,0.61,0.51)
        p.infoNote=D.uiText(p,"",584,-145,184,12); p.infoNote:SetHeight(230); p.infoNote:SetTextColor(0.68,0.69,0.72)
        local box=CreateFrame("Frame",nil,p); p.inputStatus=box
        box:SetPoint("TOPLEFT",p,"TOPLEFT",584,-140); box:SetWidth(184); box:SetHeight(283)
        local function statusText(text,y,size,height)
            local label=D.uiText(box,text,0,y,184,size)
            label:SetHeight(height); label:SetJustifyV("TOP")
            return label
        end
        statusText("Local recording",0,11,16):SetTextColor(0.78,0.71,0.54)
        box.source=statusText("",-20,14,20)
        box.detail=statusText("",-45,12,68); box.detail:SetTextColor(0.68,0.69,0.72)
        statusText("Caw Sync",-123,11,16):SetTextColor(0.78,0.71,0.54)
        box.sync=statusText("",-143,14,20)
        box.syncDetail=statusText("",-168,12,63); box.syncDetail:SetTextColor(0.68,0.69,0.72)
        statusText("DPSLog is optional. Older fights may have missing details; missing data is not zero.",-241,11,42):SetTextColor(0.65,0.61,0.51)
        box:SetScript("OnUpdate",function()
            if GetTime()<(this.nextRefresh or 0) then return end
            this.nextRefresh=GetTime()+1; updateInputStatus(p)
        end)
        box:Hide()
        p.controlsViewport=CreateFrame("ScrollFrame",nil,p)
        p.controlsViewport:SetPoint("TOPLEFT",p,"TOPLEFT",180,-140)
        p.controlsViewport:SetWidth(378); p.controlsViewport:SetHeight(283); p.controlsViewport:EnableMouseWheel(true)
        p.controlsContent=CreateFrame("Frame",nil,p.controlsViewport)
        p.controlsContent:SetWidth(378); p.controlsContent:SetHeight(1)
        p.controlsViewport:SetScrollChild(p.controlsContent)
        p.noResults=D.uiText(p,"No settings found.\nTry font, bags or sync.",180,-153,378,12); p.noResults:SetHeight(60); p.noResults:Hide()
        p.controlsViewport:SetScript("OnMouseWheel",function() D.uiScrollOptions(p,(p.controlsOffset or 0)-arg1*40) end)
        p.controlsScroll=CreateFrame("Slider",nil,p); p.controlsScroll:SetOrientation("VERTICAL")
        p.controlsScroll:SetPoint("TOPLEFT",p,"TOPLEFT",561,-140)
        p.controlsScroll:SetWidth(9); p.controlsScroll:SetHeight(283); p.controlsScroll:SetValueStep(20)
        D.uiPanel(p.controlsScroll); p.controlsScroll:SetThumbTexture(TEX)
        p.controlsScroll:GetThumbTexture():SetWidth(7); p.controlsScroll:GetThumbTexture():SetHeight(24)
        p.controlsScroll:GetThumbTexture():SetVertexColor(0.72,0.64,0.43,1)
        p.controlsScroll:SetScript("OnValueChanged",function()
            if not p.scrollUpdating then D.uiScrollOptions(p,this:GetValue()) end
        end)
        p.preview=CreateFrame("Frame",nil,p); p.preview:SetWidth(184); p.preview:SetHeight(160)
        p.preview:SetPoint("TOPLEFT",p,"TOPLEFT",584,-145); D.uiPanel(p.preview)
        p.preview.caption=D.uiText(p.preview,"Preview",0,26,184,12); p.preview.caption:SetTextColor(0.62,0.63,0.65)
        p.preview.brand=p.preview:CreateTexture(nil,"ARTWORK"); p.preview.brand:SetTexture("Interface\\AddOns\\CawDPSMeter\\Media\\CawClaw.tga")
        p.preview.brand:SetWidth(90); p.preview.brand:SetHeight(90); p.preview.brand:SetPoint("CENTER",p.preview,"CENTER",0,0)
        p.preview.header=D.uiBlock(p.preview,1,-1,182,24,0.045,0.048,0.055)
        p.preview.mode=D.uiText(p.preview,"Damage",7,-8,90,11)
        p.preview.segment=D.uiText(p.preview,"Overall",112,-8,66,11); p.preview.segment:SetJustifyH("RIGHT")
        p.preview.footer=D.uiBlock(p.preview,0,0,182,20,0.018,0.020,0.024)
        p.preview.footer:ClearAllPoints(); p.preview.footer:SetPoint("BOTTOMLEFT",p.preview,"BOTTOMLEFT",1,1)
        p.preview.total=D.uiText(p.preview,"Total: 360",7,0,168,9)
        p.preview.total:ClearAllPoints(); p.preview.total:SetPoint("CENTER",p.preview.footer,"CENTER",0,0)
        p.preview.total:SetJustifyH("RIGHT")
        p.preview.rows={}
        for i=1,3 do
            local b=CreateFrame("StatusBar",nil,p.preview); b:SetWidth(170); b:SetStatusBarTexture(TEX)
            b.background=b:CreateTexture(nil,"BACKGROUND"); b.background:SetTexture(TEX); b.background:SetAllPoints(b)
            b.name=D.uiText(b,"",5,-4,92,11); b.value=D.uiText(b,"",97,-4,68,11); b.value:SetJustifyH("RIGHT")
            b.value:ClearAllPoints(); b.value:SetPoint("RIGHT",b,"RIGHT",-5,0)
            b.classIcon=b:CreateTexture(nil,"OVERLAY"); b.classIcon:SetPoint("LEFT",b,"LEFT",4,0)
            b.name:SetShadowColor(0,0,0,1); b.name:SetShadowOffset(1,-1)
            p.preview.rows[i]=b
        end
        for i,c in ipairs(controls) do
            local r=CreateFrame("Frame",nil,p.controlsContent); r:SetWidth(378); r:SetHeight(36); r.control=c
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
                local unit=c[2]=="threshold" and "%" or nil
                if r.factor==100 then unit="%" elseif c[2]=="cooldown" then unit="s"
                elseif c[5]~="rows" and not unit then unit="px" end
                if unit then D.uiText(r,unit,361,-5,17,10) end
            elseif c[5]=="choice" or c[5]=="colour" then
                D.uiText(r,c[3],0,-5,157,12)
                r.select=D.uiButton(r,"Choose colour",162,0,196,function()
                    local row=this.controlRow
                    if row.control[5]=="choice" then openChoice(p,row) else openColour(p,row) end
                end)
                r.select.controlRow=r
                if c[5]=="colour" then
                    r.swatch=D.uiBlock(r.select,8,-5,20,14,1,1,1,1,"OVERLAY")
                else D.uiText(r.select,"v",179,-5,10,10) end
            else
                r.check=CreateFrame("CheckButton",nil,r); r.check:SetWidth(20); r.check:SetHeight(20)
                r.check:SetPoint("TOPLEFT",r,"TOPLEFT",0,-1); D.uiPanel(r.check); r.check.controlRow=r
                r.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
                r.check:SetScript("OnClick",function()
                    local row=this.controlRow; setOption(p,row.control,this:GetChecked() and true or false)
                end)
                D.uiText(r,c[3],29,-4,347,12)
            end
            r:EnableMouse(true); optionTooltip(r,r)
            for _,widget in pairs({r.slider,r.input,r.select,r.check}) do optionTooltip(widget,r) end
        end
        local function action(page,label,x,y,w,fn)
            local b=D.uiButton(p,label,x,y,w,fn); b.page=page; table.insert(p.actions,b); return b
        end
        local addWindow=action("Window","Add window",584,-395,88,function()
            local new=D.createMultiWindow(nil); if new then p.view=new end; D.saveMultiWindows(); D.refreshOptions()
        end)
        D.uiTooltip(addWindow,"Open another meter. Reuses the last closed window's position and settings, if available.")
        local showMain=action("Window","Show main",680,-395,88,function() D.uiSetMeterShown(D.window,true) end)
        D.uiTooltip(showMain,"Show the main Caw window. Automatic hiding and chat docking still apply.")
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
            p.targetMenu:SetHeight(8+n*27); D.uiShowSettingsMenu(p,p.targetMenu)
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
        D.uiTooltip(p.copyButton,"Copy this window's appearance and display options from all pages to every Caw window.")
        p.resetButton=D.uiButton(p,"Reset page",539,-449,105,function()
            if p.page=="Threat" then
                CawDPSMeterCharDB.threatAlerts=nil; D.threatAlertEpisode=nil; D.threatAlertPreviewUntil=nil; D.threatAlertStop()
            else
                local settings=D.uiSettings(p.view)
                local defaults=D.uiCopySettings(nil)
                for _,control in ipairs(controls) do
                    if control[1]==p.page and defaults[control[2]]~=nil then settings[control[2]]=defaults[control[2]] end
                end
                if p.page=="General" then D.setParserEnabled(true); D.setCombatSyncEnabled(true)
                elseif p.page=="Window" then
                    local f=p.view and p.view.frame or D.window
                    f:SetWidth(440); f:SetHeight(D.uiHeightForRows(p.view,5)); D.uiSetLock(p.view,false)
                elseif p.page=="pfUI" then
                    if optionValue(p,{"pfUI","docked","",0,"dock"}) then D.pfDockToggle(p.view) end
                    CawDPSMeterCharDB.pfDockAlternate=false; CawDPSMeterCharDB.bagLayerAlwaysBehind=false
                end
            end
            D.uiRefresh(p.view); D.refreshOptions()
        end)
        p.resetButton:SetScript("OnEnter",function()
            local tt=D.getControlTooltip(); tt:SetOwner(this,"ANCHOR_TOP")
            tt:SetText("Reset "..pageLabels[p.page],1,1,1)
            tt:AddLine("Restore the defaults on this page. Other pages keep their settings.",0.85,0.85,0.85,1)
            tt:Show()
        end)
        p.resetButton:SetScript("OnLeave",function() if D.controlTooltip then D.controlTooltip:Hide() end end)
        D.uiButton(p,"Close",663,-449,105,function() p:Hide() end)
        p:SetScript("OnHide",function()
            D.uiCloseSettingsMenus(p)
        end)
    end
    if p.view~=v then p.controlsOffset=0 end
    p.view=v; D.refreshOptions(); p:Show(); updateInputStatus(p)
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

-- Group/zone changes invalidate the cached context; no combat-event work.
D.uiVisibilityEvents=CreateFrame("Frame",nil,UIParent)
for _,ev in ipairs({"PLAYER_ENTERING_WORLD","PARTY_MEMBERS_CHANGED","RAID_ROSTER_UPDATE",
    "ZONE_CHANGED_NEW_AREA","UPDATE_BATTLEFIELD_STATUS","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do D.uiVisibilityEvents:RegisterEvent(ev) end
D.uiVisibilityEvents:SetScript("OnEvent",function()
    if event=="PLAYER_REGEN_DISABLED" then D.uiPlayerInCombat=true
    elseif event=="PLAYER_REGEN_ENABLED" then D.uiPlayerInCombat=false
    else
        D.uiGroupContext=nil
        if event=="PLAYER_ENTERING_WORLD" then D.uiPlayerInCombat=nil end
    end
    D.uiUpdateVisibility()
    if D.pfDockUpdate then D.pfDockUpdate() end
end)

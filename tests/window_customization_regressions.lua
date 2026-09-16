-- Exercise real settings callbacks and layout across main, extra and pooled windows.
local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS CUSTOMIZATION '..label) end
local function click(button) this=button; arg1='LeftButton'; button:GetScript('OnClick')() end
local function byLabel(parent,label)
    for _,f in ipairs(FRAMES) do
        if f.parent==parent and f.text and type(f.text)=='table' and (f.text:GetText()==label or f.page==label) then return f end
    end
    error('missing button '..label)
end
local function recordPoints(f)
    if not f or f.testPoints then return end
    f.testPoints={}
    local set,clear=f.SetPoint,f.ClearAllPoints
    f.SetPoint=function(self,...) self.testPoints[arg[1]]=arg; set(self,unpack(arg)) end
    f.ClearAllPoints=function(self) self.testPoints={}; clear(self) end
end
local extra=D.multiWindows[2] or D.createMultiWindow(nil)
D.appearance=D.uiCopySettings(nil); extra.appearance=D.uiCopySettings(nil)
local setHeaderColour=extra.header.SetVertexColor
extra.header.SetVertexColor=function(self,r,g,b,a) self.testOpacity=a; setHeaderColour(self,r,g,b,a) end
D.openOptions(extra); local p=D.optionsPanel
local function number(key,value)
    local e=p.controls[key].input; e:SetText(tostring(value)); this=e; e:GetScript('OnEnterPressed')()
end
local function toggle(key,value)
    local b=p.controls[key].check; b:SetChecked(value and 1 or nil); click(b)
end
click(byLabel(p,'Header'))
check(p.page=='Header' and p.controls.headerHeight:IsShown() and not p.controls.footerHeight:IsShown(),
    'Header page shows its own size, font and opacity controls')
number('headerHeight',48); number('headerFontSize',16); number('headerOpacity',35)
check(extra.appearance.headerHeight==48 and extra.modeButton:GetHeight()==42 and extra.modeText.fontSize==16
    and D.uiSettings().headerHeight==24,'header controls resize only the selected window and center its selector labels')
check(math.abs(extra.header.testOpacity-0.35)<0.0001,
    'header opacity is stored independently of window opacity')
click(byLabel(p,'Footer'))
number('footerHeight',40); number('footerFontSize',16); number('footerOpacity',25)
check(extra.footer:GetHeight()==37 and extra.footerHandle:GetHeight()==38 and extra.summary.fontSize==16
    and extra.footer:GetAlpha()==0.25,'footer background, input area and text follow independent settings')
check(D.uiHeightForRows(extra,5)==222,'five 23px bars with 3px gaps plus 48px header and 40px footer require 222px')
extra.frame:SetHeight(178); D.uiRefresh(extra)
check(D.uiVisibleRows(extra,extra.frame)==3,'taller header/footer reduce visible bars without enlarging a sufficiently large window')
p.page='Window'; number('rows',5)
check(extra.frame:GetHeight()==222 and D.uiVisibleRows(extra,extra.frame)==5,
    'Visible bars includes the customized header and footer in exact window height')
check(CawDPSMeterCharDB.extraWindows[1].appearance.headerHeight==48
    and CawDPSMeterCharDB.extraWindows[1].appearance.footerHeight==40,'extra-window settings persist with its saved layout')
-- The mock does not resolve anchors: capture them and independently check the
-- content rectangle instead of inferring correctness from visible row counts.
for _,view in ipairs({D.mainView,extra}) do
    local rows=view.id==1 and D.rows or view.rows
    for _,f in ipairs({view.modeButton,view.segmentButton,view.summary}) do recordPoints(f) end
    if view.id==1 then recordPoints(D.mainWheelArea) end
    for _,row in ipairs(rows) do recordPoints(row.frame) end
    for _,preset in ipairs({
        {18,14,14,0,1,53,true},{48,40,36,10,5,315,true},
        {24,20,23,3,5,178,true},{24,20,23,3,5,158,false}}) do
        for _,width in ipairs({160,190,300,450,900}) do
            local s=D.uiSettings(view)
            s.headerHeight=preset[1]; s.footerHeight=preset[2]; s.rowHeight=preset[3]; s.rowGap=preset[4]
            s.showFooter=preset[7]; s.headerFontSize=16; s.footerFontSize=16
            s.scale=width==160 and 0.6 or (width==900 and 1.6 or 1)
            view.frame:SetWidth(width); view.frame:SetHeight(preset[6]); D.uiRefresh(view.id~=1 and view or nil)
            assert(D.uiHeightForRows(view,preset[5])==preset[6])
            assert(D.uiVisibleRows(view,view.frame)==preset[5])
            local rowTop=-rows[1].frame.testPoints.TOPLEFT[5]
            local rowBottom=-rows[preset[5]].frame.testPoints.TOPLEFT[5]+preset[3]
            local footer=preset[7] and preset[2] or 0
            assert(rowTop>=preset[1]+4 and rowBottom<=preset[6]-footer-2)
            local controlTop=-view.modeButton.testPoints.TOPLEFT[5]
            assert(controlTop>=1 and controlTop+view.modeButton:GetHeight()<=preset[1]-1)
            assert(view.modeText:GetHeight()<=view.modeButton:GetHeight())
            for _,row in ipairs(rows) do
                assert(row.frame.testPoints.TOPLEFT[4]==6)
                assert(row.frame.testPoints.TOPRIGHT[4]==(preset[7] and -6 or -28))
            end
            if view.id==1 then
                assert(D.mainWheelArea.testPoints.TOPLEFT[5]==-rowTop)
                assert(D.mainWheelArea.testPoints.BOTTOMRIGHT[4]==-4)
                assert(D.mainWheelArea.testPoints.BOTTOMRIGHT[5]==footer+2)
            end
            assert(view.footerHandle:IsShown()==preset[7] and view.summary:IsShown()==preset[7])
            if preset[7] then
                local textY=view.summary.testPoints.BOTTOMRIGHT[5]
                assert(textY>=1 and textY+view.summary:GetHeight()<=footer-1)
                assert(view.footerRegions.summary:GetHeight()==footer-2)
            end
        end
    end
    check(true,'header, footer and full-width row bounds with resize clearance at five widths and four height presets in window '..view.id)
end
D.openOptions(extra); p.page='Footer'; D.refreshOptions(); toggle('showFooter',true)
number('footerHeight',999); check(extra.appearance.footerHeight==40,'oversized footer heights clamp to the supported range')
number('footerHeight','bad'); check(extra.appearance.footerHeight==40,'invalid footer input preserves the last valid height')
number('footerHeight',14); number('footerFontSize',16)
check(extra.summary.fontSize==8 or not extra.appearance.showFooter,'text scales down when the chosen footer is too short')
toggle('showFooter',false)
check(not extra.footer:IsShown() and not extra.summary:IsShown() and not extra.footerHandle:IsVisible(),
    'hidden footer releases its space and removes text and mouse hit regions')
extra.appearance.headerHeight=32; extra.appearance.rowGap=7
click(byLabel(p,'Reset page'))
check(extra.appearance.showFooter and extra.appearance.footerHeight==20
    and extra.appearance.headerHeight==32 and extra.appearance.rowGap==7,'Footer defaults reset only the Footer section')
p.page='Header'; number('headerHeight',32); number('headerFontSize',13)
click(p.copyButton)
for _,view in pairs(D.multiWindows) do assert(view.appearance.headerHeight==32 and view.appearance.headerFontSize==13) end
check(D.uiSettings().headerHeight==32 and CawDPSMeterDB.appearance.headerHeight==32,
    'Copy to all windows includes the new settings and persists the main window')
D.appearance=nil
check(D.uiSettings().headerHeight==32,'main appearance reloads the stored header size')
local saved=CawDPSMeterCharDB.extraWindows[1]; local oldFrame=extra.frame
D.removeMultiWindow(extra); extra=D.createMultiWindow(saved)
check(extra.frame==oldFrame and extra.appearance.headerHeight==32,'pooled window recreation restores saved header/footer settings')
-- Docking must preserve customization; menus stay above rows and chat switching still works.
pfUI={chat={right=CreateFrame('Frame',nil,UIParent)}}
pfUI.chat.right:SetWidth(380); pfUI.chat.right:SetHeight(180)
D.pfDockToggle(extra); D.layoutMultiWindow(extra)
check(extra.frame.cawDockedLayer and extra.modeButton:GetHeight()==26,'pfUI docking retains the configured header height')
D.uiCloseMeterMenus(extra); click(extra.segmentButton)
check(extra.segmentMenu:GetFrameLevel()>extra.rows[1].frame:GetFrameLevel(),'docked dropdown stays above bars after a header resize')
CawDPSMeterCharDB.pfDockAlternate=false; pfUI.chat.right:Hide(); D.pfDockUpdate()
check(not extra.frame:IsShown(),'chat visibility still hides the customized docked window')
pfUI.chat.right:Show(); D.pfDockUpdate(); D.pfDockToggle(extra); pfUI=nil
if D.localSyncStatusUpdate then
    local s=D.uiSettings(); s.footerHeight=40; s.footerFontSize=14; s.showFooter=true
    D.uiRefresh(nil); D.localSyncStatusUpdate()
    local f=D.localSyncStatus
    check(f.users.fontSize==14 and f.talents.fontSize==14 and f:GetHeight()==37,
        'private Caw/talent labels follow footer height and text size')
    s.showFooter=false; D.uiRefresh(nil); D.localSyncStatusUpdate()
    check(not f:IsVisible(),'the private overlay stays hidden together with its footer')
    s.showFooter=true; D.uiRefresh(nil); D.localSyncStatusUpdate()
    check(f:IsVisible(),'showing the footer restores the private labels')
end
D.appearance=D.uiCopySettings(nil)
for _,view in pairs(D.multiWindows) do view.appearance=D.uiCopySettings(nil); D.layoutMultiWindow(view) end
D.uiRefresh(nil); p:Hide()
print('Window customization checks: '..checks)

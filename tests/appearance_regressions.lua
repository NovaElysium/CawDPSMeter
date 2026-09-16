-- Settings callbacks must reach the selected meter and survive storage/reuse.
local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS APPEARANCE '..label) end
local function click(b) this=b; arg1='LeftButton'; b:GetScript('OnClick')() end
local function button(p,label)
    for _,f in ipairs(FRAMES) do
        if f.parent==p and type(f.text)=='table' and (f.text:GetText()==label or f.page==label) then return f end
    end
    error('button not found '..label)
end
local v=D.multiWindows[2] or D.createMultiWindow(nil)
D.appearance=D.uiCopySettings(nil); v.appearance=D.uiCopySettings(nil)
v.frame:SetWidth(450); v.frame:SetHeight(D.uiHeightForRows(v,5))
D.openOptions(v); local p=D.optionsPanel
local function page(name) click(button(p,name)) end
local function toggle(key,value) local b=p.controls[key].check; b:SetChecked(value and 1 or nil); click(b) end
local function number(key,value) local e=p.controls[key].input; e:SetText(tostring(value)); this=e; e:GetScript('OnEnterPressed')() end
local function choose(key,value)
    click(p.controls[key].select); click(p.choiceMenu.buttons[value])
end
page('Text'); choose('fontFace',2); choose('fontOutline',2); toggle('textShadow',false)
check(v.rows[1].left.fontPath=='Fonts\\FRIZQT__.TTF' and v.modeText.fontPath=='Fonts\\FRIZQT__.TTF'
    and v.summary.fontPath=='Fonts\\FRIZQT__.TTF' and D.rows[1].left.fontPath=='Fonts\\ARIALN.TTF',
    'font changes reach bars, header and footer in the selected window only')
check(v.rows[1].left.fontFlags=='OUTLINE' and v.rows[1].left.shadowOffset[1]==0,
    'outline and shadow options are applied to native font strings')
click(p.groupHeaders['Text:Text position']); choose('nameAlign',3); check(v.rows[1].left.justify=='RIGHT','name alignment updates the actual bar')
number('namePadding',17); number('valuePadding',12); number('columnGap',22); number('textOffset',8)
local row=v.rows[1]; row.actor={classToken='HUNTER',name='Archer'}; row.bar:SetWidth(420); row.rank:SetText('1.')
D.uiFormatRow(row,1250,10,2500,'damage'); D.fitBarActorName(row,'Archer',58)
check(row.left.lastPoint[4]==24+16+17 and row.right.lastPoint[4]==-12,
    'name and value padding change their actual anchors')
check(row.left:GetWidth()+row.left.lastPoint[4]+row.right:GetWidth()+12+22==420,
    'name and value columns keep the requested gap')
check(row.left.lastPoint[5]+row.left:GetHeight()/2<=v.appearance.rowHeight/2,
    'vertical offset is constrained to keep text inside the bar')
page('Bars'); choose('barTexture',2); toggle('classBars',false); toggle('growUp',true)
check(row.bar.barTexture=='Interface\\TargetingFrame\\UI-StatusBar','selected texture reaches player bars')
local bottom=(v.appearance.showFooter and v.appearance.footerHeight or 0)+2
check(row.frame.lastPoint[5]==-v.frame:GetHeight()+bottom+v.appearance.rowHeight
    and v.rows[2].frame.lastPoint[5]>row.frame.lastPoint[5],
    'upward growth anchors rank one at the bottom and subsequent ranks above it')
D.uiFormatRow(row,1250,10,2500,'damage')
check(row.bar.barColour[1]==v.appearance.barColour[1],'fixed bar colour overrides the class fill')
-- Exercise the actual vanilla colour-picker callback and cancellation contract.
ColorPickerFrame=CreateFrame('Frame','CawTestColourPicker',UIParent)
function ColorPickerFrame:SetColorRGB(r,g,b) self.rgb={r,g,b}; if self.func then self.func() end end
function ColorPickerFrame:GetColorRGB() return unpack(self.rgb) end
page('Window'); click(p.controls.windowColour.select)
ColorPickerFrame:SetColorRGB(0.2,0.3,0.4)
check(v.frame.backdropColor[1]==0.2 and D.uiSettings().windowColour[1]==0.025,
    'live colour selection changes only the selected meter')
ColorPickerFrame.cancelFunc()
check(v.frame.backdropColor[1]==0.025 and CawDPSMeterCharDB.extraWindows[1].appearance.windowColour[1]==0.025,
    'Cancel restores and persists the colour from before opening the picker')
page('Bars'); click(p.controls.barColour.select); ColorPickerFrame:SetColorRGB(0.3,0.6,0.9)
D.uiFormatRow(row,1250,10,2500,'damage')
check(row.bar.barColour[2]==0.6,'custom bar colour reaches the fill')
page('Text'); click(p.controls.textColour.select); ColorPickerFrame:SetColorRGB(0.9,0.8,0.7)
D.uiFormatRow(row,1250,10,2500,'damage')
check(row.left.textColour[2]==0.8 and row.right.textColour[2]==0.8,'custom text colour reaches both columns')
page('Window'); click(p.controls.borderColour.select); ColorPickerFrame:SetColorRGB(0.4,0.5,0.6)
check(v.frame.borderColor[3]==0.6,'border colour reaches the native window backdrop')
page('Bars'); click(p.controls.rowColour.select); ColorPickerFrame:SetColorRGB(0.1,0.2,0.3)
check(row.background.vertexColour[3]==0.3,'bar background colour reaches unfilled row area')
-- A picker captures its window even if the Editing selector changes meanwhile.
page('Header'); click(p.controls.headerColour.select); D.openOptions(nil); ColorPickerFrame:SetColorRGB(0.11,0.22,0.33)
check(v.appearance.headerColour[3]==0.33 and D.uiSettings().headerColour[3]==0.055,
    'changing the selected window cannot redirect an already-open colour picker')
ColorPickerFrame:Hide(); D.openOptions(v)
page('Header'); click(p.groupHeaders['Header:Buttons']); toggle('showSettings',false); toggle('showReport',false)
check(not v.optionsButton:IsShown() and not v.reportButton:IsShown() and v.overflowButton:IsShown(),
    'hidden header actions leave an accessible overflow button in wide windows')
local report
for _,b in ipairs(v.overflowMenu.buttons) do if b.action=='report' then report=b end end
click(v.overflowButton); click(report)
check(v.reportMenu:IsShown() and v.reportMenu.lastPoint[2]==v.overflowButton,
    'a hidden report button still opens the report menu from overflow')
choose('buttonSide',2)
check(v.closeButton.lastPoint[1]=='TOPLEFT' and v.modeButton.lastPoint[4]>5,
    'left button layout moves selectors beyond the button group')
toggle('alwaysOverflow',true)
check(v.overflowButton:IsShown() and not v.closeButton:IsShown() and not v.lockButton:IsShown(),
    'compact actions can be selected for a wide window')
for _,width in ipairs({160,190,300,450}) do
    for side=1,2 do
        v.appearance.buttonSide=side; v.frame:SetWidth(width); D.uiRefresh(v)
        assert(v.modeButton:GetWidth()>=30 and v.segmentButton:GetWidth()>=40)
        if side==2 then assert(v.modeButton.lastPoint[4]+v.modeButton:GetWidth()+3+v.segmentButton:GetWidth()<=width-5) end
    end
end
check(true,'left and right compact headers preserve both selectors at narrow widths')
for _,name in ipairs({'General','Window','Header','Footer','Bars','Text','Threat','pfUI'}) do
    page(name); D.uiScrollOptions(p,10000)
    local maximum=math.max(0,p.controlsHeight-p.controlsViewport:GetHeight())
    assert(p.controlsOffset==maximum and p.controlsViewport.scrollOffset==maximum)
    assert(p.controlsScroll:IsShown()==(maximum>0))
    D.uiScrollOptions(p,-10); assert(p.controlsOffset==0)
end
check(true,'all settings pages clamp scrolling and show a scrollbar only when needed')
page('Text'); D.uiScrollOptions(p,p.controls.nameAlign.optionOffset-240); choose('nameAlign',2)
check(v.appearance.nameAlign==2 and p.choiceMenu.lastPoint[1]=='BOTTOMLEFT',
    'a selector near the bottom opens upward outside the clipped scroll area')
page('Window'); check(p.controlsOffset==0,'switching settings sections resets their scroll position')
local snapshot=D.uiCopySettings(v.appearance)
click(button(p,'Copy to all windows')); v.appearance.barColour[1]=0.99
check(D.uiSettings().barColour[1]==snapshot.barColour[1],
    'Copy to all windows deep-copies colours without sharing mutable tables')
D.appearance=nil
check(D.uiSettings().fontFace==snapshot.fontFace and D.uiSettings().buttonSide==snapshot.buttonSide
    and D.uiSettings().textColour[2]==snapshot.textColour[2],
    'new settings survive a main-window saved-variable reload')
local saved=D.uiCopySettings(v.appearance)
D.removeMultiWindow(v); local restored=D.createMultiWindow({mode='damage',segment='current',appearance=saved})
check(restored.appearance.barTexture==saved.barTexture and restored.appearance.growUp==saved.growUp,
    'reused extra windows restore textures and growth direction')
D.openOptions(restored); page('Window'); restored.appearance.windowColour={0.4,0.5,0.6}; click(button(p,'Reset page'))
check(restored.appearance.windowColour[1]==0.025 and restored.appearance.fontFace==saved.fontFace,
    'window page reset leaves font choices intact')
local safe=D.uiCopySettings({fontFace=99,fontOutline=2.8,textColour={-1,'bad',8},barColour='bad'})
check(safe.fontFace==4 and safe.fontOutline==2 and safe.textColour[1]==0 and safe.textColour[2]==1
    and safe.textColour[3]==1 and safe.barColour[1]==D.uiDefaults.barColour[1],
    'invalid saved selections and colour components are repaired safely')
D.appearance=D.uiCopySettings(nil)
for _,extra in pairs(D.multiWindows) do extra.appearance=D.uiCopySettings(nil); D.uiRefresh(extra) end
D.uiRefresh(nil); p:Hide(); ColorPickerFrame=nil
print('Appearance checks: '..checks)

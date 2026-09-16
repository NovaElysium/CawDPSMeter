-- Reproduce the native split-layer picker with pfUI child backdrops and buttons.
local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS POPUP '..label) end
local function click(b) this=b; arg1='LeftButton'; b:GetScript('OnClick')() end
local function search(text)
    local p=D.optionsPanel; p.search:SetText(text); this=p.search; p.search:GetScript('OnTextChanged')()
end
D.openOptions(nil); local p=D.optionsPanel; D.appearance=D.uiCopySettings(nil)
local picker=CreateFrame('ColorSelect','CawLayerTestPicker',UIParent); ColorPickerFrame=picker
picker:SetWidth(360); picker:SetHeight(240); picker:SetScale(1.1)
picker:SetFrameStrata('DIALOG'); picker:SetFrameLevel(5)
function picker:GetNumPoints() return 1 end
function picker:GetPoint() return 'TOPLEFT',UIParent,'TOPLEFT',40,-60 end
function picker:SetColorRGB(r,g,b) self.rgb={r,g,b}; if self.func then self.func() end end
function picker:GetColorRGB() return unpack(self.rgb) end
picker.backdrop=CreateFrame('Frame',nil,picker); picker.backdrop:SetFrameStrata('DIALOG'); picker.backdrop:SetFrameLevel(4)
picker.backdrop_shadow=CreateFrame('Frame',nil,picker.backdrop)
picker.backdrop_shadow:SetFrameStrata('BACKGROUND'); picker.backdrop_shadow:SetFrameLevel(1)
local okay=CreateFrame('Button',nil,picker); okay:EnableMouse(true)
okay.backdrop=CreateFrame('Frame',nil,okay)
local cancel=CreateFrame('Button',nil,picker); cancel:EnableMouse(true)
local slider=CreateFrame('Slider',nil,picker)
local hidden=0; picker:SetScript('OnHide',function() hidden=hidden+1 end)
-- A skin may apply its own levels in OnShow, after Caw initially shows the root.
picker:SetScript('OnShow',function()
    okay:SetFrameStrata('LOW'); okay:SetFrameLevel(7)
    okay.backdrop:SetFrameStrata('LOW'); okay.backdrop:SetFrameLevel(6)
    cancel:SetFrameStrata('DIALOG'); cancel:SetFrameLevel(7)
    slider:SetFrameStrata('MEDIUM'); slider:SetFrameLevel(8)
end)
okay:SetScript('OnClick',function() picker:Hide() end)
cancel:SetScript('OnClick',function() picker.cancelFunc(picker.previousValues); picker:Hide() end)
local nodes={picker,picker.backdrop,picker.backdrop_shadow,okay,okay.backdrop,cancel,slider}
search('window background colour'); click(p.controls.windowColour.select)
for _,f in ipairs(nodes) do assert(f:GetFrameStrata()=='FULLSCREEN_DIALOG') end
check(true,'colour wheel, buttons, slider and pfUI backgrounds all sit above the settings dialog')
check(picker.backdrop_shadow:GetFrameLevel()<picker.backdrop:GetFrameLevel()
    and picker.backdrop:GetFrameLevel()<picker:GetFrameLevel()
    and okay:GetFrameLevel()>picker:GetFrameLevel() and cancel:GetFrameLevel()>picker:GetFrameLevel()
    and okay.backdrop:GetFrameLevel()<okay:GetFrameLevel(),
    'raising the popup keeps backgrounds behind its native interactive controls')
check(okay.mouseEnabled and cancel.mouseEnabled and okay:IsVisible() and cancel:IsVisible(),
    'Okay and Cancel remain visible input controls above the settings frame')
check(picker.lastPoint[1]=='CENTER' and picker.lastPoint[2]==p and picker:GetScale()<=p:GetEffectiveScale(),
    'picker opens centred over settings and fits its scale instead of using a stale screen position')
picker:SetColorRGB(0.2,0.3,0.4); click(okay)
check(D.uiSettings().windowColour[1]==0.2 and not picker:IsShown(),'Okay retains the colour and closes the picker')
check(picker:GetFrameStrata()=='DIALOG' and picker:GetFrameLevel()==5 and picker:GetScale()==1.1
    and picker.lastPoint[1]=='TOPLEFT' and picker.lastPoint[4]==40 and picker.lastPoint[5]==-60,
    'closing restores the shared picker position, scale and original layer')
check(okay:GetFrameStrata()=='LOW' and okay:GetFrameLevel()==7
    and picker.backdrop_shadow:GetFrameStrata()=='BACKGROUND' and not picker.cawOwner and not picker.cawPopupState,
    'child layers and Caw ownership are restored for other addons')
local before=hidden; click(p.controls.windowColour.select); picker:SetColorRGB(0.9,0.8,0.7); click(cancel)
check(D.uiSettings().windowColour[1]==0.2 and hidden==before+1,'Cancel restores the opening colour and retains the original OnHide handler')
-- The ordinary settings dropdowns must raise their whole tree as well.
p:SetFrameLevel(180); search('font'); click(p.controls.fontFace.select)
check(p.choiceMenu:GetParent()==p and p.choiceMenu:GetFrameStrata()=='DIALOG'
    and p.choiceMenu:GetFrameLevel()>p:GetFrameLevel(),
    'choice dropdown escapes scroll clipping and follows the current settings frame level')
for _,b in ipairs(p.choiceMenu.buttons) do
    assert(b:GetFrameStrata()=='DIALOG' and b:GetFrameLevel()>p.choiceMenu:GetFrameLevel())
end
check(true,'every choice entry remains above its menu background')
click(p.choiceMenu.buttons[2]); check(D.uiSettings().fontFace==2 and not p.choiceMenu:IsShown(),'raised dropdown entries still apply their choices')
click(p.controls.fontFace.select); click(p.target)
check(not p.choiceMenu:IsShown() and p.targetMenu:IsShown() and p.targetMenu:GetFrameLevel()>p:GetFrameLevel(),
    'window selection closes the previous dropdown and opens above settings')
for _,b in ipairs(p.targetMenu.buttons) do assert(b:GetFrameLevel()>p.targetMenu:GetFrameLevel()) end
click(p.targetMenu.buttons[1]); check(not p.targetMenu:IsShown() and p.view==nil,'window selector buttons remain functional above the menu')
search('window background colour'); click(p.controls.windowColour.select); click(p.target)
check(not picker:IsShown() and not picker.cawPopupState and p.targetMenu:IsShown(),
    'opening another menu closes and restores the shared colour picker')
click(p.controls.windowColour.select)
check(not p.targetMenu:IsShown() and picker:IsShown(),'opening the colour picker closes other settings popups')
p:Hide()
check(not picker:IsShown() and not picker.cawOwner and picker:GetFrameLevel()==5,'closing settings also closes and restores its colour picker')
local frameCount=table.getn(FRAMES)
for i=1,8 do D.openOptions(nil); click(p.controls.windowColour.select); click(okay); p:Hide() end
check(table.getn(FRAMES)==frameCount and picker:GetFrameLevel()==5,'reopening reuses frames and never accumulates level changes')
p:SetFrameLevel(80); ColorPickerFrame=nil; D.appearance=D.uiCopySettings(nil); D.uiRefresh(nil)
print('Settings popup checks: '..checks)

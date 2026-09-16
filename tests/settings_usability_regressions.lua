-- Exercise navigation and discovery through the same controls used in game.
local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS SETTINGS '..label) end
local function click(b) this=b; arg1='LeftButton'; b:GetScript('OnClick')() end
local function page(id)
    for _,b in ipairs(D.optionsPanel.tabs) do if b.page==id then click(b); return end end
    error('missing page '..id)
end
D.appearance=D.uiCopySettings(nil); D.openOptions(nil)
local p=D.optionsPanel; p.expandedGroups={}; D.refreshOptions()
local function search(text)
    p.search:SetText(text); this=p.search; p.search:GetScript('OnTextChanged')()
end
local function number(key,value)
    local input=p.controls[key].input; input:SetText(tostring(value)); this=input; input:GetScript('OnEnterPressed')()
end
local function toggle(key,value)
    local b=p.controls[key].check; b:SetChecked(value and 1 or nil); click(b)
end
check(table.getn(p.tabs)==8 and p.tabs[2].text:GetText()=='Player bars' and p.tabs[4].text:GetText()=='Top bar'
    and p.tabs[5].text:GetText()=='Bottom bar','navigation names identify the part of the meter being changed')
check(p.controls.windowColour.control[1]=='Window' and p.controls.barColour.control[1]=='Bars'
    and p.controls.headerColour.control[1]=='Header' and p.controls.footerColour.control[1]=='Footer',
    'each background colour is grouped with the element it changes')
page('Header')
check(p.groupHeaders['Header:Buttons']:IsShown() and not p.controls.showSettings:IsShown()
    and p.controls.headerHeight:IsShown(),'top-bar basics are visible while detailed button controls start collapsed')
click(p.groupHeaders['Header:Buttons'])
check(p.controls.showSettings:IsShown() and p.controls.buttonSide:IsShown(),'expanding Buttons exposes all button layout controls together')
click(p.groupHeaders['Header:Buttons'])
search('show settings')
check(p.controls.showSettings:IsShown() and not p.expandedGroups['Header:Buttons'],
    'search finds a setting inside a collapsed group without changing the group preference')
search('  HEADER height  ')
check(p.searchQuery=='header height' and p.controls.headerHeight:IsShown() and not p.controls.footerHeight:IsShown(),
    'search ignores case and surrounding spaces and matches all words across labels and familiar names')
local footer=D.uiSettings().footerHeight
number('headerHeight',32)
check(D.uiSettings().headerHeight==32 and D.mainView.modeButton:GetHeight()==26
    and D.uiSettings().footerHeight==footer and p.searchQuery=='header height',
    'editing a search result changes the correct live setting without losing the search')
search('color')
check(p.controls.windowColour:IsShown() and p.controls.footerColour:IsShown(),
    'both colour and color find the colour controls')
search('transparency')
check(p.controls.opacity:IsShown() and p.controls.barOpacity:IsShown() and p.controls.headerOpacity:IsShown(),
    'transparency also finds opacity settings')
search('no-such-setting-xyz')
local visible=0; for _,r in ipairs(p.controls) do if r:IsShown() then visible=visible+1 end end
check(p.noResults:IsShown() and visible==0 and not p.resetButton:IsShown() and not p.copyButton:IsShown(),
    'an empty search has a helpful message and no ambiguous reset or copy action')
click(p.searchClear)
check(p.searchQuery=='' and p.search:GetText()=='' and not p.noResults:IsShown() and p.heading:GetText()=='Top bar',
    'clearing search returns to the selected page')
search('font'); page('Bars')
check(p.searchQuery=='' and p.search:GetText()=='' and p.heading:GetText()=='Player bars',
    'choosing a category leaves search mode cleanly')
check(p.controls.barColour.disabledReason and not p.controls.barColour.select:IsEnabled(),
    'custom bar colour explains why it is unavailable with class colours enabled')
toggle('classBars',false)
check(not p.controls.barColour.disabledReason and p.controls.barColour.select:IsEnabled(),
    'turning off class colours enables the adjacent custom colour control')
page('Footer'); toggle('showFooter',false)
local previous=D.uiSettings().footerHeight; number('footerHeight',35)
check(D.uiSettings().footerHeight==previous and p.controls.footerHeight.disabledReason,
    'hidden-footer controls cannot change values while disabled')
toggle('showFooter',true); number('footerHeight',35)
check(D.uiSettings().footerHeight==35 and not p.controls.footerHeight.disabledReason,
    'showing the bottom bar makes its appearance controls usable again')
page('Header'); click(p.groupHeaders['Header:Buttons']); toggle('alwaysOverflow',true)
check(p.controls.showReport.disabledReason and not p.controls.showReport.check:IsEnabled()
    and p.controls.alwaysOverflow.check:IsEnabled(),
    'compact-menu mode disables individual buttons without disabling its own off switch')
toggle('alwaysOverflow',false)
check(p.controls.showReport.check:IsEnabled(),'leaving compact-menu mode restores individual-button settings')
page('Text'); toggle('textShadow',false)
check(p.controls.shadowColour.disabledReason and not p.controls.shadowColour.select:IsEnabled(),
    'shadow colour is only editable while shadows are enabled')
-- Navigation and search must neither change appearance nor create endless frames.
local snapshot=D.uiCopySettings(D.uiSettings())
for _,q in ipairs({'window','bars','text','header','footer','sync','threat','bags'}) do search(q) end
local count=table.getn(FRAMES)
for i=1,10 do for _,q in ipairs({'window','text','sync','bags'}) do search(q) end end
check(table.getn(FRAMES)==count and D.uiSettings().footerHeight==snapshot.footerHeight
    and D.uiSettings().headerHeight==snapshot.headerHeight,'repeated searches reuse their UI and preserve saved appearance')
page('Text'); D.uiSettings().rowGap=9; click(p.resetButton)
check(D.uiSettings().textShadow and D.uiSettings().rowGap==9 and D.uiSettings().footerHeight==35,
    'Reset page restores only settings owned by that page')
page('General'); D.setParserEnabled(false); D.setCombatSyncEnabled(false); click(p.resetButton)
check(D.parserEnabled() and CawDPSMeterCharDB.combatSyncEnabled~=false and D.uiSettings().rowGap==9,
    'resetting Combat and sync restores recording preferences without resetting window appearance')
page('Window'); number('rows',3); number('width',650); click(p.resetButton)
check(D.window:GetWidth()==440 and D.uiVisibleRows(nil,D.window)==5 and D.uiSettings().rowGap==9,
    'resetting Window restores its size using the existing player-bar settings')
D.appearance=D.uiCopySettings(nil); D.uiRefresh(nil); p:Hide()
print('Settings usability checks: '..checks)

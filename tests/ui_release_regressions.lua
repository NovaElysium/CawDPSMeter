-- Release acceptance: exercise visible menu callbacks across independent windows.
local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS RELEASE UI '..label) end
local function click(f) this=f; arg1='LeftButton'; f:GetScript('OnClick')() end
local function item(menu,key,value,index)
    if menu.up then for i=1,16 do click(menu.up) end end
    for page=1,16 do
        for _,b in ipairs(menu.buttons) do
            if b:IsShown() and b[key]==value and (not index or b.historyIndex==index) then return b end
        end
        if not menu.down then break end
        click(menu.down)
    end
    error('Unreachable menu item: '..tostring(value)..' '..tostring(index))
end
local extra=D.multiWindows[2] or D.createMultiWindow(nil)
local modes={'damage','healing','threat','damageTaken','deaths','interrupts','cc','ccBreaks','dispels','buffs','debuffsCast','debuffsReceived'}
for i=1,10 do D.fightHistory[i]={name='Encounter '..i,duration=10,actors={}} end
D.window:Show(); extra.frame:Show()
for _,width in ipairs({160,300,450}) do
    for _,view in ipairs({D.mainView,extra}) do
        view.frame:SetWidth(width)
        if view.id==1 then D.applyCompactWindowLayout() else D.layoutMultiWindow(view) end
        local state=view.id==1 and D or view
        local other=view.id==1 and extra or D
        local unchangedMode,unchangedSegment=other.mode,other.segment
        for _,mode in ipairs(modes) do
            D.uiCloseMeterMenus(view); click(view.modeButton)
            click(item(view.modeMenu,'mode',mode))
            assert(state.mode==mode and not view.modeMenu:IsShown() and other.mode==unchangedMode)
        end
        check(true,'all twelve mode selections stay in window '..view.id..' at width '..width)
        for _,segment in ipairs({'current','history','overall'}) do
            local count=segment=='history' and 10 or 1
            for index=1,count do
                D.uiCloseMeterMenus(view); click(view.segmentButton)
                click(item(view.segmentMenu,'kind',segment,segment=='history' and index or nil))
                assert(state.segment==segment and (segment~='history' or state.segmentIndex==index))
                assert(not view.segmentMenu:IsShown() and other.segment==unchangedSegment)
            end
        end
        check(true,'Current, Overall and all ten encounters are reachable in window '..view.id..' at width '..width)
    end
end
D.openOptions(extra)
local options=D.optionsPanel
click(options.target); assert(options.targetMenu:IsShown())
options:Hide(); D.openOptions(nil)
check(not options.targetMenu:IsShown() and options.view==nil,'reopening Settings clears its window dropdown and old selection')
options:Hide()
local a={key='release-player',guid='release-player',name='Release player',classToken='MAGE',damage=12,spells={Bolt={damage=12,hits=1}}}
D.fightHistory[1].actors[a.key]=a
D.openBreakdown(a,{segment='history',segmentIndex=1,mode='damage'})
local panel=D.breakdownPanel
click(panel.modeButton); panel:Hide()
D.openBreakdown(a,{segment='history',segmentIndex=1,mode='damage'})
check(not panel.modeMenu:IsShown() and panel.context and panel.total==12,'reopening player details clears dropdowns and restores its data')
panel:Hide()
-- Fill every slot through the compact menu, then close and reopen a pooled view.
D.window:SetWidth(190); D.applyCompactWindowLayout()
for i=2,D.multiWindowMax do
    if not D.multiWindows[i] then
        D.uiCloseMeterMenus(D.mainView); click(D.mainView.overflowButton); click(D.mainView.overflowMenu.buttons[2])
        assert(D.multiWindows[i] and not D.multiWindows[i].closed)
    end
end
D.uiCloseMeterMenus(D.mainView); click(D.mainView.overflowButton)
local frameCount=#FRAMES
check(not D.mainView.overflowMenu.buttons[2]:IsEnabled() and D.createMultiWindow(nil)==nil and #FRAMES==frameCount,
    'full capacity disables New window without allocating more frames')
local last=D.multiWindows[D.multiWindowMax]
last.frame:SetWidth(190); D.layoutMultiWindow(last)
click(last.overflowButton); click(last.overflowMenu.buttons[6])
check(last.closed and not last.frame:IsShown() and not last.overflowMenu:IsShown() and not D.multiWindows[last.id],
    'compact Close removes only its extra window and closes its menus')
D.uiCloseMeterMenus(D.mainView); click(D.mainView.overflowButton)
assert(D.mainView.overflowMenu.buttons[2]:IsEnabled()); click(D.mainView.overflowMenu.buttons[2])
check(D.multiWindows[last.id]==last and not last.closed and not last.overflowMenu:IsShown() and #FRAMES==frameCount,
    'New window reuses the closed frame without stale menus or new allocations')
D.uiCloseMeterMenus(D.mainView); click(D.mainView.overflowButton); click(D.mainView.overflowMenu.buttons[6])
D.window:Show()
check(not D.mainView.overflowMenu:IsShown() and D.multiWindows[last.id]==last,'main Close and Show preserve additional windows')
-- A freshly created menu must remain above docked rows after restyling.
pfUI={chat={right=CreateFrame('Frame',nil,UIParent)}}
pfUI.chat.right:SetWidth(380); pfUI.chat.right:SetHeight(180)
D.pfDockToggle(nil); D.pfDockToggle(extra)
for _,view in ipairs({D.mainView,extra}) do
    D.uiStyleView(view); D.uiCloseMeterMenus(view); click(view.segmentButton)
    assert(view.segmentMenu:GetFrameStrata()=='DIALOG' and view.segmentMenu.buttons[1]:GetFrameStrata()=='DIALOG')
    assert(view.footerRegions.summary:GetFrameLevel()>view.frame:GetFrameLevel())
end
check(true,'restyling docked windows keeps dropdowns above player bars and the footer interactive')
D.pfDockToggle(extra); D.pfDockToggle(nil); pfUI=nil
-- Full recorded numbers must survive display abbreviation in both meter types.
a.damage=12501234; a.healing=12501234; a.damageTaken=12501234
D.fightHistory[1].duration=10
for _,mode in ipairs({'damage','healing','damageTaken'}) do
    D.mode=mode; D.segment='history'; D.segmentIndex=1
    extra.mode=mode; extra.segment='history'; extra.segmentIndex=1
    for _,width in ipairs({160,190,300,450,900}) do
        D.window:SetWidth(width); extra.frame:SetWidth(width); D.uiRefreshMeters()
        for _,view in ipairs({D.mainView,extra}) do
            assert(string.find(view.footerText,'12,501,234',1,true))
            if mode~='damageTaken' then assert(string.find(view.footerText,'1250123.4',1,true)) end
            assert(view.summary:GetStringWidth()<=view.summary:GetWidth())
            assert(string.find(view.summary:GetText(),'M',1,true))
        end
    end
    check(true,'million-scale '..mode..' fits every footer width and retains complete tooltip numbers')
end
extra.mode='threat'; extra.summary:SetText('Threat | Enemy 12501234'); D.uiUpdateMeterFooter(extra)
check(extra.summary:GetText()=='Threat | Enemy 12501234','number shortening does not change Threat target names')
print('Release UI checks: '..checks)

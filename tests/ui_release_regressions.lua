-- Release acceptance: exercise visible menu callbacks across independent windows.
local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS RELEASE UI '..label) end
local function click(f) this=f; arg1='LeftButton'; f:GetScript('OnClick')() end
local function menusAboveRows(view,strata)
    local highest=view.footerRegions.summary:GetFrameLevel()
    for _,row in ipairs(view.id==1 and D.rows or view.rows) do
        highest=math.max(highest,row.frame:GetFrameLevel(),row.bar:GetFrameLevel())
    end
    for _,key in ipairs({'modeMenu','segmentMenu','reportMenu','overflowMenu'}) do
        local menu=view[key]
        if menu then
            D.uiCloseMeterMenus(view); menu:Show()
            assert(menu:GetFrameStrata()==strata and menu:GetFrameLevel()>highest,
                key..' must cover player bars and footer in window '..view.id)
            for _,b in ipairs(menu.buttons or {}) do
                assert(b:GetFrameStrata()==strata and b:GetFrameLevel()>menu:GetFrameLevel(),
                    key..' entries must remain above their menu background')
            end
        end
    end
    D.uiCloseMeterMenus(view)
end
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
    assert(view.segmentMenu:GetFrameStrata()=='MEDIUM' and view.segmentMenu.buttons[1]:GetFrameStrata()=='MEDIUM')
    assert(view.footerRegions.summary:GetFrameLevel()>view.frame:GetFrameLevel())
end
check(true,'restyling docked windows keeps dropdowns above player bars and the footer interactive')
D.pfDockToggle(extra); D.pfDockToggle(nil); pfUI=nil
-- Bagshui inventory windows are MEDIUM-strata. A visible bag must cover a
-- free Caw window as well as a docked one, and closing it restores the normal
-- foreground hierarchy.
local bagFrame=CreateFrame('Frame',nil,UIParent)
Bagshui={components={Bags={uiFrame=bagFrame}}}
bagFrame:Show(); D.pfBagLayerTick()
assert(D.window:GetFrameStrata()=='BACKGROUND' and extra.frame:GetFrameStrata()=='BACKGROUND')
menusAboveRows(D.mainView,'BACKGROUND'); menusAboveRows(extra,'BACKGROUND')
check(true,'all free-meter dropdowns cover player bars while remaining behind Bagshui')
D.uiCloseMeterMenus(D.mainView); click(D.mainView.segmentButton)
assert(D.mainView.segmentMenu:GetFrameStrata()=='BACKGROUND' and D.mainView.segmentMenu.buttons[1]:GetFrameStrata()=='BACKGROUND')
pfUI={chat={right=CreateFrame('Frame',nil,UIParent)}}
D.pfDockToggle(nil); D.pfDockToggle(nil); D.pfBagLayerTick()
assert(D.window:GetFrameStrata()=='BACKGROUND','undocking while Bagshui is open keeps the free meter behind the bag')
pfUI=nil
bagFrame:Hide(); D.pfBagLayerTick()
check(D.window:GetFrameStrata()=='HIGH' and extra.frame:GetFrameStrata()=='HIGH',
    'Bagshui visibility moves free meters behind the bag and restores them afterward')
Bagshui=nil
-- Other bag addons do not expose a shared frame API on this client.  The
-- optional character setting provides a deterministic fallback for them.
CawDPSMeterCharDB.bagLayerAlwaysBehind=true; D.pfBagLayerTick()
assert(D.window:GetFrameStrata()=='BACKGROUND' and extra.frame:GetFrameStrata()=='BACKGROUND')
menusAboveRows(D.mainView,'BACKGROUND'); menusAboveRows(extra,'BACKGROUND')
check(true,'all dropdowns cover bars with the inventory fallback enabled')
extra.rebuildSegments()
table.insert(D.fightHistory,{name='Newly finished encounter',duration=5,actors={}})
D.uiCloseMeterMenus(extra); click(extra.segmentButton)
local lastEntry=extra.segmentMenu.buttons[math.min(12,table.getn(D.fightHistory)+2)]
check(lastEntry:IsShown() and lastEntry:GetFrameStrata()=='BACKGROUND'
    and lastEntry:GetFrameLevel()>extra.segmentMenu:GetFrameLevel(),
    'encounter entries keep the correct layer after history changes')
table.remove(D.fightHistory)
-- Steady docking polls must not tear down and rebuild the entire free meter's
-- hierarchy, especially HIGH -> BACKGROUND twice per tick with the bag option.
D.pfDockUpdate(); D.pfBagLayerTick()
local tree,layerCalls=D.pfDockLayerTree,0
D.pfDockLayerTree=function(f,level,strata,docked,behind)
    layerCalls=layerCalls+1; return tree(f,level,strata,docked,behind)
end
for i=1,8 do D.pfDockUpdate(); D.pfBagLayerTick() end
D.pfDockLayerTree=tree
check(layerCalls==0,'unchanged free windows need no layer rebuilds across eight docking polls (observed '..layerCalls..')')
menusAboveRows(D.mainView,'BACKGROUND'); menusAboveRows(extra,'BACKGROUND')
CawDPSMeterCharDB.bagLayerAlwaysBehind=false; D.pfBagLayerTick()
check(D.window:GetFrameStrata()=='HIGH' and extra.frame:GetFrameStrata()=='HIGH',
    'optional inventory layering fallback works without Bagshui and restores normal strata')
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

local D=CAW_DPS_METER
local checks=0
local function check(v,label) assert(v,label); checks=checks+1; print("PASS UI "..label) end
local function click(f,button) this=f; arg1=button or "LeftButton"; f.scripts.OnClick() end
local function byLabel(parent,label)
    for _,f in ipairs(FRAMES) do if f.parent==parent and f.kind=="Button" and f.text and type(f.text)=="table" and f.text:GetText()==label then return f end end
    error("button not found: "..label)
end
D.appearance=D.uiCopySettings(nil)
local v=D.multiWindows[2] or D.createMultiWindow(nil)
v.appearance=D.uiCopySettings(nil); v.frame:Show()
D.window:SetWidth(360); D.window:SetHeight(D.uiHeightForRows(nil,5)); D.applyCompactWindowLayout()
check(D.uiVisibleRows(nil,D.window)==5 and D.window:GetHeight()==178,"default height fits five full bars and reserves footer")
for _,gap in ipairs({0,3,10}) do
    for _,height in ipairs({14,23,36}) do
        v.appearance.rowGap=gap; v.appearance.rowHeight=height
        v.frame:SetHeight(D.uiHeightForRows(v,5)); D.layoutMultiWindow(v)
        check(D.uiVisibleRows(v,v.frame)==5 and v.rows[5].frame.lastPoint[5]-height>-(v.frame:GetHeight()-16),"five-row fit with height "..height.." gap "..gap)
    end
end
v.appearance=D.uiCopySettings(nil)
D.uiSelectMain("overall",0); v.segment="overall"; D.uiSettings(v).autoCurrent=false
NOW=NOW+10; fire(D.events,"PLAYER_REGEN_DISABLED")
check(D.segment=="overall" and v.segment=="overall","combat event preserves Overall in every window by default")
D.uiSettings(v).autoCurrent=true; D.uiCombatSelection()
check(D.segment=="overall" and v.segment=="current","automatic Current selection is a per-window opt-in")
D.uiSettings().autoCurrent=true; D.uiCombatSelection(); D.uiSettings().autoCurrent=false
check(D.segment=="current" and CawDPSMeterDB.segment=="current","explicit auto Current persists primary selection")
D.openOptions(v)
local options=D.optionsPanel
check(options:IsShown() and options.view==v,"settings opens for the clicked window")
local function slide(control,value)
    this=control.slider; this:SetValue(value); this.scripts.OnValueChanged()
end
local scaleRow=options.controls.scale; slide(scaleRow,1.05)
check(math.abs(v.frame:GetScale()-1.05)<0.001 and D.window:GetScale()==1,"scale control changes only the selected window")
check(CawDPSMeterCharDB.extraWindows[1].appearance.scale==v.appearance.scale,"extra window appearance is persisted")
click(byLabel(options,"Bars"))
local heightRow=options.controls.rowHeight; slide(heightRow,24)
check(v.rows[1].frame:GetHeight()==24 and D.rows[1].frame:GetHeight()==23,"bar height changes immediately without changing primary")
local checkbox=options.controls.percent.check
click(byLabel(options,"Text"))
this=checkbox; checkbox:SetChecked(1); checkbox.scripts.OnClick()
check(v.appearance.percent and not D.uiSettings().percent,"checkbox updates only the selected window")
local input=options.controls.scale.input
click(byLabel(options,"Window"))
this=input; input:SetText('115'); input.scripts.OnEnterPressed()
check(math.abs(v.appearance.scale-1.15)<0.001,"numeric scale input converts a displayed percentage")
this=input; input:SetText('invalid'); input.scripts.OnEnterPressed()
check(math.abs(v.appearance.scale-1.15)<0.001 and input:GetText()=='115',"invalid input restores the current setting")
click(options.target); click(options.targetMenu.buttons[1])
check(options.view==nil and not options.targetMenu:IsShown(),"window selector chooses the exact frame stored on its menu item")
click(options.target); click(options.targetMenu.buttons[v.id])
check(options.view==v,"window selector can return to an additional meter")
local slider=options.controls.rowGap.slider; local savedSet=slider.SetValue; local callbackCount=0
slider.SetValue=function(self,value)
    savedSet(self,value); local previous=this; this=self; callbackCount=callbackCount+1
    self.scripts.OnValueChanged(); this=previous
end
options.page='Bars'; D.refreshOptions(); slider.SetValue=savedSet
check(callbackCount==1,"refresh safely handles native sliders firing OnValueChanged during SetValue")
local safe=D.uiCopySettings({scale=99,rowHeight=-3,rowGap=0,fontSize='bad',icons=false})
check(safe.scale==1.6 and safe.rowHeight==14 and safe.rowGap==0 and safe.fontSize==11 and not safe.icons,"invalid appearance values clamp and explicit false survives")
local function actor(key,name,damage,spells,pet,owner)
    return {key=key,guid=key,name=name,damage=damage,healing=0,spells=spells,healSpells={},isPet=pet,ownerKey=owner,classToken=pet and nil or "HUNTER"}
end
local hunter=actor('UI-A','Archer',100,{Shot={damage=100,hits=2,crits=1}})
local pet=actor('UI-P','Wolf',25,{Bite={damage=25,hits=1,crits=0}},true,'UI-A')
local stranger=actor('UI-B','Other',500,{Bolt={damage=500,hits=1,crits=1}})
local historic={name='Old enemy',duration=10,actors={['UI-A']=hunter,['UI-P']=pet,['UI-B']=stranger}}
D.fightHistory={historic}; D.segment='history'; D.segmentIndex=1; D.mode='damage'
local c=D.breakdownContext(nil)
local entries,total,a=D.breakdownEntries(c,'UI-A')
check(total==125 and #entries==2 and entries[2].source=='Wolf' and entries[2].isPet,"breakdown totals include only owned pet spells with their source")
check(entries[1].hits==2 and entries[1].crits==1 and entries[1].critDamage==nil,"breakdown uses recorded hit and crit counts without inventing crit damage")
hunter.damage=300
local _,partialTotal=D.breakdownEntries(c,'UI-A')
check(partialTotal==325,"incomplete spell data does not replace a more complete synced actor total")
hunter.damage=100
D.openBreakdown(hunter,nil)
local p=D.breakdownPanel
check(p:IsShown() and p.total==125 and p.context.history==historic,"bar analysis opens with the selected actor and segment")
D.rows[1].actor=hunter; D.rows[2].actor=stranger
this=D.rows[1].bar; arg1='LeftButton'; this.scripts.OnMouseUp()
check(p.actorKey=='UI-A',"left-click on a bound player bar selects that row's actor")
this=D.rows[2].bar; arg1='LeftButton'; this.scripts.OnMouseUp()
check(p.actorKey=='UI-B',"another bar does not reuse the first or last loop actor")
local function captures(fn,name)
    for i=1,100 do local n=debug.getupvalue(fn,i); if not n then break end; if n==name then return true end end
    return false
end
check(not captures(D.rows[1].bar.scripts.OnMouseUp,'row') and not captures(D.rows[1].bar.scripts.OnEnter,'row'),"bar callbacks do not capture Vanilla's shared loop variable")
local hovered=nil; local original=D.rows[1].bar.cawOriginalEnter
D.rows[1].bar.cawOriginalEnter=function() hovered=this.cawViewRow.actor end
this=D.rows[1].bar; this.scripts.OnEnter()
check(hovered==hunter,"hover uses the current row stored on the bar")
D.uiSettings().hover=false; hovered=nil; this.scripts.OnEnter()
check(hovered==nil,"disabled tooltips do not call the original hover handler")
D.uiSettings().hover=true; D.rows[1].bar.cawOriginalEnter=original
this=v.rows[1].bar; arg1='RightButton'; this.scripts.OnMouseUp()
check(D.optionsPanel.view==v,"right-click on an extra bar opens settings for that window")
this={}; arg1='LeftButton'; D.rows[1].bar.scripts.OnMouseUp(); D.rows[1].bar.scripts.OnEnter()
check(true,"unbound hover and click events safely return")
D.openBreakdown(hunter,nil)
click(p.spells[2])
check(p.spellId==entries[2].id and p.metrics[1]:GetText()==D.uiNumber(25),"clicking a spell refreshes its own detailed statistics")
p.searchBox:SetText('bite'); this=p.searchBox; p.searchBox.scripts.OnTextChanged()
check(#p.entries==1 and p.entries[1].name=='Bite' and p.total==125,"ability search preserves actor total and contribution percentages")
p.searchBox:SetText(''); this=p.searchBox; p.searchBox.scripts.OnTextChanged()
table.insert(D.fightHistory,1,{name='New enemy',duration=20,actors={}})
D.refreshBreakdown()
check(p.total==125 and p.context.history==historic,"new history entries cannot silently switch an open analysis to another fight")
local oldMode,oldSegment=D.mode,D.segment
v.mode='healing'; v.segment='history'; v.segmentIndex=2
D.openBreakdown(hunter,v)
check(p.context.mode=='healing' and D.mode==oldMode and D.segment==oldSegment,"extra-window analysis never changes the primary view context")
for _,mode in ipairs({'damage','healing','damageTaken','threat','deaths','interrupts','cc','ccBreaks','dispels','buffs','debuffsCast','debuffsReceived'}) do
    p.context.mode=mode; D.refreshBreakdown()
end
check(true,"all twelve breakdown modes render with missing optional statistics")
D.openBreakdown(hunter,{segment='history',segmentIndex=2,mode='damage'})
check(p.metrics[3]:IsShown() and not p.metrics[8]:IsShown() and not p.metrics[10]:IsShown(),"spell details show only statistics that belong to the selected mode")
local srv=D.serverThreatActors
D.serverThreatActors=function() return {{key='server:1',name='Other',guid='UI-B',_serverThreatValue=999},{key='server:2',name='Archer',guid='UI-A',_serverThreatValue=222}} end
local serverContext={segment='current',mode='threat',serial=D.segmentSerial}
local _,serverTotal=D.breakdownEntries(serverContext,'UI-A')
check(serverTotal==222,"server analysis selects actor identity rather than changing rank keys")
D.serverThreatActors=srv
D.uiSettings(v).scale=1; D.layoutMultiWindow(v)
D.openOptions(nil); click(D.mainView.resetButton)
check(D.resetDialog:IsShown() and D.resetDialog.kind=='current',"header reset action opens an explicit confirmation")
local before=D.actors; click(byLabel(D.resetDialog,"Cancel"))
check(D.actors==before,"cancelling reset leaves data untouched")
D.uiSettings(v).rowHeight=31; D.uiPersist()
local save=CawDPSMeterCharDB.extraWindows[1]
D.removeMultiWindow(v); local restored=D.createMultiWindow(save)
check(restored.appearance.rowHeight==31 and restored.rows[1].frame:GetHeight()==31,"pooled window restores its saved appearance")
local n=#FRAMES
D.openOptions(nil); D.openOptions(restored); D.openBreakdown(hunter,{segment='history',segmentIndex=2,mode='damage'})
check(#FRAMES==n,"settings and analysis frames are reused")
local f=CreateFrame('Frame',nil,UIParent); f:SetScale(1.4)
f.GetCenter=function() return 600/1.4,450/1.4 end
local x,y=D.uiCenterOffset(f)
D.uiAnchorCenter(f,x,y)
check(math.abs(x-100)<0.001 and math.abs(y-50)<0.001 and math.abs(f.lastPoint[4]-100/1.4)<0.001,"scaled placement round-trips through UIParent coordinates")
for _,width in ipairs({160,190,380,600}) do
    D.window:SetWidth(width); restored.frame:SetWidth(width)
    D.applyCompactWindowLayout(); D.layoutMultiWindow(restored)
    D.mainView.segmentMenu:Hide(); restored.segmentMenu:Hide()
    click(D.mainView.segmentButton); click(restored.segmentButton)
    local main,extra=D.mainView.segmentMenu,restored.segmentMenu
    check(main:GetWidth()==D.mainView.segmentButton:GetWidth() and extra:GetWidth()==restored.segmentButton:GetWidth()
        and main.buttons[1].text:GetWidth()<main:GetWidth() and extra.buttons[1].text:GetWidth()<extra:GetWidth(),
        "opened encounter lists and their labels fit both selectors at width "..width)
end
D.window:SetWidth(190); restored.frame:SetWidth(190)
D.applyCompactWindowLayout(); D.layoutMultiWindow(restored)
check(D.mainView.overflowButton:IsShown() and restored.overflowButton:IsShown() and D.mainView.segmentButton:GetWidth()>=80 and restored.segmentButton:GetWidth()>=80,
    "narrow windows keep a usable encounter selector and expose actions through overflow")
for _,view in ipairs({D.mainView,restored}) do
    click(view.overflowButton); click(view.overflowMenu.buttons[3])
    check(view.reportMenu:IsShown() and not view.overflowMenu:IsShown(),"overflow opens the report menu for window "..view.id)
    view.reportMenu:Hide(); click(view.overflowButton); click(view.overflowMenu.buttons[4])
    check(D.resetDialog:IsShown(),"overflow retains reset confirmation for window "..view.id)
    click(D.resetDialog.cancelButton or byLabel(D.resetDialog,'Cancel'))
    click(view.overflowButton); click(view.overflowMenu.buttons[1])
    check(D.optionsPanel.view==(view.id~=1 and view or nil),"overflow opens the settings for window "..view.id)
    D.optionsPanel:Hide()
    D.uiSetLock(view.id~=1 and view or nil,false)
    click(view.overflowButton); click(view.overflowMenu.buttons[5]); click(view.overflowButton)
    check(view.overflowMenu.buttons[5].text:GetText()=='Unlock',"overflow reflects the changed lock state in window "..view.id)
    click(view.overflowMenu.buttons[5])
    view.frame:SetWidth(450); D.layoutMeterHeader(view); D.uiStyleView(view)
    check(not view.overflowButton:IsShown() and view.reportButton:IsShown() and view.resetButton:IsShown() and not view.overflowMenu:IsShown(),"widening restores the full toolbar and closes overflow in window "..view.id)
    view.frame:SetWidth(190); D.layoutMeterHeader(view); D.uiStyleView(view)
end
local melee=actor('UI-M','Fighter',42,{Melee={damage=42,hits=1,crits=0}})
D.fightHistory[1].actors['UI-M']=melee
D.openBreakdown(melee,{segment='history',segmentIndex=1,mode='damage'})
check(p.spells[1].icon.texture=='Interface\\Icons\\INV_Sword_04' and p.spellIcon.texture==p.spells[1].icon.texture,
    "Melee uses the sword icon in the spell list and selected-spell details without a spellbook entry")
for _,view in ipairs({D.mainView,restored}) do
    D.uiCloseMeterMenus(view)
    click(view.modeButton); click(view.segmentButton)
    check(view.segmentMenu:IsShown() and not view.modeMenu:IsShown(),"opening an encounter dropdown closes the mode dropdown in window "..view.id)
    click(view.reportButton)
    check(view.reportMenu:IsShown() and not view.segmentMenu:IsShown(),"opening report closes the encounter dropdown in window "..view.id)
    click(view.modeButton)
    check(view.modeMenu:IsShown() and not view.reportMenu:IsShown(),"opening mode closes the report dropdown in window "..view.id)
    view.frame:Show(); view.frame:Hide(); view.frame:Show()
    check(not view.modeMenu:IsShown() and not view.segmentMenu:IsShown() and not view.reportMenu:IsShown(),"hiding and restoring a meter does not revive old dropdowns in window "..view.id)
    click(view.segmentButton)
    local item=view.segmentMenu.buttons[1]
    this=item; item.scripts.OnEnter(); item.scripts.OnLeave()
    check(item.backdrop.bgFile=='Interface\\Buttons\\WHITE8X8' and item.backdropColor[1]~=0.08,
        "legacy hover handlers do not restore the old menu skin in window "..view.id)
end
click(D.mainView.reportButton); D.openOptions(nil)
check(not D.mainView.reportMenu:IsShown(),"opening Settings closes the meter dropdown")
D.uiSetLock(nil,true); D.applyCompactWindowLayout()
this=D.mainView.lockButton; this.scripts.OnEnter(); this.scripts.OnLeave()
check(this.selected and this.backdropColor[1]==0.14,"locked button keeps the dark gold selection after hover")
D.uiSetLock(nil,false); D.applyCompactWindowLayout()
check(not D.mainView.lockButton.selected,"unlocking clears the themed lock selection")
local opacity=D.uiSettings().opacity; D.uiSettings().opacity=0.37; D.applyCompactWindowLayout()
check(D.window.backdrop.bgFile=='Interface\\Buttons\\WHITE8X8' and D.window.backdropColor[4]==0.37,
    "the solid meter background preserves the user's opacity setting")
D.uiSettings().opacity=opacity; D.applyCompactWindowLayout()
local beforeFrames=#FRAMES; local handler=D.mainView.reportButton.scripts.OnEnter
for i=1,10 do D.applyCompactWindowLayout(); D.layoutMultiWindow(restored) end
check(#FRAMES==beforeFrames and D.mainView.reportButton.scripts.OnEnter==handler,"repeated layout creates no theme textures or duplicate mouse wrappers")
-- Whisper reports freeze context and never infer a recipient from an NPC.
local originalSend,originalPlayer,originalTarget=SendChatMessage,UnitIsPlayer,UNITS.target
local sent={}
SendChatMessage=function(text,channel,language,target) table.insert(sent,{text=text,channel=channel,language=language,target=target}) end
UnitIsPlayer=function(unit) return UNITS[unit] and UNITS[unit].class~=nil end
UNITS.target={guid='0xCA',name='Receiver',class='MAGE'}
D.mode='damage'; D.segment='history'; D.segmentIndex=1
local expected=D.buildReportLines(nil)
click(D.mainView.reportMenu.buttons[5])
local whisper=D.whisperDialog
check(whisper:IsShown() and whisper.recipient:GetText()=='Receiver' and #sent==0,"Whisper menu opens a recipient dialog without sending")
UNITS.target={guid='0xCB',name='ChangedTarget',class='DRUID'}
D.mode='healing'; click(whisper.sendButton)
check(#sent==#expected and sent[1].text==expected[1] and sent[#sent].text==expected[#expected],"Whisper sends the frozen mode, fight and total despite a later view change")
for _,line in ipairs(sent) do assert(line.channel=='WHISPER' and line.target=='Receiver' and line.language==nil) end
check(not whisper:IsShown() and whisper.reportLines==nil,"all report lines use the original recipient and successful send clears the draft")
sent={}; D.mode='damage'; UNITS.target=originalTarget
click(D.mainView.reportMenu.buttons[5]); click(whisper.targetButton); click(whisper.sendButton)
check(#sent==0 and whisper.recipient:GetText()=='' and whisper:IsShown(),"an NPC target and empty name cannot receive a report")
whisper.recipient:SetText('Wrong name'); click(whisper.sendButton)
check(#sent==0 and whisper.error:GetText()~='',"invalid recipient stays in the dialog without sending")
whisper.recipient:SetText('  Manualname  '); click(whisper.sendButton)
check(#sent==#expected and sent[1].target=='Manualname',"manual recipient is trimmed and used for every report line")
sent={}; D.openWhisperReport(nil); click(whisper.cancelButton)
check(#sent==0 and not whisper:IsShown(),"cancelling Whisper sends nothing")
D.openWhisperReport(nil); this=whisper.recipient; this.scripts.OnEscapePressed()
check(#sent==0 and not whisper:IsShown(),"Escape cancels the recipient dialog")
restored.mode='damage'; restored.segment='history'; restored.segmentIndex=2
local mainMode=D.mode; D.mode='healing'
local extraExpected=D.buildReportLines(restored)
click(restored.reportMenu.buttons[5]); whisper.recipient:SetText('Another'); click(whisper.sendButton)
check(sent[1].text==extraExpected[1] and D.mode=='healing',"extra-window Whisper retains its own fight and mode without changing the main window")
D.mode=mainMode; sent={}; D.sendReportLines(expected,'SAY','Ignored')
check(#sent==#expected and sent[1].channel=='SAY' and sent[1].target==nil,"normal report channels do not inherit a Whisper recipient")
local attempts=0; SendChatMessage=function() attempts=attempts+1; error('mock transport failure') end
check(not D.sendReportLines(expected,'WHISPER','Receiver') and attempts==1,"failed report stops immediately and returns failure")
SendChatMessage=originalSend; UnitIsPlayer=originalPlayer; UNITS.target=originalTarget
-- Arrow state follows real list overflow, selection/search and shrinking data.
local many={}; local manySpells={}
for i=1,18 do manySpells['Spell '..i]={damage=i,hits=1,crits=0} end
for i=1,10 do local a=actor('many'..i,'Player '..i,171,manySpells); many[a.guid]=a end
D.fightHistory={}
for i=1,10 do D.fightHistory[i]={name='Fight '..i,duration=20,actors=many} end
D.openBreakdown(many.many1,{mode='damage',segment='history',segmentIndex=1})
check(not p.playerUp:IsEnabled() and p.playerDown:IsEnabled() and not p.segmentUp:IsEnabled() and p.segmentDown:IsEnabled() and not p.spellUp:IsEnabled() and p.spellDown:IsEnabled(),"only arrows with offscreen list entries are enabled")
click(p.playerDown); click(p.segmentDown); click(p.spellDown)
check(p.playerOffset==1 and p.segmentOffset==1 and p.spellOffset==1 and p.playerUp:IsEnabled() and p.segmentUp:IsEnabled() and p.spellUp:IsEnabled(),"each down arrow scrolls its own list and enables the return arrow")
for i=1,30 do click(p.playerDown); click(p.segmentDown); click(p.spellDown) end
check(p.playerOffset==3 and p.segmentOffset==6 and p.spellOffset==4 and not p.playerDown:IsEnabled() and not p.segmentDown:IsEnabled() and not p.spellDown:IsEnabled(),"scroll offsets stop at the bottom and disable forward arrows")
p.searchBox:SetText('Spell 18'); this=p.searchBox; this.scripts.OnTextChanged()
check(p.spellOffset==0 and #p.entries==1 and not p.spellUp:IsEnabled() and not p.spellDown:IsEnabled(),"a short search result resets scrolling and disables both spell arrows")
-- Talent trees use the client's actual slots, not a static class approximation.
local originalTabs,originalTab,originalCount,originalTalent=GetNumTalentTabs,GetTalentTabInfo,GetNumTalents,GetTalentInfo
GetNumTalentTabs=function() return 3 end
GetTalentTabInfo=function(tab) return ({'Beast Mastery','Marksmanship','Survival'})[tab] end
GetNumTalents=function() return 2 end
GetTalentInfo=function(tab,i) return 'Talent '..tab..'-'..i,'Interface\\Icons\\Ability_Hunter_BeastTaming',i,i,i,3 end
local own=actor(UNITS.player.guid,UNITS.player.name,1,{Melee={damage=1,hits=1}})
D.fightHistory[1].actors[own.guid]=own
D.openBreakdown(own,{mode='damage',segment='history',segmentIndex=1}); click(p.talentButton)
check(p.talentPane:IsShown() and not p.searchBox:IsShown() and p.talentPane.trees[1].title:GetText()=='Beast Mastery',"Talents toggles from spells to three native talent trees inside player analysis")
check(p.talentPane.trees[2].nodes[2].node.rank==2 and p.talentPane.trees[2].nodes[2].node.tier==2 and p.talentPane.trees[2].pointText:GetText()=='3 points',"tree ranks, positions and totals match the owning client API")
local nodesBefore=#FRAMES; D.refreshBreakdown(); D.refreshBreakdown()
check(#FRAMES==nodesBefore,"talent refresh reuses existing nodes")
click(p.talentButton)
check(not p.talentPane:IsShown() and p.searchBox:IsShown() and p.context.history==D.fightHistory[1],"returning to spells preserves player and fight context")
GetTalentInfo=function() error('unavailable API') end; NOW=NOW+2; click(p.talentButton)
check(string.find(p.talentPane.message:GetText(),'unavailable',1,true)~=nil and not p.talentPane.trees[1]:IsShown(),"unavailable talent API shows a clear message without stale trees")
local unnamed={name='Unknown',key='unknown'}
check(D.talentProfileFor(unnamed)==nil,"players without a GUID cannot cause a nil-index talent lookup")
GetNumTalentTabs=originalTabs; GetTalentTabInfo=originalTab; GetNumTalents=originalCount; GetTalentInfo=originalTalent
-- Moving a meter must not trigger its player-bar click action.
local oldShift,oldSave,oldMultiSave=IsShiftKeyDown,D.uiSaveMain,D.saveMultiWindows
local shifting=false; IsShiftKeyDown=function() return shifting end
local savedMain,savedExtra=0,0
D.uiSaveMain=function() savedMain=savedMain+1 end
D.saveMultiWindows=function() savedExtra=savedExtra+1 end
local function gesture(h,event)
    this=h; arg1='LeftButton'; h.scripts[event]()
end
for _,view in ipairs({D.mainView,restored}) do
    local f=view.frame; local starts,stops=0,0
    local oldStart,oldStop=f.StartMoving,f.StopMovingOrSizing
    f.StartMoving=function() starts=starts+1 end
    f.StopMovingOrSizing=function() stops=stops+1 end
    D.locked=false; view.locked=false; f.cawDockFree=nil
    local handle=view.footerRegions.summary
    gesture(handle,'OnMouseDown'); gesture(handle,'OnDragStart'); gesture(handle,'OnDragStop'); gesture(handle,'OnMouseUp')
    check(starts==1 and stops==1,"footer drag moves and stops only window "..view.id)
    D.locked=true; view.locked=true
    gesture(handle,'OnMouseDown'); gesture(handle,'OnDragStart'); gesture(handle,'OnMouseUp')
    check(starts==1,"locked footer refuses dragging in window "..view.id)
    D.locked=false; view.locked=false; f.cawDockFree={}
    gesture(handle,'OnMouseDown'); gesture(handle,'OnDragStart'); gesture(handle,'OnMouseUp')
    check(starts==1,"docked footer refuses dragging in window "..view.id)
    f.cawDockFree=nil
    local row=view.id==1 and D.rows[1] or view.rows[1]; local bar=row.bar
    local oldClick=bar.cawDragMouseUp; local clicks=0
    bar.cawDragMouseUp=function() clicks=clicks+1 end
    gesture(bar,'OnMouseDown'); gesture(bar,'OnDragStart'); gesture(bar,'OnMouseUp')
    check(starts==1 and clicks==1,"ordinary player interaction retains its click action in window "..view.id)
    shifting=true
    gesture(bar,'OnMouseDown'); gesture(bar,'OnDragStart'); gesture(bar,'OnDragStop'); gesture(bar,'OnMouseUp')
    check(starts==2 and clicks==1 and not f.cawDragHandle,"Shift-drag does not open player details in window "..view.id)
    shifting=false; gesture(bar,'OnMouseDown'); gesture(bar,'OnMouseUp')
    check(clicks==2,"a click after dragging is not swallowed in window "..view.id)
    bar.cawDragMouseUp=oldClick
    gesture(handle,'OnMouseDown'); gesture(handle,'OnDragStart'); f:Hide(); f:Show()
    check(stops==3 and not handle.cawDragging,"hiding a moving meter finishes its drag in window "..view.id)
    f.StartMoving=oldStart; f.StopMovingOrSizing=oldStop
end
check(savedMain==3 and savedExtra==3,"footer and Shift-drag save the position of the correct window")
local moved=0; local oldStart=D.window.StartMoving
D.window.StartMoving=function() moved=moved+1 end
gesture(D.mainWheelArea,'OnMouseDown'); gesture(D.mainWheelArea,'OnDragStart'); gesture(D.mainWheelArea,'OnMouseUp')
check(moved==1 and D.mainWheelArea.scripts.OnMouseWheel~=nil,"empty main-window area drags without losing mouse-wheel scrolling")
D.window.StartMoving=oldStart
IsShiftKeyDown=oldShift; D.uiSaveMain=oldSave; D.saveMultiWindows=oldMultiSave
local compactRow=D.rows[1]; compactRow.actor=hunter; compactRow.rank:SetText('1.'); compactRow.left:SetText(hunter.name)
local beforeWidth=compactRow.bar:GetWidth(); local setting=D.uiSettings()
local beforeRate,beforePercent=setting.rate,setting.percent; setting.rate=true; setting.percent=true
compactRow.bar:SetWidth(162); D.uiFormatRow(compactRow,1530,15,3060,'damage'); D.fitBarActorName(compactRow,hunter.name,58)
check(compactRow.right:GetText()=='1.5k' and compactRow.left:GetText()~='' and setting.rate and setting.percent,"minimal bars shorten numbers to preserve names without changing display preferences")
compactRow.bar:SetWidth(352); D.uiFormatRow(compactRow,1530,15,3060,'damage')
check(string.find(compactRow.right:GetText(),'102.0',1,true) and string.find(compactRow.right:GetText(),'50.0%',1,true),"widening restores the configured rate and share values")
compactRow.bar:SetWidth(beforeWidth); setting.rate=beforeRate; setting.percent=beforePercent
D.fightHistory={{name='Dungeon encounter',duration=10,actors={}}}
D.segment='history'; D.segmentIndex=1; D.window:SetWidth(190); D.applyCompactWindowLayout(); D.uiRefreshMeters()
check(D.mainView.segmentText:GetText()~='#1' and string.find(D.mainView.segmentButton.cawMenuLabel,'Dungeon encounter',1,true),"minimal selector retains encounter context and a full-name tooltip")
D.mainView.segmentMenu:Hide(); click(D.mainView.segmentButton)
check(not D.mainView.segmentMenu.up:IsShown() and D.mainView.segmentMenu:GetHeight()<90,"short encounter lists hide unused scroll arrows and shrink to their entries")
for i=2,10 do D.fightHistory[i]={name='Fight '..i,duration=10,actors={}} end
D.mainView.segmentMenu:Hide(); click(D.mainView.segmentButton)
check(D.mainView.segmentMenu.up:IsShown() and D.mainView.segmentMenu.down:IsShown() and D.mainView.segmentMenu.buttons[1]:GetWidth()==D.mainView.segmentMenu:GetWidth()-8,"overflowing encounter lists scroll above and below full-width entries")
print("UI checks: "..checks)

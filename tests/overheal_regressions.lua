local D=CAW_DPS_METER
local checks=0
local function check(v,label) assert(v,label); checks=checks+1; print("PASS OVERHEAL "..label) end
local function click(f) this=f; f.scripts.OnClick() end
CawDPSMeterCharDB.parserEnabled=true; CawDPSMeterCharDB.combatSyncEnabled=false
PARTY_COUNT=1; UNITS.player={guid="0x1",name="Healer",class="PRIEST"}
UNITS.party1={guid="0xB",name="Other",class="PRIEST"}; UNITS.pet=nil
UNITS.target={guid="0xF1",name="Enemy",hostile=true}
D.uiResetData("all"); D.threatCalEnabled=false; D.localPlayerDead=false; D.lastFinalizeAt=0
NOW=NOW+100; PLAYER_COMBAT=true; fire(D.events,"PLAYER_REGEN_DISABLED")
D.dpsLogActive=true; D.dpsLogProbing=false
local function heal(source,spell,gross,over,crit,periodic)
    return D.dpsLogReceive(periodic and "SPELL_PERIODIC_HEAL" or "SPELL_HEAL",source,nil,1,0,"0x1","Healer",1,0,
        2060,spell,2,gross,over,0,crit)
end
D.dpsLogReceive("SWING_DAMAGE","0x1","Healer",1,0,"0xF1","Enemy",64,0,5,-1,1,0,0,0,nil)
local a=D.actors['0x1']; local threat=a.threat['0xF1']
check(heal('0x1','Heal',100,100,'1'),"fully overhealed casts are accepted")
check(a.healing==0 and a.overhealing==100 and a.overhealTotal==100 and a.overhealHits==1
    and a.overhealCrits==1 and a.healSpells.Heal.spellId==2060,"full overheal preserves amount hit crit and spell identity")
check(a.threat['0xF1']==threat,"zero effective healing generates no healing threat")
heal('0x1','Heal',200,50,nil,true); heal('0x1','Heal',300,0,nil)
check(a.healing==450 and a.overhealing==150 and a.overhealTotal==600 and a.heals==3,
    "direct periodic partial and zero overheal accumulate separately from effective healing")
check(D.overhealPercent(a.overhealing,a.overhealTotal)=='25.0%',"overheal percentage uses gross healing rather than effective healing")
local hits=a.heals
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_SPELL_SELF_BUFF','Your Heal heals Healer for 300.')
check(a.heals==hits and a.overhealing==150,"RAW duplicate cannot add DPSLog healing or overheal again")
heal('0x1','Unknown heal',80,nil); heal('0x1','Unknown heal',20,-1)
check(a.healing==550 and a.overhealTotal==600 and a.healSpells['Unknown heal'].overhealing==nil,
    "missing and unknown overheal suffixes are not converted into measured zeroes")
heal('0xB','Unknown heal',100,nil)
check(D.actors['0xB'].overhealing==nil and D.overhealSummary(D.actors,D.actors['0xB'])==nil,
    "unknown healer coverage stays distinguishable from zero overheal")
local before=a.healing; local rejected=D.dpsLogRejected
heal('0x1','Invalid',100,101); heal('0x1','Invalid',100,math.huge); heal('0x1','Invalid',100,0/0)
check(a.healing==before and not a.healSpells.Invalid and D.dpsLogRejected==rejected+3,"invalid overheal suffixes cannot pollute totals")
check(not heal('0xEE','Outsider',100,50) and not D.actors['0xEE'],"outsider overheal stays outside group data")
D.dpsLogReceive('SPELL_SUMMON','0x1','Healer',1,0,'0xCA','Healing Stream Totem',1,0,5394,'Healing Stream Totem',8)
heal('0xCA','Healing Stream',40,10,nil,true)
local over,gross=D.overhealSummary(D.actors,a)
check(over==160 and gross==640,"owned summons contribute to owner overheal and its denominator")
D.mode='overhealing'; D.segment='current'; D.window:SetWidth(460); D.uiRefresh(nil)
local rows,_,cache=D.meterSortedRows(D.actors,'overhealing')
check(rows[1].actor==a and rows[1].value==160 and rows[1].overhealTotal==640
    and string.find(D.rows[1].right:GetText(),'25.0%',1,true),"main Overheal bars show owner amount and actual overheal rate")
local revision=cache.revision; heal('0x1','Heal',100,0)
D.meterSortedRows(D.actors,'overhealing')
check(cache.revision>revision and rows[1].value==160 and rows[1].overhealTotal==740,
    "clean healing invalidates cached percentages without changing overheal amount")
local v=D.multiWindows[2] or D.createMultiWindow(nil)
v.mode='overhealing'; v.segment='current'; v.frame:Show(); v.frame:SetWidth(460); D.updateMultiWindow(v)
check(v.rows[1].actor==a and string.find(v.rows[1].right:GetText(),'21.6%',1,true),"extra windows render the same Overheal data")
local report=D.buildReportLines(v)
check(report and string.find(report[1],'Overheal',1,true) and string.find(report[2],'21.6%',1,true),"Overheal report includes the player rate")
this=D.rows[1].bar; this.scripts.OnEnter()
check(D.actorHoverFrame:IsShown() and string.find(D.actorHoverFrame.summary:GetText(),'21.6%',1,true)
    and D.actorHoverFrame.rows[1].share:GetText()=='21.4%',"hover uses gross-healing percentages per player and spell")
D.openBreakdown(a,nil); local p=D.breakdownPanel
check(p.total==160 and p.shareHeader.text:GetText()=='Overheal %' and #p.entries==2,"detail view contains recorded player and summon heals only")
check(p.metricLabels[2]:GetText()=='Overheal rate' and p.metrics[2]:GetText()=='21.4%'
    and p.metrics[7]:GetText()=='550' and p.metrics[8]:GetText()=='700',"spell detail separates overheal rate effective and gross recorded healing")
p.context.mode='healing'; D.refreshBreakdown()
check(p.metricLabels[8]:GetText()=='Overheal' and p.metrics[8]:GetText()=='150',"normal healing detail also exposes known overheal")
p.context.mode='overhealing'; D.refreshBreakdown()
heal('0xB','Heal',200,100); D.openCompare(p.context,a.guid)
local cp=D.comparePanel
check(cp.rightKey=='0xB' and string.find(cp.rightTotal:GetText(),'50.0%',1,true),"same-class comparison shows each healer's own overheal rate")
check(cp.rows[1].left:GetText()=='150  21.4%' and cp.rows[1].right:GetText()=='100  50.0%',
    "spell comparison divides each side by its own gross healing")
cp:Hide(); p:Hide()
local unknown={key='raw',guid='raw',name='Legacy healer',classToken='PRIEST',healing=100,healSpells={Heal={healing=100,hits=1,crits=0}}}
D.fightHistory={{actors={raw=unknown},duration=10,name='Old data'}}; D.segment='history'; D.segmentIndex=1
D.uiRefreshMeters(); D.openBreakdown(unknown,nil)
check(D.mainView.footerText=='No overheal data' and p.totalText:GetText()=='No overheal data'
    and not p.compareButton:IsEnabled(),"old records explain unavailable overheal instead of claiming zero percent")
p:Hide()
-- A fight containing only fully overhealed casts is still useful history.
D.uiResetData('all'); NOW=NOW+100; PLAYER_COMBAT=true; D.lastFinalizeAt=0
fire(D.events,'PLAYER_REGEN_DISABLED'); heal('0x1','Heal',100,100)
NOW=NOW+8; PLAYER_COMBAT=false; fire(D.events,'PLAYER_REGEN_ENABLED')
NOW=NOW+2; this=D.events; D.events.scripts.OnUpdate()
check(#D.fightHistory==1 and D.fightHistory[1].actors['0x1'].healing==0
    and D.fightHistory[1].actors['0x1'].overhealing==100
    and D.overallSegment.actors['0x1'].overhealTotal==100,"pure overheal survives history and overall aggregation")
-- Emulate a native font reporting the width of its currently constrained text.
D.mode='damage'; D.segment='current'; D.appearance=D.uiCopySettings(nil); D.appearance.rate=true
local row=D.rows[1]; row.actor={name='Mezmerise',classToken='HUNTER'}
local oldMeasure=row.right.GetStringWidth; local oldBarWidth=row.bar:GetWidth()
row.right.GetStringWidth=function(self) return math.min(#(self:GetText() or '')*6+0.25,self:GetWidth()) end
row.bar:SetWidth(445); row.right:SetWidth(45)
D.uiFormatRow(row,3379,22,3379,'damage'); D.uiFitRowText(row,'Mezmerise')
check(string.find(row.right:GetText(),'153.6',1,true) and row.right:GetWidth()>#row.right:GetText()*6,
    "DPS width is measured before constraining the value field and rounded with padding")
check(row.left:GetText()=='Mezmerise' and row.left:GetWidth()>60,"wide bars retain the complete player name alongside DPS")
row.bar:SetWidth(180); D.uiFormatRow(row,3379,22,3379,'damage'); D.uiFitRowText(row,'Mezmerise')
row.bar:SetWidth(445); D.uiFormatRow(row,3379,22,3379,'damage'); D.uiFitRowText(row,'Mezmerise')
check(string.find(row.right:GetText(),'153.6',1,true) and row.right:GetWidth()>#row.right:GetText()*6,
    "widening a previously compact bar restores the full DPS field")
row.right.GetStringWidth=oldMeasure; row.bar:SetWidth(oldBarWidth)
print('Overheal and value-layout checks: '..checks)

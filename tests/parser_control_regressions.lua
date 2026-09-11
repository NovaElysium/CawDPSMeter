local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print('PASS PARSER '..label) end
local function hit(amount)
    fire(D.events,'RAW_COMBATLOG','CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF1 for '..amount..'.')
end
local function tick(f) this=f; f.scripts.OnUpdate() end
local function toggle(control,value)
    control.check:SetChecked(value and 1 or nil)
    this=control.check; control.check.scripts.OnClick()
end
local oldAPI=CombatLogGetCurrentEventInfo
CombatLogGetCurrentEventInfo=nil
D.dpsLogInitialized=false; D.dpsLogActive=false; D.dpsLogProbing=false; D.dpsLogRawCommitted=false
CawDPSMeterCharDB.parserEnabled=nil; CawDPSMeterCharDB.combatSyncEnabled=nil
check(D.parserEnabled() and D.combatSyncEnabled(),'existing installations default to parser and sync enabled')
SlashCmdList.CAWDPS('reset'); D.lastFinalizeAt=0; NOW=NOW+10; PLAYER_COMBAT=true
D.fightHistory={}
D.threatCalStart()
fire(D.events,'PLAYER_REGEN_DISABLED'); hit(100); NOW=NOW+2
local own=D.actors[D.selfKey]
assert(own and own.damage==100)
local duration=NOW-D.startTime
local history=table.getn(D.fightHistory)
-- Pausing must close even an encounter held open by CC or recent dead sync.
D.activeCC['0xF1']={time=NOW,spell='Sap'}; D.localPlayerDead=true; D.deadSyncLastReceived=NOW
D.dpsLogQueue={{'CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF1 for 999.'}}
D.syncQueue={{message='Z~old',channel='PARTY'}}; D.syncIncoming={segmentSerial=D.segmentSerial}
D.setParserEnabled(false)
local calibration=D.threatCalSession
local eventCount=#calibration.events; local castCount=#calibration.casts; local snapshotCount=#calibration.snapshots
D.threatCalRecordEvent({kind='damage',amount=999})
D.threatCalRecordCast('0x1','0xF1','CAST',133)
local publish,published=D.serverThreatPublish,0
D.serverThreatPublish=function(...) published=published+1 end
D.threatCalRecordSnapshot('TWTv4=Hunter:1:123456:100:1','TWT ','WHISPER','Hunter')
D.serverThreatPublish=publish
check(#calibration.events==eventCount and #calibration.casts==castCount and #calibration.snapshots==snapshotCount
    and calibration.stopReason=='parser paused','paused local data does not enter calibration or comparison snapshots')
check(published==1,'server threat responses still reach the display while the local parser is paused')
check(not D.inCombat and D.startTime==0 and D.lastDuration==duration,'pausing freezes time and closes an active CC/dead-sync segment')
check(table.getn(D.fightHistory)==history+1 and D.fightHistory[1].actors[D.selfKey].damage==100,
    'partial fight is preserved exactly once in history')
check(#D.syncQueue==0 and not D.syncIncoming and #D.dpsLogQueue==0,'pause discards pending sync and uncommitted DPSLog probe events')
local serial=D.segmentSerial
local rawCount=D.rawTotal
local scan,scanCalls=D.scanPlayerBuffs,0
D.scanPlayerBuffs=function(...) scanCalls=scanCalls+1; return scan(unpack(arg)) end
local apiCalls=0
CombatLogGetCurrentEventInfo=function() apiCalls=apiCalls+1; return 'SWING_DAMAGE','0x1','Hunter',1,0,'0xF1','Mob',64,0,30,-1,1,0,0,0,nil end
D.dpsLogActive=true
for i=1,100 do
    hit(50)
    fire(D.events,'PLAYER_AURAS_CHANGED')
    fire(D.events,'UNIT_CASTEVENT','0xF1','0x1','START',133)
    fire(D.events,'CHAT_MSG_COMBAT_FRIENDLY_DEATH','You die.')
    fire(D.dpsLogFrame,'COMBAT_LOG_EVENT_UNFILTERED')
    tick(D.events); tick(D.dpsLogFrame)
end
fire(D.events,'PLAYER_REGEN_DISABLED'); fire(D.events,'PLAYER_REGEN_ENABLED')
D.parseRawReplay('CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF1 for 999.')
D.dpsLogReceive('SPELL_INTERRUPT','0x1','Hunter',1,0,'0xF1','Mob',64,0,1766,'Kick',1,133,'Fireball',4)
check(scanCalls==0 and apiCalls==0 and D.rawTotal==rawCount,'paused event bursts skip aura scans, RAW parsing and the native DPSLog API')
check(own.damage==100 and D.segmentSerial==serial and not D.inCombat and D.pendingCombatEndAt==0,
    'RAW, replay, casts, deaths, DPSLog and combat transitions cannot change paused totals')
D.scanPlayerBuffs=scan
D.mode='damage'; D.segment='current'; D.uiRefreshMeters()
check(D.mainView.summary:GetText()=='Parser paused','paused status is visible in the meter footer')
D.openOptions(nil); local p=D.optionsPanel; p.page='General'; D.refreshOptions()
local parser,sync
for _,r in ipairs(p.controls) do
    if r.control[2]=='parserEnabled' then parser=r elseif r.control[2]=='combatSyncEnabled' then sync=r end
end
check(parser and sync and not parser.check:GetChecked() and sync.check:GetChecked(),
    'General offers separate saved parser and combat sync checkboxes')
toggle(sync,false)
CombatLogGetCurrentEventInfo=nil; D.dpsLogActive=false; D.dpsLogProbing=false
toggle(parser,true)
check(D.threatCalSession~=calibration,'resuming calibration starts a fresh session after the recording gap')
check(CawDPSMeterCharDB.parserEnabled==true and CawDPSMeterCharDB.combatSyncEnabled==false,
    'resuming the parser preserves the independent sync-off preference')
NOW=NOW+10; hit(25)
check(D.inCombat and D.actors[D.selfKey].damage==25 and D.segmentSerial>serial,
    'resuming mid-combat starts a new segment from the first new event')
check(D.fightHistory[1].actors[D.selfKey].damage==100,'resuming never merges paused time or old events into the saved fight')
D.openOptions(D.multiWindows[2]); p.page='General'; D.refreshOptions()
check(parser.check:GetChecked() and not sync.check:GetChecked(),'all windows share the same parser and sync preferences')
local scans=0; local enemies=D.syncEnemySet
D.syncEnemySet=function() scans=scans+1; return enemies() end
D.syncRequested=false
for i=1,100 do tick(D.events) end
check(scans==0,'sync off does not scan enemy GUIDs on every frame')
D.syncEnemySet=enemies
toggle(sync,true)
-- Persisted false takes effect at the next world-entry boundary, before combat.
D.setParserEnabled(false)
fire(D.events,'PLAYER_ENTERING_WORLD'); fire(D.events,'PLAYER_REGEN_DISABLED'); hit(500)
check(CawDPSMeterCharDB.parserEnabled==false and not D.inCombat,'world entry does not re-enable a saved parser-off setting')
D.setParserEnabled(true); D.setCombatSyncEnabled(true)
D.dpsLogActive=true
D.dpsLogReceive('SWING_DAMAGE','0x1','Hunter',1,0,'0xF1','Mob',64,0,40,-1,1,0,0,0,nil)
check(D.actors[D.selfKey].damage==40,'DPSLog can resume recording after a pause')
CombatLogGetCurrentEventInfo=oldAPI
D.dpsLogActive=false; D.dpsLogProbing=false
p:Hide(); D.mode='damage'; D.segment='current'
print('Parser control checks: '..checks)

local D=CAW_DPS_METER
local count=0
local function check(ok,name) assert(ok,name); count=count+1; print("PASS "..name) end
fire(D.diagBootstrapFrame,"ADDON_LOADED","CawDPSMeter")
fire(D.events,"ADDON_LOADED","CawDPSMeter")
fire(D.events,"PLAYER_ENTERING_WORLD")
local function fresh()
    SlashCmdList.CAWDPS("reset")
    D.lastFinalizeAt=0; NOW=NOW+10; PLAYER_COMBAT=true
end
fresh()
D.threatOnCast("0x99","0xF1","CAST",2649)
check(not D.inCombat,"outsider cannot open segment")
D.threatOnCast("0x2","0xF1","FAIL",2649)
check(not D.inCombat,"failed growl cannot open segment")
D.threatOnCast("0x2","0xF1","CAST",2649)
check(D.inCombat and (not D.actors["0x2"] or not D.actors["0x2"].threat),"growl waits for RAW success")
D.threatOnSpellLanded("0x2","0xF1","Growl")
D.threatOnSpellLanded("0x2","0xF1","Growl")
check(D.actors["0x2"].threat["0xF1"]==50,"growl success counted once")
check(D.actors["0x1"]~=nil,"pet creates owner actor")
NOW=NOW+3; D.threatPrunePending()
check(next(D.threatPendingCast)==nil,"expired pending casts removed")
D.threatOnCast("0x2","0xF1","CAST",99999)
check(next(D.threatPendingCast)==nil,"irrelevant casts not retained")
fresh()
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_COMBAT_SELF_HITS","You hit 0xF1 for 10.")
check(D.currentEnemyDamage["0xF1"]==10 and D.currentEnemyBestGuid=="0xF1","first RAW target survives segment reset")
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_COMBAT_SELF_HITS","You hit Other for 15.")
check(D.actors["0x1"].damage==25 and D.actors["0x1"].threat["0xF1"]==10,"unknown target does not reuse previous threat target")
local v=D.createMultiWindow(nil)
v.mode="damage"; v.segment="overall"; D.updateMultiWindow(v)
check(v.modeText.text=="Damage / DPS" and v.segmentText.text=="Overall","extra labels update without resize")
local a={buffs={Renew={total=120,targets={x=120},active={}}}}
check(string.find(D.multiReportTotalLine({mode="buffs"},{{actor=a,value=1}},1,120),"120.0s",1,true),"aura total reports seconds")
a.name="Test"; D.lastDuration=10
check(string.find(D.multiReportLine({mode="buffs"},{actor=a,value=1},1,120),"100.0%",1,true),"extra aura report uses its own duration")
-- Bounded UI pool, including menu callbacks and closed-row references.
local oldFrame=v.frame
D.removeMultiWindow(v)
local allocated=table.getn(FRAMES)
for i=1,50 do local w=D.createMultiWindow(nil); assert(w.frame==oldFrame,"reuse window "..i); D.removeMultiWindow(w) end
check(true,"50 create/close cycles reuse the same window")
check(table.getn(FRAMES)==allocated,"create/close does not allocate more frames")
check(oldFrame.scripts.OnUpdate==nil and v.rows[1].actor==nil,"closed windows stop ticking and release actors")
CawDPSMeterCharDB.extraWindowsExplicit=nil; CawDPSMeterCharDB.extraWindows={}; CawDPSMeterCharDB.extraWindowCount=0
CawDPSMeterDB.extraWindowsExplicit=true; CawDPSMeterDB.extraWindowCount=1; CawDPSMeterDB.extraWindows={{mode="damage"}}
D.multiWindowsRestored=false; D.restoreMultiWindows()
check(CawDPSMeterCharDB.extraWindowCount==0 and not D.multiWindows[2],"legacy character zero wins over account v3")
-- Name matching includes identities with no local damage/threat events.
D.actors={a={name="Wolf",guid="0x2",threat={['0xF1']=50}}}
D.guidToActor.other={name="Wolf",guid="0x3",key="0x3",isPet=true}
local match,matches,ambiguous=D.threatCalActorByName("Wolf","0xF1")
check(match==nil and matches==2 and ambiguous,"missing same-name pet remains ambiguous")
D.guidToActor.other=nil
-- Complete scans remove stale entries, failed scans preserve them.
D.activeRosterBuffs['0x3|Renew']={target="0x3",spell="Renew"}
D.scanUnitBuffs("party1","0x3")
check(D.activeRosterBuffs['0x3|Renew']==nil,"group scan removes stale aura")
D.activeRosterBuffs['0x3|Renew']={target="0x3",spell="Renew"}
UnitBuff=function() error("unavailable") end
D.scanUnitBuffs("party1","0x3")
check(D.activeRosterBuffs['0x3|Renew']~=nil,"failed scan preserves last known aura")
UnitBuff=function() end
fresh()
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_COMBAT_SELF_HITS","You hit 0xF1 for 10.")
D.threatOnCast("0x1",nil,"FAIL",5384)
check(D.actors['0x1'].threat['0xF1']==10,"FD failure does not erase threat")
D.threatOnCast("0x1",nil,"CAST",5384)
check(D.actors['0x1'].threat['0xF1']==0,"completed FD cast resets without RAW success")
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_SPELL_SELF_BUFF","You cast Feign Death.")
check(D.actors['0x1'].threat['0xF1']==0,"FD RAW success resets threat")
fresh()
PARTY_COUNT=1; UNITS.party1={guid="0x3",name="Friend",class="HUNTER"}
fire(D.events,"PARTY_MEMBERS_CHANGED")
D.threatOnCast("0x3","0xF1","CAST",20736)
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE","0x3 casts Distracting Shot on 0xF1.")
check(D.actors['0x3'].threat['0xF1']==220,"group flat success creates actor and commits rank")
-- Enemy cast completed before Earth Shock: no ghost interrupt.
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE","0xF1 begins to cast Bolt.")
fire(D.events,"UNIT_CASTEVENT","0xF1","0x1","CAST",100)
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_SPELL_SELF_DAMAGE","Your Earth Shock hits 0xF1 for 10.")
check(next(D.actors['0x1'].interrupts)==nil,"completed cast is not interrupted later")
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE","0xF1 begins to cast Bolt.")
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_SPELL_SELF_DAMAGE","Your Kick misses 0xF1.")
check(D.activeEnemyCasts['0xF1']~=nil,"failed interrupt preserves enemy cast")
-- Ordinary stun expiration is not a damage break.
D.activeCC['0xF1']={spell="Hammer of Justice",time=NOW,sourceKey="0x1"}
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_COMBAT_SELF_HITS","You hit 0xF1 for 5.")
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_SPELL_AURA_GONE_OTHER","Hammer of Justice fades from 0xF1.")
check(next(D.actors['0x1'].ccBreaks)==nil,"normal stun expiration is not a CC break")
-- Summons survive refresh without retaining unrelated outsiders.
D.pendingSelfTotem={name="Searing Totem",time=NOW}
D.tryClaimSelfTotemSource("0xF9","Searing Bolt","CHAT_MSG_SPELL_PET_DAMAGE")
fire(D.events,"PARTY_MEMBERS_CHANGED")
check(D.guidToActor['0xF9'] and D.guidToActor['0xF9'].ownerKey=='0x1',"totem identity survives roster refresh")
-- Late snapshot cannot mutate a committed current segment.
D.syncNonce="test"; D.syncSelectedSource="Friend"
fire(D.events,"PLAYER_REGEN_ENABLED")
NOW=NOW+2; PLAYER_COMBAT=false; this=D.events; D.events.scripts.OnUpdate()
local before=D.actors['0x1'].damage
fire(D.events,"CHAT_MSG_ADDON",D.syncPrefix,"H~test~100~0xF1~Mob~0xF1","PARTY","Friend")
fire(D.events,"CHAT_MSG_ADDON",D.syncPrefix,"A~test~0x1~Hunter~0x1~~0~HUNTER~999~0~1~0~0~0","PARTY","Friend")
fire(D.events,"CHAT_MSG_ADDON",D.syncPrefix,"D~test~0x1~Melee~999~1~0","PARTY","Friend")
fire(D.events,"CHAT_MSG_ADDON",D.syncPrefix,"Z~test","PARTY","Friend")
check(D.actors['0x1'].damage==before and D.syncNonce==nil,"late sync rejected after commit")
check(not D.syncEnemyCompatible('0xF8') and D.syncEnemyCompatible('0xF1'),"sync requires known shared enemy")
-- Diagnostics keeps different contexts and sessions separate.
CawDPSMeterErrorLog.entries={}
D.diagWarn('API_TIMEOUT','timeout','A'); D.diagWarn('API_TIMEOUT','timeout','B')
check(table.getn(CawDPSMeterErrorLog.entries)==2,"diagnostics preserves different contexts")
D.diagWarn('API_TIMEOUT','timeout','B')
check(CawDPSMeterErrorLog.entries[2].count==2,"same diagnostic context still deduplicates")
NOW=NOW-20; D.diagWarn('API_TIMEOUT','timeout','B')
check(table.getn(CawDPSMeterErrorLog.entries)==3,"negative time difference not deduplicated")
-- Calibration timeout keeps server rows but removes unsafe target/diff claims.
D.threatCalEnabled=true; D.threatCalNewSession(); D.threatCalPendingRequests={}
D.threatCalQueueRequest('0xF1','Mob','elite','PARTY'); NOW=NOW+2; D.threatCalSendRequest()
check(D.threatCalAttributionUncertain,"timeout marks attribution uncertain")
D.threatCalQueueRequest('0xF8','Other','elite','PARTY')
D.threatCalRecordSnapshot('TWTv4=Hunter:1:100:100:1','server','PARTY','server')
local snap=D.threatCalSession.snapshots[1]
check(snap and snap.targetGuid==nil and snap.requestTargetGuid=='0xF8' and snap.rows[1].diff==nil,"late-risk response cannot claim new target or precise diff")
-- Hypothetical Lua 5.0 upvalue regression in the large event closure.
check(debug.getinfo(D.events.scripts.OnEvent).nups<=32,"event closure stays within 32 upvalues")
D.threatCalEnabled=false
fresh()
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_CUSTOM_DAMAGE","unrecognized test damage")
check(D.rawUnknownCount>0,"unknown RAW lines reach diagnostic ring")
D.mode="damage"; D.segment="current"
local w=D.createMultiWindow(nil); w.mode="healing"; w.segment="overall"
w.rows[1].actor={name="Test"}; this=w.rows[1].bar
local original=D.actorTooltipOnEnter; D.actorTooltipOnEnter=function() error("injected tooltip failure") end
local ok=pcall(this.scripts.OnEnter)
check(not ok and D.mode=="damage" and D.segment=="current" and this.detailsRow==nil,"tooltip exception restores primary view context")
D.actorTooltipOnEnter=original
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE","0xF1 begins to cast Bolt.")
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE","0x3's Kick hits 0xF1 for 10.")
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE","0x3's Kick interrupts 0xF1's Bolt.")
check(D.actors['0x3'].interrupts.Bolt.count==1,"explicit interrupt and hit heuristic counted once")
local rogue={guid='0x4',classToken='ROGUE'}
check(D.threatGlobalModifier(rogue)==0.8,"known rogue modifier applies remotely")
D.deadEnemies['0xF1']=true; D.currentEnemyBestGuid='0xF1'
D.threatOnHealing(rogue,100,'Heal')
check(not rogue.threat,"healing does not add threat to dead dominant target")
-- Historical target and reference are independent of today's target/actors.
D.fightHistory={{enemyGuid='0xFA',enemyName='Old Mob',actors={one={threat={['0xFA']=200}}}}}
D.segment='history'; D.segmentIndex=1
check(D.threatDisplayTargetGUID()=='0xFA' and D.threatDisplayTargetName()=='Old Mob' and D.threatTopForDisplay()==200,"history threat uses historical target and reference")
fresh()
fire(D.events,"RAW_COMBATLOG","CHAT_MSG_COMBAT_SELF_HITS","You hit 0xF1 for 10.")
D.syncNonce="valid"; D.syncSelectedSource="Friend"
fire(D.events,"CHAT_MSG_ADDON",D.syncPrefix,"H~valid~100~0xF1~Mob~0xF1","PARTY","Friend")
fire(D.events,"CHAT_MSG_ADDON",D.syncPrefix,"A~valid~0x1~Hunter~0x1~~0~HUNTER~100~0~1~0~0~0","PARTY","Friend")
fire(D.events,"CHAT_MSG_ADDON",D.syncPrefix,"D~valid~0x1~Melee~100~1~0","PARTY","Friend")
fire(D.events,"CHAT_MSG_ADDON",D.syncPrefix,"Z~valid","PARTY","Friend")
check(D.actors['0x1'].damage==100,"valid current snapshot still merges")
D.threatCalEnabled=true; D.threatCalNewSession()
local resetActor={guid='0x1',name='Hunter',threat={['0xF1']=100,['0xF2']=200}}
D.threatResetActor(resetActor,'Feign Death')
local events=D.threatCalSession.events
check(table.getn(events)==2 and events[1].delta<0 and events[2].delta<0 and events[1].kind=='reset',"calibration preserves per-target reset deltas")
D.threatCalEnabled=false
CawDPSMeterDB.savedVariablesCleanupVersion=nil
CawDPSMeterLog={old=true}
CawThreatCalibrationDB.sessions={{events={}},{requests=1},{events={{kind='reset'}}}}
D.cleanupLegacySavedVariables()
check(CawDPSMeterLog==nil and table.getn(CawThreatCalibrationDB.sessions)==2,"cleanup retains request-only and captured sessions")
CawDPSMeterLog={fresh=true}; D.cleanupLegacySavedVariables()
check(CawDPSMeterLog.fresh,"repeat cleanup preserves newly captured developer logs")
check(upvalue(SlashCmdList.CAWDPSDEBUG,'oldDebug')~=nil and pcall(SlashCmdList.CAWDPSDEBUG,''),"no-argument debug retains original handler")
D.threatCalEnabled=false; CawDPSMeterCharDB.threatCalAutoStart=nil
fire(D.threatCalFrame,'PLAYER_ENTERING_WORLD')
check(D.threatCalEnabled and CawDPSMeterCharDB.threatCalAutoStart,"calibration starts automatically by default")
local autoSession=D.threatCalSession
fire(D.threatCalFrame,'PLAYER_ENTERING_WORLD')
check(D.threatCalSession==autoSession,"zone transitions do not restart calibration")
fire(D.threatCalFrame,'PLAYER_LOGOUT')
check(autoSession.stopReason=='logout' and autoSession.endedAt~=nil,"automatic session closes at logout")
SlashCmdList.CAWDPSTHREATCAL('off')
fire(D.threatCalFrame,'PLAYER_ENTERING_WORLD')
check(not D.threatCalEnabled and CawDPSMeterCharDB.threatCalAutoStart==false,"explicit off disables future automatic starts")
SlashCmdList.CAWDPSTHREATCAL('on')
check(D.threatCalEnabled and CawDPSMeterCharDB.threatCalAutoStart,"manual on restores automatic startup")
fresh()
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF1 for 10.')
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_SPELL_SELF_BUFF','You gain Feign Death.')
check(D.actors['0x1'].threat['0xF1']==10,'early FD success waits for matching cast')
NOW=NOW+0.1; D.threatOnCast('0x1',nil,'CAST',5384)
check(D.actors['0x1'].threat['0xF1']==0,'FD success before CAST resets threat')
D.actors['0x1'].threat['0xF1']=5
D.threatOnFeignSuccess('0x1'); D.threatOnCast('0x1',nil,'CAST',5384)
check(D.actors['0x1'].threat['0xF1']==5,'duplicate FD notifications do not erase new damage')
fresh()
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF1 for 10.')
D.threatOnFeignSuccess('0x1'); D.threatOnCast('0x1',nil,'FAIL',5384)
NOW=NOW+0.1; D.threatOnCast('0x1',nil,'CAST',5384)
check(D.actors['0x1'].threat['0xF1']==0,'new completed FD after an earlier FAIL can succeed')
D.threatCalNewSession(); D.threatCalEnabled=true
D.threatCalRecordCast('0x1','0xF1','MAINHAND',6603)
check(table.getn(D.threatCalSession.casts)==0 and D.threatCalSession.filteredSwings==1,'auto swings use counters instead of cast budget')
D.threatCalRecordCast('0x1',nil,'CAST',5384)
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_SPELL_SELF_BUFF','You gain Feign Death.')
check(table.getn(D.threatCalSession.feignRaw)==2,'FD original CAST and RAW recorded automatically')
local oldLimit=D.threatCalMaxCasts; D.threatCalMaxCasts=1
local oldDiag=D.diagCal; local limitWarnings=0
D.diagCal=function() limitWarnings=limitWarnings+1 end
D.threatCalRecordCast('0x1',nil,'CAST',75); D.threatCalRecordCast('0x1',nil,'CAST',75)
check(D.threatCalSession.droppedCasts==2 and limitWarnings==1,'cast cap warns once and retains drop count')
D.threatCalMaxCasts=oldLimit; D.diagCal=oldDiag
D.threatCalPendingRequests={}; D.threatCalTimeoutStreak=0
D.threatCalQueueRequest('0xF1','Mob','elite','PARTY'); NOW=NOW+2
D.threatCalSendRequest()
NOW=NOW+1
local sent,reason=D.threatCalSendRequest()
check(not sent and reason=='timeout backoff','API timeout suppresses immediate retry')
local n=table.getn(D.threatCalSession.transport)
fire(D.threatCalFrame,'CHAT_MSG_ADDON','unrelated','private unrelated addon payload','PARTY','Friend')
check(table.getn(D.threatCalSession.transport)==n,'transport trace excludes unrelated addon payloads')
fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT_SERVER','TWTv3=unknown format','PARTY','server')
check(table.getn(D.threatCalSession.transport)==n+1,'alternate TWT response retained for diagnosis')
local i; for i=1,250 do D.threatCalTrace('transport',{kind='test'}) end
check(table.getn(D.threatCalSession.transport)==200 and D.threatCalSession.transportDropped>0,'transport trace bounded to 200 records')
D.threatCalNewSession(); D.threatCalPendingRequests={}; D.threatCalLastPayload=nil
local originalLoaded=IsAddOnLoaded
IsAddOnLoaded=function(name) return name=='TWThreat' end
local sent,reason=D.threatCalSendRequest()
check(not sent and reason=='parallel TWThreat: API sampling paused','TWThreat owns requests in passive mode')
fire(D.threatCalFrame,'CHAT_MSG_ADDON','server','TWTv4=Hunter:1:123:100:1','WHISPER','server')
local passive=D.threatCalSession.snapshots[1]
check(passive and passive.captureMode=='passive' and passive.rows[1].server==123 and passive.targetGuid==nil and passive.rows[1].diff==nil,'passive server rows retained without invented target or diff')
IsAddOnLoaded=originalLoaded
D.threatCalQueueRequest('0xF1','Mob','elite','PARTY')
fire(D.threatCalFrame,'CHAT_MSG_ADDON','server','TWTv4=Hunter:1:124:100:1','WHISPER','server')
local mismatch=D.threatCalSession.snapshots[2]
check(mismatch and mismatch.channelMismatch and mismatch.rows[1].server==124 and mismatch.rows[1].diff==nil,'different response channel retains uncertain server values')
local eligible=D.threatCalApiEligible; local send=SendAddonMessage; local payload=nil
D.threatCalApiEligible=function() return true,'PARTY' end
SendAddonMessage=function(prefix,msg,channel) payload=msg end
D.threatCalPendingRequests={}; D.threatCalApiRetryAt=0; D.threatCalLastTimeoutAt=0
D.threatCalSendRequest()
check(payload=='limit=4','standalone request matches TWThreat default row limit')
D.threatCalApiEligible=eligible; SendAddonMessage=send
fresh()
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF1 for 421.')
D.threatOnCast('0x1',nil,'START',5384)
check(D.actors['0x1'].threat['0xF1']==421,'FD START alone preserves threat')
D.threatOnCast('0x1',nil,'CAST',5384)
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF1 for 43.')
check(D.actors['0x1'].threat['0xF1']==43,'live FD pattern: 421 then CAST then 43 becomes 43')
D.threatOnCast('0x1',nil,'FAIL',5384)
check(D.actors['0x1'].threat['0xF1']==464 and D.actors['0x1'].threatBase['0xF1']==464,'late FD failure restores baseline and keeps new threat')
D.threatOnCast('0x1',nil,'FAIL',5384)
check(D.actors['0x1'].threat['0xF1']==464,'duplicate FD failure does not restore twice')
fresh()
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF1 for 100.')
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF2 for 200.')
D.threatOnCast('0x1',nil,'CAST',5384)
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_SPELL_SELF_DAMAGE','Your Feign Death was resisted by 0xF1.')
check(D.actors['0x1'].threat['0xF1']==100 and D.actors['0x1'].threat['0xF2']==0,'explicit FD resist restores only matching enemy')
NOW=NOW+3; D.threatPrunePending()
check(next(D.threatFeignUndo)==nil,'FD rollback baselines expire')
fresh()
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE',"0x3's Auto Shot hits 0xF1 for 80.")
D.threatOnCast('0x3',nil,'CAST',5384)
check(D.actors['0x3'].threat['0xF1']==0,'remote hunter FD uses the same local reset path')
fresh()
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF1 for 100.')
D.threatCalNewSession(); D.threatCalEnabled=true
D.threatCalTargetState=nil; D.threatCalObservedRequest=nil; D.threatCalPendingRequests={}; D.threatCalLastPayload=nil
D.threatCalObserveTarget(); NOW=NOW+3
local transportOriginal=SendAddonMessage; local observerOriginal=D.threatCalSendObserver
local forwarded=nil
SendAddonMessage=function(a,b,c,d) forwarded={a,b,c,d}; return 'original-result',17 end
D.threatCalSendObserver=nil; D.threatCalInstallObserver()
local result,second=SendAddonMessage('TWT_UDTSv4','limit=4','PARTY','recipient')
check(result=='original-result' and second==17 and forwarded[4]=='recipient','request observer preserves transport arguments and return values')
check(D.threatCalObservedRequest.targetGuid=='0xF1','observer captures actual outgoing request target')
fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT ','TWTv4=Hunter:1:100:100:1','PARTY','Hunter')
local stableSnap=D.threatCalSession.snapshots[1]
check(stableSnap.stableTargetCandidate and stableSnap.rows[1].observedModel==100 and stableSnap.rows[1].diff==nil and stableSnap.targetGuid==nil,'stable passive context stores provisional model separately')
UNITS.target.guid='0xF2'; fire(D.threatCalFrame,'PLAYER_TARGET_CHANGED')
UNITS.target.guid='0xF1'; fire(D.threatCalFrame,'PLAYER_TARGET_CHANGED')
NOW=NOW+0.3
fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT ','TWTv4=Hunter:1:101:100:1','PARTY','Hunter')
check(D.threatCalSession.snapshots[2].contextReason=='target-changed' and not D.threatCalSession.snapshots[2].stableTargetCandidate,'target away and back invalidates old request context')
SendAddonMessage('TWT_UDTSv4','limit=4','PARTY')
fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT ','TWTv4=Hunter:1:102:100:1','PARTY','Hunter')
check(D.threatCalSession.snapshots[3].contextReason=='target-settling','recent target switch excludes comparison')
NOW=NOW+3; SendAddonMessage('TWT_UDTSv4','limit=4','PARTY')
D.segmentSerial=D.segmentSerial+1
fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT ','TWTv4=Hunter:1:103:100:1','PARTY','Hunter')
check(D.threatCalSession.snapshots[4].contextReason=='segment-changed','new segment excludes previous request context')
local requestCount=D.threatCalSession.observedRequests
SendAddonMessage('OTHER','unrelated','PARTY')
check(D.threatCalSession.observedRequests==requestCount,'observer ignores unrelated outbound traffic')
local observeOriginal=D.threatCalObserveRequest
D.threatCalObserveRequest=function() error('test observer failure') end
check(SendAddonMessage('TWT_UDTSv4','limit=4','PARTY')=='original-result','diagnostic failure does not block addon transport')
D.threatCalObserveRequest=observeOriginal
SendAddonMessage=transportOriginal; D.threatCalSendObserver=observerOriginal
D.threatCalNewSession(); D.threatCalEnabled=true
UnitLevel=function(u) if u=='pet' then return 32 elseif u=='player' then return 34 end end
UnitAttackPower=function() return 100,20,-5 end
UnitPowerType=function() return 2 end
GetPetHappiness=function() return 3 end
UnitBuff=function(u,i) if i==1 then return 'texture',1,1234 end end
local contextId=D.threatCalActorContext('0x2',true)
local context=D.threatCalSession.actorContexts[contextId]
check(context.level==32 and context.ownerLevel==34 and context.attackPowerBase==100 and context.attackPowerPositive==20 and context.attackPowerNegative==-5,'pet context preserves levels and observed attack power components')
check(context.buffs[1].spellId==1234 and context.buffScanComplete and context.happiness==3,'pet context records buff IDs and local happiness')
check(D.threatCalActorContext('0x2',false)==contextId,'repeated actor context uses short cache')
UnitLevel=function(u) if u=='pet' then return 33 elseif u=='player' then return 34 end end
D.threatCalRecordEvent({guid='0x2',source='Growl',kind='special',delta=170})
local latestEvent=D.threatCalSession.events[1]
check(D.threatCalSession.actorContexts[latestEvent.actorContextId].level==33,'Growl forces a fresh context after a level change')
UnitBuff=function() error('unavailable buff API') end
UnitAttackPower=function() error('unavailable remote stat') end
local failed=D.threatCalSession.actorContexts[D.threatCalActorContext('0x2',true)]
check(not failed.buffScanComplete and failed.attackPowerBase==nil,'unavailable stats remain unknown instead of invented zeroes')
local unknown=D.threatCalSession.actorContexts[D.threatCalActorContext('0x99',true)]
check(not unknown.available and unknown.level==nil,'unresolved actor retains unavailable context')
local contexts=D.threatCalSession.actorContexts
while table.getn(contexts)<2000 do table.insert(contexts,{}) end
check(D.threatCalActorContext('0x2',true)==nil and table.getn(contexts)==2000,'context cap does not attach stale metadata')
UnitBuff=function() end
D.threatCalEnabled=false
local petActor={guid='0x2',isPet=true}
UnitLevel=function(u) if u=='pet' then return 33 elseif u=='partypet1' then return 29 end end
check(D.threatGrowlValue(petActor,14918)==182,'measured own pet rank 4 level 33 uses 182 without calibration')
PARTY_COUNT=1; UNITS.partypet1={guid='0x22',name='Other Pet'}
check(D.threatGrowlValue({guid='0x22',isPet=true},14917)==146,'measured group pet rank 3 level 29 uses 146')
check(D.threatGrowlValue({guid='0x99',isPet=true},14918)==170,'unresolved GUID cannot borrow another pet level')
UnitLevel=function() return 34 end
check(D.threatGrowlValue(petActor,14918)==170,'unmeasured level retains rank fallback after level change')
UnitLevel=function() error('level unavailable') end
check(D.threatGrowlValue(petActor,14918)==170,'level API failure retains fallback')
UnitLevel=nil
check(D.threatGrowlValue(petActor,14918)==170,'missing level API retains fallback')
local oldRaid=GetNumRaidMembers
GetNumRaidMembers=function() return 2 end
UNITS.raidpet2={guid='0x23',name='Raid Pet'}
UnitLevel=function(u) if u=='raidpet2' then return 29 elseif u=='pet' then return 33 end end
check(D.threatGrowlValue({guid='0x23',isPet=true},14917)==146,'raid pet resolved by GUID')
GetNumRaidMembers=oldRaid
fresh()
D.threatOnCast('0x2','0xF1','CAST',14918)
D.threatOnSpellLanded('0x2','0xF1','Growl')
D.threatOnSpellLanded('0x2','0xF1','Growl')
check(D.actors['0x2'].threat['0xF1']==182,'landed Growl uses measured value once')
NOW=NOW+3
D.threatOnCast('0x2','0xF1','CAST',14918)
D.threatOnCast('0x2','0xF1','FAIL',14918)
D.threatOnSpellLanded('0x2','0xF1','Growl')
check(D.actors['0x2'].threat['0xF1']==182,'failed Growl does not apply measured bonus')
local druid={guid='0x1',classToken='DRUID',name='Druid'}
local formId=5487
UnitBuff=function(unit,index) if index==1 and formId then return 'form',1,formId end end
local talentRank=5
GetNumTalentTabs=function() return 1 end
GetNumTalents=function() return 1 end
GetTalentInfo=function() return 'Feral Instinct','icon',1,1,talentRank,5 end
D.threatFeralTalentAt=nil
check(math.abs(D.threatGlobalModifier(druid)-1.45)<0.00001,'local bear separates 1.3 form and known 5-point talent bonus')
D.threatOnDamage(druid,160,'Maul',false,'0xF1')
check(math.abs(druid.threat['0xF1']-348)<0.00001,'measured Maul 160 produces 348 with known full talent')
D.threatOnDamage(druid,31,'Swipe',false,'0xF2')
check(math.abs(druid.threat['0xF2']-62.93)<0.00001,'Swipe relative factor 1.4 composes with bear and talent')
formId=nil
check(D.threatGlobalModifier(druid)==1,'leaving bear removes form and bear-only talent bonus immediately')
formId=9634; talentRank=0; NOW=NOW+2
check(D.threatGlobalModifier(druid)==1.3,'dire bear with zero talent uses only base modifier')
talentRank=3; NOW=NOW+2
check(math.abs(D.threatGlobalModifier(druid)-1.39)<0.00001,'partial local talent rank supported')
GetTalentInfo=function() return 'Feral Instinct','icon',1,1,3,3 end
NOW=NOW+2
check(math.abs(D.threatGlobalModifier(druid)-1.45)<0.00001,'RavenCraft three-point Feral Instinct supports full bonus')
GetTalentInfo=function() return 'Feral Instinct','icon',1,1,1,3 end
NOW=NOW+2
check(math.abs(D.threatGlobalModifier(druid)-1.35)<0.00001,'three-point talent uses separate per-rank model')
GetTalentInfo=function() return 'Feral Instinct','icon',1,1,3,4 end
NOW=NOW+2
check(D.threatGlobalModifier(druid)==1.3,'unknown custom talent layout does not invent bonus')
PARTY_COUNT=1; UNITS.party1={guid='0xD1',class='DRUID',name='Remote'}
local remote={guid='0xD1',classToken='DRUID'}
check(D.threatGlobalModifier(remote)==1.3,'remote bear never borrows local talent rank')
local base,bonus,knowledge=D.threatDruidModifiers(remote)
check(base==1.3 and bonus==0 and knowledge=='talent-unknown','unknown remote talent explicitly identified')
UnitBuff=function() error('unavailable') end
check(D.threatGlobalModifier(remote)==1,'failed form scan does not keep stale bear modifier')
UnitBuff=function() return nil end
check(D.threatGlobalModifier({guid='0x99',classToken='DRUID'})==1,'unresolved druid cannot borrow another unit form')
local sarvok={guid='0xD8',name='AnyDruid',classToken='DRUID',key='0xD8'}
UNITS.party1={guid=sarvok.guid,name=sarvok.name,class='DRUID'}
UnitBuff=function(unit,index) if index==1 then return 'form',1,5487 end end
check(D.threatGlobalModifier(sarvok)==1.3,'remote talent remains unknown without sync')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~3~3','PARTY','AnyDruid')
check(math.abs(D.threatGlobalModifier(sarvok)-1.45)<0.00001,'any roster druid can announce own talent automatically')
local _,_,confirmedKnowledge=D.threatDruidModifiers(sarvok)
check(confirmedKnowledge=='caw-sync','remote talent sync provenance is explicit')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~0~3','PARTY','Hunter')
check(math.abs(D.threatGlobalModifier(sarvok)-1.45)<0.00001,'another sender cannot announce talents for a roster druid')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~0~3','WHISPER','AnyDruid')
check(math.abs(D.threatGlobalModifier(sarvok)-1.45)<0.00001,'talent sync rejects wrong channel')
UnitBuff=function() end
check(D.threatGlobalModifier(sarvok)==1,'synced talent does not force bear form')
UnitBuff=function(unit,index) if index==1 then return 'form',1,5487 end end
fresh()
D.guidToActor[sarvok.guid]=sarvok
D.threatOnCast(sarvok.guid,'0xF1','CAST',17390)
check(not D.actors[sarvok.guid] or not D.actors[sarvok.guid].threat,'Faerie Fire cast alone does not book threat')
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE',sarvok.guid..' casts Faerie Fire (Feral) on 0xF1.')
local sa=D.actors[sarvok.guid]
check(sa and math.abs(sa.threat['0xF1']-156.6)<0.00001,'Faerie Fire rank 2 RAW success applies measured flat threat and confirmed modifier')
D.threatOnSpellLanded(sarvok.guid,'0xF1','Faerie Fire')
check(math.abs(sa.threat['0xF1']-156.6)<0.00001,'Faerie Fire aura alias cannot double-count committed cast')
NOW=NOW+3
D.threatOnCast(sarvok.guid,'0xF1','CAST',17390)
D.threatOnSpellFailed(sarvok.guid,'0xF1','Faerie Fire')
D.threatOnSpellLanded(sarvok.guid,'0xF1','Faerie Fire (Feral)')
check(math.abs(sa.threat['0xF1']-156.6)<0.00001,'Faerie Fire resist alias cancels pending bonus')
NOW=NOW+3
D.threatOnCast(sarvok.guid,'0xF1','CAST',17390)
check(not D.threatOnSpellLanded(sarvok.guid,'0xF2','Faerie Fire'),'Faerie Fire requires matching target')
NOW=NOW+3
check(not D.threatOnSpellLanded(sarvok.guid,'0xF1','Faerie Fire'),'expired Faerie Fire cannot book threat')
D.threatCalNewSession(); D.threatCalEnabled=true
local ci=D.threatCalActorContext(sarvok.guid,true)
local cc=D.threatCalSession.actorContexts[ci]
check(cc.modifierKnowledge=='caw-sync' and cc.remoteTalents=='caw-sync' and math.abs(cc.modelModifier-1.45)<0.00001,'calibration records synced remote talent provenance and applied modifier')
for i=1,205 do D.threatCalRecordRaw('CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE','0xF1 is afflicted by Faerie Fire.') end
check(table.getn(D.threatCalSession.druidRaw)==200 and D.threatCalSession.druidRawDropped==5,'automatic druid RAW capture stays bounded')
D.threatCalEnabled=false
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~4~3','PARTY','AnyDruid')
check(math.abs(D.threatGlobalModifier(sarvok)-1.45)<0.00001,'invalid talent rank rejected')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~0~3','PARTY','AnyDruid')
check(D.threatGlobalModifier(sarvok)==1.3,'zero talent after respec replaces previous bonus')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~3~3','PARTY','AnyDruid')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~unknown~0','PARTY','AnyDruid')
check(D.threatSyncTalents[sarvok.guid]==nil,'unavailable talent API revokes old state')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~3~3','PARTY','AnyDruid')
NOW=NOW+46
check(D.threatGlobalModifier(sarvok)==1.3,'stale remote talent expires')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~3~3','PARTY','AnyDruid')
UNITS.party1=nil
check(D.threatSyncedFeralInstinct(sarvok)==nil,'departed roster member loses cached talents')
UNITS.player.class='DRUID'
GetTalentInfo=function() return 'Feral Instinct','icon',1,1,3,3 end
local sentTalents={}
local sendTalent=function(msg,channel) table.insert(sentTalents,{msg=msg,channel=channel}); return true end
D.threatSyncTick(sendTalent,'PARTY')
check(table.getn(sentTalents)==1 and sentTalents[1].msg=='T~1~0x1~3~3','local talent announcement uses actual API without character config')
NOW=NOW+1; D.threatSyncTick(sendTalent,'PARTY')
check(table.getn(sentTalents)==1,'unchanged talent does not send every tick')
GetTalentInfo=function() return 'Feral Instinct','icon',1,1,0,3 end
NOW=NOW+1; D.threatSyncTick(sendTalent,'PARTY')
check(table.getn(sentTalents)==2 and sentTalents[2].msg=='T~1~0x1~0~3','local respec automatically broadcasts changed talent')
NOW=NOW+15; D.threatSyncTick(sendTalent,'PARTY')
check(table.getn(sentTalents)==3,'periodic announcement reaches newly joined clients')
NOW=NOW+1; D.threatSyncTick(sendTalent,nil)
check(table.getn(sentTalents)==3,'solo player does not broadcast talents')
fresh()
UNITS.party1={guid='0xD8',name='AnyDruid',class='DRUID'}
D.guidToActor[sarvok.guid]=sarvok
D.threatSyncTalents={}
D.threatOnCast(sarvok.guid,'0xF1','CAST',17390)
NOW=NOW+0.032
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE','0xF1 is afflicted by Faerie Fire (Feral).')
local auraActor=D.actors[sarvok.guid]
check(auraActor and math.abs(auraActor.threat['0xF1']-140.4)<0.00001,'captured casterless Faerie Fire aura books rank 2 with known bear baseline')
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE','0xF1 is afflicted by Faerie Fire (Feral).')
check(math.abs(auraActor.threat['0xF1']-140.4)<0.00001,'duplicate casterless aura cannot double-book threat')
NOW=NOW+3
D.threatOnCast(sarvok.guid,'0xF1','CAST',17390)
fire(D.events,'RAW_COMBATLOG','CHAT_MSG_SPELL_PARTY_DAMAGE',sarvok.guid.."'s Faerie Fire (Feral) was resisted by 0xF1.")
check(not D.threatOnAuraLanded('0xF1','Faerie Fire (Feral)'),'captured resist removes candidate before aura matching')
NOW=NOW+3
D.threatOnCast(sarvok.guid,'0xF1','CAST',17390)
check(not D.threatOnAuraLanded('0xF2','Faerie Fire (Feral)'),'casterless aura cannot borrow another target cast')
NOW=NOW+0.6
check(not D.threatOnAuraLanded('0xF1','Faerie Fire (Feral)'),'casterless aura requires narrow timing window')
NOW=NOW+3
D.threatOnCast(sarvok.guid,'0xF1','CAST',17390)
D.guidToActor['0xD9']={guid='0xD9',key='0xD9',name='SecondDruid',classToken='DRUID'}
D.threatOnCast('0xD9','0xF1','CAST',17390)
check(not D.threatOnAuraLanded('0xF1','Faerie Fire (Feral)'),'simultaneous candidate casters remain ambiguous')
check(math.abs(auraActor.threat['0xF1']-140.4)<0.00001,'unmatched and ambiguous applications do not alter existing threat')
D.threatSyncPeers={}; D.threatSyncTalents={}
local ps,ds=D.threatPeerStatus(sarvok)
check(ps=='not-detected' and ds=='unknown','silent roster member is unconfirmed rather than classified as no addon')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'P~1~0xD8~CawThreat-0.20~fi1','PARTY','AnyDruid')
ps,ds=D.threatPeerStatus(sarvok)
check(ps=='detected' and ds=='feral-instinct-unavailable','capability announcement does not invent usable talent data')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'P~1~0xD8~forged~none','PARTY','Hunter')
check(D.threatSyncPeers['0xD8'].version=='CawThreat-0.20','peer announcement sender must own the roster GUID')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'P~1~0xD8~wrong~none','WHISPER','AnyDruid')
check(D.threatSyncPeers['0xD8'].version=='CawThreat-0.20','peer announcement rejects non-group channels')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~3~3','PARTY','AnyDruid')
ps,ds=D.threatPeerStatus(sarvok)
check(ps=='detected' and ds=='feral-instinct-current','usable data requires actual current talent message')
NOW=NOW+46
ps,ds=D.threatPeerStatus(sarvok)
check(ps=='stale' and ds=='unknown','expired peer is not presented as current')
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'P~1~0xD8~CawThreat-0.20~fi1','PARTY','AnyDruid')
ps,ds=D.threatPeerStatus(sarvok)
check(ps=='detected' and ds=='feral-instinct-unavailable','fresh heartbeat cannot revive expired talent data')
D.threatSyncPeers={}
fire(D.events,'CHAT_MSG_ADDON',D.syncPrefix,'T~1~0xD8~3~3','PARTY','AnyDruid')
ps,ds=D.threatPeerStatus(sarvok)
check(ps=='detected' and ds=='feral-instinct-current','older talent-sync client is detected without new handshake')
UNITS.player.class='HUNTER'
local peerMessages={}
local peerSend=function(msg,ch) table.insert(peerMessages,{msg=msg,ch=ch}); return true end
D.threatPeerNextCheck=nil; D.threatPeerLastChannel=nil
D.threatPeerTick(peerSend,'PARTY')
check(table.getn(peerMessages)==1 and string.find(peerMessages[1].msg,'~none',1,true),'non-druid client announces presence without claiming talent support')
NOW=NOW+1; D.threatPeerTick(peerSend,'PARTY')
check(table.getn(peerMessages)==1,'peer announcement is throttled')
NOW=NOW+15; D.threatPeerTick(peerSend,'PARTY')
check(table.getn(peerMessages)==2,'periodic announcement discovers new group clients')
UNITS.party1=nil
NOW=NOW+1; D.threatPeerTick(peerSend,'PARTY')
check(D.threatSyncPeers['0xD8']==nil,'departed member removed from peer cache')
NOW=NOW+1; D.threatPeerTick(peerSend,nil)
check(table.getn(peerMessages)==2,'no presence broadcast when solo')
local scrollView=D.multiWindows[2] or D.createMultiWindow(nil)
local oldSorted=D.multiViewSortedActors
local scrollList={}
for i=1,25 do scrollList[i]={value=100-i,actor={name='Row'..i,classToken='HUNTER'}} end
D.multiViewSortedActors=function() return scrollList,table.getn(scrollList) end
scrollView.frame:Show(); scrollView.frame:SetHeight(260); scrollView.mode='damage'; scrollView.scrollOffset=0
D.updateMultiWindow(scrollView)
check(scrollView.rows[1].frame:GetHeight()==D.rows[1].frame:GetHeight() and scrollView.scrollTrack:IsShown(),'extra window matches primary row height and displays overflow controls')
check(scrollView.rows[1].classIcon:IsShown() and scrollView.rows[1].classIcon:GetWidth()==18,'extra actor rows display class icons at primary dimensions')
scrollList[1].actor.classToken=nil; D.updateMultiWindow(scrollView)
check(not scrollView.rows[1].classIcon:IsShown(),'reused extra row hides stale icon for unknown class')
scrollList[1].actor.classToken='HUNTER'; D.updateMultiWindow(scrollView)
local primaryOffset=D.scrollOffset
D.scrollMultiWindow(scrollView,100)
check(scrollView.scrollOffset==18 and scrollView.rows[7].actor.name=='Row25' and D.scrollOffset==primaryOffset,'extra scrolling reaches final actor and remains independent of primary')
scrollView.frame:SetHeight(600); D.updateMultiWindow(scrollView)
check(scrollView.scrollOffset==5,'resizing reclamps extra window scroll offset')
scrollList={scrollList[1],scrollList[2]}; D.updateMultiWindow(scrollView)
check(scrollView.scrollOffset==0 and not scrollView.scrollTrack:IsShown() and not scrollView.scrollUp:IsShown(),'short lists reset offset and hide extra scroll controls')
D.multiViewSortedActors=oldSorted
pfUI={chat={right=CreateFrame('Frame','MockPfChat',UIParent)}}
pfUI.chat.right:SetFrameStrata('BACKGROUND')
D.window:Show(); scrollView.frame:Show()
D.pfDockToggle(nil); D.pfDockToggle(scrollView)
check(D.window.parent==UIParent and scrollView.frame.parent==UIParent,'docked windows retain independent UIParent input hierarchy')
check(scrollView.frame.lastPoint[2]==D.window and scrollView.frame.lastPoint[3]=='BOTTOMLEFT' and scrollView.frame.lastPoint[4]==0 and scrollView.frame.lastPoint[5]==0,'docked windows attach directly edge-to-edge without summed width offsets')
check(D.window:GetFrameStrata()=='HIGH' and scrollView.lockButton:GetFrameStrata()=='HIGH' and scrollView.lockButton:GetFrameLevel()>scrollView.frame:GetFrameLevel(),'window buttons are above their own backgrounds and pfUI chat')
check(D.window.lastPoint[3]=='BOTTOMRIGHT' and scrollView.frame.lastPoint[2]==D.window,'docking roots the window chain inside chat instead of above it')
local oldLocked=scrollView.locked
this=scrollView.lockButton; arg1='LeftButton'; this.scripts.OnClick()
check(scrollView.locked~=oldLocked,'docked extra lock button retains left-click action')
this=scrollView.lockButton; arg1='LeftButton'; this.scripts.OnClick()
pfUI.chat.right:Hide()
D.pfDockUpdate()
check(not D.window:IsVisible() and not scrollView.frame:IsVisible(),'pfUI arrow visibility hides both docked windows')
D.saveMultiWindows()
check(CawDPSMeterCharDB.extraWindows[1].pfDock and CawDPSMeterCharDB.extraWindowCount>0,'parent-hidden docked extra survives saving')
D.pfDockToggle(scrollView)
check(scrollView.frame.parent==UIParent and scrollView.frame:IsVisible() and not D.window:IsVisible(),'undocked extra stays visible independently of hidden chat')
check(scrollView.lockButton:GetFrameLevel()>scrollView.frame:GetFrameLevel() and scrollView.frame:GetFrameStrata()=='HIGH','free extra retains usable foreground hierarchy after undocking')
pfUI.chat.right:Show()
D.pfDockUpdate()
check(D.window:IsVisible(),'pfUI arrow restores docked main')
D.pfDockToggle(nil)
check(D.window.parent==UIParent and not D.window.cawDockFree,'undocking restores free parent and clears docking state')
pfUI=nil
D.pfDockToggle(nil)
check(not CawDPSMeterCharDB.pfDockMain,'missing pfUI does not enable docking')
pfUI={chat={right=CreateFrame('Frame',nil,UIParent)}}
CawDPSMeterCharDB.pfDockRevision=nil; CawDPSMeterCharDB.pfDockMain=true; scrollView.pfDock=true
D.window:Hide(); scrollView.frame:Hide()
D.pfDockUpdate()
check(D.window:IsVisible() and scrollView.frame:IsVisible() and not scrollView.pfDock and not CawDPSMeterCharDB.pfDockMain,'old docking settings recover both windows visibly once')
D.pfDockToggle(nil); D.pfDockUpdate()
check(CawDPSMeterCharDB.pfDockMain,'recovery migration does not disable newly enabled docking')
D.pfDockToggle(nil); pfUI=nil
local menuFrame=scrollView.modeMenu
D.pfDockLayerTree(scrollView.frame,20,'HIGH')
check(menuFrame:GetFrameStrata()=='DIALOG' and menuFrame:GetFrameLevel()>scrollView.rows[1].bar:GetFrameLevel(),'dropdown retains explicit layer above player bars when window layers refresh')
local narrowRows={D.rows[1],scrollView.rows[1]}
for _,nr in ipairs(narrowRows) do
    nr.actor={name='Somebody',classToken='HUNTER'}; nr.bar:SetWidth(150); nr.right:SetText('123 | 45')
    D.fitBarActorName(nr,'Somebody',58)
    check(not nr.classIcon:IsShown() and nr.left:GetText()=='Somebody','narrow primary or extra row drops icon before losing readable name')
    nr.bar:SetWidth(300); D.fitBarActorName(nr,'Somebody',58)
    check(nr.classIcon:IsShown() and nr.rank.lastPoint[4]==24,'widening row restores class icon and normal rank spacing')
end
fresh()
UNITS.target={guid='0xF1',name='Normal Mob',hostile=true}; PARTY_COUNT=1
UnitClassification=function() return 'normal' end
IsAddOnLoaded=function() return false end
D.threatCalEnabled=false; D.threatCalPendingRequests={}; D.threatCalStart(); D.threatCalAttributionUncertain=false
D.actors['0x1']={name='Hunter',key='0x1',guid='0x1',classToken='HUNTER',threat={['0xF1']=100}}
NOW=NOW+3
check(D.threatCalSendRequest(),'standalone Caw queries normal hostile combat targets without TWThreat')
NOW=NOW+0.05
fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT ','TWTv4=Hunter:1:777:100:1','PARTY','Hunter')
local serverView=D.serverThreatCurrent()
check(serverView and D.threatValueForActor(serverView.actors[1])==777 and D.threatPercentForActor(serverView.actors[1])==100,'own API reply supplies server threat and server percentage to display')
check(D.actors['0x1'].threat['0xF1']==100 and serverView.actors[1]._serverLocalValue==100,'server display leaves local threat untouched for calibration')
check(table.getn(D.threatCalSession.snapshots)==1,'standalone reply also saved for calibration')
NOW=NOW+1.3
check(not D.serverThreatCurrent() and D.serverThreatActors()==D.actors,'expired server view returns explicitly to local estimates')
NOW=NOW+2; D.threatCalSendRequest(); NOW=NOW+0.05
D.threatCalMaxSnapshots=0
fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT ','TWTv4=Hunter:1:778:100:1','PARTY','Hunter')
check(D.serverThreatCurrent() and D.threatValueForActor(D.serverThreatCurrent().actors[1])==778,'recording cap does not freeze the live server display')
D.threatCalMaxSnapshots=6000
UNITS.target.guid='0xF2'; D.threatCalObserveTarget()
check(not D.serverThreatCurrent(),'target switch immediately invalidates server display')
UNITS.target.guid='0xF1'; D.threatCalObserveTarget()
check(not D.serverThreatCurrent(),'switching back cannot revive old server snapshot')
NOW=NOW+3; D.threatCalSendRequest(); NOW=NOW+0.05; D.threatCalAttributionUncertain=true
fire(D.threatCalFrame,'CHAT_MSG_ADDON','TWT ','TWTv4=Hunter:1:999:100:1','PARTY','Hunter')
check(not D.serverThreatCurrent(),'uncertain timeout or parallel-probe state cannot publish server values')
D.threatCalEnabled=false
print("Checks: "..count)

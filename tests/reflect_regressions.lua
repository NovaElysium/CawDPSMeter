local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print("PASS REFLECT "..label) end
-- Earlier suites may leave DPSLog probing or parsing paused; the combat-text parser needs a clean slate.
CawDPSMeterCharDB.parserEnabled=true
D.dpsLogProbing=false; D.dpsLogActive=false; D.dpsLogQueue={}; D.dpsLogRawCommitted=false; D.dpsLogInitialized=false; D.dpsLogFallback=nil
CombatLogGetCurrentEventInfo=nil
local function fresh()
    SlashCmdList.CAWDPS("reset")
    D.lastFinalizeAt=0; NOW=NOW+10; PLAYER_COMBAT=true
end
local ON_SELF,ON_OTHERS='CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF','CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS'
local function raw(ev,text) fire(D.events,'RAW_COMBATLOG',ev,text) end
local function spellDamage(actor,name) local s=actor.spells and actor.spells[name]; return s and s.damage or 0 end

-- Thorns and Retribution Aura damage of the local player counts as player damage.
fresh()
raw('CHAT_MSG_COMBAT_SELF_HITS','You hit 0xF1 for 100.')
local me=D.actors['0x1']
raw(ON_SELF,'You reflect 8 Nature damage to 0xF1.')
check(me.damage==108 and spellDamage(me,'Damage Shield (Nature)')==8,"own Thorns damage is added with its school")
raw(ON_SELF,'You reflect 12 Holy damage to 0xF1.')
check(me.damage==120 and spellDamage(me,'Damage Shield (Holy)')==12,"own Retribution Aura damage is a separate Holy entry")
check(D.currentEnemyDamage['0xF1']==120,"reflected damage counts toward the enemy's damage taken")
check(me.threat['0xF1']==120,"reflected damage generates threat like other damage")
raw(ON_SELF,'You reflect 5 Fire damage to 0xF1. (2 resisted)')
check(me.damage==125,"trailing resist details do not stop the line from parsing")

-- Other group members and their pets.
local savedParty,savedPartyCount=UNITS.party1,PARTY_COUNT
PARTY_COUNT=1; UNITS.party1={guid="0x3",name="Friend",class="HUNTER"}
fire(D.events,"PARTY_MEMBERS_CHANGED")
raw('CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE',"0x3's Auto Shot hits 0xF1 for 80.")
local other=D.actors['0x3']
raw(ON_OTHERS,'0x3 reflects 9 Nature damage to 0xF1.')
check(other.damage==89 and spellDamage(other,'Damage Shield (Nature)')==9,"a group member's Thorns damage is credited to that member")
D.guidToActor['0x2']={name='Wolf',guid='0x2',key='0x2',isPet=true,ownerKey='0x1'}
local before=D.parsedTotal
raw(ON_OTHERS,'0x2 reflects 4 Nature damage to 0xF1.')
check(D.parsedTotal==before+1 and D.actors['0x2'] and D.actors['0x2'].isPet and D.actors['0x2'].ownerKey=='0x1' and spellDamage(D.actors['0x2'],'Damage Shield (Nature)')==4,"a pet's shield damage is credited to the pet")

-- Things that must never count as player damage.
local meDamage,otherDamage=me.damage,other.damage
local ignored=D.ignoredOutsiders
raw(ON_OTHERS,'0xF1 reflects 7 Nature damage to 0x1.')
check(me.damage==meDamage and D.ignoredOutsiders==ignored+1,"an enemy's own shield hitting the group is not player damage")
raw(ON_OTHERS,'0x99 reflects 7 Nature damage to 0xF1.')
check(D.actors['0x99']==nil and D.ignoredOutsiders==ignored+2,"players outside the roster are ignored")
raw(ON_OTHERS,'0x3 reflects 7 Holy damage to 0x1.')
check(other.damage==otherDamage and me.damage==meDamage,"a shield never counts for hitting a group member")
raw(ON_SELF,'You reflect 7 Nature damage to 0x3.')
check(me.damage==meDamage,"reflected damage on a friendly target is ignored")
raw(ON_SELF,'You reflect 0 Nature damage to 0xF1.')
check(me.damage==meDamage,"zero damage changes nothing")

-- DPSLog supplies DAMAGE_SHIELD itself, so the combat-text parser must stay out of the way.
local savedActive=D.dpsLogActive; D.dpsLogActive=true
local logged=D.parsedTotal
D.parseRawReplay(ON_SELF,'You reflect 11 Nature damage to 0xF1.')
check(D.parsedTotal==logged and me.damage==meDamage,"reflect text is not double counted while DPSLog is active")
D.dpsLogActive=savedActive

-- Unknown event names still reach the parser through the text fallback.
D.parseRawReplay('CHAT_MSG_SPELL_CUSTOM_REFLECT','You reflect 6 Nature damage to 0xF1.')
check(me.damage==meDamage+6,"reflect lines under an unrecognised event name still count")

UNITS.party1=savedParty; PARTY_COUNT=savedPartyCount
-- Totals feed the reports like any other spell.
check(me.spells['Damage Shield (Nature)'].hits==2 and me.spells['Damage Shield (Nature)'].damage==14,"each counted reflect line is one hit in the ability breakdown")
print("Reflect checks: "..checks)

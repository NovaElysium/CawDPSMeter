"""Fresh Lua clients exercise SavedVariables across reloads, alts and pfUI hiding."""
import os
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(os.environ.get('TEMP', '/tmp')) / 'caw-review-lupa'))
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
ADDON = Path(os.environ.get('CAW_TEST_ADDON_ROOT', ROOT))

def client(account='{}', character='{}', chat_hidden=False):
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute((ROOT / 'tests/mock_wow.lua').read_text(encoding='utf-8'))
    vm.execute('''
        UIParent:SetWidth(1920); UIParent:SetHeight(1080)
        UIParent.GetCenter=function() return 960,540 end
        UIParent.GetLeft=function() return 0 end; UIParent.GetBottom=function() return 0 end
        UIParent.GetRight=function() return 1920 end; UIParent.GetTop=function() return 1080 end
        local create=CreateFrame
        CreateFrame=function(...)
            local f=create(unpack(arg))
            f.GetPoint=function(self) return unpack(self.lastPoint or {'CENTER',UIParent,'CENTER',0,0}) end
            f.GetCenter=function(self)
                local p=self.lastPoint
                if p and p[1]=='CENTER' and p[2]==UIParent and p[3]=='CENTER' then
                    local scale=self:GetEffectiveScale()
                    return 960/scale+p[4],540/scale+p[5]
                end
                return 960,540
            end
            f.GetLeft=function(self) local x=self:GetCenter(); return x-self:GetWidth()/2 end
            f.GetRight=function(self) local x=self:GetCenter(); return x+self:GetWidth()/2 end
            f.GetTop=function(self) local _,y=self:GetCenter(); return y+self:GetHeight()/2 end
            f.GetBottom=function(self) local _,y=self:GetCenter(); return y-self:GetHeight()/2 end
            return f
        end
        pfUI={chat={right=CreateFrame('Frame',nil,UIParent)}}
        function snapshot(value)
            if type(value)=='table' then
                local out={}
                for k,v in pairs(value) do table.insert(out,'['..snapshot(k)..']='..snapshot(v)) end
                table.sort(out)
                return '{'..table.concat(out,',')..'}'
            elseif type(value)=='string' then return string.format('%q',value)
            else return tostring(value) end
        end
    ''')
    for line in (ADDON / 'CawDPSMeter.toc').read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.startswith('#'):
            continue
        code = (ADDON / line.strip()).read_text(encoding='utf-8')
        code = re.sub(r'\b(for\s+\w+(?:\s*,\s*\w+)*\s+in\s+)([\w.]+(?:\[[^\]\n]+\])?)\s+do\b',
                      r'\1pairs(\2) do', code)
        vm.execute(code, name=line)
    # WoW loads SavedVariables after the addon files, before ADDON_LOADED.
    vm.execute('CawDPSMeterDB=' + account + '; CawDPSMeterCharDB=' + character)
    if chat_hidden:
        vm.execute('pfUI.chat.right:Hide()')
    vm.execute('''
        D=CAW_DPS_METER
        fire(D.diagBootstrapFrame,'ADDON_LOADED','CawDPSMeter')
        fire(D.events,'ADDON_LOADED','CawDPSMeter')
        local before=snapshot(CawDPSMeterDB)
        D.uiSaveMain(); D.saveMultiWindows(); D.uiPersist()
        assert(snapshot(CawDPSMeterDB)==before,'early save overwrote unrestored settings')
        fire(D.events,'PLAYER_ENTERING_WORLD'); D.pfDockUpdate()
    ''')
    return vm

def save(vm):
    vm.execute("fire(D.events,'PLAYER_LOGOUT')")
    return vm.eval('snapshot(CawDPSMeterDB)'), vm.eval('snapshot(CawDPSMeterCharDB)')

def check(vm, code, label):
    vm.execute(code)
    print('PASS PERSISTENCE ' + label)

account = '''{layoutSaved=true,layoutVersion=4,width=440,height=222,centerX=-530,centerY=-50,
    appearance={scale=0.65,rowHeight=24,hideRaid=true},locked=true}'''
character = '''{mode='damage',segment='overall',pfDockMain=true,pfDockAlternate=false,pfDockRevision=2,
    bagLayerAlwaysBehind=true,combatSyncEnabled=false,parserEnabled=false,
    extraWindowsExplicit=true,extraWindowsVersion=3,extraWindowCount=1,
    extraWindows={{mode='threat',segment='current',width=315,height=185,centerX=210,centerY=-150,
        locked=true,pfDock=true,appearance={scale=0.8,rowHeight=19,hideRaid=true}}}}'''
vm = client(account, character)
layout_check = '''
    local v=D.multiWindows[2]
    assert(v and not D.multiWindows[3] and v.mode=='threat' and v.pfDock and v.locked)
    assert(v.frame:GetWidth()==315 and v.frame:GetHeight()==185 and v.appearance.scale==0.8)
    assert(v.appearance.rowHeight==19 and v.appearance.hideRaid)
    assert(D.window:GetWidth()==440 and D.window:GetHeight()==222 and D.window:GetScale()==0.65)
    assert(D.mode=='damage' and D.segment=='overall' and D.appearance.rowHeight==24 and D.locked)
    assert(CawDPSMeterCharDB.pfDockMain and CawDPSMeterCharDB.pfDockRevision==2)
    assert(math.abs(D.window.cawDockFree.x+530)<0.0001 and math.abs(D.window.cawDockFree.y+50)<0.0001)
    assert(math.abs(v.frame.cawDockFree.x-210)<0.0001 and math.abs(v.frame.cawDockFree.y+150)<0.0001)
'''
check(vm, layout_check, 'legacy two-window docked layout migrates without losing appearance or free positions')
account, main_character = save(vm)
for i in range(3):
    vm = client(account, main_character, chat_hidden=(i == 1))
    check(vm, layout_check, f'fresh client {i+1} restores the full docked layout')
    if i == 1:
        check(vm, "assert(not D.window:IsShown() and not D.multiWindows[2].frame:IsShown())",
              'pfUI arrow-hidden windows stay hidden without becoming closed')
    account, main_character = save(vm)

vm = client(account, "{extraWindowsExplicit=true,extraWindowCount=0,extraWindows={},mode='healing',combatSyncEnabled=true,parserEnabled=true}")
check(vm, layout_check + "assert(CawDPSMeterCharDB.combatSyncEnabled and CawDPSMeterCharDB.parserEnabled)",
      'stale alt layout cannot replace shared windows; alt recording preferences remain independent')
vm.execute("SlashCmdList.CAWDPS('hide')")
account, alt_character = save(vm)
vm = client(account, alt_character)
check(vm, layout_check + "assert(not D.window:IsShown() and not D.multiWindows[2].frame:IsShown())",
      'manual hide preserves both layouts and visibility across a fresh login')
vm.execute("SlashCmdList.CAWDPS('show'); D.removeMultiWindow(D.multiWindows[2])")
account, alt_character = save(vm)
vm = client(account, main_character)
check(vm, "assert(not D.multiWindows[2] and CawDPSMeterCharDB.extraWindowCount==0 and #CawDPSMeterCharDB.closedWindows==1)",
      'returning to an old character never resurrects a closed extra window')
vm.execute("D.createMultiWindow(nil); D.saveMultiWindows(); D.pfDockUpdate()")
check(vm, layout_check, 'explicit Add restores the closed window on another character')
account, main_character = save(vm)
vm = client('{}', main_character)
check(vm, layout_check, 'complete character backup restores a missing account layout')
vm.execute('''
    D.pfDockToggle(nil); D.pfDockToggle(D.multiWindows[2]); D.pfDockToggleVisibility()
    D.uiAnchorCenter(D.window,-430,100)
    fire(D.events,'PLAYER_ENTERING_WORLD')
    local x,y=D.uiCenterOffset(D.window)
    assert(math.abs(x+430)<0.0001 and math.abs(y-100)<0.0001,'zone event restored stale main position')
''')
account, main_character = save(vm)
vm = client(account, '{}')
check(vm, '''
    assert(not CawDPSMeterCharDB.pfDockMain and not D.multiWindows[2].pfDock and CawDPSMeterCharDB.pfDockAlternate)
    local x,y=D.uiCenterOffset(D.window)
    assert(math.abs(x+430)<0.0001 and math.abs(y-100)<0.0001)
''', 'dock controls persist account-wide and zoning does not overwrite a moved free window')
print('Fresh-client persistence checks complete.')

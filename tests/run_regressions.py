"""Behavioral checks with a mocked WoW UI and Lua 5.1 via Lupa.

Only legacy `for k,v in table do` is adapted in memory for the test VM.
The shipped Lua files stay Lua 5.0 source. This is not a client smoke test.
Install lupa in your Python environment, or in %TEMP%/caw-review-lupa.
"""
from pathlib import Path
import os
import re
import sys

sys.path.insert(0, str(Path(os.environ.get('TEMP', '/tmp')) / 'caw-review-lupa'))
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = Path(os.environ.get('CAW_TEST_ADDON_ROOT', ROOT))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / 'tests/mock_wow.lua').read_text(encoding='utf-8'))
for name in ('CawDiagnostics.lua', 'CawHeader.lua', 'CawDPSMeter.lua', 'CawDPSLog.lua', 'CawThreat.lua', 'CawThreatSync.lua', 'CawTalentSync.lua',
             'CawThreatCalibration.lua', 'CawServerThreat.lua', 'CawDiagnosticsCommands.lua', 'CawPfUI.lua', 'CawUI.lua', 'CawTalentView.lua', 'CawBreakdown.lua'):
    code = (ADDON_ROOT / name).read_text(encoding='utf-8')
    code = re.sub(r'\b(for\s+\w+(?:\s*,\s*\w+)*\s+in\s+)([\w.]+(?:\[[^\]\n]+\])?)\s+do\b',
                  r'\1pairs(\2) do', code)
    lua.execute(code, name=name)
lua.execute((ROOT / 'tests/regressions.lua').read_text(encoding='utf-8'))
lua.execute((ROOT / 'tests/ui_regressions.lua').read_text(encoding='utf-8'))
lua.execute((ROOT / 'tests/ui_release_regressions.lua').read_text(encoding='utf-8'))
lua.execute((ROOT / 'tests/threat_alert_regressions.lua').read_text(encoding='utf-8'))
private = ADDON_ROOT / 'CawLocalSyncStatus.lua'
if private.exists():
    lua.execute(private.read_text(encoding='utf-8'), name=private.name)
    lua.execute((ROOT / 'tests/local_ui_regressions.lua').read_text(encoding='utf-8'))

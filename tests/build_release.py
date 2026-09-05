"""Package only public runtime files; verify archive bytes and produce SHA-256."""
from pathlib import Path
import hashlib
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
toc = (ROOT / 'CawDPSMeter.toc').read_text(encoding='utf-8')
version = re.search(r'^## Version: (.+)$', toc, re.M).group(1).strip()
assert version == '1.0.8'
assert 'D.version = "1.0.8"' in (ROOT / 'CawDPSMeter.lua').read_text(encoding='utf-8')
runtime = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith('#')]
files = sorted(set(runtime + ['CawDPSMeter.toc', 'LICENSE', 'README.md', 'CHANGELOG.md',
                             'RELEASE_NOTES_1.0.8.md'] +
                   [p.relative_to(ROOT).as_posix() for p in (ROOT / 'Media').glob('*.tga')]))
stage = ROOT / '.release' / 'package' / 'CawDPSMeter'
out = ROOT / 'dist'
out.mkdir(exist_ok=True)
archive = out / f'CawDPSMeter-{version}.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in files:
        src = ROOT / name
        assert src.is_file(), name
        dst = stage / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        z.writestr('CawDPSMeter/' + name, src.read_bytes())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert len(z.namelist()) == len(files)
    for name in files:
        assert z.read('CawDPSMeter/' + name) == (ROOT / name).read_bytes()
    for name in runtime:
        text = (ROOT / name).read_text(encoding='utf-8')
        for media in re.findall(r'(Caw[A-Za-z]+\.tga)', text):
            assert 'Media/' + media in files, media
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(out / (archive.name + '.sha256')).write_text(digest + '  ' + archive.name + '\n', encoding='utf-8')
shutil.copyfile(ROOT / 'RELEASE_NOTES_1.0.8.md', out / 'RELEASE_NOTES_1.0.8.md')

# Populate an already-cloned public checkout, never copy saved data/private notes.
checkout = ROOT / '.release' / 'github-source'
if (checkout / '.git').is_dir():
    for name in files:
        dst = checkout / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dst)
    for src in (ROOT / 'tests').iterdir():
        if src.name in ('run_regressions.py', 'regressions.lua', 'mock_wow.lua', 'build_release.py', 'run_sync_integration.py'):
            dst = checkout / 'tests' / src.name
            dst.parent.mkdir(exist_ok=True)
            shutil.copyfile(src, dst)
print(f'{archive}\n{len(files)} verified files; SHA256 {digest}\nStaged addon: {stage}')

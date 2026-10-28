"""Read-only inputs; create a recoverable Phase 8 checkpoint and integrity evidence."""
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
OUT = ROOT / 'artifacts/phase9'
OUT.mkdir(parents=True, exist_ok=True)

def digest(data):
    return hashlib.sha256(data).hexdigest().upper()

def git(*args):
    return subprocess.check_output(['git', '-C', str(REPO), *args])

def archive_check(path):
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        files = [i for i in archive.infolist() if not i.is_dir()]
        mismatches = [i.filename for i in files if not (ROOT / i.filename).is_file()
                      or archive.read(i) != (ROOT / i.filename).read_bytes()]
        return dict(path=str(path), sha256=digest(path.read_bytes()), bytes=path.stat().st_size,
                    entries=len(archive.infolist()), files=len(files), source_mismatches=mismatches)

phase8 = archive_check(ROOT / 'dist/Zepholume-Shaders-1.0.6-dev-phase8.zip')
assert phase8['sha256'] == 'CBCEAF7BE8CD50B6C7DC4141F27CE05D4C4735DA69EC6B8096C82D21A92C880B'
assert not phase8['source_mismatches']
protected = []
for row in json.loads((ROOT / 'artifacts/phase8/baseline-hashes.json').read_text(encoding='utf-8-sig')):
    path = Path(row['Path'])
    actual = digest(path.read_bytes()) if path.is_file() else None
    protected.append(dict(path=str(path), expected=row['Hash'], actual=actual, unchanged=actual == row['Hash']))
# A user-owned live session can legitimately rotate the normal log/settings.
# Retain initial evidence and report differences without restoring those files.

checkpoint = OUT / 'phase8-checkpoint.zip'
if not checkpoint.exists():
    paths = git('ls-files', '--cached', '--others', '--exclude-standard', '-z').decode().split('\0')
    # The helper itself is Phase 9; exclude it from the Phase 8 checkpoint.
    paths = [p for p in paths if p and p != 'Zepholume-Shaders/scripts/phase9-integrity.py']
    with zipfile.ZipFile(checkpoint, 'x', zipfile.ZIP_DEFLATED) as archive:
        for name in paths:
            path = REPO / name
            if path.is_file():
                archive.write(path, 'working-tree/' + name)
        archive.writestr('git/head.txt', git('rev-parse', 'HEAD'))
        archive.writestr('git/branch.txt', git('branch', '--show-current'))
        archive.writestr('git/status.txt', git('status', '--short'))
        archive.writestr('git/tracked.patch', git('diff', '--binary', 'HEAD'))
        archive.write(ROOT / 'dist/Zepholume-Shaders-1.0.6-dev-phase8.zip', 'candidate/phase8.zip')
    with zipfile.ZipFile(checkpoint) as archive:
        assert archive.testzip() is None
        for name in paths:
            path = REPO / name
            if path.is_file():
                assert archive.read('working-tree/' + name) == path.read_bytes()

with zipfile.ZipFile(ROOT / 'dist/Zepholume-Shaders-1.0.6-dev-phase7.zip') as a, zipfile.ZipFile(ROOT / 'dist/Zepholume-Shaders-1.0.6-dev-phase8.zip') as b:
    changed = [name for name in sorted(set(a.namelist()) | set(b.namelist()))
               if name not in a.namelist() or name not in b.namelist() or a.read(name) != b.read(name)]
report = dict(phase8=phase8, phase7_sha256=digest((ROOT / 'dist/Zepholume-Shaders-1.0.6-dev-phase7.zip').read_bytes()),
              packaged_changes_from_phase7=changed, protected=protected,
              checkpoint=dict(path=str(checkpoint), sha256=digest(checkpoint.read_bytes())),
              branch=git('branch', '--show-current').decode().strip(), head=git('rev-parse', 'HEAD').decode().strip())
report_path = OUT / ('integrity-final.json' if (OUT / 'integrity.json').exists() else 'integrity.json')
report_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k != 'protected'}, indent=2))
print(f"Protected unchanged: {sum(row['unchanged'] for row in protected)}/{len(protected)}")

"""Independently inspect a final pack without changing source or archives."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--repeat', type=Path, required=True)
    parser.add_argument('--export', type=Path)
    parser.add_argument('--protected', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--source-commit', help='Frozen source revision; defaults to current HEAD')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    git = lambda *parts: subprocess.check_output(['git', '-C', str(root.parent), *parts], text=True).strip()
    source_commit = git('rev-parse', args.source_commit or 'HEAD')
    sources = {p.relative_to(root).as_posix(): p for p in (root / 'shaders').rglob('*') if p.is_file()}
    sources.update({name: root / name for name in ('README.md', 'CHANGELOG.md', 'THIRD_PARTY_NOTICES.md')})
    entries = []
    with zipfile.ZipFile(args.archive) as archive:
        assert archive.testzip() is None, 'CRC failure'
        names = archive.namelist()
        assert len(names) == len(set(names)), 'Duplicate archive paths'
        assert len(names) == len({name.casefold() for name in names}), 'Case-colliding paths'
        assert set(names) == set(sources), 'Archive/source inventory mismatch'
        for entry in archive.infolist():
            name = entry.filename
            assert not entry.is_dir() and '\\' not in name and not name.startswith('/'), name
            assert '..' not in name.split('/'), name
            assert entry.date_time == (1980, 1, 1, 0, 0, 0), name
            data = archive.read(entry)
            assert data == sources[name].read_bytes(), f'Source mismatch: {name}'
            committed = subprocess.check_output(['git', '-C', str(root.parent), 'show', f'{source_commit}:{root.name}/{name}'])
            assert committed.replace(b'\r\n', b'\n') == data.replace(b'\r\n', b'\n'), f'Frozen commit mismatch: {name}'
            entries.append(dict(path=name, size=len(data), sha256=sha(data), crc32=f'{entry.CRC:08X}'))
        properties = archive.read('shaders/shaders.properties').decode('utf-8-sig')
        profiles = [line.split('=', 1)[0].strip().removeprefix('profile.')
                    for line in properties.splitlines() if line.startswith('profile.') and '=' in line]
        assert profiles == ['Potato', 'Low', 'Balanced', 'High', 'Ultra'], profiles
        root_programs = sorted(name for name in names if name.startswith('shaders/')
                               and name.count('/') == 1 and name.endswith(('.vsh', '.fsh')))
        assert len(root_programs) == 28, root_programs
        for name in root_programs:
            for dimension in ('world0', 'world-1', 'world1'):
                assert f'shaders/{dimension}/{name.split("/")[-1]}' in names
        assert 'shaders/lang/en_US.lang' in names
        assert all(b'#define ZEPH_LIGHTMAP_LIT_PROGRAM' in archive.read(f'shaders/{prefix}gbuffers_hand.fsh')
                   for prefix in ('', 'world0/', 'world-1/', 'world1/'))
    digest = sha(args.archive.read_bytes())
    manifest = json.loads(Path(str(args.archive) + '.manifest.json').read_text(encoding='utf-8-sig'))
    assert manifest['archiveSha256'] == digest and manifest['commit'] == source_commit
    assert manifest['sourceState'] == 'clean', 'Package was not built from a clean checkout'
    assert {entry['path']: entry['sha256'] for entry in manifest['entries']} == {entry['path']: entry['sha256'] for entry in entries}
    assert Path(str(args.archive) + '.sha256').read_text(encoding='utf-8-sig').split()[0] == digest
    assert args.archive.read_bytes() == args.repeat.read_bytes(), 'Rebuild differs'
    if args.export:
        assert args.export.read_bytes() == args.archive.read_bytes(), 'Export differs'
    protected = json.loads(args.protected.read_text(encoding='utf-8-sig'))
    for row in protected:
        path = Path(row['path'])
        assert path.is_file() and path.stat().st_size == row['size'] and sha(path.read_bytes()) == row['sha256'], f'Protected file changed: {path}'
    snapshot = ''.join(f'{entry["path"]}\0{entry["sha256"]}\n' for entry in sorted(entries, key=lambda row: row['path']))
    report = dict(artifactStatus='Final ZIP successfully exported', staticValidation='Passed',
                  runtimeQualification='Not tested', archive=str(args.archive.resolve()),
                  size=args.archive.stat().st_size, entryCount=len(entries), sha256=digest,
                  sourceSnapshotSha256=sha(snapshot.encode('utf-8')), sourceSnapshotAlgorithm='SHA256 of ordinal path + NUL + uppercase file SHA256 + LF for every packaged file',
                  branch=git('branch', '--show-current'), commit=git('rev-parse', 'HEAD'),
                  sourceCommit=source_commit, packageManifestState=manifest['sourceState'],
                  gitStatus=git('status', '--porcelain'), repeat=str(args.repeat.resolve()),
                  byteIdenticalRebuild=True, export=str(args.export.resolve()) if args.export else None,
                  protectedFilesUnchanged=len(protected), profiles=profiles, entries=entries)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    assert not args.report.exists(), 'Refusing to overwrite verification evidence'
    args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in report.items() if key != 'entries'}, indent=2))


if __name__ == '__main__':
    main()

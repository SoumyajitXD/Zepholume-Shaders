"""Compare isolated Phase 2/3 specializations with native RGBA32F draws.

The baseline must be a Phase 3 source copy with only the four specialization
includes and hand vertex wrappers restored from Phase 2. Both variant corpora
must be generated with generate-compiled-variants.ps1. This is a synthetic
standalone Intel WGL fixture, not a loader or game test.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import shutil
import struct
import subprocess
import sys
from pathlib import Path


def draw(variants, source, output, profile, dimension, program, extra=()):
    cmd = [sys.executable, str(Path(__file__).with_name('native-gl-render.py')),
           '--variant-root', str(variants), '--source-root', str(source),
           '--output-dir', str(output), '--profile', profile, '--dimension', dimension,
           '--program', program, '--alpha', '0.37', '--light', '0.42',
           '--fog-start', '0.2', '--fog-end', '1.4', '--rain', '0.4', '--skip-png', *extra]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f'{profile}/{dimension}/{program}: {result.stderr or result.stdout}')
    raw = (output / 'pixels.rgba32f').read_bytes()
    pixels = struct.unpack('<' + 'f' * (len(raw) // 4), raw)
    return pixels, json.loads((output / 'result.json').read_text(encoding='utf-8'))


def compare(a, b):
    assert len(a) == len(b) and len(a) % 4 == 0
    assert all(math.isfinite(x) for x in (*a, *b))
    diffs = [abs(x-y) for x,y in zip(a,b)]
    return {'max_rgb': max(d for i,d in enumerate(diffs) if i % 4 != 3),
            'max_alpha': max(diffs[3::4]),
            'rms_rgba': math.sqrt(sum(d*d for d in diffs) / len(diffs)),
            'different_pixels': sum(any(diffs[i+j] != 0 for j in range(4)) for i in range(0,len(diffs),4)),
            'alpha_mismatch_pixels': sum(d != 0 for d in diffs[3::4])}


def mutate_variant(root, destination):
    shutil.copytree(root, destination)
    index_path = destination / 'index.json'
    rows = json.loads(index_path.read_text(encoding='utf-8-sig'))
    row = next(r for r in rows if (r['Profile'], r['Dimension'], r['Program'], r['Stage'], r['LoaderModel'], r['GpuIdentity']) ==
               ('Balanced', 'Overworld', 'gbuffers_terrain', 'fsh', 'Iris render-stage model', 'Intel'))
    artifact = destination / row['Artifact'].replace('\\', '/')
    old_hash = row['ContentHash']
    text = artifact.read_text(encoding='utf-8-sig')
    import re
    text, n = re.subn(r'(gl_FragData\s*\[\s*0\s*\]\s*=\s*vec4\s*\([^;]+;)', r'\1\n gl_FragData[0].r += 0.05; gl_FragData[0].a += 0.025;', text, count=1)
    if n != 1:
        raise RuntimeError('Mutation injection point missing')
    data = text.encode('utf-8')
    artifact.write_bytes(data)
    digest = hashlib.sha256(data).hexdigest()
    for r in rows:
        if r['ContentHash'].lower() == old_hash.lower():
            r['ContentHash'] = digest
    index_path.write_text(json.dumps(rows), encoding='utf-8')


def subset(root, source, destination):
    # Validate the entire original corpus once; copying just the selected rows
    # avoids rereading thousands of duplicate vendor mappings for every draw.
    spec = importlib.util.spec_from_file_location('native_compile', Path(__file__).with_name('native-gl-compile.py'))
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)
    rows, _ = native.load_variants(root, source)
    rows = [r for r in rows if r['Program'] in ('gbuffers_terrain', 'gbuffers_clouds', 'gbuffers_hand', 'gbuffers_water')
            and r['LoaderModel'] == 'Iris render-stage model' and r['GpuIdentity'] == 'Intel']
    destination.mkdir()
    shutil.copy2(root / 'source-manifest.json', destination / 'source-manifest.json')
    for name in {r['Artifact'].replace('\\', '/') for r in rows}:
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / name, target)
    (destination / 'index.json').write_text(json.dumps(rows), encoding='utf-8')
    return destination


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('baseline-source', 'baseline-variants', 'current-source', 'current-variants', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=False)
    expected = {'lib/cloud_fragment.glsl', 'lib/cloud_vertex.glsl', 'lib/fragment.glsl', 'lib/vertex.glsl',
                'gbuffers_hand.vsh', 'world0/gbuffers_hand.vsh', 'world-1/gbuffers_hand.vsh', 'world1/gbuffers_hand.vsh'}
    baseline_files = {p.relative_to(a.baseline_source).as_posix(): p.read_bytes() for p in a.baseline_source.rglob('*') if p.is_file()}
    current_files = {p.relative_to(a.current_source).as_posix(): p.read_bytes() for p in a.current_source.rglob('*') if p.is_file()}
    if baseline_files.keys() != current_files.keys():
        raise ValueError('Source inventories differ')
    changed = {name for name in baseline_files if baseline_files[name] != current_files[name]}
    if changed != expected:
        raise ValueError(f'Unexpected source differences: {sorted(changed ^ expected)}')
    a.baseline_variants = subset(a.baseline_variants, a.baseline_source, a.output / 'baseline-subset')
    a.current_variants = subset(a.current_variants, a.current_source, a.output / 'current-subset')
    rows = []
    for profile in ('Potato', 'Low', 'Balanced', 'High', 'Ultra'):
        for dim in ('Overworld', 'Nether', 'End'):
            for program in ('gbuffers_terrain', 'gbuffers_clouds', 'gbuffers_hand', 'gbuffers_water'):
                extra = ('--water',) if program == 'gbuffers_water' else ()
                stem = f'{profile}-{dim}-{program}'
                base, meta = draw(a.baseline_variants, a.baseline_source, a.output / (stem+'-baseline'), profile, dim, program, extra)
                current, _ = draw(a.current_variants, a.current_source, a.output / (stem+'-current'), profile, dim, program, extra)
                rows.append({'profile': profile, 'dimension': dim, 'program': program, **compare(base,current)})
    mutation = a.output / 'mutation-variants'
    mutate_variant(a.current_variants, mutation)
    pixels, _ = draw(mutation, a.current_source, a.output / 'mutation-draw', 'Balanced', 'Overworld', 'gbuffers_terrain')
    raw = (a.output / 'Balanced-Overworld-gbuffers_terrain-current' / 'pixels.rgba32f').read_bytes()
    control = compare(struct.unpack('<'+'f'*(len(raw)//4),raw), pixels)
    if not control['different_pixels'] or control['max_rgb'] < 0.04 or control['max_alpha'] < 0.02:
        raise AssertionError('RGB/alpha mutation escaped comparison')
    result = {'evidence': 'SYNTHETIC_NATIVE_GPU_SOURCE_DERIVED', 'driver': meta['driver'],
              'source_differences': sorted(changed),
              'baseline_manifest_sha256': hashlib.sha256((a.baseline_variants / 'source-manifest.json').read_bytes()).hexdigest(),
              'current_manifest_sha256': hashlib.sha256((a.current_variants / 'source-manifest.json').read_bytes()).hexdigest(),
              'threshold': 'exact RGBA32F equality', 'cases': rows, 'case_count': len(rows),
              'draw_count': 2*len(rows)+1, 'max_rgb': max(r['max_rgb'] for r in rows),
              'max_alpha': max(r['max_alpha'] for r in rows),
              'failed_cases': sum(r['different_pixels'] != 0 for r in rows),
              'mutation': {'description': 'add 0.05 to red and 0.025 to alpha in preprocessed terrain fragment output', **control},
              'limitations': 'Single synthetic quad, fixed normal and uniform textures; disabled blending; standalone Iris macro model; hand_water uses hand fallback and is not a distinct draw program; no Minecraft evidence.'}
    (a.output / 'report.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k != 'cases'}))
    if result['failed_cases']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()

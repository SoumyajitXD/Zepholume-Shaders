"""Matched water-diagonal draws on source-bound native variants, never Minecraft."""
import argparse
import json
import math
import struct
import subprocess
import sys
from pathlib import Path


def delta(a, b, channels):
    # Ignore raster edges displaced slightly by waves; compare the common face interior.
    return max(abs(a[4*(32*y+x)+c]-b[4*(32*y+x)+c])
               for y in range(4, 28) for x in range(4, 28) for c in channels)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-variant-root', type=Path, required=True)
    parser.add_argument('--baseline-source-root', type=Path, required=True)
    parser.add_argument('--variant-root', type=Path, required=True)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    renderer = Path(__file__).with_name('native-gl-render.py')
    cases = [(p.lower(), p, 'Overworld', True, False, False)
             for p in ('Potato', 'Low', 'Balanced', 'High', 'Ultra')]
    cases += [('nether', 'Balanced', 'Nether', True, False, False),
              ('end', 'Balanced', 'End', True, False, False),
              ('nonwater', 'Ultra', 'Overworld', False, False, False),
              ('underwater', 'Ultra', 'Overworld', True, True, False),
              ('centered-control', 'Low', 'Overworld', True, False, True),
              ('shortfog-water', 'Ultra', 'Overworld', True, False, False),
              ('shortfog-nonwater', 'Ultra', 'Overworld', False, False, False),
              ('shortfog-underwater', 'Ultra', 'Overworld', True, True, False)]
    rows = []
    driver = None
    for name, profile, dimension, water, underwater, centered in cases:
        short_fog = name.startswith('shortfog')
        pixels = {}
        for variant in ('baseline', 'treatment'):
            variant_root = args.baseline_variant_root if variant == 'baseline' else args.variant_root
            source_root = args.baseline_source_root if variant == 'baseline' else args.source_root
            for diagonal in ('forward', 'reverse'):
                output = args.output_dir / f'{name}-{variant}-{diagonal}'
                command = [sys.executable, str(renderer), '--variant-root', str(variant_root),
                           '--source-root', str(source_root), '--output-dir', str(output),
                           '--program', 'gbuffers_water', '--profile', profile, '--dimension', dimension,
                           '--quad-offset-x', '0' if centered else '.75',
                           '--quad-offset-y', '0' if centered else '.25',
                           '--depth', '.5', '--perspective', '--triangulation', diagonal,
                           '--fog-start', '0' if short_fog else '100',
                           '--fog-end', '2' if short_fog else '1000000000', '--skip-png']
                if water:
                    command += ['--water']
                if underwater:
                    command += ['--underwater']
                result = subprocess.run(command, capture_output=True, text=True)
                if result.returncode:
                    raise RuntimeError(f'{name}/{variant}/{diagonal}: {result.stderr}\n{result.stdout}')
                values = struct.unpack('<4096f', (output / 'pixels.rgba32f').read_bytes())
                if not all(math.isfinite(v) for v in values):
                    raise AssertionError('Non-finite GPU output')
                pixels[variant, diagonal] = values
                driver = json.loads((output / 'result.json').read_text())['driver']
        old = delta(pixels['baseline', 'forward'], pixels['baseline', 'reverse'], range(3))
        new = delta(pixels['treatment', 'forward'], pixels['treatment', 'reverse'], range(3))
        change = max(delta(pixels['baseline', d], pixels['treatment', d], range(3))
                     for d in ('forward', 'reverse'))
        alpha = max(delta(pixels['baseline', d], pixels['treatment', d], (3,))
                    for d in ('forward', 'reverse'))
        expect_defect = (water and profile != 'Potato' and not centered) or short_fog
        passed = new < 3e-5 and alpha < 1e-6 and (old > 1e-4 if expect_defect else change < 3e-5)
        row = dict(case=name, profile=profile, dimension=dimension, water_material=water,
                   underwater=underwater, centered=centered, short_fog=short_fog, old_diagonal_rgb_delta=old,
                   new_diagonal_rgb_delta=new, baseline_treatment_rgb_delta=change,
                   alpha_delta=alpha, expected_old_defect=expect_defect, passed=passed)
        rows.append(row)
        print(json.dumps(row), flush=True)
    report = dict(evidence_class='SOURCE_BOUND_SYNTHETIC_NATIVE_WATER_DIAGONAL',
                  minecraft_runtime='NOT TESTED', driver=driver, draws=len(rows)*4,
                  geometry='Same coplanar off-center face; constant textures; two diagonals; perspective projection',
                  tolerance=3e-5, cases=rows, passed=all(row['passed'] for row in rows))
    (args.output_dir / 'report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    if not report['passed']:
        raise AssertionError('Native water-diagonal regression; inspect report.json')


if __name__ == '__main__':
    main()

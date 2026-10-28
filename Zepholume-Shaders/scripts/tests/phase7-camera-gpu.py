"""Targeted native GPU camera-basis regression; never Minecraft evidence."""
import argparse
import json
import struct
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--variant-root', type=Path, required=True)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    renderer = Path(__file__).with_name('native-gl-render.py')
    cases = [('terrain', 'gbuffers_terrain', 'Ultra', 'Overworld', []),
             ('night', 'gbuffers_terrain', 'Balanced', 'Overworld', ['--sun-y', '-1']),
             ('fog', 'gbuffers_terrain', 'High', 'Overworld', ['--fog-start', '0', '--fog-end', '1']),
             ('sky', 'gbuffers_skybasic', 'Balanced', 'Overworld', []),
             ('cloud', 'gbuffers_clouds', 'Ultra', 'Overworld', []),
             ('water', 'gbuffers_water', 'Ultra', 'Overworld', ['--water']),
             ('nether', 'gbuffers_terrain', 'Balanced', 'Nether', []),
             ('end', 'gbuffers_terrain', 'Balanced', 'End', [])]
    rows = []
    for name, program, profile, dimension, extra in cases:
        reference = None
        for pitch, yaw in ((0, 0), (60, 37), (-70, -90)):
            output = args.output_dir / f'{name}-{pitch}-{yaw}'
            command = [sys.executable, str(renderer), '--variant-root', str(args.variant_root),
                       '--source-root', str(args.source_root), '--output-dir', str(output),
                       '--program', program, '--profile', profile, '--dimension', dimension,
                       '--camera-pitch', str(pitch), '--camera-yaw', str(yaw), '--skip-png', *extra]
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode:
                raise RuntimeError(f'{name} camera {pitch}/{yaw}: {result.stderr}')
            values = struct.unpack('<4096f', (output / 'pixels.rgba32f').read_bytes())
            if reference is None:
                reference = values
            delta = max(abs(a-b) for a, b in zip(reference, values))
            alpha_delta = max(abs(reference[i]-values[i]) for i in range(3, len(values), 4))
            rows.append(dict(case=name, pitch=pitch, yaw=yaw, maximum_rgba_delta=delta,
                             maximum_alpha_delta=alpha_delta, passed=delta <= 2e-5 and alpha_delta <= 1e-6))
    report = dict(evidence_class='SYNTHETIC_NATIVE_INTEL_CAMERA_BASIS',
                  minecraft_runtime='NOT TESTED', tolerance=2e-5, cases=rows,
                  passed=all(row['passed'] for row in rows))
    (args.output_dir / 'report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report))
    if not report['passed']:
        raise RuntimeError('Camera-basis GPU invariance failed; inspect report.json')


if __name__ == '__main__':
    main()

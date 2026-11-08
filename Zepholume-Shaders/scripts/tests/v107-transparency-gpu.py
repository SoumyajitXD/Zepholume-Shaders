'''Source-derived alpha and blending regression; standalone WGL, not Minecraft.'''
import argparse, json, os, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROFILES = ('Potato', 'Low', 'Balanced', 'High', 'Ultra')
DIMS = ('Overworld', 'Nether', 'End')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, default=ROOT / 'shaders')
    parser.add_argument('--variant-root', type=Path, required=True)
    args = parser.parse_args()
    args.source_root, args.variant_root = args.source_root.resolve(), args.variant_root.resolve()
    render = Path(__file__).with_name('native-gl-render.py')
    with tempfile.TemporaryDirectory(prefix='zeph-alpha-') as directory:
        temp = Path(directory)
        # Only the copied harness is instrumented; the generated production
        # shaders remain unchanged. Blend factors are explicitly synthetic.
        text = render.read_text(encoding='utf-8')
        marker = '        clear(0x00004000)\n'
        assert text.count(marker) == 1
        inject = '''        if os.environ.get("ZEPH_BLEND"):
            enable = legacy("glEnable", None, u)
            blend_func = legacy("glBlendFunc", None, u, u)
            enable(0x0BE2)
            blend_func(0x0302 if os.environ["ZEPH_BLEND"] == "straight" else 1, 0x0303)
'''
        (temp / render.name).write_text('import os\n' + text.replace(marker, marker + inject), encoding='utf-8')
        shutil.copy2(Path(__file__).with_name('native-gl-compile.py'), temp / 'native-gl-compile.py')
        count = 0
        max_alpha = max_blend = 0.0
        driver = None
        def draw(profile, dim, program, water, alpha, fog, blend=''):
            nonlocal count, driver
            out = temp / str(count)
            command = [sys.executable, str(temp / render.name), '--variant-root', str(args.variant_root),
                       '--source-root', str(args.source_root), '--output-dir', str(out), '--skip-png',
                       '--profile', profile, '--dimension', dim, '--program', program, '--alpha', str(alpha),
                       '--fog-start', str(0 if fog else 100), '--fog-end', str(0.1 if fog else 200)]
            if water: command.append('--water')
            env = os.environ.copy()
            if blend: env['ZEPH_BLEND'] = blend
            else: env.pop('ZEPH_BLEND', None)
            result = subprocess.run(command, capture_output=True, text=True, env=env)
            if result.returncode: raise RuntimeError(f'{command}: {result.stderr or result.stdout}')
            result = json.loads((out / 'result.json').read_text())
            count += 1
            driver = result['driver']
            return result['center_rgba_float']
        for profile in PROFILES:
            for dim in DIMS:
                for program, water in (('gbuffers_water', True), ('gbuffers_water', False),
                                       ('gbuffers_entities', False), ('gbuffers_hand', False)):
                    for alpha, fog in ((0, False), (0.25, True), (1, False)):
                        rgba = draw(profile, dim, program, water, alpha, fog)
                        error = abs(rgba[3] - round(alpha * 255) / 255)
                        max_alpha = max(max_alpha, error)
                        assert error < 2e-6, (profile, dim, program, water, alpha, fog, rgba)
        for program, water in (('gbuffers_water', True), ('gbuffers_water', False),
                               ('gbuffers_entities', False), ('gbuffers_hand', False)):
            for fog in (False, True):
                source = draw('Balanced', 'Overworld', program, water, 0.25, fog)
                a = source[3]
                for blend in ('straight', 'premultiplied'):
                    result = draw('Balanced', 'Overworld', program, water, 0.25, fog, blend)
                    dst = (0.03125, 0.0625, 0.125, 0.25)
                    factor = a if blend == 'straight' else 1.0
                    expected = [source[i] * factor + dst[i] * (1-a) for i in range(4)]
                    error = max(abs(x-y) for x,y in zip(result, expected))
                    max_blend = max(max_blend, error)
                    assert error < 3e-6, (program, water, fog, blend, result, expected)
        print(json.dumps(dict(passed=True, draws=count, max_alpha_error=max_alpha,
                              max_blend_error=max_blend, blend_factors=['SRC_ALPHA, ONE_MINUS_SRC_ALPHA', 'ONE, ONE_MINUS_SRC_ALPHA'],
                              blend_note='same factors apply to RGB and alpha; synthetic state, not a loader assertion',
                              coverage='five profiles, three dimensions, water, non-water translucent, entity, hand, clear/fog; alpha 0, .25, 1',
                              driver=driver, minecraft='NOT TESTED')))

if __name__ == '__main__': main()

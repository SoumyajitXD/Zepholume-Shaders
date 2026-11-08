"""Cross-file water material contract; static evidence, not loader execution."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'shaders'


def check(properties, vertex, fragment):
    mappings = []
    for line in properties.splitlines():
        line = line.split('#', 1)[0].strip()
        if not line:
            continue
        match = re.fullmatch(r'block\.(\d+)\s*=\s*(.*)', line)
        if not match:
            raise ValueError('malformed block mapping')
        mappings.append((match.group(1), match.group(2).split()))
    matches = [(ident, blocks) for ident, blocks in mappings if 'minecraft:water' in blocks]
    if len(matches) != 1 or matches[0][1] != ['minecraft:water']:
        raise ValueError('water mapping must be unique and exclusive')
    ident = matches[0][0]
    if sum(key == ident for key, _ in mappings) != 1:
        raise ValueError('water ID has duplicate mappings')
    assignment = re.search(r'zephIsWater\s*=\s*abs\s*\(\s*mc_Entity\.x\s*-\s*(\d+)\.0\s*\)', vertex)
    if not assignment or assignment.group(1) != ident:
        raise ValueError('water ID differs from vertex classification')
    for label, source in [('vertex', vertex), ('fragment', fragment)]:
        if not re.search(r'\bflat\s+varying\s+float\s+zephIsWater\s*;', source):
            raise ValueError(label + ' water classification is not flat')
    if not re.search(r'if\s*\(\s*zephIsWater\s*>\s*0\.5\s*\)\s*\{\s*vec2\s+waterWorld\s*=\s*zephWaterPhasePosition\([^;]+\);\s*position\s*=\s*zephMoveWater\(position,\s*waterWorld\)', vertex):
        raise ValueError('water displacement is not material gated')
    if not re.search(r'zephIsWater\s*>\s*0\.5\s*\?\s*zephWaterSurfaceLinear\s*\(', fragment):
        raise ValueError('water surface treatment is not material gated')


def main():
    properties = (ROOT / 'block.properties').read_text(encoding='utf-8')
    vertex = (ROOT / 'lib' / 'vertex.glsl').read_text(encoding='utf-8')
    fragment = (ROOT / 'lib' / 'fragment.glsl').read_text(encoding='utf-8')
    check(properties, vertex, fragment)
    mutations = [
        ('mapping', properties.replace('block.10001=minecraft:water', 'block.10999=minecraft:water'), vertex, fragment, 'water ID differs'),
        ('exclusive', properties.replace('minecraft:water\n', 'minecraft:water minecraft:glass\n'), vertex, fragment, 'unique and exclusive'),
        ('vertex flat', properties, vertex.replace('flat varying float zephIsWater;', 'varying float zephIsWater;'), fragment, 'vertex water classification is not flat'),
        ('fragment flat', properties, vertex, fragment.replace('flat varying float zephIsWater;', 'varying float zephIsWater;'), 'fragment water classification is not flat'),
        ('displacement gate', properties, vertex.replace('if (zephIsWater > 0.5)', 'if (true)'), fragment, 'displacement is not material gated'),
        ('surface gate', properties, vertex, fragment.replace('zephIsWater > 0.5\n        ? zephWaterSurfaceLinear', 'true\n        ? zephWaterSurfaceLinear'), 'surface treatment is not material gated'),
    ]
    for name, p, v, f, expected in mutations:
        try:
            check(p, v, f)
        except ValueError as error:
            if expected not in str(error):
                raise AssertionError(f'{name}: unexpected diagnosis {error}') from error
        else:
            raise AssertionError(f'{name}: mutation was not detected')
    print(f'Water material contract passed; {len(mutations)} targeted mutations detected with expected diagnostics. Static check only.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, AssertionError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)

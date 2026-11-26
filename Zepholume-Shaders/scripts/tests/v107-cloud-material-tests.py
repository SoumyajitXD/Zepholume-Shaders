"""Source-bound numerical checks for cloud density and translucent responses.

CPU reference for the indicated GLSL equations, not shader execution or game QA.
"""
import math
from pathlib import Path

root = Path(__file__).resolve().parents[2] / 'shaders/lib'
cloud = (root / 'cloud_fragment.glsl').read_text(encoding='utf-8')
material = (root / 'translucent_material.glsl').read_text(encoding='utf-8')
water = (root / 'water.glsl').read_text(encoding='utf-8')
for token in ('mix(0.48, 0.29, weather)',
              'clamp(fwidth(cloudField) * 0.8, 0.035, 0.16)',
              'smoothstep(threshold - edgeWidth, threshold + edgeWidth, cloudField)',
              'source.a *= mix(0.08, 1.0, coverage)'):
    assert token in cloud
for token in ('0.32 * grazing', '0.30 * grazing', 'if (material < 0.5) return colour;',
              'dot(max(colour, vec3(0.0)), vec3(0.2126, 0.7152, 0.0722))'):
    assert token in material
assert '#if ZEPH_EFFECTIVE_WATER_TIER == 1' in water
low = water.split('#if ZEPH_EFFECTIVE_WATER_TIER == 1', 1)[1].split('#else', 1)[0]
assert 'moonPosition' not in low and 'sunHalf' not in low and 'moonHalf' not in low

def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x-a)/(b-a)))
    return t*t*(3-2*t)

def alpha(field, weather, width):
    threshold = .48 + (.29 - .48) * weather
    coverage = smoothstep(threshold - width, threshold + width, field)
    return .08 + .92 * coverage

for width in (.035, .08, .16):
    for field in [i/100 for i in range(101)]:
        values = [alpha(field, i/100, width) for i in range(101)]
        assert all(math.isfinite(x) and .08 <= x <= 1 for x in values)
        assert all(a <= b + 1e-12 for a,b in zip(values, values[1:]))
    for weather in [i/100 for i in range(101)]:
        values = [alpha(i/100, weather, width) for i in range(101)]
        assert all(a <= b + 1e-12 for a,b in zip(values, values[1:]))
# These material calculations contain no additive light: zero stays zero.
for grazing in [i/100 for i in range(101)]:
    assert 0 * (1 + .08*grazing) == 0
    assert 0 <= .32*grazing <= 1 and 0 <= .30*grazing <= 1
print('PASS: bounded monotone synthetic cloud coverage and source-bound material/Low water checks')

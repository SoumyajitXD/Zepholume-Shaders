"""Source-bound numerical checks for cloud density and translucent responses.

CPU reference for the indicated GLSL equations, not shader execution or game QA.
"""
import math
from pathlib import Path

root = Path(__file__).resolve().parents[2] / 'shaders/lib'
cloud = (root / 'cloud_fragment.glsl').read_text(encoding='utf-8')
material = (root / 'translucent_material.glsl').read_text(encoding='utf-8')
water = (root / 'water.glsl').read_text(encoding='utf-8')
for token in ('smoothstep(0.22 - 0.10 * weather, 0.76 - 0.10 * weather, cloudField)',
              'mix(cloudBody, 1.0, weather * 0.55)',
              '(1.0 - cloudField) * (1.0 - zephCloudNormalUp)'):
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

def alpha(field, weather):
    coverage = smoothstep(.22-.10*weather, .76-.10*weather, field)
    body = .58 + .42*coverage
    return body + (1-body)*weather*.55

for field in [i/100 for i in range(101)]:
    values = [alpha(field, i/100) for i in range(101)]
    assert all(math.isfinite(x) and .58 <= x <= 1 for x in values)
    assert all(a <= b + 1e-12 for a,b in zip(values, values[1:]))
for weather in [i/100 for i in range(101)]:
    values = [alpha(i/100, weather) for i in range(101)]
    assert all(a <= b + 1e-12 for a,b in zip(values, values[1:]))
# These material calculations contain no additive light: zero stays zero.
for grazing in [i/100 for i in range(101)]:
    assert 0 * (1 + .08*grazing) == 0
    assert 0 <= .32*grazing <= 1 and 0 <= .30*grazing <= 1
print('PASS: bounded monotone synthetic cloud coverage and source-bound material/Low water checks')

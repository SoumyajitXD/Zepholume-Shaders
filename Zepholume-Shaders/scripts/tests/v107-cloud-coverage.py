"""CPU contracts for the mesh-bounded cloud field, not visual evidence."""
from math import floor, isfinite
from pathlib import Path

source = (Path(__file__).resolve().parents[2] / 'shaders/lib/cloud_fragment.glsl').read_text()
# Bind the model and its specialization to production. Changes to its formula
# must be reviewed here rather than silently testing an obsolete CPU model.
for expression in (
    '#if ZEPH_EFFECTIVE_CLOUD_QUALITY > 0 && ZEPH_EFFECTIVE_CLOUD_TIER >= 2',
    'fract(vec3(cell.xyx) * vec3(0.1031, 0.1030, 0.0973))',
    'p += dot(p, p.yzx + 33.33)',
    'return fract((p.x + p.y) * p.z)',
    'smoothstep(vec2(0.38), vec2(0.62), local)',
    'zephCloudBlocks(zephCloudTexCoord * 12.0)',
    'mix(0.48, 0.29, weather)',
    'clamp(fwidth(cloudField) * 0.8, 0.035, 0.16)',
    'smoothstep(threshold - edgeWidth, threshold + edgeWidth, cloudField)',
    'source.a *= mix(0.08, 1.0, coverage)',
    '#if ZEPH_EFFECTIVE_CLOUD_TIER >= 3',
    'zephCloudBlocks(zephCloudTexCoord * 28.0 + vec2(11.3, 4.7))',
    'cloudField * 0.72 + detailField * 0.28',
):
    assert expression in source, expression
assert 'discard;' not in source

def fract(x):
    return x - floor(x)

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3.0-2.0*t)

def mix(a, b, t):
    return a*(1.0-t)+b*t

def cell(x, y):
    p = [fract(x*.1031), fract(y*.1030), fract(x*.0973)]
    d = p[0]*(p[1]+33.33) + p[1]*(p[2]+33.33) + p[2]*(p[0]+33.33)
    p = [v+d for v in p]
    return fract((p[0]+p[1])*p[2])

def blocks(x, y):
    ix, iy = floor(x), floor(y)
    u, v = smooth(.38, .62, fract(x)), smooth(.38, .62, fract(y))
    return mix(mix(cell(ix, iy), cell(ix+1, iy), u),
               mix(cell(ix, iy+1), cell(ix+1, iy+1), u), v)

def alpha_factor(field, weather, width):
    threshold = mix(.48, .29, weather)
    return mix(.08, 1.0, smooth(threshold-width, threshold+width, field))

values, clear, rainy, shelves = [], [], [], []
for x in range(-48, 49):
    for y in range(-32, 33):
        u, v = x/128.0, y/128.0
        field = blocks(u*12.0, v*12.0)
        detail = blocks(u*28.0+11.3, v*28.0+4.7)
        assert isfinite(field) and 0 <= field <= 1
        assert isfinite(detail) and 0 <= detail <= 1
        values.append(field)
        shelves.append(smooth(.47, .66, field*.72 + detail*.28))
        for width in (.035, .08, .16):
            factors = [alpha_factor(field, weather, width) for weather in (0, .5, 1)]
            assert .08 <= factors[0] <= factors[1] <= factors[2] <= 1
            for source_alpha in (0, .25, .75, 1):
                assert 0 <= source_alpha*factors[1] <= source_alpha
        clear.append(alpha_factor(field, 0, .035))
        rainy.append(alpha_factor(field, 1, .035))
assert max(values)-min(values) > .5
assert min(clear) < .1 and max(clear) > .99
assert sum(rainy) > sum(clear)
assert min(shelves) < .1 and max(shelves) > .9
# The piecewise-flat block field joins continuously at every cell boundary.
for i in range(-8, 9):
    for j in range(-8, 9):
        y = j + .51
        assert abs(blocks(i-1e-7, y)-blocks(i+1e-7, y)) < 1e-6
        assert abs(blocks(y, i-1e-7)-blocks(y, i+1e-7)) < 1e-6
        assert blocks(i, y) == blocks(i, y)
print('PASS: source-bound cloud fields, continuity, variation, weather and alpha bounds')

"""Synthetic contracts for cloud facet lighting, not gameplay QA."""
from pathlib import Path
from math import isclose, isfinite

root = Path(__file__).resolve().parents[2] / 'shaders/lib'
v = (root / 'cloud_vertex.glsl').read_text(encoding='utf-8')
f = (root / 'cloud_fragment.glsl').read_text(encoding='utf-8')
common = (root / 'common.glsl').read_text(encoding='utf-8')
assert 'dot(cloudNormal, zephSafeNormalize(sunPosition)) * 0.5 + 0.5' in v
assert 'varying float zephCloudSunFacing;' in v and 'varying float zephCloudSunFacing;' in f
assert '(zephCloudSunFacing - 0.5) * 0.16 * day * clearSky' in f
assert 'zephClearTwilight(solarElevation, weather)' in f
assert 'zephTwilightFromElevation(elevation) * (1.0 - zephSaturate(weather))' in common
assert 'cloud * twilightTint, twilightLight *' in f
assert 'clamp(source.a, 0.0, 1.0)' in f
def facet_gain(facing, day, rain):
    return 1.0 + (facing - 0.5) * 0.16 * day * (1.0-rain)

for face in (0, .25, .5, .75, 1):
    assert facet_gain(face, 0, 0) == 1
    assert facet_gain(face, 1, 1) == 1
    for day in (0, .25, .5, .75, 1):
        for rain in (0, .25, .5, .75, 1):
            gain = facet_gain(face, day, rain)
            assert .92 <= gain <= 1.08 and isfinite(gain)
assert facet_gain(1, 1, 0) > facet_gain(0, 1, 0)
assert isclose(facet_gain(1, 1, .500001), facet_gain(1, 1, .5), abs_tol=1e-6)
print('PASS: synthetic cloud facet bounds and weather gates; gameplay not tested')

"""CPU bounds and continuity for the scene ambient tint; not game rendering.

The independent model checks broad safety invariants, not pixel equivalence to
production GLSL. Native production execution is covered by the visual harness.
"""
from pathlib import Path
import math

root = Path(__file__).resolve().parents[2]
source = (root / 'shaders/lib/lighting.glsl').read_text()
common = (root / 'shaders/lib/common.glsl').read_text()
assert '#if ZEPH_EFFECTIVE_FACE_LIGHTING_QUALITY >= 2' in source
assert 'zephSceneSkyWeight(lightCoord) * 0.55' in source
assert 'zephClearTwilight(sunElevation, storm)' in source
assert 'zephTwilightSurfaceTint(facing)' in source
assert 'lit *= mix(vec3(1.0), ambientTint, ambientWeight)' in source
assert 'return t * t * (3.0 - 2.0 * t)' in common


def clamp(x):
    return min(1.0, max(0.0, x))


def smooth(a, b, x):
    t = clamp((x - a) / (b - a))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a + (b - a) * t


def tint(e, sky, storm, facing):
    day = smooth(-.16, .18, e)
    dusk = (1 - smooth(.06, .34, abs(e))) * (1 - clamp(storm))
    night = (.94, .97, 1.06)
    daylight = (1.015, 1.005, .985)
    shade = (.96, .96, 1.035)
    sun = (1.14, .98, .84)
    base = [mix(a, b, day) for a, b in zip(night, daylight)]
    twilight = [mix(a, b, clamp(facing)) for a, b in zip(shade, sun)]
    ambient = [mix(a, b, dusk * .65) for a, b in zip(base, twilight)]
    weight = smooth(.04, .65, sky) * .55
    return [mix(1, x, weight) for x in ambient]


cases = 0
for sky in (-1, 0, .04, .1, .5, .65, 1, 2):
    for storm in (-1, 0, .5, 1, 2):
        for facing in (-1, 0, .5, 1, 2):
            prev = None
            for i in range(2001):
                value = tint(-1 + i / 1000, sky, storm, facing)
                # Convex mixtures of declared endpoints, then at most 0.55
                # contribution: [1+.55*(.84-1), 1+.55*(1.14-1)].
                assert all(math.isfinite(x) and .912 - 1e-12 <= x <= 1.077 + 1e-12 for x in value)
                if sky <= .04:
                    assert value == [1, 1, 1]
                # A multiplicative tint cannot brighten zero irradiance.
                assert all(0.0 * x == 0.0 for x in value)
                if prev is not None:
                    assert max(abs(a-b) for a, b in zip(value, prev)) < .002
                prev = value
                cases += 1

# Full storm removes twilight coloration regardless of face orientation.
for e in (-.34, -.1, 0, .1, .34):
    assert tint(e, 1, 1, 0) == tint(e, 1, 1, 1)
print(f'PASS: {cases} CPU ambient cases; bounded tint, dark neutrality, twilight continuity, storm behavior')

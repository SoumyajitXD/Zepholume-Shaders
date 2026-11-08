"""Broad swell invariants and source contracts, not Minecraft rendering.

The 2026-11-01 ripple rebuild replaced the former multi-wave vertex-gradient
model. Geometry now has one shared swell; fine normals are independent shading
detail, so they must not be asserted to be the derivative of that geometry.
"""
import math
from pathlib import Path

root = Path(__file__).resolve().parents[2]
water = (root / 'shaders/lib/water.glsl').read_text(encoding='utf-8')
vertex = (root / 'shaders/lib/vertex.glsl').read_text(encoding='utf-8')


def source_contract(water_source, vertex_source):
    # Bind the independent periodicity and amplitude checks below to the
    # implemented geometry; material and interpolation have separate tests.
    for required in (
        '#if ZEPH_EFFECTIVE_WATER_TIER >= 2 && ZEPH_EFFECTIVE_WATER_WAVES == 1',
        'dot(world, vec2(3.0, 2.0)) * 0.024543692606 + frameTimeCounter * 0.5235987756',
        'p.y += sin(phase) * 0.025;',
    ):
        if required not in water_source:
            raise ValueError('swell contract: ' + required)
    if 'position = zephMoveWater(position, waterWorld);' not in vertex_source:
        raise ValueError('swell is not applied to water geometry')


source_contract(water, vertex)
for mutated in (water.replace('* 0.025;', '* 2.025;', 1),
                water.replace('vec2(3.0, 2.0)', 'vec2(3.1, 2.0)', 1)):
    try:
        source_contract(mutated, vertex)
    except ValueError:
        pass
    else:
        raise AssertionError('meaningful swell mutation was not detected')


def height(x, z, t):
    return .025 * math.sin(math.tau * ((3*x + 2*z)/256 + t/12))


max_derivative_error = 0.0
cases = 0
for x in (-1000, -37, 0, 19, 1000):
    for z in (-1000, -9, 0, 31, 1000):
        for t in (0, .5, 32, 3600):
            h = height(x, z, t)
            assert math.isfinite(h) and abs(h) <= .025
            for other in (height(x+256, z, t), height(x, z+256, t), height(x, z, t+3600)):
                assert abs(h-other) < 1e-12
            eps = 1e-3
            derivative = (height(x+eps, z, t)-height(x-eps, z, t))/(2*eps)
            bound = .025 * math.tau * 3 / 256
            assert abs(derivative) <= bound + 1e-10
            max_derivative_error = max(max_derivative_error, abs(derivative))
            cases += 1
print(f'Broad swell: {cases} bounded periodic cases, max slope {max_derivative_error:.6g}; 2 source mutations detected. CPU/static only.')

"""Bounds of independent translucent response in linear working space."""
from math import isfinite
from pathlib import Path

source = (Path(__file__).resolve().parents[2] / 'shaders/lib/translucent_material.glsl').read_text()
assert '#if ZEPH_EFFECTIVE_MATERIAL_QUALITY > 0' in source
assert 'if (material < 0.5) return colour;' in source
assert 'texture' not in source.replace('texture tint', '')

def response(rgb, material, dot):
    g = (1 - max(0, min(1, abs(dot)))) ** 2
    if material < .5:
        return rgb
    if material < 1.5:
        return tuple(c*(1 + .06*g) for c in rgb)
    return tuple(c*(a + (b-a)*g) for c, a, b in zip(rgb, (.96, 1, 1.04), (.97, 1.01, 1.08)))

for mat in (0, 1, 2):
    for dot in (-1, -.75, -.1, 0, .1, .75, 1):
        assert response((0, 0, 0), mat, dot) == (0, 0, 0)
        for rgb in ((1, 1, 1), (.01, .2, .8), (0, .25, .5)):
            out = response(rgb, mat, dot)
            assert all(isfinite(v) and 0 <= v <= c*1.08 + 1e-12 for v, c in zip(out, rgb))
            assert out == response(rgb, mat, -dot)
            if mat == 0:
                assert out == rgb
assert response((1, 1, 1), 1, 0)[0] > response((1, 1, 1), 1, 1)[0]
assert response((1, 1, 1), 2, 0)[2] > response((1, 1, 1), 2, 1)[2]
print('PASS: translucent identity, zero light, bounded tint and two-sided angle response')

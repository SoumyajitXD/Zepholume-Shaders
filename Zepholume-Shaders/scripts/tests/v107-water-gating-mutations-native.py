"""Production-library metamorphic water checks with real shader mutations.

Standalone synthetic OpenGL draws only: this does not execute Minecraft/Iris.
"""
import importlib.util
from pathlib import Path

here = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('water_fixture', here / 'v107-water-specular.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
root = here.parents[1] / 'shaders' / 'lib'
common = (root / 'common.glsl').read_text(encoding='utf-8')
water = (root / 'water.glsl').read_text(encoding='utf-8')
mutations = (
    ('enclosed sky leak', 'reflectance *= skyExposure;', 'reflectance *= 1.0;'),
    ('lost solar lobe', 'zephSpecularLobe(sunNdotH) * sunWeight;', 'zephSpecularLobe(sunNdotH) * 0.0;'),
)
case = dict(tier=2, dimension='Overworld', normal=(0., 1., 0.),
            view=(0., 1., 0.), sun=(0., 1., 0.), moon=(0., -1., 0.),
            rain=0., colour=(0.35, 0.5, 0.5), sky=(0.8, 0.9, 1.0), exposure=0.)


def draw(source, sample):
    fixture = module.NativeFixture(common, source)
    try:
        return fixture.draw(sample)
    finally:
        fixture.close()


closed = draw(water, case)
closed_dark = draw(water, {**case, 'sky': (0., 0., 0.)})
assert max(abs(a-b) for a,b in zip(closed, closed_dark)) < 2e-6
sun_case = {**case, 'colour': (0., 0., 0.), 'sky': (0., 0., 0.), 'exposure': 1.}
sun = draw(water, sun_case)
assert sum(sun) > 0.1
for name, old, new in mutations:
    assert water.count(old) == 1, name
    changed = water.replace(old, new)
    if name == 'enclosed sky leak':
        observed = draw(changed, case)
        delta = max(abs(a-b) for a,b in zip(observed, closed_dark))
    else:
        observed = draw(changed, sun_case)
        delta = max(abs(a-b) for a,b in zip(observed, sun))
    assert delta > .01, (name, delta)
    print(f'{name}: detected by production-source native draw, max delta {delta:.6f}')
print('PASS: 2 behavioral mutations detected; synthetic standalone OpenGL, not Minecraft.')

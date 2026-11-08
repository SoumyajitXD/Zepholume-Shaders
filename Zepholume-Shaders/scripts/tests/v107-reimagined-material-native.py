"""Native source tests of twilight water glint and translucent colour, not gameplay."""
import importlib.util
from pathlib import Path

here = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('water_fixture', here / 'v107-water-specular.py')
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)
root = here.parents[1] / 'shaders' / 'lib'
common = (root / 'common.glsl').read_text()
water = (root / 'water.glsl').read_text()

sun = (0.979795897, 0.2, 0.0)
case = dict(tier=2, dimension='Overworld', normal=sun, view=sun,
            sun=sun, moon=(0., -1., 0.), rain=0., colour=(0., 0., 0.),
            sky=(0., 0., 0.), exposure=1.)
native = fixture.NativeFixture(common, water)
try:
    sunset = native.draw(case)
    suppressed = native.draw({**case, 'exposure': 0.})
    assert max(suppressed) < 1e-6 and min(sunset) > 0., (sunset, suppressed)
finally:
    native.close()
# A neutral-tint control uses the same production path with just the tint
# removed, isolating the behaviour of the newly integrated response.
marker = 'mix(vec3(1.0), zephTwilightSurfaceTint(1.0), sunset * 0.65)'
assert water.count(marker) == 1
native = fixture.NativeFixture(common, water.replace(marker, 'vec3(1.0)'))
try:
    neutral = native.draw(case)
    assert sunset[0] > neutral[0] and sunset[2] < neutral[2], (sunset, neutral)
finally:
    native.close()

material = (root / 'translucent_material.glsl').read_text()
# Adapt the existing one-pixel driver fixture to call the production material
# function, using its exposure uniform to select glass or ice material IDs.
material_shader = ('#define ZEPH_EFFECTIVE_MATERIAL_QUALITY 1\n' + material + '''
vec3 zephWaterSurfaceLinear(vec3 colour, vec3 normal, vec3 view, float distance, float material) {
    return zephTranslucentResponse(colour, normal, view, material);
}
''')
native = fixture.NativeFixture(common, material_shader)
try:
    glass = dict(tier=2, dimension='Overworld', normal=(0., 1., 0.), view=(0., 1., 0.),
                 sun=sun, moon=(0., -1., 0.), rain=0., colour=(0.8, 0.08, 0.04), exposure=1.)
    face = native.draw(glass)
    edge = native.draw({**glass, 'view': (1., 0., 0.)})
    black = native.draw({**glass, 'view': (1., 0., 0.), 'colour': (0., 0., 0.)})
    ice = native.draw({**glass, 'view': (1., 0., 0.), 'exposure': 2.})
    assert max(abs(a-b) for a,b in zip(face, glass['colour'])) < 1e-6, face
    assert edge[0] > edge[1] * 5 and edge[0] > edge[2] * 5, edge
    assert max(black) < 1e-6 and all(v >= 0. for v in ice), (black, ice)
    print('PASS: 7 Intel native draws: twilight colour and exposure, stained glass hue, black preservation, ice; Minecraft NOT TESTED')
finally:
    native.close()

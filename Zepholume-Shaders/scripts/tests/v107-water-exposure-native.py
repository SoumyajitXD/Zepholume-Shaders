"""Native source-library water exposure invariants, not Minecraft rendering.

Input colour stands for an already sampled block-lit surface; this isolates the
water function and does not test Minecraft's lightmap texture sampling.
"""
from pathlib import Path
import importlib.util
import json
import sys

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('water_specular', Path(__file__).with_name('v107-water-specular.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
common = (root / 'shaders/lib/common.glsl').read_text()
water = (root / 'shaders/lib/water.glsl').read_text()
fixture = module.NativeFixture(common, water)
count = 0
try:
    def draw(tier=2, dimension='Overworld', exposure=1.0, rain=0.0, night=False, colour=(0.0, 0.0, 0.0)):
        global count
        count += 1
        return fixture.draw(dict(tier=tier, dimension=dimension, exposure=exposure, rain=rain,
            normal=(0.0, 1.0, 0.0), view=(0.0, 1.0, 0.0), colour=colour,
            sun=(0.0, -1.0 if night else 1.0, 0.0),
            moon=(0.0, 1.0 if night else -1.0, 0.0)))

    def near(a, b, tol=2e-6):
        return max(abs(x-y) for x, y in zip(a, b)) < tol

    evidence = {}
    for tier in (1, 2):
        for night in (False, True):
            closed = draw(tier, exposure=0, night=night)
            opened = draw(tier, exposure=1, night=night)
            mid = draw(tier, exposure=.5, night=night)
            assert near(closed, (0, 0, 0))
            assert all(abs(m - o * .5) < 2e-6 for m, o in zip(mid, opened))
            # Low deliberately omits moon highlights.
            if tier == 1 and night:
                assert near(opened, closed)
            else:
                assert sum(opened) > .01
                storm = draw(tier, exposure=1, rain=1, night=night)
                assert all(abs(s - o * .15) < 2e-6 for s, o in zip(storm, opened))
            evidence[f'tier{tier}_{"night" if night else "day"}'] = {'closed': closed, 'open': opened}
        # Full exposure should not affect a block-lit transmitted base when
        # both celestial directions and sky colour contribute zero.
        lit = draw(tier, exposure=0, colour=(.4, .25, .1))
        dark = draw(tier, exposure=0)
        assert sum(lit) > .05 and near(dark, (0, 0, 0))
        for dim in ('Nether', 'End'):
            assert near(draw(tier, dim, exposure=0, colour=(.4, .25, .1)),
                        draw(tier, dim, exposure=1, colour=(.4, .25, .1)))
    print(json.dumps({'evidence_class':'NATIVE_SOURCE_LIBRARY_RGBA32F', 'driver':fixture.driver,
                      'draws':count, 'programs':len(fixture.programs), 'measurements':evidence, 'passed':True}))
finally:
    fixture.close()

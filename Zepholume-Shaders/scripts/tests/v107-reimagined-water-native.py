"""Native production water invariants; standalone synthetic draws, not Minecraft."""
import importlib.util
from pathlib import Path

here = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('water_fixture', here / 'v107-water-specular.py')
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)
root = here.parents[1] / 'shaders' / 'lib'
native = fixture.NativeFixture((root / 'common.glsl').read_text(), (root / 'water.glsl').read_text())
try:
    for tier in (1, 2, 3, 4):
        case = dict(tier=tier, dimension='Overworld', normal=(0., 1., 0.),
                    view=(0., 1., 0.), sun=(0., -1., 0.), moon=(0., -1., 0.),
                    rain=0., colour=(0.35, 0.5, 0.5), sky=(0.8, 0.9, 1.0), exposure=0.)
        dark_sky = native.draw({**case, 'sky': (0., 0., 0.)})
        bright_sky = native.draw(case)
        assert max(abs(a-b) for a,b in zip(dark_sky, bright_sky)) < 1e-6, 'enclosed sky leaked'
        face = native.draw({**case, 'exposure': 1.})
        grazing_case = {**case, 'view': (0.995, 0.09987, 0.)}
        grazing_off = native.draw(grazing_case)
        grazing_on = native.draw({**grazing_case, 'exposure': 1.})
        face_delta = sum(a-b for a,b in zip(face, bright_sky))
        grazing_delta = sum(a-b for a,b in zip(grazing_on, grazing_off))
        assert grazing_delta > face_delta > 0., (tier, face_delta, grazing_delta)
    print('PASS: 20 native water draws; tiers 1-4; exposure isolation and grazing reflection; Minecraft NOT TESTED')
finally:
    native.close()

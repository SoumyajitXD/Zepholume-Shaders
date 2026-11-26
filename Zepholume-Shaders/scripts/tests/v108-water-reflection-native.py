"""Native water reflection controls on the active OpenGL driver."""
import importlib.util
from pathlib import Path
import math
import sys

sys.dont_write_bytecode = True
here = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("water_fixture", here / "v107-water-specular.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

shader_lib = here.parents[1] / "shaders" / "lib"
fixture = module.NativeFixture((shader_lib / "common.glsl").read_text(encoding="utf-8"),
                               (shader_lib / "water.glsl").read_text(encoding="utf-8"))

base = dict(dimension="Overworld", normal=(0.0, 1.0, 0.0), view=(-0.97, 0.21, 0.0),
            sun=(1.0, 0.0, 0.0), moon=(0.0, -1.0, 0.0), colour=(0.0, 0.0, 0.0),
            sky=(0.8, 0.7, 0.6), rain=0.0, exposure=1.0)

try:
    for tier in (1, 2, 3, 4):
        def draw(**changes):
            colour = fixture.draw({**base, "tier": tier, **changes})
            assert all(math.isfinite(channel) and channel >= 0.0 for channel in colour)
            return colour

        # Strip direct light by subtracting the black-sky control.
        def indirect(**changes):
            solid = draw(**changes)
            black_sky = draw(**changes, sky=(0.0, 0.0, 0.0))
            return tuple(a - b for a, b in zip(solid, black_sky))

        noon = indirect(sun=(0.0, 1.0, 0.0), view=(-1.0, 0.0, 0.0))
        night = indirect(sun=(0.0, -1.0, 0.0), view=(-1.0, 0.0, 0.0))
        assert min(noon) > 0.002
        assert all(abs(dark - light * 0.52) < 2e-6 for dark, light in zip(night, noon)), tier

        # Mirror the reflected ray about the sky zenith while keeping Fresnel,
        # solar elevation, and incidence constant.
        toward = draw()
        away = draw(view=(0.97, 0.21, 0.0))
        if tier == 1:
            assert max(abs(a - b) for a, b in zip(toward, away)) < 2e-6
        else:
            assert toward[0] - away[0] > 0.003, (tier, toward, away)
            assert away[2] > toward[2]
        storm_toward = draw(rain=1.0)
        storm_away = draw(rain=1.0, view=(0.97, 0.21, 0.0))
        assert max(abs(a - b) for a, b in zip(storm_toward, storm_away)) < 2e-6

        lit = (0.4, 0.25, 0.1)
        closed = draw(colour=lit, exposure=0.0)
        almost_closed = draw(colour=lit, exposure=1e-5)
        closed_expected = tuple(x * x * scale for x, scale in zip(lit, (0.88, 0.98, 0.96)))
        assert max(abs(a - b) for a, b in zip(closed, closed_expected)) < 2e-6
        assert max(abs(a - b) for a, b in zip(closed, almost_closed)) < 1e-5
        print(f"Water tier {tier}: nighttime attenuation, weather, direction and enclosure passed")
finally:
    fixture.close()

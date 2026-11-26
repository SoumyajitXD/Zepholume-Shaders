"""Source-bound CPU checks for shared sky, surface and cloud haze.

These checks do not substitute for loader compilation or rendered evidence.
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LUMA = (0.2126, 0.7152, 0.0722)


def sat(x):
    return max(0.0, min(1.0, x))


def smooth(t):
    t = sat(t)
    return t * t * (3.0 - 2.0 * t)


def tint_weight(twilight, elevation, solar_dot, tier):
    base = twilight * 0.08
    if tier < 2:
        return base
    horizon = 1.0 - smooth(abs(elevation) / 0.44)
    toward = sat(solar_dot * 0.5 + 0.5)
    return base + twilight * horizon * toward**2 * 0.15


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def mix(a, b, weight):
    return tuple(x * (1 - weight) + y * weight for x, y in zip(a, b))


def haze(base, daylight, rain, twilight, elevation, sun_dot, tier):
    if tier == 0:
        return base
    luminance = dot(base, LUMA)
    def matched(tint):
        return tuple(x * luminance / dot(tint, LUMA) for x in tint)
    day = mix(base, matched((0.72, 0.78, 0.82)), 0.16)
    night = mix(base, matched((0.055, 0.070, 0.105)), 0.26)
    warm = tint_weight(twilight * (1.0 - sat(rain)), elevation, sun_dot, tier)
    clear = mix(mix(night, day, daylight), matched((0.82, 0.48, 0.32)), warm)
    return tuple(map(sat, mix(clear, tuple(luminance * c for c in (0.76, 0.79, 0.82)),
                              sat(rain) * 0.35)))


def main():
    cloud = (ROOT / "shaders/lib/cloud_fragment.glsl").read_text(encoding="utf-8")
    fog = (ROOT / "shaders/lib/fog.glsl").read_text(encoding="utf-8")
    sky = (ROOT / "shaders/lib/sky_fragment.glsl").read_text(encoding="utf-8")
    shared = (ROOT / "shaders/lib/atmosphere.glsl").read_text(encoding="utf-8")
    assert "zephOpenAirHaze(fogColor, day, weather, twilight, elevation, sunDot)" in cloud
    for source in (fog, sky):
        assert "zephOpenAirHaze(fogColor, daylight, storm, clearTwilight, elevation, sunDot)" in source
    assert "if (cloudFog > 0.0)" in cloud
    assert "zephSaturate(rainStrength)" in cloud
    assert "if (isEyeInWater == 0)" in cloud
    assert "vec3 haze = isEyeInWater == 0" in sky
    assert "return zephSaturate(mix(haze, luminance" in shared
    assert "vec3(1.0) - zephSaturate(result)" in sky
    assert "moonward = max(dot(viewDir, moonDir), 0.0)" in cloud
    assert cloud.index("vec2 footprint = fwidth(detailCoord)") < cloud.index("if (detailWeight > 0.0)")
    assert "mix(shelf, detailShelf, detailWeight)" in cloud
    for footprint, expected in ((0.0, 1.0), (0.23, 1.0), (0.44, 0.5), (0.65, 0.0), (2.0, 0.0)):
        assert abs(1.0 - smooth((footprint - 0.23) / 0.42) - expected) < 1e-12
    for twilight in (0.0, 0.25, 0.5, 1.0):
        for elevation in (-1.0, -0.5, -0.1, 0.0, 0.1, 0.5, 1.0):
            values = [tint_weight(twilight, elevation, d, 2) for d in (-1.0, 0.0, 1.0)]
            assert all(math.isfinite(v) and 0.0 <= v <= 0.23 for v in values)
            assert values[0] <= values[1] <= values[2]
            if abs(elevation) >= 0.44:
                assert max(values) == min(values)
            assert len({tint_weight(twilight, elevation, d, 1) for d in (-1.0, 0.0, 1.0)}) == 1
    for tier in range(5):
        for base in ((0, 0, 0), (0.002, 0.003, 0.005), (0.24, 0.41, 0.65), (1, 1, 1)):
            for rain in (-4.0, 0.0, 0.5, 1.0, 4.0):
                for daylight in (0.0, 0.5, 1.0):
                    endpoint = haze(base, daylight, rain, 1.0, 0.0, 1.0, tier)
                    assert all(math.isfinite(x) and 0 <= x <= 1 for x in endpoint)
                    assert max(endpoint) <= min(1.0, max(base) * 1.6)
                    if tier == 0 or base == (0, 0, 0):
                        assert endpoint == base
    biome_fog = (0.24, 0.41, 0.65)
    horizon = haze(biome_fog, 0.5, 0.0, 1.0, 0.0, 1.0, 2)
    # Previous sky used the raw biome value at this boundary, so this fixture
    # would detect a mutable stage returning to an independently tinted edge.
    assert max(abs(a - b) for a, b in zip(biome_fog, horizon)) > 0.025
    assert mix(horizon, (0.6, 0.3, 0.1), smooth(0.0 / 0.16)) == horizon
    # Fog density remains bounded and monotone even for a bad weather input.
    for rain in (-4.0, 0.0, 0.5, 1.0, 4.0):
        density = 0.76 + 0.24 * sat(rain)
        values = [t * (density + (1.0 - density) * t) for t in (i / 100 for i in range(101))]
        assert values[0] == 0.0 and values[-1] == 1.0
        assert all(0.0 <= v <= 1.0 for v in values)
        assert all(a <= b for a, b in zip(values, values[1:]))
    print("PASS: shared sky/cloud/terrain haze, dark preservation, angular bounds, cloud detail fade, and fog endpoints (CPU/source)")


if __name__ == "__main__":
    main()

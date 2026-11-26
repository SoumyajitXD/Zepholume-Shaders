"""Source-bound fog direction and black-preservation regression checks."""
from pathlib import Path

root = Path(__file__).resolve().parents[2] / "shaders/lib"
vertex = (root / "vertex.glsl").read_text(encoding="utf-8")
fragment = (root / "fragment.glsl").read_text(encoding="utf-8")
fog = (root / "fog.glsl").read_text(encoding="utf-8")
atmosphere = (root / "atmosphere.glsl").read_text(encoding="utf-8")

assert "zephViewDirection = -viewPosition.xyz;" in vertex
assert "zephFogColour(-zephViewDirection)" in fragment
assert "sunDot = dot(direction, sunDir);" in fog
# A surface toward the sun has the opposite surface-to-camera vector.
sun = (1.0, 0.0, 0.0)
surface_to_camera = (-1.0, 0.0, 0.0)
ray = tuple(-v for v in surface_to_camera)
assert sum(a * b for a, b in zip(ray, sun)) == 1.0
assert sum(a * b for a, b in zip(surface_to_camera, sun)) == -1.0

assert "#elif ZEPH_EFFECTIVE_PROFILE_TIER == 0\n    return fogColor;" in fog

# Near fragments avoid the fog work, including world elevation projection.
# The equality is required for the exact step used by invalid loader ranges.
guard = "if (zephDistance >= fogStart)"
assert fragment.index(guard) < fragment.index("float fogFactor = zephFogFactor(")
assert "if (isEyeInWater == 1)" in fragment.split(guard, 1)[0]
for start, end in ((-0.5, 0.5), (0.25, 0.75), (0.0, 1e-6), (1.0, 1.0), (1.0, 0.5)):
    for distance in (start - 0.01, start, (start + end) * 0.5, end, end + 0.01):
        original = (float(distance >= start) if end <= start
                    else max(0.0, min(1.0, (distance - start) / (end - start))))
        guarded = original if distance >= start else 0.0
        assert guarded == original
        if distance == start:
            assert guarded == (1.0 if end <= start else 0.0)
# The current directional fog is not the abandoned fog-hoist treatment.
# Check its intended angular behavior against an independent geometric oracle.
# Source anchors ensure this test does not silently continue after removing it.
for token in (
    "float horizon = 1.0 - smoothstep(0.0, 0.44, abs(elevation));",
    "float towardSun = zephSaturate(sunDot * 0.5 + 0.5);",
    "warmWeight += clearTwilight * horizon * towardSun * towardSun * 0.15;",
):
    assert token in atmosphere, f"Directional fog source changed: {token}"

def directional_weight(ray, sun_direction, twilight):
    t = min(1.0, abs(ray[1]) / 0.44)
    horizon = 1.0 - t * t * (3.0 - 2.0 * t)
    facing = max(0.0, min(1.0, (sum(a * b for a, b in zip(ray, sun_direction)) + 1.0) / 2.0))
    return twilight * horizon * facing**2

# Unit directions at the horizon and zenith; twilight is zero in rain/night.
for twilight in (0.0, 0.25, 1.0):
    facing = directional_weight((1, 0, 0), sun, twilight)
    sideways = directional_weight((0, 0, 1), sun, twilight)
    away = directional_weight((-1, 0, 0), sun, twilight)
    vertical = directional_weight((0, 1, 0), sun, twilight)
    assert 0 <= away <= sideways <= facing <= twilight
    assert away == vertical == 0.0
    assert abs(facing - twilight) < 1e-12
    assert abs(sideways - twilight / 4.0) < 1e-12
# Negative control: reversing the ray must change the solar-facing result.
assert directional_weight(sun, sun, 1.0) != directional_weight(tuple(-v for v in sun), sun, 1.0)
print("PASS: fog direction, angular boundaries, pre-fog guard, and Potato loader palette")

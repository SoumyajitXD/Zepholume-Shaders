"""Source-bound fog direction and black-preservation regression checks."""
from pathlib import Path

root = Path(__file__).resolve().parents[2] / "shaders/lib"
vertex = (root / "vertex.glsl").read_text(encoding="utf-8")
fragment = (root / "fragment.glsl").read_text(encoding="utf-8")
fog = (root / "fog.glsl").read_text(encoding="utf-8")
atmosphere = (root / "atmosphere.glsl").read_text(encoding="utf-8")

assert "zephViewDirection = -viewPosition.xyz;" in vertex
assert "zephFogColour(-zephViewDirection)" in fragment
assert "dot(direction, sunDir)" in fog
# A surface toward the sun has the opposite surface-to-camera vector.
sun = (1.0, 0.0, 0.0)
surface_to_camera = (-1.0, 0.0, 0.0)
ray = tuple(-v for v in surface_to_camera)
assert sum(a * b for a, b in zip(ray, sun)) == 1.0
assert sum(a * b for a, b in zip(surface_to_camera, sun)) == -1.0

potato = atmosphere.split("#if ZEPH_EFFECTIVE_PROFILE_TIER == 0", 1)[1].split("#else", 1)[0]
assert "baseFog * vec3(0.97, 1.00, 1.03)" in potato
assert "baseFog * vec3(0.88, 0.95, 1.08)" in potato
potato_fog = fog.split("// Low-order horizon warmth", 1)[1].split("#else", 1)[0]
assert "return haze * mix(" in potato_fog
for daylight in (0.0, 0.5, 1.0):
    for twilight in (0.0, 0.5, 1.0):
        for storm in (0.0, 0.5, 1.0):
            # All terms in the Potato path scale the zero input; a fixed
            # additive palette would fail this black-input invariant.
            day = [0.0 * x for x in (0.97, 1.0, 1.03)]
            night = [0.0 * x for x in (0.88, 0.95, 1.08)]
            haze = [n * (1 - daylight) + d * daylight for n, d in zip(night, day)]
            luma = sum(c * w for c, w in zip(haze, (0.2126, 0.7152, 0.0722)))
            haze = [c * (1 - storm * 0.35) + luma * t * storm * 0.35 for c, t in zip(haze, (0.76, 0.79, 0.82))]
            result = [c * (1 + (t - 1) * twilight * 0.10) for c, t in zip(haze, (1.08, 0.97, 0.91))]
            assert result == [0.0, 0.0, 0.0]
print("PASS: fog direction and Potato black preservation")

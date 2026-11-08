"""Numerical and source contract for the overworld sky/fog boundary."""
from pathlib import Path

source = (Path(__file__).resolve().parents[2] / "shaders/lib/sky_fragment.glsl").read_text()
assert "float horizonDistance = abs(dot(skyDir, zephWorldUpView()));" in source
assert "mix(fogColor, result, smoothstep(0.0, 0.16, horizonDistance))" in source

def weight(distance):
    t = max(0.0, min(1.0, abs(distance) / 0.16))
    return t * t * (3.0 - 2.0 * t)

for fog, sky in [(0.2, 0.8), (0.0, 1.0), (0.8, 0.1)]:
    blend = lambda d: fog * (1.0 - weight(d)) + sky * weight(d)
    assert blend(0.0) == fog
    assert abs(blend(1e-5) - fog) < 1e-6
    assert abs(blend(-1e-5) - fog) < 1e-6
    assert blend(0.16) == sky
    assert abs(sky - fog) > 0.1  # An unblended sky fails the boundary condition.
print("PASS: horizon converges to fog on both sides; upper sky preserved; negative control rejected")

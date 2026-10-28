"""Camera-rotation regression for world elevation; CPU/source evidence only."""

import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def normalize(vector):
    scale = 1 / math.sqrt(max(sum(x * x for x in vector), 1e-8))
    return tuple(x * scale for x in vector)


def dot(left, right):
    return sum(a * b for a, b in zip(left, right))


def rotate(vector, yaw, pitch, roll):
    # Independent sequential rotations, avoiding a GLSL matrix transcription.
    x, y, z = vector
    a, b, c = map(math.radians, (yaw, pitch, roll))
    x, z = math.cos(a) * x + math.sin(a) * z, -math.sin(a) * x + math.cos(a) * z
    y, z = math.cos(b) * y - math.sin(b) * z, math.sin(b) * y + math.cos(b) * z
    x, y = math.cos(c) * x - math.sin(c) * y, math.sin(c) * x + math.cos(c) * y
    return x, y, z


def smooth(value, low, high):
    t = max(0, min(1, (value - low) / (high - low)))
    return t * t * (3 - 2 * t)


REQUIRED = {
    "common.glsl": ("uniform mat4 gbufferModelView;", "zephSafeNormalize(gbufferModelView[1].xyz)",
                    "dot(zephSafeNormalize(viewDirection), zephWorldUpView())",
                    "zephDaylightFromElevation(zephWorldElevation(lightDirection))",
                    "zephTwilightFromElevation(zephWorldElevation(lightDirection))"),
    "lighting.glsl": ("zephWorldElevation(normal)", "zephDaylightFromDirection(sunDir)"),
    "materials.glsl": ("zephWorldElevation(normal)",),
    "fog.glsl": ("zephDaylightFromDirection(sunDir)", "zephTwilightFromDirection(sunDir)"),
    "water.glsl": ("zephDaylightFromDirection(sunDir)", "zephWorldElevation(sunDir)", "zephWorldElevation(moonDir)"),
    "fragment.glsl": ("zephFogFactor(zephDistance, zephWorldElevation(zephViewDirection))",),
    "cloud_fragment.glsl": ("zephDaylightFromDirection(sunDir)", "zephTwilightFromDirection(sunDir)", "zephWorldElevation(sunDir)"),
    "cloud_vertex.glsl": ("zephWorldElevation(gl_NormalMatrix * gl_Normal)",),
    "sky_vertex.glsl": ('#include "/lib/common.glsl"', "zephWorldElevation(viewPosition.xyz)"),
    "sky_fragment.glsl": ("zephDaylightFromDirection(sunDir)", "zephTwilightFromDirection(sunDir)"),
}


def check_source(sources):
    for name, tokens in REQUIRED.items():
        for token in tokens:
            if token not in sources[name]:
                raise AssertionError(f"Missing camera-space contract in {name}: {token}")
    for name, source in sources.items():
        for token in ("sunDir.y", "moonDir.y", "normal.y", "zephViewDirection.y", "viewPosition.y"):
            if token in source:
                raise AssertionError(f"Camera-relative elevation returned in {name}: {token}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument("--inject-view-y", action="store_true", help="Negative control: must fail")
    args = parser.parse_args()
    sources = {name: (ROOT / "shaders/lib" / name).read_text(encoding="utf-8") for name in REQUIRED}
    check_source(sources)
    mutated = dict(sources)
    mutated["common.glsl"] = mutated["common.glsl"].replace(
        "dot(zephSafeNormalize(viewDirection), zephWorldUpView())", "zephSafeNormalize(viewDirection).y")
    try:
        check_source(mutated)
    except AssertionError:
        pass
    else:
        raise AssertionError("Old view-Y source mutation escaped detection")

    vectors = ((0, 1, 0), (0, -1, 0), (1, 0, 0), (0, 0, 1),
               (1, 0.1, 1), (1, -0.1, -1), (-3, 0.18, 2), (0, 0, 0))
    cases, old_failures, maximum = 0, 0, 0.0
    for yaw in (-180, -90, 0, 37, 90, 180):
        for pitch in (-89, -60, -20, 0, 20, 60, 89):
            for roll in (-15, 0, 15):
                up_view = normalize(rotate((0, 1, 0), yaw, pitch, roll))
                for vector in vectors:
                    view = normalize(rotate(vector, yaw, pitch, roll))
                    expected = normalize(vector)[1]
                    actual = view[1] if args.inject_view_y else dot(view, up_view)
                    error = abs(actual - expected)
                    maximum = max(maximum, error)
                    if abs(view[1] - expected) > 1e-6:
                        old_failures += 1
                    if error > 1e-12:
                        raise AssertionError(f"World elevation changes with camera: {vector=} {yaw=} {pitch=} {roll=} {actual=} {expected=}")
                    # Actual user-visible consumers must retain identical weights.
                    for function in (lambda x: smooth(x, -0.16, 0.18),
                                     lambda x: 1 - smooth(abs(x), 0.06, 0.34),
                                     lambda x: max(0, min(1, x * 6 + 0.1)),
                                     lambda x: 1 - abs(x) * 0.18,
                                     lambda x: x * 0.5 + 0.5):
                        if abs(function(actual) - function(expected)) > 1e-12:
                            raise AssertionError("Camera-dependent day/twilight/horizon/up weight")
                    cases += 1
    if old_failures == 0:
        raise AssertionError("Fixtures do not detect the original view-Y defect")
    result = {"evidence_class": "CPU_NUMERICAL_AND_SOURCE_CONTRACT", "cases": cases,
              "maximum_elevation_error": maximum, "old_view_y_counterexamples": old_failures,
              "source_mutation_rejected": True, "minecraft_runtime": "NOT TESTED"}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    main()

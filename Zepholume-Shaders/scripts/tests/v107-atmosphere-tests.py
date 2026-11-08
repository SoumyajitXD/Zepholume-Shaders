"""V1.0.7 source-bound fog endpoint and cloud-distance CPU regressions.

Numerical/source evidence only; real Minecraft scene and performance QA is separate.
"""

import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sat(x):
    return min(1.0, max(0.0, x))


def fog(d, start, end, view_y, rain, potato=False, legacy=False):
    if end <= start:
        return float(d >= start)
    t = sat((d - start) / (end - start))
    if potato:
        return t
    if legacy:
        t = t * t * (3.0 - 2.0 * t)
        return sat(t * (1.0 - abs(view_y) * 0.18) * (0.84 + rain * 0.28))
    clear = t * t
    overcast = t * (2.0 - t)
    weight = sat(rain) * 0.50 + (1.0 - sat(abs(view_y))) * 0.20
    return sat(clear * (1.0 - weight) + overcast * weight)


def cloud_fog(d, start, end, rain, shaped=True, legacy=False):
    if end <= start:
        return float(d >= start)
    t = sat((d - start) / (end - start))
    if not shaped:
        return t
    density = 0.76 + 0.24 * rain
    return t * density if legacy else t * (density + (1.0 - density) * t)


def read_sources(root):
    air = (root / "shaders/lib/atmosphere.glsl").read_text(encoding="utf-8")
    fragment = (root / "shaders/lib/cloud_fragment.glsl").read_text(encoding="utf-8")
    vertex = (root / "shaders/lib/cloud_vertex.glsl").read_text(encoding="utf-8")
    return air, fragment, vertex


def check_sources(sources):
    air, fragment, vertex = sources
    for token in ("float range = fogEnd - fogStart;",
                  "if (range <= 0.0) return distance >= fogStart ? 1.0 : 0.0;",
                  "float linear = zephSaturate((distance - fogStart) / range);",
                  "float clearExtinction = linear * linear;",
                  "float overcastExtinction = linear * (2.0 - linear);",
                  "float curved = mix(clearExtinction, overcastExtinction, weather * 0.50 + horizon * 0.20);"):
        assert token in air, f"Air reference no longer matches source: {token}"
    for token in ("float range = fogEnd - fogStart;",
                  "if (range <= 0.0) return distance >= fogStart ? 1.0 : 0.0;",
                  "float linear = clamp((distance - fogStart) / range, 0.0, 1.0);",
                  "float density = 0.76 + 0.24 * rainStrength;"):
        assert token in fragment, f"Cloud reference no longer matches source: {token}"
    assert "curved * (density + (1.0 - density) * curved)" in air, "Open-air fog does not preserve endpoints"
    assert "linear * (density + (1.0 - density) * linear)" in fragment, "Cloud fog does not preserve endpoints"
    assert "zephCloudViewPosition = viewPosition.xyz;" in vertex, "Cloud distance must be derived after interpolation"
    assert "zephCloudFogFactor(length(zephCloudViewPosition))" in fragment
    assert "varying vec3 zephCloudViewPosition;" in vertex and "varying vec3 zephCloudViewPosition;" in fragment
    assert "zephCloudDistance" not in vertex + fragment, "Legacy nonlinear scalar varying returned"


def numerical_checks():
    cases = 0
    old_end_failures = 0
    # Include tiny positive, nonzero-start, ordinary, equal and reversed ranges.
    for start, end in ((0.0, 1e-6), (0.25, 0.75), (16.0, 64.0), (1.0, 1.0), (2.0, 1.0)):
        for profile in range(5):
            for view_y in (-1.0, -0.5, 0.0, 0.5, 1.0):
                for rain in (0.0, 0.25, 0.5, 0.75, 1.0):
                    distances = [start + (end - start) * i / 100 for i in range(101)] if end > start else [start - 1, start, start + 1]
                    values = [fog(d, start, end, view_y, rain, profile == 0) for d in distances]
                    assert all(math.isfinite(v) and 0 <= v <= 1 for v in values)
                    assert all(a <= b + 1e-12 for a, b in zip(values, values[1:])), "Fog must be monotone"
                    if end > start:
                        assert abs(values[0]) < 1e-12 and abs(values[-1] - 1) < 1e-12
                        assert abs(fog(end + 1, start, end, view_y, rain, profile == 0) - 1) < 1e-12
                        old_end_failures += fog(end, start, end, view_y, rain, profile == 0, True) < 1 - 1e-12
                    else:
                        assert values == [0.0, 1.0, 1.0]
                    clouds = [cloud_fog(d, start, end, rain, profile > 0) for d in distances]
                    assert all(math.isfinite(v) and 0 <= v <= 1 + 1e-12 for v in clouds)
                    assert all(a <= b + 1e-12 for a, b in zip(clouds, clouds[1:]))
                    assert abs(clouds[-1] - 1) < 1e-12
                    cases += 1
    assert old_end_failures > 0, "Negative control must reproduce the old endpoint defect"

    maximum_old_diagonal = 0.0
    maximum_new_diagonal = 0.0
    maximum_old_error = 0.0
    interpolation_cases = 0
    for x in (-3.0, -1.0, 0.2, 2.0):
        for y in (-2.0, -0.4, 1.0, 3.0):
            for width in (0.5, 2.0, 5.0):
                for height in (0.5, 1.0, 4.0):
                    for z in (0.5, 5.0, 16.0):
                        vertices = ((x, y, z), (x + width, y, z), (x + width, y + height, z), (x, y + height, z))
                        norm = lambda p: math.sqrt(sum(c * c for c in p))
                        # Center lies on both possible diagonals; interpolate each.
                        old_a = (norm(vertices[0]) + norm(vertices[2])) * 0.5
                        old_b = (norm(vertices[1]) + norm(vertices[3])) * 0.5
                        point_a = tuple((a + b) * 0.5 for a, b in zip(vertices[0], vertices[2]))
                        point_b = tuple((a + b) * 0.5 for a, b in zip(vertices[1], vertices[3]))
                        expected = norm((x + width * 0.5, y + height * 0.5, z))
                        assert abs(norm(point_a) - expected) < 1e-12
                        assert abs(norm(point_b) - expected) < 1e-12
                        maximum_old_error = max(maximum_old_error, abs(old_a - expected), abs(old_b - expected))
                        maximum_old_diagonal = max(maximum_old_diagonal, abs(old_a - old_b))
                        maximum_new_diagonal = max(maximum_new_diagonal, abs(norm(point_a) - norm(point_b)))
                        interpolation_cases += 1
    assert maximum_old_diagonal > 0.1 and maximum_new_diagonal < 1e-12
    return {"fog_case_groups": cases, "old_endpoint_counterexamples": old_end_failures,
            "cloud_interpolation_cases": interpolation_cases, "maximum_old_diagonal_distance_delta": maximum_old_diagonal,
            "maximum_new_diagonal_distance_delta": maximum_new_diagonal, "maximum_old_distance_error": maximum_old_error}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    sources = read_sources(args.source_root)
    check_sources(sources)
    mutations = ((0, "float clearExtinction = linear * linear;", "float clearExtinction = linear * 0.5;"),
                 (1, "linear * (density + (1.0 - density) * linear)", "linear * density"),
                 (2, "zephCloudViewPosition = viewPosition.xyz;", "zephCloudDistance = length(viewPosition.xyz);"))
    for index, original, replacement in mutations:
        mutated = list(sources)
        mutated[index] = mutated[index].replace(original, replacement)
        try:
            check_sources(mutated)
        except AssertionError:
            pass
        else:
            raise AssertionError(f"Defect mutation {index} escaped detection")
    result = {"status": "PASS", "evidence_class": "SOURCE_BOUND_CPU_REFERENCE", **numerical_checks(),
              "rejected_source_mutations": len(mutations),
              "minecraft_runtime": "NOT TESTED", "minecraft_performance": "NOT MEASURED"}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        if args.output.exists():
            raise FileExistsError(args.output)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

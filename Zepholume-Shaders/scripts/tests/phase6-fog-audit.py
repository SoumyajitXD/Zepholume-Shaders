"""Source-locked, independent numerical checks for the Phase 6 fog audit.

This is a CPU reference for synthetic fixtures, not Minecraft evidence.
"""

import argparse
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STRENGTH = {"Potato": 1.0, "Low": 1.02, "Balanced": 1.06,
            "High": 1.09, "Ultra": 1.12}
ABSORPTION = {"Potato": 0.0, "Low": 0.20, "Balanced": 0.30,
              "High": 0.36, "Ultra": 0.42}


def sat(value):
    return min(1.0, max(0.0, value))


def factor(distance, start, end, medium, profile, view_y=0.0, rain=0.0):
    if end <= start:
        return float(distance >= start)
    linear = sat((distance - start) / (end - start))
    if medium:
        return sat(linear * (STRENGTH[profile] if medium == 1 else 1.0))
    if profile == "Potato":
        return linear
    curved = linear * linear * (3.0 - 2.0 * linear)
    return sat(curved * (1.0 - abs(view_y) * 0.18) * (0.84 + rain * 0.28))


def water_colour(base, profile, night_vision=0.0):
    absorption = ABSORPTION[profile]
    restoration = sat(night_vision) * 0.45
    transmission = (0.76, 0.96, 0.93)
    return [channel * (1.0 - absorption * (1.0 - tint) * (1.0 - restoration))
            for channel, tint in zip(base, transmission)]


def close(actual, expected, tol=2e-4):
    if abs(actual - expected) > tol:
        raise AssertionError(f"actual {actual:.9g}, expected {expected:.9g}")


def check_source():
    fog = (ROOT / "shaders/lib/fog.glsl").read_text(encoding="utf-8")
    air = (ROOT / "shaders/lib/atmosphere.glsl").read_text(encoding="utf-8")
    fragment = (ROOT / "shaders/lib/fragment.glsl").read_text(encoding="utf-8")
    required = ((fog, "float mediumRange = fogEnd - fogStart;"),
                (fog, "if (mediumRange <= 0.0) return d >= fogStart ? 1.0 : 0.0;"),
                (fog, "factor *= 1.06;"), (fog, "return zephSaturate(factor);"),
                (air, "float range = fogEnd - fogStart;"),
                (air, "if (range <= 0.0) return distance >= fogStart ? 1.0 : 0.0;"),
                (fragment, "gl_FragData[0] = vec4(graded, clamp(source.a, 0.0, 1.0));"))
    for source, token in required:
        if token not in source:
            raise AssertionError(f"source equation changed: {token}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--comparison", type=Path,
                        default=ROOT / "artifacts/phase4-gpu/compare-v105-v106/comparisons.json")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    check_source()
    comparisons = json.loads(args.comparison.read_text(encoding="utf-8"))
    changed = [row for row in comparisons if row["maximum_absolute_rgba"] > 0]
    assert len(comparisons) == 25 and len(changed) == 7
    assert all("--fog-end" in row["fixture_args"] and "0.5" in row["fixture_args"] for row in changed)
    assert all(row["maximum_alpha_difference"] == 0 for row in comparisons)

    cases = 0
    for profile in STRENGTH:
        for medium in (0, 1, 2, 3):
            for start, end in ((0.0, 0.5), (0.25, 0.75), (16.0, 64.0),
                               (1.0, 1.0), (2.0, 1.0), (0.0, 1e-5)):
                distances = (start - 0.1, start, (start + end) / 2,
                             end, end + 0.1)
                values = [factor(d, start, end, medium, profile) for d in distances]
                assert all(math.isfinite(v) and 0 <= v <= 1 for v in values)
                if end > start:
                    assert all(a <= b + 1e-12 for a, b in zip(values, values[1:]))
                if end > start and medium:
                    close(factor(start, start, end, medium, profile), 0)
                    close(factor(end, start, end, medium, profile), 1)
                if end <= start:
                    close(factor(start - 0.1, start, end, medium, profile), 0)
                    close(factor(start, start, end, medium, profile), 1)
                cases += 1

    # Tiny-extent fixture: center distance is effectively 0.25. The frozen
    # V1.0.5 control is unfogged because its minimum start is one block.
    rows = {row["case"]: row for row in comparisons}
    midpoint = rows["underwater-midpoint"]
    endpoint = rows["underwater-endpoint"]
    target = water_colour((0.2, 0.3, 0.4), "Balanced")
    for observed, expected in zip(endpoint["treatment_center"][:3], target):
        close(observed, expected)
    midpoint_factor = factor(0.25, 0.0, 0.5, 1, "Balanced")
    for source, observed, fog in zip(midpoint["control_center"][:3],
                                     midpoint["treatment_center"][:3], target):
        close(observed, source * (1 - midpoint_factor) + fog * midpoint_factor)
    close(endpoint["control_center"][3], endpoint["treatment_center"][3], 1e-7)

    result = {"status": "PASS", "evidence_class": "CPU_REFERENCE_AND_PRIOR_SYNTHETIC_GPU_DATA",
              "source_locked": True, "numerical_cases": cases,
              "prior_comparison_cases": len(comparisons), "changed_prior_cases": len(changed),
              "midpoint_factor_balanced": midpoint_factor,
              "water_endpoint_balanced_rgb": target,
              "framebuffer": "RGBA32F floating point; values are not normalized 8-bit deltas",
              "minecraft_verified": False}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

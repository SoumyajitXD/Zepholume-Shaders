"""Run matched synthetic Intel render fixtures and compare frozen controls."""

import argparse
import importlib.util
import json
import math
import struct
import subprocess
import sys
from pathlib import Path


BASELINE_CASES = [
    ("lit-terrain", "gbuffers_terrain", "Balanced", "Overworld", ["--albedo", "0.65", "--light", "1"]),
    ("dark-terrain", "gbuffers_terrain", "Potato", "Overworld", ["--albedo", "0.45", "--light", "0.08"]),
    ("torch", "gbuffers_terrain", "Balanced", "Overworld", ["--albedo", "0.6", "--light", "0.35"]),
    ("sky", "gbuffers_skybasic", "Balanced", "Overworld", []),
    ("sky-horizon", "gbuffers_skybasic", "Balanced", "Overworld", ["--sun-y", "0"]),
    ("water", "gbuffers_water", "Ultra", "Overworld", ["--water", "--albedo", "0.45", "--light", "0.8"]),
    ("underwater", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "0.5"]),
    ("underwater-midpoint", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "0.5", "--quad-extent", "0.001", "--depth", "0.25"]),
    ("underwater-endpoint", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "0.5", "--quad-extent", "0.001", "--depth", "0.5"]),
    ("underwater-normal", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "4", "--fog-end", "20"]),
    ("underwater-nightvision", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--night-vision", "1", "--fog-start", "0", "--fog-end", "0.5"]),
    ("short-air", "gbuffers_terrain", "Balanced", "Overworld", ["--fog-start", "0", "--fog-end", "0.5"]),
    ("clouds", "gbuffers_clouds", "Potato", "Overworld", []),
    ("rain", "gbuffers_terrain", "Balanced", "Overworld", ["--rain", "1"]),
    ("nether", "gbuffers_terrain", "Balanced", "Nether", []),
    ("end", "gbuffers_terrain", "Balanced", "End", []),
    ("glass", "gbuffers_water", "Balanced", "Overworld", ["--albedo", "0.45", "--light", "0.8", "--alpha", "0.3"]),
    ("water-potato", "gbuffers_water", "Potato", "Overworld", ["--water"]),
    ("water-low", "gbuffers_water", "Low", "Overworld", ["--water"]),
    ("water-balanced", "gbuffers_water", "Balanced", "Overworld", ["--water"]),
    ("water-high", "gbuffers_water", "High", "Overworld", ["--water"]),
    ("water-night", "gbuffers_water", "Ultra", "Overworld", ["--water", "--sun-y", "-1"]),
    ("water-horizon", "gbuffers_water", "Ultra", "Overworld", ["--water", "--sun-y", "0"]),
    ("underwater-ultra", "gbuffers_terrain", "Ultra", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "0.5"]),
    ("underwater-potato", "gbuffers_terrain", "Potato", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "0.5"]),
]

TARGETED_CASES = [
    ("underwater-near-zero", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "0.5", "--quad-extent", "0.001", "--depth", "0.01"]),
    ("underwater-beyond", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "0.5", "--quad-extent", "0.001", "--depth", "0.75"]),
    ("underwater-min-visibility", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "0.01", "--quad-extent", "0.001", "--depth", "0.01"]),
    ("underwater-max-visibility", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "1", "--quad-extent", "0.001", "--depth", "0.5"]),
    ("underwater-equal-before", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0.5", "--fog-end", "0.5", "--quad-extent", "0.001", "--depth", "0.25"]),
    ("underwater-equal-at", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0.5", "--fog-end", "0.5", "--quad-extent", "0.001", "--depth", "0.5"]),
    ("underwater-reversed-before", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0.5", "--fog-end", "0.25", "--quad-extent", "0.001", "--depth", "0.25"]),
    ("underwater-reversed-at", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0.5", "--fog-end", "0.25", "--quad-extent", "0.001", "--depth", "0.5"]),
    ("underwater-red-fog", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "0.5", "--fog-color", "0.8", "0.1", "0.1", "--quad-extent", "0.001", "--depth", "0.25"]),
    ("underwater-blue-fog", "gbuffers_terrain", "Balanced", "Overworld", ["--underwater", "--fog-start", "0", "--fog-end", "0.5", "--fog-color", "0.1", "0.1", "0.8", "--quad-extent", "0.001", "--depth", "0.25"]),
    ("lava-medium", "gbuffers_terrain", "Balanced", "Overworld", ["--eye-medium", "2", "--fog-start", "0", "--fog-end", "0.5", "--quad-extent", "0.001", "--depth", "0.25"]),
    ("powder-snow-medium", "gbuffers_terrain", "Balanced", "Overworld", ["--eye-medium", "3", "--fog-start", "0", "--fog-end", "0.5", "--quad-extent", "0.001", "--depth", "0.25"]),
]

CASES = BASELINE_CASES + TARGETED_CASES


def read_pixels(path):
    data = path.read_bytes()
    if len(data) != 32 * 32 * 4 * 4:
        raise ValueError(f"Unexpected framebuffer byte count: {path}")
    return struct.unpack("<4096f", data)


def rgba8(values):
    return bytes(round(max(0, min(1, value)) * 255) for value in values)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--treatment-variants", type=Path, required=True)
    parser.add_argument("--treatment-source", type=Path, required=True)
    parser.add_argument("--control-variants", type=Path, required=True)
    parser.add_argument("--control-source", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--fail-self-test", action="store_true", help="Inject a failed assertion to verify the failure path")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    if args.fail_self_test:
        # Exercise the same machine-readable assertion failure contract without
        # repeating GPU draws that cannot change this intentional false value.
        checks = {"deliberately_broken_assertion": False}
        (args.output_dir / "assertions.json").write_text(json.dumps(checks, indent=2) + "\n", encoding="utf-8")
        if not all(checks.values()):
            raise RuntimeError(f"GPU output regression failed: {checks}")
    renderer = Path(__file__).with_name("native-gl-render.py")
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("zeph_native_render", renderer)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    results = []
    for case_index, (name, program, profile, dimension, extra) in enumerate(CASES):
        paths = {}
        for label, variants, source in (("control", args.control_variants, args.control_source),
                                        ("treatment", args.treatment_variants, args.treatment_source)):
            output = args.output_dir / name / label
            command = [sys.executable, str(renderer), "--variant-root", str(variants), "--source-root", str(source),
                       "--output-dir", str(output), "--program", program, "--profile", profile, "--dimension", dimension] + extra
            if case_index >= len(BASELINE_CASES):
                command.append("--skip-png")
            run = subprocess.run(command, capture_output=True, text=True)
            if run.returncode:
                raise RuntimeError(f"{name}/{label} failed: {run.stderr or run.stdout}")
            paths[label] = output
        before = read_pixels(paths["control"] / "pixels.rgba32f")
        after = read_pixels(paths["treatment"] / "pixels.rgba32f")
        if not all(math.isfinite(value) for value in before + after):
            raise RuntimeError(f"Non-finite output: {name}")
        difference = [abs(a - b) for a, b in zip(before, after)]
        mean = sum(difference) / len(difference)
        maximum = max(difference)
        alpha_max = max(difference[3::4])
        comparison = None
        if case_index < len(BASELINE_CASES):
            # Preserve the established panels; new numerical cases retain raw floats only.
            image = bytearray()
            control8, treatment8 = rgba8(before), rgba8(after)
            diff8 = bytearray(rgba8([min(1, value * 4) if j % 4 != 3 else 1 for j, value in enumerate(difference)]))
            for row in range(32):
                start = row * 32 * 4
                image.extend(control8[start:start + 128])
                image.extend(treatment8[start:start + 128])
                image.extend(diff8[start:start + 128])
            comparison = args.output_dir / name / "comparison.png"
            module.png(comparison, 96, 32, image)
        row = {"case": name, "program": program, "profile": profile, "dimension": dimension,
               "fixture_args": extra, "mean_absolute_rgba": mean, "maximum_absolute_rgba": maximum,
               "maximum_alpha_difference": alpha_max, "comparison_png": str(comparison) if comparison else None,
               "control_center": json.loads((paths["control"] / "result.json").read_text())["center_rgba_float"],
               "treatment_center": json.loads((paths["treatment"] / "result.json").read_text())["center_rgba_float"]}
        results.append(row)
        print(f"{name}: MAE={mean:.6f} max={maximum:.6f} alpha={alpha_max:.6f}", flush=True)
    by_name = {row["case"]: row for row in results}
    def luminance(name):
        return sum(by_name[name]["treatment_center"][:3]) / 3
    checks = {
        "lightmap_darkens": luminance("dark-terrain") < luminance("torch") < luminance("lit-terrain"),
        "glass_alpha_preserved": abs(by_name["glass"]["treatment_center"][3] - round(0.3 * 255) / 255) < 0.002,
        "water_alpha_preserved": abs(by_name["water"]["treatment_center"][3] - round(0.75 * 255) / 255) < 0.002,
        "short_underwater_fog_changed": by_name["underwater"]["maximum_absolute_rgba"] > 0.05,
        "unchanged_cases_match": all(by_name[name]["maximum_absolute_rgba"] < 1e-5 for name in
                                     ("lit-terrain", "torch", "water", "glass", "clouds", "nether", "end")),
        "alpha_identical": all(row["maximum_alpha_difference"] < 1e-5 for row in results),
        "float_readback_probe": all(all(abs(a - b) < 1e-6 for a, b in zip(
            json.loads((args.output_dir / row["case"] / label / "result.json").read_text())["readback_probe_rgba32f"],
            (-0.25, 0.125, 1.25, 0.5))) for row in results for label in ("control", "treatment")),
        "degenerate_before_step": by_name["underwater-equal-before"]["treatment_center"][:3] == by_name["underwater-reversed-before"]["treatment_center"][:3],
        "degenerate_at_step": by_name["underwater-equal-at"]["treatment_center"][:3] == by_name["underwater-reversed-at"]["treatment_center"][:3],
        "endpoint_equals_beyond": all(abs(a - b) < 1e-5 for a, b in zip(by_name["underwater-endpoint"]["treatment_center"], by_name["underwater-beyond"]["treatment_center"])),
    }
    (args.output_dir / "comparisons.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    (args.output_dir / "assertions.json").write_text(json.dumps(checks, indent=2) + "\n", encoding="utf-8")
    if not all(checks.values()):
        raise RuntimeError(f"GPU output regression failed: {checks}")


if __name__ == "__main__":
    main()

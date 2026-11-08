"""V1.0.6-fixed/V1.0.7 full-pack native diagonal regression, never Minecraft.

Both candidates must preserve planar triangulation invariance. Unlike the
historical Phase 8 test, this does not expect a broken pre-interpolation baseline
or require RGB identity where V1.0.7 intentionally corrects water/fog shading.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import struct
import subprocess
import sys
from pathlib import Path


def delta(a, b, channels):
    # Compare the common face interior; waves can displace the outside raster edge.
    return max(abs(a[4 * (32 * y + x) + c] - b[4 * (32 * y + x) + c])
               for y in range(4, 28) for x in range(4, 28) for c in channels)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-variant-root", type=Path, required=True)
    parser.add_argument("--baseline-source-root", type=Path, required=True)
    parser.add_argument("--variant-root", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    # Validate exact source/hash binding before creating any outputs. Every
    # renderer subprocess repeats this contract before compiling its program.
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("zeph_water_diagonal_inputs", Path(__file__).with_name("native-gl-compile.py"))
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)
    bindings = {}
    for label, variant_root, source_root in (
        ("baseline", args.baseline_variant_root, args.baseline_source_root),
        ("treatment", args.variant_root, args.source_root),
    ):
        index, files = native.load_variants(variant_root, source_root)
        bindings[label] = dict(source_root=str(source_root.resolve()), variant_root=str(variant_root.resolve()),
                               source_manifest_sha256=hashlib.sha256((variant_root / "source-manifest.json").read_bytes()).hexdigest(),
                               logical_mappings=len(index), unique_stages=len(files))
    args.output_dir.mkdir(parents=True, exist_ok=False)
    renderer = Path(__file__).with_name("native-gl-render.py")
    cases = [(p.lower(), p, "Overworld", True, False, False)
             for p in ("Potato", "Low", "Balanced", "High", "Ultra")]
    cases += [("nether", "Balanced", "Nether", True, False, False),
              ("end", "Balanced", "End", True, False, False),
              ("nonwater", "Ultra", "Overworld", False, False, False),
              ("underwater", "Ultra", "Overworld", True, True, False),
              ("centered-control", "Low", "Overworld", True, False, True),
              ("shortfog-water", "Ultra", "Overworld", True, False, False),
              ("shortfog-nonwater", "Ultra", "Overworld", False, False, False),
              ("shortfog-underwater", "Ultra", "Overworld", True, True, False)]
    rows = []
    drivers = []
    for name, profile, dimension, water, underwater, centered in cases:
        short_fog = name.startswith("shortfog")
        pixels = {}
        for variant in ("baseline", "treatment"):
            variant_root = args.baseline_variant_root if variant == "baseline" else args.variant_root
            source_root = args.baseline_source_root if variant == "baseline" else args.source_root
            for diagonal in ("forward", "reverse"):
                output = args.output_dir / f"{name}-{variant}-{diagonal}"
                command = [sys.executable, str(renderer), "--variant-root", str(variant_root),
                           "--source-root", str(source_root), "--output-dir", str(output),
                           "--program", "gbuffers_water", "--profile", profile, "--dimension", dimension,
                           "--quad-offset-x", "0" if centered else ".75",
                           "--quad-offset-y", "0" if centered else ".25",
                           "--depth", ".5", "--perspective", "--triangulation", diagonal,
                           "--fog-start", "0" if short_fog else "100",
                           "--fog-end", "2" if short_fog else "1000000000", "--skip-png"]
                if water:
                    command += ["--water"]
                if underwater:
                    command += ["--underwater"]
                completed = subprocess.run(command, capture_output=True, text=True)
                if completed.returncode:
                    raise RuntimeError(f"{name}/{variant}/{diagonal}: {completed.stderr}\n{completed.stdout}")
                values = struct.unpack("<4096f", (output / "pixels.rgba32f").read_bytes())
                assert all(math.isfinite(v) for v in values), "Nonfinite GPU output"
                result = json.loads((output / "result.json").read_text(encoding="utf-8"))
                assert result["finite"] and result["gl_error"] == 0, "Native fixture failure"
                if result["driver"] not in drivers:
                    drivers.append(result["driver"])
                pixels[variant, diagonal] = values
        baseline_diagonal = delta(pixels["baseline", "forward"], pixels["baseline", "reverse"], range(3))
        treatment_diagonal = delta(pixels["treatment", "forward"], pixels["treatment", "reverse"], range(3))
        change = max(delta(pixels["baseline", d], pixels["treatment", d], range(3)) for d in ("forward", "reverse"))
        alpha = max(
            *(delta(pixels["baseline", d], pixels["treatment", d], (3,)) for d in ("forward", "reverse")),
            *(delta(pixels[v, "forward"], pixels[v, "reverse"], (3,)) for v in ("baseline", "treatment")),
        )
        # This iteration changes shared nonwater lighting and water colour in
        # every dimension. Potato is the remaining unchanged shading control;
        # all cases still independently enforce triangulation and alpha bounds.
        unchanged = not short_fog and profile == "Potato"
        passed = (baseline_diagonal < 3e-5 and treatment_diagonal < 3e-5 and alpha <= 1e-6
                  and (not unchanged or change < 3e-5))
        row = dict(case=name, profile=profile, dimension=dimension, water_material=water,
                   underwater=underwater, centered=centered, short_fog=short_fog,
                   baseline_diagonal_rgb_delta=baseline_diagonal, treatment_diagonal_rgb_delta=treatment_diagonal,
                   baseline_treatment_rgb_delta=change, alpha_delta=alpha,
                   unchanged_shading_control=unchanged, passed=passed)
        rows.append(row)
        print(json.dumps(row), flush=True)
    report = dict(evidence_class="SOURCE_BOUND_FULL_PACK_NATIVE_WATER_DIAGONAL",
                  minecraft_runtime="NOT TESTED", drivers=drivers, draws=len(rows) * 4,
                  source_bindings=bindings,
                  geometry="Same 13 historical coplanar fixtures; two diagonals per candidate; perspective projection; central 24x24 pixel comparison",
                  rgb_diagonal_tolerance=3e-5, alpha_tolerance=1e-6, cases=rows,
                  maximum_baseline_diagonal_rgb_delta=max(row["baseline_diagonal_rgb_delta"] for row in rows),
                  maximum_treatment_diagonal_rgb_delta=max(row["treatment_diagonal_rgb_delta"] for row in rows),
                  maximum_alpha_delta=max(row["alpha_delta"] for row in rows),
                  passed=all(row["passed"] for row in rows))
    (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if not report["passed"]:
        raise AssertionError("V1.0.7 native water-diagonal regression; inspect report.json")


if __name__ == "__main__":
    main()

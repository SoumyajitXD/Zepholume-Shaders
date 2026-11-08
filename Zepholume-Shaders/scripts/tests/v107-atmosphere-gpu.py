"""Matched native Intel fog/cloud draws; synthetic evidence, never Minecraft QA."""

import argparse
import json
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--acknowledge-historical-negative-control", action="store_true",
                        help="Baseline must be authentic pre-fix source; current candidates are not valid controls")
    parser.add_argument("--baseline-variants", type=Path, required=True)
    parser.add_argument("--baseline-source", type=Path, required=True, help="Frozen shaders directory")
    parser.add_argument("--variants", type=Path, required=True)
    parser.add_argument("--source", type=Path, default=ROOT / "shaders")
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    if not args.acknowledge_historical_negative_control:
        parser.error("Historical negative-control comparison quarantined: provide authentic pre-fix source and explicitly acknowledge its provenance")
    args.output_dir.mkdir(parents=True, exist_ok=False)
    renders = []

    def draw(label, version, program, profile, extra):
        output = args.output_dir / label / version
        variants = args.baseline_variants if version == "baseline" else args.variants
        source = args.baseline_source if version == "baseline" else args.source
        command = [sys.executable, str(Path(__file__).with_name("native-gl-render.py")),
                   "--variant-root", str(variants), "--source-root", str(source), "--output-dir", str(output),
                   "--program", program, "--profile", profile, "--skip-png", *extra]
        completed = subprocess.run(command, capture_output=True, text=True)
        if completed.returncode:
            raise RuntimeError(f"Native draw {label}/{version}: {completed.stderr}\n{completed.stdout}")
        result = json.loads((output / "result.json").read_text(encoding="utf-8"))
        assert result["finite"] and not result["gl_error"]
        data = (output / "pixels.rgba32f").read_bytes()
        pixels = struct.unpack("<" + "f" * (len(data) // 4), data)
        renders.append({"case": label, "version": version, "center": result["center_rgba_float"]})
        return pixels, result

    fog_color = (0.2, 0.3, 0.4)
    air_color = tuple(a * 0.84 + b * 0.16 for a, b in zip(fog_color, (0.72, 0.78, 0.82)))
    baseline_endpoint_failures = 0
    checks = []
    # At every sampled fragment distance > fogEnd: expect exactly the fog colour.
    for profile in ("Potato", "Low", "Balanced", "High", "Ultra"):
        for program, expected in (("gbuffers_clouds", fog_color), ("gbuffers_terrain", air_color)):
            label = f"endpoint-{program}-{profile}"
            before, old_result = draw(label, "baseline", program, profile, ["--fog-start", "0", "--fog-end", "0.1"])
            after, result = draw(label, "treatment", program, profile, ["--fog-start", "0", "--fog-end", "0.1"])
            error = max(abs(after[i] - expected[i % 4]) for i in range(len(after)) if i % 4 != 3)
            old_error = max(abs(before[i] - expected[i % 4]) for i in range(len(before)) if i % 4 != 3)
            assert error < 2e-6, (label, error, result["center_rgba_float"], expected)
            assert all(before[i] == after[i] for i in range(3, len(after), 4)), "Alpha changed"
            baseline_endpoint_failures += old_error > 1e-3
            checks.append({"case": label, "baseline_maximum_rgb_error": old_error, "treatment_maximum_rgb_error": error})
    assert baseline_endpoint_failures == 8, "Four enabled air and cloud profiles must expose legacy endpoint defect"
    for profile in ("Potato", "Low", "Balanced", "Ultra"):
        images = {}
        for version in ("baseline", "treatment"):
            for diagonal in ("forward", "reverse"):
                label = f"cloud-triangulation-{profile}-{diagonal}"
                images[version, diagonal], _ = draw(label, version, "gbuffers_clouds", profile,
                    ["--fog-start", "0", "--fog-end", "2", "--quad-offset-x", "0.1", "--quad-offset-y", "0.15",
                     "--quad-extent", "0.8", "--triangulation", diagonal, "--perspective"])
        old_delta = max(abs(a - b) for a, b in zip(images["baseline", "forward"], images["baseline", "reverse"]))
        new_delta = max(abs(a - b) for a, b in zip(images["treatment", "forward"], images["treatment", "reverse"]))
        assert old_delta > 1e-4, (profile, old_delta)
        assert new_delta < 2e-6, (profile, new_delta)
        assert all(images["treatment", "forward"][i] == images["treatment", "reverse"][i]
                   for i in range(3, len(images["treatment", "forward"]), 4))
        checks.append({"case": f"cloud-triangulation-{profile}", "baseline_diagonal_maximum_rgba_delta": old_delta,
                       "treatment_diagonal_maximum_rgba_delta": new_delta})
    report = {"status": "PASS", "evidence_class": "SOURCE_BOUND_NATIVE_INTEL_SYNTHETIC_DRAWS",
              "draws": len(renders), "checks": checks, "renders": renders,
              "driver": result["driver"],
              "inputs": {"baseline_variants": str(args.baseline_variants), "baseline_source": str(args.baseline_source),
                         "variants": str(args.variants), "source": str(args.source)},
              "minecraft_runtime": "NOT TESTED", "minecraft_performance": "NOT MEASURED"}
    (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k != "renders"}, indent=2))


if __name__ == "__main__":
    main()

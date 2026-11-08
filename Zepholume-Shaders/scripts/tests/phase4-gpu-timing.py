"""Alternate matched native GPU timer-query workloads for a synthetic comparison."""

import argparse
import json
import statistics
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--treatment-variants", type=Path, required=True)
    parser.add_argument("--treatment-source", type=Path, required=True)
    parser.add_argument("--control-variants", type=Path, required=True)
    parser.add_argument("--control-source", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--program", default="gbuffers_water")
    parser.add_argument("--profile", default="Ultra")
    parser.add_argument("--draws", type=int, default=2000)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    renderer = Path(__file__).with_name("native-gl-render.py")
    runs = []
    for n, label in enumerate("CTTCCTTC"):
        treatment = label == "T"
        path = args.output_dir / f"{n:02d}-{label}"
        command = [sys.executable, str(renderer), "--variant-root",
                   str(args.treatment_variants if treatment else args.control_variants), "--source-root",
                   str(args.treatment_source if treatment else args.control_source), "--output-dir", str(path),
                   "--program", args.program, "--profile", args.profile, "--timing-draws", str(args.draws)]
        if args.program == "gbuffers_water":
            command.append("--water")
        run = subprocess.run(command, capture_output=True, text=True)
        if run.returncode:
            raise RuntimeError(run.stderr or run.stdout)
        result = json.loads((path / "result.json").read_text(encoding="utf-8"))
        timing = result["timing"]
        runs.append({"order": n, "version": "V1.0.6" if treatment else "V1.0.5",
                     "median_ms": timing["median_ms"], "samples_ms": timing["measured_samples"],
                     "shader_hashes": result["variant"]})
        print(f"{n} {label}: {timing['median_ms']:.6f} ms", flush=True)
    control = [row["median_ms"] for row in runs if row["version"] == "V1.0.5"]
    treatment = [row["median_ms"] for row in runs if row["version"] == "V1.0.6"]
    c, t = statistics.median(control), statistics.median(treatment)
    change = (t / c - 1) * 100
    # A small/overlapping synthetic signal does not justify a performance claim.
    # Differences below 2% are smaller than the useful resolution of this tiny fixture.
    if abs(change) < 2:
        classification = "NO MEASURABLE DIFFERENCE"
    elif max(min(control), min(treatment)) <= min(max(control), max(treatment)):
        classification = "INCONCLUSIVE"
    else:
        classification = "SYNTHETIC GPU IMPROVEMENT" if t < c else "SYNTHETIC GPU REGRESSION"
    output = {"program": args.program, "profile": args.profile, "draws_per_query": args.draws,
              "order": "CTTCCTTC", "per_run_warmup_queries": 2, "per_run_measured_queries": 6,
              "control_median_ms": c, "treatment_median_ms": t, "change_percent": change,
              "classification": classification, "runs": runs,
              "scope": "Isolated synthetic 32x32 framebuffer GPU time; not Minecraft frame time or FPS."}
    (args.output_dir / "comparison.json").write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: output[key] for key in ("classification", "control_median_ms", "treatment_median_ms", "change_percent")}))


if __name__ == "__main__":
    main()

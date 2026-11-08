"""Matched Phase 7/8 GPU timers with A/A controls; never Minecraft FPS evidence."""
import argparse
import json
import statistics
import subprocess
import sys
from pathlib import Path


def series(args, program, aa):
    runs = []
    for index, label in enumerate("CTTCCTTC"):
        treatment = label == "T" and not aa
        output = args.output_dir / program / ("aa" if aa else "ab") / f"{index}-{label}"
        command = [sys.executable, str(Path(__file__).with_name("native-gl-render.py")),
                   "--variant-root", str(args.variant_root if treatment else args.baseline_variant_root),
                   "--source-root", str(args.source_root if treatment else args.baseline_source_root),
                   "--output-dir", str(output), "--program", program, "--profile", "Ultra",
                   "--timing-draws", str(args.draws), "--skip-png"]
        if program == "gbuffers_water":
            command.append("--water")
        completed = subprocess.run(command, capture_output=True, text=True)
        if completed.returncode:
            raise RuntimeError(completed.stderr or completed.stdout)
        result = json.loads((output / "result.json").read_text())
        runs.append(dict(order=index, label=label, actual_source="Phase8" if treatment else "Phase7",
                         median_ms=result["timing"]["median_ms"], samples=result["timing"]["measured_samples"],
                         variant=result["variant"]))
        print(f"{program} {'A/A' if aa else 'A/B'} {index}-{label}: {runs[-1]['median_ms']:.6f} ms", flush=True)
    controls = [r["median_ms"] for r in runs if r["label"] == "C"]
    treatments = [r["median_ms"] for r in runs if r["label"] == "T"]
    control, treatment = statistics.median(controls), statistics.median(treatments)
    return dict(control_median_ms=control, treatment_median_ms=treatment,
                change_percent=100 * (treatment / control - 1), runs=runs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("variant-root", "source-root", "baseline-variant-root", "baseline-source-root", "output-dir"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--draws", type=int, default=2000)
    args = parser.parse_args()
    if args.draws < 1:
        parser.error("draws must be positive")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    cases = []
    for program in ("gbuffers_water", "gbuffers_hand"):
        aa = series(args, program, True)
        ab = series(args, program, False)
        # A/A is one observed noise control, not a confidence interval. Require
        # a larger signal and non-overlapping A/B ranges before flagging it.
        noise = max(2.0, abs(aa["change_percent"]))
        controls = [r["median_ms"] for r in ab["runs"] if r["label"] == "C"]
        treatments = [r["median_ms"] for r in ab["runs"] if r["label"] == "T"]
        overlap = max(min(controls), min(treatments)) <= min(max(controls), max(treatments))
        verdict = "NO RESOLVED SYNTHETIC SIGNAL"
        if abs(ab["change_percent"]) > noise and not overlap:
            verdict = "SYNTHETIC REGRESSION SIGNAL" if ab["change_percent"] > 0 else "SYNTHETIC IMPROVEMENT SIGNAL"
        cases.append(dict(program=program, aa=aa, ab=ab, screening_threshold_percent=noise,
                          classification=verdict))
    report = dict(evidence_class="SYNTHETIC_NATIVE_GPU_TIMER", minecraft_fps="NOT MEASURED",
                  scope="32x32 RGBA32F immediate-mode flat quad, Ultra; query elapsed can include submission pacing; no world/loader/frame-time evidence",
                  order="CTTCCTTC", per_run_warmups=2, measured_queries=6,
                  draws_per_query=args.draws, cases=cases)
    (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

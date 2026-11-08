"""Check lower-tier work in hash-bound preprocessed standalone shader bodies.

This is source specialization evidence, not instruction-count, performance or
real GPU-vendor evidence. Uncalled helper definitions are deliberately excluded
when checking main-path call sites, but no driver dead-code elimination is assumed.
"""
import argparse
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path


def body(source, name):
    match = re.search(r"\b" + re.escape(name) + r"\s*\([^;{}]*\)\s*\{", source)
    assert match, f"Function missing: {name}"
    start = match.end()
    depth = 1
    for end in range(start, len(source)):
        depth += (source[end] == "{") - (source[end] == "}")
        if not depth:
            return source[start:end]
    raise AssertionError(f"Unclosed function: {name}")


def check(variant_root, source_root, require_current_gates=False):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("zeph_specialization_inputs", Path(__file__).with_name("native-gl-compile.py"))
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)
    index, files = native.load_variants(variant_root, source_root)
    counts = {}
    checks = 0
    potato_cloud_vertex_analytical = 0
    seen = set()
    for row in index:
        key = row["Profile"], row["Dimension"], row["LoaderModel"], row["Program"], row["Stage"], row["ContentHash"]
        # Mock vendor labels that select identical text are one source check,
        # never additional physical driver executions.
        if key in seen:
            continue
        seen.add(key)
        source = files[row["ContentHash"].lower()][0].read_text(encoding="utf-8-sig")
        profile, program, stage = row["Profile"], row["Program"], row["Stage"]
        counts[profile] = counts.get(profile, 0) + 1
        if program == "gbuffers_water" and stage == "vsh":
            move = body(source, "zephMoveWater")
            if profile in ("Potato", "Low"):
                assert not re.search(r"\b(sin|cos)\s*\(", move), f"{profile} wave trig leaked"
            else:
                assert "sin(" in move and "p.y" in move, f"{profile} swell displacement disappeared"
            if require_current_gates:
                main = body(source, "main")
                if profile == "Potato":
                    assert "mc_Entity" not in source and "zephIsWater" not in source, "unused Potato classification leaked"
                else:
                    assert "mc_Entity" in source and "zephIsWater" in source
                if profile in ("Potato", "Low"):
                    assert "zephMoveWater(" not in main, f"{profile} displacement branch leaked"
                else:
                    assert "zephWaterPhasePosition(" in main and "zephMoveWater(" in main, f"{profile} displacement branch disappeared"
            checks += 1
        if program == "gbuffers_water" and stage == "fsh":
            surface = body(source, "zephWaterSurfaceLinear")
            main = body(source, "main")
            if require_current_gates:
                if profile in ("Potato", "Low"):
                    assert "zephWaterRippleNormal(" not in surface, f"{profile} ripple leaked"
                else:
                    assert "zephWaterRippleNormal(" in surface, f"{profile} ripple disappeared"
            if profile == "Potato":
                assert "return displayColour;" in surface and "zephSpecularLobe" not in surface
                assert "zephWaterSurfaceLinear(" not in main
            elif row["Dimension"] in ("Nether", "End"):
                assert "sunHalf" not in surface and "moonHalf" not in surface
                assert "sunIncidence" not in surface and "moonIncidence" not in surface
            elif profile == "Low":
                assert "sheen" in surface and "sunHalf" not in surface and "moonHalf" not in surface
                assert "moonPosition" not in surface and "zephSpecularLobe(" not in surface
            else:
                assert "sunSpecular" in surface and "moonSpecular" in surface
            checks += 1
        if program == "gbuffers_clouds" and stage == "fsh":
            main = body(source, "main")
            if profile == "Potato":
                assert "sunDir" not in main and "zephDaylightFromDirection" not in main
                assert "nightTint" not in main and "sunRim" not in main
            elif profile == "Low":
                if require_current_gates:
                    assert "zephCloudSolar" in main and "sunDir" not in main
                    assert "zephWorldElevation(" not in main and "zephDaylightFromElevation(" not in main
                else:
                    assert "sunDir" in main
                assert "sunRim" not in main and "twilight" not in main
            elif profile == "Balanced":
                assert "twilight" in main and "sunRim" not in main
            else:
                assert ("forwardSun" in main if require_current_gates else
                        ("sunRim" in main or "forwardSun" in main))
                if require_current_gates:
                    assert ("float relief" in main) == (profile == "Ultra")
                    if profile == "Ultra":
                        assert "cloudField - 0.5" in main
            checks += 1
        if program == "gbuffers_clouds" and stage == "vsh" and profile == "Potato":
            main = body(source, "main")
            potato_cloud_vertex_analytical += "zephWorldElevation(" in main
            if require_current_gates:
                assert "zephWorldElevation(" not in main and "zephCloudNormalUp" not in source
                checks += 1
        if program == "gbuffers_clouds" and stage == "vsh" and profile == "Low" and require_current_gates:
            main = body(source, "main")
            assert "zephCloudSolar" in main and "zephDaylightFromElevation(" in main
            assert "zephWorldElevation(" in main
            checks += 1
        if program == "gbuffers_clouds" and stage == "fsh" and profile == "Potato" and require_current_gates:
            assert "zephCloudNormalUp" not in source
            checks += 1
        if program == "gbuffers_clouds" and profile != "Potato" and require_current_gates:
            assert "zephCloudNormalUp" in source
            checks += 1
        if program == "gbuffers_terrain" and stage == "fsh" and profile == "Potato":
            main = body(source, "main")
            assert "zephApplySceneLighting(" not in main and "zephMaterialResponse(" not in main
            assert "vec3 normal =" not in main, "unused Potato scene normal calculation leaked"
            checks += 1
        if require_current_gates and program == "gbuffers_hand":
            assert "zephNormalView" not in source, f"unused {profile} hand normal leaked"
            checks += 1
        if require_current_gates and program == "gbuffers_terrain":
            if profile == "Potato":
                assert "zephNormalView" not in source, "unused Potato normal varying leaked"
            else:
                assert "zephNormalView" in source, f"{profile} scene normal disappeared"
            checks += 1
    assert set(counts) == {"Potato", "Low", "Balanced", "High", "Ultra"}
    assert checks > 0
    return dict(source_manifest_sha256=hashlib.sha256((variant_root / "source-manifest.json").read_bytes()).hexdigest(),
                logical_mappings=len(index), unique_stages=len(files), source_contexts_by_profile=counts,
                specialization_cases=checks,
                potato_cloud_vertex_contexts_with_unconditional_normal_elevation=potato_cloud_vertex_analytical,
                caveat="Unused cloud vertex varying may be eliminated by link optimization; no driver instruction claim")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant-root", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--baseline-root", type=Path)
    parser.add_argument("--baseline-source-root", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if bool(args.baseline_root) != bool(args.baseline_source_root):
        parser.error("Both baseline paths are required together")
    report = dict(evidence_class="HASH_BOUND_PREPROCESSED_SOURCE_SPECIALIZATION", performance="NOT MEASURED",
                  minecraft_runtime="NOT TESTED", current=check(args.variant_root, args.source_root, require_current_gates=True), passed=True)
    if args.baseline_root:
        report["baseline"] = check(args.baseline_root, args.baseline_source_root)
    if args.output:
        if args.output.exists():
            raise FileExistsError(args.output)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()

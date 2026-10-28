"""Hand lightmap regression. Native fixtures are standalone GLSL, not Minecraft.

Always checks source routing plus injected regressions. With --variant-root,
also renders all five profiles/three dimensions and checks irradiance response,
alpha, and immersed media on the existing source-bound Intel WGL harness.
"""

import argparse
import json
import math
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROFILES = ("Potato", "Low", "Balanced", "High", "Ultra")
DIMENSIONS = ("Overworld", "Nether", "End")
MARKER = "#define ZEPH_LIGHTMAP_LIT_PROGRAM"


def check_route(wrapper, vertex, fragment):
    include = '#include "/lib/fragment.glsl"'
    assert re.search(r"^\s*#define\s+ZEPH_HAND_PROGRAM\s*$", wrapper, re.M), "hand grade route missing"
    assert wrapper.count(MARKER) == 1, "hand must declare the lightmap route once"
    assert wrapper.index(MARKER) < wrapper.index(include), "lightmap flag must precede fragment include"
    assert "(gl_TextureMatrix[1] * gl_MultiTexCoord1).xy" in vertex, "lightmap texture matrix missing"
    assert "uniform sampler2D lightmap;" in fragment, "loader sampler missing"
    sample = "source.rgb *= texture2D(lightmap, zephLightCoord).rgb;"
    assert sample in fragment, "lightmap sample missing"
    assert fragment.index(sample) < fragment.index("graded = zephGradeHand(source.rgb);"), "sample must precede hand grading"
    assert "clamp(source.a, 0.0, 1.0)" in fragment, "source alpha preservation missing"


def check_sources(shader_root):
    vertex = (shader_root / "lib/vertex.glsl").read_text(encoding="utf-8-sig")
    fragment = (shader_root / "lib/fragment.glsl").read_text(encoding="utf-8-sig")
    checked = []
    rejected = []
    for folder in ("", "world0", "world-1", "world1"):
        path = shader_root / folder / "gbuffers_hand.fsh"
        wrapper = path.read_text(encoding="utf-8-sig")
        check_route(wrapper, vertex, fragment)
        checked.append(path.relative_to(shader_root).as_posix())
        # No separate translucent hand route exists: retain the documented
        # gbuffers_hand_water -> gbuffers_hand fallback instead of a water pass.
        assert not (shader_root / folder / "gbuffers_hand_water.fsh").exists(), "new explicit translucent hand needs its own route test"
        for name, changed in (("removed-lightmap", wrapper.replace(MARKER, "")),
                              ("late-lightmap", wrapper.replace(MARKER, "") + MARKER + "\n")):
            try:
                check_route(changed, vertex, fragment)
            except AssertionError:
                rejected.append(f"{folder or 'root'}:{name}")
            else:
                raise AssertionError(f"negative control escaped: {folder}:{name}")
    return dict(wrappers=checked, negative_controls_rejected=rejected)


def render(args, output, profile, dimension, light, alpha=0.75, medium=0):
    command = [sys.executable, str(Path(__file__).with_name("native-gl-render.py")),
               "--variant-root", str(args.variant_root), "--source-root", str(args.source_root),
               "--output-dir", str(output), "--program", "gbuffers_hand", "--profile", profile,
               "--dimension", dimension, "--light", str(light), "--alpha", str(alpha),
               "--eye-medium", str(medium), "--skip-png"]
    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode:
        raise RuntimeError(f"Hand GPU {profile}/{dimension}/{light}/{medium}: {completed.stderr or completed.stdout}")
    result = json.loads((output / "result.json").read_text(encoding="utf-8"))
    rgba = result["center_rgba_float"]
    assert result["finite"] and all(math.isfinite(x) for x in rgba), "nonfinite hand output"
    assert result["gl_error"] == 0, "OpenGL error"
    assert abs(rgba[3] - round(alpha * 255) / 255) < 2e-6, "lightmap or medium altered alpha"
    return result


def check_gpu(args):
    rows = []
    drivers = []
    for profile in PROFILES:
        for dimension in DIMENSIONS:
            samples = []
            for light in (0.0, 0.25, 1.0):
                out = args.output_dir / f"{profile}-{dimension}-light{light}"
                result = render(args, out, profile, dimension, light)
                samples.append(result["center_rgba_float"])
                if result["driver"] not in drivers:
                    drivers.append(result["driver"])
            # Grayscale albedo and no fog isolate the missing irradiance path.
            # It must be black at zero irradiance, monotonic, and unchanged at
            # unit irradiance. The independent reference is quantized RGBA8
            # albedo * irradiance; the neutral hand grade is identity here.
            albedo = round(0.65 * 255) / 255
            for sample, light in zip(samples, (0.0, 0.25, 1.0)):
                expected = albedo * (round(light * 255) / 255)
                assert max(abs(v - expected) for v in sample[:3]) < 2e-6, f"incorrect hand irradiance {profile}/{dimension}/{light}"
            assert samples[0][0] < samples[1][0] < samples[2][0], "full-bright regression"
            rows.append(dict(profile=profile, dimension=dimension, samples_rgba=samples,
                             irradiance_response="PASS", unchanged_daylight_unit_irradiance="PASS"))
    media = []
    for dimension in DIMENSIONS:
        for medium in (1, 2, 3):
            for alpha in (0.25, 1.0):
                result = render(args, args.output_dir / f"media-{dimension}-{medium}-alpha{alpha}",
                                "Balanced", dimension, 0.25, alpha, medium)
                media.append(dict(dimension=dimension, eye_medium=medium, alpha=alpha,
                                  rgba=result["center_rgba_float"], finite=True, preserved_alpha=True))
    return dict(evidence_class="SYNTHETIC_NATIVE_GPU_SOURCE_BOUND", drivers=drivers,
                profile_dimension_cases=rows, immersed_alpha_cases=media,
                render_count=45 + len(media), minecraft_runtime="NOT TESTED",
                limitations="1x1 synthetic lightmap tests multiplication, not spatial block/sky coordinate sampling, real hand/item geometry, emissive item flags, loader bindings, or blending")


def check_baseline(args, gpu):
    baseline_args = argparse.Namespace(variant_root=args.baseline_variant_root,
                                       source_root=args.baseline_source_root)
    samples = []
    for light in (0.0, 0.25, 1.0):
        result = render(baseline_args, args.output_dir / f"baseline-light{light}",
                        "Balanced", "Overworld", light)
        samples.append(result["center_rgba_float"])
    assert samples[0] == samples[1] == samples[2], "baseline did not reproduce missing irradiance response"
    current = next(row for row in gpu["profile_dimension_cases"]
                   if row["profile"] == "Balanced" and row["dimension"] == "Overworld")
    assert max(abs(a - b) for a, b in zip(samples[2], current["samples_rgba"][2])) < 2e-6, "daylight full-irradiance changed"
    assert max(current["samples_rgba"][0][:3]) < 2e-6, "corrected hand still fullbright"
    return dict(evidence_class="SYNTHETIC_NATIVE_GPU_BASELINE_COMPARISON", baseline_samples_rgba=samples,
                baseline_missing_irradiance_response_reproduced=True,
                corrected_zero_irradiance_is_black=True, unit_irradiance_unchanged=True,
                render_count=3)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=ROOT / "shaders")
    parser.add_argument("--variant-root", type=Path)
    parser.add_argument("--baseline-variant-root", type=Path)
    parser.add_argument("--baseline-source-root", type=Path)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "artifacts/phase8/hand")
    args = parser.parse_args()
    if bool(args.baseline_variant_root) != bool(args.baseline_source_root) or (args.baseline_variant_root and not args.variant_root):
        parser.error("baseline comparison requires both baseline roots and --variant-root")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    result = dict(source=check_sources(args.source_root), minecraft_runtime="NOT TESTED")
    if args.variant_root:
        result["gpu"] = check_gpu(args)
        if args.baseline_variant_root:
            result["baseline_comparison"] = check_baseline(args, result["gpu"])
    result["passed"] = True
    (args.output_dir / "report.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    main()

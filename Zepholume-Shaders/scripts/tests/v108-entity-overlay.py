"""Entity overlay contracts and optional standalone Intel WGL pixel checks."""

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ENTITY_MARKER = "#define ZEPH_ENTITY_PROGRAM"
INCLUDE = '#include "/lib/fragment.glsl"'
OVERLAY = "source.rgb = mix(source.rgb, entityColor.rgb, entityColor.a);"
LIGHTMAP = "source.rgb *= texture2D(lightmap, zephLightCoord).rgb;"


def check_source(shader_root):
    fragment = (shader_root / "lib/fragment.glsl").read_text(encoding="utf-8-sig")
    assert "#ifdef ZEPH_ENTITY_PROGRAM\nuniform vec4 entityColor;\n#endif" in fragment
    assert fragment.index("vec4 source = texture2D") < fragment.index(OVERLAY) < fragment.index(LIGHTMAP)
    assert "gl_FragData[0] = vec4(graded, clamp(source.a, 0.0, 1.0));" in fragment

    for dimension in ("", "world0", "world-1", "world1"):
        wrappers = shader_root / dimension
        routes = []
        for path in wrappers.glob("*.fsh"):
            source = path.read_text(encoding="utf-8-sig")
            if ENTITY_MARKER in source:
                assert source.count(ENTITY_MARKER) == 1
                assert source.index(ENTITY_MARKER) < source.index(INCLUDE)
                routes.append(path.name)
        assert routes == ["gbuffers_entities.fsh"], (dimension, routes)


def check_pixels(shader_root, variant_root, output):
    harness = Path(__file__).with_name("native-gl-render.py")
    red = (1.0, 0.0, 0.0, 0.3)
    white = (1.0, 1.0, 1.0, 0.5)
    draws = 0
    driver = None

    def draw(profile, dimension, overlay=None, light=1.0, program="gbuffers_entities"):
        nonlocal draws, driver
        directory = output / str(draws)
        command = [sys.executable, str(harness), "--source-root", str(shader_root),
                   "--variant-root", str(variant_root), "--output-dir", str(directory),
                   "--profile", profile, "--dimension", dimension, "--program", program,
                   "--alpha", "0.25", "--light", str(light), "--skip-png"]
        if overlay is not None:
            command.extend(["--entity-color", *map(str, overlay)])
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stderr or result.stdout)
        evidence = json.loads((directory / "result.json").read_text(encoding="utf-8"))
        rgba = evidence["center_rgba_float"]
        assert evidence["finite"] and evidence["gl_error"] == 0, evidence
        assert abs(rgba[3] - 64 / 255) < 2e-6, rgba
        driver = evidence["driver"]
        draws += 1
        return rgba[:3]

    for profile, dimension in (("Potato", "Overworld"), ("Low", "Nether"), ("Balanced", "End"),
                               ("High", "Overworld"), ("Ultra", "End")):
        plain = draw(profile, dimension)
        zero = draw(profile, dimension, (1.0, 0.5, 0.25, 0.0))
        assert plain == zero, (profile, dimension, plain, zero)
        hurt = draw(profile, dimension, red)
        assert hurt[0] > plain[0] and hurt[1] < plain[1] and hurt[2] < plain[2], (plain, hurt)
        flash = draw(profile, dimension, white)
        assert all(f > p for f, p in zip(flash, plain)), (plain, flash)
        dark = draw(profile, dimension, red, light=0.0)
        assert max(dark) < 2e-6, dark

    for program in ("gbuffers_hand", "gbuffers_terrain", "gbuffers_water"):
        assert draw("Balanced", "Overworld", program=program) == draw("Balanced", "Overworld", red, program=program)
    return {"draws": draws, "driver": driver}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=ROOT / "shaders")
    parser.add_argument("--variant-root", type=Path)
    args = parser.parse_args()
    check_source(args.source_root)
    report = {"source_wrapper_sets": 4}
    if args.variant_root:
        with tempfile.TemporaryDirectory(prefix="zeph-entity-overlay-") as temp:
            report["standalone_wgl"] = check_pixels(args.source_root, args.variant_root, Path(temp))
    print(json.dumps(report))


if __name__ == "__main__":
    main()

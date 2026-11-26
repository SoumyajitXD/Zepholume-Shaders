"""Opt-in Windows fixture for the AST patchers in installed Iris and Oculus JARs.

Consumes hash-bound output from generate-compiled-variants.ps1. This uses
fixture geometry and alpha modes with a standalone JVM, without launching
Minecraft. Only version metadata and installed JARs are read from Minecraft.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from zipfile import ZipFile

JAVA_PROBE = Path(__file__).with_name("LoaderTransformProbe.java").resolve()
LANES = ("Fabric1.20.1", "Forge1.20.1", "Fabric1.21.11", "Fabric26.1.2")
PROFILES = ("Potato", "Low", "Balanced", "High", "Ultra")
DIMS = ("Overworld", "Nether", "End")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def jar_for(version, prefix):
    jars = sorted((version / "mods").glob(prefix + "*.jar"))
    if len(jars) != 1:
        raise RuntimeError(f"Expected one {prefix} JAR in {version / 'mods'}, found {len(jars)}")
    return jars[0]


def classpath(minecraft_root, version, lane, loader, target):
    deps = [loader]
    with ZipFile(loader) as archive:
        for entry in archive.namelist():
            if entry.startswith(("META-INF/jars/glsl-transformer", "META-INF/jars/antlr", "META-INF/jars/jcpp")):
                path = target / Path(entry).name
                path.write_bytes(archive.read(entry))
                deps.append(path)
    lib = (minecraft_root / "libraries").resolve(strict=True)
    manifest = json.loads((version / f"{lane}.json").read_text(encoding="utf-8-sig"))
    for item in manifest.get("libraries", []):
        key = item.get("downloads", {}).get("artifact", {}).get("path")
        if not key:
            coordinate = item.get("name", "").split(":")
            if len(coordinate) == 3:
                group, name, artifact_version = coordinate
                key = "/".join([group.replace(".", "/"), name, artifact_version, f"{name}-{artifact_version}.jar"])
        if key:
            dependency = (lib / key).resolve()
            if not dependency.is_relative_to(lib):
                raise RuntimeError("Version metadata library path escapes the Minecraft libraries directory")
            if dependency.is_file():
                deps.append(dependency)
    if lane == "Forge1.20.1":
        deps.append(next((lib / "net/minecraft/client").glob("1.20.1*/*-srg.jar")))
        deps.append(jar_for(version, "embeddium"))
    else:
        remapped = list((version / ".fabric/remappedJars").glob("*/client-intermediary.jar"))
        deps.append(remapped[0] if remapped else version / (lane + ".jar"))
        deps.append(jar_for(version, "sodium-fabric"))
    return ";".join(map(str, deps))


def run(lane, args, index):
    target = args.output / lane
    target.mkdir()
    version = args.minecraft_root / "versions" / lane
    loader = jar_for(version, "oculus" if lane.startswith("Forge") else "iris")
    report = {"jar": loader.name, "sha256": digest(loader.read_bytes()), "rows": [],
              "source_manifest_sha256": digest((args.corpus / "source-manifest.json").read_bytes()),
              "scope": "Installed loader TransformPatcher in a standalone JVM with fixture attributes. Uses pre-expanded source; excludes full shaderpack/JCPP loading and Minecraft rendering."}
    programs = sorted({program for _, _, program, _ in index})
    if args.entities_only:
        programs = ["gbuffers_entities"]
    requests = []
    for profile in PROFILES:
        for dimension in DIMS:
            for program in programs:
                for overlay in ((True, False) if program == "gbuffers_entities" else (False,)):
                    id = f"{profile}-{dimension}-{program}-{overlay}"
                    variants = []
                    for stage in ("vsh", "fsh"):
                        info = index[profile, dimension, program, stage]
                        path = (args.corpus / info["Artifact"]).resolve(strict=True)
                        if not path.is_relative_to(args.corpus) or path.suffix != f".{stage}":
                            raise RuntimeError("Invalid standalone stage path in corpus index")
                        source = path.read_bytes()
                        if digest(source) != info["ContentHash"].lower():
                            raise RuntimeError("Corpus content hash mismatch: " + info["Artifact"])
                        (target / f"{id}.{stage}").write_bytes(source)
                        variants.append(info["ContentHash"])
                    requests.append(f"{id}\t{program}\t{overlay}")
                    report["rows"].append(dict(id=id, profile=profile, dimension=dimension, program=program,
                                               fixture_overlay_input=overlay, source_sha256=variants,
                                               transform="terrain" if program in ("gbuffers_terrain", "gbuffers_water") else "vanilla"))
    (target / "cases.tsv").write_text("\n".join(requests) + "\n")
    deps = classpath(args.minecraft_root, version, lane, loader, target)
    cmd = [str(args.java), "-Xmx320m", "-cp", deps, str(JAVA_PROBE), str(target)]
    process = subprocess.run(cmd, cwd=target, capture_output=True, text=True, timeout=120)
    if process.returncode:
        print(lane, process.stdout[-500:], process.stderr[-3000:])
        return False
    pairs = set()
    for row in report["rows"]:
        names = [target / (row["id"] + "." + stage) for stage in ("vert", "frag")]
        outputs = [path.read_bytes() for path in names]
        key = tuple(map(digest, outputs))
        if key not in pairs:
            status = subprocess.run([str(args.validator), "-l", *map(str, names)],
                                    cwd=target, capture_output=True, text=True, timeout=15)
            if status.returncode or "WARNING:" in (status.stdout + status.stderr).upper():
                print(lane, row["id"], status.stdout, status.stderr)
                return False
            pairs.add(key)
        if row["program"] == "gbuffers_entities":
            overlay = row["fixture_overlay_input"]
            expected = "in vec4 entityColor;" if overlay else "uniform vec4 entityColor;"
            if expected not in outputs[1].decode():
                print(lane, row["id"], "missing transformed entity overlay declaration", expected)
                return False
            row["overlay_output"] = "transformed varying" if overlay else "legacy uniform"
        row["output_sha256"] = key
    report["logical_transform_count"] = len(report["rows"])
    report["glslang_linked_unique_pairs"] = len(pairs)
    (target / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(lane, "pass", len(report["rows"]), "transforms", len(pairs), "unique glslang links", flush=True)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--minecraft-root", type=Path, required=True, help="Existing Minecraft root containing versions and libraries")
    parser.add_argument("--corpus", type=Path, required=True, help="Existing generated standalone GLSL corpus")
    parser.add_argument("--validator", type=Path, required=True, help="Absolute path to glslangValidator.exe")
    parser.add_argument("--java", type=Path, help="Absolute path to JDK java.exe; defaults to java on PATH")
    parser.add_argument("--output", type=Path, required=True, help="Fresh output directory under an existing parent")
    parser.add_argument("--lane", choices=LANES, help="One installed runtime lane; defaults to all four")
    parser.add_argument("--entities-only", action="store_true", help="Run only the two entity overlay routes")
    args = parser.parse_args()
    if sys.platform != "win32":
        parser.error("this fixture expects the local Windows Minecraft classpath layout")
    java = args.java or shutil.which("java")
    if not java:
        parser.error("Java executable unavailable on PATH, pass --java")
    args.java = Path(java)
    for path in (args.minecraft_root, args.corpus, args.validator, args.java, args.output):
        if not path.is_absolute():
            parser.error(f"expected an absolute path: {path}")
    args.minecraft_root = args.minecraft_root.resolve(strict=True)
    args.corpus = args.corpus.resolve(strict=True)
    args.validator = args.validator.resolve(strict=True)
    args.java = args.java.resolve(strict=True)
    args.output = args.output.resolve()
    if args.output.is_relative_to(args.minecraft_root) or args.output.is_relative_to(args.corpus):
        parser.error("output must be outside Minecraft and the input corpus")
    if not (args.validator.is_file() and args.java.is_file()):
        parser.error("--validator and --java must refer to files")
    raw = json.loads((args.corpus / "index.json").read_text(encoding="utf-8-sig"))
    index = {(r["Profile"], r["Dimension"], r["Program"], r["Stage"]): r for r in raw
             if r["LoaderModel"] == "Iris render-stage model" and r["GpuIdentity"] == "Intel"}
    if any(not re.fullmatch(r"[A-Za-z0-9_]+", program) for _, _, program, _ in index):
        parser.error("invalid shader program name in corpus index")
    args.output.mkdir()
    results = [run(lane, args, index) for lane in ((args.lane,) if args.lane else LANES)]
    return not all(results)


if __name__ == "__main__":
    sys.exit(main())

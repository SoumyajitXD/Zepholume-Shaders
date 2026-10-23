#!/usr/bin/env python3
"""Verify integrity and coverage of externally captured Minecraft QA evidence.

This NEVER launches Minecraft, authenticates capture provenance or approves a release.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

PROFILES = {"Potato", "Low", "Balanced", "High", "Ultra"}
DIMENSIONS = {"Overworld", "Nether", "End"}
REQUIRED_LANES = {("Fabric", "Iris"), ("Forge", "Oculus")}
SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")
COMMIT = re.compile(r"^[0-9a-fA-F]{40}$")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def grounded(root: Path, relative: str, prefix: str) -> Path:
    require(isinstance(relative, str) and relative.startswith(prefix + "/"), f"Path must start {prefix}/")
    require("\\" not in relative and all(p not in ("", ".", "..") for p in relative.split("/")),
            f"Unsafe path: {relative}")
    file = (root / relative).resolve()
    require(file.is_relative_to(root) and file.is_file(), f"Missing or escaping file: {relative}")
    return file


def verify_file(file: Path, expected: str) -> None:
    require(isinstance(expected, str) and bool(SHA256.fullmatch(expected)), f"Invalid digest: {file}")
    require(hashlib.sha256(file.read_bytes()).hexdigest() == expected.lower(),
            f"SHA-256 mismatch: {file}")


def verify(root: Path, manifest_name: str, candidate: str) -> dict:
    root = root.resolve()
    require(bool(COMMIT.fullmatch(candidate)), "Candidate must be a full Git commit SHA")
    manifest = json.loads(grounded(root, manifest_name, "qualification-evidence").read_text(encoding="utf-8-sig"))
    require(manifest.get("schemaVersion") == 1, "Unsupported evidence schema")
    require(manifest.get("candidateCommit", "").lower() == candidate.lower(), "Candidate SHA differs from evidence")
    package = manifest.get("package", {})
    archive = grounded(root, package.get("path"), "Releases")
    require(archive.suffix.lower() == ".zip", "Candidate must be a ZIP")
    verify_file(archive, package.get("sha256"))
    with zipfile.ZipFile(archive) as zip_file:
        require("shaders/shaders.properties" in zip_file.namelist(), "Candidate ZIP does not contain shader root")

    lanes = manifest.get("lanes", [])
    require(isinstance(lanes, list), "Expected lanes array")
    seen = set()
    checked = 0
    for lane in lanes:
        require(isinstance(lane, dict), "Invalid lane")
        key = (lane.get("modLoader"), lane.get("shaderLoader"))
        require(key in REQUIRED_LANES and key not in seen, f"Unsupported or duplicate lane: {key}")
        seen.add(key)
        require(lane.get("minecraftVersion") == "1.20.1" and lane.get("javaMajor") == 17,
                f"Unsupported game/Java qualification: {key}")
        for field in ("shaderLoaderVersion", "rendererVersion", "gpuModel", "gpuDriver", "testDateUtc"):
            require(isinstance(lane.get(field), str) and bool(lane[field].strip()),
                    f"Missing {field}: {key}")
        screenshots = set()
        kinds = set()
        artifacts = lane.get("artifacts", [])
        require(isinstance(artifacts, list), f"Invalid artifact list: {key}")
        for artifact in artifacts:
            require(isinstance(artifact, dict), "Invalid artifact")
            kind = artifact.get("kind")
            require(kind in ("latest-log", "patched-glsl", "frame-times", "screenshot"),
                    f"Unknown evidence kind: {kind}")
            file = grounded(root, artifact.get("path"), "qualification-evidence")
            require(file.stat().st_size > 0, f"Empty evidence file: {file}")
            verify_file(file, artifact.get("sha256"))
            checked += 1
            kinds.add(kind)
            if kind == "screenshot":
                require(file.suffix.lower() == ".png" and file.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n",
                        f"Invalid PNG signature: {file}")
                combo = (artifact.get("profile"), artifact.get("dimension"))
                require(combo[0] in PROFILES and combo[1] in DIMENSIONS and combo not in screenshots,
                        f"Invalid/duplicate screenshot mapping: {combo}")
                screenshots.add(combo)
            if kind == "frame-times":
                require(file.suffix.lower() == ".csv" and
                        "frameTimeMs" in file.read_text(encoding="utf-8-sig").splitlines()[0],
                        f"Missing frameTimeMs CSV field: {file}")
        require({"latest-log", "patched-glsl", "frame-times"} <= kinds,
                f"Missing required loader log/patch/benchmark evidence: {key}")
        missing = {(p, d) for p in PROFILES for d in DIMENSIONS} - screenshots
        require(not missing, f"Missing profile/dimension screenshot evidence for {key}: {sorted(missing)[:3]}")
    require(seen == REQUIRED_LANES, "Both staged Iris and Oculus lanes are required")
    return {"status": "EVIDENCE HASHES VERIFIED", "files": checked, "lanes": len(seen),
            "minecraftRuntime": "NOT VERIFIED BY THIS TOOL",
            "visualPerformanceQA": "REQUIRES MANUAL REVIEW", "releaseReady": False}


def main() -> int:
    if len(sys.argv) != 5:
        print("Usage: verify_runtime_evidence.py <root> <manifest> <candidate-sha> <report>", file=sys.stderr)
        return 2
    try:
        result = verify(Path(sys.argv[1]), sys.argv[2], sys.argv[3])
        Path(sys.argv[4]).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, sort_keys=True))
        return 0
    except (OSError, ValueError, TypeError, KeyError, zipfile.BadZipFile, json.JSONDecodeError) as exc:
        print(f"::error::Release evidence validation BLOCKED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

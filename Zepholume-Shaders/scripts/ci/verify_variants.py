#!/usr/bin/env python3
"""Validate that the generated standalone GLSL corpus covers every declared lane.

This checks source/variant inventory, never real Iris/Oculus loading or hardware.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

PROFILES = ("Potato", "Low", "Balanced", "High", "Ultra")
DIMENSIONS = {"Overworld": "world0", "Nether": "world-1", "End": "world1"}
LOADERS = ("Iris render-stage model", "Conservative Oculus model")
GPUS = ("Generic", "NVIDIA", "AMD", "Intel", "Mesa", "Unknown")
STAGES = ("vsh", "fsh")


def validate(variant_root: Path, shader_root: Path) -> dict:
    variant_root = variant_root.resolve()
    shader_root = shader_root.resolve()
    root_programs = sorted(
        p for p in shader_root.iterdir()
        if p.is_file() and p.suffix.lstrip(".") in STAGES
    )
    if not root_programs:
        raise ValueError("No root shader programs found")
    pairs = {}
    for path in root_programs:
        pairs.setdefault(path.stem, set()).add(path.suffix.lstrip("."))
    if any(stages != set(STAGES) for stages in pairs.values()):
        raise ValueError("Root shader program pairs are incomplete")
    expected = {
        (profile, dimension, loader, path.stem, path.suffix.lstrip("."), gpu)
        for profile in PROFILES
        for dimension in DIMENSIONS
        for loader in LOADERS
        for path in root_programs
        for gpu in GPUS
    }
    manifest = json.loads((variant_root / "index.json").read_text(encoding="utf-8-sig"))
    if not isinstance(manifest, list) or not manifest:
        raise ValueError("Variant index must be a nonempty JSON array")

    observed: set[tuple] = set()
    hashes: dict[str, Path] = {}
    for index, row in enumerate(manifest):
        if not isinstance(row, dict):
            raise ValueError(f"Variant row {index} must be an object")
        try:
            key = tuple(str(row[field]) for field in
                        ("Profile", "Dimension", "LoaderModel", "Program", "Stage", "GpuIdentity"))
            content_hash = str(row["ContentHash"]).lower()
            relative = str(row["Artifact"])
            original = str(row["OriginalSource"])
        except KeyError as exc:
            raise ValueError(f"Variant row {index} missing field {exc}") from exc
        if key in observed:
            raise ValueError(f"Duplicate logical variant mapping: {key}")
        observed.add(key)
        if key not in expected:
            raise ValueError(f"Unexpected profile, dimension, loader, program, stage or GPU identity: {key}")
        expected_source = f"{DIMENSIONS[key[1]]}/{key[3]}.{key[4]}"
        if original != expected_source:
            raise ValueError(f"Incorrect original shader wrapper: {original} != {expected_source}")
        if len(content_hash) != 64 or any(c not in "0123456789abcdef" for c in content_hash):
            raise ValueError(f"Invalid variant SHA-256: {content_hash}")
        expected_artifact = f"unique/{content_hash}.{key[4]}"
        if relative != expected_artifact:
            raise ValueError(f"Variant path differs from content hash: {relative}")
        candidate = (variant_root / relative).resolve()
        if not candidate.is_relative_to(variant_root):
            raise ValueError(f"Escaping variant path: {relative}")
        hashes[relative] = candidate

    missing = expected - observed
    if missing:
        raise ValueError(f"Missing {len(missing)} logical mappings (first: {sorted(missing)[0]})")
    for relative, candidate in sorted(hashes.items()):
        if not candidate.is_file():
            raise ValueError(f"Missing generated GLSL stage: {relative}")
        expected_hash = candidate.stem
        actual_hash = hashlib.sha256(candidate.read_bytes()).hexdigest()
        if actual_hash != expected_hash:
            raise ValueError(f"Tampered or stale preprocessed shader: {relative}")
    existing = {
        p.relative_to(variant_root).as_posix()
        for p in (variant_root / "unique").iterdir() if p.is_file()
    }
    if existing != set(hashes):
        raise ValueError(f"Unreferenced or missing unique variant files: {sorted(existing ^ set(hashes))[:3]}")
    return {
        "evidenceScope": "Standalone macro-model GLSL coverage, not loader-patched or real GPU validation",
        "profiles": len(PROFILES),
        "dimensions": len(DIMENSIONS),
        "loaderModels": len(LOADERS),
        "gpuIdentityLabels": len(GPUS),
        "programPairs": len(pairs),
        "logicalMappings": len(observed),
        "uniqueStages": len(hashes),
        "status": "pass",
    }


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: verify_variants.py <variant-root> <shader-root>", file=sys.stderr)
        return 2
    try:
        root = Path(sys.argv[1])
        report = validate(root, Path(sys.argv[2]))
        (root / "coverage-report.json").write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        print(json.dumps(report, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print(f"::error::Variant coverage validation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

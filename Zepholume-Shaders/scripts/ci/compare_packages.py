#!/usr/bin/env python3
"""Compare two independently built ZIPs by contents and by archive bytes.

Identical members are a mandatory guarantee. ZIP byte parity is reported
separately because compression implementations may produce different streams.
"""
from __future__ import annotations

import hashlib
import json
import sys
import zipfile
from pathlib import Path


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def inventory(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise ValueError(f"Archive missing: {path}")
    entries: dict[str, str] = {}
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            name = info.filename
            if (info.is_dir() or name.startswith("/") or "\\" in name
                    or any(part in ("", ".", "..") for part in name.split("/"))
                    or ":" in name.split("/")[0]):
                raise ValueError(f"Invalid ZIP entry path: {name}")
            if name in entries:
                raise ValueError(f"Duplicate ZIP entry: {name}")
            entries[name] = digest(archive.read(info))
    if "shaders/shaders.properties" not in entries:
        raise ValueError("ZIP does not expose shader pack root")
    return entries


def compare(first: Path, second: Path) -> dict:
    left = inventory(first)
    right = inventory(second)
    missing = sorted(set(left) - set(right))
    extra = sorted(set(right) - set(left))
    changed = sorted(name for name in set(left) & set(right) if left[name] != right[name])
    if missing or extra or changed:
        raise ValueError(
            f"Package content mismatch: missing={missing[:5]} extra={extra[:5]} changed={changed[:5]}"
        )
    first_hash = digest(first.read_bytes())
    second_hash = digest(second.read_bytes())
    return {
        "status": "pass",
        "evidenceScope": "Cross-runner archive content parity; not runtime shader qualification",
        "entryCount": len(left),
        "linuxZipSha256": first_hash,
        "windowsZipSha256": second_hash,
        "archiveBytesIdentical": first_hash == second_hash,
    }


def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: compare_packages.py <linux.zip> <windows.zip> <report.json>", file=sys.stderr)
        return 2
    try:
        report = compare(Path(sys.argv[1]), Path(sys.argv[2]))
        Path(sys.argv[3]).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, sort_keys=True))
        if not report["archiveBytesIdentical"]:
            print("::warning::ZIP contents match but compressed archive bytes differ across runners; cross-platform byte reproducibility is not established.")
        return 0
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"::error::Cross-runner ZIP content parity failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

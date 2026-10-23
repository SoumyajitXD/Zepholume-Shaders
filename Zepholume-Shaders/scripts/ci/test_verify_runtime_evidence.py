#!/usr/bin/env python3
"""Synthetic tests for the manual evidence-integrity gate; NOT Minecraft results."""
from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from verify_runtime_evidence import DIMENSIONS, PROFILES, verify

CANDIDATE = "a" * 40


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class RuntimeEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="zeph-evidence-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "qualification-evidence").mkdir()
        (self.root / "Releases").mkdir()
        archive = self.root / "Releases/candidate.zip"
        with zipfile.ZipFile(archive, "w") as out:
            out.writestr("shaders/shaders.properties", "screen=<profile>\n")
        self.data = {
            "schemaVersion": 1,
            "candidateCommit": CANDIDATE,
            "package": {"path": "Releases/candidate.zip", "sha256": digest(archive.read_bytes())},
            "lanes": [],
        }
        for modloader, shaderloader in (("Fabric", "Iris"), ("Forge", "Oculus")):
            artifacts = []
            prefix = shaderloader.lower()
            for kind, extension, payload in (
                ("latest-log", "log", b"synthetic test log"),
                ("patched-glsl", "glsl", b"#version 330 compatibility\n"),
                ("frame-times", "csv", b"frameTimeMs\n16.7\n16.6\n"),
            ):
                artifacts.append(self.add_artifact(f"{prefix}-{kind}.{extension}", payload, kind))
            for profile in sorted(PROFILES):
                for dimension in sorted(DIMENSIONS):
                    item = self.add_artifact(f"{prefix}-{profile}-{dimension}.png",
                                             b"\x89PNG\r\n\x1a\nsynthetic-test", "screenshot")
                    item.update(profile=profile, dimension=dimension)
                    artifacts.append(item)
            self.data["lanes"].append({
                "minecraftVersion": "1.20.1",
                "modLoader": modloader,
                "shaderLoader": shaderloader,
                "shaderLoaderVersion": "synthetic 1.0",
                "rendererVersion": "synthetic 1.0",
                "javaMajor": 17,
                "gpuModel": "synthetic GPU",
                "gpuDriver": "synthetic driver",
                "testDateUtc": "2026-10-23T00:00:00Z",
                "artifacts": artifacts,
            })
        self.save()

    def add_artifact(self, name, payload, kind):
        relative = f"qualification-evidence/{name}"
        (self.root / relative).write_bytes(payload)
        return {"kind": kind, "path": relative, "sha256": digest(payload)}

    def save(self):
        (self.root / "qualification-evidence/manifest.json").write_text(
            json.dumps(self.data), encoding="utf-8"
        )

    def run_gate(self):
        return verify(self.root, "qualification-evidence/manifest.json", CANDIDATE)

    def test_complete_file_hash_inventory(self):
        result = self.run_gate()
        self.assertFalse(result["releaseReady"])
        self.assertEqual(result["files"], 36)

    def test_missing_screenshot(self):
        self.data["lanes"][0]["artifacts"].pop()
        self.save()
        with self.assertRaisesRegex(ValueError, "Missing profile/dimension"):
            self.run_gate()

    def test_tampered_log(self):
        (self.root / self.data["lanes"][0]["artifacts"][0]["path"]).write_text("tampered")
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            self.run_gate()

    def test_missing_loader(self):
        self.data["lanes"].pop()
        self.save()
        with self.assertRaisesRegex(ValueError, "Both staged"):
            self.run_gate()

    def test_wrong_package(self):
        self.data["package"]["sha256"] = "f" * 64
        self.save()
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            self.run_gate()

    def test_escaping_path(self):
        self.data["lanes"][0]["artifacts"][0]["path"] = "qualification-evidence/../secret.log"
        self.save()
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            self.run_gate()


if __name__ == "__main__":
    unittest.main()

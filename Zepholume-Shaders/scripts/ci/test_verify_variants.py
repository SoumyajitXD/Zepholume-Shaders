#!/usr/bin/env python3
"""Mutation tests proving the CI corpus completeness gate rejects bad inputs."""
from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from verify_variants import DIMENSIONS, GPUS, LOADERS, PROFILES, validate


class VariantCoverageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="zeph-ci-variants-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.shaders = self.root / "shaders"
        self.variants = self.root / "variants"
        self.shaders.mkdir()
        (self.variants / "unique").mkdir(parents=True)
        self.text = b"#version 330 compatibility\nvoid main(){}\n"
        self.hash = hashlib.sha256(self.text).hexdigest()
        for stage in ("vsh", "fsh"):
            (self.shaders / f"example.{stage}").write_bytes(self.text)
            (self.variants / "unique" / f"{self.hash}.{stage}").write_bytes(self.text)
        self.rows = []
        for profile in PROFILES:
            for dimension, directory in DIMENSIONS.items():
                for loader in LOADERS:
                    for stage in ("vsh", "fsh"):
                        for gpu in GPUS:
                            self.rows.append({
                                "Profile": profile,
                                "Dimension": dimension,
                                "LoaderModel": loader,
                                "GpuIdentity": gpu,
                                "Program": "example",
                                "Stage": stage,
                                "ContentHash": self.hash,
                                "Artifact": f"unique/{self.hash}.{stage}",
                                "OriginalSource": f"{directory}/example.{stage}",
                            })
        self.save()

    def save(self):
        (self.variants / "index.json").write_text(json.dumps(self.rows), encoding="utf-8")

    def test_complete_matrix(self):
        report = validate(self.variants, self.shaders)
        self.assertEqual(report["logicalMappings"], len(self.rows))

    def test_missing_mapping_rejected(self):
        self.rows.pop()
        self.save()
        with self.assertRaisesRegex(ValueError, "Missing"):
            validate(self.variants, self.shaders)

    def test_duplicate_mapping_rejected(self):
        self.rows.append(self.rows[0].copy())
        self.save()
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            validate(self.variants, self.shaders)

    def test_wrong_loader_rejected(self):
        self.rows[0]["LoaderModel"] = "Imaginary loader"
        self.save()
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            validate(self.variants, self.shaders)

    def test_corrupted_stage_rejected(self):
        (self.variants / "unique" / f"{self.hash}.vsh").write_bytes(b"corrupt")
        with self.assertRaisesRegex(ValueError, "Tampered"):
            validate(self.variants, self.shaders)


if __name__ == "__main__":
    unittest.main()

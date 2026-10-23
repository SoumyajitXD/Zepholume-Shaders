#!/usr/bin/env python3
"""Positive and negative fixtures for independent ZIP content parity."""
from __future__ import annotations

import tempfile
import unittest
import zipfile
from pathlib import Path

from compare_packages import compare, inventory


class PackageParityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="zeph-parity-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.left = self.root / "a.zip"
        self.right = self.root / "b.zip"
        self.make_zip(self.left, {"shaders/shaders.properties": b"screen=1\n", "shaders/example.fsh": b"source"})
        self.make_zip(self.right, {"shaders/shaders.properties": b"screen=1\n", "shaders/example.fsh": b"source"})

    @staticmethod
    def make_zip(path, entries):
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
            for name, data in entries.items():
                archive.writestr(name, data)

    def test_matching_contents_pass(self):
        result = compare(self.left, self.right)
        self.assertEqual(result["entryCount"], 2)

    def test_changed_contents_fail(self):
        self.make_zip(self.right, {"shaders/shaders.properties": b"screen=1\n", "shaders/example.fsh": b"corrupt"})
        with self.assertRaisesRegex(ValueError, "mismatch"):
            compare(self.left, self.right)

    def test_missing_entry_fails(self):
        self.make_zip(self.right, {"shaders/shaders.properties": b"screen=1\n"})
        with self.assertRaisesRegex(ValueError, "mismatch"):
            compare(self.left, self.right)

    def test_archive_traversal_fails(self):
        self.make_zip(self.right, {"shaders/shaders.properties": b"screen=1\n", "../evil.txt": b"x"})
        with self.assertRaisesRegex(ValueError, "Invalid ZIP entry"):
            inventory(self.right)

    def test_duplicate_entry_fails(self):
        with zipfile.ZipFile(self.right, "w") as archive:
            archive.writestr("shaders/shaders.properties", b"a")
            archive.writestr("shaders/shaders.properties", b"b")
        with self.assertRaisesRegex(ValueError, "Duplicate ZIP entry"):
            inventory(self.right)


if __name__ == "__main__":
    unittest.main()

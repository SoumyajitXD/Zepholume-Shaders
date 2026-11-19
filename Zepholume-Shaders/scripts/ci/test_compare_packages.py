#!/usr/bin/env python3
"""Positive and negative fixtures for independent ZIP content parity."""
from __future__ import annotations

import stat
import tempfile
import unittest
import zipfile
from unittest import mock
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

    def test_entry_count_limit(self):
        with mock.patch("compare_packages.MAX_ENTRIES", 1):
            with self.assertRaisesRegex(ValueError, "too many entries"):
                inventory(self.right)

    def test_expanded_size_limit(self):
        with mock.patch("compare_packages.MAX_EXPANDED_BYTES", 1):
            with self.assertRaisesRegex(ValueError, "expanded size"):
                inventory(self.right)

    def test_member_size_limit(self):
        with mock.patch("compare_packages.MAX_MEMBER_BYTES", 1):
            with self.assertRaisesRegex(ValueError, "member exceeds"):
                inventory(self.right)

    def test_archive_traversal_fails(self):
        self.make_zip(self.right, {"shaders/shaders.properties": b"screen=1\n", "../evil.txt": b"x"})
        with self.assertRaisesRegex(ValueError, "Invalid ZIP entry"):
            inventory(self.right)

    def test_duplicate_entry_fails(self):
        with zipfile.ZipFile(self.right, "w") as archive:
            archive.writestr("shaders/shaders.properties", b"a")
            archive.writestr("shaders/shaders.properties", b"b")
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            inventory(self.right)

    def test_case_colliding_entry_fails(self):
        self.make_zip(self.right, {
            "shaders/shaders.properties": b"screen=1\n",
            "shaders/example.fsh": b"first",
            "shaders/EXAMPLE.fsh": b"second",
        })
        with self.assertRaisesRegex(ValueError, "case-colliding"):
            inventory(self.right)

    def test_nested_windows_ads_path_fails(self):
        self.make_zip(self.right, {"shaders/shaders.properties": b"screen=1\n",
                                   "shaders/cache:stream.fsh": b"x"})
        with self.assertRaisesRegex(ValueError, "Invalid ZIP entry"):
            inventory(self.right)

    def test_windows_device_name_fails(self):
        self.make_zip(self.right, {"shaders/shaders.properties": b"screen=1\n",
                                   "shaders/CON.txt": b"x"})
        with self.assertRaisesRegex(ValueError, "Invalid ZIP entry"):
            inventory(self.right)

    def test_trailing_dot_path_fails(self):
        self.make_zip(self.right, {"shaders/shaders.properties": b"screen=1\n",
                                   "shaders/example.fsh.": b"x"})
        with self.assertRaisesRegex(ValueError, "Invalid ZIP entry"):
            inventory(self.right)

    def test_symlink_entry_fails(self):
        info = zipfile.ZipInfo("shaders/example.fsh")
        info.create_system = 3
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(self.right, "w") as archive:
            archive.writestr("shaders/shaders.properties", b"screen=1\n")
            archive.writestr(info, b"../elsewhere")
        with self.assertRaisesRegex(ValueError, "Symlink"):
            inventory(self.right)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Offline fixtures for asset preparation; no copyrighted resource payload is included."""
import hashlib
import pathlib
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "prepare_assets.py"

class PrepareAssetsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.archive = self.root / "fixture.zip"
        self.assets = self.root / "runtime_assets"
        self.data = self.root / "reference_data"
        self.files = {
            "minecraft-assets-1.18.2/assets/minecraft/textures/block/grass_block_top.png": b"fixture texture bytes",
            "minecraft-assets-1.18.2/assets/minecraft/models/block/cube.json": b'{"parent":"block/cube"}',
            "minecraft-assets-1.18.2/data/minecraft/recipes/example.json": b'{"type":"minecraft:crafting_shaped"}',
            "minecraft-assets-1.18.2/unrelated/readme.txt": b"not part of runtime domains",
        }
        with zipfile.ZipFile(self.archive, "w", zipfile.ZIP_DEFLATED) as z:
            for name, content in self.files.items():
                z.writestr(name, content)

    def run_tool(self, *extra):
        return subprocess.run(
            [sys.executable, str(TOOL), str(self.archive),
             "--asset-destination", str(self.assets),
             "--reference-data-destination", str(self.data),
             "--allow-hash-mismatch", *extra],
            capture_output=True, text=True, check=False,
        )

    def test_extracts_only_minecraft_resource_and_reference_domains(self):
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.assets / "textures/block/grass_block_top.png").read_bytes(), b"fixture texture bytes")
        self.assertEqual((self.assets / "models/block/cube.json").read_bytes(), b'{"parent":"block/cube"}')
        self.assertEqual((self.data / "recipes/example.json").read_bytes(), b'{"type":"minecraft:crafting_shaped"}')
        self.assertFalse((self.assets / "unrelated/readme.txt").exists())
        self.assertIn("ASSET_EXTRACTION_MANIFEST.csv", result.stdout)

    def test_conflicting_files_abort_without_force(self):
        self.assets.mkdir(parents=True)
        target = self.assets / "textures/block/grass_block_top.png"
        target.parent.mkdir(parents=True)
        target.write_bytes(b"keep existing")
        result = self.run_tool()
        self.assertEqual(result.returncode, 3)
        self.assertEqual(target.read_bytes(), b"keep existing")

    def test_force_preserves_conflict_bytes_before_replacement(self):
        self.assets.mkdir(parents=True)
        target = self.assets / "textures/block/grass_block_top.png"
        target.parent.mkdir(parents=True)
        target.write_bytes(b"keep existing")
        result = self.run_tool("--force")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(target.read_bytes(), b"fixture texture bytes")
        backups = list((self.assets.parent / ".preserved-replacements").rglob("grass_block_top.png"))
        self.assertTrue(backups)
        self.assertEqual(backups[0].read_bytes(), b"keep existing")

    def test_hash_mismatch_is_rejected_unless_explicitly_allowed(self):
        result = subprocess.run(
            [sys.executable, str(TOOL), str(self.archive),
             "--asset-destination", str(self.assets),
             "--reference-data-destination", str(self.data)],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("SHA-256 mismatch", result.stdout)

if __name__ == "__main__":
    unittest.main()

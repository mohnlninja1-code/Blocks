#!/usr/bin/env python3
"""Fast, offline smoke tests for the reproducible ZIP audit tool."""
import csv
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest
import zipfile

REPO = pathlib.Path(__file__).resolve().parents[1]
TOOL = REPO / "tools" / "audit_source_archive.py"

class AuditSourceArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.archive = self.root / "fixture.zip"
        self.out = self.root / "out"
        prefix = "minecraft-assets-1.18.2/"
        items = {
            prefix + "assets/minecraft/models/item/generated.json": {"parent": "builtin/generated"},
            prefix + "assets/minecraft/models/item/test_item.json": {
                "parent": "minecraft:item/generated",
                "textures": {"layer0": "minecraft:item/test_item"},
                "display": {"gui": {"rotation": [30, 225, 0]}},
                "overrides": [{"predicate": {"damaged": 1}, "model": "minecraft:item/test_item_damaged"}],
            },
            prefix + "assets/minecraft/blockstates/test_block.json": {
                "variants": {"facing=north": {"model": "minecraft:block/test_block"}},
                "multipart": [],
            },
            prefix + "data/minecraft/recipes/test_item.json": {
                "type": "minecraft:crafting_shaped",
                "pattern": ["X"],
                "key": {"X": {"item": "minecraft:stone"}},
                "result": {"item": "minecraft:test_item", "count": 1},
            },
        }
        with zipfile.ZipFile(self.archive, "w", compression=zipfile.ZIP_DEFLATED) as z:
            for path, data in items.items():
                z.writestr(path, json.dumps(data))
            z.writestr(prefix + "assets/minecraft/textures/item/test_item.png", b"fixture-not-a-real-png")

    def run_audit(self):
        result = subprocess.run(
            [sys.executable, str(TOOL), str(self.archive), "--out", str(self.out), "--allow-hash-mismatch"],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + "\n" + result.stderr)
        return json.loads((self.out / "ARCHIVE_AUDIT_REPORT.json").read_text(encoding="utf-8"))

    def read_rows(self, filename):
        with (self.out / filename).open(newline="", encoding="utf-8") as f:
            return list(csv.DictReader(f))

    def test_inventory_and_integrity(self):
        report = self.run_audit()
        self.assertEqual(report["zip_integrity"], "PASS")
        self.assertEqual(report["non_directory_file_count"], 5)
        self.assertEqual(report["json_file_count"], 4)
        self.assertEqual(report["json_invalid_count"], 0)
        self.assertEqual(report["duplicate_archive_paths"], 0)
        self.assertFalse(report["hash_matches_expected"])

    def test_item_model_details_are_preserved(self):
        self.run_audit()
        rows = {row["model_id"]: row for row in self.read_rows("ITEM_MODELS.csv")}
        self.assertEqual(len(rows), 2)
        item = rows["minecraft:test_item"]
        self.assertEqual(item["parent_resolution"], "SOURCE_MODEL_FOUND")
        self.assertEqual(item["override_count"], "1")
        self.assertIn("layer0", item["texture_layers"])
        self.assertEqual(item["visual_integration_status"], "BLOCKED_MISSING_RUNTIME_AND_EXTRACTED_ASSETS")

    def test_blockstate_and_recipe_coverage(self):
        self.run_audit()
        blocks = self.read_rows("BLOCK_MECHANICS.csv")
        recipes = self.read_rows("RECIPE_COVERAGE.csv")
        self.assertEqual(len(blocks), 1)
        self.assertIn("minecraft:block/test_block", blocks[0]["model_references"])
        self.assertEqual(len(recipes), 1)
        self.assertEqual(recipes[0]["recipe_type"], "minecraft:crafting_shaped")
        self.assertEqual(recipes[0]["result_item"], "minecraft:test_item")

if __name__ == "__main__":
    unittest.main()

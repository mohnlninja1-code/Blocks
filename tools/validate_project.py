#!/usr/bin/env python3
"""Static project structure/data validator; does not claim to validate game behavior."""
from __future__ import annotations
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
failures: list[str] = []
warnings: list[str] = []
checks = 0

def check(condition: bool, message: str, *, warning: bool = False) -> None:
    global checks
    checks += 1
    if condition:
        print("PASS:", message)
    elif warning:
        warnings.append(message)
        print("WARN:", message)
    else:
        failures.append(message)
        print("FAIL:", message)

def read_json(path: pathlib.Path, expected_type: type | tuple[type, ...]):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        check(False, f"{path.relative_to(ROOT)} is valid JSON ({exc})")
        return None
    check(isinstance(value, expected_type), f"{path.relative_to(ROOT)} has expected JSON type")
    return value

def main() -> int:
    for relative in [
        "project.godot", "scenes/main.tscn", "scripts/main.gd", "scripts/block_registry.gd",
        "scripts/save_store.gd", "scripts/sound_bank.gd", "scripts/recipe_registry.gd",
        "scripts/inventory_model.gd", "scripts/voxel_world.gd", "scripts/voxel_player.gd",
        "data/blocks.json", "data/items.json", "data/expanded_blocks.json",
        "data/recipes.json", "data/smelting_recipes.json", "export_presets.cfg",
        "tests/run_tests.gd", "tests/model_loader_tests.gd", "tests/recipe_registry_tests.gd",
    ]:
        check((ROOT / relative).is_file(), f"required project file exists: {relative}")

    blocks = read_json(ROOT / "data/blocks.json", dict) or {}
    items = read_json(ROOT / "data/items.json", dict) or {}
    expanded = read_json(ROOT / "data/expanded_blocks.json", list) or []
    recipes = read_json(ROOT / "data/recipes.json", list) or []
    smelting = read_json(ROOT / "data/smelting_recipes.json", dict) or {}
    block_ids: set[int] = set()
    item_ids: set[int] = set()
    block_names: set[str] = set()
    for key, value in blocks.items():
        try: numeric_id = int(key)
        except ValueError:
            check(False, f"block key is numeric: {key}"); continue
        check(isinstance(value, dict), f"block {key} has a definition")
        if not isinstance(value, dict): continue
        check(numeric_id not in block_ids, f"block ID is unique: {key}")
        check(value.get("name") not in block_names, f"block name is unique: {value.get('name')}")
        block_ids.add(numeric_id); block_names.add(value.get("name", ""))
    item_names: set[str] = set()
    for key, value in items.items():
        try: numeric_id = int(key)
        except ValueError:
            check(False, f"item key is numeric: {key}"); continue
        check(isinstance(value, dict), f"item {key} has a definition")
        if not isinstance(value, dict): continue
        check(numeric_id not in item_ids, f"item ID is unique: {key}")
        check(value.get("name") not in item_names, f"item name is unique: {value.get('name')}")
        item_ids.add(numeric_id); item_names.add(value.get("name", ""))

    expanded_ids: set[int] = set()
    for entry in expanded:
        check(isinstance(entry, dict), "expanded block is an object")
        if not isinstance(entry, dict): continue
        block_id = entry.get("id")
        check(isinstance(block_id, int) and block_id > 0, f"expanded block has positive integer ID: {block_id}")
        if isinstance(block_id, int):
            check(block_id not in block_ids and block_id not in expanded_ids, f"expanded block ID is unique: {block_id}")
            expanded_ids.add(block_id)

    all_ids = block_ids | item_ids | expanded_ids
    for index, recipe in enumerate(recipes):
        check(isinstance(recipe, dict), f"recipe {index} is an object")
        if not isinstance(recipe, dict): continue
        for input_value in recipe.get("inputs", []):
            if not isinstance(input_value, dict): continue
            check(int(input_value.get("id", -1)) in all_ids, f"recipe {recipe.get('id', index)} input ID is registered: {input_value.get('id')}")
        output = recipe.get("output", {})
        if isinstance(output, dict):
            check(int(output.get("id", -1)) in all_ids, f"recipe {recipe.get('id', index)} output ID is registered: {output.get('id')}")
    for input_id, result in smelting.items():
        check(input_id.isdigit(), f"smelting input ID is numeric: {input_id}")
        check(isinstance(result, dict), f"smelting input {input_id} has an object definition")
        if isinstance(result, dict):
            check(int(input_id) in all_ids, f"smelting input {input_id} is registered")
            check(int(result.get("output_id", -1)) in all_ids, f"smelting output {result.get('output_id')} is registered")

    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    autoload_paths = re.findall(r'(?m)^[A-Za-z0-9_]+="\*?res://([^"]+)"', project)
    for path in autoload_paths:
        check((ROOT / path).is_file(), f"autoload source exists: {path}")
    main_match = re.search(r'run/main_scene="res://([^"]+)"', project)
    if main_match:
        check((ROOT / main_match.group(1)).is_file(), f"main scene exists: {main_match.group(1)}")
    scene = (ROOT / "scenes/main.tscn").read_text(encoding="utf-8")
    for path in re.findall(r'path="res://([^"]+)"', scene):
        check((ROOT / path).is_file(), f"scene resource exists: {path}")

    # Explicit/preload paths can be validated statically. Interpolated paths are runtime/data refs.
    explicit_references: set[str] = set()
    for source in list((ROOT / "scripts").glob("*.gd")) + list((ROOT / "scenes").glob("*.tscn")):
        text = source.read_text(encoding="utf-8")
        explicit_references.update(re.findall(r'(?:preload|load)\("res://([^"%]+)"\)', text))
    for path in sorted(explicit_references):
        check((ROOT / path).is_file(), f"literal resource reference exists: {path}")
    assets_root = ROOT / "assets" / "minecraft"
    check(assets_root.is_dir(), "extracted Minecraft asset resource root exists", warning=True)
    check(len(blocks) >= 19, f"starter block registry contains at least 19 entries ({len(blocks)})", warning=True)
    check(len(items) >= 8, f"starter item registry contains at least 8 entries ({len(items)})", warning=True)
    if warnings:
        print(f"\n{len(warnings)} warning(s) indicate known scope/resource gaps; these are not treated as parity passes.")
    print(f"\nStatic project checks: {checks}; failures: {len(failures)}; warnings: {len(warnings)}")
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())

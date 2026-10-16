#!/usr/bin/env python3
"""Inventory a supplied Java 1.18.2 asset ZIP without distributing its payload."""
from __future__ import annotations
import argparse, csv, hashlib, json, pathlib, zipfile
from collections import Counter

EXPECTED_SHA256 = "bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97"
PREFIX = "minecraft-assets-1.18.2/"
ITEM_PREFIX = PREFIX + "assets/minecraft/models/item/"
BLOCKSTATE_PREFIX = PREFIX + "assets/minecraft/blockstates/"
RECIPE_PREFIX = PREFIX + "data/minecraft/recipes/"
INDEX_FILES = {"_all.json", "_list.json"}
BUILTIN_PARENTS = {"block/block", "block/cube", "block/cube_all", "block/cube_bottom_top", "block/cube_column", "block/cube_column_horizontal", "block/cube_mirrored", "block/cube_mirrored_all", "block/cube_directional", "block/orientable", "block/orientable_vertical", "block/cross", "block/tinted_cross", "block/torch", "block/torch_wall", "block/crop", "block/rail", "block/rail_flat", "block/rail_raised_ne", "block/rail_raised_sw", "block/stairs", "block/slab", "block/fence_post", "block/fence_side", "block/wall_post", "block/wall_side", "block/wall_inventory", "item/generated", "item/handheld", "item/handheld_rod", "item/template_spawn_egg", "item/template_skull", "builtin/generated", "builtin/entity"}

def digest_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def canonical_parent(parent: str) -> str:
    return "assets/minecraft/models/" + parent.split(":", 1)[-1] + ".json"

def write_csv(path: pathlib.Path, columns: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=columns, extrasaction="ignore")
        w.writeheader()
        for row in rows:
            w.writerow({k: json.dumps(v, ensure_ascii=False, sort_keys=True, separators=(",", ":")) if isinstance(v, (dict, list)) else v for k, v in row.items()})

def classify(path: str) -> tuple[str, str, str]:
    p = path.lower()
    if p.endswith(("/_all.json", "/_list.json")) or "/_all.json" in p or "/_list.json" in p:
        return "archive_index", "pack_index_metadata", "NOT_RUNTIME_ASSET"
    if "/models/item/" in p: return "item_model", "item_visual_model", "NOT_INTEGRATED"
    if "/models/block/" in p: return "block_model", "block_visual_model", "NOT_INTEGRATED"
    if "/blockstates/" in p: return "blockstate_definition", "block_state_to_model_mapping", "NOT_INTEGRATED"
    if "/textures/" in p: return "texture", "material_or_entity_visual", "NOT_INTEGRATED"
    if "/sounds/" in p and p.endswith(".ogg"): return "sound", "game_audio_event", "NOT_INTEGRATED"
    if "/data/minecraft/recipes/" in p: return "recipe_data", "crafting_recipe", "NOT_INTEGRATED"
    if "/data/minecraft/loot_tables/" in p: return "loot_data", "drop_or_container_loot", "NOT_INTEGRATED"
    if "/data/minecraft/advancements/" in p: return "advancement_data", "advancement_or_unlock", "NOT_INTEGRATED"
    if "/data/minecraft/tags/" in p: return "tag_data", "tag_membership", "NOT_INTEGRATED"
    if p.endswith(".nbt") or "/data/minecraft/structures/" in p: return "structure_or_nbt", "structure_or_world_data", "NOT_INTEGRATED"
    if "/data/minecraft/" in p: return "datapack_data", "world_or_game_reference_data", "NOT_INTEGRATED"
    if p.endswith(".mcmeta"): return "animation_metadata", "animated_texture_metadata", "NOT_INTEGRATED"
    if p.endswith(".png"): return "image", "visual_asset", "NOT_INTEGRATED"
    if p.endswith(".json"): return "json_data", "reference_or_runtime_data", "NOT_INTEGRATED"
    return "other", "reference_or_support_file", "NOT_INTEGRATED"

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("archive", help="path to minecraft-assets-1.18.2.zip")
    ap.add_argument("--out", default="docs/audit-generated")
    ap.add_argument("--allow-hash-mismatch", action="store_true")
    args = ap.parse_args()
    archive = pathlib.Path(args.archive).resolve()
    out = pathlib.Path(args.out).resolve()
    if not archive.is_file(): raise SystemExit("Archive not found: " + str(archive))
    archive_hash = digest_file(archive)
    if archive_hash != EXPECTED_SHA256 and not args.allow_hash_mismatch:
        raise SystemExit("SHA-256 mismatch; expected " + EXPECTED_SHA256 + ", got " + archive_hash)
    out.mkdir(parents=True, exist_ok=True)
    assets, models, item_rows, block_rows, recipe_rows = [], {}, [], [], []
    invalid_json, extensions, classes, duplicate_names = [], Counter(), Counter(), []
    with zipfile.ZipFile(archive) as z:
        infos = z.infolist()
        bad = z.testzip()
        if bad is not None: raise SystemExit("Corrupt ZIP member: " + bad)
        names = {i.filename for i in infos}
        seen = set()
        for info in infos:
            if info.is_dir(): continue
            p = info.filename
            if p in seen: duplicate_names.append(p)
            seen.add(p)
            extension = pathlib.PurePosixPath(p).suffix.lower() or "[none]"
            asset_class, role, status = classify(p)
            sha = hashlib.sha256()
            with z.open(info) as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""): sha.update(chunk)
            assets.append({"archive_path": p, "relative_path": p[len(PREFIX):] if p.startswith(PREFIX) else p, "size_bytes": info.file_size, "extension": extension, "asset_class": asset_class, "intended_role": role, "sha256": sha.hexdigest(), "integration_status": status, "runtime_consumer": "", "verification_evidence": "Archive inventory only; no live runtime consumer proved in inspected repository"})
            extensions[extension] += 1
            classes[asset_class] += 1
            if not p.endswith(".json"): continue
            try: obj = json.loads(z.read(info))
            except Exception as e:
                invalid_json.append({"path": p, "error": str(e)})
                continue
            rel = p[len(PREFIX):] if p.startswith(PREFIX) else p
            if "/assets/minecraft/models/" in p and pathlib.PurePosixPath(p).name not in INDEX_FILES:
                models[rel[:-5]] = obj if isinstance(obj, dict) else {}
            if p.startswith(ITEM_PREFIX) and pathlib.PurePosixPath(p).name not in INDEX_FILES:
                mid = p[len(ITEM_PREFIX):-5]
                parent = obj.get("parent", "") if isinstance(obj, dict) else ""
                textures = obj.get("textures", {}) if isinstance(obj, dict) else {}
                display = obj.get("display", {}) if isinstance(obj, dict) else {}
                overrides = obj.get("overrides", []) if isinstance(obj, dict) else []
                parent_path = canonical_parent(parent) if parent else ""
                parent_file = PREFIX + parent_path if parent_path and PREFIX + parent_path in names else ""
                parent_status = "BUILTIN_PARENT" if parent in BUILTIN_PARENTS else ("SOURCE_MODEL_FOUND" if parent_file else ("NO_PARENT" if not parent else "UNRESOLVED_CHECK"))
                item_rows.append({"model_id": "minecraft:" + mid, "source_path": p, "parent_model": parent, "parent_source_path": parent_file, "parent_resolution": parent_status, "texture_layers": textures, "geometry_source": "Elements or inherited parent; runtime parsing not implemented", "display_transforms": display, "override_count": len(overrides) if isinstance(overrides, list) else 0, "overrides": overrides, "has_durability_or_predicate_variants": bool(overrides), "visual_integration_status": "BLOCKED_MISSING_RUNTIME_AND_EXTRACTED_ASSETS", "behavior_status": "NOT_IMPLEMENTED_OR_VERIFIED", "render_context_tests": "NOT_RUN", "evidence": "Source model JSON exists; no item renderer in current repository"})
            if p.startswith(BLOCKSTATE_PREFIX) and pathlib.PurePosixPath(p).name not in INDEX_FILES:
                variants = obj.get("variants", {}) if isinstance(obj, dict) else {}
                multipart = obj.get("multipart", []) if isinstance(obj, dict) else []
                refs = set()
                def collect(value):
                    if isinstance(value, dict):
                        if isinstance(value.get("model"), str): refs.add(value["model"])
                        for child in value.values(): collect(child)
                    elif isinstance(value, list):
                        for child in value: collect(child)
                collect(variants); collect(multipart)
                block_rows.append({"block_id": "minecraft:" + pathlib.PurePosixPath(p).stem, "source_path": p, "variant_selector_count": len(variants) if isinstance(variants, dict) else 0, "multipart_clause_count": len(multipart) if isinstance(multipart, list) else 0, "model_references": sorted(refs), "model_reference_count": len(refs), "collision_and_selection_shape": "Requires runtime block rules", "placement_and_support": "NOT_STARTED", "drops_and_tools": "NOT_STARTED", "ticks_and_interactions": "NOT_STARTED", "runtime_status": "NOT_STARTED", "test_evidence": "No block-state runtime/test harness in current tree"})
            if p.startswith(RECIPE_PREFIX) and pathlib.PurePosixPath(p).name not in INDEX_FILES:
                o = obj if isinstance(obj, dict) else {}
                result = o.get("result", {})
                result_item = result.get("item", "") if isinstance(result, dict) else (result if isinstance(result, str) else "")
                ingredients = o.get("ingredients", o.get("key", {}))
                recipe_rows.append({"recipe_id": "minecraft:" + p[len(RECIPE_PREFIX):-5], "source_path": p, "recipe_type": o.get("type", "minecraft:crafting_shaped" if "pattern" in o else "minecraft:unknown"), "result_item": result_item, "result_count": result.get("count", 1) if isinstance(result, dict) else 1, "ingredient_definition": ingredients, "recipe_pattern": o.get("pattern", []), "station": "Resolve from recipe type plus workstation rules", "condition_or_unlock": o.get("conditions", []), "runtime_status": "NOT_IMPLEMENTED_OR_VERIFIED", "test_status": "NOT_RUN", "evidence": "Reference JSON exists; recipe service absent from current tree"})
    asset_cols = ["archive_path","relative_path","size_bytes","extension","asset_class","intended_role","sha256","integration_status","runtime_consumer","verification_evidence"]
    write_csv(out / "ASSET_MANIFEST.csv", asset_cols, assets)
    write_csv(out / "ASSET_USAGE.csv", ["archive_path","asset_class","intended_role","runtime_consumer","integration_status","verification_evidence"], [{k:r[k] for k in ["archive_path","asset_class","intended_role","runtime_consumer","integration_status","verification_evidence"]} for r in assets])
    write_csv(out / "ITEM_MODELS.csv", ["model_id","source_path","parent_model","parent_source_path","parent_resolution","texture_layers","geometry_source","display_transforms","override_count","overrides","has_durability_or_predicate_variants","visual_integration_status","behavior_status","render_context_tests","evidence"], item_rows)
    write_csv(out / "BLOCK_MECHANICS.csv", ["block_id","source_path","variant_selector_count","multipart_clause_count","model_references","model_reference_count","collision_and_selection_shape","placement_and_support","drops_and_tools","ticks_and_interactions","runtime_status","test_evidence"], block_rows)
    write_csv(out / "RECIPE_COVERAGE.csv", ["recipe_id","source_path","recipe_type","result_item","result_count","ingredient_definition","recipe_pattern","station","condition_or_unlock","runtime_status","test_status","evidence"], recipe_rows)
    report = {"archive": archive.name, "archive_bytes": archive.stat().st_size, "archive_sha256": archive_hash, "expected_sha256": EXPECTED_SHA256, "hash_matches_expected": archive_hash == EXPECTED_SHA256, "zip_integrity": "PASS", "archive_entries_including_directories": len(infos), "non_directory_file_count": len(assets), "uncompressed_bytes": sum(i.file_size for i in infos if not i.is_dir()), "json_file_count": sum(1 for i in infos if not i.is_dir() and i.filename.endswith(".json")), "json_invalid_count": len(invalid_json), "item_model_json_count": len(item_rows), "block_model_json_count": sum(k.startswith("assets/minecraft/models/block/") for k in models), "blockstate_json_count": len(block_rows), "recipe_json_count": len(recipe_rows), "duplicate_archive_paths": len(duplicate_names), "invalid_json": invalid_json, "user_reported_missing_mechanic_target": 332, "mechanic_list_reconciled": False, "user_reported_missing_item_model_target": 791, "item_model_target_reconciled": False, "target_reconciliation_note": "The numeric targets were not accompanied by named ID lists. Do not fabricate filler rows; archive model count is not project-gap count."}
    (out / "ARCHIVE_AUDIT_REPORT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if invalid_json or duplicate_names: return 2
    print(json.dumps({k: report[k] for k in ["archive_sha256","hash_matches_expected","zip_integrity","non_directory_file_count","json_file_count","json_invalid_count","item_model_json_count","block_model_json_count","blockstate_json_count","recipe_json_count","duplicate_archive_paths"]}, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

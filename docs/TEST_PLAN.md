# Test plan and evidence

## Passed: source archive inventory

- Hash verification: `bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97`.
- ZIP member integrity passed.
- Parsed 8,311 JSON files successfully, 0 invalid JSON.
- Source counts: 14,459 files; 1,235 item models; 1,725 block models; 900 blockstate JSONs; 1,058 recipes.
- Offline audit fixture tests passed 3/3 in GitHub Actions: https://github.com/mohnlninja1-code/Blocks/actions/runs/38949358846.
- New asset-extraction fixture tests cover safe domain filtering, conflict abort, conflict backup with forced replacement, and archive hash mismatch handling. The combined offline tests must pass on the latest commit before calling them CI-verified.

Reproduce the source inventory with:

```sh
python3 tools/audit_source_archive.py /path/to/minecraft-assets-1.18.2.zip --out docs/audit-generated
```

## Passed: foundational Godot checks

Latest evidence: https://github.com/mohnlninja1-code/Blocks/actions/runs/38950885879

- Godot 4.7.2 import/parser: pass.
- Static validator: 142 checks, 0 failures, 1 expected scope warning because extracted assets are absent.
- GDScript foundational suite: 26 passed, 0 failed.
- Headless startup smoke: pass.
- Inventory atomicity/rollback, starter recipe, save/recovery and minimal terrain/edit-save persistence assertions passed.

This is not a full gameplay test suite. Initial runs failed on inferred variable types, which were fixed before the successful run.

## Local source asset preparation

The public workflow must never commit the user-supplied resource payload. To extract a working copy locally:

```sh
python3 tools/prepare_assets.py /path/to/minecraft-assets-1.18.2.zip
```

The tool verifies the expected SHA-256 and ZIP integrity, stages only `assets/minecraft/**` resource assets plus `data/minecraft/**` reference data, and writes `assets/ASSET_EXTRACTION_MANIFEST.csv`. Differing preexisting outputs abort by default; `--force` preserves prior bytes under an ignored backup folder before replacement. Extraction still does not prove runtime integration.

## Required, not yet passed

- Model resolver/parser test coverage (parent inheritance, texture aliases, element geometry, transforms, state variants/multipart).
- Full registries, all 332 mechanic IDs and 791 missing item IDs reconciled to named Java 1.18.2 references.
- All block/item state behavior and visual contexts.
- Every applicable recipe/station type and item transaction edge case.
- Redstone signal/tick, fluid propagation/timing, block entities and automation.
- World-generation differential tests, biomes/caves/structures and chunk-streaming soak.
- All mobs/pathfinding/combat/equipment/drops/persistence.
- Nether portal/structure/mob/progression and End portal/Dragon/gateway/city/ship progression.
- Survival effects/hunger/XP/farming/villagers/sleep/death/respawn.
- Android export through the preset, artifact SHA-256, device install/launch, actual touch combinations, pause/resume and save/reload.
- Capture and inspect screenshots from the **exported GL Compatibility APK**; menu/world/mining/inventory/mobs/Nether/End/day-night/settings layouts.
- Mobile performance/memory profile, 30+ minute session, chunk travel and repeated save/dimension operations.

Final deep bug-hunt follows feature implementation. Fix each reproduced defect and rerun its regression test. No full-game visual or device QA has been performed.
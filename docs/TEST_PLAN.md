# Test plan and current evidence

## Completed in this session: source archive inventory only

- Verified SHA-256 `bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97`.
- `zipfile.testzip()` reported no corrupt member.
- Parsed all 8,311 JSON files successfully (zero invalid JSON).
- Found 1,235 item model JSONs, 1,725 block model JSONs, 900 blockstate JSONs and 1,058 recipe JSONs.
- Audited 14,459 non-directory files and per-file hashes.
- A six-test Python audit-bundle consistency test passed (manifest/usage row counts, item/blockstate/recipe row counts and source hash/report invariants). These tests validate the inventory, not gameplay.

Reproduce with:

```sh
python3 tools/audit_source_archive.py /path/to/minecraft-assets-1.18.2.zip --out docs/audit-generated
```

## Required but NOT RUN

The current repository does not yet contain `tools/validate_project.py`, `tests/run_tests.gd`, or a GitHub Actions workflow, and it is missing runtime script references. The following commands are targets, not existing passes:

```sh
python3 tools/validate_project.py
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --quit-after 5
godot --headless --path . --export-debug "Android" build/blocks-debug.apk
```

## Gameplay and differential test gates

- Registries: every block/item ID, duplicate IDs, aliases, model/texture paths and missing resource references.
- Block states: legal state selectors, multipart resolution, orientation, placement/support, hitboxes, selection shapes, collision, tool/mining/drop rules, scheduled/random ticks and save persistence.
- Item models: parent chains, generated geometry, texture layer indirection, display transforms, predicates/overrides and in-world/hand/GUI/drop visual regressions.
- Recipes/stations: every recipe type/category, tags, station restrictions, recipe unlocks, remainders and atomic transfers with no duplication/loss.
- Inventory/storage: stack limits, pickups, containers, hopper directions, furnace progress/output and save/reload/corruption recovery.
- Fluids/redstone: source and flow propagation, buckets/contact effects/waterlogging; representative signal strength, component directions and exact ticks.
- World: seed determinism, negative coordinates, chunk seams, cave/ore generation, lighting, structures and unload/reload.
- Entities: spawning, navigation, targeting, projectiles, combat/effects, drops, persistence and spawn bounds.
- Dimensions: Nether biomes/fortresses/bastions/portal coordinate scaling; End access, Dragon phases/death/rewards, gateways, cities, ships and exit travel.
- Android: landscape layout, simultaneous touch, release tracking, pause/resume, process suspension, install/launch, save/reload, renderer screenshots, frame time/memory and long sessions.

A final broad bug hunt must be run after feature implementation, with fixes followed by the corresponding regression tests. No engine/device/gameplay tests are reported as passed now.

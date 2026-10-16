# Java 1.18.2 parity matrix — verified state

This is an evidence ledger, not a feature promise. Source data and runtime behavior are assessed separately.

| Area | Evidence in current source | Current result | Status | Required exit evidence |
|---|---|---|---|---|
| Project startup | `project.godot`, `scenes/main.tscn` | Main script, three autoloads and expanded block JSON are missing | BLOCKED | Every referenced file resolves; clean Godot import/startup logs |
| Block catalog/state | 19 starter block records; 900 source blockstate JSONs in ZIP | Starter registry only; pack not staged | NOT IMPLEMENTED | Full 1.18.2 block/state catalog plus placement/physics/drop/tick tests |
| Block models | 1,725 source block model JSONs | No model resolver in repository | NOT IMPLEMENTED | Parent, UV, rotation, multipart and image-regression tests |
| Item models | 8 starter item records; 1,235 source item model JSONs | No complete inventory/item-model renderer | BLOCKED | Reconcile reported 791 missing IDs, then test behavior and render contexts |
| Textures/audio | Source resources exist in ZIP | Runtime consumers and extracted paths are not in tree | NOT INTEGRATED | Correct packaged paths plus renderer/audio evidence |
| Recipes/stations | 6 starter recipes, 2 smelting entries; 1,058 recipe JSONs in ZIP | Recipe autoload missing | NOT IMPLEMENTED | All recipes parsed; atomic transaction and workstation tests |
| Asset inventory | ZIP hash/integrity verified | Full row-level CSVs produced in audit bundle; source archive is not public | AUDITED LOCALLY | Keep manifests reproducible and link each asset to real consumers as implemented |
| Fluids | Source reference assets/data only | No fluid runtime source | NOT IMPLEMENTED | Flow/source/contact/bucket/waterlogging tests against reference ticks |
| Redstone | Source reference assets/data only | No signal/tick simulation source | NOT IMPLEMENTED | Exact power/state/timing circuit tests |
| Block entities/storage | Source reference data only | No authoritative container/block-entity runtime | NOT IMPLEMENTED | Atomic inventory plus save/reload/automation tests |
| Entities/combat | Entity textures/sounds in ZIP | No entity runtime source | NOT IMPLEMENTED | Spawn, AI, combat, drops and persistence tests |
| Overworld generation | Some reference data and NBT in ZIP | No chunk/world generator source | NOT IMPLEMENTED | Seed determinism, chunk seams, caves and structure tests |
| Nether | Source references only | No Nether generator, portals or progression runtime | NOT IMPLEMENTED | Biomes, structures, mobs, portal scaling and progression tests |
| End/Dragon | Source references only | No End generator, Dragon fight or gateways runtime | NOT IMPLEMENTED | Full portal/fight/reward/gateway/city/ship tests |
| Survival progression | Some tags, recipes, loot and advancements in ZIP | No complete player/progression runtime | NOT IMPLEMENTED | Hunger, XP, effects, agriculture, villagers, sleep/death/respawn tests |
| Android landscape/touch | Landscape export preset is configured | Gameplay/UI source absent | BLOCKED | Device touch matrix, safe-area layouts and suspend/resume QA |
| Godot parse/tests | Godot executable not found locally | No CI workflow in baseline tree | NOT RUN | Godot 4.7.2 stable and matching template logs |
| Android APK | Export preset metadata exists | No artifact or device test | NOT RUN | Checksum-verified APK installed and exercised on Android |
| 332 missing mechanics | Only the numeric target is present in the handoff | No named target list recovered | BLOCKED_RECONCILIATION | Reconcile against Java 1.18.2 reference mechanics without filler rows |
| 791 missing item models | Only the numeric target is present in the handoff | ZIP contains 1,235 item-model definitions, not a project-gap list | BLOCKED_RECONCILIATION | Map every reported missing model ID to source model, runtime use and visual tests |

## Status policy

- `NOT_STARTED`: implementation source does not exist.
- `IN_PROGRESS`: traceable code exists, but it is incomplete.
- `IMPLEMENTED_UNVERIFIED`: code exists; required test/reference evidence has not passed.
- `VERIFIED`: implementation passes named tests with recorded evidence.
- `BLOCKED`: required source, list, toolchain or device evidence is unavailable.

No feature is marked VERIFIED from a registry/file count alone. The detailed audit bundle has per-model/per-blockstate/per-recipe rows; it labels them not integrated or not tested until runtime evidence exists.

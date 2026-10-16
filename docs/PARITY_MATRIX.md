# Java Edition 1.18.2 parity matrix — current evidence

This is an evidence ledger, not a feature promise. Registry/resource presence is separate from working gameplay. Statuses use the required vocabulary where possible.

| Area | Current implementation/evidence | Status | Acceptance test still required |
|---|---|---|---|
| Startup/menu | `scripts/main.gd`; Godot 4.7.2 headless scene smoke passed in CI | IMPLEMENTED_UNVERIFIED for desktop/headless flow; mobile UI not verified | On-device launch, screen capture and landscape touch layout |
| Save store | Versioned JSON saves, temp writes, primary/backup rotation/recovery; corruption recovery test passed | IMPLEMENTED_UNVERIFIED | Crash/power-loss and Android app kill/resume matrix |
| Inventory core | Stack merge/split-by-count, atomic cost spending, output-capacity rollback and serialization | IMPLEMENTED_UNVERIFIED | Full item stack rules, equipment, container transfer, all failure/cancel paths |
| Starter recipes | Legacy starter recipe matching and craft transaction; two-plank stick recipe tested | IMPLEMENTED_UNVERIFIED | All Java 1.18.2 recipes/types/tags/stations/remainders/unlocks/reference comparison |
| Smelting data | Parses the scaffold's two-entry object format | IMPLEMENTED_UNVERIFIED | Complete furnace/blast furnace/smoker/campfire timing and output state |
| Voxel storage/chunks | 16×16 chunks, Y=-64…319, seeded noise terrain, 3×3 streaming, visible-face meshes and collision | IMPLEMENTED_UNVERIFIED | Reference world-generation parity, optimized meshing, seams, light, unload, large worlds |
| Block edits | Place/remove storage and save/reload edit-delta tests pass | IMPLEMENTED_UNVERIFIED | All legal block states, collision/selection shape, drops/tools/support/ticks/state persistence |
| First-person movement | Keyboard/mouse actions and simple jump/sprint/sneak/Creative flight code | IMPLEMENTED_UNVERIFIED | Android simultaneous touches/look, actual collision/camera, damage, fall, respawn |
| Item/block catalog | 19 starter blocks and 8 starter items only; empty expanded-block array only repairs missing-file access | NOT_STARTED for full catalog | Complete legal Java 1.18.2 registries and reference IDs |
| Block model renderer | Current renderer creates cube faces using face texture fields or fallback colors | NOT_STARTED for vanilla model parity | Parent inheritance, elements, model/blockstate rotations, UV, variants, multipart and render comparisons |
| Item model renderer | No full first-person/third-person/GUI/dropped model pipeline | NOT_STARTED | All reconciled item IDs and context screenshots/behavior |
| Asset extraction | Hash-safe local extractor; preserves differing working files before forced replacement; four fixture tests added | IMPLEMENTED_UNVERIFIED pending current CI | Extract supplied archive locally and verify exact runtime paths; prove individual resources have live consumers |
| Asset audit | Source archive exact hash, ZIP integrity and JSON parse counts verified; offline audit tool CI passed | VERIFIED for inventory process only | Reproducible fresh run against same source archive, complete manifests retained/versioned |
| Fluids | No source simulation | NOT_STARTED | Source/flow, tick ordering, contacts, buckets, waterlogged states |
| Redstone | No signal simulation | NOT_STARTED | Component logic, update order and exact circuit tick assertions |
| Block entities/storage automation | No authoritative full runtime | NOT_STARTED | All containers, automation directions, tile ticks and reload tests |
| Entities/combat | No full mob runtime; starter handoff's mobs not found | NOT_STARTED | Complete applicable roster, AI goals, drops, attacks, effects and persistence |
| Overworld biomes/structures | Simple noise surface/cave/ore foundation only | NOT_STARTED for Java parity | Java 1.18.2 seed comparison, biomes, caves, ores, structure placement/loot |
| Nether | No Nether generator/travel/progression code | NOT_STARTED | Five biome families, portals, fortresses/bastions, mobs and netherite loop |
| End/Dragon | No End generator/dragon progression code | NOT_STARTED | Portal/platform, fight phases, crystals, rewards, gateways, cities/ships and travel |
| Survival progression | Basic health/hunger display values only; no complete survival simulation | NOT_STARTED | Java difficulty, hunger/exhaustion, XP, status effects, farming, villagers, sleep/death |
| Android packaging/device | Export preset exists, but no APK artifact or device/emulator evidence in current run | NOT RUN | Godot Android templates, JDK17/SDK, export/checksum, install/launch, touch/save/screenshot/perf |
| 332 mechanics gap target | The number is reported by the handoff only; no named list was found | BLOCKED pending reconciliation | Reconcile each feature against a Java 1.18.2 reference catalog without synthetic filler rows |
| 791 item model gap target | The number is reported by the handoff only; archive itself has 1,235 source item-model JSONs | BLOCKED pending reconciliation | Trace every reported missing ID to source model, resolved parent/texture, runtime consumer and visual test |

## Current successful CI evidence

Latest successful Godot workflow: https://github.com/mohnlninja1-code/Blocks/actions/runs/38950885879

- Engine: Godot `4.7.2.stable.official.ed1daf0bf`.
- Static project validator: 142 checks, 0 failures, 1 scope warning (assets not extracted).
- Godot import/resource/script parsing: pass.
- Foundational GDScript tests: 26 passed, 0 failed.
- Headless main-scene smoke launch: pass.

These checks do not claim visual quality, mobile readiness, full Java parity or APK export. Earlier failing runs caught inferred-type errors; their fixes are in the branch and the later run passed.

## Status semantics

- `NOT_STARTED`: implementation does not exist.
- `IN_PROGRESS`: traceable code exists but is incomplete.
- `IMPLEMENTED_UNVERIFIED`: code exists but required reference/device/visual evidence is absent.
- `VERIFIED`: implementation passes specified, reproducible acceptance tests.
- `BLOCKED`: required target list, source, toolchain or device evidence is absent.
- `NOT RUN`: the requested test has not executed.

Do not mark a feature VERIFIED from a registry entry or resource count alone.
# Java Edition 1.18.2 parity matrix — current evidence

This is an evidence ledger, not a feature promise. Resource discovery is separate from correct runtime behavior.

| Area | Current implementation/evidence | Status | Acceptance test still required |
|---|---|---|---|
| Startup/menu | Main menu, world/mode selection and pause flow; headless smoke passed | IMPLEMENTED_UNVERIFIED | Landscape device launch, visual capture, pause/resume and touch |
| New-world defaults | Survival + normal Overworld selected by default; Creative and Superflat remain available | IMPLEMENTED_UNVERIFIED | End-to-end creation/save/reload on Android |
| Survival spawn | Searches near origin for land, avoids identified ocean/river biomes, positions above sea level; regression passed | IN_PROGRESS | Verify in real rendered world across many seeds and verify spawn collision/biome |
| Biome terrain prototype | Seeded continentalness, erosion/ridge, temperature/humidity and river fields; multiple valid Java 1.18.2 biome IDs; biome-dependent surface blocks, water level, cave carving, ore placements and trees | IN_PROGRESS | Implement exact Java 1.18.2 climate/noise settings, surface rules, 3D carvers, ore/feature distributions, biome edges and reference seed comparison |
| Superflat | Optional four-layer Classic Flat preset (bedrock Y=0, dirt Y=1–2, grass Y=3); layer/mode save tests pass | IMPLEMENTED_UNVERIFIED | Verify full Superflat preset and exact layer semantics against Java 1.18.2 |
| Save store | Versioned JSON, temp writes, primary/backup rotation/recovery; tests pass | IMPLEMENTED_UNVERIFIED | Crash/power-loss, app-kill/resume and Android storage tests |
| Inventory core | Stack insert/remainder, atomic costs, output-capacity rollback and serialization | IMPLEMENTED_UNVERIFIED | Java stack/equipment/container transfer behavior and all cancel/failure paths |
| Recipes and tags | Source recipe traversal, shaped/shapeless matching, nested item tags and cooking-result/timing conversion; 16 fixture tests pass | IN_PROGRESS | Run over every archive recipe/tag and finish replacement/order, conditions, remainders, unlocks, recipe books and stations |
| Block model resolver | Parent inheritance, texture aliases, variants, weighted models and multipart selectors; tests pass | IN_PROGRESS | Full asset-pack coverage, built-in parent behavior, UV-lock, culling and rotations |
| Block model mesher | Builds faces from model elements and source textures; fixture integration passes | IN_PROGRESS | All variant shapes, light/AO/tint/render layers, correct transparency, boundary culling and screenshot comparisons |
| Item model renderer | Source texture icons, first-person selected-item node, inherited element meshes and generated-item extrusion from source alpha; fixture tests pass | IN_PROGRESS | Full predicate/override and GUI/ground/fixed/head/third-person contexts, animations, glint and screenshots |
| Sound events | Looks up source `sounds.json` events and referenced OGG paths | IN_PROGRESS | Stage all OGG files and verify live world/entity/UI playback, spatial audio and volume |
| Source archive | SHA/integrity and JSON counts verified; extraction has staging, hash checks, conflict backup and manifest | VERIFIED for the archive-audit process only | Stage archive in the actual build workspace and verify every used resource path |
| Fluids | No authoritative fluid simulation | NOT_STARTED | Java source/flow rules, update ticks, buckets, contact effects and waterlogged states |
| Redstone | No signal simulation | NOT_STARTED | Signal strengths/directionality/update order and exact circuit tick assertions |
| Block entities/automation | No complete runtime | NOT_STARTED | Containers, furnaces, hoppers, dispensers, signs, persistence and automation |
| Entities/combat | No complete mob runtime | NOT_STARTED | All Java 1.18.2 entities, AI goals, pathfinding, combat, drops and save state |
| Overworld structures | No accurate structure generator | NOT_STARTED | All applicable structures, placement, layout, encounters, loot and reference-seed tests |
| Nether/End | No authoritative dimension/progression loop | NOT_STARTED | Dimensions, portals, structures, boss, rewards and travel |
| Android packaging/device | Landscape preset exists; no APK artifact or device evidence | NOT RUN | Templates/JDK/SDK, APK export/checksum, install/launch, touch/save/reload/screenshots/perf |
| 332 mechanics target | Reported by handoff; no authoritative named list recovered | BLOCKED pending reconciliation | Reconcile every row against a Java 1.18.2 reference catalog |
| 791 item-model target | Archive contains 1,235 item-model JSONs; no authoritative 791-ID target list recovered | BLOCKED pending reconciliation | Link each target item to exact model, texture, consumer and visual test |

## Latest successful CI

https://github.com/mohnlninja1-code/Blocks/actions/runs/38958535541

Godot 4.7.2 results: 7 archive/extraction fixtures, 44 foundation tests, 29 model resolver/renderer tests, 16 recipe/tag tests, and 17 Creative catalog tests passed; headless main-scene smoke passed. The biome checks prove only that the prototype selects diverse valid biome names and finds a dry spawn. They do not prove Java 1.18.2 world-generation parity.

## Status semantics

- NOT_STARTED: implementation does not exist.
- IN_PROGRESS: code exists, behavior incomplete or acceptance evidence missing.
- IMPLEMENTED_UNVERIFIED: code exists but full reference/device/visual acceptance is absent.
- VERIFIED: only the exact named acceptance check passed.
- BLOCKED: an authoritative reference list, staged assets, toolchain or required evidence is unavailable.
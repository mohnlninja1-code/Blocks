# Java Edition 1.18.2 parity matrix — current evidence

This is an evidence ledger, not a feature promise. Resource discovery is separate from correct runtime behavior.

| Area | Current implementation/evidence | Status | Acceptance test still required |
|---|---|---|---|
| Startup/menu | Main menu, world/mode selection and pause flow; Godot 4.7.2 smoke launch passed | IMPLEMENTED_UNVERIFIED | Device launch and gameplay screenshots; pause/resume on Android |
| Creative catalog | Searchable list based on runtime registry, 72-result display cap, selects entries into the active hotbar, source model textures used as icons when assets are staged; 8 UI tests pass | IMPLEMENTED_UNVERIFIED | Run with the full ZIP staged; reconcile all entries and test every block/item select/place path on device |
| Save store | Versioned JSON, temp writes, primary/backup rotation/recovery; corruption recovery test passed | IMPLEMENTED_UNVERIFIED | Crash/power-loss, app-kill/resume and Android storage tests |
| Inventory core | Stack insertion/remainder, atomic costs, output-capacity rollback and serialization; 29 foundational tests pass | IMPLEMENTED_UNVERIFIED | Java stack rules, drag/drop, equipment, containers, recipe remainders and cancellation |
| Recipes and tags | Source recipe traversal, shaped/shapeless matching, nested item-tag references, cooking-result normalization and timing; 16 fixture tests pass | IN_PROGRESS | Run against every supplied recipe/tag file; implement replacement semantics, all condition/remainder/unlock behavior, recipe books and station rules |
| Chunk/world storage | Chunk storage, seeded noise terrain, Y −64…319, streaming region, visible-face meshes and collision | IMPLEMENTED_UNVERIFIED | Java worldgen comparison, seams, large worlds, lighting and measured mobile performance |
| Block edits/states | Place/remove deltas and state property save/load APIs exist | IMPLEMENTED_UNVERIFIED | Every legal state, support/neighbour rules, collision/selection shape, drops, tools, ticks and state persistence |
| Block model resolver | Source model parent inheritance, aliases, blockstate variants, weighted selections and multipart selectors; regression tests pass | IN_PROGRESS | Coverage of the full pack, special built-in parents, UV-lock, rotations, tint, render layers and reference screenshots |
| Block model mesher | Builds faces from source model element JSON and referenced source textures; fixture integration tests pass | IN_PROGRESS | Full resource-staged render test, face culling, AO/light, transparency, render layers, non-cube shapes and visual comparisons |
| Item model renderer | Item texture icons, first-person selected-item node, inherited element meshes and generated-item extrusion from source texture alpha; fixture tests pass | IN_PROGRESS | All predicates/overrides, GUI/ground/fixed/head/left-hand contexts, animations, glint, third person and reference screenshots |
| Sound events | Parses source sounds.json and selects referenced OGG samples by event | IN_PROGRESS | Stage every OGG, verify path coverage, spatial/world audio, entity/UI events and volume settings |
| Source archive | SHA/integrity and JSON counts verified; extraction pipeline uses staging, hash checks, conflict backup and manifest | VERIFIED for audit process only | Extract into the runtime build workspace and verify all resolved paths from the game |
| Fluids | No authoritative fluid simulation | NOT_STARTED | Flow/source rules, ticks, buckets, contacts, waterlogging and render/collision behavior |
| Redstone | No signal simulation | NOT_STARTED | Components, update order and tick-accurate circuit assertions |
| Block entities/automation | No authoritative complete runtime | NOT_STARTED | Containers, signs, furnaces, hoppers, dispensers and reload/update tests |
| Entities/combat | No complete mob runtime | NOT_STARTED | Correct roster, AI/pathfinding, attacks, effects, drops and persistence |
| Overworld biomes/structures | Simple noise surface/cave/ore foundation only | NOT_STARTED for Java parity | Version-matched seed tests, biomes, caves, ores, structure placement and loot |
| Nether/End | No authoritative dimension/progression loop | NOT_STARTED | Dimension terrain, portals, structures, boss encounter, rewards and travel |
| Android packaging/device | Landscape Android export preset exists; no APK artifact or device evidence | NOT RUN | Templates/JDK/SDK, export and checksum, install/launch, touch/save/reload/performance |
| 332 mechanics gap target | Count reported by handoff; no complete named target list was recovered | BLOCKED pending reconciliation | Reconcile each item against a Java 1.18.2 reference catalogue |
| 791 item-model gap target | Archive inventory has 1,235 item model JSONs; no authoritative 791-ID list was recovered | BLOCKED pending reconciliation | Trace each target ID to model, texture, runtime consumer and visual test |

## Latest successful CI

https://github.com/mohnlninja1-code/Blocks/actions/runs/38956921930

Godot 4.7.2 results: 7 archive/fixture tests, 29 foundational tests, 29 model tests, 16 recipe/tag tests and 8 Creative catalog UI tests passed; main-scene headless smoke launch passed. This is not proof of full source-resource coverage or visual/gameplay parity.

## Status semantics

- NOT_STARTED: implementation does not exist.
- IN_PROGRESS: traceable code exists but remains incomplete.
- IMPLEMENTED_UNVERIFIED: code exists but reference/device/visual acceptance evidence is absent.
- VERIFIED: only the exact named acceptance check passed.
- BLOCKED: required reference list, asset staging, toolchain or other prerequisite is unavailable.
# Known issues / release blockers

**Release status: BLOCKED. The current branch has a tested foundation, not Java 1.18.2 parity and not a delivered APK.**

1. Catalog scope remains tiny: 19 starter blocks and 8 starter items. `data/expanded_blocks.json` is deliberately empty, not a reconstructed registry.
2. `scripts/voxel_world.gd` currently uses a small seeded noise-based terrain/cave/ore generator; it is not Java 1.18.2 terrain, biome, cave, ore or structure generation.
3. World meshing currently handles cube-shaped starter blocks and face texture fields/fallback colors, not the Minecraft model-parent/blockstate/multipart renderer. Most source assets are not staged in the runtime tree until locally extracted, and visual output has not been inspected.
4. The item-model renderer for GUI, hand, dropped item and third-person contexts is not implemented.
5. Fluid simulation, Redstone timing, all block-entity inventories/automation, most recipes/stations and recipe tags/unlocks/remainders are incomplete.
6. The complete entity roster, goal-based AI/pathfinding, combat/status effects, drops/equipment/persistence and spawn controls are absent.
7. Nether/End generation, portals, travel, fortress/bastion, dragon fight, gateways, city/ship and progression are not implemented.
8. Survival rules are incomplete; the current health/hunger values are only starter UI/player state.
9. Android assets need local extraction and packaging rules. Full source assets must not be committed publicly without established distribution rights.
10. The reported 332 missing mechanics and 791 missing item models have no named target lists recovered. Archive counts are not a substitute for reconciling the IDs.
11. Godot CI on run 38950885879 passed import, project parse, 142 static checks (0 failures, one asset-scope warning), 26 foundational tests and main-scene smoke launch. Latest asset-prep fixture CI must be inspected separately after the latest workflow changes.
12. No Android APK export, package checksum, install/launch, device touch/input, save/reload, visual review or performance profile is evidenced. Dropbox has no verified build release from this session.

## Known foundations risk

The successful smoke test starts the main menu, but the newly created world's full visual output has not been rendered and inspected on a real graphical renderer/device. Treat startup, chunk-generation assertions and menu scene load as narrow tests, not proof the gameplay is crash-free or visually correct.
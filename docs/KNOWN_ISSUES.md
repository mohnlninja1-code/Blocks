# Known issues / release blockers

**Release status: BLOCKED. This branch is not a complete or playable Java 1.18.2-parity game.**

1. `scenes/main.tscn` references missing `scripts/main.gd`.
2. `project.godot` declares missing autoload scripts `scripts/save_store.gd`, `scripts/sound_bank.gd`, and `scripts/recipe_registry.gd`.
3. `scripts/block_registry.gd` reads missing `data/expanded_blocks.json`.
4. The starter registry is only 19 blocks, 8 items, 6 crafting recipes and 2 smelting recipes.
5. Runtime source for chunks/world generation, player controls, inventory, entity AI/combat, block entities, fluids, redstone, model rendering, dimension travel and the game UI is absent from the inspected tree.
6. The original ZIP is not staged into `assets/minecraft/`; archive assets are not proven to have runtime consumers.
7. Audit found 1,235 item model JSONs, 900 blockstate JSONs and 1,058 recipe JSONs in the source archive; all rows require implementation and tests. The reported 791 missing item models and 332 mechanics are not backed by named target lists yet.
8. A Godot parser/test workflow and Android CI workflow are absent. Local Godot and adb are unavailable; JDK 17 was not found.
9. No Android APK, checksum, install/launch log, renderer screenshots, touch/input evidence, save/reload evidence, or performance profile exists in this session.
10. The local metadata audit bundle passed six inventory consistency tests; these are audit-ledger tests only and do not exercise the game engine.

## Visual defect policy

After runtime and renderer paths exist, a source change alone does not close a rendering defect. Reproduce, fix, rerun the affected test, and inspect exported-renderer screenshots for seams, holes, UV/rotation errors, transparency/z-fighting, missing or magenta textures, light discontinuities, clipped UI and collision/geometry mismatch.

Do not label any item or mechanic complete until the implementation and its applicable reference/regression tests pass.

# Blocks: Voxel Frontier

Godot 4.7.2-targeted landscape voxel sandbox with Minecraft Java Edition 1.18.2 as the only gameplay reference target.

## Current status

The branch is an actively tested development foundation, not a complete Java Edition recreation and not a delivered APK. New worlds now default to **Survival + normal Overworld biome generation**. Creative mode and the valid Superflat world preset remain available; neither is the default. The older procedural-noise prototype remains in code only for compatibility with older saves.

Latest successful Godot workflow: https://github.com/mohnlninja1-code/Blocks/actions/runs/38958535541

It passed archive/fixture tests (7), foundational runtime tests (44), model resolver/renderer tests (29), source recipe/tag tests (16), Creative catalog UI/source-discovery tests (17), and the headless main-scene smoke launch.

## Implemented foundations

- Main menu, landscape Android export preset, touch-action buttons, basic first-person movement, block mining/placement, saves with backup recovery, inventory transactions and chunked world storage.
- New-world options default to Survival and normal Overworld. Superflat remains an optional valid Java 1.18.2 preset.
- An early seeded climate/biome terrain pipeline selects Java 1.18.2 biome identifiers over broad regions and includes different surface families, water level, caves, ores and biome-appropriate tree species. It is **not** yet vanilla's exact 1.18.2 noise-settings, surface-rule, cave, ore, tree/feature or structure generation.
- A source JSON model/blockstate resolver with parent inheritance, texture aliases, variants, deterministic weighted selections and multipart selectors.
- Basic block-element mesh generation from source model JSON and item/icon rendering from source models and supplied textures. Generated-item extrusion uses the alpha pixels of the source texture; no new texture art is synthesized.
- Sound-event lookup against the pack's sounds.json and OGG paths.
- Source recipe loading, nested item-tag lookup and Java-style cooker timing/result normalization, with focused fixture tests.
- Searchable Creative Catalog UI that uses source-model textures when the ZIP is staged, allows selecting entries into the hotbar and caps visible results at 72 for mobile performance.
- Hash-checked local asset extraction, archive inventory tooling and auditable coverage tests.

All above systems are partial. A passing fixture test does not prove a matching feature works across every resource or in a real mobile build.

## Source archive

Supplied archive SHA-256: `bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97`.

Verified inventory: 14,459 files, 8,311 valid JSON files, 1,235 item-model JSONs, 1,725 block-model JSONs, 900 blockstate JSONs and 1,058 recipe JSONs. The untouched original ZIP is kept outside Git. Full third-party source resource files and extracted copies are excluded from the public tree. Stage them locally with:

```sh
python3 tools/prepare_assets.py /path/to/minecraft-assets-1.18.2.zip
```

The runtime name-discovery catalog currently assigns temporary local IDs where starter definitions are absent. It is not a reference-ID-reconciled Java 1.18.2 registry.

## Still missing / not delivered

Exact Java 1.18.2 world generation and structures; full registry/state behavior; complete model/render-layer/lighting parity; scheduled ticks, fluids, Redstone, block entities/automation, all crafting stations, all entities/combat/survival progression, Nether and End progression, broad visual regression tests and all associated bug fixing remain outstanding.

No APK has been exported, installed or device-tested. The authoring environment has Java 21 but no Godot executable, matching Android export templates or Android SDK/adb. GitHub Actions currently validates the Godot source project but does not export an APK. The ZIP must be staged in the actual build workspace before any APK can claim to contain the supplied assets.
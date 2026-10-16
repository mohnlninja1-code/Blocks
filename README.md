# Blocks: Voxel Frontier

Godot 4.7.2-targeted landscape voxel sandbox. The current reference baseline is Minecraft Java Edition 1.18.2 because that is the version represented by the supplied resource/data ZIP.

## Current status

This is an actively tested foundation, not a complete Java Edition recreation and not a delivered APK. The latest successful Godot workflow is:
https://github.com/mohnlninja1-code/Blocks/actions/runs/38956921930

That run passed archive/fixture tests (7), foundational runtime tests (29), model resolver/renderer tests (29), source recipe/tag tests (16), Creative catalog UI tests (8), and the headless main-scene smoke launch.

## Implemented foundations

- Main menu, landscape Android export preset, touch-action buttons, basic first-person movement, mining/placement, saves with backup recovery, inventory transactions and a chunked seeded world.
- A source JSON model/blockstate resolver, including parent inheritance, texture aliases, variants, deterministic weighted selections and multipart selectors.
- Basic block-element mesh generation from source model JSON and first-person/item-icon rendering from source models and textures. Generated-item side geometry is derived from opaque pixels in the supplied texture; no new texture art is synthesized.
- Sound-event lookup against the pack's sounds.json and OGG paths.
- Source recipe loading, nested item-tag lookup and Java-style cooker timing/result normalization, with focused fixture tests.
- Searchable Creative Catalog UI that uses source-model textures when the resource ZIP has been extracted, allows selecting a result into the hotbar, and caps the visible list at 72 entries for mobile memory/performance.
- Hash-checked local asset extraction and archive audit tools.

These are partial integrations only. Passing fixture tests does not prove that every source resource or gameplay rule works.

## Source archive

The supplied archive's SHA-256 is:
bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97

The verified inventory recorded 14,459 files, 8,311 valid JSON files, 1,235 item-model JSON files, 1,725 block-model JSON files, 900 blockstate JSON files and 1,058 recipe JSON files. The original ZIP has not been modified. Full third-party resources are intentionally excluded from the Git tree; extracted files are also excluded. Stage the original archive in the local project workspace using:

python3 tools/prepare_assets.py /path/to/minecraft-assets-1.18.2.zip

The runtime catalog assigns temporary local IDs to discovered entries; it is not yet a complete, reference-ID-reconciled Java registry. Asset presence and catalogue name discovery are not evidence of correct block behavior.

## Build and known gaps

See docs/DELIVERY_STATUS.md, docs/PARITY_MATRIX.md, docs/KNOWN_ISSUES.md and docs/BUILD_ANDROID.md.

No APK has been exported, installed or device-tested in this session. The authoring workspace has no Godot binary, matching Android export templates or Android SDK/adb; GitHub Actions currently validates the source project but does not export an APK. The current noisy terrain generator is not Java-compatible world generation; fluids, Redstone, block entities/automation, entities, structures, and Nether/End progression remain incomplete.
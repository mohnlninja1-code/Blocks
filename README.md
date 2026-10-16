# Blocks: Voxel Frontier

Native GDScript voxel-sandbox project targeting **Godot 4.7.2 stable** and Android. This repository contains the playable development milestone, selected supplied resource-pack art/audio, source audits, automated test script and an Android debug-APK workflow.

**Important: this is not yet a completed Minecraft Java 1.18.2 recreation or a release candidate.** Fluids, Redstone, most blocks/items/recipes/mobs, complete biomes/structures, Nether/End, deep progression, exported screenshot review and Android device validation remain outstanding. We will not call renderer compatibility verified until actual output has been inspected.

## Setup

Run `python3 tools/prepare_assets.py --force` to restore the 75 explicitly selected texture/audio files from `assets/blocks-artwork.zip.b64`. Then open `project.godot` in Godot 4.7.2 stable. See `docs/BUILD_ANDROID.md` and `docs/TEST_PLAN.md` for checks and export steps.

## Source checks

```sh
python3 tools/validate_project.py
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --quit-after 5
```

GitHub Actions provisions pinned Godot 4.7.2/templates, restores selected assets, validates references, imports and tests the project, smoke-starts the main scene, and exports `blocks-debug.apk` as `blocks-android-debug`. A successful export is not a visual/gameplay release certification.

## Asset accounting

`docs/ASSET_USAGE.csv` maps each of 75 selected assets to a live consumer. The source archive contained 14,459 files and its complete asset audit was produced locally as `docs/ASSET_MANIFEST.csv`; the compact per-file report is available in the project archive from this conversation and its compressed/encoded copy in this repository. The original full archive is not copied into the repository. Most supplied reference assets remain unintegrated; see `docs/ASSET_MANIFEST.md` and `docs/FEATURE_MATRIX.md`.

## Renderer

GL Compatibility is selected for a conservative OpenGL ES-oriented Android path. This source configuration has not been rendered or inspected in this environment, so the final Android visual gate remains unresolved. See `docs/KNOWN_ISSUES.md`.
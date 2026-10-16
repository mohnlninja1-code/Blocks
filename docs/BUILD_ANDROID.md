# Android build status and prerequisites

## Required target

- Godot Engine 4.7.2 stable and matching Android export templates.
- JDK 17 plus Android SDK/platform/build-tools and adb.
- GL Compatibility renderer, landscape-only orientation.
- Application ID `org.blocks.voxelfrontier`.
- Debug APK only; never commit signing credentials.

## What is verified

Latest successful Godot workflow: https://github.com/mohnlninja1-code/Blocks/actions/runs/38958535541

It passed project import/parse, static validation, 7 archive/extraction tests, 44 foundation tests (including biome IDs and Survival spawn), 29 model resolver/renderer tests, 16 recipe/tag tests, 17 Creative catalog tests and headless main-scene smoke launch.

This is not an Android export/device test. The current GitHub workflow does not export an APK.

## Correct target defaults

New worlds default to Survival and the normal Overworld terrain mode. A climate/biome prototype is now active; Superflat remains an optional valid preset. The previous noise-only prototype is kept only for old saves. The Overworld generator is not yet Java 1.18.2 parity: climate/noise settings, surface rules, caves, ores, placed features, structures and biome/seed behavior need reference validation.

## Source asset preparation

The supplied resource/data ZIP's SHA-256 is:
`bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97`

In the same local project workspace, run:

```sh
python3 tools/prepare_assets.py /path/to/minecraft-assets-1.18.2.zip
```

The script verifies the hash before staging `assets/minecraft` and `assets/reference_data/minecraft`, rejects unsafe paths, records copied-file hashes in `assets/ASSET_EXTRACTION_MANIFEST.csv` and preserves differing destination files before replacement. It does not modify the original archive. Full source resources remain excluded from Git.

Important: the GitHub Actions runner does not have the source ZIP from this authoring workspace. An APK built without staging the archive in its actual build workspace cannot claim to include the supplied assets.

## Build commands

With Godot 4.7.2, matching export templates, JDK 17 and SDK configured:

```sh
python3 -m unittest discover -s tests -p "test_*.py" -v
python3 tools/validate_project.py
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/model_loader_tests.gd
godot --headless --path . --script res://tests/recipe_registry_tests.gd
godot --headless --path . --script res://tests/creative_catalog_tests.gd
godot --headless --path . --quit-after 5
mkdir -p build
godot --headless --path . --export-debug "Android" build/blocks-debug.apk
sha256sum build/blocks-debug.apk
```

## Release gates

1. Stage and audit the source ZIP in the exact Android build workspace; check the generated asset manifest.
2. Export a non-empty APK and record SHA-256 plus tested commit/toolchain versions.
3. Install/launch on Android device or emulator in landscape.
4. Test simultaneous touch movement/look, Survival spawn, mining/placement, inventory/crafting, save/reload, pause/resume and application restart.
5. Capture screenshots, inspect visuals and measure performance/memory.
6. Upload only verified release artifacts to Dropbox.

No APK export, install, physical-device test or release upload has passed yet.
# Android build status and prerequisites

## Required target

- Godot Engine 4.7.2 stable and matching Android export templates.
- JDK 17 plus configured Android SDK/platform/build-tools and adb.
- GL Compatibility renderer and landscape-only orientation.
- Application ID: org.blocks.voxelfrontier.
- Debug APK only; never commit signing credentials.

## What is verified

The latest successful Godot workflow:
https://github.com/mohnlninja1-code/Blocks/actions/runs/38956921930

It passed project import/parse, static validation, 7 archive/fixture tests, 29 foundational tests, 29 model resolver/renderer tests, 16 recipe/tag tests, 8 Creative catalog UI tests and the headless main-scene smoke launch.

This is not an Android export or device test. The current GitHub workflow does not export an APK.

## Source asset preparation

The supplied resource/data ZIP's SHA-256 is:
bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97

In the same local working directory as the project, run:

python3 tools/prepare_assets.py /path/to/minecraft-assets-1.18.2.zip

The script verifies the ZIP/hash before staging assets/minecraft and assets/reference_data/minecraft, rejects unsafe paths, records copied-file hashes in assets/ASSET_EXTRACTION_MANIFEST.csv and preserves differing destination files before replacement. It never edits the original archive. Both the original ZIP and the extracted resources are excluded from Git.

Important: the currently connected GitHub Actions runner cannot access a ZIP that exists only in the authoring workspace. Do not build or label an APK as asset-complete until the verified archive is staged in the actual Android build workspace and included in the exported PCK/APK.

## Local build commands

With Godot 4.7.2, matching export templates, JDK 17 and SDK configured:

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

## Release gates still outstanding

1. Run asset extraction in the exact workspace used for the Android build and review the extraction manifest.
2. Export a non-empty APK and record its SHA-256.
3. Install/launch on an Android device or emulator in landscape mode.
4. Test simultaneous touch movement/look, Creative catalog search/selection, placement/removal, save/reload, pause/resume and application restart.
5. Record device screenshots, startup/render performance, memory behavior and any unresolved issues.

No APK export, installation, physical-device test or release upload has passed yet.
# Android build status and prerequisites

## Required target

- Godot Engine 4.7.2 stable and matching Android export templates.
- JDK 17 plus configured Android SDK/platform/build-tools.
- GDScript and GL Compatibility renderer.
- Android application ID `org.blocks.voxelfrontier`.
- Landscape-only orientation.
- Debug APK; never commit signing credentials.

## What is currently verified

Godot 4.7.2 CI has successfully imported/parsed the project, run the foundational GDScript test harness (26 passed, 0 failed), and smoke-launched the main scene in headless mode:
https://github.com/mohnlninja1-code/Blocks/actions/runs/38950885879

This is not an Android export or device test. The available CI workflow intentionally does not yet export an APK.

## Release blockers

The game still has only starter registries and a simple noise-driven chunk world. It lacks the correct Java 1.18.2 model/state renderer, complete item/catalog behavior, fluids/Redstone, full station/block-entity inventory, all entities/structures, Nether/End and related progression. The user-provided source pack is not committed to Git, and must be staged locally by the user/release environment first.

Godot and `adb` were not installed in the current local authoring environment; OpenJDK 21.0.12.1 was present, rather than the documented JDK 17. So no local Android package build was performed.

## Source resource preparation

```sh
python3 tools/prepare_assets.py /path/to/minecraft-assets-1.18.2.zip
```

Strict hash and ZIP integrity checks run before staging. The original ZIP remains unmodified. Extracted assets and reference data are excluded from Git by `.gitignore`. Inspect `assets/ASSET_EXTRACTION_MANIFEST.csv` for copied file hashes and statuses.

## Build commands (future release gate, not a claimed pass)

```sh
python3 -m unittest discover -s tests -p "test_*.py" -v
python3 tools/validate_project.py
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --quit-after 5
mkdir -p build
godot --headless --path . --export-debug "Android" build/blocks-debug.apk
sha256sum build/blocks-debug.apk
```

The matching Android export templates, SDK/JDK configuration, non-empty APK/checksum, installation on a physical Android device/emulator, landscape/touch tests, screenshot inspection and save/reload proof are separate release gates. None of these has passed yet.
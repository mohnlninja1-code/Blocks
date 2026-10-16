# Android build status and prerequisites

## Required target

- Godot Engine 4.7.2 stable and matching export templates.
- JDK 17 and configured Android SDK/build-tools.
- GDScript; GL Compatibility.
- Android application ID `org.blocks.voxelfrontier`.
- Landscape-only orientation.
- Debug APK only; do not put signing secrets in Git.

The official Godot archive confirms 4.7.2 stable was released on 18 August 2026: https://godotengine.org/download/archive/4.7.2-stable/.

## Current blocker

The current public tree is missing `scripts/main.gd`, `scripts/save_store.gd`, `scripts/sound_bank.gd`, `scripts/recipe_registry.gd`, and `data/expanded_blocks.json`. It has no complete runtime, no tests and no Android CI workflow. Consequently the export preset alone cannot produce a playable game and no APK is claimed as built.

In the current execution environment, Godot and `adb` were not found; OpenJDK 21.0.12.1 was present, not the required JDK 17. The supplied asset ZIP is not copied into the public repository.

## Intended build gates (not yet passes)

```sh
python3 tools/audit_source_archive.py /path/to/minecraft-assets-1.18.2.zip --out docs/audit-generated
python3 tools/validate_project.py
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --quit-after 5
mkdir -p build
godot --headless --path . --export-debug "Android" build/blocks-debug.apk
sha256sum build/blocks-debug.apk
```

The project validator and engine test script must be created/recovered and the missing runtime fixed before expecting these commands to pass. Install and inspect the APK on an Android device/emulator; APK export alone does not establish device compatibility, visual correctness or parity.

No Godot import/parser run, engine test run, APK export, device install, screenshot inspection or performance profile has passed in this session.

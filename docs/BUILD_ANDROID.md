# Android build

## Target toolchain

- Godot Engine **4.7.2 stable** with matching export templates.
- JDK 17 and Android SDK platform/build-tools installed on runner/editor.
- GDScript; no custom native extensions.
- Android application ID `org.blocks.voxelfrontier`; display name `Blocks: Voxel Frontier`.
- Debug APK only. Release signing keys/passwords are not in source control.

## Local checks

```sh
python3 tools/prepare_assets.py --force
python3 tools/validate_project.py
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --quit-after 5
```

## Export

Configure the Android SDK path and Java SDK path in Godot Editor Settings and install the matching export templates, then run:

```sh
mkdir -p build
godot --headless --path . --export-debug "Android" build/blocks-debug.apk
```

Expected artifact: `build/blocks-debug.apk`. The GitHub Actions artifact is named `blocks-android-debug`. An APK export only proves packaging success; it does not prove game coverage, visual correctness or Android device compatibility.

## CI implementation

The workflow downloads the Godot 4.7.2 Linux binary and matching export templates, configures Java/Android SDK, reconstructs the 75-file selected asset bundle, validates JSON/resource references, runs the test script and smoke startup, exports APK and uploads it. The first hosted workflow run is the required evidence before promoting Godot test/export statuses.

## Known environment limitation

Godot and matching export templates were unavailable locally when this project was created; no local Godot parser/test execution, APK installation, Android input/session test or renderer screenshot review is claimed.

Official references: [Godot 4.7.2 stable](https://godotengine.org/download/archive/4.7.2-stable/), [exporting projects](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html), [Android export setup](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html).

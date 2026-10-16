# Test plan and current evidence

## Python source validation

`python3 tools/validate_project.py` checks JSON syntax, registry texture/icon paths, recipe/smelting references, static audio preload paths, asset usage entries, compact bundle contents and required project files. It is not a Godot parser or rendering test.

## Required Godot/CI commands

1. `godot --headless --editor --path . --import --quit` — project import and GDScript/scene parse.
2. `godot --headless --path . --script res://tests/run_tests.gd` — registries, asset manifest, negative coordinates, seed determinism, bedrock/subsurface, modification deltas, inventory transactions and save round-trip.
3. `godot --headless --path . --quit-after 5` — main-scene startup smoke test; inspect output for script/resource errors.
4. `godot --headless --path . --export-debug "Android" build/blocks-debug.apk` — APK export and nonzero artifact check.

These engine steps are not marked passed until a real workflow run completes successfully. The project authoring environment did not have a local Godot executable.

## Manual gameplay regression

- Create new Survival and Creative worlds with different/same seeds; verify player spawn, bedrock/subsurface continuity and determinism.
- Walk/sprint/jump/fly, cross chunk borders including negative X/Z, mine/place on all faces, verify drops/stack counts, collision and correct updates at local x/z 0 and 15.
- Repeat inventory/recipe operations and attempt invalid craft/capacity operations; verify no item duplication or loss.
- Craft planks/sticks/table/pickaxe/furnace; check table-gated recipes.
- Smelt iron/gold using coal; collect output; save/quit/restart and verify station state/inventory.
- Test zombie wander/chase/attack/hurt/death/drop and entity save state; verify Creative immunity.
- Save, terminate/relaunch and confirm world edits, inventory, time, stations and player state survive.
- Test simultaneous joystick/look, all touch buttons, menu while finger held, release tracking, safe-area bounds and pause/resume on Android.

## Mandatory visual regression gate

Capture and actually inspect: menu; world spawn; every used material; leaves alpha cutout; mining/replacement; load/unload chunk edges; negative coordinates; cave/bedrock; day/night; zombie idle/walk/attack/death; hotbar/inventory/crafting/furnace/pause/settings; narrow/wide landscape layouts; Android suspend/resume. Inspect for holes/seams, z-fighting, wrong face winding/UVs, alpha problems, missing/magenta materials, lighting jumps, clipped/overlapping controls and collision/mesh mismatch. Test in the final exported GL Compatibility/OpenGL ES build on real Android hardware.

No screenshots were produced/inspected, and no renderer/device is visually verified as of this milestone.

## Evidence log

| Check | Status | Evidence |
|---|---|---|
| Python registry/resource/bundle validator | PASSED locally | Validator output; data/path coverage only |
| Full source-archive audit | COMPLETED locally | `ASSET_MANIFEST.csv`, one row per non-directory archive file |
| Godot project import/script parse | NOT RUN | Engine unavailable locally; CI run required |
| Godot unit/integration script | NOT RUN | CI run required |
| APK export | NOT RUN | CI run required |
| Android device install/launch/input/save | NOT RUN | No device or emulator attached |
| Renderer screenshots/review | NOT RUN | No graphical Godot output available |

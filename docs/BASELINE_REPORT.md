# Verified baseline — 2026-10-16

Repository: https://github.com/mohnlninja1-code/Blocks  
Baseline commit: `d7d168a801d142cbe164ce1b2c1e2f4a7075f3f9`  
Working branch: `audit/java-1.18.2-baseline-2026-10-16`

## Repository finding

Both visible branches, `main` and `ci-build`, point to the same commit and contain the same 16-file bootstrap scaffold. It is not a playable game. The public tree is missing:
- `scripts/main.gd`, referenced by `scenes/main.tscn).
- `scripts/save_store.gd`, `scripts/sound_bank.gd`, and `scripts/recipe_registry.gd`, configured as autoloads.
- `data/expanded_blocks.json`, loaded by the block registry.
- Runtime world/player/inventory/entity/model-renderer services, extracted assets, audit CSVs, tests and GitHub Actions workflows.

The committed starter data contains 19 block entries, 8 item entries, 6 crafting recipes and 2 basic smelting recipes. The architecture notes describe an intended design and must not be read as proof those source files exist.

## Dropbox recovery

The connected Dropbox root returned zero entries. Searches for `Blocks`, `minecraft`, `apk`, `godot`, `zip`, `assets`, `Blocks Voxel Frontier`, `minecraft-assets-1.18.2`, `Voxel Frontier`, and `Godot project APK` returned zero results. No fuller source package or prior APK was recovered in this session.

## Supplied ZIP verification

- File: `minecraft-assets-1.18.2.zip`
- Compressed bytes: 435,164,471
- SHA-256: `bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97` (matches the previously recorded hash)
- ZIP integrity: PASS
- Entries incl. directory entries: 14,958; files: 14,459; uncompressed bytes: 532,470,059
- JSON files: 8,311; valid: 8,311; invalid: 0
- Item model JSONs: 1,235; block model JSONs: 1,725; blockstate JSONs: 900; recipe JSONs: 1,058
- Archive-level model parent references requiring resolution: 0 after normalizing vanilla built-in parents
- Source-model texture references missing from the archive: 0
- Duplicate ZIP member names: 0

The ZIP was only read; its original bytes remain untouched. No supplied game resource payloads were copied into the public repository.

## Target reconciliation

The handoff reports 332 missing mechanics and 791 missing item models, but no named list for either target exists in the current upload, inspected Git tree or connected Dropbox results. The archive has 1,235 source item-model JSON files; this is not equivalent to 791 *missing runtime models*. The generated audit bundle contains exact ledgers for every archive file, item model, blockstate mapping and recipe JSON. It deliberately does not fabricate a 332-row mechanics list. See `docs/PARITY_MATRIX.md` and the downloadable audit bundle for evidence.

## Build baseline

Godot was not installed in the current local environment; `adb` was not found and no Android device/emulator was exposed. OpenJDK 21.0.12.1 was present, while the current build notes target JDK 17. Therefore Godot parsing/import, gameplay tests, APK export/install, visual QA, touch testing and performance tests remain NOT RUN.

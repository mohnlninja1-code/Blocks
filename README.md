# Blocks: Voxel Frontier

Godot 4.7.2-targeted Android landscape voxel sandbox. The intended gameplay target is Minecraft Java Edition 1.18.2 parity.

## Current repository status

The checked-in project is **a bootstrap scaffold, not a playable full game**. The current tree is missing the main scene script, three autoload scripts, the expanded block catalog, the complete runtime, extracted source assets, tests and Android CI. Do not treat the architecture notes as proof those systems exist.

The verified baseline and missing paths are recorded in [docs/BASELINE_REPORT.md](docs/BASELINE_REPORT.md). The feature-by-feature evidence ledger is [docs/PARITY_MATRIX.md](docs/PARITY_MATRIX.md), and the release gates are [docs/DELIVERY_STATUS.md](docs/DELIVERY_STATUS.md).

## Source asset audit

The supplied `minecraft-assets-1.18.2.zip` was checked in the development session. SHA-256: `bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97`. The archive is intentionally not committed to this public repository. To recreate file/model/blockstate/recipe inventories, use `tools/audit_source_archive.py` with a local copy of the archive.

The reported 332 missing mechanics and 791 missing item models remain unreconciled because no named per-ID target lists were found in the provided upload, the current Git branches or the connected Dropbox results. Do not pad the ledgers with placeholders or claim parity from resource counts.

## Targets

- Engine: Godot 4.7.2 stable, GDScript.
- Renderer: GL Compatibility.
- Android package: `org.blocks.voxelfrontier`.
- Android orientation: landscape.
- World vertical range target: Y=-64 through Y=319.

No full-parity claim is made. Godot parsing/import, gameplay integration tests, APK export, Android device tests and renderer screenshot QA must remain marked NOT RUN until actual logs/evidence exist.

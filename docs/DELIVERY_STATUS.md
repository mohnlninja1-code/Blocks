# Delivery status — 2026-10-16

**Release readiness: BLOCKED. Java 1.18.2 parity is not achieved. No Android APK has been exported, device-tested or uploaded to Dropbox.**

## Live repository work

- Repository: https://github.com/mohnlninja1-code/Blocks
- Work branch: audit/java-1.18.2-baseline-2026-10-16
- The main branch has intentionally not been overwritten.
- The work branch now contains a menu/HUD, chunk/world storage and rendering foundation, player movement and block interaction, transactional inventory, saves with backup recovery, source-asset model and sound resolvers, source recipe/tag integration, a searchable Creative Catalog UI, audit/extraction tools and multiple test suites.
- The registry still combines starter definitions with dynamic source-name discovery. Dynamic entries use temporary local IDs and do not constitute a reconciled Java 1.18.2 registry.

## Source archive evidence

- Original ZIP SHA-256: bd6b2db35ab6e92de254a398b30ae56b0884e7f1a9c46490af1378ecc4d18f97 (matched the expected digest).
- ZIP integrity and the archive inventory were checked: 14,459 files; 532,470,059 uncompressed bytes; 8,311 valid JSON files; 1,235 item models; 1,725 block models; 900 blockstates; 1,058 recipes; zero invalid JSON.
- The original ZIP was not modified. Full source resources and extracted copies are excluded from Git. The source ZIP was available in the authoring workspace but is not passed into the GitHub Actions runner; it still must be extracted in the same workspace used for a local asset-enabled build.
- Asset extraction uses a hash gate, path safety checks, staging, output hashes, a manifest and conflict backups. Extraction alone does not prove runtime use.

## Latest successful CI evidence

Workflow: https://github.com/mohnlninja1-code/Blocks/actions/runs/38956921930  
Commit tested: 93d14e2dcda9df25debded671d6ac4ad18bb4bb7

- Godot 4.7.2 import and project parsing: pass.
- Offline archive and extraction-fixture tests: 7 passed.
- Static project validation: pass.
- Foundational GDScript tests: 29 passed, 0 failed.
- Model resolver and mesh/item renderer tests: 29 passed, 0 failed.
- Source recipe, nested item-tag and cooking tests: 16 passed, 0 failed.
- Creative catalog runtime UI tests: 8 passed, 0 failed.
- Main-scene headless smoke launch: pass.

The checks are narrow automated tests using isolated fixture JSON. They do not verify the full 435 MB resource pack's runtime coverage, visual parity, real gameplay or Android readiness.

## Not verified / blocked

- Complete block/item/entity registries with authoritative Java IDs, every legal state and reference-based reconciliation of the 332-mechanic/791-item-model targets.
- Full runtime staging of the source ZIP inside the game project or final APK.
- Correct rendering and visual regression for every variant, multipart model, UV, animation, render type, tint, transparency rule and item context.
- Java-reference terrain/world generation, biomes, structures, lighting, random/scheduled ticks, fluid simulation, Redstone, block entities/automation, full crafting station behavior, mobs/combat, survival progression, Nether or End/Dragon.
- Android export toolchain (Godot 4.7.2 Android templates, JDK 17 and Android SDK), APK checksum/export, installation, landscape/touch/suspend-resume behavior, device screenshots, performance and memory.
- Dropbox release artifact/link verification. There is no APK to upload.

## Current practical build limitation

The current authoring workspace contains the source ZIP but has no Godot executable, matching Android export templates or Android SDK/adb. The GitHub workflow validates source code and fixture tests; it does not export an APK. Therefore no APK can honestly be reported as built. The next build step needs a project workspace where the ZIP can be staged and Godot's Android exporter and SDK are configured.

## Artifact hygiene

The public Git tree intentionally omits the 435 MB source ZIP and extracted source resources. Use tools/prepare_assets.py locally with the verified archive to stage resources at assets/minecraft and reference data at assets/reference_data/minecraft. Do not commit proprietary resource files to the public repository without confirming their distribution rights.
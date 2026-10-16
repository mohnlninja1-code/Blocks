# Known issues / release blockers

**Release status: BLOCKED. The branch has a tested partial runtime, not Java 1.18.2 parity and not a delivered APK.**

1. **Correct defaults:** new worlds now default to Survival and the normal Overworld. Creative mode and Superflat remain optional. Legacy noise terrain is retained only for older saves.
2. The content registry still combines starter definitions with source-name discovery. Dynamically discovered IDs are temporary local IDs, not fully reconciled Java 1.18.2 registry IDs; the 332-mechanic and 791-missing-item-model lists still need authoritative reconciliation.
3. A new biome-aware worldgen prototype uses seeded climate and landform noise, Java 1.18.2 biome names, biome-dependent surface blocks, water at sea level, cave carving, ore placements and selected tree species. It is **not** vanilla's exact 1.18.2 multi-noise terrain, surface rules, cave carvers, ore distributions, placed features, structures or spawn algorithm.
4. Spawn selection avoids known ocean/river biome IDs near the origin; this is only an initial safety check. Spawn suitability/collision and biome edges require tests over many reference seeds.
5. A source model resolver and block model mesher exist, covering parent inheritance, texture aliases, variants, weighted selections and multipart selectors. They have fixture coverage only; full-pack UV, rotation/UV-lock, render layers, tinting, transparency, lighting, occlusion, AO and visual parity remain unverified.
6. Item icon/mesh handling uses source textures and source model JSON, but full predicates/overrides and GUI/ground/fixed/head/third-person contexts, animations and glint remain incomplete.
7. The Creative catalog works against registered definitions, caps results at 72 and selects into a hotbar slot. Full ZIP coverage and in-game selection/placement are not verified on a device.
8. Source recipe JSON and nested item-tag references are parsed; cooker times/results are normalized. Full recipe semantics, tag replace/order behavior, optional entries, conditions, remainders, unlocks, recipe books and all stations remain incomplete.
9. Sound-event lookup reads source `sounds.json` and referenced OGG paths, but full archive staging and live event coverage remain unverified.
10. Fluids, tick-accurate Redstone, block entities/automation, complete entity roster/AI/combat, structures, Survival progression, Nether/End and Dragon progression remain incomplete.
11. The ZIP's SHA and inventory are verified, but the GitHub runner is not given the private source archive and no APK includes its resources.
12. Latest successful Godot 4.7.2 workflow passed 7 archive/fixture tests, 44 foundation tests, 29 model tests, 16 recipe/tag tests, 17 Creative catalog tests and the main-scene smoke: https://github.com/mohnlninja1-code/Blocks/actions/runs/38958535541. These are regression tests, not full-game QA.
13. No Android export, checksum, install/launch, device screenshot, touch/save/reload, performance profile or Dropbox release exists.

## Acceptance rule

Do not mark a feature complete just because the ZIP contains a similarly named JSON/PNG. Each claim requires a runtime consumer plus behavior test, full-pack coverage evidence and, for visual/gameplay claims, reference comparisons. Do not create substitute art; use the supplied ZIP's assets and report missing files.
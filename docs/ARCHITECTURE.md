# Architecture status

## Target

Godot 4.7.2 stable, GDScript and GL Compatibility renderer. Android orientation is set to landscape; application ID is `org.blocks.voxelfrontier`. This is a chosen target, not proof of Android visual/performance compatibility.

## Current source modules

| Module | Actual implementation | Known boundary |
|---|---|---|
| `BlockRegistry` | Loads starter blocks/items from JSON; material cache; face texture path lookup and starter tool helper rules | Only 19 blocks and 8 items; not the Java registry |
| `SaveStore` | Versioned JSON saves, temporary write, prior-save backup, corrupt-primary backup recovery | Single-player foundation; mobile power-loss/large-save stress not tested |
| `SoundBank` | Optional event-to-path map, lazy streams, capped voice pool | Few illustrative names; clip paths may not exist until asset preparation; no event parity |
| `RecipeRegistry` | Starter JSON plus shaped/shapeless matching and legacy inputs; basic smelting data normalization | Not complete 1.18.2 recipe format, tags/unlocks/remainders/stations |
| `InventoryModel` | Stack insertion, total counts, atomic cost spending, rollback on output capacity failure, JSON-compatible save state | Core data model only; full slot controls, equipment/container transfer not implemented |
| `VoxelWorld` | Integer block coordinates, 16×16 chunks with packed IDs for Y=-64…319, seeded noise height/cave/ore starter generation, 3×3 streaming, edits, visible cube-face mesh/collision | Not vanilla worldgen, stateful blocks, real model geometry, dimension data, lighting propagation or efficient large-view streaming |
| `VoxelPlayer` | CharacterBody3D, keyboard/mouse actions, basic movement/jump/sprint/sneak/Creative flight, block ray target/mining/placement, health/hunger storage | No parity physics/tool tiers/damage, touch-look QA or complete survival rules |
| `main.gd` | Menu, world setup/load, HUD/hotbar, simple inventory panel, touch buttons, pause, autosave, day/night color/light changes | Screens have only headless smoke evidence, not screenshot/on-device QA |

## Rendering and asset flow

`tools/prepare_assets.py` verifies the uploaded archive's expected SHA-256, tests ZIP integrity and stages `assets/minecraft/**` plus `data/minecraft/**` reference data to an ignored local tree. It writes a per-file checksum manifest. By default, a differing destination aborts without replacing files; `--force` preserves changed target bytes before replacement. The source archive is never modified.

World meshing currently maps simple cube faces using starter registry texture fields and fallback colors. No Java model parent resolver, model-element builder, blockstate selector or item-model renderer has been integrated yet. Extracting a resource file is not equivalent to consuming it in gameplay.

## Coordinate and save rules

Target vertical coordinates are Y=-64 through Y=319. Chunk lookup uses floor division for negative X/Z and positive modulo for local coordinates. Block edits are saved as explicit deltas to deterministic base terrain. Save/player/inventory foundation data is serialized; container contents, all entity state, dimensions and portal links are not implemented.

## Verification policy

See `docs/PARITY_MATRIX.md` and `docs/DELIVERY_STATUS.md`. Godot CI has passed a narrow foundation test suite. No feature is marked fully complete from resource counts, registry rows or successful packaging alone.
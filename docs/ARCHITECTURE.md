# Architecture status

## Target

Godot 4.7.2 stable, GDScript and GL Compatibility renderer. Android orientation is configured as landscape; package ID is `org.blocks.voxelfrontier`. The official Godot 4.7.2 stable release was published on 18 August 2026. The renderer/export path is a target, not a validated compatibility claim.

## Important baseline correction

The public GitHub tree is a 16-file bootstrap scaffold. The services described below are **planned system boundaries**, not currently present implementations. Missing source paths and evidence are recorded in `docs/BASELINE_REPORT.md` and `docs/PARITY_MATRIX.md`.

| Planned service | Intended responsibility | Current source status |
|---|---|---|
| BlockRegistry | 1.18.2 block/item metadata, state and tag access | Partial starter registry only; references missing `data/expanded_blocks.json` |
| SaveStore | Versioned world/player/container/entity serialization; crash-safe rotation/recovery | Missing `scripts/save_store.gd` |
| SoundBank | Event-to-asset mapping and bounded audio playback | Missing `scripts/sound_bank.gd` |
| RecipeRegistry | Reference recipe loading, station/type matching, remainders/unlocks | Missing `scripts/recipe_registry.gd` |
| VoxelWorld | Chunked world storage, state-aware mesh/collision, deterministic terrain and streaming | No runtime source file in checked-in tree |
| VoxelPlayer | Movement, interaction, survival rules and persistence | No runtime source file in checked-in tree |
| InventoryModel | Atomic item stacks, crafting, transfer and equipment state | No runtime source file in checked-in tree |
| Entity runtime | Goal-driven AI, physics, attacks, drops and save state | No runtime source file in checked-in tree |
| Main/mobile UI | Menus, game mode, HUD, touch input, pause/settings and dimension transitions | `scenes/main.tscn` references missing `scripts/main.gd` |

## Asset and rendering constraints

The source archive is kept outside public Git until resource distribution rights are established. `tools/audit_source_archive.py` creates a hash-audited file/model/blockstate/recipe inventory from a local copy. Archive presence is not runtime integration. Model inheritance, texture indirection, element geometry, blockstate variants/multipart, transparency and context transforms need a real renderer plus visual regression evidence.

## Coordinates and saves

The required world range is Y=-64 through Y=319. Chunk floor division and positive local-coordinate modulo, edit deltas, block entities, inventory stacks, entities, portals and dimension-specific state must be consistent across mesh/collision, loading and saving. No matching complete runtime/save implementation is present at the inspected baseline.

## Scope discipline

Do not mark a feature VERIFIED until the source implementation, targeted tests and evidence exist. Do not treat successful export, a registry entry, or an asset-file count as proof of gameplay parity.

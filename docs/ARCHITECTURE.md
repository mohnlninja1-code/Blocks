# Architecture — Blocks: Voxel Frontier

## Engine / renderer

Godot 4.7.2 stable, GDScript, GL Compatibility. This deliberately conservative OpenGL ES-oriented Android path has not yet been executed or visually inspected here; it is a selected target, not a compatibility claim.

## Services and boundaries

- `BlockRegistry`: loads block/item registries and caches materials.
- `SaveStore`: versioned JSON with temporary writes and last-good backup recovery.
- `SoundBank`: capped eight-voice one-shot audio pool, selected original-pack clips and one effects-volume setting.
- `VoxelWorld`: integer block coordinates; 16×16 horizontal chunks, packed integer storage for Y=-64…319, seeded height/cave/ore/tree generation, edit deltas, exposed-face culling, per-texture ArrayMesh surfaces and per-chunk trimesh collision.
- `VoxelPlayer`: first-person movement, jump/sprint/sneak, Creative flight, ray-based block/mob target, mining/placement, simple health/hunger, tool durability and survival respawn.
- `InventoryModel`: authoritative hotbar/backpack stack transactions, crafted against data-driven recipes.
- `SandboxZombie`: supplied skin mapped to custom box meshes, walk animation, chase/wander/melee/damage/death/drop/save state.
- `main.gd`: world/menu flow, HUD, survival/creative entry, world time/lighting, recipe and furnace UI, station state, entity spawn/save, settings/autosave.
- `MobileControls`: multitouch joystick/look/buttons, with keyboard/mouse development inputs.

## Rendering and mesh safety

Each chunk's visible block faces are grouped by texture/material; internal opaque faces are culled. Texture UVs stay per-texture rather than using an atlas. Pixel art uses nearest filtering; leaves use alpha scissor. There are no custom shaders, translucent fluids or glass in this milestone. When a mesh is rebuilt, its prior children are removed before the new mesh/collider is attached. Adjacent chunk meshes rebuild on stream-in/unload to reconsider boundary visibility. Source-level measures are not visual proof; the affected renderer must be inspected after Godot import/export.

## Coordinate and save rules

Floor division handles negative chunk coordinates; local X/Z uses positive modulo. The JSON save format version is 1 and records seed/mode/time, player/inventory, block edit deltas, furnace state and the currently supported zombie state. `SaveStore` rotates through temporary/backup paths; crash/restart reliability remains untested on Android.

## Scope discipline

`docs/ASSET_USAGE.csv` maps selected assets to actual consumers. `docs/FEATURE_MATRIX.md` and `docs/KNOWN_ISSUES.md` distinguish integrated source from features not yet built. No registry/file count is used as evidence for content parity.

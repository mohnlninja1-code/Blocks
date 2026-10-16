# Changelog

## 0.1.0-dev — development milestone

- Created the Godot 4.7.2-targeted project and original identity.
- Added deterministic procedural chunk terrain, face-culled mesh and collision, edit-delta persistence, player controller, mining/placement and hotbar/backpack.
- Added starter block/item/recipe registries, transactional crafting, workbench-gated recipes and persistent iron/gold smelting in furnaces.
- Added Survival and Creative entry/movement differences, health/food basics, versioned saves, day/night, touch controls, one textured hostile zombie family and capped event SFX.
- Audited all 14,459 source-archive entries and selected 75 files with explicit active consumers.
- Corrected terrain voxel write indentation (previously only the last Y voxel per column was assigned); regression check added, engine test pending.
- Corrected zombie front/back normals and render-distance refresh; runtime visual check pending.
- No Godot test pass, APK, Android device test or inspected renderer screenshot is claimed.

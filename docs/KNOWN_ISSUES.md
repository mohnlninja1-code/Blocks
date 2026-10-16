# Known issues / release blockers

This is a development milestone, not the final 1.18.2-style game.

1. Godot 4.7.2 script import, tests and APK export have not yet run in the authoring environment. The hosted CI workflow must pass and any issues it finds must be fixed.
2. No real render output or screenshot has been captured or inspected. The GL Compatibility Android path remains visually unverified; no absence-of-artifacts claim is made.
3. Scope is materially incomplete: fluid simulation, Redstone, advanced states/shapes, most block/item/recipe families, most mobs, ranged projectiles, advanced combat, weather, structures, Nether/End, progression/enchanting/brewing are missing.
4. Only 75 of the 14,459 source pack files are presently integrated to runtime callsites. The remaining 14,384 entries have per-file audit statuses; applicable art/audio must be integrated as associated features are actually implemented.
5. No Android device install/launch, touch matrix, suspend/resume, long-save test, performance profile or visual review has run.
6. Save integrity, fast chunk boundary updates, furnace edge cases and zombie movement need engine/runtime tests.

## Visual defect policy

A changed source line does not close a rendering defect. Reproduce, diagnose, fix, rerun the affected test, and inspect the resulting image in the renderer/export where it occurred. Chunk seams, missing faces, inverted normals, texture bleed, transparency/depth issues, flicker, black/magenta resources, clipped UI or collision/geometry mismatch are release blockers until retested and closed with evidence.

# Blocks — Voxel Frontier

Original Godot 4.7.2-targeted voxel sandbox project, with Android landscape export configuration.

## Repository status — read before use

**The GitHub repository is currently only a bootstrap scaffold. It is not the complete project and does not contain the full GDScript runtime, asset archives or Android workflow.** I have not been able to sync the locally prepared full project bundle through the connected GitHub file API. Do not treat this repository's current contents as a built or playable release.

The full local source package for the current development milestone contains the scripts, registries, tests, source audits and the complete user-supplied resource ZIP. It is available as an archive in the originating ChatGPT conversation. SHA and completeness evidence are in `docs/DELIVERY_STATUS.md` within that package.

## Target and known gaps

- Engine target: Godot 4.7.2 stable, GDScript.
- Android orientation target: landscape only.
- Renderer target: GL Compatibility / OpenGL ES, selected as a conservative path; runtime renderer output has **not** been visually verified.
- This is not Minecraft Java 1.18.2 parity. Fluids, full Redstone/TNT behavior, all content/recipes/states, all mobs and spawn rules, complete biome/structure generation, Nether/End, exact touchscreen UI, and device/renderer regression testing remain outstanding.
- No Godot parser/test run, APK export, device install, or screenshot inspection is claimed as passed.

A successful build is not proof of visual correctness or game completeness. The source project's feature matrix, per-recipe ledger, asset manifest and known-issue register are release gates, not marketing checklists.

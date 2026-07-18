---
name: terrain
display_name: Terrain3D
version: 1.0.2
upstream: https://github.com/TokisanGames/Terrain3D
upstream_license: MIT
godot_min: "4.1"
godot_max: "4.7"
type: gdextension
provides:
  - terrain.generate
  - terrain.sculpt
  - terrain.paint
  - terrain.bake_nav
  - terrain.stream
recipes:
  - rolling_hills
  - mountain_range
  - island
status: vendored
---

# Terrain3D

## What it does

High-performance, editable 3D terrain for Godot 4, written in C++ as a
GDExtension (works with official Godot builds — no custom engine). Up to 32
textures, 10 LOD levels, runtime collision, hole cutting, and a built-in
instancer for scattering meshes across the surface. This is the foundation
every HermesForge outdoor environment is built on.

## For humans

1. The addon ships pre-enabled in the HermesForge base template
   (`addons/terrain_3d`). In a stock project: copy `addon/` into your project's
   `addons/terrain_3d/`, then **Project → Project Settings → Plugins → enable
   "Terrain3D"**.
2. Add a `Terrain3D` node to your scene. Select it to get the terrain toolbar
   (sculpt, paint, height, holes, instancer) in the 3D viewport.
3. Import a heightmap (16-bit PNG/EXR) via **Terrain3D → Import**, or sculpt
   from flat. Assign a `Terrain3DMaterial` + texture assets to paint.
4. Docs: https://terrain3d.readthedocs.io

No mono/C# required. Works headless for generation (GPU needed for rendering).

## For agents

MCP capabilities (Phase 1 bridge; until then drive via godot-ai generic tools):

- `terrain.generate(recipe, size_m, seed)` — heightfield from a named recipe
- `terrain.sculpt(brush, center, radius, strength)` — non-destructive edit
- `terrain.paint(texture_id, mask)` — paint control map from biome data
- `terrain.bake_nav()` — bake navigation mesh over walkable slope range
- `terrain.stream(region, lod_bias)` — region streaming for large worlds

Recipes (see `recipes/`): `rolling_hills`, `mountain_range`, `island`.

Pitfalls:
- Heightmap import wants 16-bit; 8-bit banding is visible on slopes.
- Collision is generated from the heightfield — call `terrain.bake_nav`/update
  after sculpting before running physics audits.
- The instancer is the cheapest way to scatter; prefer it over manual
  MultiMesh for trees/rocks until the `foliage` module spike (D4) decides.

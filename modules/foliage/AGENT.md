---
name: foliage
display_name: Foliage Scatter
version: "0.1.0"
upstream: https://github.com/Jpalmer95/hermesforge
upstream_license: MIT
godot_min: "4.4"
godot_max: "4.7"
type: gdscript_plugin
provides:
  - foliage.scatter
  - foliage.clear
  - foliage.list
recipes:
  - pine
  - jungle
  - alpine
  - rock
  - grass
  - shrub
status: bridged
---

# Foliage Scatter

## What it does

Scatters vegetation/props across terrain as `MultiMeshInstance3D`s (GPU
instancing — one draw call per group), placed on the terrain surface by
sampling `Terrain3D.data.get_height()`. Poisson-ish spacing rejection keeps
clumps natural; deterministic for a given seed.

## Decision D4 (resolved)

Chose **direct MultiMesh scattering** over:
- *HungryProton/scatter* — actively maintained (4.7-compatible, MIT) but
  community-reported perf issues + an extra dependency. Optional add-on later.
- *Spatial Gardener* — best-in-class for hand-painting, but last commit
  2025-03 (pre-4.7) and GDScript-only painter (not agent/headless oriented).
- *Terrain3D instancer* — great runtime perf, but needs meshes registered in
  the Terrain3D asset dock (editor GUI step) — poor fit for headless agent
  driving. We may bridge it later behind `foliage.scatter(backend="instancer")`.

MultiMesh is headless-safe, zero-dependency, and fully agent-drivable. Humans
can hand-edit the resulting `MultiMeshInstance3D` in the editor as usual.

## For humans

1. The handler lives in `addons/hermes_bridge/handlers/foliage_handler.gd`.
2. Scattered groups appear as `Foliage_<recipe>` `MultiMeshInstance3D` nodes —
   tweak the multimesh, material, or instance transforms directly.
3. To use your own meshes instead of the built-in primitives, swap
   `mm.mesh` for your `ArrayMesh`/`obj`/`glb` mesh.

## For agents

MCP tools:

- `hermes_foliage_scatter(recipe, count, area_m, seed, min_spacing, y_offset, name)`
- `hermes_foliage_clear(name?)` — remove one group or all
- `hermes_foliage_list()` — groups + instance counts

Recipes (built-in procedural meshes): `pine`, `jungle`, `alpine`, `rock`,
`grass`, `shrub`.

Pitfalls:
- Requires a `Terrain3D` in the scene to follow terrain height; without one it
  scatters on y=0.
- `min_spacing` rejection sampling can place fewer than `count` on small areas
  — check the `placed` field in the result.
- MultiMesh is one draw call; thousands of instances are cheap, but each group
  is a single mesh/material — split biomes into separate groups for varied mats.

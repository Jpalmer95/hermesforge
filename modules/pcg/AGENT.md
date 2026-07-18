---
name: pcg
display_name: Gaea 2.0
version: 2.0.0-beta6
upstream: https://github.com/gaea-godot/gaea
upstream_license: MIT
godot_min: "4.3"
godot_max: "4.7"
type: gdscript_plugin
provides:
  - pcg.graph_create
  - pcg.graph_set_param
  - pcg.generate
  - pcg.seed_diff
recipes:
  - cave_system
  - dungeon_layout
  - forest_scatter
status: vendored
---

# Gaea 2.0

## What it does

Graph-based procedural content generation for Godot 4: a VisualShader-like node
graph where generation flows from noise/sampling nodes through modifiers into
output (tilemap, gridmap, heightmap, scatter). Chunk loader supports
streaming/infinite worlds. Mature for 2D; 3D gridmap + heightmap workflows are
solid and improving. This is HermesForge's general-purpose PCG brain — anything
repetitive-but-organic (caves, dungeons, scatter masks, biome maps) starts here.

## For humans

1. Copy `addon/` into `addons/gaea/`, enable plugin **"Gaea 2.0"**.
2. Add a `GaeaGenerator` node; open the **Gaea** bottom panel to edit its graph.
3. Wire nodes (e.g. `Noise` → `Threshold` → `TilemapTile`); press **Generate**.
4. Docs: https://gaea-godot.github.io (graph reference lives in-editor too).

Pure GDScript — no mono, no GDExtension build. Headless generation works.

## For agents

MCP capabilities (Phase 1 bridge):

- `pcg.graph_create(recipe)` — instantiate a graph from a recipe template
- `pcg.graph_set_param(node, param, value)` — tweak noise scale, thresholds...
- `pcg.generate(seed)` — run generation into the scene
- `pcg.seed_diff(seed_a, seed_b)` — compare two seeds (screenshot + cell stats)

Recipes (see `recipes/`): `cave_system`, `dungeon_layout`, `forest_scatter`.

Pitfalls / policy:
- UPSTREAM CONTRIBUTION RULE: gaea's CONTRIBUTING.md has an AI disclaimer —
  do NOT open upstream PRs containing AI-generated code without following their
  disclosure terms. Vendoring + local recipes is unaffected.
- 2.0 is beta: pin to this version, re-vendor deliberately, run golden tests
  after any version bump.
- Large graphs generate on the main thread — for big maps use the chunk loader
  rather than one giant grid.

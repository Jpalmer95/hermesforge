---
name: physics
display_name: Jolt Physics (built-in)
version: "builtin-godot-4.7.1"
upstream: https://github.com/godot-jolt/godot-jolt
upstream_license: MIT
godot_min: "4.4"
godot_max: "4.7"
type: builtin
provides:
  - physics.audit
  - physics.collision_autogen
  - physics.ragdoll
  - physics.vehicle
  - physics.tune
recipes:
  - vehicle_arcade
  - vehicle_sim
  - ragdoll_humanoid
status: vendored
---

# Jolt Physics (built-in)

## What it does

Jolt is the multi-core rigid-body physics engine (the library behind Horizon
Forbidden West) with better continuous collision detection, stable stacking,
proper vehicle constraints, and soft bodies than Godot's default GodotPhysics.
**On Godot 4.4+ Jolt is compiled into the official engine** — that is what this
module uses. No GDExtension, no download, no version-matching risk.

> Decision record: we vendored the godot-jolt GDExtension v0.16.0 first, but it
> only supports Godot 4.3–4.6 and refuses to load on 4.7.1. Built-in Jolt is
> the upstream-recommended path for 4.4+ and is verified active here — the
> `physics/jolt_physics_3d/*` settings tree only exists when built-in Jolt is
> the live engine. See `addon/builtin-jolt/NOTE.md`.

## For humans

1. Already enabled in the HermesForge base template
   (`templates/base/project.godot` sets `physics/3d/physics_engine="Jolt
   Physics"`). In a stock project: **Project Settings → Physics → 3D → Physics
   Engine → "Jolt Physics"**, restart editor.
2. Tune solver quality under **Project Settings → Physics → Jolt Physics 3D**
   (velocity/position steps, CCD thresholds, sleep thresholds).
3. Verify: run a scene with a tall stack of rigid boxes — Jolt settles without
   the jitter GodotPhysics shows.

No mono, no GDExtension, works headless (physics needs no GPU).

## For agents

MCP capabilities (Phase 1 bridge):

- `physics.audit()` — report bodies without collision shapes, static/dynamic
  mismatches, perf risks (too many active bodies, huge concave dynamic shapes)
- `physics.collision_autogen(node, mode)` — convex-decompose or primitive-fit
  collision for meshes
- `physics.ragdoll(skeleton)` — generate physical bones from a humanoid rig
- `physics.vehicle(recipe, wheels)` — VehicleBody/VehicleWheel rig from recipe
- `physics.tune(preset)` — solver iteration + CCD presets per scene scale

Detection: built-in Jolt is live iff
`ProjectSettings.has_setting("physics/jolt_physics_3d/simulation/velocity_steps")`
is true AND `physics/3d/physics_engine == "Jolt Physics"`. The audit tool
asserts both before running Jolt-specific tuning.

Recipes (see `recipes/`): `vehicle_arcade`, `vehicle_sim`, `ragdoll_humanoid`.

Pitfalls:
- Don't confuse built-in Jolt (`"Jolt Physics"`) with the GDExtension
  (`"Jolt Physics (Extension)"`) — different setting values, different feature
  sets. HermesForge targets built-in on Godot 4.7.
- Concave (trimesh) *dynamic* bodies are a perf trap; prefer convex
  decomposition. Trimesh is fine for static only.
- After sculpting Terrain3D, re-run collision update before auditing.

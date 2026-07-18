---
name: water
display_name: HermesForge Water Kit
version: "0.2.0"
upstream: https://github.com/Jpalmer95/hermesforge
upstream_license: MIT
godot_min: "4.4"
godot_max: "4.7"
type: gdscript_plugin
provides:
  - water.create
  - water.remove
  - water.float_on_water
  - water.list
recipes:
  - lake
  - pond
  - ocean
  - river_spline
  - calm_pool
status: bridged
---

# HermesForge Water Kit

## What it does

A GDScript water kit: animated surface (Gerstner-wave vertex displacement
shader with fresnel) plus real buoyancy — `RigidBody3D`s registered to a
`HermesWaterBody` float via spring forces using the same wave math as the
visuals, so physics and rendering agree. This is a *kit*, not a full fluid sim
(true SPH/FLIP is post-launch roadmap — see master plan section 9).

## For humans

1. The kit ships in `templates/golden-demo` (`addons/hermes_bridge/shaders/
   water_surface.gdshader` + `scripts/water_body.gd`). In your project, copy
   those two files in.
2. Add a `HermesWaterBody` node; assign the `water_surface.gdshader` to a
   PlaneMesh child. Tune `wave_height/scale/speed` and colors in the inspector.
3. To float something, call `water.register_floater(rigid_body)` — or just use
   the agent tool `hermes_water_float_on_water`.

## For agents

MCP tools (via the bridge):

- `hermes_water_create(recipe, at, radius)` — water body + surface from a recipe
- `hermes_water_remove()` — remove the water body
- `hermes_water_float_on_water(node)` — register a RigidBody3D to float
- `hermes_water_list()` — active water params

Recipes (set surface params): `lake`, `pond`, `ocean`, `river_spline`,
`calm_pool`.

Pitfalls:
- The wave math in `scripts/water_body.gd` MUST match
  `shaders/water_surface.gdshader` — if you edit one, mirror the other or
  buoyancy will detach from the visuals.
- Buoyancy is a spring toward the wave height, not true hydrostatics — good
  for crates/boats/props, not for accurate ship displacement.
- Headless: buoyancy runs fine (no GPU); the shader surface only renders with
  a viewport.

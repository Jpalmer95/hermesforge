# HermesForge Recipe Catalog

Recipes are the agent-facing vocabulary of HermesForge: a parameterized,
JSON-fillable intent description for one module capability. Both the MCP
bridge tools and the ForgeDNA `environment:` block speak this vocabulary.
Every recipe is deterministic for a given `seed`.

Two ways to use a recipe:

1. **MCP tool** (live editor, Path A) — e.g. `hermes_terrain_generate(recipe="rolling_hills", size_m=512)`.
2. **ForgeDNA `environment:` block** (headless compiler, Path B) — see
   [first-environment.md](first-environment.md).

---

## terrain — Terrain3D heightfields

Tool: `hermes_terrain_generate(recipe, size_m, seed, amplitude, frequency)`

| recipe | description | key params |
|--------|-------------|-----------|
| `rolling_hills` | Gentle rolling hills, grass + dirt blend | `size_m` (def 1024), `amplitude` (30), `frequency` (0.004), `biome` temperate\|alpine\|desert |
| `mountain_range` | Ridged alpine chain with valley floor | `size_m` (2048), `amplitude` (220), `ridge_gain` (0.6), `snowline_m` (140) |
| `island` | Single island, beach falloff into water | `size_m` (1024), `amplitude` (60), `falloff` (0.7), `beach_width_m` (24) |

Also: `hermes_terrain_sculpt(center, radius, strength)` raise/lower a region;
`hermes_terrain_info()` report region size + height range.

```json
"terrain": { "recipe": "rolling_hills", "size_m": 1024, "seed": 7, "amplitude": 18.0, "biome": "temperate" }
```

## water — Gerstner surface + buoyancy

Tool: `hermes_water_create(recipe, at, radius)` · buoyancy: `hermes_water_float_on_water(node)`

| recipe | description |
|--------|-------------|
| `lake` | Balanced default: moderate waves, blue-green |
| `pond` | Small gentle ripples, greener, calm |
| `ocean` | Big slow swells, deep blue |
| `river_spline` | Faster, smaller chop for flowing water |
| `calm_pool` | Near-still, minimal wave height |

All take `at` ([x,y,z] center), `radius`, and accept wave overrides
(`wave_height`, `wave_scale`, `wave_speed`). Multiple bodies coexist
(`HermesWater`, `HermesWater2`, …). `float_bodies` lists RigidBody3D names to
float on that body.

```json
"water": [
  { "recipe": "pond", "at": [24, 0, -16], "radius": 20.0 },
  { "recipe": "calm_pool", "at": [-40, 0, 32], "radius": 12.0, "float_bodies": ["Crate0"] }
]
```

## foliage — MultiMesh scatter (one draw call per group)

Tool: `hermes_foliage_scatter(recipe, count, area_m, seed, min_spacing, y_offset, name)`

| recipe | description |
|--------|-------------|
| `pine` | Tall conifer cones, pine-forest green |
| `jungle` | Broad dense cones, lush green |
| `alpine` | Narrow tall cones, darker alpine green |
| `grass` | Low tufts, bright green |
| `shrub` | Rounded low bushes |
| `rock` | Faceted grey rocks/boulders |

All take `count`, `area_m`, `seed`, `min_spacing`, `y_offset`. Deterministic
per seed; idempotent per `name`. Also `hermes_foliage_clear(name)`,
`hermes_foliage_list()`.

```json
"foliage": [
  { "recipe": "pine", "count": 220, "area_m": 300.0, "seed": 7, "min_spacing": 2.4 },
  { "recipe": "grass", "count": 600, "area_m": 320.0, "seed": 11 }
]
```

## sky — WorldEnvironment + sun presets

Tool: `hermes_sky_set(recipe)`

| preset | description |
|--------|-------------|
| `golden_hour` | Warm low sun, long shadows, soft bloom |
| `midday` | Neutral overhead sun, clear |
| `overcast_storm` | Grey, diffuse, heavy fog |
| `clear_night` | Dark sky, stars, cool ambient |

```json
"sky": { "preset": "golden_hour" }
```

## physics — Jolt rigs & tuning

| tool | description | recipes / params |
|------|-------------|------------------|
| `hermes_physics_audit` | Bodies missing collision, dynamic-trimesh traps, Jolt status | — |
| `hermes_physics_collision_autogen` | Auto collision for a MeshInstance3D | `mode`: convex (dynamic) \| box \| sphere \| trimesh (static) |
| `hermes_physics_vehicle` | 4-wheel VehicleBody3D rig | `vehicle_arcade` (high grip) \| `vehicle_sim` (weighty) |
| `hermes_physics_ragdoll` | Flag a humanoid Skeleton3D for ragdoll | `ragdoll_humanoid` |
| `hermes_physics_tune` | Jolt solver quality | performance (6/1) \| balanced (10/2) \| quality (16/4) |
| `hermes_physics_add_test_body` | Simple RigidBody3D (buoyancy/physics tests) | `shape`: box \| sphere, `mass`, `at` |

## pcg — Gaea graph PCG (Phase 2+, bridged later)

Recipes reserved for the Gaea module (graph-based PCG): `cave_system`,
`dungeon_layout`, `forest_scatter`. These are vendored and validated but not
yet exposed as MCP tools — they land in a future phase.

---

### A complete environment block (for copy-paste)

```json
"environment": {
  "terrain": { "recipe": "rolling_hills", "size_m": 1024, "seed": 7, "amplitude": 18.0, "biome": "temperate" },
  "water": [ { "recipe": "pond", "at": [24, 0, -16], "radius": 20.0 } ],
  "foliage": [
    { "recipe": "pine", "count": 220, "area_m": 300.0, "seed": 7 },
    { "recipe": "grass", "count": 600, "area_m": 320.0, "seed": 11 }
  ],
  "sky": { "preset": "golden_hour" }
}
```

Build it: `forgedna-harness build-full your_dna.json --apply`.

# HermesForge Bridge

The "1st-class Hermes" layer: exposes the curated Godot module stack as
semantic MCP tools so an AI agent drives the editor by intent, not raw node
plumbing — while humans keep full use of the stock editor.

## Architecture

```
Hermes Agent ──(MCP stdio)──> bridge/hermesforge_mcp.py (Python, FastMCP)
                                   │  HTTP+JSON, 127.0.0.1:8787
                                   ▼
            templates/golden-demo/addons/hermes_bridge (Godot editor plugin)
                                   │  GDScript
                                   ▼
                    Terrain3D / Gaea / Jolt / water / sky / scene
```

Two halves:

- **Godot plugin** (`addons/hermes_bridge/`): `bridge_server.gd` (network +
  dispatch core, editor-independent) + thin `hermes_bridge.gd` EditorPlugin
  wrapper + `handlers/` (scene / terrain / water / sky / physics). Binds
  **127.0.0.1 only** — never expose beyond loopback.
- **Python MCP server** (`bridge/hermesforge_mcp.py`): stdio MCP via FastMCP.
  Translates `mcp_hermesforge_*` tool calls into bridge ops. Runs via `uv run`
  (inline `mcp` dep — no system install). If the editor is offline, every tool
  returns a clean "bridge unreachable" error instead of hanging.

## Tools (21)

| tool | what it does |
|------|--------------|
| `hermes_project_info` | editor/project status, physics engine, Jolt active, bridge reachable |
| `hermes_scene_get_tree` | open scene node tree (names + types) |
| `hermes_scene_screenshot` | capture editor 3D viewport to PNG |
| `hermes_scene_save` | save open scene |
| `hermes_terrain_generate` | Terrain3D heightfield from a recipe (rolling_hills / mountain_range / island) |
| `hermes_terrain_sculpt` | raise/lower terrain in a radius |
| `hermes_terrain_info` | terrain presence, region size, height range |
| `hermes_water_create` | water body w/ Gerstner surface (lake / pond / ocean / river_spline / calm_pool) |
| `hermes_water_remove` | remove the water body |
| `hermes_water_float_on_water` | register a RigidBody3D to float (buoyancy) |
| `hermes_water_list` | active water params + recipes |
| `hermes_sky_set` | sky/sun/fog preset (golden_hour / midday / overcast_storm / clear_night) |
| `hermes_physics_audit` | bodies missing collision, dynamic-trimesh traps, Jolt status |
| `hermes_physics_collision_autogen` | convex/box/sphere/trimesh collision for a mesh |
| `hermes_physics_vehicle` | spawn a 4-wheel VehicleBody3D (vehicle_arcade / vehicle_sim) |
| `hermes_physics_ragdoll` | flag a humanoid Skeleton3D for ragdoll |
| `hermes_physics_tune` | Jolt solver preset (performance / balanced / quality) |
| `hermes_physics_add_test_body` | simple RigidBody3D for testing |
| `hermes_foliage_scatter` | MultiMesh foliage over terrain (pine / jungle / alpine / rock / grass / shrub) |
| `hermes_foliage_clear` | remove scattered foliage (one group or all) |
| `hermes_foliage_list` | scattered groups + instance counts |

## Setup

1. Open `templates/golden-demo` in Godot 4.7.1 — the `hermes_bridge` plugin is
   pre-enabled and starts the socket on 127.0.0.1:8787.
2. The MCP server is registered in `~/.hermes/config.yaml` under
   `mcp_servers.hermesforge` (command `uv run .../bridge/hermesforge_mcp.py`).
   Start a new Hermes session — tools appear as `mcp_hermesforge_*`.
3. Sanity: `hermes mcp list` shows `hermesforge`; in a session ask for
   `hermes_project_info`.

## Verify (headless, no editor needed)

```bash
python qa/run.py --golden 1   # Phase 1 intent: terrain + lake + golden hour (9/9)
python qa/run.py --golden 2   # Phase 2 scene: + buoyancy, foliage, vehicle (19/19)
```

Runs `golden_test.gd` / `golden_test2.gd`: drives the canonical intent through
the real socket and asserts the resulting scene. These are the success gates.

## Adding a tool

1. Add a handler method in `addons/hermes_bridge/handlers/<domain>_handler.gd`
   and register its op id in `get_ops()`.
2. Add a matching `@mcp.tool()` in `bridge/hermesforge_mcp.py` that POSTs the op.
3. Re-run `python qa/run.py --golden 1` and `python qa/run.py --golden 2`.

Keep ops JSON-serializable and synchronous (no `await` across dispatch).

## Security

Loopback bind only. The bridge can edit + save scenes and run GDScript in the
editor — treat it with the same trust as the terminal. Never widen the bind.

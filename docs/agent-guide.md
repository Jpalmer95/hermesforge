# HermesForge for Agents

How an AI agent (Hermes, Claude Code, or any MCP client) drives Godot by
intent through the HermesForge bridge. This is the machine-facing companion to
[first-environment.md](first-environment.md).

## Mental model

You are not plumbing nodes. You are calling **semantic ops** that map to the
curated module stack. Each op is a single intent:

```
hermes_terrain_generate(recipe="rolling_hills", size_m=512, seed=42)
hermes_water_create(recipe="lake", at=[0,0,0], radius=56)
hermes_foliage_scatter(recipe="pine", count=60, area_m=200, seed=7)
hermes_sky_set(recipe="golden_hour")
```

Every op lands as **ordinary, hand-editable Godot nodes** in the open scene.
The human keeps full use of the stock editor; nothing you do is hidden.

## Setup

1. The target project must have the `hermes_bridge` editor plugin enabled. The
   `templates/golden-demo` project and every ForgeDNA-generated HermesForge
   project ship it pre-enabled. The plugin opens a loopback socket on
   `127.0.0.1:8787` while the editor is open.
2. The MCP server is `bridge/hermesforge_mcp.py` (FastMCP over stdio, run via
   `uv run`). Registered in `~/.hermes/config.yaml` as `mcp_servers.hermesforge`;
   tools appear as `mcp_hermesforge_*`.

## The 21 tools

Always call `hermes_project_info` first — it tells you the bridge is reachable,
the physics engine (expect `Jolt Physics`), and the Godot version. If the
editor is offline every tool returns a clean "bridge unreachable" error instead
of hanging.

| group | tools |
|-------|-------|
| project/scene | `hermes_project_info`, `hermes_scene_get_tree`, `hermes_scene_screenshot` (GUI only), `hermes_scene_save` |
| terrain | `hermes_terrain_generate`, `hermes_terrain_sculpt`, `hermes_terrain_info` |
| water | `hermes_water_create`, `hermes_water_remove`, `hermes_water_float_on_water`, `hermes_water_list` |
| foliage | `hermes_foliage_scatter`, `hermes_foliage_clear`, `hermes_foliage_list` |
| sky | `hermes_sky_set` |
| physics | `hermes_physics_audit`, `hermes_physics_collision_autogen`, `hermes_physics_vehicle`, `hermes_physics_ragdoll`, `hermes_physics_tune`, `hermes_physics_add_test_body` |

Full parameter tables live in [recipes.md](recipes.md). Per-module manifests
(capability lists, pitfalls, upstream licenses) live in
`modules/<name>/AGENT.md`.

## Ordering rules (matter)

1. **Terrain before water and foliage.** `foliage.scatter` samples the terrain
   heightfield; water sits in/on it. Generate terrain first.
2. **Water before buoyancy.** Create a water body, then `float_on_water` the
   RigidBody3Ds. Registering before any water exists returns an error.
3. **Multiple water bodies coexist.** `HermesWater`, `HermesWater2`, … Pass an
   explicit `name` to `water.create` to make re-runs idempotent per body.
4. **Save when done.** Ops mutate the live scene; `hermes_scene_save` persists.
   (ForgeDNA's headless `environment_apply.gd` packs + saves automatically.)

## Verify after you build

The point of HermesForge is *verifiable* generation. After building, confirm
the scene actually has what you intended:

- `hermes_terrain_info` — regions + real height range
- `hermes_water_list` — water bodies + wave params
- `hermes_foliage_list` — scatter groups + instance counts
- `hermes_physics_audit` — zero missing-collision issues
- `hermes_scene_get_tree` — full node tree

Headless (CI / no editor): `python qa/run.py --golden 1` and
`python qa/run.py --golden 2` drive the canonical intents through the real
socket and assert the result (9/9 and 19/19 checks, the latter including a
live buoyancy sim). Treat these as the contract your own builds should meet.

## Headless / batch generation (ForgeDNA)

If you need to *produce* a world without an editor session (CI, batch,
agentic pipeline), don't drive the socket yourself — use the ForgeDNA
compiler, which emits a project whose `environment_apply.gd` does it:

```bash
forgedna-harness build-full your_dna.json --output ./world --apply
```

`--apply` runs the same bridge ops headless and saves the world into
`main.tscn`. See [first-environment.md](first-environment.md) Path B.

## Pitfalls

- **Loopback only.** The bridge binds `127.0.0.1`; it can edit/save scenes and
  run GDScript — treat it with the same trust as a terminal. Never widen it.
- **Screenshot needs a GUI.** `hermes_scene_screenshot` returns a clean error
  under `--headless`; use the QA harness for headless verification instead.
- **Godot 4.7.x only.** The stack targets 4.7 (Terrain3D 1.0.2, built-in Jolt).
  Earlier versions are unsupported.
- **Keep ops synchronous.** New bridge ops must be JSON-serializable and must
  not `await` across the dispatch boundary (see bridge/README.md "Adding a tool").

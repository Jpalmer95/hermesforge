# HermesForge Module Contract

Every folder under `modules/<name>/` is a self-contained capability unit that
must be understandable and drivable by BOTH a human in the stock Godot editor
and an AI agent via the HermesForge MCP bridge. This contract is enforced by
`scripts/validate_modules.py` and runs in CI on every PR.

## Required layout

```
modules/<name>/
  AGENT.md            ← manifest (this contract, see below)
  addon/              ← the vendored upstream addon, dropped into a project's
                        addons/<name>/ as-is. MUST include upstream LICENSE.
  recipes/            ← JSON "DNA recipes": parameterized, agent-fillable
                        intent descriptions (schema below)
  tests/              ← golden scene(s) + headless assert script(s)
```

## AGENT.md manifest (YAML frontmatter + markdown)

Frontmatter fields (all required unless noted):

| field | meaning |
|-------|---------|
| `name` | module id, matches folder name (`terrain`, `pcg`, ...) |
| `display_name` | human name |
| `version` | vendored upstream version |
| `upstream` | upstream repo URL |
| `upstream_license` | SPDX id (MIT, Apache-2.0, ...) |
| `godot_min` / `godot_max` | compatible Godot version range (e.g. `"4.4"`) |
| `type` | `gdextension` \| `gdscript_plugin` \| `hybrid` \| `builtin` (engine built-in, e.g. Jolt on 4.4+) |
| `provides` | list of MCP capability ids this module exposes in Phase 1+ (e.g. `terrain.generate`) |
| `recipes` | list of recipe files present under `recipes/` |
| `status` | `vendored` \| `bridged` \| `tested` — maturity gate |

Markdown body MUST contain three sections:
1. `## What it does` — one paragraph, plain language.
2. `## For humans` — how to use it in the editor (enable plugin, where the UI lives).
3. `## For agents` — the exact MCP tool ids + recipe ids an agent should call,
   and any pitfalls (headless support, GPU requirements, mono requirement...).

## Recipe JSON schema (`recipes/<id>.recipe.json`)

```json
{
  "id": "rolling_hills",
  "module": "terrain",
  "description": "Gentle rolling hills, 1km, grass + dirt",
  "params": {
    "size_m":    {"type": "int",   "default": 1024, "min": 128, "max": 8192},
    "seed":      {"type": "int",   "default": 0},
    "amplitude": {"type": "float", "default": 30.0},
    "biome":     {"type": "enum",  "values": ["temperate","alpine","desert"]}
  },
  "emits": {"nodes": ["Terrain3D"], "signals": []}
}
```

Recipes are the agent-facing "vocabulary": an agent fills params and calls the
bridge; a human can hand-edit the same JSON and re-run.

## Golden tests (`tests/`)

Each module ships at least one headless check runnable via:

```
python qa/run.py modules/<name>/tests/<test_name>
```

Exit 0 = pass, non-zero = fail. A test is a folder with:
- `scene.tscn` (or a generator script) — the minimal exercising scene
- `assert.py` — receives a screenshot path + scene tree dump, returns 0/1
- `expect/` — reference screenshot(s) for diffing (optional in v0)

## Maturity gates

- `vendored`: files present, LICENSE included, AGENT.md valid
- `bridged`: at least one MCP capability implemented in the Phase 1 bridge
- `tested`: golden test passes headless in CI

Phase 0 ships all modules at `vendored`.

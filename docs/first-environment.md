# Your First Environment in 10 Minutes

This guide takes you from a fresh clone to a real, editable Godot world —
terrain, a lake, a pine shoreline, golden-hour light — in about ten minutes,
without writing a line of code or touching an editor until you *want* to.

You have two paths. Pick the one that fits how you work:

- **Path A — Hermes agent (recommended).** You describe the world in plain
  language; the HermesForge MCP tools build it live in your running editor.
- **Path B — ForgeDNA compiler.** You fill a small JSON "DNA"; the harness
  compiles it into a finished project headless, no editor session needed.

Both produce the same thing: an ordinary Godot project you can open, inspect,
and hand-edit. Nothing is hidden or locked.

---

## Prerequisites (one-time, ~3 min)

1. **Godot 4.7.x** on your PATH (or set `GODOT_BIN`). Download from
   [godotengine.org/download](https://godotengine.org/download). Standard
   (non-mono) is fine.
2. **Python 3.10+** (for the QA harness and MCP bridge).
3. **This repo:**
   ```bash
   git clone https://github.com/Jpalmer95/hermesforge.git
   cd hermesforge
   ```

Sanity-check the stack (~10 seconds):

```bash
python scripts/validate_modules.py     # module contract OK
python qa/run.py templates/base        # base template boots headless
```

If both pass, you're set up. That's the whole install.

---

## Path A — Drive it with Hermes (~5 min)

The bridge exposes 21 semantic tools (`hermes_terrain_generate`,
`hermes_water_create`, `hermes_foliage_scatter`, `hermes_sky_set`, …) so an
agent — or you, via the agent — builds the world by intent.

1. **Open the demo project in the editor:**
   ```bash
   godot --path templates/golden-demo
   ```
   The `hermes_bridge` plugin starts a local control socket on
   `127.0.0.1:8787` automatically.

2. **Ask Hermes** (with the hermesforge MCP server configured — see
   `bridge/README.md`):
   > "Create rolling-hills terrain 512m, add a lake in the middle, scatter a
   > pine forest around it, and set golden-hour light."

   The agent calls the tools; you watch the world appear in the editor
   viewport. Every node it creates is a normal Godot node — select it, move
   it, delete it, tweak its material.

3. **Verify it headless** (optional, ~15s):
   ```bash
   python qa/run.py --golden 1   # 9/9 checks
   python qa/run.py --golden 2   # 19/19 checks incl. a real buoyancy sim
   ```

---

## Path B — Compile it from a DNA (~5 min, no editor)

ForgeDNA turns a small JSON intent document into a finished project. The
`environment:` block is the HermesForge recipe vocabulary.

1. **Clone the compiler and install the harness:**
   ```bash
   git clone https://github.com/Jpalmer95/ForgeDNA.git
   cd ForgeDNA
   python3 -m venv harness/.venv
   harness/.venv/bin/pip install -e harness
   ```

2. **Build + realize the world in one command** (`--apply` runs the headless
   environment apply — no editor opens):
   ```bash
   harness/.venv/bin/forgedna-harness build-full \
     examples/quiet-hollow-hermesforge.json \
     --output ./my_world --apply
   ```

   You'll see `🌍 Build → World — Environment realized! (14 ops)`. The world
   (terrain, two ponds, pine/grass/shrub, golden hour) is now saved into
   `my_world/godot_project/main.tscn`.

3. **Open it:**
   ```bash
   godot --path ./my_world/godot_project
   ```
   It's a complete, ordinary Godot project with the environment already in
   the scene. Edit anything.

**Want your own world?** Copy `examples/quiet-hollow-hermesforge.json`, edit
the `environment:` block, and rebuild. The recipes are documented in
[recipes.md](recipes.md) — e.g. swap `rolling_hills` for `mountain_range`,
`pond` for `ocean`, `pine` for `jungle`, `golden_hour` for `clear_night`.

---

## What's in the world you just made

| Node | What it is | Where it came from |
|------|-----------|--------------------|
| `Terrain3D` | Editable heightfield terrain | `terrain.generate` (Terrain3D) |
| `HermesWater` | Gerstner-wave water + buoyancy | `water.create` |
| `Foliage_pine` … | MultiMesh scatter (one draw call each) | `foliage.scatter` |
| `WorldEnvironment` + `Sun` | Sky, fog, sun | `sky.set` |

Everything is a standard Godot node — open the scene tree and poke at it.

## Troubleshooting

- **`Godot binary not found`** → set `GODOT_BIN` to your Godot executable.
- **`bridge unreachable`** (Path A) → make sure the project is open in the
  editor; the bridge only runs while the editor is open.
- **QA harness fails on import** → run `python qa/run.py templates/base`
  alone to see the raw Godot log; usually a Godot version mismatch (needs
  4.7.x).

## Next steps

- [recipes.md](recipes.md) — the full recipe catalog (every module, every param).
- [agent-guide.md](agent-guide.md) — how AI agents drive the same tools.
- [../HERMESFORGE-MASTER-PLAN.md](../HERMESFORGE-MASTER-PLAN.md) — the roadmap.

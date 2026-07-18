# HermesForge

**A Hermes-native, human+AI-friendly Godot 4 editor distribution.** Curated
open-source physics, PCG, terrain, water, foliage and sky modules — each one
hand-tweakable in the stock Godot editor AND drivable by AI agents through a
semantic MCP bridge — plus an intent→project compiler (via ForgeDNA) that turns
"carve me a misty valley with a lake at golden hour" into a real, editable
Godot project.

Read the plan first: [HERMESFORGE-MASTER-PLAN.md](HERMESFORGE-MASTER-PLAN.md).

## Status (2026-07-18)

Phases 0–3.5 complete. Today this repo contains:

- `modules/` — vendored addons with agent/human manifests:
  - `terrain` — Terrain3D 1.0.2 (C++ GDExtension, MIT)
  - `pcg` — Gaea 2.0.0-beta6 (graph PCG, MIT)
  - `physics` — built-in Jolt (MIT; see module AGENT.md for why not the GDExtension)
  - `water` — Gerstner surface shader + buoyancy (HermesWaterBody)
  - `foliage` — headless MultiMesh scatter (deterministic per seed)
- `templates/base` — minimal Godot 4.7.1 project with modules pre-wired
- `templates/golden-demo` — base + `hermes_bridge` editor plugin + demo scene
- `bridge/` — the MCP bridge: `hermesforge_mcp.py` (Python MCP server, 21 tools)
  + the `hermes_bridge` Godot plugin (127.0.0.1:8787)
- `scripts/validate_modules.py` — enforces the module contract
- `qa/run.py` — headless QA harness (base boot + `--golden` end-to-end tests)
- `docs/` — human + agent guides + the recipe catalog

**ForgeDNA integration (Phase 3/3.5):** the [ForgeDNA](https://github.com/Jpalmer95/ForgeDNA)
compiler turns a `game_dna.json` with an `environment:` block into a
HermesForge-base project — and can realize the world **headless, no editor
session** (`forgedna-harness build-full <dna> --apply`).

## Quick start

Requirements: Godot 4.7.x on PATH (or `GODOT_BIN`), Python 3.10+.

```bash
# validate the module stack
python scripts/validate_modules.py

# boot the base template headless (QA harness)
python qa/run.py templates/base

# golden tests: rolling hills + lake + golden hour, then the full Phase 2 scene
python qa/run.py --golden 1    # 9/9 checks
python qa/run.py --golden 2    # 19/19 checks incl. a real buoyancy sim

# open a template in the editor
godot --path templates/golden-demo
```

**Your first environment in 10 minutes → [docs/first-environment.md](docs/first-environment.md)**

## Layout

```
modules/<name>/   AGENT.md (manifest) + addon/ + recipes/ + tests/
templates/base/   pre-wired Godot project (Jolt physics, Forward+)
qa/               headless verification harness
scripts/          validators and tooling
docs/             human + agent guides + recipe catalog
```

## Documentation

- **[docs/first-environment.md](docs/first-environment.md)** — 10-minute first
  environment (human quickstart, both the agent path and the ForgeDNA path).
- **[docs/recipes.md](docs/recipes.md)** — full recipe catalog (every module,
  every param, copy-paste `environment:` blocks).
- **[docs/agent-guide.md](docs/agent-guide.md)** — how AI agents drive the 21
  MCP tools (ordering rules, verification, pitfalls).
- `modules/<name>/AGENT.md` — per-module manifests (capabilities, licenses).
- `bridge/README.md` — bridge internals + how to add a tool.

## Principles

1. **Humans first-class.** Every AI action lands as ordinary scenes/scripts —
   nothing hidden, nothing locked.
2. **Agents first-class.** Every module ships an `AGENT.md` manifest + JSON
   recipes so an agent can understand and drive it without guessing.
3. **Curate, don't reinvent.** Best-in-class OSS addons, vendored with
   licenses preserved, composed cleanly.
4. **Local-first / BYOC.** Runs on your machine, your models, your GPU. No SaaS.

## License

HermesForge glue (manifests, bridge, harness, recipes): MIT — see LICENSE.
Vendored addons keep their own upstream licenses (all MIT today); see each
`modules/<name>/addon/LICENSE*`.

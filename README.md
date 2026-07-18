# HermesForge

**A Hermes-native, human+AI-friendly Godot 4 editor distribution.** Curated
open-source physics, PCG, terrain, water, foliage and sky modules — each one
hand-tweakable in the stock Godot editor AND drivable by AI agents through a
semantic MCP bridge — plus an intent→project compiler (via ForgeDNA) that turns
"carve me a misty valley with a lake at golden hour" into a real, editable
Godot project.

Read the plan first: [HERMESFORGE-MASTER-PLAN.md](HERMESFORGE-MASTER-PLAN.md).

## Status (2026-07-17)

Phase 0 (foundations) in progress. Today this repo contains:

- `modules/` — vendored addons with agent/human manifests:
  - `terrain` — Terrain3D 1.0.2 (C++ GDExtension, MIT)
  - `pcg` — Gaea 2.0.0-beta6 (graph PCG, MIT)
  - `physics` — Godot Jolt 0.16.0 (MIT)
- `templates/base` — Godot 4.7.1 project with all modules pre-wired
- `scripts/validate_modules.py` — enforces the module contract
- `qa/run.py` — headless QA harness v0

Coming next (see master plan): MCP bridge (`hermes_terrain_*`,
`hermes_water_*`, ...), water + foliage modules, recipes, golden tests.

## Quick start

Requirements: Godot 4.7.x on PATH (or `GODOT_BIN`), Python 3.10+.

```bash
# validate the module stack
python scripts/validate_modules.py

# boot the base template headless (QA harness)
python qa/run.py templates/base

# open the base template in the editor
godot --path templates/base
```

## Layout

```
modules/<name>/   AGENT.md (manifest) + addon/ + recipes/ + tests/
templates/base/   pre-wired Godot project (Jolt physics, Forward+)
qa/               headless verification harness
scripts/          validators and tooling
docs/             human + agent guides (Phase 4)
```

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

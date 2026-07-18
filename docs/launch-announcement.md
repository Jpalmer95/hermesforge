# HermesForge — Launch Announcement (draft)

> For review before posting. Suggested venues: GitHub repo announcement,
> r/godot, the Godot subreddit/forum, and a build-in-public thread tagging the
> Hermes/Nous ecosystem (per owner preference — genuine, not growth-hacky).

---

**HermesForge: a Hermes-native Godot 4 editor distribution — curated physics/PCG/terrain/water/foliage modules, drivable by AI agents and humans alike.**

I built HermesForge to scratch a specific itch: the Godot ecosystem has
world-class pieces (Terrain3D hit 1.0, Gaea 2.0 has a node-graph PCG editor,
Jolt physics is built into 4.4+), but there's no layer that makes them
*composable, scriptable, and understandable by AI agents* — and no clean way
to go from "carve me a misty valley with a lake at golden hour" to a real,
editable Godot project.

HermesForge is three layers, each usable on its own:

1. **Module stack** — Terrain3D, Gaea 2.0, built-in Jolt, a Gerstner-water +
   buoyancy kit, and a headless MultiMesh foliage scatter, vendored under
   `modules/` with a manifest (`AGENT.md`) + JSON recipes so both humans and
   agents can understand and tweak each one. Curation over reinvention.

2. **MCP bridge** — a Godot editor plugin + thin Python MCP server exposing 21
   *semantic* tools (`hermes_terrain_generate`, `hermes_water_create`,
   `hermes_foliage_scatter`, `hermes_sky_set`, `hermes_physics_audit`, …) so an
   agent drives the editor by intent, not raw node plumbing. Everything it does
   lands as ordinary, hand-editable Godot scenes — nothing hidden.

3. **ForgeDNA compiler** — a `game_dna.json` with an `environment:` block
   compiles into a HermesForge-base project, and can **realize the world
   headless, no editor session** (`forgedna-harness build-full <dna> --apply`).
   One JSON doc → a Godot project with terrain, water, foliage, and sky already
   in the scene.

**Verifiable by construction.** Everything ships with headless golden tests
(`python qa/run.py --golden 1` / `--golden 2`): the second drives "a lake with
floating crates, a pine shoreline, a vehicle on terrain" through the real
socket and asserts 19/19 checks — including a live buoyancy sim where a crate
actually rises to the surface. Agents can iterate autonomously against a real
success gate instead of guessing.

**Local-first / BYOC.** Runs on your machine, your models, your GPU. No SaaS,
no per-image API cost. MIT, and every vendored addon keeps its upstream
license.

Fresh clone → first golden demo in under a minute. Docs:
- 10-minute first environment (human quickstart)
- full recipe catalog
- agent guide (21 tools, ordering rules, pitfalls)

Repo: https://github.com/Jpalmer95/hermesforge
Companion compiler: https://github.com/Jpalmer95/ForgeDNA

Built with Hermes Agent (Nous Research). Feedback welcome — especially from
folks driving Godot with agents, or who've wanted PCG + physics to be more
scriptable.

---

*Demo video: to be recorded from a real Hermes session driving the bridge live
(see master plan Phase 4 note — the one remaining manual item).*

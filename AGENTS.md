# AGENTS.md — HermesForge

**A Hermes-native, human+AI-friendly Godot 4 editor distribution.** Curated open-source physics,
PCG, terrain, water, foliage and sky modules — each hand-tweakable in the *stock* Godot editor
**and** drivable by agents through a semantic MCP bridge — plus an intent→project compiler
(via ForgeDNA) that turns *"carve me a misty valley with a lake at golden hour"* into a real,
editable Godot project.

**Read `HERMESFORGE-MASTER-PLAN.md` first.** Execute it phase-by-phase using the
`subagent-driven-development` skill; mark `[x]` only after Success Criteria pass. Atomic commits.
Never commit secrets. Each phase is independently shippable.

## Status
Phases 0–4 complete — **launch-ready** (demo video pending a desktop GUI recording).
Decisions **D1–D6 approved 2026-07-17**.

## Decisions that must not be relitigated
- **D1 — Two repos.** `hermesforge` (distribution + bridge + modules) stays separate;
  `forgedna` stays its own repo and *consumes HermesForge as its target stack*.
- **D2 — Own HTTP socket on port 8787** (the godot-ai pattern). No upstream coupling.
- **D3 — GDScript compute ripple** for water interaction (standard Godot, no mono).
- **D5 — Also configure the Coding-Solo Godot MCP** (launch/run/debug) alongside the bridge.
- **D6 — Editor value first** (Phases 0–2); the ForgeDNA hub DB plan runs in parallel, orthogonal.

## Modules (`modules/`)
Vendored addons, each with agent/human manifests:
- `terrain` — Terrain3D 1.0.2 (C++ GDExtension, MIT)
- `pcg` — Gaea 2.0.0-beta6 (graph PCG, MIT)
- `physics` — **built-in Jolt** (MIT) — read the module `AGENT.md` for why *not* the GDExtension
- `water` — Gerstner surface shader + buoyancy (`HermesWaterBody`)
- `foliage`, `sky`

## The governing constraint
**Every module must be hand-tweakable in the stock Godot editor AND agent-drivable via MCP.**
That dual requirement is why the bridge exists instead of a bespoke scripting layer. A module
that only one of the two can drive does not meet the bar.

## Related
Cross-cutting context: `~/dev/knowledge` → `wiki/projects/game-and-xr.md`.

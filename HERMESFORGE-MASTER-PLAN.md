# HermesForge — Master Plan

> **For Hermes:** Use the `subagent-driven-development` skill to execute this plan
> phase-by-phase. Mark `[x]` only after Success Criteria pass. Atomic commits.
> Never commit secrets. Each phase is independently shippable.

**Vision:** Turn Godot 4.7 into a first-class, Hermes-native game editor — where a
human with intent (and one or more AI agents) can carve beautiful environments,
wire advanced physics and fluid simulation, and tune every knob by hand or by
prompt — by composing the best open-source Godot addons into a curated,
MCP-exposed "HermesForge Distribution" and evolving ForgeDNA from a text-spec
build harness into the intent→project compiler that drives it.

**Status:** v1.0 — Decisions D1–D6 APPROVED 2026-07-17. Phase 0 in progress.

**Decisions (all approved as recommended):**
- D1: Two repos — `hermesforge` (distribution+bridge+modules) + `forgedna` stays separate, consumes HermesForge as target stack.
- D2: Own HTTP socket on port 8787 (godot-ai pattern), no upstream coupling.
- D3: GDScript compute ripple for water interaction (standard Godot, no mono).
- D4: Foliage 1-hour spike deferred to start of Phase 2 (foliage3d vs Scatter vs Terrain3D instancer on golden scene).
- D5: Also configure Coding-Solo godot MCP (launch/run/debug) alongside bridge.
- D6: Editor value first (Phases 0–2); ForgeDNA hub DB plan runs in parallel later, orthogonal.

---

## 1. What we are NOT building

Get this out first, because "Godot as 1st-class Hermes editor with physics,
fluids, PCG" can be read five ways:

- NOT a fork of the Godot engine source. No C++ engine patches.
- NOT a new physics engine, fluid solver, or terrain system from scratch.
- NOT a replacement for the Godot editor UI. Humans keep the stock editor.
- NOT a hosted SaaS. Everything runs local-first on this machine (RTX 4070 PC),
  with Tailscale for remote Kanban/approvals only.
- NOT a one-shot generator that vomits a project the human can't edit.
  Every AI action lands as ordinary, hand-editable Godot scenes/scripts.

## 2. What we ARE building

A three-layer stack, each layer usable on its own:

```
┌───────────────────────────────────────────────────────────────────┐
│  LAYER 3 — FORGEDNA INTENT COMPILER (evolves existing repo)        │
│  game_dna.json  ──► build plan DAG ──► agent swarm ──► project     │
│  New: emits HermesForge project skeletons + DNA recipes per        │
│  module (terrain DNA, water DNA, foliage DNA, physics DNA)         │
└───────────────────────────────────────────────────────────────────┘
            ▲ feeds DNA recipes / projects into
┌───────────────────────────────────────────────────────────────────┐
│  LAYER 2 — HERMESFORGE MCP BRIDGE (the "1st-class Hermes" part)    │
│  A Godot editor plugin (addons/hermes_bridge) + thin MCP server    │
│  that exposes every curated module below as typed MCP tools:       │
│    hermes_terrain_*   hermes_water_*   hermes_foliage_*            │
│    hermes_physics_*   hermes_scene_*   hermes_project_*            │
│  Works alongside (does not replace) godot-ai generic editor tools. │
└───────────────────────────────────────────────────────────────────┘
            ▲ drives
┌───────────────────────────────────────────────────────────────────┐
│  LAYER 1 — HERMESFORGE MODULE STACK (curated addons, vendored)     │
│  Terrain3D • Gaea 2.0 • Jolt Physics • Water/fluid kit •           │
│  Foliage/scatter • Sky/atmosphere • VFX • QA harness               │
│  Each module = one folder with AGENT.md (manifest + capability     │
│  schema + recipe library + golden test) so humans AND agents       │
│  can understand and tweak it.                                      │
└───────────────────────────────────────────────────────────────────┘
```

The bet: **curation + agent legibility beats reinvention.** The Godot
ecosystem already has world-class pieces (Terrain3D hit 1.0, Gaea 2.0 has a
VisualShader-like node graph, Jolt is built into Godot 4.4+). What's missing
is a layer that makes them composable, scriptable, and understandable by AI
agents — and a distribution that wires them together cleanly.

## 3. Current state (honest snapshot, 2026-07-17)

Installed and working on this machine:

- Godot 4.7.1 stable (standard + mono) at `~/apps/`, symlinked into
  `~/.local/bin` (skill `hermes-3d-mcp` conventions)
- Blender 5.0.1 + `blender` MCP server (ahujasid) configured in Hermes
- `godot-ai` MCP entry configured (hi-godot, ~43 live-editor tools) —
  plugin server not currently running; CLOSED on :8000
- ForgeDNA repo at `~/dev/forgedna` — harness with 17 agent specs, DAG
  orchestrator, Godot engine adapter, MCP server mode, master plan with
  Phase 0–2 drafted (hub DB, lineage, agent registry — NOT started)
- `~/dev/godot-workspace/` with `starter-3d` and `planet-sphere` projects
- daggr-pipelines repo (separate) for asset-gen workflows; ComfyUI local GPU

Not yet present:

- No vendored addons anywhere (no Terrain3D/Gaea/Jolt in any project)
- No module manifest/agent-schema convention
- No HermesForge distribution repo
- Coding-Solo `godot` MCP server is not configured (only godot-ai + blender)

## 4. Layer 1 — Module stack (the curation)

Each module below is vendored under `modules/<name>/` in the HermesForge repo
with this contract:

```
modules/<name>/
  AGENT.md            ← manifest: version, upstream, license, Godot compat,
                        exported MCP capabilities, recipe index, known pitfalls
  addon/              ← the vendored upstream addon (git submodule or subtree)
  recipes/            ← JSON "DNA recipes" (parameterized, agent-fillable)
  tests/              ← golden scene + headless assert script (godot --headless)
```

### 4.1 terrain — Terrain3D (TokisanGames, C++ GDExtension, 1.0, MIT)

High-performance editable terrain, up to 32 textures, 10 LOD levels, collision,
hole cutting, instancer for scatter. Agent ops: generate-from-heightfield,
sculpt brushes, paint textures, bake navigation, stream regions.
Recipes: `rolling_hills`, `mountain_range`, `island`, `canyon`, `crater_lake`.

### 4.2 pcg — Gaea 2.0 (gaea-godot, MIT, active as of 2026-06)

Graph-based PCG with a VisualShader-like editor; chunk loader for infinite
worlds; 2D mature, 3D gridmap + heightmap workflows improving. Agent ops:
author graph from description, set node params, run generation, diff seeds.
Recipes: `cave_system`, `dungeon_layout`, `forest_scatter`, `biome_map`,
`river_carve`. Note upstream has an AI-contribution disclaimer — we comply
with their CONTRIBUTING terms (no upstream PRs of AI code without disclosure).

### 4.3 physics — Jolt (built into Godot 4.4+; godot-jolt GDExtension as
fallback/override)

Just enabling Jolt in project settings gets multi-core rigid bodies, better
CCD, vehicle constraints, soft bodies (via extension). Agent ops: audit scene
physics bodies, auto-generate collision shapes, tune solver iterations,
ragdoll setup, vehicle rig template. Recipes: `vehicle_arcade`,
`vehicle_sim`, `ragdoll_humanoid`, `destructible_prop`, `rope_chain`.

### 4.4 water — modular kit (no single winner; honest engineering needed)

Reality check: Godot has no single dominant 3D fluid sim. Best composable set:

- **Surface water:** realistic water shader (foam, waves, caustics,
  depth-based color) — several MIT candidates to evaluate
- **Interaction:** ripple/heightfield interaction (Kextex-style compute-shader
  interactive water is C#-based; we need a GDScript/port or evaluate
  boujie-water port) — decision D3
- **Buoyancy:** Jolt or GDScript buoyancy probes on floating bodies
- **VFX fluid:** GPU particle-based splash/spray, not true SPH (SPH is a
  phase-3+ stretch goal via compute shader)

Agent ops: create water body (plane/shape), set wave params, attach buoyancy
to selected bodies, add interaction ripple source, bake shore foam mask.
Recipes: `ocean`, `lake`, `river_spline`, `pond`, `waterfall`.

### 4.5 foliage — scatter/instancer (evaluate foliage3d vs Terrain3D
instancer vs Scatter addon)

PCG-driven placement with density masks, slope/height rules, wind animation,
LOD + impostors. Agent ops: paint density masks from biome data, spawn rules
from recipes, optimize draw calls. Recipes: `grass_field`, `pine_forest`,
`jungle_undergrowth`, `alpine_sparse`.

### 4.6 sky — atmosphere/clouds/day-night (PhysicalSky + volumetric clouds
config, or evaluate addons like Celestial)

Agent ops: set time-of-day presets, weather state machine, fog/ambient
grading per biome. Recipes: `golden_hour`, `overcast_storm`, `clear_night`,
`alien_sky`.

### 4.7 vfx — curated particle/VFX kit + Blender bridge

GPU particles presets + glTF pipeline from Blender MCP for hero assets.
Agent ops: spawn VFX preset, tune emission, hook to gameplay signal.
Recipes: `campfire`, `waterfall_mist`, `magic_aura`, `impact_dust`.

### 4.8 qa — headless verification harness (we write this)

Godot `--headless` runner + screenshot diff + scene validation + perf budget
checks (draw calls, physics tick ms). This is what lets agents iterate
autonomously with verifiable success criteria. Also wraps Coding-Solo
godot-mcp for run/debug capture (decision D5).

## 5. Layer 2 — HermesForge MCP bridge

Why not just use godot-ai (hi-godot) for everything? godot-ai gives generic
editor control (nodes, scripts, scenes — ~43 tools). It's excellent but
knows nothing about Terrain3D heightmaps or Gaea graphs. The bridge adds
*semantic* tools on top:

```
hermes_terrain_generate(recipe="rolling_hills", size=1024, seed=42)
hermes_terrain_sculpt(brush="raise", center=[x,z], radius=12, strength=0.4)
hermes_water_create(recipe="lake", at=[x,z], radius=80)
hermes_foliage_scatter(recipe="pine_forest", density=0.6, biome_mask="...")
hermes_physics_audit() -> report of bodies missing collision, perf risks
hermes_scene_screenshot(camera="overview") -> image for vision verify
hermes_project_run(test="golden_forest") -> pass/fail + perf metrics
```

Implementation: a Godot editor plugin (`addons/hermes_bridge/`, GDScript)
that opens a local HTTP+JSON control socket (same pattern as godot-ai,
port 8787), plus a thin Python MCP server (`hermes-mcp install hermesforge`)
that translates MCP tool calls to bridge commands. Keeps engine-side code
minimal; lets us version tool schemas in Python where iteration is cheap.

Layered access model (human + agent friendly):
- Humans: use the addons directly in the stock Godot editor. Nothing hidden.
- Quick agent edits: godot-ai generic tools (already wired).
- Semantic module ops: hermes_bridge MCP tools.
- Full builds: ForgeDNA harness driving all of the above.

## 6. Layer 3 — ForgeDNA evolution (the intent compiler)

ForgeDNA already parses game_dna.json → task DAG → 17 agent types → Godot
adapter. The evolution is scope, not rewrite:

1. New agent specs: `code_terrain`, `code_water`, `code_foliage`,
   `code_sky` — each emits HermesForge module recipes, not raw scenes.
2. Godot adapter v2: generated projects use the HermesForge module stack as
   their base template (project.godot with addons pre-wired, Jolt enabled).
3. DNA schema v2: add `environment:` block (terrain recipe, water bodies,
   biomes, sky presets) that maps 1:1 to module recipes.
4. The existing FORGEDNA-MASTER-PLAN phases (hub DB, lineage, registry)
   stay as-is; this plan doesn't block on them. Decision D6 covers whether
   we sequence hub work first or run streams in parallel.

## 7. Sustainability / cost model

Per the user's BYOC/local-first principles:

- All inference runs on user's own provider keys (Nous/xAI/OpenRouter) —
  no platform AI cost to anyone else.
- Asset generation (textures, models, audio) runs on local GPU (RTX 4070,
  ComfyUI/daggr) — no per-image API cost.
- HermesForge distribution is MIT, GitHub-public (build-in-public per user
  preference). Upstream licenses preserved in each module AGENT.md.
- If it goes viral: costs are zero-sum for us (git hosting + CI minutes);
  users bring their own models and GPUs. No community pool needed.

## 8. Phased execution

### Phase 0 — Foundations & decisions (week 1) — DONE 2026-07-17

- [x] D1–D6 decisions resolved (below) and recorded in this file
- [x] Repo created: `github.com/Jpalmer95/hermesforge` with this plan at root
- [x] `modules/` contract implemented (AGENT.md schema + validator script)
- [x] Vendor Terrain3D + Jolt + Gaea into `modules/`; each loads in a fresh
      Godot 4.7.1 project with zero errors
      (NOTE: physics uses **built-in Jolt**, not the godot-jolt GDExtension —
      v0.16.0 supports only Godot 4.3–4.6 and fails on 4.7.1. Built-in Jolt
      verified active via the `physics/jolt_physics_3d/*` settings tree.)
- [x] QA harness v0: `python qa/run.py <project>` launches headless, imports
      (GDExtension registration), opens a scene, exits 0/1
      (screenshot capture deferred to Phase 1 — needs the bridge/camera)
- Success criteria MET: `qa/run.py templates/base` passes; three modules
  verified live headless (Terrain3D instantiable, Jolt settings present, Gaea
  GDScript registered); AGENT.md validator passes on all three.

### Phase 1 — MCP bridge v1 (week 2) — DONE 2026-07-17

- [x] `addons/hermes_bridge` editor plugin: HTTP control socket (loopback
      127.0.0.1:8787) + command dispatch + scene screenshot. Implemented as
      `bridge_server.gd` (editor-independent core) + thin `hermes_bridge.gd`
      EditorPlugin + `handlers/` (scene/terrain/water/sky/physics).
- [x] Python MCP server wrapping bridge (`bridge/hermesforge_mcp.py`, FastMCP
      over stdio via `uv run`) — first 11 tools: project.info, scene.get_tree,
      scene.screenshot, scene.save, terrain.generate/sculpt/info, water.create/
      remove, sky.set, physics.audit. Verified: MCP handshake + 11 tools
      registered + clean "bridge unreachable" when editor offline.
- [x] Wired into `~/.hermes/config.yaml` (`mcp_servers.hermesforge`); tools
      appear as `mcp_hermesforge_*` in a new session. Documented in
      `bridge/README.md`.
- [x] Golden test: "create rolling hills terrain 512m, add a lake, set golden
      hour" driven end-to-end through the real bridge socket → 9/9 structural
      checks pass headless. Reproducible: `python qa/run.py --golden
      templates/golden-demo` (import pass built in).
- Success criteria MET except: screenshot capture requires the editor GUI (no
  xvfb on this box) — `scene.screenshot` is implemented and returns a clean
  error headless; verify visually on a desktop session. Terrain v1 uses a
  coarse 16m step + single noise field; multi-texture painting + biomes land
  in Phase 2.

### Phase 2 — Water & physics depth (week 3–4) — DONE 2026-07-18

- [x] Water module: Gerstner surface shader (`water_surface.gdshader`) +
      buoyancy (`HermesWaterBody` floats RigidBody3Ds with matching wave math)
      + 5 recipes (lake/pond/ocean/river_spline/calm_pool). Buoyancy sim
      verified: crate rises toward surface headless.
- [x] Physics module: audit (now detects dynamic-trimesh perf traps),
      collision auto-gen (convex/box/sphere/trimesh), vehicle builder (4-wheel
      VehicleBody3D, arcade/sim), ragdoll flagging, Jolt tune presets
      (performance/balanced/quality), test-body helper.
- [x] Foliage module (D4 resolved): direct MultiMesh scatter (headless-safe,
      zero-dep) over terrain-height sampling. 6 recipes (pine/jungle/alpine/
      rock/grass/shrub), Poisson-ish spacing, deterministic by seed. D4 spike
      outcome: rejected HungryProton/scatter (perf reports + dep), Spatial
      Gardener (stale pre-4.7, painter not agent-oriented), Terrain3D instancer
      (needs editor asset-dock setup — may bridge later as a backend).
- [x] New MCP tools: 21 total (added collision_autogen, vehicle, ragdoll,
      tune, add_test_body, water.float_on_water, water.list, foliage.scatter/
      clear/list).
- Success criteria: golden scene "lake with floating crates, pine shoreline,
  vehicle on terrain" runs headless and passes physics audit with zero
  missing-collision issues → MET via `python qa/run.py --golden 2` (19/19,
  incl. buoyancy sim). The ≥60fps-on-4070 sub-check needs a desktop GUI run
  (headless here can't measure render fps); flagged for desktop verification.

### Phase 3 — ForgeDNA integration (week 5–6)

- [ ] DNA schema v2 `environment:` block + validation
- [ ] 4 new agent specs wired into orchestrator
- [ ] Godot adapter v2 emitting HermesForge-base projects
- [ ] End-to-end: one existing example DNA (quiet_hollow or forgednaRPG1test)
      rebuilt onto HermesForge stack and playable
- Success criteria: `forgedna-harness build-full <dna> --backend api` produces
  a project that opens in the HermesForge editor with terrain/water/foliage
  present, and the QA harness passes on it.

### Phase 4 — Polish, docs, public launch (week 7–8)

- [ ] Human docs: "10-minute first environment" guide
- [ ] Agent docs: per-module AGENT.md finalized + recipe catalog
- [ ] Demo video (recorded from a real Hermes session)
- [ ] Public repo announcement; tag Nous/Hermes ecosystem per user preference
- Success criteria: a fresh clone + documented setup reaches the Phase 1
  golden demo in ≤15 minutes on a machine with Godot + Hermes installed.

## 9. Future roadmap (post-launch; agents must NOT execute)

- True SPH/FLIP fluid via compute shader (Godot 4.7 RenderingDevice)
- Voxel/destructible terrain module
- Blender→Godot live-link hero-asset pipeline (glTF round-trip)
- Multi-agent collaborative editing (two agents, one scene, conflict policy)
- Web export of golden scenes embedded in a public gallery
- Community recipe registry (share/rate DNA recipes)

## 10. Open decisions (resolve before Phase 0)

- **D1 — Repo strategy:** new repo `hermesforge` (distribution + bridge +
  modules), with ForgeDNA staying its own repo and consuming HermesForge as
  the target stack? Or everything inside `forgedna` monorepo?
  Recommendation: two repos — distribution is independently useful and
  independently star-able.
- **D2 — Bridge protocol:** own HTTP socket (port 8787, godot-ai pattern)
  vs extending godot-ai's plugin? Recommendation: own socket — clean
  versioning, no upstream coupling, same proven pattern.
- **D3 — Water interaction:** port a GDScript compute ripple solution vs
  adopt the C# Kextex-style addon (requires mono)? Recommendation: GDScript
  compute (standard Godot, no mono dependency), accept smaller feature set
  at v1.
- **D4 — Foliage:** adopt foliage3d (Unreal-PCG-inspired, alpha) vs mature
  Scatter addon vs Terrain3D instancer only? Needs a 1-hour spike comparing
  the three on our golden scene before Phase 2.
- **D5 — Debug/run loop:** also configure Coding-Solo godot MCP (14 tools,
  launch/run/debug) alongside bridge? Recommendation: yes — complementary,
  costs nothing, already documented in hermes-3d-mcp skill.
- **D6 — Sequencing vs ForgeDNA hub plan:** run this plan's Phases 0–2 first
  (editor value), then ForgeDNA Phase 0 (hub DB) in parallel with our
  Phase 3? Or interleave? Recommendation: editor value first; hub DB is
  orthogonal and can wait.

---

*Author: Hermes + Jonathan Korstad. Date: 2026-07-17. Status: draft —
decisions D1–D6 pending. This document is authoritative; update it after
every phase (user preference: durable repo docs over chat context).*

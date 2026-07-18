#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["mcp>=1.0"]
# ///
"""HermesForge MCP server — semantic Godot editor tools.

Run over stdio (Hermes `mcp_servers` entry, command = this file via `uv run`).
Talks to the hermes_bridge Godot editor plugin over a loopback HTTP socket
(127.0.0.1:8787). Exposes semantic terrain/water/sky/scene/physics tools so an
agent drives the editor by intent, not raw node plumbing.

Transport: stdio MCP (FastMCP). Bridge: HTTP+JSON to the running editor.

If the editor isn't running (bridge unreachable), every tool returns a clear
"editor offline" error instead of hanging — agents should call
hermes_project_info first to check.
"""
from __future__ import annotations

import json
import urllib.error
import urllib.request

from mcp.server.fastmcp import FastMCP  # type: ignore[import-not-found]

BRIDGE = "http://127.0.0.1:8787"
TIMEOUT = 30

mcp = FastMCP("hermesforge")


def _post(op: str, args: dict) -> dict:
    """Call one bridge op; never raises — returns an error dict instead."""
    body = json.dumps({"op": op, "args": args}).encode()
    req = urllib.request.Request(
        f"{BRIDGE}/call", data=body,
        headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.URLError as e:
        return {"ok": False,
                "error": f"editor offline / bridge unreachable: {e.reason}",
                "hint": "open the project in Godot with the hermes_bridge plugin enabled"}
    except Exception as e:  # noqa: BLE001 - surface any bridge issue as data
        return {"ok": False, "error": f"bridge call failed: {e}"}


def _health() -> dict:
    try:
        with urllib.request.urlopen(f"{BRIDGE}/health", timeout=5) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "error": f"bridge unreachable: {e}"}


def _fmt(result: dict) -> str:
    return json.dumps(result, indent=2)


# ---- project / scene ----

@mcp.tool()
def hermes_project_info() -> str:
    """Get editor + project status: name, path, Godot version, physics engine,
    whether built-in Jolt is active, and whether the bridge is reachable."""
    health = _health()
    if not health.get("ok"):
        return _fmt(health)
    return _fmt(_post("project.info", {}))


@mcp.tool()
def hermes_scene_get_tree(max_depth: int = 6) -> str:
    """Return the open scene's node tree (names + types) as JSON."""
    return _fmt(_post("scene.get_tree", {"max_depth": max_depth}))


@mcp.tool()
def hermes_scene_screenshot(path: str = "user://hermesforge_shot.png") -> str:
    """Capture the editor 3D viewport to a PNG. Returns the absolute path.
    Requires the editor GUI (fails cleanly under --headless)."""
    return _fmt(_post("scene.screenshot", {"path": path}))


@mcp.tool()
def hermes_scene_save() -> str:
    """Save the currently open scene to disk."""
    return _fmt(_post("scene.save", {}))


# ---- terrain ----

@mcp.tool()
def hermes_terrain_generate(
    recipe: str = "rolling_hills",
    size_m: int = 512,
    seed: int = 0,
    amplitude: float = 30.0,
    frequency: float = 0.004,
) -> str:
    """Generate Terrain3D heightfield from a named recipe.

    recipe: rolling_hills | mountain_range | island
    size_m: side length of the terrain in meters (coarse 16m steps in v1)
    amplitude: max height variation in meters
    frequency: noise frequency (lower = broader features)
    """
    return _fmt(_post("terrain.generate", {
        "recipe": recipe, "size_m": size_m, "seed": seed,
        "amplitude": amplitude, "frequency": frequency}))


@mcp.tool()
def hermes_terrain_sculpt(
    center: list[float] = [0, 0, 0],
    radius: float = 32.0,
    strength: float = 5.0,
) -> str:
    """Raise (+strength) or lower (-strength) terrain in a radius around center
    (world [x,y,z]). Smooth falloff from center to edge."""
    return _fmt(_post("terrain.sculpt", {
        "center": list(center), "radius": radius, "strength": strength}))


@mcp.tool()
def hermes_terrain_info() -> str:
    """Report whether a Terrain3D node exists, region size, and height range."""
    return _fmt(_post("terrain.info", {}))


# ---- water ----

@mcp.tool()
def hermes_water_create(
    recipe: str = "lake",
    at: list[float] = [0, 0, 0],
    radius: float = 48.0,
) -> str:
    """Create a water body (styled plane + material; Area3D hook for Phase 2
    buoyancy). recipe: lake | ocean | river_spline | pond. at = world [x,y,z]
    of the water surface center."""
    return _fmt(_post("water.create", {
        "recipe": recipe, "at": list(at), "radius": radius}))


@mcp.tool()
def hermes_water_remove() -> str:
    """Remove the HermesWater node created by hermes_water_create."""
    return _fmt(_post("water.remove", {}))


# ---- sky ----

@mcp.tool()
def hermes_sky_set(recipe: str = "midday") -> str:
    """Set sky/sun/fog from a preset: golden_hour | midday | overcast_storm |
    clear_night. Configures WorldEnvironment + a DirectionalLight3D sun."""
    return _fmt(_post("sky.set", {"recipe": recipe}))


# ---- physics ----

@mcp.tool()
def hermes_physics_audit() -> str:
    """Audit the open scene: physics bodies, how many lack collision shapes,
    dynamic-trimesh perf traps, and whether built-in Jolt is active."""
    return _fmt(_post("physics.audit", {}))


# ---- physics depth (Phase 2) ----

@mcp.tool()
def hermes_physics_collision_autogen(node: str, mode: str = "convex") -> str:
    """Auto-generate collision for a MeshInstance3D. mode: convex (default,
    best for dynamic) | box | sphere | trimesh (static only). Wraps the mesh in
    a StaticBody3D if it has no physics body parent."""
    return _fmt(_post("physics.collision_autogen", {"node": node, "mode": mode}))


@mcp.tool()
def hermes_physics_vehicle(
    recipe: str = "vehicle_arcade",
    at: list[float] = [0, 2, 0],
) -> str:
    """Spawn a 4-wheel VehicleBody3D rig. recipe: vehicle_arcade (high grip) |
    vehicle_sim (weighty). Returns the rig node name (HermesVehicle)."""
    return _fmt(_post("physics.vehicle", {"recipe": recipe, "at": list(at)}))


@mcp.tool()
def hermes_physics_ragdoll(node: str) -> str:
    """Flag a humanoid Skeleton3D for ragdoll (physical bones). node = skeleton
    name. Full generation runs in-editor where the skeleton pose is available."""
    return _fmt(_post("physics.ragdoll", {"node": node}))


@mcp.tool()
def hermes_physics_tune(preset: str = "balanced") -> str:
    """Set Jolt solver quality preset: performance (6/1) | balanced (10/2) |
    quality (16/4) velocity/position steps."""
    return _fmt(_post("physics.tune", {"preset": preset}))


@mcp.tool()
def hermes_physics_add_test_body(
    name: str = "TestBody",
    shape: str = "box",
    mass: float = 1.0,
    at: list[float] = [0, 2, 0],
) -> str:
    """Add a simple RigidBody3D (box|sphere) — for testing buoyancy/physics."""
    return _fmt(_post("physics.add_test_body", {
        "name": name, "shape": shape, "mass": mass, "at": list(at)}))


# ---- water depth (Phase 2) ----

@mcp.tool()
def hermes_water_float_on_water(node: str) -> str:
    """Register a named RigidBody3D to float on the HermesWater surface using
    buoyancy. Create water first via hermes_water_create."""
    return _fmt(_post("water.float_on_water", {"node": node}))


@mcp.tool()
def hermes_water_list() -> str:
    """Report the active water body: position, wave params, available recipes."""
    return _fmt(_post("water.list", {}))


# ---- foliage (Phase 2) ----

@mcp.tool()
def hermes_foliage_scatter(
    recipe: str = "pine",
    count: int = 200,
    area_m: float = 200.0,
    seed: int = 0,
    min_spacing: float = 2.0,
    y_offset: float = 0.0,
    name: str = "",
) -> str:
    """Scatter foliage meshes across terrain via MultiMeshInstance3D, placed on
    the terrain surface. recipe: pine | jungle | alpine | rock | grass | shrub.
    Deterministic for a given seed. Idempotent per name."""
    return _fmt(_post("foliage.scatter", {
        "recipe": recipe, "count": count, "area_m": area_m, "seed": seed,
        "min_spacing": min_spacing, "y_offset": y_offset, "name": name}))


@mcp.tool()
def hermes_foliage_clear(name: str = "") -> str:
    """Remove scattered foliage. name = specific group, or empty to clear all."""
    return _fmt(_post("foliage.clear", {"name": name}))


@mcp.tool()
def hermes_foliage_list() -> str:
    """List scattered foliage groups and their instance counts."""
    return _fmt(_post("foliage.list", {}))


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()

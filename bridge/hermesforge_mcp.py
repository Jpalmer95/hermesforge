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
    and whether built-in Jolt is active. Returns an issue list."""
    return _fmt(_post("physics.audit", {}))


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()

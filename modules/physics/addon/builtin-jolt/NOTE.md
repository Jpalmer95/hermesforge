# Jolt Physics — built-in backend (Godot 4.4+)

This module uses **Godot's built-in Jolt Physics** (compiled into official
Godot 4.4+), not the godot-jolt GDExtension.

Why: godot-jolt GDExtension v0.16.0 (latest, 2026-02) supports only Godot
4.3–4.6 and fails to load on 4.7.1 ("compatible with 4.6 or earlier").
Built-in Jolt is the upstream-recommended path for 4.4+ and is fully active
here (verified: `physics/jolt_physics_3d/*` settings tree present at runtime).

## How to enable (already set in templates/base/project.godot)
    [physics]
    3d/physics_engine="Jolt Physics"

## If a future godot-jolt release adds 4.7 support and you want extension-only
## features (soft bodies beyond built-in, extra joints), vendor it here and set
## physics engine to "Jolt Physics (Extension)" instead.

License note: Jolt itself is MIT (c) Mikael Hermansson and Godot Jolt
contributors. Built-in Jolt ships inside the MIT-licensed Godot engine.

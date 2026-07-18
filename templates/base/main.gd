extends Node3D
# Minimal boot scene for the HermesForge base template.
# Exists so the QA harness has a main scene to open headless.

func _ready() -> void:
	print("HermesForge base template booted OK")
	print("Physics engine: ", ProjectSettings.get_setting("physics/3d/physics_engine", "default"))

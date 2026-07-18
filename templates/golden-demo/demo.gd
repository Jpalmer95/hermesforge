extends Node3D
# HermesForge golden-demo root. The bridge drives this scene (terrain, water,
# sky). A camera + light are present so scene.screenshot has something to draw.

func _ready() -> void:
	print("[golden-demo] booted; physics=", ProjectSettings.get_setting("physics/3d/physics_engine", "?"))

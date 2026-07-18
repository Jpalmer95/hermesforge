extends "res://addons/hermes_bridge/handlers/base_handler.gd"
## Scene + project ops: info, tree, screenshot.


func get_ops() -> Array:
	return ["project.info", "scene.get_tree", "scene.screenshot", "scene.save"]


func call_op(op: String, args: Dictionary) -> Dictionary:
	match op:
		"project.info":
			return _project_info()
		"scene.get_tree":
			return _scene_get_tree()
		"scene.screenshot":
			return awaitable_screenshot(args)
		"scene.save":
			return _scene_save()
	return _err("unhandled op", {"op": op})


func _project_info() -> Dictionary:
	return _ok({
		"name": ProjectSettings.get_setting("application/config/name", "?"),
		"path": ProjectSettings.globalize_path("res://"),
		"physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine", "default"),
		"jolt_builtin_active": ProjectSettings.has_setting("physics/jolt_physics_3d/simulation/velocity_steps"),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
		"godot": Engine.get_version_info().get("string", "?"),
	})


func _serialize_node(node: Node, depth: int, max_depth: int) -> Dictionary:
	var d := {
		"name": node.name,
		"type": node.get_class(),
		"children": [],
	}
	if node.owner != null and node.scene_file_path != "":
		d["scene_file"] = node.scene_file_path
	if depth < max_depth:
		for child in node.get_children():
			d["children"].append(_serialize_node(child, depth + 1, max_depth))
	return d


func _scene_get_tree() -> Dictionary:
	var root := _editor_root()
	if root == null:
		return _err("no scene open")
	return _ok({"tree": _serialize_node(root, 0, 6), "root": root.name})


func awaitable_screenshot(args: Dictionary) -> Dictionary:
	# Screenshot the editor 3D viewport (grabs the last rendered frame).
	# Headless / no-viewport: returns a clear error rather than hanging.
	var path := str(args.get("path", "user://hermesforge_shot.png"))
	var abs_path := ProjectSettings.globalize_path(path)
	var iface = _editor_interface()
	var img: Image = null
	if iface and iface.has_method("get_editor_viewport_3d"):
		var vp: Viewport = iface.get_editor_viewport_3d(0)
		if vp and vp.get_texture():
			img = vp.get_texture().get_image()
	if img == null:
		return _err("screenshot unavailable (no editor 3D viewport / headless)")
	var err := img.save_png(abs_path)
	if err != OK:
		return _err("failed to save screenshot", {"code": err})
	return _ok({"screenshot": abs_path, "size": [img.get_width(), img.get_height()]})


func _scene_save() -> Dictionary:
	var iface = _editor_interface()
	if iface and iface.has_method("save_scene"):
		var err: int = iface.save_scene()
		return _ok({"saved": err == OK}) if err == OK else _err("save failed", {"code": err})
	return _err("save_scene unavailable")

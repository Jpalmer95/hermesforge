extends "res://addons/hermes_bridge/handlers/base_handler.gd"
## Physics ops (Phase 1 basic): audit the open scene for bodies missing
## collision shapes and other common problems. Deeper autogen/ragdoll/vehicle
## come in Phase 2 via the physics module.


func get_ops() -> Array:
	return ["physics.audit"]


func call_op(op: String, args: Dictionary) -> Dictionary:
	match op:
		"physics.audit":
			return _physics_audit()
	return _err("unhandled op", {"op": op})


func _physics_audit() -> Dictionary:
	var root := _editor_root()
	if root == null:
		return _err("no scene open")
	var issues: Array = []
	var bodies := 0
	var with_shape := 0
	_scan_node(root, issues, bodies, with_shape)
	return _ok({
		"physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine", "default"),
		"jolt_builtin_active": ProjectSettings.has_setting("physics/jolt_physics_3d/simulation/velocity_steps"),
		"bodies": bodies,
		"bodies_with_shape": with_shape,
		"issue_count": issues.size(),
		"issues": issues,
	})


func _scan_node(node: Node, issues: Array, bodies: int, with_shape: int) -> void:
	var is_body := node is RigidBody3D or node is StaticBody3D \
		or node is CharacterBody3D or node is AnimatableBody3D
	if is_body:
		bodies += 1
		var has_shape := false
		for c in node.get_children():
			if c is CollisionShape3D or c is CollisionPolygon3D:
				has_shape = true
				break
		if has_shape:
			with_shape += 1
		else:
			issues.append({
				"node": str(node.get_path()),
				"type": node.get_class(),
				"problem": "physics body with no collision shape",
			})
	for child in node.get_children():
		_scan_node(child, issues, bodies, with_shape)

extends "res://addons/hermes_bridge/handlers/base_handler.gd"
## Water ops (Phase 1 basic): create a water body as a styled plane with a
## water material + optional Area3D for future buoyancy. Phase 2 adds real
## surface shader / ripple interaction / buoyancy via the water module.


func get_ops() -> Array:
	return ["water.create", "water.remove"]


func call_op(op: String, args: Dictionary) -> Dictionary:
	match op:
		"water.create":
			return _water_create(args)
		"water.remove":
			return _water_remove(args)
	return _err("unhandled op", {"op": op})


func _water_create(args: Dictionary) -> Dictionary:
	var root := _editor_root()
	if root == null:
		return _err("no scene open")
	var recipe := str(args.get("recipe", "lake"))
	var at := _to_vec3(args.get("at", [0, 0, 0]))
	var radius := float(args.get("radius", 48.0))

	# Remove any existing water body of the same name first (idempotent).
	var existing := _find_node_by_name(root, "HermesWater")
	if existing:
		existing.queue_free()

	var water := MeshInstance3D.new()
	water.name = "HermesWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	water.mesh = plane

	var mat := StandardMaterial3D.new()
	match recipe:
		"lake", "pond":
			mat.albedo_color = Color(0.08, 0.24, 0.32, 0.78)
		"ocean":
			mat.albedo_color = Color(0.03, 0.16, 0.28, 0.82)
		"river_spline":
			mat.albedo_color = Color(0.10, 0.30, 0.34, 0.75)
		_:
			mat.albedo_color = Color(0.08, 0.24, 0.32, 0.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.1
	mat.roughness = 0.05
	mat.set("uv1_scale", Vector3(4, 4, 4))
	water.material_override = mat

	water.position = at
	root.add_child(water)
	water.owner = root
	return _ok({"recipe": recipe, "at": [at.x, at.y, at.z], "radius": radius, "node": "HermesWater"})


func _water_remove(_args: Dictionary) -> Dictionary:
	var root := _editor_root()
	var w := _find_node_by_name(root, "HermesWater") if root else null
	if w == null:
		return _err("no HermesWater node present")
	w.queue_free()
	return _ok({"removed": true})

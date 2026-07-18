extends "res://addons/hermes_bridge/handlers/base_handler.gd"
## Foliage ops v1: scatter meshes across terrain via MultiMeshInstance3D.
## Decision D4: uses direct MultiMesh scattering (headless-safe, no asset-dock
## dependency) rather than Terrain3D's instancer (needs editor asset setup) or
## HungryProton/scatter (optional; see modules/foliage/AGENT.md).
## Places instances on the terrain surface via Terrain3D.data.get_height().


func get_ops() -> Array:
	return ["foliage.scatter", "foliage.clear", "foliage.list"]


# Built-in mesh recipes (procedural primitives so no asset import needed).
# Agents can also pass a custom mesh via foliage.scatter(mesh_path=...).
const MESH_RECIPES := {
	"pine":    {"kind": "cone",    "color": Color(0.10, 0.28, 0.12), "h": 6.0, "r": 1.4},
	"jungle":  {"kind": "cone",    "color": Color(0.16, 0.42, 0.16), "h": 5.0, "r": 2.0},
	"alpine":  {"kind": "cone",    "color": Color(0.14, 0.24, 0.18), "h": 7.0, "r": 1.2},
	"rock":    {"kind": "rock",    "color": Color(0.42, 0.40, 0.38), "h": 1.2, "r": 1.0},
	"grass":   {"kind": "grass",   "color": Color(0.22, 0.46, 0.18), "h": 0.6, "r": 0.15},
	"shrub":   {"kind": "sphere",  "color": Color(0.18, 0.36, 0.16), "h": 1.0, "r": 0.8},
}


func call_op(op: String, args: Dictionary) -> Dictionary:
	match op:
		"foliage.scatter":
			return _scatter(args)
		"foliage.clear":
			return _clear(args)
		"foliage.list":
			return _list()
	return _err("unhandled op", {"op": op})


func _build_mesh(recipe: Dictionary) -> Mesh:
	var mesh: Mesh
	match recipe["kind"]:
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = recipe["r"]
			c.height = recipe["h"]
			mesh = c
		"rock":
			var s := SphereMesh.new()
			s.radius = recipe["r"]
			s.height = recipe["h"] * 2.0
			s.radial_segments = 6
			s.rings = 4
			mesh = s
		"grass":
			var b := BoxMesh.new()
			b.size = Vector3(recipe["r"], recipe["h"], recipe["r"])
			mesh = b
		_:  # sphere / shrub
			var s := SphereMesh.new()
			s.radius = recipe["r"]
			s.height = recipe["h"] * 2.0
			mesh = s
	return mesh


func _scatter(args: Dictionary) -> Dictionary:
	var root := _editor_root()
	if root == null:
		return _err("no scene open")
	var recipe_name := str(args.get("recipe", "pine"))
	if not MESH_RECIPES.has(recipe_name):
		return _err("unknown foliage recipe", {"recipes": MESH_RECIPES.keys()})
	var count := int(args.get("count", 200))
	var area := float(args.get("area_m", 200.0))  # square side length
	var seed := int(args.get("seed", 0))
	var min_spacing := float(args.get("min_spacing", 2.0))
	var group_name := str(args.get("name", "Foliage_" + recipe_name))
	var y_offset := float(args.get("y_offset", 0.0))

	var recipe: Dictionary = MESH_RECIPES[recipe_name]

	# Remove existing group of same name (idempotent re-scatter).
	var existing := _find_node_by_name(root, group_name)
	if existing:
		existing.queue_free()

	# Find terrain to sample heights (optional — falls back to flat 0).
	var terrain := _find_node_by_name(root, "Terrain3D")

	# Build the MultiMesh.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _build_mesh(recipe)

	# Poisson-ish placement via jittered grid + rejection on spacing.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var transforms: Array = []
	var half := area / 2.0
	var attempts := 0
	var max_attempts := count * 10
	while transforms.size() < count and attempts < max_attempts:
		attempts += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var ok := true
		for t in transforms:
			var dx: float = t.origin.x - x
			var dz: float = t.origin.z - z
			if dx * dx + dz * dz < min_spacing * min_spacing:
				ok = false
				break
		if not ok:
			continue
		var y := 0.0
		if terrain and terrain.data:
			y = terrain.data.get_height(Vector3(x, 0, z))
		var basis := Basis().rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		var scale_r := rng.randf_range(0.8, 1.3)
		basis = basis.scaled(Vector3.ONE * scale_r)
		transforms.append(Transform3D(basis, Vector3(x, y + y_offset, z)))

	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, recipe["color"])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = group_name
	mmi.multimesh = mm
	# Simple foliage material (vertex-color aware).
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mmi.material_override = mat
	root.add_child(mmi)
	mmi.owner = root

	return _ok({
		"recipe": recipe_name, "requested": count, "placed": transforms.size(),
		"node": group_name, "area_m": area, "min_spacing": min_spacing,
		"attempts": attempts,
	})


func _clear(args: Dictionary) -> Dictionary:
	var root := _editor_root()
	var name := str(args.get("name", ""))
	var removed := 0
	if name != "":
		var n := _find_node_by_name(root, name)
		if n and n is MultiMeshInstance3D:
			n.queue_free()
			removed += 1
	else:
		removed = _clear_all_foliage(root)
	return _ok({"removed": removed})


func _clear_all_foliage(node: Node) -> int:
	var removed := 0
	for c in node.get_children():
		removed += _clear_all_foliage(c)
	if node is MultiMeshInstance3D and node.name.begins_with("Foliage_"):
		node.queue_free()
		removed += 1
	return removed


func _list() -> Dictionary:
	var root := _editor_root()
	var groups := []
	_collect_foliage(root, groups)
	return _ok({"groups": groups, "count": groups.size(), "recipes": MESH_RECIPES.keys()})


func _collect_foliage(node: Node, out: Array) -> void:
	if node == null:
		return
	if node is MultiMeshInstance3D and node.multimesh:
		out.append({"name": node.name, "instances": node.multimesh.instance_count})
	for c in node.get_children():
		_collect_foliage(c, out)

extends "res://addons/hermes_bridge/handlers/base_handler.gd"
## Terrain ops: generate (from recipe), sculpt, info. Drives Terrain3D.

const STEP_M := 16  # coarse sculpt step for v1 (fast; refine later)


func get_ops() -> Array:
	return ["terrain.generate", "terrain.sculpt", "terrain.info"]


func call_op(op: String, args: Dictionary) -> Dictionary:
	match op:
		"terrain.generate":
			return _terrain_generate(args)
		"terrain.sculpt":
			return _terrain_sculpt(args)
		"terrain.info":
			return _terrain_info()
	return _err("unhandled op", {"op": op})


func _get_or_create_terrain() -> Node:
	var root := _editor_root()
	if root == null:
		return null
	var t := _find_node_by_name(root, "Terrain3D")
	if t == null:
		if not ClassDB.class_exists("Terrain3D"):
			return null
		t = ClassDB.instantiate("Terrain3D")
		t.name = "Terrain3D"
		root.add_child(t)
		t.owner = root
	return t


func _ensure_regions(terrain, size_m: int) -> bool:
	# Terrain3D writes height into regions; set_height fails with "No active
	# region found" until regions exist. Add a grid of blank regions covering
	# the requested area (centered on origin). Returns true if regions exist.
	if terrain.data == null:
		return false
	var data = terrain.data
	var region_size: int = terrain.get_region_size() if terrain.has_method("get_region_size") else 1024
	if region_size <= 0:
		region_size = 1024
	# If regions already exist, assume coverage (v1: don't manage partial edits).
	if "region_locations" in data and data.region_locations.size() > 0:
		return true
	var half := size_m / 2.0
	# Region grid indices covering [-half, half] in world meters.
	var rmin := int(floor(-half / float(region_size)))
	var rmax := int(floor(half / float(region_size)))
	var added := 0
	for rx in range(rmin, rmax + 1):
		for rz in range(rmin, rmax + 1):
			if data.has_method("add_region_blank"):
				data.add_region_blank(Vector2i(rx, rz), false)
				added += 1
	if data.has_method("update_maps"):
		data.update_maps()
	print("[HermesForge] terrain: added %d blank regions (size %d)" % [added, region_size])
	return added > 0


func _terrain_generate(args: Dictionary) -> Dictionary:
	var recipe := str(args.get("recipe", "rolling_hills"))
	var size_m := int(args.get("size_m", 512))
	var seed := int(args.get("seed", 0))
	var amplitude := float(args.get("amplitude", 30.0))
	var frequency := float(args.get("frequency", 0.004))
	var terrain := _get_or_create_terrain()
	if terrain == null:
		return _err("Terrain3D class not available (module not loaded)")
	# Terrain3D initializes its (read-only) `data` in _ready(), which Godot
	# calls synchronously on add_child() when added to an active tree. If data
	# is still null here the node isn't properly in the tree.
	if terrain.data == null:
		return _err("Terrain3D.data is null (node not ready; ensure it is in the active scene tree)")
	if not _ensure_regions(terrain, size_m):
		return _err("could not create terrain regions")

	# Recipe presets tune the noise field.
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	match recipe:
		"rolling_hills":
			noise.frequency = frequency
			noise.fractal_octaves = 4
		"mountain_range":
			noise.frequency = frequency * 0.7
			noise.fractal_octaves = 6
			noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
			amplitude = amplitude * 2.0
		"island":
			noise.frequency = frequency * 1.2
			noise.fractal_octaves = 5
		_:
			noise.frequency = frequency
			noise.fractal_octaves = 4

	# Lay heights on a coarse grid centered on origin.
	var half := size_m / 2.0
	var count := 0
	var data = terrain.data
	for x in range(-int(half), int(half), STEP_M):
		for z in range(-int(half), int(half), STEP_M):
			var h := noise.get_noise_2d(float(x), float(z)) * amplitude
			if recipe == "island":
				var d := Vector2(x, z).length() / half  # 0 center -> 1 edge
				h *= clamp(1.0 - d * d, 0.0, 1.0)
			data.set_height(Vector3(x, 0, z), h)
			count += 1
	data.update_maps()
	# Recalculate the cached height range so terrain.info / verification report
	# real values (get_height_range() is a stale cache until recalculated).
	if data.has_method("calc_height_range"):
		data.calc_height_range(true)
	return _ok({
		"recipe": recipe, "size_m": size_m, "seed": seed,
		"points_set": count, "amplitude": amplitude,
	})


func _terrain_sculpt(args: Dictionary) -> Dictionary:
	var center := _to_vec3(args.get("center", [0, 0, 0]))
	var radius := float(args.get("radius", 32.0))
	var strength := float(args.get("strength", 5.0))
	var terrain := _get_or_create_terrain()
	if terrain == null:
		return _err("Terrain3D not available")
	if not _ensure_regions(terrain, int(radius * 2) + 64):
		return _err("could not create terrain regions")
	var data = terrain.data
	var count := 0
	for x in range(int(center.x - radius), int(center.x + radius), STEP_M):
		for z in range(int(center.z - radius), int(center.z + radius), STEP_M):
			var d := Vector2(x - center.x, z - center.z).length()
			if d <= radius:
				var fall := 1.0 - (d / radius)
				var cur: float = data.get_height(Vector3(x, 0, z))
				data.set_height(Vector3(x, 0, z), cur + strength * fall)
				count += 1
	data.update_maps()
	return _ok({"sculpted_points": count, "center": [center.x, center.y, center.z]})


func _terrain_info() -> Dictionary:
	var root := _editor_root()
	var t := _find_node_by_name(root, "Terrain3D") if root else null
	if t == null:
		return _ok({"present": false})
	var info := {"present": true, "region_size": t.get_region_size() if t.has_method("get_region_size") else -1}
	if t.data != null:
		info["regions"] = t.data.region_locations.size() if "region_locations" in t.data else -1
		if t.data.has_method("get_height_range"):
			var r: Vector2 = t.data.get_height_range()
			info["height_range"] = [r.x, r.y]
	return _ok(info)

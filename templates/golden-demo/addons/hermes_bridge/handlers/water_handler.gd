extends "res://addons/hermes_bridge/handlers/base_handler.gd"
## Water ops v2: shader-driven surface (Gerstner waves) + a HermesWaterBody
## that floats RigidBody3Ds. Recipes set surface params. Phase 2 adds
## water.float_on_water for buoyancy registration + water.ripple for ripples.

const WATER_SHADER := "res://addons/hermes_bridge/shaders/water_surface.gdshader"
const WATER_BODY := "res://addons/hermes_bridge/scripts/water_body.gd"

const RECIPES := {
	"lake":        {"wave_height": 0.22, "wave_scale": 0.6, "wave_speed": 0.9, "shallow": Color(0.10, 0.35, 0.40, 0.55), "deep": Color(0.03, 0.16, 0.28, 0.90)},
	"pond":        {"wave_height": 0.08, "wave_scale": 0.9, "wave_speed": 0.6, "shallow": Color(0.12, 0.34, 0.30, 0.50), "deep": Color(0.04, 0.18, 0.16, 0.88)},
	"ocean":       {"wave_height": 0.65, "wave_scale": 0.35, "wave_speed": 1.3, "shallow": Color(0.05, 0.28, 0.42, 0.62), "deep": Color(0.01, 0.10, 0.22, 0.94)},
	"river_spline":{"wave_height": 0.15, "wave_scale": 1.2, "wave_speed": 1.8, "shallow": Color(0.10, 0.32, 0.36, 0.52), "deep": Color(0.04, 0.18, 0.24, 0.88)},
	"calm_pool":   {"wave_height": 0.03, "wave_scale": 0.8, "wave_speed": 0.4, "shallow": Color(0.10, 0.30, 0.34, 0.45), "deep": Color(0.03, 0.15, 0.20, 0.85)},
}


func get_ops() -> Array:
	return ["water.create", "water.remove", "water.float_on_water", "water.list"]


func call_op(op: String, args: Dictionary) -> Dictionary:
	match op:
		"water.create":
			return _water_create(args)
		"water.remove":
			return _water_remove(args)
		"water.float_on_water":
			return _water_float(args)
		"water.list":
			return _water_list()
	return _err("unhandled op", {"op": op})


func _water_create(args: Dictionary) -> Dictionary:
	var root := _editor_root()
	if root == null:
		return _err("no scene open")
	var recipe := str(args.get("recipe", "lake"))
	if not RECIPES.has(recipe):
		return _err("unknown water recipe", {"recipes": RECIPES.keys()})
	var at := _to_vec3(args.get("at", [0, 0, 0]))
	var radius := float(args.get("radius", 48.0))
	var p: Dictionary = RECIPES[recipe]

	var existing := _find_node_by_name(root, "HermesWater")
	if existing:
		existing.queue_free()

	# Water body (holds params + buoyancy) with a MeshInstance3D surface child.
	var body: Node3D = load(WATER_BODY).new()
	body.name = "HermesWater"
	body.position = at
	body.wave_height = p["wave_height"]
	body.wave_scale = p["wave_scale"]
	body.wave_speed = p["wave_speed"]

	var surf := MeshInstance3D.new()
	surf.name = "Surface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	surf.mesh = plane

	var mat := ShaderMaterial.new()
	var shader: Shader = load(WATER_SHADER)
	if shader == null:
		return _err("water shader failed to load", {"path": WATER_SHADER})
	mat.shader = shader
	mat.set_shader_parameter("shallow_color", p["shallow"])
	mat.set_shader_parameter("deep_color", p["deep"])
	mat.set_shader_parameter("wave_height", p["wave_height"])
	mat.set_shader_parameter("wave_scale", p["wave_scale"])
	mat.set_shader_parameter("wave_speed", p["wave_speed"])
	surf.material_override = mat

	body.add_child(surf)
	root.add_child(body)
	body.owner = root
	surf.owner = root
	return _ok({
		"recipe": recipe, "at": [at.x, at.y, at.z], "radius": radius,
		"node": "HermesWater", "wave_height": p["wave_height"],
	})


func _water_remove(_args: Dictionary) -> Dictionary:
	var root := _editor_root()
	var w := _find_node_by_name(root, "HermesWater") if root else null
	if w == null:
		return _err("no HermesWater node present")
	w.queue_free()
	return _ok({"removed": true})


func _water_float(args: Dictionary) -> Dictionary:
	# Register a named RigidBody3D to float on the water.
	var root := _editor_root()
	var body := _find_node_by_name(root, "HermesWater") if root else null
	if body == null:
		return _err("no HermesWater present — create water first")
	var target_name := str(args.get("node", ""))
	if target_name == "":
		return _err("missing 'node' (name of a RigidBody3D to float)")
	var target := _find_node_by_name(root, target_name)
	if target == null:
		return _err("node not found", {"node": target_name})
	if not (target is RigidBody3D):
		return _err("node is not a RigidBody3D", {"node": target_name, "type": target.get_class()})
	body.register_floater(target)
	return _ok({"floating": target_name, "on": "HermesWater"})


func _water_list() -> Dictionary:
	var root := _editor_root()
	var w := _find_node_by_name(root, "HermesWater") if root else null
	if w == null:
		return _ok({"present": false})
	return _ok({
		"present": true, "position": [w.position.x, w.position.y, w.position.z],
		"wave_height": w.wave_height, "wave_scale": w.wave_scale,
		"recipes": RECIPES.keys(),
	})

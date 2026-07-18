extends "res://addons/hermes_bridge/handlers/base_handler.gd"
## Sky/atmosphere ops: set a time-of-day / weather preset via WorldEnvironment
## + a DirectionalLight3D sun. Recipes: golden_hour, midday, overcast_storm,
## clear_night.


func get_ops() -> Array:
	return ["sky.set"]


func call_op(op: String, args: Dictionary) -> Dictionary:
	match op:
		"sky.set":
			return _sky_set(args)
	return _err("unhandled op", {"op": op})


const PRESETS := {
	"golden_hour": {
		"sun_energy": 1.2, "sun_color": Color(1.0, 0.72, 0.45),
		"sun_rotation": Vector3(-25, -35, 0),
		"sky_energy": 0.9, "ambient": 0.35, "fog": 0.0,
		"bg_color": Color(0.98, 0.62, 0.38),
	},
	"midday": {
		"sun_energy": 1.4, "sun_color": Color(1.0, 0.98, 0.92),
		"sun_rotation": Vector3(-70, 0, 0),
		"sky_energy": 1.2, "ambient": 0.5, "fog": 0.0,
		"bg_color": Color(0.45, 0.65, 0.95),
	},
	"overcast_storm": {
		"sun_energy": 0.4, "sun_color": Color(0.7, 0.75, 0.8),
		"sun_rotation": Vector3(-60, 20, 0),
		"sky_energy": 0.4, "ambient": 0.25, "fog": 0.35,
		"bg_color": Color(0.32, 0.36, 0.42),
	},
	"clear_night": {
		"sun_energy": 0.08, "sun_color": Color(0.6, 0.7, 1.0),
		"sun_rotation": Vector3(-50, 100, 0),
		"sky_energy": 0.05, "ambient": 0.08, "fog": 0.0,
		"bg_color": Color(0.02, 0.03, 0.08),
	},
}


func _sky_set(args: Dictionary) -> Dictionary:
	var root := _editor_root()
	if root == null:
		return _err("no scene open")
	var recipe := str(args.get("recipe", "midday"))
	if not PRESETS.has(recipe):
		return _err("unknown sky recipe", {"recipes": PRESETS.keys()})
	var p: Dictionary = PRESETS[recipe]

	# WorldEnvironment
	var env_node := _find_node_by_name(root, "WorldEnvironment")
	if env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		root.add_child(env_node)
		env_node.owner = root
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = p["bg_color"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p["bg_color"].lerp(Color.WHITE, 0.4)
	env.ambient_light_energy = p["ambient"]
	if p["fog"] > 0.0:
		env.fog_enabled = true
		env.fog_density = p["fog"] * 0.1
		env.fog_light_color = p["bg_color"]
	env_node.environment = env

	# Sun
	var sun := _find_node_by_name(root, "Sun")
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "Sun"
		root.add_child(sun)
		sun.owner = root
	sun.light_energy = p["sun_energy"]
	sun.light_color = p["sun_color"]
	sun.rotation_degrees = p["sun_rotation"]
	sun.shadow_enabled = true

	return _ok({"recipe": recipe, "sky_energy": p["sky_energy"], "fog": p["fog"]})

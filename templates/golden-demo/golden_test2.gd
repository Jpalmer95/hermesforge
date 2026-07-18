extends SceneTree
## Golden test v2 (Phase 2): the canonical Phase 2 scene, driven through the
## real bridge socket and verified structurally + a buoyancy sim step.
##
##   "a lake with floating crates, a pine shoreline, and a vehicle on terrain"
##
## Asserts:
##   - terrain generated (rolling hills)
##   - HermesWater created with Gerstner params
##   - 3 crates registered to float (buoyancy), and they rise toward surface
##   - pine foliage scattered (MultiMesh with instances)
##   - vehicle rig present with 4 wheels
##   - physics.audit reports zero missing-collision issues
## Exit 0 = all pass.

const PORT := 8794

var _server
var _root_node: Node3D
var _checks := 0
var _passed := 0


func _init() -> void:
	_root_node = Node3D.new()
	_root_node.name = "GoldenDemo"
	root.add_child(_root_node)
	var cam := Camera3D.new()
	cam.current = true
	cam.position = Vector3(0, 60, 120)
	_root_node.add_child(cam)
	var ServerScript = load("res://addons/hermes_bridge/bridge_server.gd")
	_server = ServerScript.new()
	_server.setup(null, _root_node, PORT)
	call_deferred("_go")


func _go() -> void:
	_server.listen()
	await create_timer(0.1).timeout
	_server.pump()

	# Build the scene via ops.
	var tg := await _call("terrain.generate", {"recipe": "rolling_hills", "size_m": 512, "seed": 21})
	_check("terrain.generate ok", tg.get("ok") == true)
	var wc := await _call("water.create", {"recipe": "lake", "at": [0, 0.5, 0], "radius": 60})
	_check("water.create ok", wc.get("ok") == true)

	# Floating crates.
	for i in range(3):
		var tb := await _call("physics.add_test_body", {
			"name": "Crate%d" % i, "shape": "box", "mass": 0.5,
			"at": [i * 3 - 3, -1.0, 5]})
		_check("crate %d added" % i, tb.get("ok") == true)
		var fl := await _call("water.float_on_water", {"node": "Crate%d" % i})
		_check("crate %d registered to float" % i, fl.get("ok") == true)

	# Pine shoreline.
	var sc := await _call("foliage.scatter", {
		"recipe": "pine", "count": 60, "area_m": 200, "seed": 7, "min_spacing": 5.0})
	_check("foliage.scatter ok", sc.get("ok") == true)
	_check("pines placed", sc.get("placed", 0) >= 30)

	# Vehicle.
	var vh := await _call("physics.vehicle", {"recipe": "vehicle_arcade", "at": [0, 3, -20]})
	_check("physics.vehicle ok", vh.get("ok") == true)

	# Physics audit.
	var audit := await _call("physics.audit", {})
	_check("physics.audit ok", audit.get("ok") == true)
	_check("no missing-collision issues", audit.get("issue_count", 99) == 0)

	# Structural verification.
	var water := _find(_root_node, "HermesWater")
	_check("HermesWater present w/ waves", water != null and water.wave_height > 0.0)
	var pines := _find(_root_node, "Foliage_pine")
	_check("Foliage_pine MultiMesh present", pines != null and pines is MultiMeshInstance3D)
	if pines:
		_check("pine instances > 0", pines.multimesh.instance_count > 0)
	var vehicle := _find(_root_node, "HermesVehicle")
	_check("HermesVehicle present", vehicle != null and vehicle is VehicleBody3D)
	if vehicle:
		var wheels := 0
		for c in vehicle.get_children():
			if c is VehicleWheel3D:
				wheels += 1
		_check("vehicle has 4 wheels", wheels == 4)

	# Buoyancy sim: run physics frames, crates should rise toward surface.
	var crate := _find(_root_node, "Crate0")
	if crate and water:
		var start_y: float = crate.global_position.y
		for i in range(120):  # ~2s at 60fps
			_server.pump()
			await physics_frame
		var end_y: float = crate.global_position.y
		var surface: float = water.get_wave_height_at(crate.global_position)
		print("[golden] crate0 start_y=%.2f end_y=%.2f surface=%.2f" % [start_y, end_y, surface])
		_check("crate0 floated upward", end_y > start_y)
	else:
		_check("crate0 present for buoyancy sim", false)

	print("\n[golden2] RESULT: %d/%d checks passed" % [_passed, _checks])
	_server.stop()
	quit(0 if _passed == _checks else 1)


func _check(label: String, cond: bool) -> void:
	_checks += 1
	if cond:
		_passed += 1
		print("[golden2] PASS: ", label)
	else:
		print("[golden2] FAIL: ", label)


func _find(root: Node, name: String) -> Node:
	if root == null:
		return null
	if root.name == name:
		return root
	for c in root.get_children():
		var f := _find(c, name)
		if f:
			return f
	return null


func _call(op: String, args: Dictionary) -> Dictionary:
	var body := await _rt(HTTPClient.METHOD_POST, "/call", JSON.stringify({"op": op, "args": args}))
	var parsed = JSON.parse_string(body)
	return parsed if parsed is Dictionary else {"ok": false, "error": "bad json: " + body.substr(0, 120)}


func _rt(method: int, path: String, body: String) -> String:
	var http := HTTPClient.new()
	http.connect_to_host("127.0.0.1", PORT)
	var guard := 0
	while http.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING] and guard < 500:
		http.poll(); _server.pump(); guard += 1
		await create_timer(0.005).timeout
	var headers := ["Content-Type: application/json"] if method == HTTPClient.METHOD_POST else []
	http.request(method, path, headers, body)
	guard = 0
	while http.get_status() == HTTPClient.STATUS_REQUESTING and guard < 500:
		http.poll(); _server.pump(); guard += 1
		await create_timer(0.005).timeout
	var resp := PackedByteArray()
	guard = 0
	while http.get_status() == HTTPClient.STATUS_BODY and guard < 3000:
		http.poll(); _server.pump()
		var chunk := http.read_response_body_chunk()
		if chunk.size() == 0:
			await create_timer(0.005).timeout
			guard += 1
		else:
			resp.append_array(chunk)
	return resp.get_string_from_utf8()

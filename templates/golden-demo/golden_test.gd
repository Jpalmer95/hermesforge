extends SceneTree
## Golden test (Phase 1): the canonical HermesForge intent, driven end-to-end
## through the real bridge HTTP socket, verified structurally.
##
##   "create rolling hills terrain 512m, add a lake, set golden hour"
##
## Asserts after the ops:
##   - a Terrain3D node exists with regions + a real height range
##   - a HermesWater node exists (the lake)
##   - a WorldEnvironment + Sun exist (golden hour)
## Exit 0 = pass, 1 = fail. Run: godot --headless --path . --script golden_test.gd

const PORT := 8793

var _server
var _root_node: Node3D
var _checks := 0
var _passed := 0


func _init() -> void:
	_root_node = Node3D.new()
	_root_node.name = "GoldenDemo"
	root.add_child(_root_node)
	var ServerScript = load("res://addons/hermes_bridge/bridge_server.gd")
	_server = ServerScript.new()
	_server.setup(null, _root_node, PORT)
	call_deferred("_go")


func _go() -> void:
	_server.listen()
	await create_timer(0.1).timeout
	_server.pump()

	# 1. rolling hills terrain, 512m
	var tg := await _call("terrain.generate", {"recipe": "rolling_hills", "size_m": 512, "seed": 11})
	_check("terrain.generate ok", tg.get("ok") == true)

	# 2. add a lake
	var wc := await _call("water.create", {"recipe": "lake", "at": [0, -1.5, 0], "radius": 56})
	_check("water.create ok", wc.get("ok") == true)

	# 3. set golden hour
	var sk := await _call("sky.set", {"recipe": "golden_hour"})
	_check("sky.set ok", sk.get("ok") == true)

	# --- verify the resulting scene ---
	var terrain := _find(_root_node, "Terrain3D")
	_check("Terrain3D node present", terrain != null)
	if terrain and terrain.data:
		_check("terrain has regions", terrain.data.region_locations.size() > 0)
		var hr: Vector2 = terrain.data.get_height_range()
		_check("terrain has real height variation", (hr.y - hr.x) > 0.5)
	_check("HermesWater present", _find(_root_node, "HermesWater") != null)
	_check("WorldEnvironment present", _find(_root_node, "WorldEnvironment") != null)
	_check("Sun present", _find(_root_node, "Sun") != null)

	print("\n[golden] RESULT: %d/%d checks passed" % [_passed, _checks])
	_server.stop()
	quit(0 if _passed == _checks else 1)


func _check(label: String, cond: bool) -> void:
	_checks += 1
	if cond:
		_passed += 1
		print("[golden] PASS: ", label)
	else:
		print("[golden] FAIL: ", label)


func _find(root: Node, name: String) -> Node:
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

extends RefCounted
class_name HermesBridgeServer
## HermesForge bridge — network + dispatch core (editor-independent).
##
## Owns the loopback TCP socket, minimal HTTP/1.1 parsing, and command
## dispatch to the domain handlers. The EditorPlugin (hermes_bridge.gd) wraps
## this; headless tests drive it directly with a test_root injected.
##
## Trust boundary: binds 127.0.0.1 ONLY. Never expose beyond loopback.

const BIND := "127.0.0.1"

var port := 8787
var test_root: Node = null     # headless/test override for the scene root
var _editor_plugin = null       # set when running inside the editor plugin

var _server := TCPServer.new()
var _clients: Array = []
var _buffers := {}
var _handlers := {}


func setup(editor_plugin = null, root_override: Node = null, bind_port: int = 8787) -> void:
	_editor_plugin = editor_plugin
	test_root = root_override
	port = bind_port
	_register_handlers()


func listen() -> int:
	var err := _server.listen(port, BIND)
	if err == OK:
		print("[HermesForge] bridge listening on http://%s:%d" % [BIND, port])
	else:
		push_error("[HermesForge] failed to bind %s:%d (err %d)" % [BIND, port, err])
	return err


func stop() -> void:
	for c in _clients:
		c.disconnect_from_host()
	_clients.clear()
	_buffers.clear()
	if _server.is_listening():
		_server.stop()


func pump() -> void:
	# Drive one network tick (accept + read + dispatch). EditorPlugin calls this
	# from _process; tests call it manually.
	while _server.is_listening() and _server.is_connection_available():
		var conn := _server.take_connection()
		_clients.append(conn)
		_buffers[conn] = PackedByteArray()
	for conn in _clients.duplicate():
		if not is_instance_valid(conn) or conn.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_drop_client(conn)
			continue
		var avail: int = conn.get_available_bytes()
		if avail > 0:
			var chunk: Array = conn.get_data(avail)
			if chunk[0] == OK:
				_buffers[conn].append_array(chunk[1])
				_try_consume_request(conn)


func _drop_client(conn) -> void:
	_clients.erase(conn)
	_buffers.erase(conn)


# --- Minimal HTTP/1.1 parsing ---

func _try_consume_request(conn) -> void:
	var buf: PackedByteArray = _buffers[conn]
	var header_end := _find_header_end(buf)
	if header_end == -1:
		return
	var head := buf.slice(0, header_end).get_string_from_utf8()
	var lines := head.split("\r\n")
	if lines.is_empty():
		_respond(conn, 400, {"error": "bad request"})
		_consume(conn, buf.size())
		return
	var request_line := lines[0].split(" ")
	var method: String = request_line[0] if request_line.size() > 0 else ""
	var path: String = request_line[1] if request_line.size() > 1 else "/"
	var content_length := 0
	for i in range(1, lines.size()):
		var l := lines[i]
		if l.to_lower().begins_with("content-length:"):
			content_length = l.split(":", true, 1)[1].strip_edges().to_int()
	var body_start := header_end + 4
	if buf.size() < body_start + content_length:
		return
	var body := buf.slice(body_start, body_start + content_length).get_string_from_utf8()
	_consume(conn, body_start + content_length)
	_route(conn, method, path, body)


func _find_header_end(buf: PackedByteArray) -> int:
	for i in range(0, buf.size() - 3):
		if buf[i] == 13 and buf[i+1] == 10 and buf[i+2] == 13 and buf[i+3] == 10:
			return i
	return -1


func _consume(conn, n: int) -> void:
	_buffers[conn] = _buffers[conn].slice(n)


func _route(conn, method: String, path: String, body: String) -> void:
	if path == "/health":
		_respond(conn, 200, _health_payload())
		return
	if path == "/call" and method == "POST":
		var parsed = JSON.parse_string(body)
		if parsed == null or not (parsed is Dictionary):
			_respond(conn, 400, {"ok": false, "error": "invalid JSON body"})
			return
		var op: String = str(parsed.get("op", ""))
		var args = parsed.get("args", {})
		_respond(conn, 200, dispatch(op, args if args is Dictionary else {}))
		return
	_respond(conn, 404, {"ok": false, "error": "not found: %s %s" % [method, path]})


func _respond(conn, status: int, payload: Dictionary) -> void:
	payload["project"] = ProjectSettings.globalize_path("res://")
	payload["godot"] = Engine.get_version_info().get("string", "?")
	payload["ready"] = is_ready()
	var body := JSON.stringify(payload)
	var reason := {200: "OK", 400: "Bad Request", 404: "Not Found", 500: "Server Error"}.get(status, "OK")
	var resp := "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [status, reason, body.to_utf8_buffer().size(), body]
	conn.put_data(resp.to_utf8_buffer())
	conn.disconnect_from_host()
	_drop_client(conn)


# --- Readiness + active root (test_root wins, else editor scene) ---

func is_ready() -> bool:
	return _active_root() != null


func _active_root() -> Node:
	if test_root != null:
		return test_root
	if _editor_plugin != null:
		var tree = _editor_plugin.get_tree()
		if tree and "edited_scene_root" in tree:
			return tree.edited_scene_root
	return null


func _health_payload() -> Dictionary:
	return {
		"ok": true,
		"service": "hermesforge-bridge",
		"version": "0.1.0",
		"ops": _handlers.keys(),
	}


# --- Dispatch ---

func _register_handlers() -> void:
	var base := "res://addons/hermes_bridge/handlers/"
	for fname in ["scene_handler.gd", "terrain_handler.gd", "water_handler.gd", "sky_handler.gd", "physics_handler.gd", "foliage_handler.gd"]:
		var h = load(base + fname).new()
		h.setup(self)
		for op in h.get_ops():
			_handlers[op] = h


func dispatch(op: String, args: Dictionary) -> Dictionary:
	if not _handlers.has(op):
		return {"ok": false, "error": "unknown op: %s" % op, "ops": _handlers.keys()}
	if not is_ready() and not op.begins_with("project."):
		return {"ok": false, "error": "editor not ready (no scene open)", "op": op}
	var result = _handlers[op].call_op(op, args)
	if result == null:
		result = {"ok": false, "error": "handler returned null", "op": op}
	result["op"] = op
	return result


# Editor-interface access for handlers that need it (screenshot, save).
func get_editor_interface():
	if _editor_plugin != null:
		return _editor_plugin.get_editor_interface()
	return null

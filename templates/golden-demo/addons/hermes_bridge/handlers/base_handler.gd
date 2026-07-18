extends RefCounted
## Base class for HermesForge bridge command handlers.
## `_plugin` is the HermesBridgeServer (exposes _active_root, get_editor_interface).

var _plugin


func setup(server) -> void:
	_plugin = server


## Override: return the op ids this handler serves (e.g. ["scene.get_tree"]).
func get_ops() -> Array:
	return []


## Override: dispatch one op. Must return a Dictionary (JSON-serializable).
func call_op(_op: String, _args: Dictionary) -> Dictionary:
	return {"ok": false, "error": "not implemented"}


# --- shared helpers ---

func _editor_root() -> Node:
	if _plugin == null:
		return null
	if _plugin.has_method("_active_root"):
		return _plugin._active_root()
	return null


func _editor_interface():
	if _plugin and _plugin.has_method("get_editor_interface"):
		return _plugin.get_editor_interface()
	return null


func _ok(extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": true}
	d.merge(extra)
	return d


func _err(msg: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": false, "error": msg}
	d.merge(extra)
	return d


func _to_vec3(v, default := Vector3.ZERO) -> Vector3:
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	if v is Vector3:
		return v
	return default


func _find_node_by_name(root: Node, name: String) -> Node:
	if root == null:
		return null
	if root.name == name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, name)
		if found != null:
			return found
	return null

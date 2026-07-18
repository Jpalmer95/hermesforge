@tool
extends EditorPlugin
## HermesForge Bridge — editor plugin (thin wrapper).
##
## Owns the HermesBridgeServer (network + dispatch core) and pumps it from the
## editor's process loop. All real logic lives in bridge_server.gd so it can be
## tested headless without the editor. Binds 127.0.0.1:8787 ONLY.

const PORT := 8787

var _server  # HermesBridgeServer


func _enter_tree() -> void:
	var ServerScript = preload("res://addons/hermes_bridge/bridge_server.gd")
	_server = ServerScript.new()
	_server.setup(self, null, PORT)
	var err: int = _server.listen()
	if err != OK:
		push_error("[HermesForge] bridge not started (port busy?)")


func _exit_tree() -> void:
	if _server:
		_server.stop()
		_server = null
	print("[HermesForge] bridge stopped")


func _process(_delta: float) -> void:
	if _server:
		_server.pump()

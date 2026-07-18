extends Node3D
class_name HermesWaterBody
## Water body with buoyancy. Holds the surface params and floats registered
## RigidBody3Ds via spring forces toward the wave height. The wave math here
## mirrors water_surface.gdshader so visuals and physics agree (approx).

signal body_entered_water(body)

@export var wave_height := 0.25
@export var wave_scale := 0.6
@export var wave_speed := 1.0
@export var buoyancy := 9.8        # upward spring strength
@export var water_drag := 0.6      # velocity damping while submerged
@export var float_offset := 0.5    # how deep the body sits before full buoyancy

var _floaters: Array = []          # Array[RigidBody3D]
var _time := 0.0


func _physics_process(delta: float) -> void:
	_time += delta
	for body in _floaters.duplicate():
		if not is_instance_valid(body):
			_floaters.erase(body)
			continue
		_apply_buoyancy(body, delta)


func register_floater(body: RigidBody3D) -> void:
	if body and not _floaters.has(body):
		_floaters.append(body)
		emit_signal("body_entered_water", body)


func unregister_floater(body: RigidBody3D) -> void:
	_floaters.erase(body)


func get_wave_height_at(world_pos: Vector3) -> float:
	# Must roughly match the vertex displacement in water_surface.gdshader.
	var p := Vector2(world_pos.x, world_pos.z) * wave_scale
	var t := _time * wave_speed
	var h := 0.0
	h += sin(p.dot(Vector2(1.0, 0.3).normalized()) * 1.0 + t) * 0.5
	h += sin(p.dot(Vector2(-0.7, 1.0).normalized()) * 1.7 + t * 1.3) * 0.3
	h += sin(p.dot(Vector2(0.4, -1.0).normalized()) * 2.6 + t * 1.7) * 0.2
	return global_position.y + h * wave_height


func _apply_buoyancy(body: RigidBody3D, delta: float) -> void:
	var surface_y: float = get_wave_height_at(body.global_position)
	var depth: float = surface_y - body.global_position.y + float_offset
	if depth > 0.0:
		# Submerged (at least partially): spring up, damp velocity.
		var force: Vector3 = Vector3.UP * buoyancy * clamp(depth, 0.0, 2.0) * body.mass
		body.apply_central_force(force)
		body.linear_velocity = body.linear_velocity.lerp(
			body.linear_velocity * (1.0 - water_drag), delta * 8.0)

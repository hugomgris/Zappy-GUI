extends Area3D

@export var float_height: float = 0.08
@export var float_speed: float = 1.2
@export var animation_fps: float = 12.0
@export var scale_quantity_factor: float = 0.1

var _anim_accum: float = 0.0

var _origin: Vector3
var _time: float

func _read() -> void:
	_origin = position
	_time = randf() * TAU # de-sync rando

func _process(delta: float) -> void:
	_anim_accum += delta
	var anim_step := 1.0 / animation_fps
	if _anim_accum >= anim_step:
		_anim_accum = fmod(_anim_accum, anim_step)
		_time += anim_step * float_speed
		position = _origin + Vector3(0.0, sin(_time) * float_height, 0.0)

func transform_by_quantity(quantity: float) -> void:
	scale = Vector3.ONE * (quantity * scale_quantity_factor + 1.0)
	_origin.y = 0.0 + quantity * 0.01

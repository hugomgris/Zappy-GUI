extends Node3D

@onready var _pitch: Node3D = %Pitch
@onready var _zoom_arm: Node3D = %ZoomArm
@onready var _camera: Camera3D = %Camera

@export var move_speed: float = 8.0
@export var zoom_speed: float = 2.0
@export var lerp_speed: float = 12.0
@export var pitch_angle_deg: float = 30.0
@export var initial_yaw_deg: float = 45.0

var _pos_target: Vector3 = Vector3.ZERO
var _size_target: float = 10.0
var _yaw_target: float = 0.0
var _bounds: Rect2 = Rect2()
var _initialized: bool = false

func _ready() -> void:
	_pitch.rotation_degrees.x = -pitch_angle_deg
	rotation_degrees.y = initial_yaw_deg
	_yaw_target = PI * 0.25
	rotation.y = _yaw_target
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	
func initialize_for_map(size: Vector2i) -> void:
	var spacing: float = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
	var center := Vector3((size.x - 1) * spacing * 0.5, 0.0,
							(size.y - 1) * spacing * 0.5)
							
	var span: float = max(size.x, size.y) * spacing
							
	position = center
	_pos_target = center
	_size_target = span * 0.7
	_camera.size = _size_target
	
	var pad: float = span * 0.5
	_bounds = Rect2(center.x - span - pad, center.z - span - pad,
					span * 2.0 + pad * 2.0, span * 2.0 + pad * 2.0)
					
	_initialized = true

func _process(delta: float) -> void:
	if not _initialized:
		return
	_handle_keyboard(delta)
	_apply_lerp(delta)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_size_target = max(2.0, _size_target - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_size_target = min(60.0, _size_target + zoom_speed)
			
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		var drag: Vector2 = event.relative * 0.02
		_pos_target += Vector3(-drag.x, 0.0, -drag.y).rotated(Vector3.UP, rotation.y)

func _handle_keyboard(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		var world_dir := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, rotation.y)
		_pos_target += world_dir * move_speed * delta
		
	if Input.is_action_just_pressed("rotate_left"):
		_yaw_target -= PI * 0.5
	if Input.is_action_just_pressed("rotate_right"):
		_yaw_target += PI * 0.5
	
	_yaw_target = wrapf(_yaw_target, -PI, PI)

func _apply_lerp(delta: float) -> void:
	var t: float = clamp(lerp_speed * delta, 0.0, 1.0)
	
	_pos_target.x = clamp(_pos_target.x, _bounds.position.x,
						_bounds.position.x + _bounds.size.x)
	_pos_target.z = clamp(_pos_target.z, _bounds.position.y,
						_bounds.position.y + _bounds.size.y)
						
	print(_pos_target, "-", _camera.position)
	position = position.lerp(_pos_target, t)
	rotation.y = lerp_angle(rotation.y, _yaw_target, t)
	_camera.size = lerpf(_camera.size, _size_target, t)
	print("yaw: ", rotation_degrees.y, " target: ", rad_to_deg(_yaw_target))
	
func focus_on(world_pos: Vector3) -> void:
	_pos_target = Vector3(world_pos.x, 0.0, world_pos.z)

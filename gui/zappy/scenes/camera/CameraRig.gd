# Axonometric camera manager (set up + controller)
extends Node3D

@onready var _pitch: Node3D = %Pitch
@onready var _zoom_arm: Node3D = %ZoomArm
@onready var _camera: Camera3D = %Camera

@export var move_speed: float = 8.0
@export var zoom_speed: float = 2.0
@export var lerp_speed: float = 5.0
@export var pitch_angle_deg: float = 60.0
@export var initial_yaw_deg: float = 22.5
@export var margin_offset: float = 1.5

@export var animation_fps: float = 12.0

var _anim_accum: float = 0.0
var _initial_camera_size: float

var _pos_target: Vector3 = Vector3.ZERO
var _size_target: float = 10.0
var _yaw_target: float = 0.0
var _bounds: Rect2 = Rect2()
var _initialized: bool = false

var _grid_center: Vector3 = Vector3.ZERO

func _ready() -> void:
	_pitch.rotation_degrees.x = -pitch_angle_deg
	rotation_degrees.y = initial_yaw_deg
	_yaw_target = deg_to_rad(initial_yaw_deg)   # was: initial_yaw_deg (degrees — wrong!)
	rotation.y = _yaw_target
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	
func initialize_for_map(size: Vector2i) -> void:
	var spacing: float = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
	var grid_center := Vector3(
		(size.x - 1) * spacing * 0.5,
		0.0,
		(size.y - 1) * spacing * 0.5
	)
	var span: float = max(size.x, size.y) * spacing

	_size_target = span * margin_offset
	_camera.size = _size_target
	_initial_camera_size = _size_target
	_grid_center = grid_center

	# Set yaw first so _compute_recentering_correction uses the right angle
	rotation.y = deg_to_rad(initial_yaw_deg)
	_yaw_target = deg_to_rad(initial_yaw_deg)

	# Use the same analytical correction the rotation system uses
	_pos_target = _compute_recentering_correction(_yaw_target)
	position = _pos_target

	var pad := span * 0.5
	_bounds = Rect2(
		grid_center.x - span - pad,
		grid_center.z - span - pad,
		span * 2.0 + pad * 2.0,
		span * 2.0 + pad * 2.0
	)
	
	_camera.position.z = span * 2.0
	
	_initialized = true

func _process(delta: float) -> void:
	if not _initialized:
		return
	
	_handle_keyboard(delta)
	
	_anim_accum += delta
	var anim_step := 1.0 / animation_fps
	if _anim_accum >= anim_step:
		_anim_accum = fmod(_anim_accum, anim_step)
		_apply_lerp(anim_step)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_size_target = max(6.0, _size_target - zoom_speed)
			print(_size_target)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_size_target = min(_initial_camera_size, _size_target + zoom_speed)
			
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
		_yaw_target = wrapf(_yaw_target, -PI, PI)
		_pos_target = _compute_recentering_correction(_yaw_target)

	if Input.is_action_just_pressed("rotate_right"):
		_yaw_target += PI * 0.5
		_yaw_target = wrapf(_yaw_target, -PI, PI)
		_pos_target = _compute_recentering_correction(_yaw_target)

func _apply_lerp(delta: float) -> void:
	var t: float = clamp(lerp_speed * delta, 0.0, 1.0)
	
	_pos_target.x = clamp(_pos_target.x, _bounds.position.x,
						_bounds.position.x + _bounds.size.x)
	_pos_target.z = clamp(_pos_target.z, _bounds.position.y,
						_bounds.position.y + _bounds.size.y)
						
	position = position.lerp(_pos_target, t)
	rotation.y = lerp_angle(rotation.y, _yaw_target, t)
	_camera.size = lerpf(_camera.size, _size_target, t)

func _compute_recentering_correction(target_yaw: float) -> Vector3:
	var pitch_rad := deg_to_rad(-pitch_angle_deg)

	var cam_local := Vector3(0, 0, _camera.position.z)

	var after_pitch := Vector3(
		cam_local.x,
		cam_local.y * cos(pitch_rad) - cam_local.z * sin(pitch_rad),
		cam_local.y * sin(pitch_rad) + cam_local.z * cos(pitch_rad)
	)
	var total_local := _pitch.position + after_pitch

	var cam_offset := Vector3(
		total_local.x * cos(target_yaw) + total_local.z * sin(target_yaw),
		total_local.y,
		-total_local.x * sin(target_yaw) + total_local.z * cos(target_yaw)
	)

	var look := Vector3(
		-sin(target_yaw) * cos(pitch_rad),
		sin(pitch_rad),
		-cos(target_yaw) * cos(pitch_rad)
	)

	var future_cam_pos := _grid_center + cam_offset

	var t := -future_cam_pos.y / look.y
	var ground_hit := future_cam_pos + look * t

	var correction := _grid_center - ground_hit
	correction.y = 0.0

	return _grid_center + correction

func focus_on(world_pos: Vector3) -> void:
	_pos_target = Vector3(world_pos.x, 0.0, world_pos.z)

func _debug_camera_info(intended_center: Vector3) -> void:
	print("=== CAMERA DEBUG ===")
	print("Intended world center: ", intended_center)
	print("Rig (self) position: ", position)
	print("Rig (self) rotation_degrees: ", rotation_degrees)
	print("Pitch node position: ", _pitch.position)
	print("Pitch node rotation_degrees: ", _pitch.rotation_degrees)
	print("ZoomArm position: ", _zoom_arm.position)
	print("ZoomArm rotation_degrees: ", _zoom_arm.rotation_degrees)
	print("Camera local position: ", _camera.position)
	print("Camera global position: ", _camera.global_position)
	print("Camera global basis Z (forward): ", _camera.global_basis.z)
	print("====================")

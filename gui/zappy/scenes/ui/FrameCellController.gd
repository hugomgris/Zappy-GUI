class_name FrameCellController

extends Area2D

const CELL_SIZE: int = 135

const COLOR_A      = Color(0.0, 0.485, 0.0, 1.0)
const COLOR_B      = Color(0.0, 0.0, 0.485, 1.0)
const BORDER_COLOR = Color(0.854, 0.854, 0.854, 1.0)
const BORDER_WIDTH = 8.0

@onready var _positions: Node2D = $Positions
@onready var _animations: Node2D = $Animations
@onready var _collider: CollisionShape2D = $Collider
@onready var _odd_slider: Texture2D = preload("res://assets/textures/slider_grabber_horizontal_blue.png")

@export var is_number_cell: bool = false
@export var is_horizontal_controller: bool = false
@export var is_vertical_controller: bool = false
@export var odd: bool = true
@export var fixed_position: String = "mid_left"
@export var fixed_animation: String = "Cuby"
@export var number_sprites: Array[Texture2D] = []

var _leader_cell: Node2D = null
var _top_text: RichTextLabel = null
var _level_sprites: Dictionary = {}
var _leader_name: RichTextLabel = null
var _current_max_level: Sprite2D = null

var _selected_position: Node2D = null
var _selected_animation: AnimatedSprite2D = null
var _original_position: Vector2 = Vector2.ZERO

var _is_scaled: bool = false
var _scaled_position: Node2D = null

var _slider: HSlider = null
var _current_volume_step: int = 5
var _current_color_step: int = 0
var _current_time_step: int = 0

func _ready() -> void:
	MockServer.update_leader_status.connect(_on_leader_update)
	
	_original_position = position
	
	if is_number_cell:
		_leader_cell	 = get_node_or_null("Leader")
		_top_text = _leader_cell.get_node_or_null("top_text")
		_leader_name = _leader_cell.get_node_or_null("leader_name")
		
		if not _leader_cell:
			push_error("FrameCellController: number cell: couldn't find levels node")
			return
		elif not _top_text:
			push_error("FrameCellController: number cell: couldn't find top_text node")
			return
		elif not _leader_name:
			push_error("FrameCellController: number cell: couldn't find leader_name node")
			return
			
	pick_position()
	if is_number_cell:
		preload_number_sprites()
	else:
		pick_animation()
	set_outer_color()
	set_inner_color()
	set_up_sliders()
	
func on_mouse_entered() -> void:
	_positions.scale = Vector2(2.0, 2.0)
	if is_number_cell:
		_leader_cell.scale = Vector2(2.0, 2.0)
		_leader_cell.z_index = _leader_cell.z_index + 11
		_positions.z_index = _positions.z_index + 10
	else:
		_animations.scale = Vector2(2.0, 2.0)
		_animations.z_index = _animations.z_index + 21 if name == "Console" else _animations.z_index + 11
		_positions.z_index = _positions.z_index + 20 if name == "Console" else _positions.z_index + 10
		
	_move_to_scaled_position()
	_switch_to_scaled_layout()
	
	_collider.scale = Vector2(2.0, 2.0)
	
	if get_node_or_null("ConsoleLog"):
		ConsoleManager.console_hovered.emit()
	
func on_mouse_exited() -> void:
	_remove_scaled_layout()
	_positions.scale = Vector2(1.0, 1.0)
	if is_number_cell:
		_leader_cell.scale = Vector2(1.0, 1.0)
		_leader_cell.z_index = _leader_cell.z_index - 11
		_positions.z_index = _positions.z_index - 10
	else:
		_animations.scale = Vector2(1.0, 1.0)
		_animations.z_index = _animations.z_index - 21 if name == "Console" else _animations.z_index - 11	
		_positions.z_index = _positions.z_index - 20 if name == "Console" else _positions.z_index - 10
		
	position = _original_position
	
	_collider.scale = Vector2(1.0, 1.0)
	
	if get_node_or_null("ConsoleLog"):
		ConsoleManager.console_unhovered.emit()
		
func pick_position() -> void:
	for i in range (_positions.get_children().size()):
		var child: Node2D = _positions.get_child(i)
		child.visible = false
		
	var final_position = _positions.get_node_or_null(fixed_position)
	if final_position:
		final_position.visible = true
		_selected_position = final_position
	else:
		push_error("FrameCellController: couldn't find position node from string {%s}" % fixed_position)

func set_outer_color() -> void:
	var selected_outer: ColorRect = _selected_position.get_node_or_null("Outer")
	if selected_outer:
		selected_outer.color = BORDER_COLOR
	else:
		push_error("FrameCellController: failed to find target inner ColorRect node")

func set_inner_color() -> void:
	var selected_color: Color = Color.BLACK
	
	if odd:
		selected_color = COLOR_B
	else:
		selected_color = COLOR_A
		
	var selected_inner: ColorRect = _selected_position.get_node_or_null("Inner")
	if selected_inner:
		selected_inner.color = selected_color
	else:
		push_error("FrameCellController: failed to find target inner ColorRect node")
		
func set_scaled_inner_color() -> void:
	if not _is_scaled: return
	
	var selected_color: Color = Color.BLACK
	
	if odd:
		selected_color = COLOR_B
	else:
		selected_color = COLOR_A
		
	var selected_inner: ColorRect = _scaled_position.get_node_or_null("Inner")
	if selected_inner:
		selected_inner.color = selected_color
	else:
		push_error("FrameCellController: failed to find target inner ColorRect node")
		
func pick_animation() -> void:
	for i in range(_animations.get_children().size() - 1):
		var child: AnimatedSprite2D = _animations.get_child(i)
		child.visible = false
		
	var selected: AnimatedSprite2D = _animations.get_node_or_null(fixed_animation)
	if selected:
		selected.visible = true
		_selected_animation = selected
		return
	
	if fixed_animation != "NONE":
		push_error("FrameCellController: couldn't find animation node from string {%s}" % fixed_animation)

func preload_number_sprites() -> void:
	for i in range(8):
		_level_sprites[i + 1] = number_sprites[i]
		
	_current_max_level = _leader_cell.get_node_or_null("level")
	if not _current_max_level:
		push_error("FrameCellController: preload_number_sprite: failed to fetch level number sprite node")
	
	_current_max_level.texture = _level_sprites[1]
	_current_max_level.visible = true
	_top_text.visible = true
	_leader_name.visible = true
	
func _move_to_scaled_position() -> void:
	match _selected_position.name:
		"top_left":
			position.x = position.x + (CELL_SIZE / 2.0) + BORDER_WIDTH / 4
			position.y = position.y + (CELL_SIZE / 2.0) + BORDER_WIDTH / 4
		"top_right":
			position.x = position.x - (CELL_SIZE / 2.0) - BORDER_WIDTH / 2
			position.y = position.y + (CELL_SIZE / 2.0) + BORDER_WIDTH / 4
		"bot_right":
			position.x = position.x - (CELL_SIZE / 2.0) - CELL_SIZE
			position.y = position.y - (CELL_SIZE / 2.0) - BORDER_WIDTH / 4
		"bot_left":
			position.x = position.x + (CELL_SIZE / 2.0) + BORDER_WIDTH / 4
			position.y = position.y - (CELL_SIZE / 2.0) - BORDER_WIDTH / 4
		"mid_left":
			if _collider.shape.get_rect().size.y == 135.0:
				position.x = position.x + (CELL_SIZE / 2.0) + BORDER_WIDTH / 4
			else:
				position.x = position.x + (CELL_SIZE / 2.0) + BORDER_WIDTH / 2
				position.y = position.y - (CELL_SIZE / 2.0) + BORDER_WIDTH / 4
		"mid_top":
			position.y = position.y + (CELL_SIZE / 2.0) + BORDER_WIDTH / 4
		"mid_right":
			position.x = position.x - (CELL_SIZE / 2.0) - BORDER_WIDTH / 4
		"mid_bottom":
			position.y = position.y - (CELL_SIZE / 2.0) - BORDER_WIDTH / 4
		_:
			position.y = position.y - (CELL_SIZE / 2.0) + BORDER_WIDTH
		
func _switch_to_scaled_layout() -> void:
	var current_position_name = String(_selected_position.name)
	var current_position: Node2D = _positions.get_node_or_null(current_position_name)
	current_position.visible = false
	
	var scaled_position = _positions.get_node_or_null("scaled")
	scaled_position.visible = true
	
	_scaled_position = scaled_position
	_is_scaled = true
	set_scaled_inner_color()
	
	if _slider:
		_set_slider_to_hovered_position()

func _remove_scaled_layout() -> void:
	var current_position_name = String(_selected_position.name)
	var current_position: Node2D = _positions.get_node_or_null(current_position_name)
	current_position.visible = true
	
	_is_scaled = false
	_scaled_position = null
	var scale_position_node = _positions.get_node_or_null("scaled")
	scale_position_node.visible = false
	
	if _slider:
		_reset_slider_to_regular_position()

func set_up_sliders() -> void:
	if not is_horizontal_controller:
		return

	_slider = get_node_or_null("HorizontalSlider")
	if not _slider:
		return

	if odd:
		_slider.add_theme_icon_override("grabber", _odd_slider)
		_slider.add_theme_icon_override("grabber_highlight", _odd_slider)
		_slider.add_theme_icon_override("grabber_disabled", _odd_slider)
		
	_slider.min_value = 0
	_slider.step = 1
	_slider.visible = true
	match _selected_animation.name:
		"Volume":
			
			_slider.max_value = SoundManager.SNAP_STEPS
			_slider.value = _current_volume_step
			
			_slider.value_changed.connect(func(v):
				_current_volume_step = int(v)
				@warning_ignore("integer_division")
				SoundManager.volume = int(v) * (100 / SoundManager.SNAP_STEPS)
			)

		"Colors":
			_slider.max_value = ColorManager.SNAP_STEPS
			_slider.value = _current_color_step
			
			_slider.value_changed.connect(func(v):
				_current_color_step = int(v)
				ColorManager.set_ink_shimmer(v / (100.0 / SoundManager.SNAP_STEPS))
			)
			
		"Time":
			_slider.max_value = TimeManager.TIME_STEPS
			_slider.value = _current_time_step
			
			_slider.value_changed.connect(func(v):
				_current_time_step = int(v)
				print("value of the time interval:", v)
				TimeManager.set_time_value(int(v))
			)
			

func _set_slider_to_hovered_position() -> void:
	_slider.z_index += 30
	_slider.position.x -= 35
	_slider.position.y += 37
	_slider.scale = Vector2(2.0, 2.0)
	
func _reset_slider_to_regular_position() -> void:
	_slider.z_index -= 30
	_slider.position.x += 35
	_slider.position.y -= 37
	_slider.scale = Vector2(1.0, 1.0)

func _on_leader_update(new_leader: String, new_level: int) -> void:
	if not is_number_cell:
		return
	new_leader = new_leader.to_upper()
	_leader_name.text = TextHelper.bold(new_leader)
	_leader_name.text = TextHelper.center(_leader_name.text)
	_leader_name.text = TextHelper.size(_leader_name.text, 16)
	_current_max_level.texture = _level_sprites[new_level]

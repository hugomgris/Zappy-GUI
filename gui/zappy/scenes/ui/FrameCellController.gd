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

@export var odd: bool = true
@export var fixed_position: String = "mid_left"
@export var fixed_animation: String = "Cuby"

var _selected_position: Node2D = null
var _selected_animation: AnimatedSprite2D = null
var _original_position: Vector2 = Vector2.ZERO

var _is_scaled: bool = false
var _scaled_position: Node2D = null

func _ready() -> void:
	_original_position = position
	
	pick_position()
	pick_animation()
	set_outer_color()
	set_inner_color()
	
func on_mouse_entered() -> void:
	_positions.scale = Vector2(2.0, 2.0)
	_animations.scale = Vector2(2.0, 2.0)
	_move_to_scaled_position()
	_switch_to_scaled_layout()
	
	_positions.z_index += 10
	_animations.z_index += 11
	
	_collider.scale = Vector2(2.0, 2.0)
	
func on_mouse_exited() -> void:
	_remove_scaled_layout()
	_positions.scale = Vector2(1.0, 1.0)
	_animations.scale = Vector2(1.0, 1.0)
	position = _original_position
	
	_positions.z_index -= 10
	_animations.z_index -= 11
	
	_collider.scale = Vector2(1.0, 1.0)
		
func pick_position() -> void:
	for i in range (_positions.get_children().size()):
		var child: Node2D = _positions.get_child(i)
		child.visible = false
		
	var final_position = _positions.get_node_or_null(fixed_position)
	if final_position:
		final_position.visible = true
		_selected_position = final_position
	else:
		push_warning("FrameCellController: couldn't find position node from string {%s}" % fixed_position)

func set_outer_color() -> void:
	var selected_outer: ColorRect = _selected_position.get_node_or_null("Outer")
	if selected_outer:
		selected_outer.color = BORDER_COLOR
	else:
		push_warning("FrameCellController: failed to find target inner ColorRect node")

func set_inner_color() -> void:
	var selected_color: Color = Color.BLACK
	
	if odd:
		selected_color = COLOR_A
	else:
		selected_color = COLOR_B
		
	var selected_inner: ColorRect = _selected_position.get_node_or_null("Inner")
	if selected_inner:
		selected_inner.color = selected_color
	else:
		push_warning("FrameCellController: failed to find target inner ColorRect node")
		
func set_scaled_inner_color() -> void:
	if not _is_scaled: return
	
	var selected_color: Color = Color.BLACK
	
	if odd:
		selected_color = COLOR_A
	else:
		selected_color = COLOR_B
		
	var selected_inner: ColorRect = _scaled_position.get_node_or_null("Inner")
	if selected_inner:
		selected_inner.color = selected_color
	else:
		push_warning("FrameCellController: failed to find target inner ColorRect node")
		
func pick_animation() -> void:
	for i in range(_animations.get_children().size() - 1):
		var child: AnimatedSprite2D = _animations.get_child(i)
		child.visible = false
	
	var selected: AnimatedSprite2D = _animations.get_node_or_null(fixed_animation)
	if selected:
		selected.visible = true
		_selected_animation = selected
	else:
		push_warning("FrameCellController: couldn't find animation node from string {%s}" % selected)

func _move_to_scaled_position() -> void:
	print(_selected_position.name)
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
	
	#var scaled_inner: ColorRect = scaled_position.get_node("Inner")
	#scaled_inner.size = Vector2(_scaled_sizes["mid_top"] / 2, _scaled_sizes["mid_top"] / 2)
	
	_scaled_position = scaled_position
	_is_scaled = true
	set_scaled_inner_color()

func _remove_scaled_layout() -> void:
	var current_position_name = String(_selected_position.name)
	var current_position: Node2D = _positions.get_node_or_null(current_position_name)
	current_position.visible = true
	
	_is_scaled = false
	_scaled_position = null
	var scale_position_node = _positions.get_node_or_null("scaled")
	scale_position_node.visible = false

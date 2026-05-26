class_name FrameCellController

extends Area2D

const CELL_SIZE: int = 135

const COLOR_A      = Color(0.0, 0.485, 0.0, 1.0)
const COLOR_B      = Color(0.0, 0.0, 0.485, 1.0)
const BORDER_COLOR = Color(0.854, 0.854, 0.854, 1.0)
const BORDER_WIDTH = 8.0

@onready var _root: Area2D = $"."
@onready var _positions: Node2D = $Positions
@onready var _animations: Node2D = $Animations

@export var odd: bool = true
@export var fixed_position: String = "none"
@export var fixed_animation: String = "none"

var _selected_position: Node2D = null
var _selected_animation: AnimatedSprite2D = null

func _ready() -> void:
	pick_position()
	pick_animation()
	set_outer_color()
	set_inner_color()
	#_root.global_position = Vector2(GameConfig.WINDOW_SIZE.x / 2.0, GameConfig.WINDOW_SIZE.y / 2.0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
func _on_mouse_entered() -> void:
	_root.scale *= 2
	
func _on_mouse_exited() -> void:
	_root.scale /= 2
		
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
		
func pick_animation() -> void:
	for i in range(_animations.get_children().size()):
		var child: AnimatedSprite2D = _animations.get_child(i)
		child.visible = false
	
	var selected: AnimatedSprite2D = _animations.get_node_or_null(fixed_animation)
	if selected:
		selected.visible = true
		_selected_animation = selected
	else:
		push_warning("FrameCellController: couldn't find animation node from string {%s}" % selected)

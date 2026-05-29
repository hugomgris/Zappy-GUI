extends Control

@onready var tile_tooltip: Panel = $TileTooltip
@onready var player_tooltip: Panel = $PlayerTooltip
@onready var resource_tooltip: Panel = $ResourceTooltip
@onready var egg_tooltip: Panel = $EggTooltip

var _active_panel: Panel = null
var _compositor_mouse := Vector2.ZERO
var _tooltips: Control = null

func initialize(tooltips: Control) -> void:
	_tooltips = tooltips

func _ready() -> void:
	_hide_all()
	
func show_tile(pos: Vector2i) -> void:
	var data := GameData.get_tile(pos)
	if not data:
		push_error("TooltipManager: show_tile failed to fetch tile data at ", pos)
		return
		
	tile_tooltip.populate(data)
	_show(tile_tooltip)
	
func show_player(id: int) -> void:
	var data:= GameData.get_player(id)
	if not data:
		return
		
	#player_tooltip.populate(data)
	_show(player_tooltip)
	
func hide_all() -> void:
	_hide_all()
	
func _process(delta:float) -> void:
	if _active_panel and _active_panel.visible:
		_track_cursor(_active_panel)
		
func _show(panel: Panel) -> void:
	_hide_all()
	panel.visible = true
	_active_panel = panel
	_track_cursor(panel)

func _hide_all() -> void:
	for child in get_children():
		if child is Panel:
			child.visible = false
	_active_panel = null
	
func _track_cursor(panel: Panel) -> void:
	var pos := _compositor_mouse + Vector2(32.0, -panel.size.y / 2)
	pos.x = clamp(pos.x, 0.0, 1080.0 - panel.size.x)
	pos.y = clamp(pos.y, 0.0, 1080.0 - panel.size.y)
	panel.position = pos
	
func update_mouse_position(pos: Vector2) -> void:
	_compositor_mouse = pos

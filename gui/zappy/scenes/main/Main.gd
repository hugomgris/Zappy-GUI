extends Control

@onready var _camera_rig: Node3D = %CameraRig
@onready var game_sub_viewport: SubViewport = %GameSubViewport
@onready var logo_viewport: SubViewport = %LogoViewport
@onready var post_processing: SubViewportContainer = $PostProcessing
@onready var tooltips: Control = $PostProcessing/Compositor/Tooltips

@export var use_mock := false
@export var map_size := Vector2i(10, 10)
@export var logo_scale := 1.0

var _hovered_tile: TileController = null
var _hovered_player: PlayerController = null

func _ready() -> void:
	TooltipManager.initialize($PostProcessing/Compositor/Tooltips)
	
	if use_mock:
		MockServer.build_mock_initial_game_state()
		MockServer.start()
	else:
		GameData.map_size = map_size
	
	GameData.world_initialized.emit()
	_camera_rig.initialize_for_map(GameData.map_size)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var pp_offset := post_processing.global_position
		var compositor_pos: Vector2 = event.position - pp_offset
		var game_offset := Vector2(135, 135)
		var local_event := event.xformed_by(
			Transform2D(0, -(pp_offset + game_offset))
		)
		game_sub_viewport.push_input(local_event)
		if event is InputEventMouseMotion:
			_do_picking(local_event.position)
			tooltips.update_mouse_position(compositor_pos)

func _do_picking(viewport_pos: Vector2) -> void:
	var camera := game_sub_viewport.get_camera_3d()
	if not camera:
		return
	
	var from := camera.project_ray_origin(viewport_pos)
	var to := from + camera.project_ray_normal(viewport_pos) * 1000.0
		
	var space := game_sub_viewport.find_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result := space.intersect_ray(query)
	
	if result:
		var collider = result.get("collider")
		if collider and collider is TileController:
			if collider != _hovered_tile:
				if _hovered_tile:
					_hovered_tile.unhovered.emit(_hovered_tile.grid_pos)
				_hovered_tile = collider
				_hovered_tile.hovered.emit(_hovered_tile.grid_pos)
		elif collider and collider is PlayerController:
			if collider != _hovered_player:
				if _hovered_player:
					_hovered_player.unhovered.emit(_hovered_player.get_player_id())
				_hovered_player = collider
				_hovered_player.hovered.emit(_hovered_player.get_player_id())
	else:
		if _hovered_tile:
			_hovered_tile.unhovered.emit(_hovered_tile.grid_pos)
			_hovered_tile = null
		if _hovered_player:
			_hovered_player.unhovered.emit(_hovered_player.get_player_id())
			_hovered_player = null

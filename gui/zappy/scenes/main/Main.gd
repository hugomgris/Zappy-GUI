extends Control

@onready var _camera_rig: Node3D = %CameraRig
@onready var game_sub_viewport: SubViewport = %GameSubViewport
@onready var logo_viewport: SubViewport = %LogoViewport
@onready var post_processing: SubViewportContainer = $PostProcessing
@onready var tooltips: Control = $PostProcessing/Compositor/Tooltips
@onready var start_button: Button = $CanvasLayer/StartButton


@export var map_size := Vector2i(10, 10)
@export var logo_scale := 1.0

var _hovered_tile: TileController = null
var _hovered_player: PlayerController = null

func _ready() -> void:
	TooltipManager.initialize($PostProcessing/Compositor/Tooltips)
	GameData.world_initialized.connect(_on_world_initialized, CONNECT_ONE_SHOT)

	if AppState.use_mock:
		MockServer.build_mock_initial_game_state()
		MockServer.start()
		GameData.world_initialized.emit()
	else:
		ServerConnectionManager.raw_message_received.connect(ProtocolParser.handle)
		ServerConnectionManager.connection_established.connect(_on_server_connection_established, CONNECT_ONE_SHOT)
		ProtocolParser.snapshot_ready.connect(_on_snapshot_ready, CONNECT_ONE_SHOT)
		ProtocolParser.event_received.connect(_on_server_event)

func _on_server_connection_established() -> void:
	print("[Main] Connection established — snapshot incoming")

func _on_snapshot_ready() -> void:
	print("[Main] Snapshot ready — firing world_initialized")
	GameData.world_initialized.emit()

func _on_server_event(event_type: String, data: Dictionary) -> void:
	print("GOT AN EVENT")
	var status: String = data.get("status", "")
	var msg_type: String = data.get("type", "")

	# Mirror MockServer's dispatch filter exactly
	if status == "ok" or (msg_type == "event" and status == "level_up"):
		CommandProcessor.process_command(data)
	elif msg_type == "game_end":
		CommandProcessor.process_command(data)  # when you uncomment _game_end

func _on_world_initialized() -> void:
	_camera_rig.initialize_for_map(GameData.map_size)
	if not AppState.use_mock:
		start_button.show()
		start_button.pressed.connect(_on_start_game_pressed)

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouse):
		return

	if event is InputEventMouseButton:
		var control_at_pos := get_viewport().gui_get_hovered_control()
		if control_at_pos != null:
			return

	var pp_offset := post_processing.global_position
	var compositor_pos: Vector2 = event.position - pp_offset
	var game_offset := Vector2(135, 135)
	var local_event := event.xformed_by(Transform2D(0, -(pp_offset + game_offset)))
	game_sub_viewport.push_input(local_event)
	if event is InputEventMouse:
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


func _on_start_game_pressed() -> void:
	start_button.hide()
	var script_path = ProjectSettings.globalize_path("/home/hmunoz-g/42-OuterCore/zappy/server/run.sh")
	var output = []
	var exit_code = OS.execute("bash", [script_path], output, true, true)
	if exit_code != 0:
		push_error("[Main] run.sh failed (exit %d): %s" % [exit_code, "\n".join(output)])
	else:
		print("[Main] Server time API started")

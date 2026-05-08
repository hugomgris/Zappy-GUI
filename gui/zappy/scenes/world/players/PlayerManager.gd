extends Node3D

@onready var world_root: Node3D = %WorldRoot

const SCENES: Dictionary = {
	"test": preload("res://scenes/world/players/player_test.tscn")
}

var _players: Dictionary = {}

func _ready() -> void:
	GameData.world_initialized.connect(_spawn_players)
	CommandProcessor.player_moved.connect(_on_player_moved)
	CommandProcessor.player_rotated.connect(_on_player_rotated)
	CommandProcessor.player_leveled_up.connect(_on_player_leveled_up)


func _spawn_players() -> void:
	for id in GameData.players:
		_spawn_player(id)

func _spawn_player(id: int) -> void:
	var player_data: GameData.PlayerData = GameData.get_player(id)
	if not player_data:
		push_warning("PlayerManager: failed to get player data from id ", id)
		return
		
	var pos: Vector2i = player_data.pos
	var tile : TileController = world_root.get_tile(pos)
	if not tile:
		push_warning("PlayerManager: tile not found at pos ", pos)
		return
	
	var slot := tile.get_free_player_slot()
	if slot == -1:
		push_warning("PlayerManager: Tile full when attempting to place player ", id)
		return
	
	var scene: Node3D = SCENES["test"].instantiate()
	scene.assign_player_id(id)
	tile.occupy_player_slot(slot, scene)
	_players[id] = scene
	_rotate_player_from_orientation(scene, player_data.orientation)
	
	return

# signal responders
func _on_player_moved(id: int, from: Vector2i, to: Vector2i) -> void:		
	var scene = _players[id]
	if not scene:
		push_warning("PlayerManager: player scene not found for id ", id)
		return
	
	var from_tile : TileController = world_root.get_tile(from)
	if not from_tile:
		push_warning("PlayerManager: from_tile not found at pos ", from)
		return
		
	var to_tile : TileController = world_root.get_tile(to)
	if not to_tile:
		push_warning("PlayerManager: to_tile not found at pos ", to)
		return
	
	var spacing: float = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	
	var pos_before: Vector3 = scene.global_position
	var target_pos: Vector3 = pos_before + Vector3(dx * spacing, 0, dy * spacing)
	
	_move_player_between_tiles(id, from, to)
	
	scene.global_position = pos_before
	
	var tween = scene.create_tween()
	var start_pos: Vector3 = scene.global_position
	var duration: float = 0.3
	var steps: int = 12
	var total_frames: int = int(steps * duration)
	
	tween.tween_method(
		func(t: float):
			var frame: int = int(t * total_frames)
			var q_t: float = float(frame) / float(total_frames)
			
			scene.global_position = start_pos.lerp(target_pos, q_t),
		0.0, 1.0, duration
	)
	
	#tween.tween_property(scene, "global_position", target_pos, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_callback(_move_player_between_tiles.bind(id, from, to))
	
	return

func _on_player_rotated(id: int, new_orientation: int) -> void:
	var player_data: GameData.PlayerData = GameData.get_player(id)
	var pos: Vector2i = player_data.pos
	
	var tile : TileController = world_root.get_tile(pos)
	if not tile:
		push_warning("PlayerManager: tile not found at pos ", pos)
		return
	
	var player_scene: Node3D = tile.get_player_scene_from_id(id)
	if not player_scene:
		push_warning("PlayerManager: failed to fetch player_scene from id ", id)
		return
	
	var target_y: float = _calculate_rotation_radians(new_orientation)
	
	var delta : float = wrapf(target_y - player_scene.global_rotation.y, -PI, PI)
	var target_rotation_vector = Vector3(player_scene.global_rotation.x, player_scene.global_rotation.y + delta, player_scene.global_rotation.z)
	
	var tween = player_scene.create_tween()
	var start_rotation = player_scene.global_rotation
	var duration: float = 0.3
	var steps: int = 12
	var total_frames: int = int(steps * duration)

	tween.tween_method(
		func(t: float):
			var frame: int = int(t * total_frames)
			var q_t: float = float(frame) / float(total_frames)

			player_scene.global_rotation = start_rotation.lerp(target_rotation_vector, q_t),
		0.0, 1.0, duration
	)

	#tween.tween_property(player_scene, "global_rotation:y", player_scene.global_rotation.y + delta, 0.5)

	return

func _on_player_leveled_up(id: int, new_level: int) -> void:
	print("player ", id, " leveled up and is now level ", new_level)
	return
		
# helpers
func _rotate_player_from_orientation(scene: Node3D, orientation: int) -> void:
	scene.global_rotation.y = _calculate_rotation_radians(orientation)
			
func _calculate_rotation_radians(orientation: int) -> float:
	match orientation:
		1: return 0.0
		2: return deg_to_rad(-90)
		3: return deg_to_rad(180)
		4: return deg_to_rad(90)
	return 0.0

func _move_player_between_tiles(id: int, from: Vector2i, to: Vector2i) -> void:
	var from_tile : TileController = world_root.get_tile(from)
	if not from_tile:
		push_warning("PlayerManager: from_tile not found at pos ", from)
		return
		
	var to_tile : TileController = world_root.get_tile(to)
	if not to_tile:
		push_warning("PlayerManager: to_tile not found at pos ", to)
		return
		
	var from_slot: int = from_tile.find_player_occupied_index_from_player_id(id)
	if from_slot == -1:
		push_warning("PlayerManager: player ", id, " not found in any slot on from_tile")
			
	var scene = from_tile.get_player_scene_from_id(id)
	from_tile.free_player_slot(from_slot)
	
	var to_slot: int = to_tile.get_free_player_slot()
	if to_slot == -1:
		push_warning("PlayerManager: no free slot on to_tile at ", to)
		
	to_tile.occupy_player_slot(to_slot, scene)
	
	return

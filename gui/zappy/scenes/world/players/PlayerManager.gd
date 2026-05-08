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
func _on_player_moved(id: int, from: Vector2i, to: Vector2i, orientation: int) -> void:		
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
	
	var spacing: int = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	
	#if abs(dx) > 1:
		#scene.global_position.x = abs(dx)
	#elif abs(dy) > 1:
		#scene.global_position.z = abs(dy)
		
	scene.global_position.x += dx * spacing
	scene.global_position.z += dy * spacing
	
	_move_player_between_tiles(id, from, to)
	
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
	
	_rotate_player_from_orientation(player_scene, new_orientation)

	return

func _on_player_leveled_up(id: int, new_level: int) -> void:
	print("player ", id, " leveled up and is now level ", new_level)
	return
		
# helpers
func _rotate_player_from_orientation(scene: Node3D, orientation: int) -> void:
	match orientation:
		1:
			scene.global_rotation.y = 0
			return
		2:
			scene.global_rotation.y = deg_to_rad(-90)
			return
		3:
			scene.global_rotation.y = deg_to_rad(180)
			return
		4:
			scene.global_rotation.y = deg_to_rad(90)
			return

func _move_player_between_tiles(id: int, from: Vector2i, to: Vector2i) -> void:
	var from_tile : TileController = world_root.get_tile(from)
	if not from_tile:
		push_warning("PlayerManager: from_tile not found at pos ", from)
		return
		
	var to_tile : TileController = world_root.get_tile(to)
	if not to_tile:
		push_warning("PlayerManager: to_tile not found at pos ", to)
		return
		
	var scene = from_tile.get_player_scene_from_id(id)
	to_tile.free_player_slot(0)
	from_tile.occupy_player_slot(1, scene)
	
	print(from_tile._player_slots[0].get_child_count())
	print(to_tile._player_slots[0].get_child_count())
	
	to_tile.add_child(scene)
	
	return

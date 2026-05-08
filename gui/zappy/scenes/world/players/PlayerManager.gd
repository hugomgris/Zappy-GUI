extends Node3D

@onready var world_root: Node3D = %WorldRoot

const SCENES: Dictionary = {
	"test": preload("res://scenes/world/players/player_test.tscn")
}

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
	_rotate_player_from_orientation(scene, player_data.orientation)
	tile.occupy_player_slot(slot, scene)
	
	return

# signal responders
func _on_player_moved(id: int, from: Vector2i, to: Vector2i, orientation: int) -> void:
	print("player ", id, " is moving from ", from, " to ", to, " with orientation ", orientation)
	return

func _on_player_rotated(id: int, new_orientation: int) -> void:
	var player_data: GameData.PlayerData = GameData.get_player(id)
	var pos: Vector2i = player_data.pos
	
	var tile : TileController = world_root.get_tile(pos)
	if not tile:
		push_warning("PlayerManager: tile not found at pos ", pos)
		return
	
	var player_scene: Node3D = tile.get_player_scene_from_id(id, tile)
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
			scene.global_rotation.y = deg_to_rad(0)
		2:
			scene.global_rotation.y =deg_to_rad(-90)
		3:
			scene.global_rotation.y = deg_to_rad(180)
		4:
			scene.global_rotation.y = deg_to_rad(90)
		

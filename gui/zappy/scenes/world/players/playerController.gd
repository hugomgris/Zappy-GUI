extends Node3D

var player_id: int = -1

func assign_player_id(id: int) -> void:
	player_id = id

# accessor
func get_player_id() -> int:
	return player_id

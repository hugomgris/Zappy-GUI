class_name PlayerController

extends Area3D

signal hovered(pos: Vector2i)
signal unhovered(pos: Vector2i)

var player_id: int = -1

func _ready() -> void:
	mouse_entered.connect(func(): hovered.emit(player_id))
	mouse_exited.connect(func(): unhovered.emit(player_id))

func assign_player_id(id: int) -> void:
	player_id = id

# accessor
func get_player_id() -> int:
	return player_id

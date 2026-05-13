extends Node

var _instance: Control = null

func initialize(instance: Control) -> void:
	_instance = instance

func show_tile(pos: Vector2i) -> void:
	if _instance: _instance.show_tile(pos)

func show_player(id: int) -> void:
	if _instance: _instance.show_player(id)

func hide_all() -> void:
	if _instance: _instance.hide_all()

func update_mouse_position(pos: Vector2) -> void:
	if _instance: _instance.update_mouse_position(pos)

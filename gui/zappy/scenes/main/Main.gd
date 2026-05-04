extends Control

@onready var _camera_rig: Node3D = %CameraRig

func _ready() -> void:
	GameData.map_size = Vector2i(10, 10)
	GameData.world_initialized.emit()
	_camera_rig.initialize_for_map(Vector2i(10, 10))

extends Control

@onready var _camera_rig: Node3D = %CameraRig

@export var map_size := Vector2i(10, 10)

func _ready() -> void:
	GameData.map_size = map_size
	GameData.world_initialized.emit()
	_camera_rig.initialize_for_map(map_size)

extends Node3D

@onready var _camera_rig: Node3D = $CameraRig

func _ready() -> void:
	_camera_rig.initialize_for_map(Vector2i(10, 10))

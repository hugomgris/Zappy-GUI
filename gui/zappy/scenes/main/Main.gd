extends Control

@onready var _camera_rig: Node3D = %CameraRig
@onready var game_sub_viewport: SubViewport = %GameSubViewport
@onready var logo_viewport: SubViewport = %LogoViewport

@export var use_mock := false
@export var map_size := Vector2i(10, 10)
@export var logo_scale := 1.0

func _ready() -> void:
	$PostProcessing/Compositor/GameWorldTexture.texture = game_sub_viewport.get_texture()
	$PostProcessing/Compositor/LogoTexture.texture = logo_viewport.get_texture()
	
	var mat := $PostProcessing.material as ShaderMaterial
	# Match your actual window size
	mat.set_shader_parameter("screen_size", Vector2(1080, 1080))
	
	if use_mock:
		MockServer.build_mock_initial_game_state()
		MockServer.start()
	else:
		GameData.map_size = map_size
	
	GameData.world_initialized.emit()
	_camera_rig.initialize_for_map(GameData.map_size)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		$GameSubViewport.push_input(event)

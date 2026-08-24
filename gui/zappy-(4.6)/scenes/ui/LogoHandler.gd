extends Sprite2D

@export var logo_scale: float = 1.0
const BASE_SIZE := Vector2(135, 135)
const BASE_POS := Vector2(0, 0)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_apply()

func _apply() -> void:
	var target := BASE_SIZE * logo_scale
	scale = target / BASE_SIZE
	position = BASE_POS + (BASE_SIZE * logo_scale * 0.5)
	# Use the compositor viewport width instead of hardcoded 1920
	var viewport_width: float = get_viewport().size.x
	position.x = position.x

func _process(_delta: float) -> void:
	_apply()

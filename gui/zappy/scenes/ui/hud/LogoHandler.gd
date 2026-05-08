extends Sprite2D

@export var logo_scale: float = 1.0
const BASE_SIZE := Vector2(530.0, 140.0)
const BASE_POS := Vector2(32.0, 32.0)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_apply()

func _apply() -> void:
	var target := BASE_SIZE * logo_scale
	scale = target / BASE_SIZE
	position = BASE_POS + (BASE_SIZE * logo_scale * 0.5)
	position.x = 1920 - position.x

func _process(_delta: float) -> void:
	_apply()

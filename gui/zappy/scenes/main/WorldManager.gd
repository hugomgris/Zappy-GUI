# World general manager script.
# Owns all tile instances
extends Node3D

@export var debugMode: bool = false

var _tiles: Dictionary = {} # Vector2i -> TileController
var _tile_scenes: Dictionary # TileType -> PackedScene

func _ready() -> void:
	_tile_scenes = {
		GameConfig.TileType.RED_LIGHT:
			preload("res://scenes/world/tiles/tile_RED_light.tscn"),
		GameConfig.TileType.RED_DARK:
			preload("res://scenes/world/tiles/tile_RED_dark.tscn")
	}
	GameData.world_initialized.connect(_on_world_initialized)
	
func _on_world_initialized() -> void:
	_build_map()

func _build_map() -> void:
	for child in get_children():
		child.queue_free()
	_tiles.clear()
	
	var spacing = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
	
	for x in GameData.map_size.x:
		for y in GameData.map_size.y:
			var pos := Vector2i(x, y)
			var tile_type: GameConfig.TileType = PatternBuilder.tile_type_for(pos.x, pos.y)
			var tile: Area3D = _tile_scenes[tile_type].instantiate()
			tile.position = Vector3(x * spacing, 0.0, y * spacing)
			tile.setup(pos)
			add_child(tile)
			_tiles[pos] = tile
				
			# Connect hover to HUD tooltip sistem (signal bus or direct)
			tile.hovered.connect(_on_tile_hovered)
			tile.unhovered.connect(_on_tile_unhovered)
			
## Returns tile scene from sent position value X-Y
func get_tile(pos: Vector2i) -> TileController:
	return _tiles.get(pos)
	
func world_pos(grid: Vector2i) -> Vector3:
	var spacing: float = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
	return Vector3(grid.x * spacing, 0.0, grid.y * spacing)
	
func _on_tile_hovered(pos: Vector2i) -> void:
	print("TILE HOVERED at ", pos)
	TooltipManager.show_tile(pos)

func _on_tile_unhovered(pos: Vector2i) -> void:
	print("TILE UNHOVERED at ", pos)
	TooltipManager.hide_all()

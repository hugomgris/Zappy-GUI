# World general manager script.
# Owns all tile instances
extends Node3D

@export var debugMode: bool = false

var _tiles: Dictionary = {} # Vector2i -> TileController
var _tile_scenes: Dictionary # TileType -> PackedScene

func _ready() -> void:
	_tile_scenes = {
		GameConfig.TileType.BASIC:
			preload("res://scenes/world/tiles/tile_base.tscn"),
		GameConfig.TileType.ARCH_1F:
			preload("res://scenes/world/tiles/tile_arch_1F.tscn"),
		GameConfig.TileType.ARCH_2F:
			preload("res://scenes/world/tiles/tile_arch_2F.tscn"),
		GameConfig.TileType.ARCH_3F:
			preload("res://scenes/world/tiles/tile_arch_3F.tscn"),
	}
	GameData.world_initialized.connect(_on_world_initialized)
	
func _on_world_initialized() -> void:
	_build_map()


func _build_map() -> void:
	# Clear previous tiles
	for child in get_children():
		child.queue_free()
	_tiles.clear()
	
	var spacing = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
	var pattern = PatternBuilder.select_pattern(debugMode, GameData.map_size)
	
	for x in GameData.map_size.y:
		for y in GameData.map_size.y:
			var pos := Vector2i(x, y)
			var tile_type: GameConfig.TileType = PatternBuilder.tile_type_for(pattern, pos.x, pos.y, GameData.map_size)
			var tile: Area3D = _tile_scenes[tile_type].instantiate()
			tile.position = Vector3(x * spacing, 0.0, y * spacing)
			tile.setup(pos)
			add_child(tile)
			_tiles[pos] = tile
			
			#checkerboard darkening
			if (x + y) % 2 == 1:
				print("at ", x, "-", y)
				PatternBuilder.darken_tile(tile)
				
			# Connect hover to HUD tooltip sistem (signal bus or direct)
			tile.hovered.connect(_on_tile_hovered)
			tile.unhovered.connect(_on_tile_unhovered)
			
func get_tile(pos: Vector2i) -> TileController:
	return _tiles.get(pos)
	
func world_pos(grid: Vector2i) -> Vector3:
	var spacing: float = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
	return Vector3(grid.x * spacing, 0.0, grid.y * spacing)
	
func _on_tile_hovered() -> void:
	print("TILE HOVERED")

func _on_tile_unhovered() -> void:
	print("TILE UNHOVERED")

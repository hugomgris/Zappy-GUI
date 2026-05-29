# Manages the resource in relation to tiles and their contents
extends Node3D

@onready var world_root: Node3D = %WorldRoot

const SCENES: Dictionary = {
	"nourriture": preload("res://scenes/world/resources/nourriture.tscn"),
	"linemate": preload("res://scenes/world/resources/linemate.tscn"),
	"deraumere": preload("res://scenes/world/resources/deraumere.tscn"),
	"sibur": preload("res://scenes/world/resources/sibur.tscn"),
	"mendiane": preload("res://scenes/world/resources/mendiane.tscn"),
	"phiras": preload("res://scenes/world/resources/phiras.tscn"),
	"thystame": preload("res://scenes/world/resources/thystame.tscn"),
}

func _ready() -> void:
	GameData.world_initialized.connect(_place_initial_resources)
	CommandProcessor.resource_placed.connect(_on_resource_placed)
	CommandProcessor.resource_taken.connect(_on_resource_taken)
	CommandProcessor.tile_updated.connect(_on_tile_updated)

func _place_initial_resources() -> void:
	for tile in GameData.tiles:
		var tile_data: GameData.TileState = GameData.tiles[tile]
		for resource in tile_data.resources:
			var quantity: int = tile_data.resources[resource]
			if quantity > 0:
				_place_resource(GameData.tiles[tile].pos, resource, quantity)
	return

func _place_resource(pos: Vector2i, resource: String, quantity: int) -> void:
	var tile : TileController = world_root.get_tile(pos)
	if not tile:
		push_error("ResourceManager: Tile not found at pos ", pos)
		return
	
	var slot := tile.get_free_resource_slot()
	if slot == -1:
		push_error("ResourceManager: Tile full when attempting to place ", resource)
		return

	var scene: Area3D = SCENES[resource].instantiate()
	tile.occupy_resource_slot(slot, scene)
	scene.transform_by_quantity(quantity)
	
	return

func _on_resource_placed(pos: Vector2i, resource: String, reserve: int) -> void:
	var tile : TileController = world_root.get_tile(pos)
	if not tile:
		push_error("ResourceManager: Tile not found at pos ", pos)
		return
	
	var resource_scene: Area3D = tile.get_resource_scene_from_name(resource)
	if resource_scene:
		resource_scene.transform_by_quantity(reserve)
		return
	else:
		var scene: Area3D = SCENES[resource].instantiate()
		tile.occupy_resource_slot(tile.get_free_resource_slot(), scene)
		return

func _on_resource_taken(pos: Vector2i, resource: String, reserve: int) -> void:
	var tile : TileController = world_root.get_tile(pos)
	if not tile:
		push_error("ResourceManager: Tile not found at pos ", pos)
		return
	
	var resource_scene: Area3D = tile.get_resource_scene_from_name(resource)
	if not resource_scene:
		push_error("ResourceManageR: Tile has no resource scene for ", resource)
	
	if (reserve > 1):
		resource_scene.transform_by_quantity(reserve)
	else:
		tile.free_resource_slot(tile.get_resource_scene_index(resource))
	return
	
func _on_tile_updated(pos: Vector2i, resources: Dictionary) -> void:
	# update data tile
	var tile_data := GameData.get_tile(pos)
	
	
	# update data visuals

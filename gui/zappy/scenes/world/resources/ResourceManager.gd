# Manages the resource in relation to tiles and their contents
extends Node3D

@onready var world_root: Node3D = %WorldRoot

const SCENES: Dictionary = {
	"nourriture": preload("res://scenes/world/resources/nourriture.tscn"),
	"linemate": preload("res://scenes/world/resources/linemate.tscn")
}

func _ready() -> void:
	GameData.world_initialized.connect(_place_initial_resources)
	CommandProcessor.resource_placed.connect(_on_resource_placed)
	CommandProcessor.resource_taken.connect(_on_resource_taken)

func _place_initial_resources() -> void:
	for tile in GameData.tiles:
		var tile_data: GameData.TileState = GameData.tiles[tile]
		for resource in tile_data.resources:
			var quantity: int = tile_data.resources[resource]
			if quantity > 0:
				print(resource)
				_place_resource(GameData.tiles[tile].pos, resource, quantity)
	return

func _place_resource(pos: Vector2i, resource: String, quantity: int) -> void:
	if not resource == "nourriture" and not resource == "linemate": return # until all the other resource scenes are up
	var tile : TileController = world_root.get_tile(pos)
	if not tile:
		push_warning("ResourceManager: Tile not found at pos ", pos)
		return
	
	var slot := tile.get_free_resource_slot()
	if slot == -1:
		push_warning("ResourceManager: Tile full when attempting to place ", resource)
		return

	var scene: Node3D = SCENES[resource].instantiate()
	tile.occupy_resource_slot(slot, scene)
			
	
	return

func _on_resource_placed(id: int, tile_pos: Vector2i, resource: String) -> void:
	return

func _on_resource_taken(id: int, tile_pos: Vector2i, resource: String) -> void:
	return

# connect signals
# place and remove functions
# quantity -> scale

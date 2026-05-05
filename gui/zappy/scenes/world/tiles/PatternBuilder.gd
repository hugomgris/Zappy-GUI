# Static, pure-logic class with pattern managing functions

class_name PatternBuilder

enum Pattern {
	# Small patterns (≤5x5)
	SMALL_FORTRESS,
	SMALL_ARENA,
	SMALL_TOWER,
	
	# Medium patterns (6-12)
	MEDIUM_COURTYARD,
	MEDIUM_WALLS,
	MEDIUM_CORNER_TOWERS,
	MEDIUM_CENTER_TOWER,
	
	# Large patterns (>12)
	LARGE_MAZE,
	LARGE_TOWERS,
	LARGE_STRONGHOLD,

	# DEBUG
	DEBUG
}

static var shared_dark_materials = {}

static func select_pattern(debug: bool, map_size: Vector2i) -> Pattern:
	var max_dimension = max(map_size.x, map_size.y)

	if debug:
		return Pattern.DEBUG

	if max_dimension <= 5:
		return [Pattern.SMALL_FORTRESS, Pattern.SMALL_ARENA, Pattern.SMALL_TOWER].pick_random()

	if max_dimension <= 12:
		return [Pattern.MEDIUM_COURTYARD, Pattern.MEDIUM_WALLS, Pattern.MEDIUM_CORNER_TOWERS, Pattern.MEDIUM_CENTER_TOWER].pick_random()

	else:
		return [Pattern.LARGE_MAZE, Pattern.LARGE_TOWERS, Pattern.LARGE_STRONGHOLD].pick_random()

static func tile_type_for(x: int, y: int) -> GameConfig.TileType:
	if (x + y) % 2 == 1:
		return GameConfig.TileType.RED_DARK
	else:
		return GameConfig.TileType.RED_LIGHT

#static func darken_tile(tile: Area3D) -> void:
	#var mesh: MeshInstance3D = _find_tile_mesh(tile)
	#if not mesh:
		#return;
#
	#var original_material = mesh.material_override
	#if not original_material:
		#return
#
	#var material_key = str(original_material.get_rid())
	#if not shared_dark_materials.has(material_key):
		#var new_material = original_material.duplicate() as StandardMaterial3D
		#new_material.albedo_color = original_material.albedo_color.darkened(0.3)
		#shared_dark_materials[material_key] = new_material
#
	#mesh.material_override = shared_dark_materials[material_key]
	#print("darkened")

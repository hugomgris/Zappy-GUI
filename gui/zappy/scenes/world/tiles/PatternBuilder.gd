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

static func tile_type_for(pattern: Pattern, x: int, y: int, map_size: Vector2i) -> GameConfig.TileType:
	match pattern:
		Pattern.SMALL_FORTRESS:
			return _build_small_fortress(x, y, map_size)
		Pattern.SMALL_ARENA:
			return _build_small_arena(x, y, map_size)
		Pattern.SMALL_TOWER:
			return _build_small_tower(x, y)
		Pattern.MEDIUM_COURTYARD:
			return _build_medium_courtyard(x, y, map_size)
		Pattern.MEDIUM_WALLS:
			return _build_medium_walls(x, y, map_size)
		Pattern.MEDIUM_CORNER_TOWERS:
			return _build_corner_towers(x, y, map_size)
		Pattern.MEDIUM_CENTER_TOWER:
			return _build_center_tower(x, y, map_size)
		Pattern.LARGE_MAZE:
			return _build_large_maze(x, y, map_size)
		Pattern.LARGE_TOWERS:
			return _build_large_towers(x, y, map_size)
		Pattern.LARGE_STRONGHOLD:
			return _build_large_stronghold(x, y, map_size)
		_:
			return GameConfig.TileType.BASIC

static func darken_tile(tile: Area3D) -> void:
	var mesh: MeshInstance3D = _find_tile_mesh(tile)
	if not mesh:
		return;

	var original_material = mesh.material_override
	if not original_material:
		return

	var material_key = str(original_material.get_rid())
	if not shared_dark_materials.has(material_key):
		var new_material = original_material.duplicate() as StandardMaterial3D
		new_material.albedo_color = original_material.albedo_color.darkened(0.3)
		shared_dark_materials[material_key] = new_material

	mesh.material_override = shared_dark_materials[material_key]
	print("darkened")

static func _find_tile_mesh(tile: Area3D) -> MeshInstance3D:
	var mesh_paths = [
		"mesh/basic_tile",
		"mesh/tile_1f",
		"mesh/tile_2f",
		"mesh/tile_3f",
	]

	for path in mesh_paths:
		var mesh = tile.get_node_or_null(path) as MeshInstance3D
		if mesh:
			return mesh
	
	return null

# pattern building functions
static func _build_small_tower(x: int, y: int) -> GameConfig.TileType:
	if _is_north_corner(x, y):
		return GameConfig.TileType.ARCH_3F
	elif _is_north_sub_corner(x, y):
		return GameConfig.TileType.ARCH_2F
	elif _is_north_sub_sub_corner(x, y):
		return GameConfig.TileType.ARCH_1F
	return GameConfig.TileType.BASIC

static func _build_small_fortress(x: int, y: int, map_size: Vector2i) -> GameConfig.TileType:
	if _is_border(x, y, map_size):
		return GameConfig.TileType.ARCH_1F
	return GameConfig.TileType.BASIC

static func _build_small_arena(x: int, y: int, map_size: Vector2i) -> GameConfig.TileType:
	if _is_corner(x, y, map_size):
		return GameConfig.TileType.ARCH_2F
	return GameConfig.TileType.BASIC

static func _build_medium_courtyard(x: int, y: int, map_size: Vector2i) -> GameConfig.TileType:
	if _is_border(x, y, map_size):
		return GameConfig.TileType.ARCH_3F
	elif _is_inner_border(x, y, map_size):
		return GameConfig.TileType.ARCH_1F
	return GameConfig.TileType.BASIC

static func _build_medium_walls(x: int, y: int, map_size: Vector2i) -> GameConfig.TileType:
	if _is_corner(x, y, map_size):
		return GameConfig.TileType.ARCH_2F
	elif _is_border(x, y, map_size):
		return GameConfig.TileType.ARCH_1F
	return GameConfig.TileType.BASIC

static func _build_corner_towers(x: int, y: int, map_size: Vector2i) -> GameConfig.TileType:
	if _is_corner(x, y, map_size):
		return GameConfig.TileType.ARCH_3F
	elif _is_sub_corner(x, y, map_size):
		return GameConfig.TileType.ARCH_2F
	elif _is_sub_sub_corner(x, y, map_size):
		return GameConfig.TileType.ARCH_1F
	return GameConfig.TileType.BASIC

static func _build_center_tower(x: int, y: int, map_size: Vector2i) -> GameConfig.TileType:
	if _is_center_core(x, y, map_size):
		return GameConfig.TileType.ARCH_3F
	elif _is_center_ring_1(x, y, map_size):
		return GameConfig.TileType.ARCH_2F
	elif _is_center_ring_2(x, y, map_size):
		return GameConfig.TileType.ARCH_1F
	return GameConfig.TileType.BASIC

static func _build_large_maze(x: int, y: int, map_size: Vector2i) -> GameConfig.TileType:
	if _is_border(x, y, map_size):
		return GameConfig.TileType.ARCH_3F
	elif y == 1 or y == map_size.y - 2:
		return GameConfig.TileType.ARCH_2F
	elif x == 1 or x == map_size.x - 2:
		return GameConfig.TileType.ARCH_1F
	return GameConfig.TileType.BASIC

static func _build_large_towers(x: int, y: int, map_size: Vector2i) -> GameConfig.TileType:
	if _is_corner(x, y, map_size):
		return GameConfig.TileType.ARCH_3F
	return GameConfig.TileType.BASIC

static func _build_large_stronghold(x: int, y: int, map_size: Vector2i) -> GameConfig.TileType:
	if _is_corner(x, y, map_size):
		return GameConfig.TileType.ARCH_3F
	elif _is_border(x, y, map_size):
		return GameConfig.TileType.ARCH_2F
	elif _is_inner_border(x, y, map_size):
		return GameConfig.TileType.ARCH_1F
	return GameConfig.TileType.BASIC

# Helper Functions for Position Detection
static func _is_border(x: int, y: int, map_size: Vector2i) -> bool:
	return x == 0 or y == 0 or x == map_size.x - 1 or y == map_size.y - 1

static func _is_corner(x: int, y: int, map_size: Vector2i) -> bool:
	return (x == 0 or x == map_size.x - 1) and (y == 0 or y == map_size.y - 1)
	
static func _is_north_corner(x: int, y: int) -> bool:
	return (x == 0 and y == 0)
	
static func _is_north_sub_corner(x: int, y: int) -> bool:
	if ((x == 0 and y == 1)
	or (x == 1 and (y == 0 or y == 1))):
		return true
	return false
	
static func _is_north_sub_sub_corner(x: int, y: int) -> bool:
	if ((x == 0 and y == 2)
	or (x == 1 and y == 2)
	or (x == 2 and (y == 0 or y == 1 or y == 2))):
		return true
	return false

static func _is_sub_corner(x: int, y: int, map_size: Vector2i) -> bool:
	if (x == 0 and (y == 1 or y == map_size.y - 2)):
		return true
	elif (x == 1 and (y == 0 or y == 1 or y == map_size.y - 1 or y == map_size.y - 2)):
		return true
	elif (x == map_size.x - 2 and (y == 0 or y == 1 or y == map_size.y - 1 or y == map_size.y - 2)):
		return true
	elif (x == map_size.x - 1 and (y == 1 or y == map_size.y - 2)):
		return true
	return false

static func _is_sub_sub_corner(x: int, y: int, map_size: Vector2i) -> bool:
	if (x == 0 and (y == 2 or y == map_size.y - 3)):
		return true
	elif (x == 1 and (y == 2 or y == map_size.y - 3)):
		return true
	elif (x == 2 and (y == 0 or y == 1 or y == 2 or y == map_size.y - 3 or y == map_size.y - 2 or y == map_size.y - 1)):
		return true
	elif (x == map_size.x - 3 and (y == 0 or y == 1 or y == 2 or y == map_size.y - 3 or y == map_size.y - 2 or y == map_size.y - 1)):
		return true
	elif (x == map_size.x - 2 and (y == 2 or y == map_size.y - 3)):
		return true
	elif (x == map_size.x - 1 and (y == 2 or y == map_size.y - 3)):
		return true
	return false

static func _is_center(x: int, y: int, map_size: Vector2i) -> bool:
	@warning_ignore("INTEGER_DIVISION")
	var center_x = map_size.x / 2
	@warning_ignore("INTEGER_DIVISION") 
	var center_y = map_size.y / 2
	return abs(x - center_x) <= 1 and abs(y - center_y) <= 1

static func _is_inner_border(x: int, y: int, map_size: Vector2i) -> bool:
	return ((x == 1 or x == map_size.x - 2) or (y == 1 or y == map_size.y - 2)) and not _is_border(x, y, map_size)

static func _is_inner_center(x: int, y: int, map_size: Vector2i) -> bool:
	return not _is_border(x, y, map_size) and not _is_inner_border(x, y, map_size)


static func _is_center_core(x: int, y: int, map_size: Vector2i) -> bool:
	"""Check if position is in the 2x2 center core (3F tiles)"""
	@warning_ignore("INTEGER_DIVISION")
	var center_x = map_size.x / 2
	@warning_ignore("INTEGER_DIVISION") 
	var center_y = map_size.y / 2
	
	return (x >= center_x - 1 and x <= center_x) and (y >= center_y - 1 and y <= center_y)

static func _is_center_ring_1(x: int, y: int, map_size: Vector2i) -> bool:
	"""Check if position is in the 4x4 hollowed ring around center (2F tiles)"""
	@warning_ignore("INTEGER_DIVISION")
	var center_x = map_size.x / 2
	@warning_ignore("INTEGER_DIVISION") 
	var center_y = map_size.y / 2
	
	var in_4x4_area = (x >= center_x - 2 and x <= center_x + 1) and (y >= center_y - 2 and y <= center_y + 1)
	return in_4x4_area and not _is_center_core(x, y, map_size)

static func _is_center_ring_2(x: int, y: int, map_size: Vector2i) -> bool:
	"""Check if position is in the 6x6 hollowed ring around center (1F tiles)"""
	@warning_ignore("INTEGER_DIVISION")
	var center_x = map_size.x / 2
	@warning_ignore("INTEGER_DIVISION") 
	var center_y = map_size.y / 2

	var in_6x6_area = (x >= center_x - 3 and x <= center_x + 2) and (y >= center_y - 3 and y <= center_y + 2)
	var in_4x4_area = (x >= center_x - 2 and x <= center_x + 1) and (y >= center_y - 2 and y <= center_y + 1)
	return in_6x6_area and not in_4x4_area

static func verify_center_tower_8x8():
	"""Manually verify the CENTER_TOWER pattern matches expected output"""
	var map_size = Vector2i(8, 8)
	print("Verifying CENTER_TOWER 8x8 pattern:")
	print("Expected: 2x2 center (3F), 4x4 ring (2F), 6x6 ring (1F), rest Basic")
	
	# Test key positions
	var test_cases = [
		[Vector2i(3,3), "3F", "center core"],
		[Vector2i(3,4), "3F", "center core"], 
		[Vector2i(4,3), "3F", "center core"],
		[Vector2i(4,4), "3F", "center core"],
		[Vector2i(2,2), "2F", "4x4 ring corner"],
		[Vector2i(5,5), "2F", "4x4 ring corner"],
		[Vector2i(3,2), "2F", "4x4 ring edge"],
		[Vector2i(1,1), "1F", "6x6 ring corner"],
		[Vector2i(6,6), "1F", "6x6 ring corner"],
		[Vector2i(0,0), "B", "outside all rings"],
		[Vector2i(7,7), "B", "outside all rings"]
	]
	
	for test_case in test_cases:
		var pos = test_case[0]
		var expected = test_case[1]
		var description = test_case[2]
		var actual_type = tile_type_for(Pattern.MEDIUM_CENTER_TOWER, pos.x, pos.y, map_size)
		var actual = ""
		match actual_type:
			GameConfig.TileType.BASIC: actual = "B"
			GameConfig.TileType.ARCH_1F: actual = "1F"
			GameConfig.TileType.ARCH_2F: actual = "2F" 
			GameConfig.TileType.ARCH_3F: actual = "3F"
		
		var status = "✓" if actual == expected else "✗"
		print("  %s (%d,%d) %s: expected %s, got %s %s" % [status, pos.x, pos.y, description, expected, actual, "✓" if actual == expected else "✗"])

static func get_pattern_name(pattern: Pattern) -> String:
	"""Get a descriptive name for a pattern"""
	match pattern:
		Pattern.SMALL_FORTRESS:
			return "Small Fortress"
		Pattern.SMALL_ARENA:
			return "Small Arena"
		Pattern.SMALL_TOWER:
			return "Small Tower"
		Pattern.MEDIUM_COURTYARD:
			return "Medium Courtyard"
		Pattern.MEDIUM_WALLS:
			return "Medium Walls"
		Pattern.MEDIUM_CORNER_TOWERS:
			return "Corner Towers"
		Pattern.MEDIUM_CENTER_TOWER:
			return "Center Tower"
		Pattern.LARGE_MAZE:
			return "Large Maze"
		Pattern.LARGE_TOWERS:
			return "Large Towers"
		Pattern.LARGE_STRONGHOLD:
			return "Large Stronghold"
		_:
			return "Unknown Pattern"

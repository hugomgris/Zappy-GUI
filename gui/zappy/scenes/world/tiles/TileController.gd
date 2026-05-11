# Tile manager script.
# Adds scenes to tile markers
# Tracks occupied and occupied slots
class_name TileController

extends Area3D

var grid_pos: Vector2i
var _resource_slots: Array[Marker3D] = []
var _player_slots: Array[Marker3D] = []
var _resource_slot_occupied: Array[bool] = []
var _player_slot_occupied: Array[bool] = []

signal hovered(pos: Vector2i)
signal unhovered(pos: Vector2i)

func _ready() -> void:
	# signal wiring
	mouse_entered.connect(func(): hovered.emit(grid_pos))
	mouse_exited.connect(func(): unhovered.emit(grid_pos))
	
	# slot population from child Marker3D nodes
	_resource_slots = _collect_markers("ResourceSlots")
	_player_slots = _collect_markers("PlayerSlots")

	
	_resource_slot_occupied.resize(_resource_slots.size())
	_resource_slot_occupied.fill(false)
	
	_player_slot_occupied.resize(_player_slots.size())
	_player_slot_occupied.fill(false)

func setup(pos: Vector2i) -> void:
	grid_pos = pos
	
func get_free_resource_slot() -> int:
	return _resource_slot_occupied.find(false)
	
func occupy_resource_slot(index: int, scene: Node3D) -> void:
		_resource_slot_occupied[index] = true
		_resource_slots[index].add_child(scene) # add scene as child to the marker3D
		
func free_resource_slot(index: int) -> void:
	_resource_slot_occupied[index] = false
	if _resource_slots[index].get_child_count() == 0:
		push_error("TileController: free_resource_slot found no scene at index ", index)
		return
	var scene: Node3D = _resource_slots[index].get_child(0)
	_resource_slots[index].remove_child(scene)

func get_free_player_slot() -> int:
	return _player_slot_occupied.find(false)
	
func occupy_player_slot(index: int, scene: Node3D) -> void:
	_player_slot_occupied[index] = true
	_player_slots[index].add_child(scene)
	
func free_player_slot(index: int) -> void:
	_player_slot_occupied[index] = false
	if _player_slots[index].get_child_count() == 0:
		push_error("TileController: free_player_slot found no scene at index ", index)
		return
	var scene: Node3D = _player_slots[index].get_child(0)
	_player_slots[index].remove_child(scene)

func _collect_markers(parent_name: String) -> Array[Marker3D]:
	var result: Array[Marker3D] = []	
	var parent := get_node_or_null(parent_name)
	
	if not parent:
		return result
	
	for child in parent.get_children():
		if child is Marker3D:
			result.append(child)
			
	return result

func get_player_marker_from_slot(slot: int) -> Marker3D:
	return _player_slots[slot]

func get_player_scene_from_id(id: int) -> Node3D:
	for i in range(_player_slots.size()):
		if _player_slots[i].get_child_count() == 0:
			continue
		var player_scene: Node3D = _player_slots[i].get_child(0)
		if player_scene.get_player_id() == id:
			return player_scene
	return null

func find_player_occupied_index_from_player_id(id: int) -> int:
	for i in range(_player_slots.size()):
		if _player_slots[i].get_child_count() == 0:
			continue
		var player_scene: Node3D = _player_slots[i].get_child(0)
		if player_scene.get_player_id() == id:
			return i
	return -1

func get_resource_scene_from_name(name: String) -> Node3D:
	for i in range(_resource_slots.size()):
		if (_resource_slots[i].get_children_count() > 0):
			var target_scene: Node3D = _resource_slots[i].get_node(name)
			if target_scene:
				return target_scene
	
	return null

#debug tools
func get_occupied_player_slots_amount() -> int:
	var count: int = 0
	for i in range(_player_slots.size()):
		count += _player_slots[i].get_child_count()
		
	return count

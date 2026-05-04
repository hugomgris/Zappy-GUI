# GAME DATA - SOURCE OF TRUTH, WHERE OTHER SYSTEMS READ FOR AND REACT TO ITS SIGNALS
extends Node


# STATE
var map_size: Vector2i = Vector2i.ZERO
var time_unit: int = 100
var tick: int = 0
var teams: Dictionary = {} # team_name -> { player_count, connections }
var tiles: Dictionary = {} # Vector2i -> TileData
var players: Dictionary = {} # int (id) -> PlayerData
var eggs: Dictionary = {} # int (id) -> EggData

# SIGNALS
# Emitted once when the initial full state burst is complete
signal world_initialized
# Emitted when individual entities change
signal tile_change(pos: Vector2i)
signal player_changed(id: int)
signal player_removed(id: int)
signal egg_added(id: int)
signal egg_removed(id: int)
signal team_changed(name: String)
signal tick_updated(tick: int)
signal time_unit_changed(t: int)
signal game_over(winning_team: String)

# INNER CLASSES FOR TYPED DATA
class TileState:
	var pos: Vector2i
	var resources: Dictionary #resource_name -> int
	var player_ids: Array[int]
	var egg_ids: Array[int]
	
	func _init(p: Vector2i) -> void:
		pos = p
		resources = {}
		for r in GameConfig.RESOURCE_NAMES:
			resources[r] = 0
		player_ids = []
		egg_ids = []
		
class PlayerData:
	var id: int
	var team: String
	var pos: Vector2i
	var orientation: int #GameConfig.Orientation
	var level: int
	var inventory: Dictionary
	var status: GameConfig.PlayerStatus
	
	func _init(pid: int) -> void:
		id = pid
		inventory = {}
		for r in GameConfig.RESOURCE_NAMES:
			inventory[r] = 0
		status = GameConfig.PlayerStatus.NORMAL
	
class EggData:
	var id: int
	var layer_id: int
	var team: String
	var pos: Vector2i
	
# ACCESORS
func get_tile(pos: Vector2i) -> TileState:
	return tiles.get(pos)
	
func get_player(id: int) -> PlayerData:
	return players.get(id)
	
func get_egg(id: int) -> EggData:
	return eggs.get(id)

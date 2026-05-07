extends Node

# Signals
signal player_moved(id: int, from: Vector2i, to: Vector2i, orientation: int)
signal player_rotated(id: int, new_orientation: int)
signal player_died(id: int)
signal player_leveled_up(id: int, new_level: int)
signal player_status_changed(id: int, status: GameConfig.PlayerStatus)
signal resource_placed(tile_pos: Vector2i, resource: String)
signal resource_taken(tile_pos: Vector2i, resource: String)
signal egg_laid(egg_id: int, tile_pos: Vector2i)
signal egg_hatched(egg_id: int)
signal egg_died(egg_id: int)
signal incantatation_started(tile_pos: Vector2i, level: int, player_ids: Array[int])
signal incantation_ended(tile_pos: Vector2i, success:bool)
signal broadcast_sent(player_id: int, message: String)
signal game_over(winning_team: String)

func process_command(cmd: Dictionary) -> void:
	var type: String = cmd.get("cmd", "")
	if type.is_empty():
		push_warning("CommandProcessor: received command with no type")
		return

	match type:
		"avance":				_avance(cmd)
		"gauche":				_rotate(cmd, -1)
		"droite":				_rotate(cmd, 1)
		"prend":				_prend(cmd)
		"pose":					_pose(cmd)
		"fork":					_fork(cmd) # egg laid here
		"incantation_start":	_incantation_start(cmd)
		"incantation_end":		_incantation_end(cmd)
		"broadcast":			_broadcast(cmd)
		"death":				_death(cmd)
		"level_up":				_level_up(cmd)
		"egg_hatch":			_egg_hatch(cmd)
		"egg_death":			_egg_death(cmd)
		"game_end":				_game_end(cmd)
		_:
			push_warning("CommandProcessor: unknown command type '%s'" % type)

func _avance(cmd: Dictionary) -> void:
	var id: int = cmd.get("player_id", -1)
	var player := GameData.get_player(id)
	if not player:
		push_warning("CommandProcessor._avance: player %d not found" % id)
		return

	var from: Vector2i = player.pos
	var to: Vector2i = _advance_pos(from, player.orientation)

	# always update data before signal emission
	var old_tile := GameData.get_tile(from)
	var new_tile := GameData.get_tile(to)
	if old_tile: old_tile.player_ids.erase(id)
	if new_tile and not new_tile.player_ids.has(id):
		new_tile.player_ids.append(id)
	player.pos = to

	player_moved.emit(id, from, to, player.orientation)

	print("Processing ", cmd.get("cmd", ""), " for player with id [", id, "]")
	print("Emitting player_moved with (%d, %d-%d, %d-%d, %d)", % id, from.x, from.y, to.x, to.y, player.orientation)
	return
	
func _rotate(cmd: Dictionary, direction: int) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _prend(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _pose(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _fork(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _incantation_start(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _incantation_end(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _broadcast(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _death(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _level_up(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _egg_hatch(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _egg_death(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

func _game_end(cmd: Dictionary) -> void:
	print("Processing ", cmd.get("cmd", ""))
	return

# helpers
func _advance_pos(pos: Vector2i, orientation: int) -> Vector2i:
	return Vector2i(0,0)

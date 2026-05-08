extends Node

# Signals
signal player_moved(id: int, from: Vector2i, to: Vector2i, orientation: int)
signal player_rotated(id: int, new_orientation: int)
signal player_died(id: int)
signal player_leveled_up(id: int, new_level: int)
signal player_status_changed(id: int, status: GameConfig.PlayerStatus)
signal resource_placed(id: int, tile_pos: Vector2i, resource: String)
signal resource_taken(id: int, tile_pos: Vector2i, resource: String)
signal egg_laid(egg_id: int, tile_pos: Vector2i)
signal egg_hatched(egg_id: int)
signal egg_died(egg_id: int)
signal incantatation_started(tile_pos: Vector2i, level: int, player_ids: Array[int])
signal incantation_ended(tile_pos: Vector2i, success:bool)
signal broadcast_sent(player_id: int, message: String)
signal game_over(winning_team: String)

func process_command(cmd: Dictionary) -> void:
	var command: String = cmd.get("cmd", "")
	
	if command.is_empty():
		if (cmd.has("type") and cmd.get("type") == "event" and \
			cmd.has("status") and cmd.get("status") == "level_up"):
			command = cmd.get("status")
		else:
			push_warning("CommandProcessor: received command with no value")
			return

	match command:
		"avance":				_avance(cmd)
		"gauche":				_rotate(cmd, -1)
		"droite":				_rotate(cmd, 1)
		"prend":				_prend(cmd)
		"pose":					_pose(cmd)
		"fork":					_fork(cmd) # egg laid here
		#"incantation_start":	_incantation_start(cmd)
		#"incantation_end":		_incantation_end(cmd)
		#"broadcast":			_broadcast(cmd)
		#"death":				_death(cmd)
		"level_up":				_level_up(cmd)
		#"egg_hatch":			_egg_hatch(cmd)
		#"egg_death":			_egg_death(cmd)
		#"game_end":				_game_end(cmd)
		_:
			push_error("CommandProcessor: unknown command '%s'" % command)

func _avance(cmd: Dictionary) -> void:
	var id: int = cmd.get("player_id", -1)
	var player := GameData.get_player(id)
	if not player:
		push_error("CommandProcessor._avance: player %d not found" % id)
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

	return
	
func _rotate(cmd: Dictionary, direction: int) -> void:
	var id: int = cmd.get("player_id", -1)
	var new_orientation: int = GameData.players[id].orientation + 1 if direction > 0 else GameData.players[id].orientation - 1


	if new_orientation > 4:
		new_orientation = 1
	elif new_orientation < 1:
		new_orientation = 4

	GameData.players[id].orientation = new_orientation

	player_rotated.emit(id, new_orientation)

	return

func _prend(cmd: Dictionary) -> void:
	var id: int = cmd.get("player_id")
	var pos: Vector2i = GameData.players[id].pos
	var target: String = cmd.get("arg")

	
	var tile_reserve: int = GameData.tiles[pos].resources[target]
	if tile_reserve > 0:
		GameData.tiles[pos].resources[target] -= 1
		GameData.players[id].inventory[target] += 1
		resource_taken.emit(id, pos, target)

	return

func _pose(cmd: Dictionary) -> void:
	var id: int = cmd.get("player_id")
	var pos: Vector2i = GameData.players[id].pos
	var target: String = cmd.get("arg")

	var player_reserve: int = GameData.players[id].inventory[target]
	if (player_reserve > 0):
		GameData.tiles[pos].resources[target] += 1
		GameData.players[id].inventory[target] -= 1
		resource_placed.emit(id, pos, target)

	return

func _fork(cmd: Dictionary) -> void:
	var id: int = cmd.get("player_id")
	var data = GameData.EggData.new(id)
	data.id = GameData.eggs.size()
	data.layer_id = id
	data.team = GameData.players[id].team
	data.pos = GameData.players[id].pos

	GameData.eggs[data.id] = data
	GameData.tiles[data.pos].egg_ids.append(data.id)

	egg_laid.emit(data.id, data.pos)

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
	var id: int = cmd.get("player_id")
	GameData.players[id].level = min(8, GameData.players[id].level + 1)

	player_leveled_up.emit(id, GameData.players[id].level)

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
	var new_pos := pos

	match orientation:
		1: #NORTH
			new_pos.y -= 1
		2: #EAST
			new_pos.x += 1
		3: #SOUTH
			new_pos.y += 1
		4: #WEST
			new_pos.x -= 1

	if new_pos.x < 0:
		new_pos.x = GameData.map_size.x - 1
	elif new_pos.x >= GameData.map_size.x:
		new_pos.x = 0
	
	if new_pos.y < 0:
		new_pos.y = GameData.map_size.y - 1
	elif new_pos.y >= GameData.map_size.y:
		new_pos.y = 0

	return new_pos

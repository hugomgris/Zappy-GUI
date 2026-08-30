extends Node

var commands_path: String = "res://data/mock/"
var connection_path: String = commands_path + "connection/"
var interval: float = 1.0
var auto_start: bool = false

var _files: Array[String] = []
var _index: int = 0
var _timer: float = 0.0
var _running: bool = false

func _ready() -> void:
	CommandProcessor.game_over.connect(func (winner: String) -> void:
		_running = false
	)

func build_mock_initial_game_state() -> void:
	_load_mock_initial_state()
	return

func start() -> void:
	_load_mock_command_files()
	_running = _files.size() > 0

func stop() -> void:
	_running = false

func _process(delta: float) -> void:
	if not _running: return

	_timer += delta
	if _timer >= interval:
		_timer = 0.0
		_dispatch_next()

func _dispatch_next() -> void:
	if _index >= _files.size():
		_index = 0 # loop!

	var data := _load_json(_files[_index])
	_index += 1

	if data.is_empty():
		return

	if data.has("status"):
		print(data)
		ConsoleManager.console_update_received.emit(data)
		CommandProcessor.process_command(data)
	

func _load_mock_initial_state() -> void:
	var dir := DirAccess.open(connection_path)
	if not dir:
		push_error("MockServer: cannot open %s" % connection_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with("initial_state.json"):
			var data := _load_json(connection_path + file_name)
			_parse_initial_state_data(data)
			return
		file_name = dir.get_next()

func _load_mock_command_files() -> void:
	_files.clear()
	
	var dir := DirAccess.open(commands_path)
	if not dir:
		push_error("MockServer: cannot open %s" % commands_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_files.append(commands_path + file_name)
		file_name = dir.get_next()
	_files.sort()

func _load_json(path: String) -> Dictionary:
	var file: = FileAccess.open(path, FileAccess.READ)
	if not file: 
		print("NOFILE")
		return {}
	
	var json := JSON.new()
	return json.data if json.parse(file.get_as_text()) == OK else {}

func _parse_initial_state_data(data: Dictionary) -> void:
	if not (data.has("map") and data.has("players") and data.has("game")):
		push_error("MockServer: parsing state json has missing field")
		return

	_load_map_data_from_file(data.get("map"))
	_load_player_data_from_file(data.get("players"))
	_load_game_data_from_file(data.get("game"))
				
	return

func _load_map_data_from_file(map: Dictionary) -> void:
	if not (map.has("width") and map.has("height")) \
		or not (map.has("tiles")):
		return

	var map_size := Vector2i(map.get("width"), map.get("height"))
	GameData.map_size = map_size

	var tiles: Array = map.get("tiles")
	for raw_tile in tiles:
		var tile_pos := Vector2i(raw_tile.x, raw_tile.y)
		var tile = GameData.TileState.new(tile_pos)

		if not raw_tile.has("resources"):
			push_error("MockServer: parsed tile has no resource field")
			return
		elif not raw_tile.has("players"):
			push_error("MockServer: parsed tile has no resource player")
			return

		_parse_tile_resources_data(tile, raw_tile.get("resources"))
		_parse_tile_player_data(tile, raw_tile.get("players"))
		
		GameData.tiles[tile_pos] = tile

	return
	
func _parse_tile_resources_data(tile: GameData.TileState, resources: Dictionary) -> void:
	for r in GameConfig.RESOURCE_NAMES:
		if not resources.has(r):
			push_error("MockServer: tile resource data is missing ", r)
			return
		
		tile.resources[r] = resources[r]

	return

func _parse_tile_player_data(tile: GameData.TileState, players: Array) -> void:
	for i in range(players.size()):
		tile.player_ids.append(players[i])
	return

func _load_player_data_from_file(players: Array) -> void:
	for i in range(players.size()):
		var player: Dictionary = players[i]

		if not (player.has("id") and player.has("position") \
				and player.has("orientation") and player.has("level") \
				and player.has("team") and player.has("inventory")):
			push_error("MockServer: player field has missing sub-field")
			return

		var id: int = player.id
		var data = GameData.PlayerData.new(id)

		data.id = id
		data.pos = Vector2i( player.position.get("x"),  player.position.get("y"))
		data.orientation = player.orientation
		data.level = player.level
		data.team = player.team
		data.inventory = player.inventory
		data.status = GameConfig.PlayerStatus.NORMAL
		
		if i == 0:
			GameData.update_leader_status.emit(data.team, data.level)

		GameData.players[id] = data
	
	return

func _load_game_data_from_file(game: Dictionary) -> void:
	if not (game.has("tick") and game.has("time_unit") and game.has("teams")):
		push_error("MockServer: game data field has missing sub-fileds")
		return

	GameData.tick = game.get("tick")
	GameData.time_unit = game.get("time_unit")
	
	for i in range(game.teams.size()):
		var team: Dictionary = game.teams[i]
		GameData.teams[team.get("name")] = { "player_count": team.get("player_count"), "remaining_connections": team.get("remaining_connections")}

	return
	
func set_new_interval(new_interval: float) -> void:
	interval = new_interval

extends Node

@export var commands_path: String = "res://data/mock/"
@export var connection_path: String = commands_path + "connection/"
@export var interval: float = 0.08
@export var auto_start: bool = false

var _files: Array[String] = []
var _index: int = 0
var _timer: float = 0.0
var _running: bool = false

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
	if data.get("status", "ok") != "ok" : return
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
	print("PARSING INIT STATE")
	if data.has("map"):
		var map: Dictionary = data.get("map")
		
		if map.has("width"):
			var map_width: int = data.get("map").get("width")
			GameData.map_size.x = map_width
			print("width-X ", map_width)

		if map.has("height"):
			var map_height: int = data.get("map").get("height")
			GameData.map_size.y = map_height
			print("height-Y ", map_height)

	return

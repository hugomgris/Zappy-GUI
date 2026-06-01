extends RichTextLabel

const MAX_STORED = 30
const LINES_NORMAL = 5
const LINES_HOVERED = 10

var _message_buffer: Array[String] = []
var _is_hovered := false

func _ready() -> void:
	ConsoleManager.console_update_received.connect(_on_console_update_received)
	text = _color(_bold("HOPLAAAAA"), "#330000")
	
func _on_console_update_received(data: Dictionary) -> void:
	# parse -> build -> push
	if data.has("player_id") and data.has("cmd"):
		var player_id: int = data.get("player_id")
		var player_team: String = GameData.get_player(player_id).team
		var console_string = "[%s][%d]" % [player_team, player_id]
		var command_string = data.get("cmd")
		console_string = _bold(console_string) + ": %s" % command_string
		
		if (command_string == "prend" or command_string == "pose") && data.has("arg"):
			var arg_string = data.get("arg")
			console_string += " -> %s" % arg_string
		
		push_message(console_string)
	return

func push_message(msg: String) -> void:
	_message_buffer.append(msg)
	if _message_buffer.size() > MAX_STORED:
		_message_buffer.pop_front()
	_refresh_display()

func _refresh_display() -> void:
	var limit := LINES_HOVERED if _is_hovered else LINES_NORMAL
	var slice := _message_buffer.slice(-limit)  # last N entries
	text = "\n".join(slice)
	
func _bold(string: String) -> String:
	var bold_text: String = "[b]" + string + "[/b]"
	return bold_text
	
func _color(string: String, color: String) -> String:
	var colored_text = "[color=" + color + "]" + string + "[/color]"
	return colored_text

extends RichTextLabel

const MAX_STORED = 30
const LINES_NORMAL = 5
const LINES_HOVERED = 7
const REGULAR_FONT_SIZE = 16
const HOVERED_FONT_SIZE = 24

var _raw_messages: Array[String] = []  # Store without font size tags
var _is_hovered := false
var _current_font_size := REGULAR_FONT_SIZE

func _ready() -> void:
	text= ""
	scroll_active = false
	
	ConsoleManager.console_update_received.connect(_on_console_update_received)
	ConsoleManager.console_hovered.connect(_on_hovered)
	ConsoleManager.console_unhovered.connect(_on_unhovered)

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

		# Store raw message without font size
		push_message(console_string)
	return

func push_message(msg: String) -> void:
	_raw_messages.append(msg)
	if _raw_messages.size() > MAX_STORED:
		_raw_messages.pop_front()
	_refresh_display()

func _refresh_display() -> void:
	var limit := LINES_HOVERED if _is_hovered else LINES_NORMAL
	var slice := _raw_messages.slice(-limit)
	
	# Apply current font size when building the display text
	var display_lines = []
	for line in slice:
		display_lines.append(_scale(line, _current_font_size))
	
	text = "\n".join(display_lines)

func _on_hovered() -> void:
	_is_hovered = true
	_current_font_size = HOVERED_FONT_SIZE
	_set_to_hovered_layout()
	_refresh_display()

func _on_unhovered() -> void:
	_is_hovered = false
	_current_font_size = REGULAR_FONT_SIZE
	_set_to_regular_layout()
	_refresh_display()

func _set_to_hovered_layout() -> void:
	# awfully managed, but ask me if I care
	position.x -= 180
	position.y -= 50
	size.x += 300
	size.y += 100

func _set_to_regular_layout() -> void:
	position.x += 180
	position.y += 50
	size.x -= 300
	size.y -= 100

# Text format helpers
func _bold(string: String) -> String:
	var bold_text: String = "[b]" + string + "[/b]"
	return bold_text

func _color(string: String, color: String) -> String:
	var colored_text = "[color=" + color + "]" + string + "[/color]"
	return colored_text

func _scale(string: String, font_size: int) -> String:
	var scaled_text = "[font_size={%d}]" % font_size + string + "[/font_size]"
	return scaled_text

extends RichTextLabel

const MAX_STORED = 30
const LINES_NORMAL = 5
const LINES_HOVERED = 7
const REGULAR_FONT_SIZE = 16
const HOVERED_FONT_SIZE = 24

@onready var _animations: Node2D = $"../Animations"

var _raw_messages: Array[Dictionary] = []
var _is_hovered := false
var _current_font_size := REGULAR_FONT_SIZE
var _position_shift_x = 180
var _position_shift_y = 50
var _size_shift_x = 400
var _size_shift_y = 110

func _ready() -> void:
	z_index = _animations.z_index + 1
	text = ""
	scroll_active = false

	ConsoleManager.console_update_received.connect(_on_console_update_received)
	ConsoleManager.console_hovered.connect(_on_hovered)
	ConsoleManager.console_unhovered.connect(_on_unhovered)

func _on_console_update_received(data: Dictionary) -> void:
	if not data.has("player_id"):
		return

	var player_id: int = data.get("player_id")
	var player = GameData.get_player(player_id)
	if not player:
		push_warning("ConsoleLog: received event for unknown player_id %d" % player_id)
		return

	var player_team: String = player.team
	var player_position: Vector2i = GameData.players[player_id].pos
	var prefix: String = "[%d,%d][%s][%d]: " % [player_position.x, player_position.y, player_team, player_id]

	if data.has("cmd"):
		var command_string: String = data.get("cmd")
		var status_string: String = data.get("status", "")

		if (command_string == "prend" or command_string == "pose") and data.has("arg"):
			var arg_string: String = data.get("arg")
			push_message(prefix + "%s → %s" % [command_string, arg_string], status_string)
		elif command_string == "incantation" and status_string == "in_progress":
			push_message(prefix + "incantation", "in progress")
		elif command_string == "incantation" and status_string == "ko":
			push_message(prefix + "incantation", "ko")
		else:
			push_message(prefix + command_string, status_string)

	elif data.has("status") and data.get("status") == "level_up":
		var new_level: int = player.level
		push_message(prefix + "level up", str(new_level))

func push_message(label: String, suffix: String) -> void:
	_raw_messages.append({"label": label, "suffix": suffix})
	if _raw_messages.size() > MAX_STORED:
		_raw_messages.pop_front()
	_refresh_display()

func _refresh_display() -> void:
	var limit := LINES_HOVERED if _is_hovered else LINES_NORMAL
	var slice := _raw_messages.slice(-limit)

	var display_lines = []
	for msg in slice:
		var line: String = _occupy_cell_width(msg["label"], msg["suffix"])
		display_lines.append(TextHelper.size(TextHelper.bold(line), _current_font_size))

	text = "\n".join(display_lines)

func _occupy_cell_width(label: String, suffix: String) -> String:
	var target := 50 if _is_hovered else 38
	while label.length() < target - suffix.length():
		label += "."
	return label + suffix

func _on_hovered() -> void:
	_is_hovered = true
	_current_font_size = HOVERED_FONT_SIZE
	z_index = _animations.z_index + 1
	_set_to_hovered_layout()
	_refresh_display()

func _on_unhovered() -> void:
	z_index = _animations.z_index + 1
	_is_hovered = false
	_current_font_size = REGULAR_FONT_SIZE
	_set_to_regular_layout()
	_refresh_display()

func _set_to_hovered_layout() -> void:
	position.x -= _position_shift_x
	position.y -= _position_shift_y
	size.x += _size_shift_x
	size.y += _size_shift_y

func _set_to_regular_layout() -> void:
	position.x += _position_shift_x
	position.y += _position_shift_y
	size.x -= _size_shift_x
	size.y -= _size_shift_y

# autoloads/ServerConnectionManager.gd
extends Node

signal connection_established   # emitted after login ACK ("ok")
signal connection_failed        # emitted on any fatal transport error
signal connection_closed        # emitted when server closes gracefully
signal raw_message_received(text: String)

const SERVER_KEY := "SOME_KEY"

var _ws: WebSocketPeer = null
var _state := State.IDLE
var _ip := ""
var _port := 0

var _game_ended: bool = false

enum State { IDLE, CONNECTING, AUTHENTICATING, CONNECTED, CLOSED }

# Public API 

func connect_to_server(ip: String, port: int) -> void:
	_ip = ip
	_port = port
	_state = State.CONNECTING
	_ws = WebSocketPeer.new()
	var tls = TLSOptions.client_unsafe()        # self-signed cert on server
	var url = "wss://%s:%d" % [ip, port]
	print("[SCM] Connecting to %s" % url)
	var err = _ws.connect_to_url(url, tls)
	if err != OK:
		push_error("[SCM] connect_to_url failed: %d" % err)
		connection_failed.emit()
		_state = State.IDLE

func disconnect_from_server() -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close()
	_state = State.CLOSED

# Main loop 
func _ready() -> void:
	CommandProcessor.game_over.connect(func (winner: String) -> void:
		_game_ended = true
	)

func _process(_delta: float) -> void:
	if not _ws or _game_ended:
		return
	_ws.poll()
	_check_state()

func _check_state() -> void:
	var ws_state := _ws.get_ready_state()

	match ws_state:
		WebSocketPeer.STATE_CONNECTING:
			pass    # still waiting

		WebSocketPeer.STATE_OPEN:
			if _state == State.CONNECTING:
				print("[SCM] WebSocket open — waiting for bienvenue")
				connection_established.emit() # GOOD?
				_state = State.AUTHENTICATING
			_drain_packets()

		WebSocketPeer.STATE_CLOSING:
			pass

		WebSocketPeer.STATE_CLOSED:
			if _state != State.IDLE and _state != State.CLOSED:
				print("[SCM] Connection closed (code=%d)" % _ws.get_close_code())
				_state = State.CLOSED
				connection_closed.emit()

func _drain_packets() -> void:
	while _ws.get_available_packet_count() > 0:
		var raw := _ws.get_packet().get_string_from_utf8()
		print("[SCM] RAW ← %s" % raw)
		_on_raw_message(raw)

func _on_raw_message(text: String) -> void:
	match _state:
		State.AUTHENTICATING:
			_handle_authenticating(text)
		State.CONNECTED:
			raw_message_received.emit(text)

func _handle_authenticating(text: String) -> void:
	var j := JSON.new()
	if j.parse(text) != OK:
		return
	var d: Dictionary = j.data
	var t: String = d.get("type", "")

	if t == "bienvenue":
		print("[SCM] Got bienvenue — sending login")
		_send_login()

	elif t == "ok":
		print("[SCM] Login accepted — waiting for snapshot")
		_state = State.CONNECTED
		connection_established.emit()

	elif d.has("map"):
		# Snapshot arrived before "ok" — forward it anyway
		print("[SCM] Snapshot received early (before ok) — forwarding")
		raw_message_received.emit(text)

	elif t == "error":
		push_error("[SCM] Login rejected: %s" % str(d))
		connection_failed.emit()

func _send_login() -> void:
	var payload := JSON.stringify({
		"type": "login",
		"key":  SERVER_KEY,
		"role": "observer"
	})
	_ws.send_text(payload)
	print("[SCM] → login sent")

func _exit_tree() -> void:
	disconnect_from_server()

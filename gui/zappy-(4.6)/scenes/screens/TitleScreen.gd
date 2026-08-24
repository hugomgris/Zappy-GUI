# scenes/screens/TitleScreen.gd
extends Control

@onready var ip_field: LineEdit = $Panel/VBox/IPField
@onready var port_field: LineEdit = $Panel/VBox/PortField
@onready var connect_btn: Button = $Panel/VBox/ConnectButton
@onready var mock_btn: Button = $Panel/VBox/MockButton
@onready var status_label: Label = $Panel/VBox/StatusLabel

const MAIN_SCENE = "res://scenes/main/Main.tscn"

func _ready() -> void:
	ip_field.text = AppState.server_ip
	port_field.text = str(AppState.server_port)
	connect_btn.pressed.connect(_on_connect)
	mock_btn.pressed.connect(_on_mock)

func _on_connect() -> void:
	status_label.text = "Connecting..."
	connect_btn.disabled = true
	AppState.use_mock = false
	AppState.server_ip = ip_field.text
	AppState.server_port = int(port_field.text)
	ServerConnectionManager.connection_established.connect(_on_success, CONNECT_ONE_SHOT)
	ServerConnectionManager.connection_failed.connect(_on_fail, CONNECT_ONE_SHOT)
	ServerConnectionManager.connect_to_server(AppState.server_ip, AppState.server_port)

func _on_success() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_fail() -> void:
	status_label.text = "Connection failed. Check IP/port."
	connect_btn.disabled = false

func _on_mock() -> void:
	AppState.use_mock = true
	get_tree().change_scene_to_file(MAIN_SCENE)

# GAME CONFIG - DATA CONTAINER
extends Node

# Window
const WINDOW_SIZE := Vector2i(1080, 1080)

# MAP
const TILE_SIZE: float = 2.0
const TILE_GAP: float = 0.0

# TIMING
const MOVE_DURATION: float			= 0.25	# seconds
const ROTATE_DURATION: float			= 0.15
const PREND_DURATION: float			= 0.25
const POSE_DURATION: float			= 0.25
const INCANTATATION_DURATION: float	= 0.5
const DEATH_DURATION: float			= 0.4

# NETWORK
const WS_OBSERVER_HANDSHAKE: Dictionary = {"type": "GRAPHIC"} # sent after ws connection

# RESOURCES
const RESOURCE_NAMES: Array[String]  = [
	"nourriture", "linemate", "deraumere",
	"sibur", "mendiane", "phiras", "thystame"
]

# ENUMS
enum Orientation { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }
enum TileType { RED_LIGHT, RED_DARK }
enum PlayerStatus { NORMAL, INCANTATION, BROADCASTING, DEAD }

# TEAMS
const TEAM_COLORS: Dictionary = {
	"Alpha": Color(0.9, 0.2, 0.2),
	"Beta":  Color(0.2, 0.4, 0.9),
	"Gamma": Color(0.2, 0.8, 0.3),
	"Delta": Color(0.9, 0.8, 0.1),
	"Epsilon": Color(0.8, 0.3, 0.9),
}

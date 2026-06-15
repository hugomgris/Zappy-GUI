# autoloads/ProtocolParser.gd
extends Node

# Emitted once, after the initial snapshot is fully parsed
signal snapshot_ready

# Emitted for every subsequent event pushed by the server
signal event_received(event_type: String, data: Dictionary)

var _snapshot_received := false

# entry point

func handle(text: String) -> void:
	var j := JSON.new()
	if j.parse(text) != OK:
		push_error("[PP] JSON parse error in: %s" % text)
		return
	var d: Dictionary = j.data
	
	print("[PP] handle() — snapshot_received=%s, has_map=%s, type=%s" % [
		str(_snapshot_received), str(d.has("map")), str(d.get("type", "?"))
	])
	
	if not _snapshot_received and d.has("map") and d.has("players") and d.has("game"):
		print("parsing SNAPSHOT")
		_parse_snapshot(d)
	else:
		print("parsing event")
		_parse_event(d)

# initial snapshot processing

func _parse_snapshot(d: Dictionary) -> void:
	var map_data: Dictionary = d["map"]
	GameData.map_size = Vector2i(map_data["width"], map_data["height"])

	# Tiles
	GameData.tiles.clear()
	for tile in map_data["tiles"]:
		var pos := Vector2i(int(tile["x"]), int(tile["y"]))
		var ts := GameData.TileState.new(pos)          # ← typed object, not a dict
		var res: Dictionary = tile["resources"]
		for r in GameConfig.RESOURCE_NAMES:
			ts.resources[r] = int(res.get(r, 0))
		for pid in tile.get("players", []):
			ts.player_ids.append(int(pid))
		GameData.tiles[pos] = ts

	# Players
	GameData.players.clear()
	for p in d["players"]:
		var pid: int = int(p["id"])
		var pd := GameData.PlayerData.new(pid)         # ← typed object, not a dict
		pd.team        = str(p["team"])
		pd.pos         = Vector2i(int(p["position"]["x"]), int(p["position"]["y"]))
		pd.orientation = int(p["orientation"])
		pd.level       = int(p["level"])
		_fill_inventory(pd.inventory, p["inventory"])
		GameData.players[pid] = pd

	# Game meta
	var game_data: Dictionary = d["game"]
	GameData.tick      = int(game_data.get("tick",      0))
	GameData.time_unit = int(game_data.get("time_unit", 0))
	GameData.teams.clear()
	for t in game_data.get("teams", []):
		GameData.teams[str(t["name"])] = {
			"name":                  str(t["name"]),
			"player_count":          int(t["player_count"]),
			"remaining_connections": int(t["remaining_connections"])
		}

	_snapshot_received = true
	print("[PP] Snapshot parsed — map %s, %d players, %d tiles" % [
		str(GameData.map_size), GameData.players.size(), GameData.tiles.size()
	])
	snapshot_ready.emit()

func _fill_inventory(inv: Dictionary, src: Dictionary) -> void:
	for r in GameConfig.RESOURCE_NAMES:
		inv[r] = int(src.get(r, 0))

func _parse_inventory(inv: Dictionary) -> Dictionary:
	return {
		"nourriture": int(inv.get("nourriture", 0)),
		"linemate":   int(inv.get("linemate",   0)),
		"deraumere":  int(inv.get("deraumere",  0)),
		"sibur":      int(inv.get("sibur",      0)),
		"mendiane":   int(inv.get("mendiane",   0)),
		"phiras":     int(inv.get("phiras",     0)),
		"thystame":   int(inv.get("thystame",   0)),
	}

# Ongoing events

func _parse_event(d: Dictionary) -> void:
	var t: String = d.get("type", "unknown")
	print("[PP] Event ← type=%s" % t)
	event_received.emit(t, d)

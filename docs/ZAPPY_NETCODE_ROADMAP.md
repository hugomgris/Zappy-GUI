# Zappy GUI – Network Code Roadmap

A step-by-step implementation guide for connecting the Godot observer GUI to the real C server.

---

## Orientation: What the server actually does

Before writing a single line of GDScript, here is the complete protocol as reverse-engineered from `server.c` and `game.c`:

### Connection sequence

```
GUI  ──TCP/TLS──►  Server
                    ◄── {"type":"bienvenue","msg":"Knock knock, who's there?"}

GUI  ──────────►  {"type":"login","key":"SOME_KEY","role":"observer"}
                    ◄── {"type":"ok","msg":"Observer registered"}     (login ACK)
                    ◄── <full game state JSON>                        (snapshot, sent immediately by game_register_observer)

GUI (polling)   ◄── <event JSON> …                                   (ongoing updates)
```

### Login payload

```json
{ "type": "login", "key": "SOME_KEY", "role": "observer" }
```

`"SOME_KEY"` is the literal string defined as `SERVER_KEY` in `server.c`.

### Initial game-state snapshot (sent right after login ACK)

Produced by `m_serialize_server()` in `game.c`:

```json
{
  "map": {
    "width": <int>,
    "height": <int>,
    "tiles": [
      {
        "x": <int>, "y": <int>,
        "resources": {
          "nourriture": <int>, "linemate": <int>, "deraumere": <int>,
          "sibur": <int>, "mendiane": <int>, "phiras": <int>, "thystame": <int>
        },
        "players": [ <player_id>, … ]
      },
      …
    ]
  },
  "players": [
    {
      "id": <int>,
      "position": { "x": <int>, "y": <int> },
      "orientation": <0-3>,
      "level": <int>,
      "team": "<string>",
      "inventory": { … }
    },
    …
  ],
  "game": {
    "tick": <int>,
    "time_unit": <int>,
    "teams": [
      { "name": "<string>", "player_count": <int>, "remaining_connections": <int> },
      …
    ]
  }
}
```

### Ongoing event messages (pushed to observer by `m_server_notify_observers`)

These are sent whenever a player command resolves:

```json
{ "type": "response", "cmd": "<command_name>", "arg": "…", "status": "ok|ko", "player_id": <int> }
```

Special push messages (via `server_create_response_msg`):

```json
{ "type": "message",   "arg": "<broadcast_text>", "status": "<direction_K>", "player_id": <int> }
{ "type": "event",     "status": "level_up|incantation_start",                "player_id": <int> }
{ "type": "game_end",  "winner_team": "<string>", "winner_team_id": <int> }
```

### Important transport note

The server uses **real TLS** via its `ssl_al` layer (wrapping OpenSSL). You must connect with `TLSOptions.client_unsafe()` because the server uses a self-signed certificate. This is exactly what the old `ServerConnectionManager` did and it must be kept.

---

## Architecture plan

```
TitleScreen.gd
  └─ calls ServerConnectionManager.connect_to_server(ip, port)

ServerConnectionManager (autoload)         ← owns the WebSocketPeer, drives poll()
  │  signals: connection_established, connection_failed, connection_closed
  └─ emits raw_message_received(text: String)

ProtocolParser (autoload)                  ← pure parsing, no I/O
  │  called by Main.gd with each raw message
  └─ returns structured data / emits typed signals

Main.gd
  └─ connects raw_message_received → ProtocolParser.handle()
     connects ProtocolParser signals → GameData / WorldManager
```

`ProtocolParser` stays side-effect-free (easy to unit-test with mock strings).  
`ServerConnectionManager` stays transport-only (easy to swap or stub).

---

## Phase 1 – Bare TCP/TLS handshake

**Goal:** See the server's `bienvenue` message in the Godot console. No game logic yet.

### 1.1 – Write `ServerConnectionManager.gd`

```gdscript
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

enum State { IDLE, CONNECTING, AUTHENTICATING, CONNECTED, CLOSED }

# ── Public API ────────────────────────────────────────────────────────────────

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

# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
    if not _ws:
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
        # login ACK — next message(s) will be the game snapshot
        print("[SCM] Login accepted — waiting for snapshot")
        _state = State.CONNECTED
        # The snapshot arrives as the very next message; we stay in CONNECTED
        # and let _drain_packets forward it via raw_message_received.
        # BUT: the server may have already queued it in the same recv burst,
        # so we immediately fall through to CONNECTED handling.

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
```

### 1.2 – Wire TitleScreen signals

`TitleScreen.gd` already calls `ServerConnectionManager.connect_to_server(…)`.  
Make sure `_on_success` only fires on `connection_established`:

```gdscript
# In TitleScreen._on_connect():
ServerConnectionManager.connection_established.connect(_on_success, CONNECT_ONE_SHOT)
ServerConnectionManager.connection_failed.connect(_on_fail, CONNECT_ONE_SHOT)
ServerConnectionManager.connect_to_server(AppState.server_ip, AppState.server_port)
```

### ✅ Testable checkpoint 1

Start the real server. Press **Connect** in the GUI.  
Expected console output:
```
[SCM] Connecting to wss://127.0.0.1:8674
[SCM] WebSocket open — waiting for bienvenue
[SCM] RAW ← {"type":"bienvenue","msg":"Knock knock, who's there?"}
[SCM] Got bienvenue — sending login
[SCM] → login sent
[SCM] RAW ← {"type":"ok","msg":"Observer registered"}
[SCM] Login accepted — waiting for snapshot
[SCM] RAW ← {"map":{…},"players":[…],"game":{…}}
```

If you see `bienvenue` but not `ok`, the key or role is wrong.  
If the WebSocket closes immediately, the TLS certificate is rejected — confirm you are using `TLSOptions.client_unsafe()`.

---

## Phase 2 – Parse the initial snapshot

**Goal:** Populate `GameData` from the real server snapshot and emit `world_initialized`.

### 2.1 – Write `ProtocolParser.gd`

```gdscript
# autoloads/ProtocolParser.gd
extends Node

# Emitted once, after the initial snapshot is fully parsed
signal snapshot_ready

# Emitted for every subsequent event pushed by the server
signal event_received(event_type: String, data: Dictionary)

var _snapshot_received := false

# ── Entry point ───────────────────────────────────────────────────────────────

func handle(text: String) -> void:
    var j := JSON.new()
    if j.parse(text) != OK:
        push_error("[PP] JSON parse error in: %s" % text)
        return
    var d: Dictionary = j.data

    if not _snapshot_received and d.has("map") and d.has("players") and d.has("game"):
        _parse_snapshot(d)
    else:
        _parse_event(d)

# ── Snapshot ──────────────────────────────────────────────────────────────────

func _parse_snapshot(d: Dictionary) -> void:
    var map_data: Dictionary = d["map"]
    GameData.map_size = Vector2i(map_data["width"], map_data["height"])

    # Tiles
    GameData.tiles.clear()
    for tile in map_data["tiles"]:
        var pos := Vector2i(int(tile["x"]), int(tile["y"]))
        var res: Dictionary = tile["resources"]
        GameData.tiles[pos] = {
            "resources": {
                "nourriture": int(res.get("nourriture", 0)),
                "linemate":   int(res.get("linemate",   0)),
                "deraumere":  int(res.get("deraumere",  0)),
                "sibur":      int(res.get("sibur",      0)),
                "mendiane":   int(res.get("mendiane",   0)),
                "phiras":     int(res.get("phiras",     0)),
                "thystame":   int(res.get("thystame",   0)),
            },
            "player_ids": Array(tile.get("players", []))
        }

    # Players
    GameData.players.clear()
    for p in d["players"]:
        var pid: int = int(p["id"])
        GameData.players[pid] = {
            "id":          pid,
            "position":    Vector2i(int(p["position"]["x"]), int(p["position"]["y"])),
            "orientation": int(p["orientation"]),
            "level":       int(p["level"]),
            "team":        str(p["team"]),
            "inventory":   _parse_inventory(p["inventory"])
        }

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

# ── Ongoing events ────────────────────────────────────────────────────────────

func _parse_event(d: Dictionary) -> void:
    var t: String = d.get("type", "unknown")
    print("[PP] Event ← type=%s" % t)
    event_received.emit(t, d)
```

### 2.2 – Ensure `GameData` has the necessary fields

Check your `GameData` autoload and confirm these properties exist (add any that are missing):

```gdscript
# In GameData.gd (add if not present)
var map_size   := Vector2i.ZERO
var tiles      := {}      # Vector2i → Dictionary
var players    := {}      # int (id) → Dictionary
var teams      := {}      # String (name) → Dictionary
var tick       := 0
var time_unit  := 0
signal world_initialized
```

### 2.3 – Wire everything in `Main.gd`

Replace the mock block in `Main._ready()`:

```gdscript
func _ready() -> void:
    TooltipManager.initialize($PostProcessing/Compositor/Tooltips)
    GameData.world_initialized.connect(_on_world_initialized, CONNECT_ONE_SHOT)

    if AppState.use_mock:
        MockServer.build_mock_initial_game_state()
        MockServer.start()
        GameData.world_initialized.emit()
    else:
        # Wire real server pipeline
        ServerConnectionManager.raw_message_received.connect(
            ProtocolParser.handle
        )
        ServerConnectionManager.connection_established.connect(
            _on_server_connection_established, CONNECT_ONE_SHOT
        )
        ProtocolParser.snapshot_ready.connect(_on_snapshot_ready, CONNECT_ONE_SHOT)
        ProtocolParser.event_received.connect(_on_server_event)

func _on_server_connection_established() -> void:
    print("[Main] Connection established — snapshot incoming")

func _on_snapshot_ready() -> void:
    print("[Main] Snapshot ready — firing world_initialized")
    GameData.world_initialized.emit()

func _on_server_event(event_type: String, data: Dictionary) -> void:
    # Placeholder — Phase 3 will flesh this out
    print("[Main] Server event: %s" % event_type)
```

> **Note on signal sequencing:** `connection_established` is currently never emitted by `ServerConnectionManager` in the Phase 1 code above. You have two options:
> - Emit it from `ServerConnectionManager._handle_authenticating` when `t == "ok"`.  
> - Or skip it entirely for the real-server path and let `ProtocolParser.snapshot_ready` drive `world_initialized`.
>
> The simplest approach for now: emit `connection_established` inside `_handle_authenticating` when `t == "ok"`, right before setting `_state = State.CONNECTED`.

### ✅ Testable checkpoint 2

Start server with a map and at least one player connected. Press **Connect**.  
Expected:
- World renders exactly as it does with the mock
- Console shows `[PP] Snapshot parsed — map (W, H), N players, T tiles`
- If the map doesn't appear: add `print(GameData.map_size)` and `print(GameData.tiles.size())` inside `_on_snapshot_ready` to verify data reached GameData

---

## Phase 3 – Live event handling

**Goal:** React to ongoing server pushes so the world stays in sync with the game.

The server sends observer updates via `m_server_notify_observers`, which is called from `server_create_response_to_command` every time any player command resolves.

### 3.1 – Identify the events you need to handle

| `type` field | When sent | What to update |
|---|---|---|
| `"response"` | Every player command result | Player position, inventory, level |
| `"event"` with `status: "level_up"` | Player levelled up | Player level |
| `"event"` with `status: "incantation_start"` | Incantation beginning | Visual effect on tile |
| `"message"` | Broadcast by a player | Optionally show in UI |
| `"game_end"` | Winner condition met | Show winner screen |

### 3.2 – Extend `ProtocolParser._parse_event`

```gdscript
func _parse_event(d: Dictionary) -> void:
    var t: String = d.get("type", "unknown")

    match t:
        "response":
            _handle_response(d)
        "event":
            _handle_game_event(d)
        "message":
            event_received.emit("broadcast", d)
        "game_end":
            event_received.emit("game_end", d)
        _:
            print("[PP] Unknown event type: %s" % t)

func _handle_response(d: Dictionary) -> void:
    var cmd: String    = d.get("cmd", "")
    var pid: int       = int(d.get("player_id", -1))
    var status: String = d.get("status", "")

    if pid < 0 or not GameData.players.has(pid):
        return

    match cmd:
        "avance":
            if status == "ok":
                _request_player_position_update(pid)
        "droite", "gauche":
            if status == "ok":
                _request_player_orientation_update(pid)
        "prend", "pose":
            if status == "ok":
                _request_tile_update(pid)
        "incantation":
            if status == "ok":
                # level already updated server-side; rely on level_up event
                pass

    event_received.emit("response", d)

func _handle_game_event(d: Dictionary) -> void:
    var status: String = d.get("status", "")
    var pid: int       = int(d.get("player_id", -1))
    match status:
        "level_up":
            if pid >= 0 and GameData.players.has(pid):
                GameData.players[pid]["level"] += 1
            event_received.emit("level_up", d)
        "incantation_start":
            event_received.emit("incantation_start", d)
```

> **On position tracking:** The server does not push a "player moved to (x,y)" message to observers — it only notifies that `avance` resolved with `ok`. To know the new position you have two options:
> 1. **Re-request the full snapshot** periodically (simplest, no server changes needed).
> 2. **Track movement locally** by maintaining orientation and advancing the position yourself.
>
> Option 1 is recommended for a first working version.

### 3.3 – Periodic snapshot refresh (simplest sync strategy)

In `ServerConnectionManager`, add a timer that re-requests the full snapshot. The server sends it automatically on observer registration, but you can trigger a re-sync by… there is no "refresh" command in the current protocol. The cleanest approach without modifying the server is to track state incrementally.

**Practical recommendation for 42 eval:** Request a fresh snapshot by disconnecting and reconnecting as observer, or implement incremental tracking as described in 3.2 above. For a basic eval pass, the event log is sufficient — the world state after the initial snapshot is kept up-to-date by handling `avance`/`droite`/`gauche` events locally.

### 3.4 – Wire events to WorldManager in `Main.gd`

```gdscript
func _on_server_event(event_type: String, data: Dictionary) -> void:
    match event_type:
        "level_up":
            var pid := int(data.get("player_id", -1))
            _refresh_player_display(pid)
        "game_end":
            _show_game_end(data.get("winner_team", "?"))
        "response":
            var cmd: String = data.get("cmd", "")
            var pid := int(data.get("player_id", -1))
            if cmd in ["avance", "droite", "gauche"]:
                _refresh_player_display(pid)

func _refresh_player_display(pid: int) -> void:
    # Hook into your PlayerController / WorldManager as appropriate
    pass

func _show_game_end(winner: String) -> void:
    print("GAME OVER — Winner: %s" % winner)
    # Show your win screen
```

### ✅ Testable checkpoint 3

While the GUI is connected, trigger player actions from the CLI client. Verify:
- Player move commands result in `[PP] Event ← type=response` log lines
- `level_up` events appear when incantation completes
- `game_end` appears when a team wins

---

## Phase 4 – Robustness and edge cases

These are the things that will bite you during the 42 eval.

### 4.1 – Handle the snapshot/event ordering problem

The server sends the login ACK (`"ok"`) and then immediately the snapshot in the same TCP burst. Your WebSocket drain loop processes them packet-by-packet, but they may arrive in a single `recv()` call split across WebSocket frames. The `_drain_packets` loop in Phase 1 already handles this correctly — just confirm that `_handle_authenticating` transitions state to `CONNECTED` _before_ falling through to drain remaining packets. The current structure does this because `_drain_packets` is called in a loop for every `_process` tick.

### 4.2 – Connection timeout UI

```gdscript
# In ServerConnectionManager.connect_to_server():
_timeout_timer = get_tree().create_timer(10.0)
_timeout_timer.timeout.connect(func():
    if _state == State.CONNECTING or _state == State.AUTHENTICATING:
        push_error("[SCM] Connection timed out")
        connection_failed.emit()
        _state = State.IDLE
)
```

### 4.3 – Reconnect on unexpected close

```gdscript
# In ServerConnectionManager, when STATE_CLOSED is detected:
if _state == State.CONNECTED:
    connection_closed.emit()
    # Optionally: auto-reconnect after a delay
```

### 4.4 – Keep `AppState` clean between attempts

If the user presses Connect, fails, and tries again, make sure `ProtocolParser._snapshot_received` is reset. Add a `reset()` method to `ProtocolParser`:

```gdscript
func reset() -> void:
    _snapshot_received = false
```

And call it from `TitleScreen._on_connect()` or `ServerConnectionManager.connect_to_server()`.

---

## Phase 5 – Cleanup and final wiring

### 5.1 – `AppState` autoload

Make sure these exist (you referenced them in TitleScreen):

```gdscript
# autoloads/AppState.gd
extends Node
var server_ip   := "127.0.0.1"
var server_port := 8674
var use_mock    := false
```

### 5.2 – Scene transition safety

In `TitleScreen._on_success()`, the scene changes to `Main.tscn`. Since `ServerConnectionManager` is an autoload, its WebSocket connection and `_process` loop persist across scene changes. That's what you want. Just make sure `Main._ready()` doesn't try to re-connect — it should only wire signals to the already-connected manager.

### 5.3 – Final `ServerConnectionManager` signal: emit `connection_established`

Add this to `_handle_authenticating` in the `"ok"` branch:

```gdscript
elif t == "ok":
    print("[SCM] Login accepted")
    _state = State.CONNECTED
    connection_established.emit()   # ← this triggers TitleScreen scene change
```

The snapshot will arrive on the very next (or same) `_process` tick and be forwarded via `raw_message_received` → `ProtocolParser.handle()` → `snapshot_ready` → `GameData.world_initialized`.

---

## Summary: implementation order

| Step | File | What you write |
|------|------|----------------|
| 1 | `ServerConnectionManager.gd` | Full WebSocket + TLS + login handshake |
| 2 | `ProtocolParser.gd` | `handle()` + `_parse_snapshot()` |
| 3 | `GameData.gd` | Add any missing fields |
| 4 | `Main.gd` | Wire signals for real-server path |
| 5 | Test checkpoint 1 & 2 | Confirm bienvenue → login → snapshot → world render |
| 6 | `ProtocolParser._parse_event()` | Handle response/event/game_end |
| 7 | `Main._on_server_event()` | Update WorldManager from events |
| 8 | Test checkpoint 3 | Confirm live updates work |
| 9 | Timeout + reconnect | Phase 4 robustness |

---

## Quick reference: full message taxonomy

```
Server → GUI (unsolicited, always JSON)
──────────────────────────────────────
{"type":"bienvenue", "msg":"…"}                        connection welcome
{"type":"ok",        "msg":"Observer registered"}      login ACK
{"type":"error",     "msg":"…"}                        login rejected
{…full snapshot…}                                      sent by game_register_observer
{"type":"response",  "cmd":"avance", "status":"ok", "player_id":N}   player command result
{"type":"event",     "status":"level_up",            "player_id":N}   level change
{"type":"event",     "status":"incantation_start",   "player_id":N}   incantation
{"type":"message",   "arg":"<text>", "status":"<K>", "player_id":N}   broadcast
{"type":"game_end",  "winner_team":"<name>", "winner_team_id":N}       game over

GUI → Server
────────────
{"type":"login", "key":"SOME_KEY", "role":"observer"}   (only message GUI ever sends)
```

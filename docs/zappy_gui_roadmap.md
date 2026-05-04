# Zappy GUI — From-Scratch Rebuild Roadmap
### Godot 4 · GDScript · 3D Observer Client

---

> **How to read this document**
>
> This is a sequential, opinionated build plan. Each phase produces something
> runnable before the next one begins. The goal is twofold: ship a working
> Zappy GUI, and rebuild your Godot 4 fluency through deliberate practice.
> Every major architectural decision is explained, not just stated.
>
> Estimated total: **8–12 focused days** depending on how deep you go on polish.

---

## Before You Write a Line of Code

### What you're building

A **read-only observer client** for a running Zappy game. It connects to the
server, receives the full game state, renders a 3D arena, and visualizes every
event in real time — player movement, resource changes, incantations, deaths,
and the end of the game. It never sends game commands to the server.

### Key constraints to keep in mind throughout

- The Zappy server speaks **WebSocket**, and messages are **JSON objects**.
  Every architectural decision around networking flows from this.
- The map is **toroidal** — players who walk off one edge appear on the
  opposite edge. Movement animations must handle this.
- The server's **time unit `t`** controls how fast the game runs. At `t=100`,
  one time unit takes 10ms. At `t=1`, it takes 1 second. Your visual timing
  must adapt to this.
- You are building a **spectator tool**, not a game. Prioritize readability
  and clarity over spectacle.

### Technology decisions (and why)

| Decision | Choice | Reason |
|---|---|---|
| Engine | Godot 4.x | Signals, typed GDScript, native TCP, great 3D |
| Language | GDScript (typed) | Fastest iteration; type hints catch bugs early |
| Camera | Orthographic, axonometric | Classic RTS readability; already validated in prototype |
| Networking | `WebSocketPeer` | The server speaks WebSocket over TCP; messages are JSON |
| State management | Autoload singleton (`GameData`) | Single source of truth; all managers read from it |
| Scene architecture | One scene per logical object | Tiles, players, resources are each their own `.tscn` |
| UI approach | `CanvasLayer` HUD + hover tooltips | HUD is always visible; tooltips are contextual |

---

## Project Setup

### Folder structure

Create this structure before writing any scripts. Consistent organization is
the single best thing you can do for a Godot project you'll return to.

```
res://
├── assets/
│   ├── models/          # Imported .glb files (tiles, players, resources, eggs)
│   └── textures/        # Textures, HDRIs
├── materials/
│   ├── shaders/         # .gdshader files
│   └── *.tres           # Material resources
├── scenes/
│   ├── main/
│   │   ├── Main.tscn
│   │   └── Main.gd
│   ├── world/
│   │   ├── tiles/       # tile_base.tscn, tile_arch_01.tscn, etc.
│   │   └── environment/ # enviro.tscn, WorldEnvironment
│   ├── entities/
│   │   ├── players/     # One .tscn per team character
│   │   ├── resources/   # One .tscn per resource type + egg
│   │   └── effects/     # Incantation, broadcast, death VFX
│   ├── ui/
│   │   ├── hud/         # HUD.tscn, HUD.gd
│   │   ├── tooltips/    # TileTooltip.tscn, PlayerTooltip.tscn, etc.
│   │   └── screens/     # ConnectionScreen.tscn, EndScreen.tscn
│   └── camera/
│       └── CameraRig.tscn
├── scripts/
│   ├── autoloads/       # GameData.gd, CommandProcessor.gd, etc.
│   └── utils/           # Pure utility scripts (no Node dependency)
└── data/
    └── mock/            # Mock server JSON files for development
```

### Autoloads to register immediately

Go to `Project → Project Settings → Autoload` and register these in this
order. The order matters because later autoloads can safely reference earlier
ones in `_ready()`.

| Autoload name | File | Purpose |
|---|---|---|
| `GameConfig` | `scripts/autoloads/GameConfig.gd` | Constants and enums |
| `GameData` | `scripts/autoloads/GameData.gd` | Single source of truth for game state |
| `CommandProcessor` | `scripts/autoloads/CommandProcessor.gd` | Translates commands into signals |
| `MockServer` | `scripts/autoloads/MockServer.gd` | Development-only fake server |

`ServerConnectionManager` and `ProtocolParser` are **not** autoloads — they
are instantiated by `Main.gd` and live in the scene tree. The distinction:
autoloads exist for the entire application lifetime; connection managers should
be destroyable and recreatable on reconnect.

---

## Phase 0 — Foundation (Day 1)
*Goal: A running project with correct architecture in place and nothing else.*

This phase produces an empty 3D scene with a working camera and a confirmed
autoload chain. Nothing visible yet — but every subsequent phase builds on
this, so getting it right matters.

### 0.1 — GameConfig

`GameConfig.gd` is a **pure data container**. No logic, no node references,
no `_ready()`. It exists so magic numbers and strings never appear in other
files.

```gdscript
# scripts/autoloads/GameConfig.gd
extends Node

# --- Map ---
const TILE_SIZE: float = 1.0
const TILE_GAP: float = 0.0   # Set to 0.05 later if you want visible separation

# --- Timing ---
const MOVE_DURATION: float = 0.25     # seconds per tile move tween
const ROTATE_DURATION: float = 0.15   # seconds per 90° rotation tween
const DEATH_DURATION: float = 0.4

# --- Network ---
const WS_OBSERVER_HANDSHAKE: Dictionary = {"type": "GRAPHIC"}  # sent after WS connection

# --- Resources ---
const RESOURCE_NAMES: Array[String] = [
    "nourriture", "linemate", "deraumere",
    "sibur", "mendiane", "phiras", "thystame"
]

# --- Enums ---
enum Orientation { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }
enum TileType { BASIC, ARCH_1F, ARCH_2F, ARCH_3F }
enum PlayerStatus { NORMAL, INCANTATION, BROADCASTING, DEAD }

# --- Teams (extend as needed) ---
const TEAM_COLORS: Dictionary = {
    "Alpha": Color(0.9, 0.2, 0.2),
    "Beta":  Color(0.2, 0.4, 0.9),
    "Gamma": Color(0.2, 0.8, 0.3),
    "Delta": Color(0.9, 0.8, 0.1),
    "Epsilon": Color(0.8, 0.3, 0.9),
}
```

**Godot practice note:** Autoloads that `extend Node` but never use the node
lifecycle (`_ready`, `_process`, etc.) are sometimes better as `extends
RefCounted`. However, `extends Node` keeps them consistent with other autoloads
and lets you add lifecycle methods later without refactoring. Use `Node` here.

### 0.2 — GameData

`GameData.gd` is the **single source of truth** for all game state. It holds
the data; it does not build visuals, move players, or interpret commands. Other
systems read from it and react to its signals.

```gdscript
# scripts/autoloads/GameData.gd
extends Node

# --- State ---
var map_size: Vector2i = Vector2i.ZERO
var time_unit: int = 100
var tick: int = 0
var teams: Dictionary = {}   # team_name -> { player_count, connections }
var tiles: Dictionary = {}   # Vector2i -> TileData
var players: Dictionary = {} # int (id) -> PlayerData
var eggs: Dictionary = {}    # int (id) -> EggData

# --- Signals ---
# Emitted once when the initial full state burst is complete
signal world_initialized
# Emitted when individual entities change
signal tile_changed(pos: Vector2i)
signal player_changed(id: int)
signal player_removed(id: int)
signal egg_added(id: int)
signal egg_removed(id: int)
signal team_changed(name: String)
signal tick_updated(tick: int)
signal time_unit_changed(t: int)
signal game_over(winning_team: String)

# --- Inner classes for typed data ---
class TileState:
    var pos: Vector2i
    var resources: Dictionary  # resource_name -> int
    var player_ids: Array[int]
    var egg_ids: Array[int]

    func _init(p: Vector2i) -> void:
        pos = p
        resources = {}
        for r in GameConfig.RESOURCE_NAMES:
            resources[r] = 0
        player_ids = []
        egg_ids = []

class PlayerData:
    var id: int
    var team: String
    var pos: Vector2i
    var orientation: int  # GameConfig.Orientation
    var level: int
    var inventory: Dictionary
    var status: GameConfig.PlayerStatus

    func _init(pid: int) -> void:
        id = pid
        inventory = {}
        for r in GameConfig.RESOURCE_NAMES:
            inventory[r] = 0
        status = GameConfig.PlayerStatus.NORMAL

class EggData:
    var id: int
    var layer_id: int
    var team: String
    var pos: Vector2i

# --- Accessors ---
func get_tile(pos: Vector2i) -> TileState:
    return tiles.get(pos)

func get_player(id: int) -> PlayerData:
    return players.get(id)

func get_egg(id: int) -> EggData:
    return eggs.get(id)
```

**Why inner classes?** GDScript inner classes give you typed data containers
without needing separate files. They're much safer than raw `Dictionary` access
— a typo in `player.positoin` is caught at parse time; a typo in
`player["positoin"]` silently returns `null`. Use them for all data models.

### 0.3 — Scene architecture rule

Establish this rule now and follow it consistently: **every scene has exactly
one "root" script that owns that scene's behavior**. Scripts never reach into
sibling scenes. Communication always goes upward via signals or through the
autoload layer (`GameData`, `CommandProcessor`).

The scene tree hierarchy:

```
Main (Node3D)          ← orchestrator, owns managers
├── WorldRoot          ← parent for all tile instances
├── EntityRoot         ← parent for players, eggs
├── Camera             ← CameraRig scene instance
├── HUD                ← CanvasLayer, always visible
└── ConnectionScreen   ← CanvasLayer, shown before connection
```

`Main.gd` instantiates managers as child nodes, not as autoloads. This keeps
the autoload list minimal and makes the managers restartable (important for
reconnection).

### 0.4 — First runnable milestone

Create `Main.tscn` with a `WorldEnvironment`, a `DirectionalLight3D`, and your
`CameraRig.tscn` instance. Run the project. You should see a lit, empty 3D
viewport. If `GameConfig.TILE_SIZE` prints correctly from `Main.gd`'s
`_ready()`, your autoload chain is working.

---

## Phase 1 — Camera Rig (Day 1–2)
*Goal: A fully controllable axonometric camera before any world content exists.*

Build the camera in isolation. Testing it on an empty scene forces you to get
the math right without visual distractions.

### Scene structure

```
CameraRig (Node3D)          ← moves horizontally; this is what you pan
└── Pitch (Node3D)          ← rotates on X axis (isometric angle ~30°)
    └── ZoomArm (Node3D)    ← translates on Z; this is what you zoom
        └── Camera3D        ← the actual camera, set to Orthogonal projection
```

This three-node rig separates concerns cleanly: panning never affects pitch,
pitch never affects zoom. Each node does exactly one thing.

### CameraRig.gd — key decisions

**Orthographic projection.** Set `Camera3D.projection = PROJECTION_ORTHOGONAL`
and control scale via `Camera3D.size`. Orthographic gives the classic isometric
look and means zoom is linear (doubling `size` shows twice as much world).

**Lerped movement.** Never set `position` or `size` directly in response to
input. Instead, maintain a `_target` for each controlled value and lerp toward
it every frame. This gives smooth, readable motion.

```python
# scenes/camera/CameraRig.gd
extends Node3D

@onready var _pitch: Node3D = $Pitch
@onready var _zoom_arm: Node3D = $Pitch/ZoomArm
@onready var _camera: Camera3D = $Pitch/ZoomArm/Camera3D

@export var move_speed: float = 8.0
@export var zoom_speed: float = 2.0
@export var lerp_speed: float = 12.0
@export var pitch_angle_deg: float = 30.0
@export var initial_yaw_deg: float = 45.0

var _pos_target: Vector3 = Vector3.ZERO
var _size_target: float = 10.0
var _yaw_target: float = 0.0
var _bounds: Rect2 = Rect2()
var _initialized: bool = false

func _ready() -> void:
    _pitch.rotation_degrees.x = -pitch_angle_deg
    rotation_degrees.y = initial_yaw_deg
    _yaw_target = deg_to_rad(initial_yaw_deg)
    _camera.projection = Camera3D.PROJECTION_ORTHOGONAL

func initialize_for_map(size: Vector2i) -> void:
    var spacing: float = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
    var center := Vector3((size.x - 1) * spacing * 0.5, 0.0,
                           (size.y - 1) * spacing * 0.5)
    var span: float = max(size.x, size.y) * spacing

    position = center
    _pos_target = center
    _size_target = span * 0.7
    _camera.size = _size_target

    var pad: float = span * 0.5
    _bounds = Rect2(center.x - span - pad, center.z - span - pad,
                    span * 2.0 + pad * 2.0, span * 2.0 + pad * 2.0)
    _initialized = true

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _size_target = max(2.0, _size_target - zoom_speed)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _size_target = min(60.0, _size_target + zoom_speed)

    if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
        var drag := event.relative * 0.02
        _pos_target += Vector3(-drag.x, 0.0, -drag.y).rotated(Vector3.UP, rotation.y)

func _process(delta: float) -> void:
    if not _initialized:
        return
    _handle_keyboard(delta)
    _apply_lerp(delta)

func _handle_keyboard(delta: float) -> void:
    var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if dir != Vector2.ZERO:
        var world_dir := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, rotation.y)
        _pos_target += world_dir * move_speed * delta

    if Input.is_action_just_pressed("rotate_left"):   # Q
        _yaw_target -= PI * 0.5
    if Input.is_action_just_pressed("rotate_right"):  # E
        _yaw_target += PI * 0.5

func _apply_lerp(delta: float) -> void:
    var t: float = clamp(lerp_speed * delta, 0.0, 1.0)

    # Clamp to bounds
    _pos_target.x = clamp(_pos_target.x, _bounds.position.x,
                            _bounds.position.x + _bounds.size.x)
    _pos_target.z = clamp(_pos_target.z, _bounds.position.y,
                            _bounds.position.y + _bounds.size.y)

    position = position.lerp(_pos_target, t)
    rotation.y = lerp_angle(rotation.y, _yaw_target, t)
    _camera.size = lerpf(_camera.size, _size_target, t)

func focus_on(world_pos: Vector3) -> void:
    _pos_target = Vector3(world_pos.x, 0.0, world_pos.z)
```

**Input map:** Add these actions in `Project → Project Settings → Input Map`:
`rotate_left` (Q), `rotate_right` (E). Keep movement on the default arrow keys
and WASD via `ui_left/right/up/down`. Middle-mouse drag is handled directly in
`_unhandled_input`.

**Milestone:** The camera should smoothly pan, zoom, and snap-rotate 90° on
an empty scene before you move to Phase 2.

---

## Phase 2 — World Generation (Days 2–3)
*Goal: Given a map size, build a 3D grid of tiles with the correct visual pattern.*

### 2.1 — Tile scenes

Each tile type is a standalone scene in `scenes/world/tiles/`. The root is an
`Area3D` (not a `Node3D`) — this is what enables mouse hover detection. The
`Area3D` contains the 3D mesh and a `CollisionShape3D`.

```
tile_base.tscn
└── Area3D  (root, script: TileController.gd)
    ├── MeshInstance3D      ← visual mesh
    ├── CollisionShape3D    ← for mouse picking; BoxShape3D is fine
    └── ResourceSlots       ← Node3D, parent for resource instances
        ├── Marker3D_0 ... Marker3D_7   ← 8 resource anchor points
    └── PlayerSlots
        ├── Marker3D_P0 ... Marker3D_P3 ← 4 player anchor points
```

Use `BoxShape3D` for the collision, not `ConcavePolygonShape3D`. Mouse picking
only needs the approximate footprint, and a box is orders of magnitude cheaper
to compute. Reserve complex collision shapes for physics.

**TileController.gd** owns this tile's visual state:

```gdscript
# scenes/world/tiles/TileController.gd
extends Area3D

var grid_pos: Vector2i
var _resource_slots: Array[Marker3D] = []
var _player_slots: Array[Marker3D] = []
var _slot_occupied: Array[bool] = []
var _player_slot_occupied: Array[bool] = []

signal hovered(pos: Vector2i)
signal unhovered(pos: Vector2i)

func _ready() -> void:
    mouse_entered.connect(func(): hovered.emit(grid_pos))
    mouse_exited.connect(func(): unhovered.emit(grid_pos))
    # Populate slot arrays from child Marker3D nodes at runtime
    _resource_slots = _collect_markers("ResourceSlots")
    _player_slots   = _collect_markers("PlayerSlots")
    _slot_occupied       = _slot_occupied.duplicate()
    _slot_occupied.resize(_resource_slots.size())
    _slot_occupied.fill(false)
    _player_slot_occupied = _player_slot_occupied.duplicate()
    _player_slot_occupied.resize(_player_slots.size())
    _player_slot_occupied.fill(false)

func setup(pos: Vector2i) -> void:
    grid_pos = pos

func get_free_resource_slot() -> int:
    return _slot_occupied.find(false)

func occupy_resource_slot(index: int, scene: Node3D) -> void:
    _slot_occupied[index] = true
    _resource_slots[index].add_child(scene)

func free_resource_slot(index: int) -> void:
    _slot_occupied[index] = false
    for child in _resource_slots[index].get_children():
        child.queue_free()

func get_free_player_slot() -> int:
    return _player_slot_occupied.find(false)

func occupy_player_slot(index: int, scene: Node3D) -> void:
    _player_slot_occupied[index] = true
    _player_slots[index].add_child(scene)

func free_player_slot_for(scene: Node3D) -> void:
    for i in _player_slots.size():
        if _player_slots[i].get_child_count() > 0 and _player_slots[i].get_child(0) == scene:
            _player_slot_occupied[i] = false
            return

func _collect_markers(parent_name: String) -> Array[Marker3D]:
    var result: Array[Marker3D] = []
    var parent := get_node_or_null(parent_name)
    if not parent:
        return result
    for child in parent.get_children():
        if child is Marker3D:
            result.append(child)
    return result
```

### 2.2 — WorldManager

`WorldManager.gd` is a scene-level script (not an autoload) attached to a
`Node3D` called `WorldRoot` in `Main.tscn`. It owns all tile instances.

```gdscript
# scenes/main/WorldManager.gd
extends Node3D

var _tiles: Dictionary = {}   # Vector2i -> TileController
var _tile_scenes: Dictionary  # TileType -> PackedScene

func _ready() -> void:
    _tile_scenes = {
        GameConfig.TileType.BASIC:   preload("res://scenes/world/tiles/tile_base.tscn"),
        GameConfig.TileType.ARCH_1F: preload("res://scenes/world/tiles/tile_arch_01.tscn"),
        GameConfig.TileType.ARCH_2F: preload("res://scenes/world/tiles/tile_arch_02.tscn"),
        GameConfig.TileType.ARCH_3F: preload("res://scenes/world/tiles/tile_arch_03.tscn"),
    }
    GameData.world_initialized.connect(_on_world_initialized)

func _on_world_initialized() -> void:
    _build_map()

func _build_map() -> void:
    # Clear previous tiles
    for child in get_children():
        child.queue_free()
    _tiles.clear()

    var spacing: float = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
    var pattern := _select_pattern(GameData.map_size)

    for x in GameData.map_size.x:
        for y in GameData.map_size.y:
            var pos := Vector2i(x, y)
            var tile_type: GameConfig.TileType = _tile_type_for(pattern, pos, GameData.map_size)
            var tile: TileController = _tile_scenes[tile_type].instantiate()
            tile.position = Vector3(x * spacing, 0.0, y * spacing)
            tile.setup(pos)
            add_child(tile)
            _tiles[pos] = tile

            # Checkerboard darkening
            if (x + y) % 2 == 1:
                _darken_tile(tile)

            # Connect hover to HUD tooltip system (via signal bus or direct)
            tile.hovered.connect(_on_tile_hovered)
            tile.unhovered.connect(_on_tile_unhovered)

func get_tile(pos: Vector2i) -> TileController:
    return _tiles.get(pos)

func world_pos(grid: Vector2i) -> Vector3:
    var spacing: float = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
    return Vector3(grid.x * spacing, 0.0, grid.y * spacing)
```

**Why does WorldManager live in the scene tree and not as an autoload?** Because
it owns 3D nodes — tile instances that need a parent in the scene tree. Autoloads
exist outside the scene tree and can't be parents to visible 3D objects.

### 2.3 — Pattern selection

Keep the `WorldBuilder` concept from your prototype, but as a pure-logic static
class:

```gdscript
# scripts/utils/PatternBuilder.gd
# No extends — used as a namespace for static functions
class_name PatternBuilder

enum Pattern { FLAT, FORTRESS, ARENA, CORNER_TOWERS, CENTER_TOWER, STRONGHOLD }

static func select(map_size: Vector2i) -> Pattern:
    var dim := max(map_size.x, map_size.y)
    if dim <= 5:
        return [Pattern.FORTRESS, Pattern.ARENA].pick_random()
    elif dim <= 12:
        return [Pattern.CORNER_TOWERS, Pattern.CENTER_TOWER].pick_random()
    else:
        return [Pattern.FORTRESS, Pattern.STRONGHOLD].pick_random()

static func tile_type(pattern: Pattern, pos: Vector2i,
                       map: Vector2i) -> GameConfig.TileType:
    match pattern:
        Pattern.FLAT:
            return GameConfig.TileType.BASIC
        Pattern.FORTRESS:
            return GameConfig.TileType.ARCH_1F if _is_border(pos, map) \
                   else GameConfig.TileType.BASIC
        # ... etc
        _:
            return GameConfig.TileType.BASIC
```

`class_name PatternBuilder` with only `static func` methods means you call it
as `PatternBuilder.select(map_size)` without instantiating it. No `extends`
means no parent class overhead. This is the idiomatic Godot 4 way to write
utility namespaces.

**Milestone:** Call `GameData.map_size = Vector2i(10, 10)` and
`GameData.world_initialized.emit()` from `Main.gd`'s `_ready()`. You should
see a 10×10 grid of tiles appear in the viewport with correct camera framing.

---

## Phase 3 — Mock Server & CommandProcessor (Days 3–4)
*Goal: Game events flowing through the system on a fake server before real networking.*

Build mock mode first, always. It lets you develop and test the entire visual
layer without a running server.

### 3.1 — CommandProcessor

This is the **most important architectural piece**. It is an autoload that:
1. Receives a raw command dictionary (from mock or real server)
2. Validates it
3. Mutates `GameData` to reflect the new state
4. Emits a typed signal so visual managers can respond

It **never** touches 3D nodes directly. Its only dependencies are `GameData`
and `GameConfig`.

```gdscript
# scripts/autoloads/CommandProcessor.gd
extends Node

# --- Signals (the visual layer listens to these) ---
signal player_moved(id: int, from: Vector2i, to: Vector2i, orientation: int)
signal player_rotated(id: int, new_orientation: int)
signal player_died(id: int)
signal player_leveled_up(id: int, new_level: int)
signal player_status_changed(id: int, status: GameConfig.PlayerStatus)
signal resource_placed(tile_pos: Vector2i, resource: String)
signal resource_taken(tile_pos: Vector2i, resource: String)
signal egg_laid(egg_id: int)
signal egg_hatched(egg_id: int)
signal egg_died(egg_id: int)
signal incantation_started(tile_pos: Vector2i, level: int, player_ids: Array[int])
signal incantation_ended(tile_pos: Vector2i, success: bool)
signal broadcast_sent(player_id: int, message: String)
signal game_over(winning_team: String)

func process_command(cmd: Dictionary) -> void:
    var type: String = cmd.get("type", "")
    if type.is_empty():
        push_warning("CommandProcessor: received command with no type")
        return

    match type:
        "avance":           _avance(cmd)
        "gauche":           _rotate(cmd, -1)
        "droite":           _rotate(cmd, 1)
        "prend":            _prend(cmd)
        "pose":             _pose(cmd)
        "fork":             _fork(cmd)
        "incantation_start": _incantation_start(cmd)
        "incantation_end":   _incantation_end(cmd)
        "broadcast":        _broadcast(cmd)
        "death":            _death(cmd)
        "level_up":         _level_up(cmd)
        "egg_hatch":        _egg_hatch(cmd)
        "egg_death":        _egg_death(cmd)
        "game_end":         _game_end(cmd)
        _:
            push_warning("CommandProcessor: unknown command type '%s'" % type)

func _avance(cmd: Dictionary) -> void:
    var id: int = cmd.get("player_id", -1)
    var player := GameData.get_player(id)
    if not player:
        push_warning("CommandProcessor._avance: player %d not found" % id)
        return

    var from: Vector2i = player.pos
    var to: Vector2i = _advance_pos(from, player.orientation)

    # Update data first, then emit signal
    var old_tile := GameData.get_tile(from)
    var new_tile := GameData.get_tile(to)
    if old_tile: old_tile.player_ids.erase(id)
    if new_tile and not new_tile.player_ids.has(id):
        new_tile.player_ids.append(id)
    player.pos = to

    player_moved.emit(id, from, to, player.orientation)

func _advance_pos(pos: Vector2i, orientation: int) -> Vector2i:
    match orientation:
        GameConfig.Orientation.NORTH: return Vector2i(pos.x, (pos.y - 1 + GameData.map_size.y) % GameData.map_size.y)
        GameConfig.Orientation.EAST:  return Vector2i((pos.x + 1) % GameData.map_size.x, pos.y)
        GameConfig.Orientation.SOUTH: return Vector2i(pos.x, (pos.y + 1) % GameData.map_size.y)
        GameConfig.Orientation.WEST:  return Vector2i((pos.x - 1 + GameData.map_size.x) % GameData.map_size.x, pos.y)
        _: return pos

# ... remaining handlers follow the same pattern:
# validate → update GameData → emit signal
```

**The golden rule:** `GameData` is always updated *before* the signal is
emitted. This means any handler that reads `GameData` in response to a signal
will always see the current state.

### 3.2 — MockServer

`MockServer.gd` replays a folder of JSON command files, one per frame tick.
It is an autoload but only does anything when explicitly started.

```gdscript
# scripts/autoloads/MockServer.gd
extends Node

@export var commands_path: String = "res://data/mock/"
@export var interval: float = 0.08   # seconds between commands
@export var auto_start: bool = false

var _files: Array[String] = []
var _index: int = 0
var _timer: float = 0.0
var _running: bool = false

func start() -> void:
    _load_files()
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
        _index = 0  # loop

    var data := _load_json(_files[_index])
    _index += 1

    if data.is_empty(): return
    if data.get("status", "ok") != "ok": return
    CommandProcessor.process_command(data)

func _load_files() -> void:
    _files.clear()
    var dir := DirAccess.open(commands_path)
    if not dir:
        push_error("MockServer: cannot open %s" % commands_path)
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.ends_with(".json"):
            _files.append(commands_path + name)
        name = dir.get_next()
    _files.sort()

func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if not file: return {}
    var json := JSON.new()
    return json.data if json.parse(file.get_as_text()) == OK else {}
```

**Milestone:** Create a few JSON files in `res://data/mock/` with player
movement commands. `CommandProcessor` should emit `player_moved` signals in the
Output log. No visuals yet — just confirmed signal flow.

---

## Phase 4 — Entity Managers (Days 4–6)
*Goal: Players, resources, and eggs visually present and responding to commands.*

### Architecture principle for this phase

Each entity manager (`PlayerManager`, `ResourceManager`) is a `Node3D` child
of `Main`. They listen to `CommandProcessor` signals and manipulate 3D scenes.
They never talk to each other — they both read from `GameData` when they need
cross-entity information.

```
CommandProcessor (signal) → PlayerManager → player 3D scenes
CommandProcessor (signal) → ResourceManager → resource 3D scenes
```

### 4.1 — ResourceManager

Resources are the most numerous entity type. Build this first because it has
no animations — just placement and removal.

```gdscript
# scenes/main/ResourceManager.gd
extends Node3D

# Preload all resource scenes
const SCENES: Dictionary = {
    "nourriture": preload("res://scenes/entities/resources/nourriture.tscn"),
    "linemate":   preload("res://scenes/entities/resources/linemate.tscn"),
    # ... etc
}

func _ready() -> void:
    GameData.world_initialized.connect(_place_initial_resources)
    CommandProcessor.resource_placed.connect(_on_resource_placed)
    CommandProcessor.resource_taken.connect(_on_resource_taken)

func _place_initial_resources() -> void:
    for pos in GameData.tiles:
        var tile_data: GameData.TileData = GameData.tiles[pos]
        for resource in tile_data.resources:
            var qty: int = tile_data.resources[resource]
            if qty > 0:
                _place_resource(pos, resource, qty)

func _place_resource(pos: Vector2i, resource: String, qty: int) -> void:
    var world := get_parent().world_manager  # typed reference
    var tile: TileController = world.get_tile(pos)
    if not tile: return

    var slot := tile.get_free_resource_slot()
    if slot == -1: return   # tile full — silently drop

    var scene: Node3D = SCENES[resource].instantiate()
    scene.scale = _qty_to_scale(qty)
    tile.occupy_resource_slot(slot, scene)

func _qty_to_scale(qty: int) -> Vector3:
    var s: float = clamp(0.5 + (qty - 1) * 0.15, 0.5, 1.2)
    return Vector3(s, s, s)
```

**One resource scene per type.** Each scene is a `Node3D` containing the GLB
import, an `AnimationPlayer` for the idle float, and an `Area3D` for hover
detection. The hover signal on the `Area3D` routes through to the tooltip
system (Phase 5).

### 4.2 — Resource floating animation

The idle float belongs in the resource scene itself, not in the manager. Each
resource scene has a script:

```gdscript
# scenes/entities/resources/ResourceEntity.gd
extends Node3D

@export var float_height: float = 0.08
@export var float_speed: float = 1.2

var _origin: Vector3
var _time: float

func _ready() -> void:
    _origin = position
    # Randomize phase so all resources don't bob in sync
    _time = randf() * TAU

func _process(delta: float) -> void:
    _time += delta * float_speed
    position = _origin + Vector3(0.0, sin(_time) * float_height, 0.0)
```

**Godot practice note:** `randf() * TAU` in `_ready()` gives each instance a
random starting phase. This one line makes a scene with 50 resources feel alive
instead of mechanical.

### 4.3 — PlayerManager

```gdscript
# scenes/main/PlayerManager.gd
extends Node3D

# One scene per team character
const TEAM_SCENES: Dictionary = {
    "Alpha":   preload("res://scenes/entities/players/player_cuby.tscn"),
    "Beta":    preload("res://scenes/entities/players/player_piry.tscn"),
    "Gamma":   preload("res://scenes/entities/players/player_bally.tscn"),
    "Delta":   preload("res://scenes/entities/players/player_dody.tscn"),
    "Epsilon": preload("res://scenes/entities/players/player_icy.tscn"),
}

var _players: Dictionary = {}  # int -> Node3D

func _ready() -> void:
    GameData.world_initialized.connect(_spawn_all_players)
    CommandProcessor.player_moved.connect(_on_player_moved)
    CommandProcessor.player_rotated.connect(_on_player_rotated)
    CommandProcessor.player_died.connect(_on_player_died)
    CommandProcessor.player_leveled_up.connect(_on_player_leveled_up)
    CommandProcessor.incantation_started.connect(_on_incantation_started)
    CommandProcessor.incantation_ended.connect(_on_incantation_ended)
    CommandProcessor.broadcast_sent.connect(_on_broadcast_sent)

func _spawn_all_players() -> void:
    for id in GameData.players:
        _spawn_player(id)

func _spawn_player(id: int) -> void:
    var data := GameData.get_player(id)
    if not data: return

    var scene_key: String = data.team if TEAM_SCENES.has(data.team) else TEAM_SCENES.keys()[0]
    var scene: Node3D = TEAM_SCENES[scene_key].instantiate()
    add_child(scene)

    _place_player_on_tile(scene, data)
    _players[id] = scene

    # Set up hover
    var area := scene.find_child("Area3D") as Area3D
    if area:
        area.mouse_entered.connect(func(): _on_player_hovered(id))
        area.mouse_exited.connect(func(): _on_player_unhovered(id))
```

### 4.4 — Movement animation with world wrapping

Toroidal wrapping is the trickiest visual problem in this project. When a
player moves from tile `(0, y)` northward to `(0, map_size.y-1)`, the visual
should teleport to just off the opposite edge and slide in — not travel across
the entire map.

```gdscript
func _on_player_moved(id: int, from: Vector2i, to: Vector2i, orientation: int) -> void:
    var scene := _players.get(id) as Node3D
    if not scene: return

    var world: WorldManager = get_parent().world_manager
    var from_world := world.world_pos(from)
    var to_world   := world.world_pos(to)

    # Detect wrap and adjust start position
    var spacing: float = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
    var dx: int = to.x - from.x
    var dy: int = to.y - from.y

    # If the raw grid delta is larger than 1, a wrap occurred
    if abs(dx) > 1:
        # Moving east across wrap: slide in from the west
        scene.global_position.x = to_world.x - spacing
    elif abs(dy) > 1:
        scene.global_position.z = to_world.z - spacing

    var tween := create_tween()
    tween.set_ease(Tween.EASE_OUT)
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(scene, "global_position",
                          to_world + Vector3(0.0, 0.2, 0.0),
                          GameConfig.MOVE_DURATION)

    # Move to correct tile slot
    _move_to_tile_slot(scene, id, from, to)
```

**Milestone:** Spawn a mock initial state with 3 players and watch them move
around the grid using mock commands. Deaths, rotations, and resource
pickup/drop should be visible.

---

## Phase 5 — UI Layer (Days 6–7)
*Goal: HUD with persistent info, hover tooltips for all entity types.*

### 5.1 — UI architecture

Split the UI into two concerns that never mix:

**HUD (`hud/HUD.tscn`)** — a `CanvasLayer` that is always visible. Shows
global game state: connection status, tick, time unit, team scores. Never
follows the cursor.

**Tooltips (`ui/tooltips/`)** — individual `Panel` nodes that appear near the
cursor when hovering an entity. Each entity type has its own tooltip scene.
All tooltips are children of a single `CanvasLayer` that sits above the HUD.

```
CanvasLayer (z_index: 0)  ← HUD
├── StatusBar
├── TeamPanel
└── EventLog

CanvasLayer (z_index: 1)  ← Tooltips (above HUD)
├── TileTooltip
├── PlayerTooltip
├── ResourceTooltip
└── EggTooltip
```

### 5.2 — TooltipManager

Rather than having each 3D entity directly update a panel, route everything
through a single `TooltipManager` node on the tooltip layer. This keeps 3D
entities decoupled from UI.

```gdscript
# scenes/ui/tooltips/TooltipManager.gd
extends CanvasLayer

@onready var tile_tooltip: Panel = $TileTooltip
@onready var player_tooltip: Panel = $PlayerTooltip
@onready var resource_tooltip: Panel = $ResourceTooltip
@onready var egg_tooltip: Panel = $EggTooltip

var _active_panel: Panel = null

func _ready() -> void:
    _hide_all()

func show_tile(pos: Vector2i) -> void:
    var data := GameData.get_tile(pos)
    if not data: return
    tile_tooltip.populate(data)
    _show(tile_tooltip)

func show_player(id: int) -> void:
    var data := GameData.get_player(id)
    if not data: return
    player_tooltip.populate(data)
    _show(player_tooltip)

func hide_all() -> void:
    _hide_all()

func _process(_delta: float) -> void:
    if _active_panel and _active_panel.visible:
        _track_cursor(_active_panel)

func _show(panel: Panel) -> void:
    _hide_all()
    panel.visible = true
    _active_panel = panel
    _track_cursor(panel)

func _hide_all() -> void:
    for child in get_children():
        if child is Panel:
            child.visible = false
    _active_panel = null

func _track_cursor(panel: Panel) -> void:
    var mouse := get_viewport().get_mouse_position()
    var vp := get_viewport().get_visible_rect().size
    var offset := Vector2(16.0, -8.0)
    var pos := mouse + offset
    pos.x = clamp(pos.x, 0.0, vp.x - panel.size.x)
    pos.y = clamp(pos.y, 0.0, vp.y - panel.size.y)
    panel.global_position = pos
```

Each tooltip scene has its own `populate(data)` method that fills in labels.
The manager never reads data directly — it just shows the right tooltip and
passes data to it.

### 5.3 — HUD

```gdscript
# scenes/ui/hud/HUD.gd
extends CanvasLayer

@onready var connection_indicator: ColorRect = $StatusBar/ConnectionDot
@onready var tick_label: Label = $StatusBar/TickLabel
@onready var time_unit_label: Label = $StatusBar/TimeUnitLabel
@onready var team_container: VBoxContainer = $TeamPanel/TeamList

func _ready() -> void:
    GameData.tick_updated.connect(_on_tick)
    GameData.time_unit_changed.connect(_on_time_unit)
    GameData.world_initialized.connect(_build_team_rows)
    GameData.team_changed.connect(_refresh_team)

func _on_tick(t: int) -> void:
    tick_label.text = "Tick: %d" % t

func _on_time_unit(t: int) -> void:
    time_unit_label.text = "t=%d" % t
```

**Milestone:** With mock commands running, you should see the tick counter
incrementing, team player counts changing, and tooltips following your cursor
as you hover over tiles and players.

---

## Phase 6 — Network Layer (Days 7–9)
*Goal: Connect to a real Zappy server and replace the mock entirely.*

Build this phase last, after the entire visual layer is working on mock data.
This is important: it means you can test and debug the protocol parser in
isolation, and your visual layer is already proven.

### 6.1 — Connection screen

`ConnectionScreen.tscn` is a `CanvasLayer` added to `Main.tscn`, visible at
startup and hidden after successful connection.

```gdscript
# scenes/ui/screens/ConnectionScreen.gd
extends CanvasLayer

@onready var ip_field: LineEdit = $Panel/VBox/IPField
@onready var port_field: LineEdit = $Panel/VBox/PortField
@onready var connect_btn: Button = $Panel/VBox/ConnectButton
@onready var mock_btn: Button = $Panel/VBox/MockButton
@onready var status_label: Label = $Panel/VBox/StatusLabel

func _ready() -> void:
    ip_field.text = "127.0.0.1"
    port_field.text = "4242"
    connect_btn.pressed.connect(_on_connect)
    mock_btn.pressed.connect(_on_mock)

func _on_connect() -> void:
    status_label.text = "Connecting..."
    connect_btn.disabled = true
    var mgr: ServerConnectionManager = get_parent().connection_manager
    mgr.connection_established.connect(_on_success, CONNECT_ONE_SHOT)
    mgr.connection_failed.connect(_on_fail, CONNECT_ONE_SHOT)
    mgr.connect_to_server(ip_field.text, int(port_field.text))

func _on_success() -> void:
    visible = false

func _on_fail() -> void:
    status_label.text = "Connection failed. Check IP/port."
    connect_btn.disabled = false

func _on_mock() -> void:
    MockServer.start()
    visible = false
```

### 6.2 — ServerConnectionManager

The server speaks **WebSocket**, so use Godot's built-in `WebSocketPeer`. It
handles the HTTP upgrade handshake internally — you only need to manage the
open/poll/close lifecycle and read/write text frames.

```gdscript
# scenes/main/ServerConnectionManager.gd
extends Node

signal connection_established
signal connection_failed
signal disconnected

var _ws: WebSocketPeer
var _ip: String = ""
var _port: int = 0

enum State { IDLE, CONNECTING, CONNECTED }
var _state: State = State.IDLE

func connect_to_server(ip: String, port: int) -> void:
    _ip = ip
    _port = port
    _ws = WebSocketPeer.new()
    var url := "ws://%s:%d" % [ip, port]
    var err := _ws.connect_to_url(url)
    if err != OK:
        push_error("ServerConnectionManager: connect_to_url failed (%d)" % err)
        connection_failed.emit()
        return
    _state = State.CONNECTING

func disconnect_from_server() -> void:
    if _ws:
        _ws.close()
    _state = State.IDLE

func send_json(data: Dictionary) -> void:
    if _state != State.CONNECTED: return
    _ws.send_text(JSON.stringify(data))

func _process(_delta: float) -> void:
    if _state == State.IDLE or not _ws: return
    _ws.poll()

    var ws_state := _ws.get_ready_state()
    match ws_state:
        WebSocketPeer.STATE_OPEN:
            if _state == State.CONNECTING:
                _state = State.CONNECTED
                connection_established.emit()
            _drain_packets()
        WebSocketPeer.STATE_CLOSING:
            pass  # Wait for CLOSED
        WebSocketPeer.STATE_CLOSED:
            _state = State.IDLE
            disconnected.emit()

func _drain_packets() -> void:
    while _ws.get_available_packet_count() > 0:
        var raw := _ws.get_packet()
        var text := raw.get_string_from_utf8()
        if text.is_empty(): continue
        ProtocolParser.parse_message(text)
```

**Why `WebSocketPeer` and not `StreamPeerTCP`?** The server performs a proper
WebSocket handshake (`Upgrade: websocket`, `Sec-WebSocket-Key`, etc.) and sends
framed messages — your `WebsocketClient.cpp` and `FrameCodec.cpp` in the AI
client are the reference implementation for exactly this. `StreamPeerTCP` sees
raw bytes and would force you to re-implement frame parsing in GDScript.
`WebSocketPeer` handles all of that and gives you clean text messages.

### 6.3 — ProtocolParser

`ProtocolParser.gd` is a `Node` child of `Main` (not an autoload — it depends
on `ServerConnectionManager` being in the same scene). It translates every
JSON message from the server into either a direct `GameData` mutation or a
`CommandProcessor.process_command()` call.

Because messages are JSON objects, each message already has a `"type"` field
you can dispatch on directly — no line-splitting or string parsing needed.

**The Zappy graphic protocol — full command reference:**

| `"type"` value | Meaning | Action |
|---|---|---|
| `"WELCOME"` | Initial greeting | Send `{"type": "GRAPHIC"}` back |
| `"msz"` | Map dimensions | Set `GameData.map_size` |
| `"sgt"` | Time unit | Set `GameData.time_unit` |
| `"tna"` | Team name | Add team to `GameData.teams` |
| `"bct"` | Tile content | Set tile resources |
| `"pnw"` | New player | Add player to `GameData.players` |
| `"enw"` | New egg | Add egg to `GameData.eggs` |
| `"ppo"` | Player position | Move command |
| `"plv"` | Player level | Level up command |
| `"pin"` | Player inventory | Inventory update |
| `"pex"` | Player death | Death command |
| `"pbc"` | Broadcast | Broadcast command |
| `"pic"` | Incantation start | Incantation command |
| `"pie"` | Incantation end | Incantation end command |
| `"pfk"` | Fork (lay egg) | Fork command |
| `"ebo"` | Egg hatches | Egg hatch command |
| `"edi"` | Egg dies | Egg death command |
| `"sst"` | Time unit change | Update `GameData.time_unit` |
| `"seg"` | Game over | Game over command |
| `"smg"` | Server message | Log only |
| `"suc"` | Unknown command | Log only |
| `"sbp"` | Bad params | Log only |

The initial connection sequence is deterministic: `WELCOME` → `msz` → `sgt` →
`tna` (×N teams) → `bct` (×W×H tiles) → `pnw` (×P players) → `enw` (×E eggs).
Only after receiving *all* `bct` messages is the map complete. Track this with
a counter and emit `GameData.world_initialized` when `received_bct_count ==
map_size.x * map_size.y`.

```gdscript
# scenes/main/ProtocolParser.gd
extends Node

var _expected_bct: int = 0
var _received_bct: int = 0
var _map_ready: bool = false

func _ready() -> void:
    # ServerConnectionManager must be a sibling node
    var conn: ServerConnectionManager = get_parent().get_node("ServerConnectionManager")
    conn.connection_established.connect(_on_connected)

func _on_connected() -> void:
    _reset()

func _reset() -> void:
    _received_bct = 0
    _map_ready = false
    GameData.tiles.clear()
    GameData.players.clear()
    GameData.eggs.clear()
    GameData.teams.clear()

func parse_message(text: String) -> void:
    var json := JSON.new()
    if json.parse(text) != OK:
        push_warning("ProtocolParser: failed to parse JSON: %s" % text.left(80))
        return

    var msg: Dictionary = json.data
    var type: String = msg.get("type", "")
    if type.is_empty():
        push_warning("ProtocolParser: message has no 'type' field")
        return

    match type:
        "WELCOME":
            get_parent().connection_manager.send_json(GameConfig.WS_OBSERVER_HANDSHAKE)
        "msz":
            GameData.map_size = Vector2i(int(msg["w"]), int(msg["h"]))
            _expected_bct = GameData.map_size.x * GameData.map_size.y
        "sgt":
            GameData.time_unit = int(msg["t"])
            GameData.time_unit_changed.emit(GameData.time_unit)
        "tna":
            GameData.teams[msg["name"]] = {"player_count": 0, "connections": 0}
        "bct":
            _parse_bct(msg)
        "pnw":
            _parse_pnw(msg)
        "enw":
            _parse_enw(msg)
        "ppo":
            CommandProcessor.process_command({
                "type": "avance",
                "player_id": int(msg["player_id"]),
                "x": int(msg["x"]), "y": int(msg["y"]),
                "orientation": int(msg["orientation"])
            })
        "plv":
            CommandProcessor.process_command({
                "type": "level_up",
                "player_id": int(msg["player_id"]),
                "level": int(msg["level"])
            })
        "pex":
            CommandProcessor.process_command({
                "type": "death", "player_id": int(msg["player_id"])
            })
        "pbc":
            CommandProcessor.process_command({
                "type": "broadcast",
                "player_id": int(msg["player_id"]),
                "message": str(msg.get("message", ""))
            })
        "pic":
            _parse_pic(msg)
        "pie":
            CommandProcessor.process_command({
                "type": "incantation_end",
                "tile_pos": Vector2i(int(msg["x"]), int(msg["y"])),
                "success": bool(msg.get("result", false))
            })
        "pfk":
            CommandProcessor.process_command({
                "type": "fork", "player_id": int(msg["player_id"])
            })
        "ebo":
            CommandProcessor.process_command({
                "type": "egg_hatch", "egg_id": int(msg["egg_id"])
            })
        "edi":
            CommandProcessor.process_command({
                "type": "egg_death", "egg_id": int(msg["egg_id"])
            })
        "sst":
            GameData.time_unit = int(msg["t"])
            GameData.time_unit_changed.emit(GameData.time_unit)
        "seg":
            CommandProcessor.process_command({
                "type": "game_end", "winning_team": str(msg.get("team", ""))
            })
        "smg", "suc", "sbp":
            pass  # Ignore or log

    # Note: the exact JSON field names above ("player_id", "x", "y", etc.) must
    # match whatever your C server sends. Inspect a live session or the server
    # source to confirm them — adjust the keys here if they differ.

func _parse_bct(msg: Dictionary) -> void:
    var pos := Vector2i(int(msg["x"]), int(msg["y"]))
    if not GameData.tiles.has(pos):
        GameData.tiles[pos] = GameData.TileData.new(pos)
    var tile: GameData.TileData = GameData.tiles[pos]
    var resources := GameConfig.RESOURCE_NAMES
    # Expect msg["resources"] to be an Array of 7 ints, or msg["q0"]..msg["q6"]
    var qty: Array = msg.get("resources", [])
    for i in resources.size():
        tile.resources[resources[i]] = int(qty[i]) if i < qty.size() else 0

    _received_bct += 1
    if not _map_ready and _received_bct >= _expected_bct:
        _map_ready = true
        GameData.world_initialized.emit()

func _parse_pnw(msg: Dictionary) -> void:
    var player := GameData.PlayerData.new(int(msg["player_id"]))
    player.pos         = Vector2i(int(msg["x"]), int(msg["y"]))
    player.orientation = int(msg["orientation"])
    player.level       = int(msg["level"])
    player.team        = str(msg["team"])
    GameData.players[player.id] = player
    var tile := GameData.get_tile(player.pos)
    if tile and not tile.player_ids.has(player.id):
        tile.player_ids.append(player.id)
```

### 6.4 — Reconnection

Add automatic reconnect to `ServerConnectionManager`:

```gdscript
var _ip: String = ""
var _port: int = 0
var _reconnect_count: int = 0
const MAX_RECONNECTS: int = 5

func _on_disconnected() -> void:
    disconnected.emit()
    if _reconnect_count < MAX_RECONNECTS:
        _reconnect_count += 1
        var delay: float = pow(2.0, _reconnect_count)  # 2, 4, 8, 16, 32 seconds
        await get_tree().create_timer(delay).timeout
        connect_to_server(_ip, _port)
```

**Milestone:** Connect to a real running Zappy server. The 3D arena should
build itself from server data, and all live game events should animate
correctly.

---

## Phase 7 — Visual Events (Days 9–10)
*Goal: The remaining game events that need dedicated visual effects.*

These are listed in implementation order, simplest first.

### 7.1 — Player death

Tween scale to zero, free the tile slot, remove from tracking:

```gdscript
func _on_player_died(id: int) -> void:
    var scene := _players.get(id) as Node3D
    if not scene: return

    var tween := create_tween()
    tween.set_ease(Tween.EASE_IN)
    tween.tween_property(scene, "scale", Vector3.ZERO, GameConfig.DEATH_DURATION)
    await tween.finished

    _free_player_tile_slot(id)
    scene.queue_free()
    _players.erase(id)
```

### 7.2 — Level-up popup

A `Label3D` that floats upward and fades. Create it procedurally — no separate
scene needed:

```gdscript
func _on_player_leveled_up(id: int, new_level: int) -> void:
    var scene := _players.get(id) as Node3D
    if not scene: return

    var label := Label3D.new()
    label.text = "Level %d!" % new_level
    label.font_size = 40
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    scene.add_child(label)
    label.position = Vector3.ZERO

    var tween := create_tween()
    tween.tween_property(label, "position:y", 1.8, 1.0)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
    await tween.finished
    label.queue_free()
```

### 7.3 — Broadcast

An expanding torus ring at ground level, fading out:

```gdscript
func _on_broadcast_sent(player_id: int, _msg: String) -> void:
    var scene := _players.get(player_id) as Node3D
    if not scene: return

    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.0
    torus.outer_radius = 0.1
    ring.mesh = torus

    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.3, 0.9, 1.0, 0.7)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring.material_override = mat
    ring.scale = Vector3.ZERO

    get_tree().root.add_child(ring)
    ring.global_position = scene.global_position * Vector3(1, 0, 1)  # flat on ground

    var tween := create_tween()
    tween.tween_property(ring, "scale", Vector3(10, 0.05, 10), 0.7)
    tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.7)
    await tween.finished
    ring.queue_free()
```

### 7.4 — Incantation

**Start:** All participating players get a pulsing emissive tint. The tile gets
a rising `GPUParticles3D` effect.

**End success:** Flash gold, remove tint, trigger level-up popup on initiating
player.

**End failure:** Flash red, remove tint.

Implement the glow by swapping material on the player model mesh at incantation
start, restoring it at end. Keep the original material reference so it can be
restored correctly.

### 7.5 — Egg lifecycle

Egg scenes already have a floating animation from your prototype — keep that
approach. Add:

- A brief "appear" scale-from-zero tween when an egg is placed (`pfk`)
- A "crack" animation (from the egg GLB's AnimationPlayer) on `ebo`, then
  `queue_free()`
- Instant `queue_free()` on `edi`

### 7.6 — Game over screen

`EndScreen.tscn` slides in over the game view (don't destroy the scene — keep
the final state visible). It shows the winning team, final player counts, and
a Quit button.

```gdscript
func show_winner(team: String) -> void:
    winner_label.text = "%s wins!" % team
    visible = true
    var tween := create_tween()
    modulate.a = 0.0
    tween.tween_property(self, "modulate:a", 1.0, 0.8)
```

---

## Phase 8 — Polish (Day 10–12)
*These are all improvements, none are blockers. Do them in any order.*

### Post-processing

Your prototype's ink/paper shader aesthetic is worth preserving — it's
distinctive. Set it up as a `ColorRect` on a `CanvasLayer` with the
chromatic aberration shader applied. Add a hotkey (`F2`) to toggle it on/off.
Some people find it harder to read; give them the choice.

### Camera feel

- Add **smooth zoom limits**: if the map is large, don't let the camera zoom
  so far in that tiles fill the screen. Compute `_size_target` min/max from
  `GameData.map_size` in `initialize_for_map()`.
- Add a **focus shortcut**: clicking a player in the player tooltip could call
  `camera_rig.focus_on(player_world_pos)`.
- **Reset key**: `Home` key calls `camera_rig.initialize_for_map(GameData.map_size)`
  to return to overview.

### Performance

For maps larger than 15×15 with many resources, `_process()` running on every
resource instance becomes measurable. Two mitigations:

1. **Stagger floating animation updates** — only update floating offset every
   2 frames, offset by instance ID modulo:

   ```gdscript
   func _process(delta: float) -> void:
       if Engine.get_process_frames() % 2 != get_instance_id() % 2:
           return
       _time += delta * 2.0  # compensate for skipped frames
       position = _origin + Vector3(0.0, sin(_time) * float_height, 0.0)
   ```

2. **Batch tile generation** — for maps > 100 tiles, spread tile instantiation
   across multiple frames to avoid a frame spike on map load:

   ```gdscript
   func _build_map_batched() -> void:
       var positions: Array[Vector2i] = []
       for x in GameData.map_size.x:
           for y in GameData.map_size.y:
               positions.append(Vector2i(x, y))

       while positions.size() > 0:
           var batch := positions.slice(0, 10)
           positions = positions.slice(10)
           for pos in batch:
               _create_tile(pos)
           await get_tree().process_frame
   ```

### Signal safety

Adopt a consistent pattern for connecting signals to avoid duplicate
connections (which cause handler methods to fire twice):

```gdscript
# Instead of:
signal.connect(handler)

# Use:
if not signal.is_connected(handler):
    signal.connect(handler)

# Or for one-shot connections:
signal.connect(handler, CONNECT_ONE_SHOT)
```

### Code hygiene

- Add `## Documentation comments` to all public methods using GDScript's
  built-in doc comment syntax (double `#`). Godot's editor will show these
  in the inspector.
- Replace all `print()` calls with `push_warning()` or `push_error()` for
  things that shouldn't happen, and remove debug prints entirely. The Output
  log becomes signal noise very quickly in a running game.
- Run `Project → Tools → GDScript` → check for any typed warnings and resolve
  them. Typed GDScript with zero warnings is the target state.

---

## What To Keep From the Prototype

You're building from scratch, but the prototype contains working art and
validated logic. These are worth copying verbatim:

| Asset / script | What to take |
|---|---|
| All `.glb` files | All 3D models — tiles, players, resources, eggs, environment |
| `chromatic_aberration.gdshader` | The ink/paper post-processing aesthetic |
| `WorldBuilder.gd` | The pattern logic (`_build_small_fortress`, etc.) — just copy the helper functions into `PatternBuilder.gd` |
| `CameraController.gd` | The `_calculate_optimal_ortho_size()` formula, the boundary calculation |
| `MockServer.gd` | The file loading and timer logic — nearly identical to what's described here |
| Mock JSON data files | Your existing `data/commands/` folder |
| `WorldEnvironmentController.gd` | The HDRI + solid background setup |

Do **not** copy `DataManager.gd` (replaced by typed inner classes),
`ServerConnectionManager.gd` (replaced by WebSocket version), `UI.gd` (replaced by
tooltip manager pattern), or any `.tscn` files (rebuild them clean).

---

## Milestone Summary

| Phase | Deliverable | Day |
|---|---|---|
| 0 | Empty scene, camera, autoloads confirmed | 1 |
| 1 | Controllable axonometric camera on empty scene | 1–2 |
| 2 | 3D tile grid generated from `GameData.map_size` | 2–3 |
| 3 | Commands flowing through `CommandProcessor` from mock data | 3–4 |
| 4 | Players, resources, eggs spawning and animating | 4–6 |
| 5 | HUD + cursor tooltips working | 6–7 |
| 6 | Real server connection, full protocol handled | 7–9 |
| 7 | All game events have visual feedback | 9–10 |
| 8 | Polish, performance, reconnection | 10–12 |

Each milestone is independently runnable. If you get stuck in a later phase,
the game is still demonstrable at the last milestone.

---

## A Note on Learning Godot While Building This

Each phase of this project maps directly to a Godot concept you'll internalize
by using it in a real context:

- **Phase 0–1** teaches you autoloads, typed GDScript, and the scene tree
- **Phase 2** teaches you scene instancing, `Area3D`, and `Marker3D` positioning
- **Phase 3** teaches you the signal system deeply — this is Godot's most
  important concept
- **Phase 4** teaches you `Tween`, animation players, and 3D transforms
- **Phase 5** teaches you `CanvasLayer`, UI anchors, and the Control node system
- **Phase 6** teaches you `WebSocketPeer`, JSON parsing in GDScript, and `_process`-based polling
- **Phase 7** teaches you procedural mesh creation, `Label3D`, and `GPUParticles3D`
- **Phase 8** teaches you GDScript performance patterns and documentation

By Phase 6 you'll be comfortable enough with Godot that the networking work
won't feel like fighting the engine — it'll just feel like solving a protocol
problem.

---

*Document version: 1.1 — Updated April 2026 (networking corrected: WebSocket + JSON)*
*Project: Zappy GUI · Engine: Godot 4.x · Language: GDScript (typed)*

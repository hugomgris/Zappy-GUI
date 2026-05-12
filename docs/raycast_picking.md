# 3D Raycast Picking in Nested Viewports — Zappy GUI

## The Problem It Solves

The Zappy GUI renders its 3D world inside a chain of nested viewports:

```
Main (Control)
└── PostProcessing (SubViewportContainer)  ← riso shader lives here
    └── Compositor (SubViewport)
        └── GameContainer (SubViewportContainer)
            └── GameSubViewport (SubViewport)
                └── CameraRig + Tiles (Area3D)
```

The goal was to detect when the mouse hovers over a tile in the 3D world, so a tooltip could be shown. The natural Godot approach — connecting `Area3D.mouse_entered` and `Area3D.mouse_exited` signals — completely failed to fire in this setup, even after correctly configuring `physics_object_picking`, `handle_input_locally`, and `mouse_filter` on every node in the chain.

---

## Why Area3D Mouse Signals Failed

### How they normally work

In a standard Godot setup, `Area3D.mouse_entered` fires through an internal engine pipeline:

1. The OS delivers a mouse event to the root viewport
2. Godot's physics server runs a picking pass — it casts a ray from the camera through the mouse position into the 3D world
3. If that ray hits an Area3D with `input_ray_pickable = true`, the engine emits `mouse_entered` on that Area3D

This is convenient but **entirely internal** — you have no control over when it runs, what coordinate space it uses, or how it traverses the viewport tree.

### Why nested viewports break it

For the picking pass to run correctly inside a SubViewport, two things must be true simultaneously:

- The SubViewport must receive the mouse event in its **own local coordinate space**
- The SubViewport must have `physics_object_picking = true` and process the event through its own internal input pipeline

In a single-viewport setup this is automatic. In a nested setup, the outer Compositor SubViewport receives the event first. Even with `handle_input_locally = false`, the coordinate transformation between the outer and inner viewport isn't applied correctly for the physics picking pass — only for regular input events.

The result: `physics_object_picking = true` is set, the events arrive at the viewport, but the picking ray is cast with wrong coordinates (or not cast at all), and `mouse_entered` never fires.

Additionally, `push_input` — which is needed to manually forward events into the viewport — goes through the regular input pipeline but **bypasses the internal physics picking step entirely**. The picking pass is a separate system that only runs when the viewport processes input through its own natural flow, not through `push_input`.

### In short

Area3D mouse signals depend on an internal engine mechanism that is not designed to survive manual input forwarding through nested SubViewports. It is not configurable or fixable from GDScript — you cannot hook into it, override it, or force it to run correctly in this context.

---

## The Raycast Solution — Fundamentals

### What a raycast is

A ray is a line in 3D space defined by an origin point and a direction. A raycast fires that line into the physics world and returns information about the first object it intersects.

In the context of mouse picking, the ray represents the line of sight from the camera through the pixel the mouse is currently over — extending into the 3D scene until it hits something.

### The camera projection functions

Godot's `Camera3D` provides two functions that make this trivial:

```gdscript
camera.project_ray_origin(viewport_pos: Vector2) -> Vector3
camera.project_ray_normal(viewport_pos: Vector2) -> Vector3
```

`project_ray_origin` returns the 3D point where the ray starts — for a perspective camera this is the camera's own position; for an orthographic camera it's the point on the near plane directly behind the mouse cursor.

`project_ray_normal` returns the normalised direction vector the ray travels in — pointing from the camera out through the given 2D viewport position into the scene.

Together they fully define the ray:

```gdscript
var from := camera.project_ray_origin(viewport_pos)
var to   := from + camera.project_ray_normal(viewport_pos) * 1000.0
```

The `* 1000.0` sets the ray's maximum length. Any object beyond 1000 units won't be detected — tune this to your scene's scale.

### The physics space query

The 3D world's physics state is accessed through:

```gdscript
var space := game_sub_viewport.find_world_3d().direct_space_state
```

`find_world_3d()` retrieves the `World3D` resource associated with the viewport — this is the physics simulation context that knows about all collision shapes in the scene.

`direct_space_state` gives you a `PhysicsDirectSpaceState3D` object, which exposes `intersect_ray()` — the function that actually performs the cast.

```gdscript
var query := PhysicsRayQueryParameters3D.create(from, to)
query.collide_with_areas  = true   # detect Area3D nodes
query.collide_with_bodies = false  # ignore RigidBody3D, StaticBody3D etc.

var result := space.intersect_ray(query)
```

`result` is a dictionary. If the ray hit something, it contains:
- `collider` — the node that was hit
- `position` — the 3D world position of the intersection
- `normal` — the surface normal at the hit point
- `collider_id`, `shape`, `rid` — lower-level physics identifiers

If the ray hit nothing, `result` is an empty dictionary.

---

## The Implementation

### Coordinate pipeline

The critical requirement is that `viewport_pos` passed to the camera projection functions must be in **GameSubViewport's local coordinate space** — (0,0) at the top-left of the game viewport, (810, 810) at the bottom-right.

The mouse position from `event.position` is in **Main's screen space** — (0,0) at the top-left of the application window. The transformation is:

```gdscript
var pp_offset    := post_processing.global_position  # PostProcessing's position in screen space
var game_offset  := Vector2(135, 135)                # GameContainer's position inside Compositor

var local_pos := event.position - pp_offset - game_offset
```

`pp_offset` accounts for the PostProcessing container being centred in the 1920-wide window (offset 420px from left). `game_offset` accounts for the 135px frame border, which offsets the game viewport inside the Compositor.

### Hover state tracking

Unlike `mouse_entered`/`mouse_exited` which fire automatically on entry and exit, the raycast runs every `MouseMotion` event and returns the currently hovered object. To replicate enter/exit semantics, a `_hovered_tile` variable tracks the previously hovered tile:

```gdscript
var _hovered_tile: TileController = null

func _do_picking(viewport_pos: Vector2) -> void:
    var camera := game_sub_viewport.get_camera_3d()
    if not camera:
        return

    var from  := camera.project_ray_origin(viewport_pos)
    var to    := from + camera.project_ray_normal(viewport_pos) * 1000.0
    var space := game_sub_viewport.find_world_3d().direct_space_state

    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collide_with_areas  = true
    query.collide_with_bodies = false

    var result := space.intersect_ray(query)

    if result:
        var collider = result.get("collider")
        if collider is TileController:
            if collider != _hovered_tile:
                # Mouse moved from one tile to another — fire exit on old, enter on new
                if _hovered_tile:
                    _hovered_tile.unhovered.emit(_hovered_tile.grid_pos)
                _hovered_tile = collider
                _hovered_tile.hovered.emit(_hovered_tile.grid_pos)
    else:
        # Ray hit nothing — mouse left the grid
        if _hovered_tile:
            _hovered_tile.unhovered.emit(_hovered_tile.grid_pos)
            _hovered_tile = null
```

The `if collider != _hovered_tile` guard ensures the signals only fire on actual changes — not every frame the mouse moves while staying over the same tile.

### Full _input function

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion or event is InputEventMouseButton:
        var pp_offset   := post_processing.global_position
        var game_offset := Vector2(135, 135)
        var local_event := event.xformed_by(
            Transform2D(0, -(pp_offset + game_offset))
        )
        # Forward to viewport for camera input (zoom, pan, etc.)
        game_sub_viewport.push_input(local_event)

        # Manual picking on motion events
        if event is InputEventMouseMotion:
            _do_picking(local_event.position)
```

The `push_input` call still happens for camera interaction — the camera rig needs transformed mouse events for zoom and pan. The `_do_picking` call runs in parallel, using the same already-transformed position.

### Signal wiring

`TileController` keeps its custom signals but removes the `mouse_entered`/`mouse_exited` connections from `_ready()` entirely:

```gdscript
# TileController._ready() — remove these:
# mouse_entered.connect(func(): hovered.emit(grid_pos))
# mouse_exited.connect(func(): unhovered.emit(grid_pos))
```

The `hovered` and `unhovered` signals are now emitted by Main.gd's picking code directly. They connect to the TooltipManager wherever tiles are registered:

```gdscript
tile.hovered.connect(func(pos): TooltipManager.show_tile(pos))
tile.unhovered.connect(func(pos): TooltipManager.hide_all())
```

---

## Why This Approach Is Better

### It works

This is not a small point. The Area3D signal approach is fundamentally incompatible with manual input forwarding through nested SubViewports. No amount of configuration fixes it — the picking pass simply does not run correctly in this context. The raycast approach has no such dependency.

### Full control over coordinate space

The raycast explicitly receives coordinates that have already been transformed correctly for the viewport. There is no ambiguity about which coordinate space the engine is using internally — you computed it yourself and you can verify it with a print.

### Extensible to multiple object types

Adding picking for players, resources, and eggs is trivial — the same `_do_picking` function can check `collider is PlayerController`, `collider is ResourceController` etc. in priority order. You can define exactly which objects take precedence when they overlap:

```gdscript
if collider is PlayerController:
    # player tooltip takes priority over tile
elif collider is TileController:
    # tile tooltip as fallback
```

With Area3D signals, overlapping objects both fire independently and you have to manage priority in the tooltip manager instead.

### No dependency on engine internals

`Area3D.mouse_entered` is internally wired to the physics picking pass, which is wired to the viewport input pipeline. Any of those links can silently break when the scene structure changes. The raycast approach uses only public, documented API — `project_ray_origin`, `intersect_ray` — with no hidden dependencies.

### Debuggable

If picking stops working, you can add a single print inside `_do_picking` and immediately see whether the ray is firing, what it's hitting, and what coordinates it's using. With Area3D signals, a silent failure gives you nothing to inspect.

---

## Limitations and Considerations

**Runs every MouseMotion event** — this is very frequent. The raycast itself is cheap (it's a single physics query), but if performance ever becomes a concern, you can throttle it with a timer or only run it when the mouse has moved more than N pixels.

**Only detects the topmost object** — `intersect_ray` returns the first hit. If a player is standing on a tile, you'll only get the player (or only the tile, depending on which collision shape the ray hits first). This is usually the desired behaviour but requires thought when designing collision layer assignments.

**Collision layers** — for more precise control over what the ray can and cannot hit, assign different physics layers to tiles, players, and resources, then set `query.collision_mask` to only check the layers you care about for each picking context.

**Mouse leaving the game area** — if the mouse moves outside the 810×810 game viewport area, `viewport_pos` will be outside the valid range. The ray will still be cast but will likely hit nothing, correctly clearing `_hovered_tile`. If you need to explicitly detect this, clamp or bounds-check `viewport_pos` before casting.

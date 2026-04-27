# Building an Axonometric Camera in Godot 4
## A first-principles tutorial for the Zappy GUI

---

## What is an axonometric camera, and why does it fit this project?

A **perspective** camera simulates how human eyes work: parallel lines converge
at a vanishing point, and objects further away appear smaller. It feels natural
and immersive.

An **orthographic** camera has no perspective distortion at all: parallel lines
stay parallel, and an object's rendered size is independent of its distance from
the camera. When you tilt an orthographic camera at a fixed angle above a scene,
you get the classic **axonometric** (or isometric) look — every tile reads
clearly regardless of distance, depth is implied by the fixed angle rather than
vanishing points, and the view is easy to scan.

For a strategy/spectator game like Zappy, this is the right choice. You want the
player to read the whole arena at a glance, not feel immersed in it.

In Godot 4, you get this by setting `Camera3D.projection` to
`PROJECTION_ORTHOGONAL` and controlling scale via `Camera3D.size` instead of
field of view.

---

## The node structure, and why it's designed this way

The camera rig is four nodes nested inside each other:

```
CameraRig (Node3D)       ← this is the root; its script lives here
└── Pitch (Node3D)       ← rotates on the X axis (the vertical tilt)
    └── ZoomArm (Node3D) ← translates on the Z axis (distance from subject)
        └── Camera3D     ← the actual camera; set to Orthogonal projection
```

Each node does **exactly one thing**. This separation is the key insight — if
you tried to do everything on a single node you would find that operations
interfere with each other in confusing ways.

### Why separate nodes?

**CameraRig** sits at the world position you want to look at. When you pan, you
move this node. Its Y rotation controls which compass direction the camera faces
(the yaw, or "spin around the vertical axis"). Think of it as the tripod base.

**Pitch** is a child of CameraRig, so it inherits the tripod's position and
yaw. Its only job is to rotate on the X axis — tilting the camera downward at
the fixed isometric angle (~30° from horizontal, so `rotation_degrees.x = -30`
since negative X tilts the front downward). Because it's a child, it rotates
relative to CameraRig's already-applied yaw — the two rotations compose
correctly without any manual matrix math.

**ZoomArm** is a child of Pitch, so it inherits position + yaw + tilt. Its only
job is to translate on its **local** Z axis. Because Pitch has already tilted the
local axes, moving ZoomArm on Z moves the camera along the tilted "look" axis —
i.e., backward away from the subject. This is how you zoom: push ZoomArm further
back, the camera moves away. Pull it in, the camera gets closer.

> **But wait** — in orthographic mode, distance doesn't actually change what the
> camera sees, right?
>
> Correct. In true orthographic projection, physical distance from the subject is
> irrelevant to the rendered size. **For this project, zoom is instead controlled
> by `Camera3D.size`** — the larger the value, the more world fits in the frame.
> The ZoomArm translation matters if you ever want to avoid clipping through
> geometry, but the visual "zoom" sensation comes from changing `size`, not
> from moving the arm.

**Camera3D** is the leaf node. It sits at the end of the arm, pointing along
its local -Z axis (which Pitch has already aimed downward at the scene). Set
`projection = PROJECTION_ORTHOGONAL` here. This node has no script — it's
entirely controlled by its parent's transforms.

---

## Coordinate systems and local vs. world space

Before writing any code it's worth being clear on this, because it's the source
of most camera bugs.

In Godot 4, every Node3D has a **local space** and a **world space**.

- **World space** is fixed: X points right, Y points up, Z points toward the
  viewer (out of the screen).
- **Local space** is relative to the node's current transform. If you rotate a
  node 45° on Y, its local X axis no longer points world-right — it points
  world-northeast.

When you call `node.position += Vector3(1, 0, 0)`, you move it in **local
space**. When you call `node.global_position += Vector3(1, 0, 0)`, you move it
in **world space**.

For the camera rig:

- **Panning** should happen in world space, but adjusted for the rig's current
  yaw. If the camera is rotated 90° and the player presses "pan right", you want
  to move in the rig's local X direction — not world X. That's why pan input is
  rotated by `rotation.y` before being applied:

  ```gdscript
  var world_dir := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, rotation.y)
  _pos_target += world_dir * speed * delta
  ```

- **Pitch** is applied in Pitch node's local X — which is already correctly
  oriented because CameraRig's yaw has been applied at the parent level.

- **Zoom** (changing `Camera3D.size`) operates in camera space and doesn't need
  any coordinate transformation.

---

## The lerp pattern — why you never set values directly

A naive camera sets `position = new_position` immediately on input. This works
but feels robotic: the camera teleports instead of glides.

The standard solution is to separate **target** from **current**:

- Input events modify a `_target` variable (immediately, no smoothing).
- Every `_process()` frame, the actual value lerps toward the target.

```gdscript
# On input:
_pos_target += pan_delta

# In _process():
position = position.lerp(_pos_target, lerp_speed * delta)
```

`lerp(a, b, t)` returns a value `t` of the way from `a` to `b`. When `t` is
small (near 0), movement is slow; when `t` is large (near 1), movement is fast.
Using `lerp_speed * delta` means the speed is framerate-independent — the camera
covers the same proportion of remaining distance per second regardless of FPS.

The result is **ease-out motion**: the camera starts fast and slows as it
approaches the target, which feels natural.

> **Clamping the lerp factor:** `lerp_speed * delta` can exceed 1.0 at low
> framerates (e.g. `lerp_speed=12, delta=0.1` → `t=1.2`). `lerp()` with `t > 1`
> overshoots. Always clamp: `clamp(lerp_speed * delta, 0.0, 1.0)`.

For **rotation** use `lerp_angle()` instead of `lerpf()`. `lerp_angle` correctly
handles the wraparound at ±180°, so a rotation from 350° to 10° goes through 0°
instead of spinning 340° the wrong way.

For **zoom** (`Camera3D.size`) use `lerpf()` — it's just a float.

---

## Snap rotation (90° increments)

Axonometric games traditionally let you snap-rotate the view in 90° steps to see
around obstacles. This is a special case of the lerp pattern:

```gdscript
if Input.is_action_just_pressed("rotate_left"):
    _yaw_target -= PI * 0.5   # 90° in radians
if Input.is_action_just_pressed("rotate_right"):
    _yaw_target += PI * 0.5
```

Because `_yaw_target` is a float that `lerp_angle` smoothly approaches, the
rotation animates to the next 90° snap rather than teleporting. The input sets
the destination; lerp handles the journey.

---

## Input handling — three input types

The camera receives three kinds of input, each handled differently:

### 1. Keyboard pan (held keys)

Checked every frame in `_process()` using `Input.get_vector()`. This returns a
`Vector2` whose axes are −1 to +1 based on which keys are held. You then rotate
this by the rig's current yaw so "forward" means "toward where the camera is
facing", not always "toward world -Z":

```gdscript
func _handle_keyboard(delta: float) -> void:
    var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if dir != Vector2.ZERO:
        var world_dir := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, rotation.y)
        _pos_target += world_dir * move_speed * delta
```

### 2. Middle-mouse drag pan

Handled in `_unhandled_input()` using `InputEventMouseMotion`. The
`event.relative` gives pixel delta since last frame. Scale it down (pixels are
much larger than world units), then apply the same yaw rotation:

```gdscript
if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
    var drag := event.relative * 0.02
    _pos_target += Vector3(-drag.x, 0.0, -drag.y).rotated(Vector3.UP, rotation.y)
```

The negation on `drag.x` is because mouse moving right should pan the camera
right (moving the world left), but the sign depends on your coordinate
conventions — adjust if it feels inverted.

### 3. Scroll wheel zoom

Also in `_unhandled_input()`. Scroll events are discrete button presses
(`MOUSE_BUTTON_WHEEL_UP` / `MOUSE_BUTTON_WHEEL_DOWN`), not continuous motion.
Each event nudges the size target:

```gdscript
if event is InputEventMouseButton:
    if event.button_index == MOUSE_BUTTON_WHEEL_UP:
        _size_target = max(2.0, _size_target - zoom_speed)
    elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
        _size_target = min(60.0, _size_target + zoom_speed)
```

The `max(2.0, ...)` and `min(60.0, ...)` clamps prevent zooming so far in or out
that the scene becomes unusable. You'll tune these limits once you know your
map size range.

---

## Map-aware initialization

The camera should center itself on the map and set an appropriate initial zoom
when the map size is known. This is not done in `_ready()` (the map size isn't
known then) but in a method called by `Main.gd` after `GameData.world_initialized`
fires:

```gdscript
func initialize_for_map(size: Vector2i) -> void:
    var spacing := GameConfig.TILE_SIZE + GameConfig.TILE_GAP
    var center := Vector3(
        (size.x - 1) * spacing * 0.5,
        0.0,
        (size.y - 1) * spacing * 0.5
    )
    var span := max(size.x, size.y) * spacing

    # Snap immediately — don't lerp from origin to map center on load
    position = center
    _pos_target = center
    _size_target = span * 0.7
    _camera.size = _size_target
    _initialized = true
```

Notice that `position` and `_camera.size` are set directly here (not just the
targets). If you only set the targets, the camera would visibly animate from
world origin to the map center on first load, which looks broken. Snap the
current value, then let future lerps handle smooth motion from there.

The `_initialized` flag gates `_process()` so the camera doesn't try to lerp
before a map exists:

```gdscript
func _process(delta: float) -> void:
    if not _initialized:
        return
    _handle_keyboard(delta)
    _apply_lerp(delta)
```

---

## Bounds clamping

Without bounds, the player can pan the camera off into empty space and lose the
map entirely. Compute a bounding rectangle from the map size and clamp
`_pos_target` every frame before applying the lerp:

```gdscript
func _apply_lerp(delta: float) -> void:
    var t := clamp(lerp_speed * delta, 0.0, 1.0)

    _pos_target.x = clamp(_pos_target.x, _bounds.position.x,
                           _bounds.position.x + _bounds.size.x)
    _pos_target.z = clamp(_pos_target.z, _bounds.position.y,
                           _bounds.position.y + _bounds.size.y)

    position = position.lerp(_pos_target, t)
    rotation.y = lerp_angle(rotation.y, _yaw_target, t)
    _camera.size = lerpf(_camera.size, _size_target, t)
```

The bounds are set in `initialize_for_map()` with some padding so the edges of
the map remain reachable. `Rect2` uses `position` (top-left corner) and `size`,
so `_bounds.position.y` corresponds to world Z, not world Y — the 2D rect is
mapping onto the XZ plane of the 3D world.

---

## Putting it all together — the mental model

When you sit down to write `CameraRig.gd`, think of it in three distinct layers:

1. **Input layer** — reads events and modifies `_pos_target`, `_yaw_target`,
   `_size_target`. Nothing here touches the actual node transforms.

2. **Lerp layer** (`_apply_lerp`) — every frame, moves actual values toward
   targets. Nothing here reads input.

3. **Initialization** (`initialize_for_map`) — called once when the map is
   ready. Sets both target and current to the correct starting values to avoid
   a visible snap.

The node hierarchy makes this clean because each node's transform is
independently controllable. You never fight the engine trying to decompose a
combined rotation-translation into its parts — each part already lives in its
own node.

---

## Building it step by step

Do this in order, testing at each step before moving on:

1. [x] **Create the node hierarchy** in the Godot editor. `CameraRig` (Node3D) →
   `Pitch` (Node3D) → `ZoomArm` (Node3D) → `Camera3D`. Save as
   `scenes/camera/CameraRig.tscn`.

2. [x] **Set the Camera3D projection** to Orthogonal in the inspector. Set `Size`
   to something like `10.0` so you can see the scene.

3. [ ] **Set Pitch's `rotation_degrees.x` to `-30`** in the inspector (tilt it
   downward). You should see your empty scene from above and at an angle.

4. [ ] **Attach `CameraRig.gd`** to the root node. Add `@onready` references to
   Pitch, ZoomArm, and Camera3D.

5. [ ] **Implement `_ready()`** — just set the initial yaw and confirm the pitch
   angle is applied.

6. [ ] **Implement `_unhandled_input()`** — scroll wheel zoom first (easiest to
   test). Verify `_size_target` changes.

7. [ ] **Implement `_apply_lerp()`** — now scroll wheel zoom should visually
   animate.

8. [ ] **Add keyboard pan** to `_handle_keyboard()`. Verify it moves in the right
   direction relative to the camera's facing.

9. [ ] **Add middle-mouse drag.** Verify it feels natural.

10. [ ] **Add snap rotation** (Q/E keys). Verify panning direction updates correctly
    after a rotation.

11. [ ] **Implement `initialize_for_map()`** and call it from `Main.gd` once
    `GameData.world_initialized` fires.

12. [ ] **Add bounds clamping** once the map is visible, tune the padding values.

Each step is independently testable. Don't write the whole script and then debug
it — you won't know which part broke.

---

*Tutorial written for the Zappy GUI rebuild · Godot 4.x · GDScript (typed)*

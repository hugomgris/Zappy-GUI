# Axonometric Camera: Setup, Centering & Rotation

## 1. The Rig Hierarchy

Before anything else, it helps to understand the scene tree structure and *why* each node exists:

```
CameraManager  (Node3D)  ← the "rig root" — moves in XZ, rotates in Y (yaw)
  └── Pitch    (Node3D)  ← rotated permanently on X axis (pitch)
        └── ZoomArm (Node3D)  ← (optional arm for zoom offsets)
              └── Camera3D    ← the actual camera, pushed back along Z
```

Each level of the hierarchy handles **one concern**:

| Node | Responsibility |
|------|---------------|
| `CameraManager` | XZ world position + Y-axis rotation (yaw) |
| `Pitch` | Fixed downward tilt (e.g. 60° below horizontal) |
| `Camera3D` | Pushed away from origin along its local Z so it's "above and behind" the pivot |

This separation means you can rotate the whole rig around Y without touching the pitch, and zoom by moving the camera along Z without touching anything else.

---

## 2. What "Orthographic Axonometric" Means Here

```gdscript
_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
```

In an **orthographic** projection, there is no perspective foreshortening. All parallel lines stay parallel. The "size" property of the camera controls how many world units fit vertically in the viewport — it is the zoom knob.

In a **perspective** camera, zooming moves the camera physically closer, which changes how angles are perceived. In orthographic, zooming just widens or narrows the projection frustum in place, so the viewing angle never changes. This is what gives isometric / axonometric games their characteristic flat look.

---

## 3. Initial Setup: `_ready()`

```gdscript
func _ready() -> void:
    _pitch.rotation_degrees.x = -pitch_angle_deg   # tilt camera down 60°
    rotation_degrees.y = initial_yaw_deg            # start rotated 22.5°
    _yaw_target = initial_yaw_deg
    rotation.y = _yaw_target                        # set both actual and target
    _camera.projection = Camera3D.PROJECTION_ORTHOGONAL
```

Two things are established at startup:

- **Pitch**: The `Pitch` node is rotated `-60°` on its local X axis, meaning the camera permanently looks downward at 60° below horizontal. This never changes.
- **Yaw**: The rig root is rotated `22.5°` around the world Y axis. This gives the classic "diamond" axonometric look rather than a head-on view. Both the *actual* rotation and the *lerp target* (`_yaw_target`) are set to the same value so there's no initial animated snap.

---

## 4. Map Centering: `initialize_for_map()`

This is the most complex function. Its job is: **make the camera look at exactly the center of the grid when the scene starts.** The challenge is that because the camera is pitched and offset, the rig pivot is *not* at the same position as what the camera is looking at.

### Step 1 — Compute the grid center in world space

```gdscript
var spacing: float = GameConfig.TILE_SIZE + GameConfig.TILE_GAP
var grid_center := Vector3(
    (size.x - 1) * spacing * 0.5,
    0.0,
    (size.y - 1) * spacing * 0.5
)
```

Tiles are laid out in a grid. The center is just the average position of the first and last tile in each axis, at Y = 0 (ground plane).

### Step 2 — First pass: plant the rig at grid center

```gdscript
position    = grid_center
_pos_target = grid_center
_size_target = span * margin_offset
_camera.size = _size_target
```

The rig is placed at the grid center. But because the camera is offset (it's pushed away along Z through the pitch/zoom arm), it won't actually be *looking at* the grid center yet. It'll be looking at some point in front of the rig.

### Step 3 — Wait one frame

```gdscript
await get_tree().process_frame
```

Godot computes `global_position` and `global_basis` lazily. After changing node positions, we need to wait one physics/render frame for Godot to propagate all the transforms down the scene tree. Without this, `_camera.global_position` and `_camera.global_basis` would reflect stale values.

### Step 4 — Find where the camera ray hits the ground

```gdscript
var cam_world_pos := _camera.global_position
var cam_forward   := -_camera.global_basis.z   # look direction in world space

var t := -cam_world_pos.y / cam_forward.y
var ground_hit := cam_world_pos + cam_forward * t
```

This is a **ray-plane intersection**. The camera is at `cam_world_pos` and looking in direction `cam_forward`. We want to find where this ray hits the Y = 0 plane (the ground).

The parametric form of the ray is:
```
P(t) = cam_world_pos + t * cam_forward
```

We want `P(t).y = 0`:
```
cam_world_pos.y + t * cam_forward.y = 0
t = -cam_world_pos.y / cam_forward.y
```

Plugging `t` back in gives `ground_hit` — the exact world-space point on the ground that the camera center is currently aimed at.

> **Why `-global_basis.z`?**
> In Godot, a camera's local `-Z` axis is its look direction (cameras "look" toward negative Z in their local space). `global_basis.z` is the world-space direction of the camera's local +Z, so negating it gives the actual viewing direction.

### Step 5 — Correct the rig position

```gdscript
var correction := grid_center - ground_hit
correction.y = 0.0

position    = grid_center + correction
_pos_target = position
```

`ground_hit` is where the camera was looking. `grid_center` is where we *want* it to look. The difference is the error. We shift the entire rig by that error (XZ only — we don't touch Y, which is always 0 for the rig).

**Intuition**: if the camera was looking 3 units to the right of grid center, we shift the whole rig 3 units to the left. Now the camera looks exactly at grid center.

---

## 5. The Zoom Arm and Camera.size

Zooming in this rig works in two orthogonal ways:

- `_camera.size` controls the **orthographic frustum width** — think of it as "how wide a window does the camera see through." Increasing it zooms out (more world fits on screen), decreasing zooms in.
- The camera's local Z position (set in the scene) controls the **physical distance** of the camera from the rig pivot, but in orthographic projection this doesn't affect zoom — it only affects near/far clip planes.

So in practice, all zoom is done by lerping `_camera.size`, not by moving nodes.

---

## 6. Frame-to-Frame Motion: `_process()` and Lerping

Rather than snapping transforms immediately, all changes go through **lerp targets**:

```
_pos_target   → position        (via position.lerp)
_yaw_target   → rotation.y      (via lerp_angle)
_size_target  → _camera.size    (via lerpf)
```

Each frame, `_apply_lerp()` moves the actual values toward their targets:

```gdscript
var t: float = clamp(lerp_speed * delta, 0.0, 1.0)
position  = position.lerp(_pos_target, t)
rotation.y = lerp_angle(rotation.y, _yaw_target, t)
_camera.size = lerpf(_camera.size, _size_target, t)
```

`lerp_speed * delta` turns the lerp speed into a **framerate-independent factor**. At 60fps, `delta ≈ 0.0167`, so `lerp_speed = 12` gives `t ≈ 0.2` per frame — the gap closes by 20% each frame, giving smooth exponential easing. Because it's geometric decay, the motion *feels* fast at first and soft at the end.

`lerp_angle` is used for rotation because it correctly handles the wraparound at ±180°. Without it, rotating from 170° to -170° (a 20° turn) would appear to spin 340° in the wrong direction.

---

## 7. Rotation With Re-centering: The Hard Part

When you press Q or E to rotate 90°, three things need to happen simultaneously:
1. The yaw target changes by ±90°.
2. The camera *appears* to pivot around the grid center, not around the rig's current XZ position.
3. The grid should still be centered when the rotation completes.

Because the camera is offset from the rig (it's pitched and pulled back), rotating the rig around its own pivot *won't* keep the grid centered. The ground point the camera was looking at will shift. `_compute_recentering_correction()` figures out how much to move the rig so that the camera ends up looking at `_grid_center` after the rotation.

### The Math

```gdscript
func _compute_recentering_correction(target_yaw: float) -> Vector3:
```

The goal: given the rig ends up at some position with `target_yaw`, what XZ position should the rig be at so the camera looks at `_grid_center`?

**Step 1 — Reconstruct the camera's world offset from the rig pivot**

The camera sits at a known local position inside the rig hierarchy. We unroll that chain manually:

```gdscript
var pitch_rad := deg_to_rad(-pitch_angle_deg)
var cam_local := Vector3(0, 0, _camera.position.z)  // camera's local offset in pitch space
```

Rotate `cam_local` through the pitch (X-axis rotation):
```
after_pitch.x =  cam_local.x
after_pitch.y =  cam_local.y * cos(pitch) - cam_local.z * sin(pitch)
after_pitch.z =  cam_local.y * sin(pitch) + cam_local.z * cos(pitch)
```

Add the pitch node's own position (it's not at the rig's origin):
```gdscript
var total_local := _pitch.position + after_pitch
```

Now rotate through the *target* yaw (Y-axis rotation) to get the camera's world-space offset from the rig pivot:
```
cam_offset.x =  total_local.x * cos(yaw) + total_local.z * sin(yaw)
cam_offset.y =  total_local.y
cam_offset.z = -total_local.x * sin(yaw) + total_local.z * cos(yaw)
```

**Step 2 — Compute the camera's look direction at target yaw**

The camera looks downward at `pitch_angle_deg` and faces `target_yaw`:
```gdscript
var look := Vector3(
    -sin(target_yaw) * cos(pitch_rad),
     sin(pitch_rad),
    -cos(target_yaw) * cos(pitch_rad)
)
```

`sin(pitch_rad)` is negative (since `pitch_rad` is negative), so `look.y < 0` — the ray points toward the ground, which is required for the ray-plane intersection to work.

**Step 3 — Find where the camera would look if the rig were at `_grid_center`**

```gdscript
var future_cam_pos := _grid_center + cam_offset
var t := -future_cam_pos.y / look.y
var ground_hit := future_cam_pos + look * t
```

Same ray-plane intersection as in `initialize_for_map`. If we placed the rig right at `_grid_center`, where would the camera actually be looking on the ground?

**Step 4 — Compute the correction**

```gdscript
var correction := _grid_center - ground_hit
correction.y = 0.0
return _grid_center + correction
```

`ground_hit` is where the camera would look. `_grid_center` is where we want it to look. The correction shifts the rig so those two align.

### Why `_pos_target = correction` (not `+=`)

When rotation is triggered:

```gdscript
_pos_target = _compute_recentering_correction(_yaw_target)
```

We *assign* rather than *add* because the function already returns the absolute rig position that centers the grid. Adding it to the current `_pos_target` would double-count.

---

## 8. Input Handling Summary

| Input | Effect |
|-------|--------|
| Arrow keys / WASD | Pan: shifts `_pos_target` in the camera-relative XZ direction |
| Mouse wheel up/down | Zoom: adjusts `_size_target` (clamped to `[2, 60]`) |
| Middle mouse drag | Pan: shifts `_pos_target` from screen-space drag vector |
| Q / rotate_left | Yaw −90°, recalculate `_pos_target` to re-center grid |
| E / rotate_right | Yaw +90°, recalculate `_pos_target` to re-center grid |

All panning respects the current yaw, so "up" always means "away from camera" regardless of rotation:

```gdscript
var world_dir := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, rotation.y)
```

---

## 9. Putting It All Together: The Full Flow

```
STARTUP
  ├─ _ready(): set pitch, yaw, orthographic
  └─ initialize_for_map(size):
       ├─ compute grid_center
       ├─ plant rig at grid_center (first pass)
       ├─ await 1 frame (let Godot update global transforms)
       ├─ raycast camera → Y=0 to find actual ground_hit
       ├─ shift rig by (grid_center - ground_hit) → camera now looks at grid_center
       └─ store _grid_center, set _initialized = true

EACH FRAME (_process)
  ├─ _handle_keyboard(delta)
  │    ├─ WASD/arrows → _pos_target += direction
  │    └─ Q/E → _yaw_target ±= 90°
  │              _pos_target = _compute_recentering_correction(_yaw_target)
  └─ _apply_lerp(delta)
       ├─ clamp _pos_target to _bounds
       ├─ position   = lerp(position, _pos_target, t)
       ├─ rotation.y = lerp_angle(rotation.y, _yaw_target, t)
       └─ camera.size = lerpf(camera.size, _size_target, t)

ON MOUSE INPUT (_unhandled_input)
  ├─ wheel up/down → _size_target ±= zoom_speed
  └─ middle drag   → _pos_target += screen_drag_in_world_space
```

---

## 10. Common Pitfalls

**The rig pivot ≠ the look-at point.** The rig's XZ position is *not* the world-space point the camera is looking at. They differ by the camera's forward projection onto the ground plane. All centering math must account for this offset.

**Orthographic ≠ top-down.** Even though there's no perspective, the camera is still pitched 60°. The look ray is oblique, not vertical.

**`lerp_angle` for yaw.** Using plain `lerpf` for rotation will cause the camera to spin the long way around when crossing ±180°. Always use `lerp_angle` for angles.

**Global transforms need a frame.** Godot doesn't immediately propagate changed local positions to `global_position`. If you need `_camera.global_position` right after moving a parent, `await get_tree().process_frame` first.

**The correction is an absolute position, not a delta.** `_compute_recentering_correction` returns where the rig *should be*, not how much to move it. Assign it directly to `_pos_target`.

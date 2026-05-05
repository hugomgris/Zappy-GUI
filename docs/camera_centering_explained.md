# Axonometric Camera Centering — How It Works

## The Problem

You have a 3D camera rig with this hierarchy:

```
CameraRig (Node3D)   ← yaw rotation + XZ position
  └─ Pitch (Node3D)  ← pitched -60°, also has a local XYZ offset saved in the scene
       └─ ZoomArm (Node3D)
            └─ Camera3D   ← local Z offset (the "arm" length)
```

Your instinct was: *"just put the rig at the grid center and the camera will look at it."*

That would be true **only if** every node in the chain had zero local position. But your Pitch node has a non-zero local offset `(0, 2.42, 6.97)` and the Camera has a local Z offset of `11.36`. These get rotated and compounded through the hierarchy, so the camera ends up physically sitting somewhere far from the rig pivot — and therefore looking at a ground point that is **not** the grid center.

---

## The Geometry

With an **orthographic** camera, every pixel on screen corresponds to a ray that is parallel to the camera's look direction. The screen center pixel shoots a ray from `camera.global_position` in the direction of `-camera.global_basis.z`.

For the grid to appear centered, that screen-center ray must hit the **geometric center of the grid** on the Y=0 ground plane.

```
         Camera (global pos)
              \
               \  (look direction = -global_basis.z)
                \
                 \
──────────────────X──────────────────  Y = 0 ground plane
                  ↑
            ground_hit
            (must equal grid_center for correct centering)
```

---

## Step-by-Step: What the Code Does

### 1. Compute the grid center in world space

```gdscript
var grid_center := Vector3(
    (size.x - 1) * spacing * 0.5,
    0.0,
    (size.y - 1) * spacing * 0.5
)
```

This is the pure geometric midpoint of the tile grid on the Y=0 plane. For a 10×10 grid with `spacing = 2.0`, this gives `(9, 0, 9)`.

---

### 2. First pass: plant the rig at grid_center

```gdscript
position = grid_center
await get_tree().process_frame
```

We set the rig pivot to `grid_center` and wait one frame. This is necessary because Godot only recomputes `global_position` and `global_basis` on the next physics/render tick. Without the `await`, all the global transform values would be stale.

After this frame, the camera is sitting somewhere in the air — its `global_position` reflects the full chain of offsets rotated by the current yaw and pitch.

---

### 3. Find where the camera's center ray hits Y=0

```gdscript
var cam_world_pos := _camera.global_position
var cam_forward   := -_camera.global_basis.z

var t := -cam_world_pos.y / cam_forward.y
var ground_hit := cam_world_pos + cam_forward * t
```

This is the **ray–plane intersection formula**. We want the point `P` where:

```
P = cam_world_pos + t * cam_forward
P.y = 0
```

Solving for `t`:

```
0 = cam_world_pos.y + t * cam_forward.y
t = -cam_world_pos.y / cam_forward.y
```

Then we substitute back to get `ground_hit` — the XZ world coordinate that the screen center is currently looking at.

---

### 4. Compute the correction and apply it

```gdscript
var correction := grid_center - ground_hit
correction.y = 0.0

position    = grid_center + correction
_pos_target = position
```

`ground_hit` is where the camera is *actually* looking. `grid_center` is where we *want* it to look. The difference is the correction vector.

We then shift the rig by that correction **on top of** `grid_center` (not on top of zero), because the ray measurement was taken with the rig already at `grid_center`. The structural offset of the rig (from the Pitch and Camera local positions) is already baked into `ground_hit`, so subtracting gives us exactly the compensation needed.

Visually:

```
ground_hit  = grid_center + structural_offset   (measured after first pass)
correction  = grid_center - ground_hit = -structural_offset
final pos   = grid_center + correction = grid_center - structural_offset  ✓
```

---

## Why Planting at grid_center (Not Zero) Matters

The Pitch node has a **local position** that gets rotated by the yaw. This means the structural offset is **yaw-dependent** — it points in a different world-space direction depending on how much the rig is rotated.

If you plant at `Vector3.ZERO` first and measure, then move to `grid_center`, the yaw context is the same so the math still works. But planting at `grid_center` is more robust: the measurement happens in the exact world context where the correction will be applied, removing any floating-point or transform-order ambiguity.

---

## Why Rotation (Q/E) Breaks Centering

When you rotate 90°, the yaw changes, which rotates the Pitch node's local offset into a **different world-space direction**. The structural offset vector that was pointing "forward-left" now points "forward-right" (or similar), shifting `ground_hit` to a completely different XZ position — but your rig position stays fixed.

The fix is to **re-run the centering correction whenever the yaw changes**. Since you're lerping the yaw, the cleanest approach is to track the *committed* yaw and re-center after the lerp settles:

```gdscript
var _last_corrected_yaw: float = 0.0

func _apply_lerp(delta: float) -> void:
    # ... existing lerp code ...

    # Re-center once the rotation has settled
    var yaw_diff := absf(angle_difference(rotation.y, _yaw_target))
    if yaw_diff < 0.01 and absf(rotation.y - _last_corrected_yaw) > 0.01:
        _last_corrected_yaw = rotation.y
        _recenter_to_grid()

func _recenter_to_grid() -> void:
    # Same ray-cast logic, but keeping the current _pos_target as base
    var cam_world_pos := _camera.global_position
    var cam_forward   := -_camera.global_basis.z
    var t             := -cam_world_pos.y / cam_forward.y
    var ground_hit    := cam_world_pos + cam_forward * t
    var correction    := _grid_center - ground_hit
    correction.y      = 0.0
    _pos_target       = _pos_target + correction  # shift current pan target, not absolute
```

You'll need to store `_grid_center` as a class variable (set during `initialize_for_map`) so `_recenter_to_grid` can access it.

This is **not** a byproduct of the projection — it's a consequence of the non-zero local offsets in your rig hierarchy. A rig with all children at local origin would rotate perfectly in place.

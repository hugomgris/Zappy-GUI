Step-by-step build progression for your Risograph shader
Step 1 — Color detection and flat ink layering
The conceptual foundation. Before any texture or effect, establish the core idea: detect ink colors from the source image and replace them with your palette.

Sample SCREEN_TEXTURE at the current UV
Write the is_red(), is_green(), is_cyan() etc. boolean detection functions
Map each detected color to a flat ink_N color uniform
Render everything else as a flat background color

At this point you have a hard posterized image — ugly, but it proves the pipeline works. This is also where you introduce the has_1..has_6 flags and the sequential layering order, which matters a lot for the final look even if it's invisible at this stage.

Step 2 — Stipple noise: the first "print" feel
Replace the flat ink areas with a noise-based stipple pattern. This is the moment the image starts feeling handmade.

Write the base noise() hash function
Build ink_noise() — the multi-octave version that gives organic texture
Write noise_hit(), which thresholds the noise against a density value derived from pixel luminance (your density_dark / density_light mix)
The result: ink areas that are denser in shadows, lighter in highlights — the fundamental risograph ink behavior


Step 3 — Halftone dots: the second print mode
Now introduce the irregular halftone dot grid as an alternative pattern, and blend between the two modes.

Write halftone_hit(): divide UV space into a grid, place one dot per cell
Add stipple_jitter to offset dot centers from the grid — breaks the mechanical regularity
Add per-dot size_rand, shape_rand (squish + rotation), and opacity_rand — these three variation uniforms are what separate a convincing risograph dot from a sterile halftone
Write get_hit(), which blends between halftone_hit and noise_hit based on density using noise_threshold — dense shadow areas get organic noise, midtones get dots


Step 4 — Plate angles: separating the inks
A real risograph prints each color on a separate pass at a different angle. Simulate this with rotate_uv().

Apply a different rotation angle to the UV before each get_hit() call (your 0°, 15°, 30°, 45°... steps)
This prevents the dots of different inks from stacking identically, creates subtle moiré-like interference, and is one of the most visually characteristic features of the medium


Step 5 — Misregistration: the human error
Real print passes never align perfectly. This is a big part of what makes risograph feel physical.

Introduce offset_top_px, offset_left_px, offset_right_px uniforms
Sample TEXTURE at slightly shifted UVs for the ink detection pass — so ink detection for each "plate" can see slightly different source geometry
The has_N flags now come from slightly offset samples rather than all from the same pixel


Step 6 — Paper grain
A small but important grounding layer — without it, the image floats.

Add a single octave of noise() scaled by paper_grain_size, modulated by paper_grain_amount
Apply it additively to final_color at the very end, and to the background color separately
Introduce the transparent_background flag here naturally, since you're already handling the background case explicitly


Step 7 — Animation: making it feel like cel printing
Everything up to here is static. Now you give the shader its living quality — the feeling that each frame is a slightly different print run.
Introduce stepped_time (floor(TIME * anim_speed) / anim_speed) as a foundational concept — the discretization is what makes motion feel like flipping between hand-pulled prints rather than smooth video. Then layer effects from subtlest to most impactful:

anim_strength — the stipple noise offsets per frame (barely visible alone, but foundational)
anim_density_jitter — density wobbles in noise-heavy zones
halftone_anim_strength / halftone_size_anim / halftone_opacity_anim — per-dot position, size, and opacity drift
frame_density_jitter — the whole ink coverage pulses, as if ink viscosity varied between passes
global_frame_jitter + frame_warp_strength — the entire UV plate shifts and warps each frame; this is the single biggest contributor to the cel-printed feel
frame_ink_shimmer — per-ink color drift, as if pigment concentration varied slightly

Each of these can be presented as its own mini-step, turning animation on uniform at a time, since they're completely independent and each produces a clearly visible change.

The through-line for the dev log
The narrative arc is essentially: detection → texture → structure → physicality → life. Each stage adds one property that real risograph printing has, and the final shader is just all of those properties running simultaneously. That framing should make it digestible — readers can stop at any step and have something that already looks intentional and good.
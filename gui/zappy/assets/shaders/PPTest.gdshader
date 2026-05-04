shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// --- Controls ---
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float curvature_amount : hint_range(0.0, 1.0) = 0.05;
uniform float vignette_strength : hint_range(0.0, 3.0) = 1.4;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.003;
uniform float grain_amount : hint_range(0.0, 0.1) = 0.03;

// Optional override (0 = auto)
uniform vec2 resolution = vec2(0.0);

// --- Helpers ---
vec2 get_resolution() {
    return (resolution.x > 0.0) ? resolution : vec2(textureSize(screen_texture, 0));
}

vec2 curve_uv(vec2 uv) {
    if (curvature_amount <= 0.0) return uv;

    vec2 centered = uv * 2.0 - 1.0;
    float r2 = dot(centered, centered);

    centered *= 1.0 + curvature_amount * r2;

    return centered * 0.5 + 0.5;
}

float scanlines(vec2 uv, vec2 res) {
    float s = sin(uv.y * res.y * 2.0);
    return 1.0 - s * scanline_intensity;
}

float vignette(vec2 uv) {
    float d = distance(uv, vec2(0.5));
    return smoothstep(0.8, 0.3, d * vignette_strength);
}

float noise(vec2 co, float time) {
    return fract(sin(dot(co, vec2(12.9898, 78.233)) + time) * 43758.5453);
}

vec3 shadow_mask(vec2 uv, vec2 res) {
    vec3 mask = vec3(1.0);

    float x = fract(uv.x * res.x / 3.0);

    if (x < 0.333) {
        mask.r *= 1.1;
        mask.gb *= vec2(0.9);
    } else if (x < 0.666) {
        mask.g *= 1.1;
        mask.rb *= vec2(0.9);
    } else {
        mask.b *= 1.1;
        mask.rg *= vec2(0.9);
    }

    return mask;
}

// --- Main ---
void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 res = get_resolution();

    vec2 curved_uv = curve_uv(uv);

    bool in_bounds =
        curved_uv.x >= 0.0 && curved_uv.x <= 1.0 &&
        curved_uv.y >= 0.0 && curved_uv.y <= 1.0;

    vec3 color = vec3(0.0);

    if (in_bounds) {
        // --- Chromatic aberration ---
        if (chromatic_aberration > 0.0) {
            float dist = distance(uv, vec2(0.5));
            float aberr = chromatic_aberration * dist * 2.0;

            color.r = texture(screen_texture, curved_uv + vec2(aberr, 0.0)).r;
            color.g = texture(screen_texture, curved_uv).g;
            color.b = texture(screen_texture, curved_uv - vec2(aberr, 0.0)).b;
        } else {
            color = texture(screen_texture, curved_uv).rgb;
        }

        // --- CRT effects ---
        color *= scanlines(curved_uv, res);
        color *= mix(vec3(1.0), shadow_mask(curved_uv, res), 0.3);
        color *= vignette(uv);

        // --- Grain ---
        if (grain_amount > 0.0) {
            float g = noise(curved_uv * res, TIME) * grain_amount;
            color += g;
        }

        // --- Slight warm tint ---
        color *= vec3(1.0, 0.98, 0.95);
    }

    COLOR = vec4(color, 1.0);
}
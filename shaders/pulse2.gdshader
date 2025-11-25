shader_type spatial;
render_mode unshaded;

// --- CONFIG ---
uniform int pulse_count = 0;

uniform vec3 pulse_origins[16];
uniform float pulse_radii[16];

// NEW: per-pulse width array
uniform float pulse_widths[16];

// OLD: fallback width (used only if pulse_widths[i] == 0)
uniform float default_pulse_width = 10.0;

uniform vec4 pulse_color : source_color = vec4(1.0);
uniform float world_scale = 0.95;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

varying mat4 CAMERA;


// ----------------------------------------
// sdf helpers
// ----------------------------------------
float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

float when_lt(float a, float b) {
    return max(sign(b - a), 0.0);
}

float when_gt(float a, float b) {
    return max(sign(a - b), 0.0);
}


// ----------------------------------------
// vertex
// ----------------------------------------
void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
    CAMERA = INV_VIEW_MATRIX;
}


// ----------------------------------------
// fragment — NOW PER-PULSE WIDTH
// ----------------------------------------
void fragment() {
    vec4 original = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0);
    float depth = textureLod(DEPTH_TEXTURE, SCREEN_UV, 0.0).x;

    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
    vec4 world = CAMERA * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    vec3 world_position = world.xyz / world.w;

    float best_contrib = 0.0;

    for (int i = 0; i < pulse_count; i++) {
        vec3 origin = pulse_origins[i];
        float radius = pulse_radii[i];

        // get width: if array element is zero, use default width
        float pwidth = pulse_widths[i];
        if (pwidth <= 0.0) {
            pwidth = default_pulse_width;
        }

        // SDF
        float dist = sdSphere((world_position - origin) * world_scale, radius * world_scale);

        float check = when_lt(dist, 0.0) * when_gt(dist, -pwidth);
        float pct = abs(dist) / abs(pwidth);
        float mix_ratio = clamp(check - pct, 0.0, 1.0);

        best_contrib = max(best_contrib, mix_ratio);
    }

    ALBEDO = mix(original.rgb, pulse_color.rgb, best_contrib);
}

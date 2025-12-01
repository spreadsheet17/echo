shader_type spatial;
//render_mode unshaded;

// --- CONFIG ---
uniform int pulse_count = 0;

uniform vec3 pulse_origins[50];
uniform float pulse_radii[50];
uniform float pulse_widths[50];
uniform float default_pulse_width = 10.0;

uniform vec4 pulse_colors[50];
uniform vec4 pulse_alphas[50];

uniform float world_scale = 0.95;
uniform float emission_strength = 2.0; // <--- NEW

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

varying mat4 CAMERA;


// ----------------------------------------
float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

float when_lt(float a, float b) { return max(sign(b - a), 0.0); }
float when_gt(float a, float b) { return max(sign(a - b), 0.0); }


// ----------------------------------------
void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
    CAMERA = INV_VIEW_MATRIX;
}


// ----------------------------------------
void fragment() {
    vec4 original = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0);
    float depth = textureLod(DEPTH_TEXTURE, SCREEN_UV, 0.0).x;

    vec3 final_color = vec3(0.0);
    float final_mix = 0.0;

    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
    vec4 world = CAMERA * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    vec3 world_position = world.xyz / world.w;

    for (int i = 0; i < pulse_count; i++) {
        float width = pulse_widths[i];
        if (width <= 0.0) width = default_pulse_width;

        float dist = sdSphere((world_position - pulse_origins[i]) * world_scale,
                              pulse_radii[i] * world_scale);

        float check = when_lt(dist, 0.0) * when_gt(dist, -width);
        float pct = abs(dist) / abs(width);
        float mix_ratio = clamp(check - pct, 0.0, 1.0);
		float fade = pulse_alphas[i].a;
		mix_ratio *= fade;
        final_mix = max(final_mix, mix_ratio);

        // blended color
        final_color = mix(final_color, pulse_colors[i].rgb, mix_ratio);
    }

    // base scene
    ALBEDO = final_color;

    // emission only on pulse intensity
    EMISSION = final_color * final_mix * emission_strength;

    ALPHA = 1.0;
}

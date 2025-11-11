// multi_pulse.shader
shader_type spatial;
render_mode unshaded;

uniform int pulse_count = 0;
uniform vec3 pulse_origins[16];
uniform float pulse_radii[16];
uniform float pulse_width = 10.0;
uniform vec4 pulse_color : source_color = vec4(1.0);
uniform float world_scale = 0.95;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

varying mat4 CAMERA;

float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

// small helpers
float when_lt(float left_side, float right_side) {
    return max(sign(right_side - left_side), 0.0);
}
float when_gt(float left_side, float right_side) {
    return max(sign(left_side - right_side), 0.0);
}

void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
    CAMERA = INV_VIEW_MATRIX;
}

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

        // simple SDF: distance from origin to world point minus radius
        //float dist = sdSphere(world_position - origin, radius);
		float dist = sdSphere((world_position - origin) * world_scale, radius * world_scale);

        float check = when_lt(dist, 0.0) * when_gt(dist, -pulse_width);
        float percentage = abs(dist) / abs(pulse_width);
        float mix_ratio = clamp(1.0 * check - percentage, 0.0, 1.0);

        // take max so overlapping pulses visually combine sensibly
        best_contrib = max(best_contrib, mix_ratio);
    }

    ALBEDO = mix(original.rgb, pulse_color.rgb, best_contrib);
}

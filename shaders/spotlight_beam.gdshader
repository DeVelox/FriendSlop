shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, unshaded;

uniform vec3 beam_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float beam_opacity : hint_range(0.0, 1.0) = 0.12;
uniform float beam_top_radius : hint_range(0.0, 50.0) = 0.2;
uniform float beam_bottom_radius : hint_range(0.0, 50.0) = 4.5;
uniform float beam_length : hint_range(0.0, 100.0) = 14.0;
uniform float edge_falloff : hint_range(0.1, 10.0) = 3.0;
uniform float view_falloff : hint_range(0.0, 5.0) = 1.2;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.3;

varying float v_height_normalized;

void vertex() {
	v_height_normalized = (VERTEX.y + beam_length * 0.5) / beam_length;
}

void fragment() {
	float t = clamp(v_height_normalized, 0.0, 1.0);

	float local_radius = mix(beam_top_radius, beam_bottom_radius, t);
	float radial_dist = length(UV - vec2(0.5));
	float normalized_dist = radial_dist / 0.5;
	float beam_falloff = 1.0 - smoothstep(0.0, 1.0, normalized_dist);
	beam_falloff = pow(beam_falloff, edge_falloff);

	vec3 view_dir = normalize(VIEW);
	float ndotv = abs(dot(NORMAL, VIEW));
	float view_factor = pow(ndotv, view_falloff);

	float depth_fade = 1.0 - pow(t, 0.8);
	float alpha = beam_opacity * beam_falloff * view_factor * depth_fade;

	ALBEDO = beam_color * (1.0 + glow_strength);
	ALPHA = alpha;
}

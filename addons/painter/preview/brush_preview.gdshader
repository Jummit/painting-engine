shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disable;

uniform sampler2D albedo : hint_white;
uniform sampler2D tip : hint_white;

void fragment() {
	// Flip to match painting shader.
	vec2 uv = vec2(1.0) - UV;
	ALBEDO = texture(albedo, vec2(1.0 - uv.x, uv.y)).rgb * 100.0;
	vec4 strength = texture(tip, vec2(1.0 - uv.x, uv.y));
	ALPHA = strength.r * strength.a * 0.7;
}

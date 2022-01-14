shader_type spatial;
render_mode unshaded, cull_disabled;

uniform mat4 brush_transform;
uniform vec4 brush_color = vec4(1.0);
uniform sampler2D albedo : hint_white;
uniform sampler2D tip : hint_white;
uniform sampler2D stencil : hint_black;
uniform mat4 stencil_transform;
uniform bool erase = false;
uniform sampler2D previous;
uniform float max_opacity = 1.0;

varying vec2 view_uv;
varying vec3 position;
varying vec3 normal;

const float DEPTH_OFFSET = 0.3;

void vertex() {
	POSITION = vec4(vec2(0.5, 0.5) - vec2(1.0 - UV.x, UV.y), 0.0, 0.5);
	view_uv = (vec4(VERTEX, 1.0) * inverse(MODELVIEW_MATRIX)).xy;
	position = VERTEX.xyz;
	normal = NORMAL;
}

vec3 triplanar_mapped_texture(sampler2D sampler) {
	vec3 uv_power_normal = abs(normal);
	vec4 color = vec4(0.0);
	color += texture(sampler, position.xy) * uv_power_normal.z;
	color += texture(sampler, position.xz) * uv_power_normal.y;
	color += texture(sampler, position.zy) * uv_power_normal.x;
	return color.rgb / 1.5;
}

void fragment() {
	// TODO: Optimize this.
	// TODO: Make small brushes not be low opacity.
	mat4 offset_uv_transform = mat4(
		vec4(1.0, 0.0, 0.0, 0.5),
		vec4(0.0, 1.0, 0.0, 0.5),
		vec4(0.0, 0.0, 1.0, DEPTH_OFFSET),
		vec4(0.0, 0.0, 0.0, 0.0));
	vec3 brush_space = (inverse(brush_transform) * vec4(position, 1) * offset_uv_transform).xyz;
	brush_space = clamp(brush_space, vec3(0), vec3(1.0));
	vec2 brush_uv = brush_space.xy;
	float depth = 1.0 - smoothstep(0.0, 0.4, abs(brush_space.z - DEPTH_OFFSET));
	float facing = clamp(dot(
		max(brush_transform[2].xyz, normalize(brush_transform[2].xyz) * 0.2) * 5.0,
		normal), 0.0, 1.0);
	float stencil_strength = texture(stencil, (vec4(view_uv, 1, 1) * stencil_transform).xy).a;
	float strength = texture(tip, brush_uv).r * texture(tip, brush_uv).a * brush_color.a * facing * depth * stencil_strength;
	if (any(lessThan(brush_uv, vec2(0.01))) || any(greaterThan(brush_uv, vec2(0.95))))
		strength = 0.0;
	// TODO: Better triplanar mapping for normal maps
//	ALBEDO = ALBEDO * (1.0 - strength) +
//			triplanar_mapped_texture(albedo) * strength;
	vec4 previous_color = texture(previous, vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y));
	ALBEDO = texture(albedo, UV).rgb * brush_color.rgb;
	if (previous_color.a > 0.0)
		ALBEDO = mix(previous_color.rgb, ALBEDO, strength);
	ALPHA = clamp(max(previous_color.a, strength), 0, max_opacity);
	// Premultiply alpha because viewports with transparent backgrounds become
	// darker otherwise: https://github.com/godotengine/godot/issues/17574
	if (ALPHA > 0.0)
		ALBEDO /= ALPHA;
}

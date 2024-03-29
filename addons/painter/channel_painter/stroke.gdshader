shader_type spatial;
render_mode unshaded, cull_disabled;

/*
Shader that handles the painting; the core of the painting engine.

The scene is set up so that the camera and the model have the same transform as
the painter sees it.
As the result is a texture which can be applied in UV-space, the model is then
transformed into a quad in front of the camera.
All of this is done to preserve the information about the camera transform.

The shader gets passed the pre-calculated transform of the brush, with
translation, rotation and scale already figured out.

The brush tip is then projected into surface-space using that transform.
*/

uniform int strokes;
uniform mat4[40] brush_transforms;
uniform vec4[40] colors : source_color;
uniform sampler2D albedo : hint_default_white;
uniform sampler2D tip : hint_default_white;
uniform mat4 stencil_transform;
uniform sampler2D previous;
uniform float max_opacity = 1.0;

varying vec2 view_uv;
varying vec3 position;
varying vec3 normal;

const float DEPTH_OFFSET = 0.3;

void vertex() {
	POSITION = vec4(vec2(UV.x, UV.y) - vec2(.5), 0.0, 0.5);
	position = VERTEX.xyz;
	normal = NORMAL;
}

// TODO: Better triplanar mapping for normal maps
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
	ALPHA = 0.0;
	mat4 offset_uv_transform = mat4(
		vec4(1.0, 0.0, 0.0, 0.5),
		vec4(0.0, 1.0, 0.0, 0.5),
		vec4(0.0, 0.0, 1.0, DEPTH_OFFSET),
		vec4(0.0, 0.0, 0.0, 0.0));
	for (int i = 0; i < strokes; i++) {
		mat4 brush_transform = brush_transforms[i];
		vec3 brush_space = (inverse(brush_transform) * vec4(position, 1) * offset_uv_transform).xyz;
		brush_space = clamp(brush_space, vec3(0), vec3(1.0));
		vec2 brush_uv = brush_space.xy;
		float depth = 1.0 - smoothstep(0.0, 0.4, abs(brush_space.z - DEPTH_OFFSET));
		float facing = clamp(dot(max(brush_transform[2].xyz, normalize(brush_transform[2].xyz) * 0.2) * 5.0,normal), 0.0, 1.0);
		vec4 brush_color = colors[i];
		float strength = texture(tip, brush_uv).r * texture(tip, brush_uv).a * brush_color.a * facing * depth;
		ALPHA += strength;
	}
	vec4 prev = texture(previous, vec2(SCREEN_UV.x, SCREEN_UV.y));
	ALPHA = min(prev.a + ALPHA, max_opacity);
	ALBEDO = prev.rgb;
	if (ALPHA > 0.0) {
		ALBEDO = triplanar_mapped_texture(albedo).rgb * colors[0].rgb;
		// Premultiply alpha because viewports with transparent backgrounds become
		// darker otherwise: https://github.com/godotengine/godot/issues/17574
		ALBEDO /= ALPHA;
	}
}

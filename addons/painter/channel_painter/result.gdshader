shader_type canvas_item;
render_mode unshaded, blend_disabled;

/*
Shader that applies a stroke to the existing result.
*/

uniform sampler2D previous : hint_default_white;
uniform sampler2D stroke : hint_default_white;
uniform sampler2D seams : hint_default_transparent;
uniform bool erase;

void fragment() {
	vec4 offset = texture(seams, UV);
	vec2 uv = offset.a == 1.0 ? offset.xy : UV;
//	uv = UV; // TODO: Remove.
	vec4 stroke_color = texture(stroke, uv);
	vec4 previous_color = texture(previous, UV);
	if (erase) {
		COLOR = previous_color;
		COLOR.a -= stroke_color.a;
	} else {
		COLOR.rgb = mix(previous_color.rgb, stroke_color.rgb, stroke_color.a);
		COLOR.a = max(previous_color.a, stroke_color.a);
	}
}

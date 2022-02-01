shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D previous;
uniform sampler2D stroke;
uniform sampler2D seams;
uniform bool erase;
uniform float strength = 0.031;

void fragment() {
	vec2 offset = (texture(seams, UV).rg - vec2(.5)) * 2.0;
	vec2 uv = UV + offset * strength;
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
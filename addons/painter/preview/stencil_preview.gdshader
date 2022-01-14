shader_type canvas_item;
render_mode unshaded;

uniform mat4 transform;

void fragment() {
	COLOR = texture(TEXTURE, (vec4(UV, 1.0, 1.0) * transform).xy);
}

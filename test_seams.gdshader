shader_type canvas_item;

uniform sampler2D tex;
uniform sampler2D seam;
uniform float scale = 1;
uniform bool on;

void fragment() {
	if (on) {
	COLOR = texture(tex, UV + (texture(seam, UV).xy - vec2(.5)) * scale);
	} else {
	COLOR = texture(tex, UV);
	}
//	COLOR = texture(seam, UV);
}

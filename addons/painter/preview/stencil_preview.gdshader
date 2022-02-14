shader_type canvas_item;
render_mode unshaded;

uniform mat4 transform;

void fragment() {
	mat4 trans = transform;
	trans[1] = trans[1];
//	trans[2] = vec4(1.0) - trans[2];
	COLOR = texture(TEXTURE, ((vec4(UV - trans[3].xy, 1, 1) * inverse(trans)).xy + vec2(.5, .5)));
	COLOR.a = min(COLOR.a, COLOR.r);
}

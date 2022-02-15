shader_type canvas_item;
render_mode unshaded;

uniform mat4 transform;

void fragment() {
	COLOR = texture(TEXTURE, ((vec4(UV - transform[3].xy, 1, 1)
			* inverse(transform)).xy + vec2(.5, .5)));
	COLOR.a = min(COLOR.a, COLOR.r);
}

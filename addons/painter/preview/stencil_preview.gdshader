shader_type canvas_item;
render_mode unshaded;

uniform mat4 transform;

void fragment() {
	vec2 uv = UV;
	uv = (vec4(uv - transform[3].xy, 1, 1)
			* inverse(transform)).xy + vec2(.5, .5);
	COLOR = texture(TEXTURE, uv);
	COLOR.a = min(COLOR.a, COLOR.r);
}

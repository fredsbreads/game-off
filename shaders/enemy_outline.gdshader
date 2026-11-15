shader_type canvas_item;
// The enemy sprite, plus a thin red outline ("glint") while a teleport would
// slash him. `glint` 0..1 fades it in and out; the node's modulate (his
// death fade) still applies.

uniform vec4 outline_color : source_color = vec4(1.0, 0.15, 0.2, 1.0);
uniform float glint = 0.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.0) {
		COLOR = c * tint;
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		float shimmer = 0.8 + 0.2 * sin(TIME * 9.0);
		float a = n > 0.0 ? outline_color.a * glint * shimmer * tint.a : 0.0;
		COLOR = vec4(outline_color.rgb, a);
	}
}

shader_type canvas_item;
// The enemy sprite, plus a thin red outline ("glint") while a teleport would
// slash him. `glint` 0..1 fades it in and out; the node's modulate (his
// death fade) still applies.

uniform vec4 outline_color : source_color = vec4(1.0, 0.15, 0.2, 1.0);
uniform float glint = 0.0;
// Knights draw their slash arc (the pure white pixels) behind their body:
// 0 = everything, 1 = all but the arc (the body, in front), 2 = only the arc.
uniform int white_part = 0;

varying vec4 tint;

bool is_arc(vec4 c) {
	return c.a > 0.0 && c.r > 0.999 && c.g > 0.999 && c.b > 0.999;
}

// A neighbour's alpha for the outline, counting only the part this sprite
// draws: his body hugs his body, the arc copy outlines the arc.
float part_alpha(vec4 c) {
	if (white_part == 1 && is_arc(c)) {
		return 0.0;
	}
	if (white_part == 2 && !is_arc(c)) {
		return 0.0;
	}
	return c.a;
}


void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool arc = is_arc(c);
	if (white_part == 2 && arc) {
		COLOR = c * tint;
	} else if (white_part != 2 && c.a > 0.0 && !(white_part == 1 && arc)) {
		COLOR = c * tint;
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float n = part_alpha(texture(TEXTURE, UV + vec2(px.x, 0.0))) + part_alpha(texture(TEXTURE, UV - vec2(px.x, 0.0)))
			+ part_alpha(texture(TEXTURE, UV + vec2(0.0, px.y))) + part_alpha(texture(TEXTURE, UV - vec2(0.0, px.y)));
		float shimmer = 0.8 + 0.2 * sin(TIME * 9.0);
		float a = n > 0.0 ? outline_color.a * glint * shimmer * tint.a : 0.0;
		COLOR = vec4(outline_color.rgb, a);
	}
}

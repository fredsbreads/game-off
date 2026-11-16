shader_type canvas_item;
// An afterimage of her: the sprite's shape filled with `fill`, with an
// optional 1-pixel `outline` around it (drawn just outside the shape).
// The node's modulate alpha fades the whole thing.

#include "res://shaders/accent.gdshaderinc"

uniform vec4 fill : source_color = vec4(1.0, 0.3, 0.3, 0.5);
uniform vec4 outline : source_color = vec4(0.0);

varying float fade;

void vertex() {
	fade = COLOR.a;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	if (a > 0.0) {
		COLOR = vec4(accent(fill.rgb, SCREEN_UV.x), fill.a * fade);
	} else if (n > 0.0 && outline.a > 0.0) {
		COLOR = vec4(accent(outline.rgb, SCREEN_UV.x), outline.a * fade);
	} else {
		discard;
	}
}

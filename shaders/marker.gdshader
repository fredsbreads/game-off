shader_type canvas_item;
// A teleport marker: a small katana silhouette. Plain by default; the part
// within `fill` of the tip (0 = none, 1 = all) is `lit`. During the "your
// move" freeze the fill drains toward the tip as time runs out.

#include "res://shaders/accent.gdshaderinc"

uniform vec4 plain : source_color = vec4(1.0, 1.0, 1.0, 0.32);
uniform vec4 lit : source_color = vec4(0.95, 0.15, 0.2, 1.0);
uniform float fill = 0.0;
uniform float lit_mix = 1.0;   // eases the lit part between plain (0) and lit (1)
uniform vec4 outline : source_color = vec4(0.0);   // a dark edge round the katana (alpha 0: none; the forest background has one)

void fragment() {
	float a = texture(TEXTURE, UV).a;
	if (a == 0.0) {
		float near = 0.0;
		if (outline.a > 0.0) {
			vec2 px = TEXTURE_PIXEL_SIZE;
			near = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
					max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		}
		if (near == 0.0) {
			discard;
		}
	}
	// The image (the diagonal sword) has the hilt at the top and the tip at
	// the bottom.
	COLOR = UV.y >= 1.0 - fill ? mix(plain, lit, lit_mix) : plain;
	COLOR.rgb = accent(COLOR.rgb, SCREEN_UV.x);
	if (a == 0.0) {
		COLOR = outline;   // (the edge round it)
	}
}

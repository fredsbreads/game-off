shader_type canvas_item;
// Her death: she fizzles out in little blocks. `amount` 0 = whole, 1 = gone.
// The blocks about to vanish glow (white-hot to red), like she was zapped.

#include "res://shaders/accent.gdshaderinc"

uniform float amount = 0.0;
uniform vec4 edge_hot : source_color = vec4(1.0, 0.95, 0.9, 1.0);
uniform vec4 edge_red : source_color = vec4(1.0, 0.15, 0.2, 1.0);
uniform float edge = 0.14;
uniform float block = 2.0;   // art pixels per dissolving block
// Before she dissolves (the death freeze): a scattering of her blocks glow
// without vanishing. `sparkle` = how many (0..1); change `seed` to re-scatter.
uniform float sparkle = 0.0;
uniform float seed = 0.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * tint;
	if (c.a == 0.0) {
		discard;
	}
	if (amount <= 0.0) {
		vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE / block);
		float s = hash(cell + vec2(seed, seed * 1.7));
		if (s < sparkle) {
			COLOR = vec4(mix(edge_hot.rgb, edge_red.rgb, s / max(sparkle, 0.001)), c.a);
		} else {
			COLOR = c;
		}
		COLOR.rgb = accent(COLOR.rgb, SCREEN_UV.x);
	} else {
		vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE / block);
		float n = hash(cell);
		if (n < amount) {
			discard;
		}
		if (n < amount + edge) {
			float k = (n - amount) / edge;   // 0 = about to go
			COLOR = vec4(mix(edge_hot.rgb, edge_red.rgb, k), c.a);
		} else {
			COLOR = c;
		}
		COLOR.rgb = accent(COLOR.rgb, SCREEN_UV.x);
	}
}

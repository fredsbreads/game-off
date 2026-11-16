shader_type canvas_item;
// A slash arc that sweeps along the swing. t_map says how far along the swing
// each pixel is (0 = start, 1 = the sword tip). Pixels up to `progress` show;
// the newest part is brightest while it sweeps. `fade` dims the whole arc
// as it goes.

uniform sampler2D t_map : filter_nearest;
uniform float progress = 0.0;
uniform float fade = 1.0;
uniform float max_alpha = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = texture(t_map, UV).r;
	if (c.a == 0.0 || t > progress) {
		discard;
	}
	// While it sweeps the trailing part is a little dimmer; once the swing is
	// done the whole slash is solid (as white as a knight's).
	float trail = progress >= 1.0 ? 1.0 : 0.55 + 0.45 * (1.0 - (progress - t));
	float a = max_alpha * fade * trail;
	COLOR = vec4(c.rgb, c.a * clamp(a, 0.0, 1.0));
}

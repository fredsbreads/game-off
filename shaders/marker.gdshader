shader_type canvas_item;
// A teleport marker: the katana's silhouette. Plain by default; the part
// within `fill` of the tip (0 = none, 1 = all) is `lit`. During the "your
// move" freeze the fill drains toward the tip as time runs out.

uniform vec4 plain : source_color = vec4(1.0, 1.0, 1.0, 0.32);
uniform vec4 lit : source_color = vec4(0.95, 0.15, 0.2, 1.0);
uniform float fill = 0.0;

void fragment() {
	float a = texture(TEXTURE, UV).a;
	if (a == 0.0) {
		discard;
	}
	// The image has the tip at the top (UV.y = 0) and the hilt at the bottom.
	COLOR = UV.y <= fill ? lit : plain;
}

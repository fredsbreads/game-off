shader_type canvas_item;
// A plain sprite in her colour (red, or pink from level 10): her body (her
// hair), her lightning. See accent.gdshaderinc.

#include "res://shaders/accent.gdshaderinc"

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(accent(c.rgb), c.a);
}

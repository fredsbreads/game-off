shader_type canvas_item;
// A flat silhouette: the sprite's shape, filled with the node's modulate
// colour (a teleporter's next spot, faint, in his colour).

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(COLOR.rgb, a * COLOR.a);
}

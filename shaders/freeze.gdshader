shader_type canvas_item;
// Full-screen effect for the kill pause. Reads what's already been drawn
// below this layer (the world) and inverts and/or greys it out.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float invert : hint_range(0.0, 1.0) = 0.0;
uniform float grey : hint_range(0.0, 1.0) = 0.0;
uniform float grey_darken : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l * grey_darken), grey);
	c = mix(c, vec3(1.0) - c, invert);
	COLOR = vec4(c, 1.0);
}

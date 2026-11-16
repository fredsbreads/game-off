// Her colour. Red until level 10, then pink: `accent_pink` (a global, set by
// Palette.set_pink) moves every reddish pixel toward pink, 0 = red, 1 = pink.
// Only reds move: whites, greys, greens (the knight) stay as they are.
// Palette.tint() in palette.gd is the same thing for colours set in code.

global uniform float accent_pink;
// The change-over sweeps across the screen right to left: pixels right of
// this (a screen x, 0..1) are pink, left of it still red, with a bright edge
// on the line. -1 = all of them (the usual).
global uniform float accent_wipe;

const float ACCENT_PINK_HUE = 0.925;   // ~333 degrees
const float ACCENT_PINK_SAT = 0.7;     // pink is a little softer than her red

vec3 accent_rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 accent_hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// `sx`: the pixel's screen x (SCREEN_UV.x).
vec3 accent(vec3 c, float sx) {
	if (accent_pink <= 0.0) {
		return c;
	}
	vec3 hsv = accent_rgb2hsv(c);
	float from_red = min(hsv.x, 1.0 - hsv.x);   // hue distance from red (0..0.5)
	float w = (1.0 - smoothstep(0.05, 0.11, from_red)) * smoothstep(0.12, 0.3, hsv.y);
	vec3 pink = accent_hsv2rgb(vec3(ACCENT_PINK_HUE, hsv.y * ACCENT_PINK_SAT, min(1.0, hsv.z * 1.05 + 0.04)));
	float swept = smoothstep(accent_wipe - 0.002, accent_wipe + 0.002, sx);
	vec3 out_c = mix(c, pink, w * accent_pink * swept);
	if (accent_wipe > -0.5) {
		float edge = 1.0 - smoothstep(0.0, 0.01, abs(sx - accent_wipe));
		out_c = mix(out_c, vec3(1.0, 0.9, 0.97), w * edge * 0.9);
	}
	return out_c;
}

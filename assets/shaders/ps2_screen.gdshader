shader_type canvas_item;
// PS2-era screen filter (GDD "Görsel tarz"): washed, slightly cold colour, a little contrast,
// 5-bit-ish colour depth with ordered dithering, film grain and a soft vignette.
// Values live in ps2_screen.tres.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float saturation : hint_range(0.0, 1.5) = 0.8;
uniform float contrast : hint_range(0.5, 1.5) = 1.08;
uniform vec3 tint = vec3(0.95, 0.98, 1.04);
uniform float color_levels : hint_range(4.0, 256.0) = 32.0;
uniform float dither : hint_range(0.0, 2.0) = 1.0;
uniform float grain : hint_range(0.0, 0.3) = 0.05;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;

// 4x4 Bayer matrix, 0..1.
float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int index = i.x + i.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[index]) / 16.0;
}

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;
	float noise = fract(sin(dot(FRAGCOORD.xy + fract(TIME) * 97.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	c += noise * grain;
	float threshold = (bayer4(FRAGCOORD.xy) - 0.5) * dither / color_levels;
	c = floor((c + threshold) * color_levels + 0.5) / color_levels;
	vec2 centered = SCREEN_UV - 0.5;
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	c *= 1.0 - vignette * smoothstep(0.45, 1.05, length(centered) * 1.25);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}

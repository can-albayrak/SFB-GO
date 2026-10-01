shader_type canvas_item;
// Scope view blur while moving (CS-style: a moving sniper sees, and shoots, worse).
// `amount` 0..1 picks a blurrier mip of the screen.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float max_lod = 3.5;

void fragment() {
	COLOR = vec4(textureLod(screen_texture, SCREEN_UV, amount * max_lod).rgb, 1.0);
}

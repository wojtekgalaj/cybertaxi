shader_type canvas_item;
// Full-screen CRT post-process: curvature, scanlines, vignette, mild chroma.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

uniform float curvature : hint_range(0.0, 0.25) = 0.06;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.28;
uniform float scanline_count : hint_range(60.0, 480.0) = 180.0;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.55;
uniform float chroma_offset : hint_range(0.0, 0.004) = 0.0012;
uniform float brightness : hint_range(0.5, 1.5) = 1.05;
uniform float contrast : hint_range(0.5, 1.5) = 1.08;
uniform float mask_strength : hint_range(0.0, 0.4) = 0.12;


vec2 curve_uv(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) * curvature;
	uv += uv * offset * offset;
	uv = uv * 0.5 + 0.5;
	return uv;
}


void fragment() {
	vec2 uv = curve_uv(SCREEN_UV);
	bool inside = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
	vec2 sample_uv = clamp(uv, vec2(0.0), vec2(1.0));

	float r = texture(screen_texture, sample_uv + vec2(chroma_offset, 0.0)).r;
	float g = texture(screen_texture, sample_uv).g;
	float b = texture(screen_texture, sample_uv - vec2(chroma_offset, 0.0)).b;
	vec3 col = vec3(r, g, b);

	// Horizontal scanlines.
	float scan = sin(sample_uv.y * scanline_count * PI);
	scan = scan * 0.5 + 0.5;
	col *= mix(1.0, scan, scanline_strength);

	// RGB aperture grille (subtle).
	float mask = mod(floor(FRAGCOORD.x), 3.0);
	vec3 grille = vec3(
		mask == 0.0 ? 1.0 : 1.0 - mask_strength,
		mask == 1.0 ? 1.0 : 1.0 - mask_strength,
		mask == 2.0 ? 1.0 : 1.0 - mask_strength
	);
	col *= grille;

	// Soft vignette toward tube edges.
	vec2 vig_uv = sample_uv * (1.0 - sample_uv);
	float vig = vig_uv.x * vig_uv.y * 15.0;
	vig = pow(clamp(vig, 0.0, 1.0), vignette_strength);
	col *= vig;

	col = (col - 0.5) * contrast + 0.5;
	col *= brightness;
	col = clamp(col, vec3(0.0), vec3(1.0));

	// Outside the curved tube: dark bezel.
	if (!inside) {
		col = vec3(0.01, 0.02, 0.03);
	}

	COLOR = vec4(col, 1.0);
}

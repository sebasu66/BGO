shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform int filter_mode = 0;
uniform float filter_strength : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float contrast : hint_range(0.5, 1.5) = 1.0;
uniform float temperature : hint_range(-1.0, 1.0) = 0.0;

vec3 grade_filter(vec3 color, int mode) {
	if (mode == 1) {
		float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
		vec3 shadows = vec3(0.76, 0.96, 1.08);
		vec3 highlights = vec3(1.08, 0.91, 0.72);
		return color * mix(shadows, highlights, smoothstep(0.18, 0.82, luma));
	}
	if (mode == 2) {
		float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
		return vec3(smoothstep(0.03, 0.96, luma));
	}
	if (mode == 3) {
		return color * vec3(1.12, 1.02, 0.88);
	}
	if (mode == 4) {
		return color * vec3(0.88, 1.02, 1.12);
	}
	if (mode == 5) {
		float luma = dot(color, vec3(0.299, 0.587, 0.114));
		vec3 sepia = vec3(luma * 1.12, luma * 0.96, luma * 0.73);
		return mix(sepia, color * vec3(1.06, 0.96, 0.82), 0.42);
	}
	if (mode == 6) {
		float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
		return mix(vec3(luma), color, 1.32);
	}
	if (mode == 7) {
		float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
		vec3 desaturated = mix(vec3(luma), color, 0.34);
		return (desaturated - 0.5) * 1.42 + 0.5;
	}
	if (mode == 8) {
		float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
		vec3 teal_shadows = color * vec3(0.72, 1.08, 1.16);
		vec3 orange_highlights = color * vec3(1.18, 0.96, 0.72);
		return mix(teal_shadows, orange_highlights, smoothstep(0.24, 0.76, luma));
	}
	if (mode == 9) {
		float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
		vec3 softened = mix(vec3(luma), color, 0.72);
		return softened * 0.76 + vec3(0.12, 0.105, 0.09);
	}
	if (mode == 10) {
		vec3 lifted = sqrt(max(color, vec3(0.0))) * vec3(1.03, 0.99, 1.07);
		float luma = dot(lifted, vec3(0.2126, 0.7152, 0.0722));
		return mix(vec3(luma), lifted, 0.76) * 1.04;
	}
	if (mode == 11) {
		float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
		vec3 moonlit = mix(color, vec3(luma) * vec3(0.46, 0.72, 1.14), 0.68);
		return (moonlit - 0.42) * 1.2 + 0.38;
	}
	return color;
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec3 color = source.rgb;
	color = mix(color, grade_filter(color, filter_mode), filter_strength);
	color *= mix(vec3(1.0, 1.0, 1.0 + (-temperature * 0.08)), vec3(1.0 + temperature * 0.08, 1.0, 1.0), step(0.0, temperature));
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luma), color, saturation);
	color = (color - 0.5) * contrast + 0.5;
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	centered.x *= SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.000001);
	float edge = smoothstep(0.52, 1.38, length(centered));
	color *= 1.0 - edge * vignette * 0.72;
	COLOR = vec4(max(color, vec3(0.0)), source.a);
}

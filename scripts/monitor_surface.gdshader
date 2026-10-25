shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D feed : source_color, filter_linear;
uniform bool monitor = true;
uniform float activation : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec3 color = texture(feed, UV).rgb;
	if (monitor) {
		float level = clamp(dot(color, vec3(0.299, 0.587, 0.114)) * 1.7, 0.0, 1.0);
		vec3 dark = vec3(0.031, 0.055, 0.161);
		vec3 middle = vec3(0.259, 0.420, 0.761);
		color = level < 0.55 ? mix(dark, middle, level / 0.55) : mix(middle, vec3(0.835, 0.980, 0.965), (level - 0.55) / 0.45);
		float noise = fract(sin(dot(floor(UV * vec2(400.0, 300.0)), vec2(12.9898, 78.233)) + floor(TIME * 12.0)) * 43758.5453) - 0.5;
		color += vec3(sin(UV.y * 440.0) * 0.024 + noise * 0.035);
		color *= 1.0 - dot(UV - vec2(0.5), UV - vec2(0.5)) * 0.5;
	}
	ALBEDO = color * activation;
}

shader_type canvas_item;
uniform bool monitor = true;
uniform bool peephole = false;
uniform float aspect = 2.8;
uniform float grain_strength = 0.025;
void fragment() {
	vec2 uv = UV;
	vec2 p = uv - vec2(0.5);
	float edge = length(vec2(p.x * aspect, p.y));
	vec4 scene = texture(TEXTURE, uv);
	float luma = dot(scene.rgb, vec3(0.299, 0.587, 0.114));
	if (monitor) {
		vec3 dark = vec3(0.031, 0.055, 0.161);
		vec3 middle = vec3(0.259, 0.420, 0.761);
		vec3 bright = vec3(0.835, 0.980, 0.965);
		float level = clamp(luma * 1.7, 0.0, 1.0);
		scene.rgb = level < 0.55 ? mix(dark, middle, level / 0.55) : mix(middle, bright, (level - 0.55) / 0.45);
		float line = sin(uv.y * 510.0) * 0.025;
		float noise = fract(sin(dot(floor(uv * vec2(640.0, 360.0)), vec2(12.9898, 78.233)) + floor(TIME * 12.0)) * 43758.5453) - 0.5;
		scene.rgb += vec3(line + noise * grain_strength);
		scene.rgb *= 1.0 - dot(p, p) * 0.55;
	} else {
		scene.rgb *= 1.0 - dot(p, p) * 0.35;
	}
	if (peephole) {
		float mask = 1.0 - smoothstep(0.43, 0.49, edge);
		scene.rgb = mix(vec3(0.006, 0.009, 0.010), scene.rgb, mask);
	}
	COLOR = vec4(scene.rgb, scene.a);
}

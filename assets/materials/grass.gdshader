shader_type spatial;

uniform sampler2D grass_texture : source_color, repeat_enable, filter_linear_mipmap;

varying vec2 world_xz;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), blend.x),
		blend.y
	);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float variation = mix(noise2(world_xz * 0.18), noise2(world_xz * 0.055 + vec2(13.7, 8.1)), 0.5);
	ALBEDO = texture(grass_texture, UV).rgb * mix(0.82, 1.18, variation);
	ROUGHNESS = 1.0;
}

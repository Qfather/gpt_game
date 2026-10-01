shader_type spatial;

uniform vec4 color_a : source_color = vec4(0.95, 0.22, 0.48, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.42, 0.62, 1.0);
uniform vec4 color_c : source_color = vec4(0.75, 0.12, 0.36, 1.0);
uniform vec4 color_d : source_color = vec4(1.0, 0.68, 0.76, 1.0);
uniform float palette_seed = 0.0;

varying float palette_value;

void vertex() {
	vec3 object_position = MODEL_MATRIX[3].xyz;
	float position_hash = dot(floor(object_position * 4.0), vec3(12.9898, 78.233, 37.719));
	palette_value = fract(sin(position_hash + palette_seed) * 43758.5453);
}

void fragment() {
	if (palette_value < 0.25) {
		ALBEDO = color_a.rgb;
	} else if (palette_value < 0.5) {
		ALBEDO = color_b.rgb;
	} else if (palette_value < 0.75) {
		ALBEDO = color_c.rgb;
	} else {
		ALBEDO = color_d.rgb;
	}
	ROUGHNESS = 1.0;
}

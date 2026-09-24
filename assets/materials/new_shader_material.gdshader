shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// ================================
// 基础材质
// ================================

uniform sampler2D albedo_texture : source_color;
uniform vec4 base_color : source_color = vec4(1.0);

// ================================
// 边缘磨损
// ================================

uniform vec4 edge_color : source_color = vec4(
	1.0, 0.75, 0.42, 1.0
);

uniform float edge_strength : hint_range(0.0, 1.0) = 0.45;

// 越高，只有明显的倒角才会被识别
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.15;

uniform float edge_sharpness : hint_range(0.1, 10.0) = 3.0;


// ================================
// 计算倒角区域
// ================================

float get_edge_mask(vec3 normal) {

	vec3 n = abs(normalize(normal));

	// 找到法线最接近 XYZ 主轴的程度
	float major_axis = max(
		n.x,
		max(n.y, n.z)
	);

	// 平面：
	// (1,0,0)
	// major_axis ≈ 1
	//
	// 倒角：
	// (0.7,0.7,0)
	// major_axis < 1

	float edge = 1.0 - major_axis;

	edge = smoothstep(
		edge_threshold,
		edge_threshold + 0.25,
		edge
	);

	edge = pow(edge, edge_sharpness);

	return edge;
}


// ================================
// Fragment
// ================================

void fragment() {

	vec4 tex = texture(albedo_texture, UV);

	vec3 color = tex.rgb * base_color.rgb;

	// 使用模型空间法线
	float edge = get_edge_mask(NORMAL);

	// 边缘提亮
	color = mix(
		color,
		edge_color.rgb,
		edge * edge_strength
	);

	ALBEDO = color;

	ROUGHNESS = 0.8;
}
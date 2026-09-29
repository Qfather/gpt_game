shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform sampler2D water_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D surface_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 shallow_color : source_color = vec4(0.24, 0.64, 0.86, 1.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.33, 0.68, 1.0);
uniform vec4 very_deep_color : source_color = vec4(0.025, 0.12, 0.34, 1.0);
uniform vec4 shore_foam_color : source_color = vec4(0.73, 0.89, 0.98, 1.0);
uniform vec4 shore_wave_color : source_color = vec4(0.55, 0.76, 0.90, 1.0);
uniform vec4 surface_foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float normal_tiling = 5.0;
uniform float normal_strength = 0.152;
uniform float normal_speed = 0.035;
uniform float normal_pan_speed = 1.0;
uniform float normal_noise_intensity = 0.23;
uniform float normal_noise_tiling = 0.2;
uniform float deep_height = 2.34;
uniform float very_deep_height = 5.85;
uniform float base_opacity = 0.941;
uniform float shallows_opacity = 0.819;
uniform float shore_edge_opacity = 0.429;
uniform float shore_edge_thickness = 0.233;
uniform float shore_edge_noise_scale = 0.86;
uniform float shore_small_foam_opacity = 0.751;
uniform float shore_small_foam_tiling = 2.5;
uniform float shore_foam_intensity = 0.504;
uniform float shore_foam_noise_scale = 0.3;
uniform float shore_wave_speed = 0.147;
uniform float shore_wave_return_amount = 0.519;
uniform float shore_wave_fade_out_speed = 1.0;
uniform float shore_wave_fade_in_speed = 3.0;
uniform float shore_wave_oscillation = 1.0;
uniform float shore_wave_thickness = 0.133;
uniform float shore_wave_intensity = 0.226;
uniform bool enable_calm_surface_foam = true;
uniform float surface_foam_strength = 0.3;
uniform float surface_foam_tiling = 4.0;
uniform float surface_foam_speed = 0.012;
uniform float roughness = 0.397;

void fragment() {
	vec2 normal_uv = UV * normal_tiling;
	vec2 normal_noise_uv = UV * normal_noise_tiling + TIME * vec2(0.011, -0.008) * normal_pan_speed;
	vec2 normal_distortion = (texture(foam_noise, normal_noise_uv).rg - vec2(0.5)) * normal_noise_intensity * 0.05;
	vec2 normal_flow = TIME * normal_speed * normal_pan_speed * vec2(1.0, 0.37);
	vec3 normal_a = texture(water_normal, normal_uv + normal_flow + normal_distortion).rgb * 2.0 - 1.0;
	vec3 normal_b = texture(water_normal, normal_uv * 0.73 - normal_flow.yx * 0.61 - normal_distortion).rgb * 2.0 - 1.0;
	vec3 tangent_normal = normalize(vec3(normal_a.xy + normal_b.xy, max(normal_a.z + normal_b.z, 0.1)));
	NORMAL_MAP = tangent_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;

	float raw_scene_depth = texture(scene_depth, SCREEN_UV).r;
	vec4 scene_view_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_scene_depth, 1.0);
	scene_view_position.xyz /= scene_view_position.w;
	float water_depth = max(VERTEX.z - scene_view_position.z, 0.0);
	float shallow_factor = 1.0 - smoothstep(0.0, deep_height, water_depth);
	float very_deep_factor = smoothstep(deep_height, very_deep_height, water_depth);
	vec3 water_color = mix(deep_color.rgb, shallow_color.rgb, shallow_factor);
	water_color = mix(water_color, very_deep_color.rgb, very_deep_factor);

	float edge_noise = texture(foam_noise, UV * shore_edge_noise_scale + TIME * vec2(0.018, -0.012)).r;
	float edge_thickness = shore_edge_thickness * (0.75 + edge_noise * shore_foam_noise_scale);
	float edge_foam = (1.0 - smoothstep(0.0, edge_thickness, water_depth)) * shore_edge_opacity;
	float shore_reach = 1.0 - smoothstep(0.0, shore_edge_thickness * (shore_wave_fade_in_speed + shore_wave_fade_out_speed), water_depth);
	float small_noise = texture(foam_noise, UV * shore_small_foam_tiling + TIME * vec2(shore_wave_speed * 0.1, -shore_wave_speed * 0.07)).r;
	float small_foam = shore_reach * smoothstep(0.66, 0.82, small_noise) * shore_foam_intensity * shore_small_foam_opacity;
	float wave_frequency = 6.28318 * shore_wave_oscillation / max(shore_wave_thickness * 2.0, 0.001);
	float wave = 0.5 + 0.5 * sin(water_depth * wave_frequency - TIME * shore_wave_speed * 6.28318 + small_noise * 0.6);
	float wave_foam = shore_reach * smoothstep(0.72, 0.94, wave) * shore_wave_intensity * shore_wave_return_amount;
	float shoreline_foam = clamp(edge_foam + small_foam + wave_foam, 0.0, 1.0);
	vec2 surface_foam_uv = UV * surface_foam_tiling;
	float surface_noise_a = texture(surface_noise, surface_foam_uv + TIME * vec2(surface_foam_speed, surface_foam_speed * 0.37)).r;
	float surface_noise_b = texture(surface_noise, surface_foam_uv * 1.37 - TIME * vec2(surface_foam_speed * 0.61, surface_foam_speed)).r;
	float surface_detail = texture(foam_noise, surface_foam_uv * 1.8 + TIME * vec2(0.018, -0.012)).r;
	float surface_foam_pattern = smoothstep(0.62, 0.78, surface_noise_a * 0.65 + surface_noise_b * 0.35);
	surface_foam_pattern *= 0.72 + surface_detail * 0.28;
	float open_water = smoothstep(shore_edge_thickness * 1.2, very_deep_height * 0.5, water_depth);
	float surface_foam = surface_foam_pattern * surface_foam_strength * open_water;
	if (!enable_calm_surface_foam) {
		surface_foam = 0.0;
	}
	float foam = clamp(shoreline_foam + surface_foam, 0.0, 1.0);

	vec3 shore_color = mix(shore_foam_color.rgb, shore_wave_color.rgb, wave_foam);
	water_color = mix(water_color, shore_color, shoreline_foam);
	ALBEDO = mix(water_color, surface_foam_color.rgb, surface_foam);
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	float alpha = mix(base_opacity, shallows_opacity, shallow_factor);
	ALPHA = clamp(mix(alpha, 1.0, foam * 0.5), 0.0, 1.0);
}

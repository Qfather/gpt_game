shader_type sky;

uniform vec4 day_top_color : source_color = vec4(0.435, 0.651, 0.847, 1.0);
uniform vec4 day_horizon_color : source_color = vec4(0.780, 0.863, 0.918, 1.0);
uniform vec4 night_top_color : source_color = vec4(0.035, 0.055, 0.14, 1.0);
uniform vec4 night_horizon_color : source_color = vec4(0.16, 0.20, 0.32, 1.0);
uniform vec4 day_ground_color : source_color = vec4(0.38, 0.45, 0.48, 1.0);
uniform vec4 night_ground_color : source_color = vec4(0.10, 0.12, 0.17, 1.0);
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform float daylight = 1.0;
uniform float star_visibility = 0.0;
uniform bool clouds_enabled = true;
uniform float cloud_density = 0.50;
uniform float cloud_scale = 5.0;
uniform float cloud_opacity = 0.65;
uniform vec3 cloud_offset = vec3(0.0);

float hash_cell(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float hash_point(vec3 point) {
	vec3 p = fract(point * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 point) {
	vec3 cell = floor(point);
	vec3 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float n000 = hash_point(cell + vec3(0.0, 0.0, 0.0));
	float n100 = hash_point(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash_point(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash_point(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash_point(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash_point(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash_point(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash_point(cell + vec3(1.0, 1.0, 1.0));
	float x00 = mix(n000, n100, local.x);
	float x10 = mix(n010, n110, local.x);
	float x01 = mix(n001, n101, local.x);
	float x11 = mix(n011, n111, local.x);
	return mix(mix(x00, x10, local.y), mix(x01, x11, local.y), local.z);
}

float cloud_noise(vec3 point) {
	float total = 0.0;
	float amplitude = 0.5;
	float amplitude_sum = 0.0;
	for (int octave = 0; octave < 4; octave++) {
		total += value_noise(point) * amplitude;
		amplitude_sum += amplitude;
		point = point * 2.03 + vec3(17.1, 9.2, 13.7);
		amplitude *= 0.5;
	}
	return total / amplitude_sum;
}

void sky() {
	float sky_gradient = smoothstep(-0.025, 0.72, EYEDIR.y);
	vec3 top_color = mix(night_top_color.rgb, day_top_color.rgb, daylight);
	vec3 horizon_color = mix(night_horizon_color.rgb, day_horizon_color.rgb, daylight);
	vec3 color = mix(horizon_color, top_color, sky_gradient);
	if (EYEDIR.y < 0.0) {
		float ground_gradient = smoothstep(-0.72, 0.0, EYEDIR.y);
		vec3 ground_color = mix(night_ground_color.rgb, day_ground_color.rgb, daylight);
		color = mix(ground_color * 0.8, horizon_color, ground_gradient);
	}

	float sun_dot = dot(normalize(EYEDIR), normalize(sun_direction));
	float sun_disk = smoothstep(cos(0.030), cos(0.020), sun_dot) * daylight;
	float sun_glow = pow(max(sun_dot, 0.0), 180.0) * daylight * 0.22;
	float sunset_strength = (1.0 - smoothstep(0.0, 0.28, abs(sun_direction.y))) * (1.0 - daylight);
	float sunset_horizon = (1.0 - smoothstep(0.02, 0.28, abs(EYEDIR.y))) * sunset_strength;
	color = mix(color, vec3(0.95, 0.43, 0.25), sunset_horizon * 0.46);
	color += vec3(1.0, 0.83, 0.57) * (sun_disk + sun_glow);

	vec3 moon_direction = -normalize(sun_direction);
	float moon_dot = dot(normalize(EYEDIR), moon_direction);
	float moon_disk = smoothstep(cos(0.022), cos(0.015), moon_dot) * star_visibility;
	float moon_glow = pow(max(moon_dot, 0.0), 260.0) * star_visibility * 0.16;
	color += vec3(0.70, 0.79, 1.0) * (moon_disk * 0.95 + moon_glow);

	vec2 sky_uv = vec2(atan(EYEDIR.z, EYEDIR.x) / TAU + 0.5, acos(clamp(EYEDIR.y, -1.0, 1.0)) / PI);
	vec2 star_grid = sky_uv * vec2(180.0, 90.0);
	vec2 star_cell = floor(star_grid);
	vec2 star_local = fract(star_grid) - vec2(0.5);
	float star_random = hash_cell(star_cell);
	float star_shape = 1.0 - smoothstep(0.018, 0.060, length(star_local * vec2(1.0, 1.7)));
	float star_presence = step(0.990, star_random) * star_shape * step(0.0, EYEDIR.y);
	float twinkle = 0.72 + 0.28 * sin(TIME * (1.2 + star_random * 2.2) + star_random * TAU);
	color += vec3(0.72, 0.82, 1.0) * star_presence * twinkle * star_visibility;

	if (clouds_enabled && EYEDIR.y > -0.08) {
		vec3 cloud_position = normalize(EYEDIR + vec3(0.0, 0.18, 0.0)) * cloud_scale + cloud_offset;
		float cloud_field = cloud_noise(cloud_position);
		float cloud_shape = smoothstep(cloud_density, min(cloud_density + 0.20, 1.0), cloud_field);
		float cloud_horizon_mask = smoothstep(-0.08, 0.18, EYEDIR.y);
		float cloud_alpha = cloud_shape * cloud_opacity * cloud_horizon_mask;
		vec3 cloud_color = mix(vec3(0.13, 0.16, 0.25), vec3(0.92, 0.95, 0.98), daylight);
		cloud_color = mix(cloud_color, vec3(0.98, 0.58, 0.38), sunset_strength * 0.35);
		color = mix(color, cloud_color, cloud_alpha);
	}

	COLOR = color;
}

shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D fog_mask : repeat_disable, filter_linear;
uniform vec2 map_extent;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view /= view.w;
	vec3 world = (INV_VIEW_MATRIX * view).xyz;
	vec2 uv = world.xz / map_extent + vec2(0.5);
	vec2 texel = 1.5 / vec2(textureSize(fog_mask, 0));
	vec4 center_mask = texture(fog_mask, clamp(uv, vec2(0.0), vec2(1.0)));
	vec2 mask_values = 4.0 * center_mask.rb;
	mask_values += 2.0 * texture(fog_mask, clamp(uv + vec2(texel.x, 0.0), vec2(0.0), vec2(1.0))).rb;
	mask_values += 2.0 * texture(fog_mask, clamp(uv - vec2(texel.x, 0.0), vec2(0.0), vec2(1.0))).rb;
	mask_values += 2.0 * texture(fog_mask, clamp(uv + vec2(0.0, texel.y), vec2(0.0), vec2(1.0))).rb;
	mask_values += 2.0 * texture(fog_mask, clamp(uv - vec2(0.0, texel.y), vec2(0.0), vec2(1.0))).rb;
	mask_values += texture(fog_mask, clamp(uv + texel, vec2(0.0), vec2(1.0))).rb;
	mask_values += texture(fog_mask, clamp(uv - texel, vec2(0.0), vec2(1.0))).rb;
	mask_values += texture(fog_mask, clamp(uv + vec2(texel.x, -texel.y), vec2(0.0), vec2(1.0))).rb;
	mask_values += texture(fog_mask, clamp(uv + vec2(-texel.x, texel.y), vec2(0.0), vec2(1.0))).rb;
	mask_values /= 16.0;
	float mask = mask_values.x;
	if (world.y > center_mask.g * 32.0) {
		mask = max(mask, mask_values.y);
	}
	bool inside = all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)));
	ALBEDO = vec3(0.0);
	ALPHA = inside ? 0.7 * (1.0 - mask) : 0.7;
}

extends SceneTree

class ReferenceFog extends "res://Script/world/fog_of_war.gd":
	func _reveal_at(point: Vector3, sight_radius: float = SIGHT_RADIUS, tree_occluders: Array[Vector3] = []) -> void:
		sight_radius *= visibility_multiplier
		var center: Vector2i = _pixel(point)
		var radius := Vector2i(Vector2.ONE * sight_radius / extent * RESOLUTION) + Vector2i.ONE
		var origin := Vector2(point.x, point.z)
		var sight_limits: PackedFloat32Array = _tree_sight_limits(origin, sight_radius, tree_occluders)
		var visual_limits: PackedFloat32Array = _smooth_sight_limits(sight_limits)
		for y: int in range(maxi(0, center.y - radius.y), mini(RESOLUTION, center.y + radius.y + 1)):
			for x: int in range(maxi(0, center.x - radius.x), mini(RESOLUTION, center.x + radius.x + 1)):
				# 当前刷新中已被其他视野源完全照亮的像素，后续合并不会再改变结果。
				var old_pixel: Color = visual_map.get_pixel(x, y)
				if old_pixel.r == 1.0 and visibility_map.get_pixel(x, y).r == 1.0:
					continue
				var world: Vector2 = ((Vector2(x, y) + Vector2.ONE * 0.5) / RESOLUTION - Vector2.ONE * 0.5) * extent
				var offset: Vector2 = world - origin
				var distance: float = offset.length()
				if distance > sight_radius:
					continue
				var angle_index: int = posmod(floori((offset.angle() + PI) / TAU * ANGLE_SAMPLES), ANGLE_SAMPLES)
				var visible_distance: float = sight_limits[angle_index]
				if distance <= visible_distance:
					visibility_map.set_pixel(x, y, Color.WHITE)
					explored.set_pixel(x, y, Color(0.35, 0.35, 0.35))
				# 判定仍使用中心射线；画面使用预先平滑的树后边缘。
				var visual_angle: float = (offset.angle() + PI) / TAU * ANGLE_SAMPLES - 0.5
				var visual_index: int = floori(visual_angle)
				var visual_limit: float = lerpf(
					visual_limits[posmod(visual_index, ANGLE_SAMPLES)],
					visual_limits[posmod(visual_index + 1, ANGLE_SAMPLES)],
					visual_angle - visual_index
				)
				var strength: float = minf(
					1.0 - smoothstep(sight_radius - 2.0, sight_radius, distance),
					1.0 - smoothstep(maxf(0.0, visual_limit - 0.4), visual_limit + 1.2, distance)
				)
				visual_map.set_pixel(x, y, Color(maxf(old_pixel.r, strength), old_pixel.g, old_pixel.b, 1.0))

func _init() -> void:
	var actual = load("res://Script/world/fog_of_war.gd").new()
	var reference = ReferenceFog.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 418
	for multiplier: float in [1.0, 0.6, 1.5]:
		for fog in [actual, reference]:
			fog.extent = Vector2(80, 64)
			fog.visibility_multiplier = multiplier
			fog.explored = Image.create(256, 256, false, Image.FORMAT_L8)
			fog.visibility_map = Image.create(256, 256, false, Image.FORMAT_L8)
			fog.visual_map = Image.create(256, 256, false, Image.FORMAT_RGBA8)
		for refresh in range(3):
			for fog in [actual, reference]:
				fog.visibility_map.copy_from(fog.explored)
				fog.visual_map.fill(Color(0, 1, 0, 0))
				fog.fully_visible_pixels.resize(256 * 256)
				fog.fully_visible_pixels.fill(0)
				fog.merging_visibility = true
			var trees: Array[Vector3] = [Vector3(3, 2, 1), Vector3(-4, 1.5, 4), Vector3(8, 2.5, -3)]
			for source in range(20):
				var point := Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
				var radius: float = rng.randf_range(8, 18)
				actual._reveal_at(point, radius, trees)
				reference._reveal_at(point, radius, trees)
				for image_name: String in ["explored", "visibility_map", "visual_map"]:
					if actual.get(image_name).get_data() != reference.get(image_name).get_data():
						push_error("迷雾像素不等价：%s 倍率%s 刷新%s 视野源%s" % [image_name, multiplier, refresh, source])
						actual.free()
						reference.free()
						quit(1)
						return
	actual.free()
	reference.free()
	print("迷雾像素等价通过：3种视野倍率、连续3次刷新、20个重叠视野源及树遮挡，全部图像逐字节一致")
	quit()

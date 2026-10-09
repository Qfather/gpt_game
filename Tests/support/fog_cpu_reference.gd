extends "res://Script/world/fog_of_war.gd"



# 优化前的算法，供像素和显隐等价对照使用。

func _refresh_object_visibility() -> void:
	for group: String in ["enemies", "migrants", "resources", "buildings", "villagers", "vegetation", "treasure_camps", "wildlife", "loot_bundles"]:
		for object: Node in get_tree().get_nodes_in_group(group):
			if not object is Node3D or object.is_queued_for_deletion():
				continue
			if group == "loot_bundles" and object is TreasureCamp:
				continue
			var visible_now: bool = is_visible_at(object.global_position) or (
				object is ConstructionSite
				and object.building_data != null
				and object.building_data.id == &"torch"
			)
			object.set_meta("fog_hidden", not visible_now)
			var children: Dictionary = _get_visibility_children(object)
			# 树木和地形保留在黑色遮罩下；其余对象隐藏网格但保持根节点与 AI 运作。
			if not (group == "resources" and object.get_script() == TREE_SCRIPT):
				for mesh: Node in children.meshes:
					if group == "treasure_camps" and _belongs_to_camp_guard(mesh, object):
						continue
					if mesh is AggroRange3D:
						mesh._refresh_visibility()
						continue
					if not mesh.has_meta("fog_visible"):
						mesh.set_meta("fog_visible", mesh.visible)
					mesh.visible = visible_now and bool(mesh.get_meta("fog_visible"))
			for collider: Node in children.colliders:
				if group == "treasure_camps" and _belongs_to_camp_guard(collider, object):
					continue
				if not collider.has_meta("fog_pickable"):
					collider.set_meta("fog_pickable", collider.input_ray_pickable)
				collider.input_ray_pickable = visible_now and bool(collider.get_meta("fog_pickable"))
	var main: Node = get_tree().current_scene
	if main != null and main.get("selected_object") != null:
		var selected: Node3D = main.selected_object
		if is_instance_valid(selected) and not is_visible_at(selected.global_position) and not (
			selected is ConstructionSite
			and selected.building_data != null
			and selected.building_data.id == &"torch"
		):
			main.clear_selection()

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
			var pixel_index: int = y * RESOLUTION + x
			if merging_visibility and fully_visible_pixels[pixel_index] == 1:
				continue
			var world: Vector2 = ((Vector2(x, y) + Vector2.ONE * 0.5) / RESOLUTION - Vector2.ONE * 0.5) * extent
			var offset: Vector2 = world - origin
			var distance: float = offset.length()
			if distance > sight_radius:
				continue
			var old_pixel: Color = visual_map.get_pixel(x, y)
			if old_pixel.r == 1.0 and visibility_map.get_pixel(x, y).r == 1.0:
				if merging_visibility:
					fully_visible_pixels[pixel_index] = 1
				continue
			var angle: float = (offset.angle() + PI) / TAU * ANGLE_SAMPLES
			var angle_index: int = posmod(floori(angle), ANGLE_SAMPLES)
			var visible_distance: float = sight_limits[angle_index]
			if distance <= visible_distance:
				visibility_map.set_pixel(x, y, Color.WHITE)
				explored.set_pixel(x, y, Color(0.35, 0.35, 0.35))
			# 判定仍使用中心射线；画面使用预先平滑的树后边缘。
			var visual_angle: float = angle - 0.5
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
			if merging_visibility and strength >= 1.0 and distance <= visible_distance:
				fully_visible_pixels[pixel_index] = 1

func _tree_sight_limits(origin: Vector2, sight_radius: float = SIGHT_RADIUS, tree_occluders: Array[Vector3] = []) -> PackedFloat32Array:
	var limits := PackedFloat32Array()
	limits.resize(ANGLE_SAMPLES)
	limits.fill(sight_radius)
	if tree_occluders.is_empty(): tree_occluders = _collect_tree_occluders()
	for tree: Vector3 in tree_occluders:
		var offset: Vector2 = Vector2(tree.x, tree.y) - origin
		var distance: float = offset.length()
		var tree_radius: float = tree.z
		if distance <= tree_radius + 0.15 or distance > sight_radius + tree_radius:
			continue
		var center_index: int = floori((offset.angle() + PI) / TAU * ANGLE_SAMPLES)
		var half_count: int = ceili(asin(tree_radius / distance) / TAU * ANGLE_SAMPLES) + 1
		for index: int in range(center_index - half_count, center_index + half_count + 1):
			var direction := Vector2.from_angle(-PI + (float(index) + 0.5) * TAU / ANGLE_SAMPLES)
			var projection: float = offset.dot(direction)
			var perpendicular_squared: float = offset.length_squared() - projection * projection
			if projection <= 0.0 or perpendicular_squared >= tree_radius * tree_radius:
				continue
			# 树干本身仍可见；视线从树干后方开始被截断。
			var hit_distance: float = projection + tree_radius * 0.25
			var wrapped_index: int = posmod(index, ANGLE_SAMPLES)
			limits[wrapped_index] = minf(limits[wrapped_index], hit_distance)
	return limits

func _smooth_sight_limits(limits: PackedFloat32Array) -> PackedFloat32Array:
	# 原三角权重 13-|offset| 等价于两次长度 13 的环形滑动求和。
	var sums := PackedFloat64Array()
	sums.resize(ANGLE_SAMPLES)
	for index: int in range(ANGLE_SAMPLES): sums[index] = limits[index]
	for pass_index: int in range(2):
		var next := PackedFloat64Array()
		next.resize(ANGLE_SAMPLES)
		var total: float = 0.0
		for offset: int in range(-6, 7): total += sums[posmod(offset, ANGLE_SAMPLES)]
		for index: int in range(ANGLE_SAMPLES):
			next[index] = total
			total += sums[posmod(index + 7, ANGLE_SAMPLES)] - sums[posmod(index - 6, ANGLE_SAMPLES)]
		sums = next
	var smoothed := PackedFloat32Array()
	smoothed.resize(ANGLE_SAMPLES)
	for index: int in range(ANGLE_SAMPLES): smoothed[index] = sums[index] / 169.0
	return smoothed

func _reveal_visible_tree_canopies() -> void:
	for node: Node in get_tree().get_nodes_in_group("resources"):
		if node.get_script() != TREE_SCRIPT or node.is_queued_for_deletion() or not is_visible_at(node.global_position):
			continue
		var visual: Node3D = node.get_node_or_null("meshs") as Node3D
		if visual == null:
			continue
		var canopy_radius: float = 1.8 * visual.global_basis.get_scale().x
		var fade_radius: float = canopy_radius + 0.7
		var center: Vector2i = _pixel(node.global_position)
		var radius := Vector2i(Vector2.ONE * fade_radius / extent * RESOLUTION) + Vector2i.ONE
		var origin := Vector2(node.global_position.x, node.global_position.z)
		var crown_height: float = clampf((node.global_position.y + 0.65 * visual.global_basis.get_scale().y) / 32.0, 0.0, 1.0)
		for y: int in range(maxi(0, center.y - radius.y), mini(RESOLUTION, center.y + radius.y + 1)):
			for x: int in range(maxi(0, center.x - radius.x), mini(RESOLUTION, center.x + radius.x + 1)):
				var world: Vector2 = ((Vector2(x, y) + Vector2.ONE * 0.5) / RESOLUTION - Vector2.ONE * 0.5) * extent
				var strength: float = 1.0 - smoothstep(canopy_radius, fade_radius, world.distance_to(origin))
				if strength <= 0.0:
					continue
				var old_pixel: Color = visual_map.get_pixel(x, y)
				visual_map.set_pixel(x, y, Color(old_pixel.r, minf(old_pixel.g, crown_height), maxf(old_pixel.b, strength), 1.0))
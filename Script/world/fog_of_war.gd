extends Node3D

const SIGHT_RADIUS: float = 12.0
const RESOLUTION: int = 256
const ANGLE_SAMPLES: int = 720
const TREE_SCRIPT: Script = preload("res://Script/resource/game/tree.gd")
var extent: Vector2
var explored: Image
var visibility_map: Image
var visual_map: Image
var fully_visible_pixels: PackedByteArray = []
var merging_visibility: bool = false
var mask_texture: ImageTexture
var overlay: MeshInstance3D
var timer: float = 0.0
var initialized: bool = false
var refresh_queued: bool = false
var visibility_multiplier: float = 1.0
var last_visibility_inputs: Array = []
var static_visibility_inputs: Array = []
var static_visible_pixels: PackedInt32Array = []
var static_fully_visible_pixels: PackedByteArray = []
var static_visual_map: Image


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 110
	add_to_group("fog_of_war")
	var day_night: Node = get_node_or_null("../Systems/StylizedDayNight")
	if day_night != null:
		visibility_multiplier = float(day_night.get("current_visibility_multiplier"))
		if day_night.has_signal("night_visibility_changed"):
			day_night.connect("night_visibility_changed", _on_night_visibility_changed)
	var runtime: MapGenerateRuntime = get_tree().get_first_node_in_group("map_generate_runtime") as MapGenerateRuntime
	if runtime == null or runtime.map_data == null:
		return
	extent = Vector2(runtime.map_data.map_size) * runtime.map_data.cell_size_m
	explored = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_L8)
	visibility_map = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_L8)
	visual_map = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	mask_texture = ImageTexture.create_from_image(visual_map)
	overlay = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	overlay.mesh = quad
	overlay.extra_cull_margin = 16384
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://Script/world/fog_of_war.gdshader")
	material.render_priority = 127
	material.set_shader_parameter("fog_mask", mask_texture)
	material.set_shader_parameter("map_extent", extent)
	overlay.material_override = material
	add_child(overlay)
	initialized = true
	refresh_visibility()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(_node: Node) -> void:
	if not refresh_queued:
		refresh_queued = true
		call_deferred("refresh_visibility")


func _process(delta: float) -> void:
	if not initialized:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		overlay.global_position = camera.global_position - camera.global_basis.z
	timer += delta / maxf(Engine.time_scale, 0.001)
	if timer >= 0.1:
		timer = 0.0
		refresh_visibility()


func _pixel(point: Vector3) -> Vector2i:
	return Vector2i((Vector2(point.x, point.z) / extent + Vector2.ONE * 0.5) * RESOLUTION)


func _on_night_visibility_changed(multiplier: float) -> void:
	visibility_multiplier = multiplier


func is_visible_at(point: Vector3) -> bool:
	if not initialized:
		return false
	var pixel: Vector2i = _pixel(point)
	return Rect2i(0, 0, RESOLUTION, RESOLUTION).has_point(pixel) and visibility_map.get_pixelv(pixel).r > 0.9


func _belongs_to_camp_guard(node: Node, camp: Node) -> bool:
	var ancestor: Node = node.get_parent()
	while ancestor != null and ancestor != camp:
		if ancestor is EnemyBase:
			return true
		ancestor = ancestor.get_parent()
	return false


func is_area_visible(center: Vector3, radius: float) -> bool:
	if not initialized:
		return false
	var pixel: Vector2i = _pixel(center)
	var reach := Vector2i(ceili(radius / extent.x * RESOLUTION), ceili(radius / extent.y * RESOLUTION))
	for y: int in range(maxi(0, pixel.y - reach.y), mini(RESOLUTION, pixel.y + reach.y + 1)):
		for x: int in range(maxi(0, pixel.x - reach.x), mini(RESOLUTION, pixel.x + reach.x + 1)):
			var world_point: Vector2 = (Vector2(x + 0.5, y + 0.5) / RESOLUTION - Vector2.ONE * 0.5) * extent
			if world_point.distance_to(Vector2(center.x, center.z)) <= radius and visibility_map.get_pixel(x, y).r > 0.9:
				return true
	return false


func refresh_visibility() -> void:
	refresh_queued = false
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var tree_occluders: Array[Vector3] = _collect_tree_occluders()
	var moving_sources: Array[Vector4] = []
	var fixed_sources: Array[Vector4] = []
	for unit: Node in get_tree().get_nodes_in_group("villagers"):
		if not unit is Node3D or not unit.is_visible_in_tree() or (unit.has_method("is_dead") and unit.is_dead()):
			continue
		if not unit.has_method("get_faction") or unit.get_faction() != EnemyData.Faction.SETTLEMENT:
			continue
		var point: Vector3 = unit.global_position
		moving_sources.append(Vector4(point.x, point.y, point.z, SIGHT_RADIUS))
	for building: Node in get_tree().get_nodes_in_group("buildings"):
		if not building is Node3D or building is ConstructionSite or building.is_queued_for_deletion() or not building.is_visible_in_tree():
			continue
		if building.has_method("get_health") and building.get_health() <= 0.0:
			continue
		var radius: float = building.get_sight_radius() if building.has_method("get_sight_radius") else SIGHT_RADIUS
		var point: Vector3 = building.global_position
		fixed_sources.append(Vector4(point.x, point.y, point.z, radius))
	for camp: Node in get_tree().get_nodes_in_group("treasure_camps"):
		if camp is TreasureCamp and camp.cleared and not camp.is_queued_for_deletion():
			var point: Vector3 = camp.global_position
			fixed_sources.append(Vector4(point.x, point.y, point.z, SIGHT_RADIUS))
	# 树冠高度和缩放影响画面修补，即使遮挡轮廓未变化也需要更新。
	var tree_visuals: Array[Transform3D] = []
	for tree: Node in get_tree().get_nodes_in_group("resources"):
		if tree.get_script() != TREE_SCRIPT or tree.is_queued_for_deletion():
			continue
		var visual: Node3D = tree.get_node_or_null("meshs") as Node3D
		if visual != null:
			tree_visuals.append(visual.global_transform)
	var fixed_inputs: Array = [extent, visibility_multiplier, fixed_sources, tree_occluders]
	var inputs: Array = [fixed_inputs, moving_sources, tree_visuals]
	if inputs != last_visibility_inputs:
		if fixed_inputs != static_visibility_inputs:
			visibility_map.fill(Color.BLACK)
			visual_map.fill(Color(0.0, 1.0, 0.0, 0.0))
			fully_visible_pixels.resize(RESOLUTION * RESOLUTION)
			fully_visible_pixels.fill(0)
			merging_visibility = true
			for source: Vector4 in fixed_sources:
				_reveal_at(Vector3(source.x, source.y, source.z), source.w, tree_occluders)
			static_visual_map = visual_map.duplicate()
			static_fully_visible_pixels = fully_visible_pixels.duplicate()
			static_visible_pixels.clear()
			var fixed_pixels: PackedByteArray = visibility_map.get_data()
			for index: int in range(fixed_pixels.size()):
				if fixed_pixels[index] == 255:
					static_visible_pixels.append(index)
			static_visibility_inputs = fixed_inputs
		var pixels: PackedByteArray = explored.get_data()
		for index: int in static_visible_pixels:
			pixels[index] = 255
		visibility_map.set_data(RESOLUTION, RESOLUTION, false, Image.FORMAT_L8, pixels)
		visual_map.copy_from(static_visual_map)
		fully_visible_pixels = static_fully_visible_pixels.duplicate()
		merging_visibility = true
		for source: Vector4 in moving_sources:
			_reveal_at(Vector3(source.x, source.y, source.z), source.w, tree_occluders)
		merging_visibility = false
		_reveal_visible_tree_canopies()
		mask_texture.update(visual_map)
		last_visibility_inputs = inputs
	_refresh_object_visibility()


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
			# 树木和地形保留在黑色遮罩下；其余对象隐藏网格但保持根节点与 AI 运作。
			if not (group == "resources" and object.get_script() == TREE_SCRIPT):
				for mesh: Node in object.find_children("*", "GeometryInstance3D", true, false):
					if group == "treasure_camps" and _belongs_to_camp_guard(mesh, object):
						continue
					if mesh is AggroRange3D:
						mesh._refresh_visibility()
						continue
					if not mesh.has_meta("fog_visible"):
						mesh.set_meta("fog_visible", mesh.visible)
					mesh.visible = visible_now and bool(mesh.get_meta("fog_visible"))
			for collider: Node in object.find_children("*", "CollisionObject3D", true, false):
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


func _collect_tree_occluders() -> Array[Vector3]:
	var occluders: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group("resources"):
		if node.get_script() != TREE_SCRIPT or node.is_queued_for_deletion():
			continue
		var bounds: AABB = node.get_build_obstacle_bounds()
		if bounds.size == Vector3.ZERO:
			continue
		var tree_center := Vector2(bounds.get_center().x, bounds.get_center().z)
		var tree_radius: float = maxf(bounds.size.x, bounds.size.z) * 0.5
		occluders.append(Vector3(tree_center.x, tree_center.y, tree_radius))
	return occluders


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

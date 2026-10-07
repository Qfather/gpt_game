class_name BuildingGhost
extends Node3D

const CONSTRUCTION_SITE_SCENE: PackedScene = preload(
	"res://Scene/building/construction_site.tscn"
)

@export_category("蓝图")
@export var building_data: BuildingData = preload(
	"res://data/buildings/LumberCampData.tres"
)
@export var start_preview: bool = false

var rotation_step: int = 0
var mirrored: bool = false
var grid_position: Vector2i = Vector2i.ZERO
var is_valid_position: bool = false

var build_grid: BuildGrid
var preview_model: Node3D
var ghost_material: StandardMaterial3D
var base_preview_scale: Vector3 = Vector3.ONE
var preview_model_bounds: AABB = AABB()
var has_preview_model_bounds: bool = false
var entrance_arrow: MeshInstance3D
var entrance_local: Vector3
var path_warning: Label3D
var path_check_timer: float = 0.0
var has_reachable_approach: bool = true
var was_paused: bool = false
var placement_active_when_paused: bool = false
var placement_cancelled_during_pause: bool = false
var moving_building: BuildingBase
var moving_existing_building: bool = false
var relocation_cost_label: Label3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	build_grid = get_parent().get_node("BuildGrid") as BuildGrid
	visible = false
	_create_preview_mesh()
	_create_path_warning()
	relocation_cost_label = Label3D.new()
	relocation_cost_label.name = "RelocationCost"
	relocation_cost_label.font_size = 32
	relocation_cost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	relocation_cost_label.no_depth_test = true
	relocation_cost_label.hide()
	add_child(relocation_cost_label)
	if start_preview:
		_update_preview()


func select_building(data: BuildingData) -> void:
	if data == null:
		return
	moving_building = null
	moving_existing_building = false
	relocation_cost_label.hide()
	if get_tree().paused:
		placement_active_when_paused = true
		placement_cancelled_during_pause = false

	building_data = data
	rotation_step = 0
	mirrored = false
	start_preview = true
	if is_instance_valid(preview_model):
		preview_model.free()
	preview_model = null
	has_preview_model_bounds = false
	_create_preview_mesh()
	_update_preview()


func is_placement_active() -> bool:
	return start_preview


func select_moving_building(building: BuildingBase) -> void:
	if not is_instance_valid(building) or not building.can_be_moved():
		return
	select_building(building.building_data)
	moving_building = building
	moving_existing_building = true
	rotation_step = building.build_grid_rotation_step
	mirrored = building.scale.x < 0.0
	_update_preview()


func _moving_building_cells() -> Array[Vector2i]:
	if is_instance_valid(moving_building) and moving_building.build_grid_area_registered:
		return build_grid._get_area_cells(moving_building.build_grid_position, moving_building.build_grid_size, moving_building.build_grid_rotation_step)
	return []


func _process(delta: float) -> void:
	var paused: bool = get_tree().paused
	if paused and not was_paused:
		was_paused = true
		placement_active_when_paused = start_preview
		placement_cancelled_during_pause = false
	elif not paused and was_paused:
		was_paused = false
		if placement_cancelled_during_pause or not placement_active_when_paused:
			start_preview = false
			visible = false
		placement_cancelled_during_pause = false

	if not start_preview:
		return
	if moving_existing_building and (not is_instance_valid(moving_building) or not moving_building.can_be_moved()):
		cancel_preview()
		return

	_update_preview(delta)


func _unhandled_input(event: InputEvent) -> void:

	if not start_preview:
		return

	if event is InputEventKey and event.pressed and not event.echo:

		var key_event := event as InputEventKey

		if key_event.keycode == KEY_R:
			_rotate_preview(1)
			get_viewport().set_input_as_handled()
			return

		if key_event.keycode == KEY_M:
			_toggle_mirror()
			get_viewport().set_input_as_handled()
			return

		if key_event.keycode == KEY_ESCAPE:
			cancel_preview()
			get_viewport().set_input_as_handled()
			return

	if (
		event is InputEventMouseButton
		and event.pressed
	):

		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_preview()
			get_viewport().set_input_as_handled()
			return

		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_preview()
			get_viewport().set_input_as_handled()


func _create_preview_mesh() -> void:

	preview_model = Node3D.new()
	preview_model.name = "PreviewModel"
	add_child(preview_model)

	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.albedo_color = Color(0.2, 1.0, 0.2, 0.45)

	if building_data == null or building_data.building_scene == null:
		return

	var visual_scene: PackedScene = building_data.model_scene if building_data.model_scene != null else building_data.building_scene
	var source_root: Node3D = (
		visual_scene.instantiate()
		as Node3D
	)
	preview_model.transform = source_root.transform
	base_preview_scale = source_root.scale
	_calculate_preview_model_bounds(source_root)
	_copy_visual_tree(source_root, preview_model)
	entrance_local = source_root.transform * BuildingBase.get_local_entrance(source_root)
	if is_instance_valid(entrance_arrow): entrance_arrow.free()
	entrance_arrow = BuildingBase.create_entrance_arrow(entrance_local)
	entrance_arrow.visible = building_data.id != &"torch"
	add_child(entrance_arrow)
	source_root.free()


func _create_path_warning() -> void:
	path_warning = Label3D.new()
	path_warning.name = "PathWarning"
	path_warning.text = "!"
	path_warning.font_size = 96
	path_warning.modulate = Color(1.0, 0.78, 0.05, 1.0)
	path_warning.outline_size = 12
	path_warning.outline_modulate = Color(0.12, 0.08, 0.0, 1.0)
	path_warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	path_warning.no_depth_test = true
	path_warning.position = Vector3(0.0, 3.0, 0.0)
	path_warning.visible = false
	add_child(path_warning)


func _calculate_preview_model_bounds(model: Node3D) -> void:
	_collect_preview_bounds(model, model.transform)


func _collect_preview_bounds(node: Node3D, transform_from_root: Transform3D) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_bounds: AABB = _transform_aabb(
				mesh_instance.get_aabb(),
				transform_from_root
			)
			if not has_preview_model_bounds:
				preview_model_bounds = mesh_bounds
				has_preview_model_bounds = true
			else:
				preview_model_bounds = preview_model_bounds.merge(mesh_bounds)

	for child: Node in node.get_children():
		if child is Node3D:
			var child_3d: Node3D = child as Node3D
			_collect_preview_bounds(
				child_3d,
				transform_from_root * child_3d.transform
			)


func _transform_aabb(source: AABB, transform: Transform3D) -> AABB:
	var result: AABB = AABB(transform * source.position, Vector3.ZERO)
	for corner_index: int in range(1, 8):
		var corner: Vector3 = source.position
		if (corner_index & 1) != 0:
			corner.x += source.size.x
		if (corner_index & 2) != 0:
			corner.y += source.size.y
		if (corner_index & 4) != 0:
			corner.z += source.size.z
		result = result.expand(transform * corner)
	return result


func _copy_visual_tree(
	source_node: Node,
	target_parent: Node3D
) -> void:

	for child: Node in source_node.get_children():

		if child is MeshInstance3D:

			var source_mesh := child as MeshInstance3D
			var preview_mesh := MeshInstance3D.new()

			preview_mesh.name = source_mesh.name
			preview_mesh.transform = source_mesh.transform
			preview_mesh.mesh = source_mesh.mesh
			preview_mesh.material_override = ghost_material
			target_parent.add_child(preview_mesh)

		elif child is Node3D:

			var source_node_3d := child as Node3D
			var preview_node := Node3D.new()

			preview_node.name = source_node_3d.name
			preview_node.transform = source_node_3d.transform
			target_parent.add_child(preview_node)
			_copy_visual_tree(source_node_3d, preview_node)


func _update_preview(delta: float = 0.0) -> void:

	if building_data == null or build_grid == null:
		visible = false
		path_warning.visible = false
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		visible = false
		path_warning.visible = false
		return

	var world_position: Vector3 = _get_mouse_world_position(camera)
	if world_position == Vector3.INF:
		visible = false
		path_warning.visible = false
		return

	grid_position = build_grid.world_to_grid(world_position)
	is_valid_position = build_grid.is_area_free(
		grid_position,
		building_data.grid_size,
		rotation_step,
		building_data.id == &"wall",
		true,
		_moving_building_cells()
	)

	var rotated_size := build_grid.get_rotated_size(
		building_data.grid_size,
		rotation_step
	)
	rotation.y = float(rotation_step) * PI * 0.5
	var first_cell_center := build_grid.grid_to_world(grid_position)

	global_position = first_cell_center + Vector3(
		float(rotated_size.x - 1) * build_grid.cell_size * 0.5,
		0.0,
		float(rotated_size.y - 1) * build_grid.cell_size * 0.5
	)
	if moving_existing_building and is_instance_valid(moving_building):
		var can_pay: bool = moving_building.can_pay_relocation_cost(global_position)
		is_valid_position = is_valid_position and can_pay
		var parts: PackedStringArray = []
		var database: ResourceDatabase = preload("res://data/resources/resource_database.tres")
		var cost := moving_building.get_relocation_cost(global_position)
		for resource_id: StringName in cost:
			var resource_data: ResourceData = database.get_resource_data(resource_id)
			parts.append("%s %.0f" % [resource_data.display_name if resource_data != null else str(resource_id), cost[resource_id]])
		relocation_cost_label.text = "搬迁费用：%s%s" % ["、".join(parts) if not parts.is_empty() else "无", "（据点库存不足）" if not can_pay else ""]
		relocation_cost_label.position = Vector3(0, preview_model_bounds.end.y + 1.5, 0)
		relocation_cost_label.show()
	path_check_timer += delta
	if delta <= 0.0 or path_check_timer >= 0.35:
		path_check_timer = 0.0
		has_reachable_approach = _has_reachable_approach_point()

	preview_model.scale = Vector3(
		base_preview_scale.x * (-1.0 if mirrored else 1.0),
		base_preview_scale.y,
		base_preview_scale.z
	)

	ghost_material.albedo_color = (
		Color(0.2, 1.0, 0.2, 0.45)
		if is_valid_position
		else Color(1.0, 0.15, 0.15, 0.45)
	)
	path_warning.visible = is_valid_position and not has_reachable_approach
	# 模型镜像时入口也同步，旋转由蓝图根节点继承。
	entrance_arrow.position.x = entrance_local.x * (-1.0 if mirrored else 1.0)
	if has_preview_model_bounds:
		path_warning.position = Vector3(
			preview_model_bounds.get_center().x * (-1.0 if mirrored else 1.0),
			preview_model_bounds.end.y + 0.8,
			preview_model_bounds.get_center().z
		)

	visible = true


func _has_reachable_approach_point() -> bool:
	if not has_preview_model_bounds:
		return true
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return true
	var navigation_region: NavigationRegion3D = current_scene.get_node_or_null(
		"Systems/NavigationRegion3D"
	) as NavigationRegion3D
	if navigation_region == null:
		return true
	var navigation_map: RID = navigation_region.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(navigation_map) == 0:
		return true

	var start_points: Array[Vector3] = []
	for villager: Node in get_tree().get_nodes_in_group("villagers"):
		if villager is Node3D and is_instance_valid(villager):
			start_points.append((villager as Node3D).global_position)
	if start_points.is_empty():
		var base: Node3D = get_tree().get_first_node_in_group("bases") as Node3D
		if base != null:
			start_points.append(base.global_position)
	if start_points.is_empty():
		return true

	var local_point: Vector3 = entrance_local
	if mirrored: local_point.x = -local_point.x
	var approach_point: Vector3 = global_transform * local_point
	var navigation_point: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, approach_point)
	if _horizontal_distance(navigation_point, approach_point) > 0.75 or absf(navigation_point.y - approach_point.y) > 1.0:
		return false
	for start_position: Vector3 in start_points:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(navigation_map, start_position, navigation_point, true)
		if not path.is_empty() and path[-1].distance_to(navigation_point) <= 0.5:
			return true
	return false

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _get_mouse_world_position(camera: Camera3D, screen_position: Vector2 = Vector2.INF) -> Vector3:

	var mouse_position: Vector2 = get_viewport().get_mouse_position() if screen_position == Vector2.INF else screen_position
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)

	if absf(ray_direction.y) < 0.001:
		return Vector3.INF

	var base_height: float = build_grid.get_ground_height(Vector2i.ZERO) if build_grid != null else 0.0
	var distance: float = (base_height - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return Vector3.INF
	var point: Vector3 = ray_origin + ray_direction * distance
	if build_grid != null:
		var ground_height: float = build_grid.get_ground_height(build_grid.world_to_grid(point))
		if ground_height > 0.0:
			distance = (ground_height - ray_origin.y) / ray_direction.y
			if distance >= 0.0:
				point = ray_origin + ray_direction * distance
	return point


func _rotate_preview(direction: int) -> void:

	if building_data.allow_rotation:
		rotation_step = posmod(rotation_step + direction, 4)
		_update_preview()
		print("BuildingGhost rotation_step: ", rotation_step)


func _toggle_mirror() -> void:

	if building_data.allow_mirror:
		mirrored = not mirrored
		_update_preview()
		print("BuildingGhost mirrored: ", mirrored)


func _confirm_preview() -> void:

	if not is_valid_position:
		print("BuildingGhost 放置非法：", grid_position)
		return
	if moving_existing_building:
		if is_instance_valid(moving_building) and moving_building.relocate(build_grid, grid_position, rotation_step, mirrored, global_transform):
			cancel_preview()
		return
	var placed_data: BuildingData = building_data
	var placed_grid_position: Vector2i = grid_position
	var placed_rotation_step: int = rotation_step
	var placed_mirrored: bool = mirrored
	var placed_transform: Transform3D = global_transform

	var keep_placing: bool = Input.is_key_pressed(KEY_SHIFT)
	var created: bool = false
	if get_tree().paused:
		created = _create_construction_site(
			placed_data,
			placed_grid_position,
			placed_rotation_step,
			placed_mirrored,
			placed_transform,
			false,
			true
		)
		if not created:
			return
		print("BuildingGhost 暂停期间记录放置：", placed_data.id)
		if not keep_placing:
			start_preview = false
			visible = false
		return

	created = _create_construction_site(
		placed_data,
		placed_grid_position,
		placed_rotation_step,
		placed_mirrored,
		placed_transform,
		false,
		false
	)
	if not created:
		return
	if keep_placing:
		start_preview = true
		_update_preview()
	else:
		start_preview = false
		visible = false


func _create_construction_site(
	placed_data: BuildingData,
	placed_grid_position: Vector2i,
	placed_rotation_step: int,
	placed_mirrored: bool,
	placed_transform: Transform3D,
	area_already_occupied: bool,
	defer_activation_until_unpause: bool
) -> bool:
	if placed_data == null:
		return false
	if (
		not area_already_occupied
		and not build_grid.occupy_area(
			placed_grid_position,
			placed_data.grid_size,
			placed_rotation_step,
			placed_data.id == &"wall",
			true
		)
	):
		print("BuildingGhost 放置时网格已被占用：", placed_grid_position)
		return false

	var site: ConstructionSite = (
		CONSTRUCTION_SITE_SCENE.instantiate()
		as ConstructionSite
	)
	var cleared_resources: Array[ResourceBase] = []
	if placed_data.id == &"wall":
		cleared_resources = _get_wall_clearance_resources(placed_data, placed_transform)
	var site_data: BuildingData = placed_data
	if not cleared_resources.is_empty():
		# 仅复制本墙段的数据，避免修改共享预设或按资源个数重复累加。
		site_data = placed_data.duplicate() as BuildingData
		site_data.construction_time = placed_data.construction_time * 1.5
	site.setup(
		site_data,
		placed_grid_position,
		placed_rotation_step,
		placed_mirrored
	)
	site.set_activation_deferred_until_unpause(
		defer_activation_until_unpause
	)
	get_parent().add_child(site)
	site.global_transform = placed_transform
	site.rotation.y = float(placed_rotation_step) * PI * 0.5
	site.scale.x = -1.0 if placed_mirrored else 1.0
	for resource: ResourceBase in cleared_resources:
		resource.clear_for_construction()
	if not cleared_resources.is_empty():
		print("城墙清障：移除资源=", cleared_resources.size(), "，施工时间增加50%：", site_data.construction_time)

	print(
		"BuildingGhost 确认：",
		placed_data.id,
		" grid=",
		placed_grid_position,
		" rotation_step=",
		placed_rotation_step,
		" mirrored=",
		placed_mirrored
	)
	return true


func _get_wall_clearance_resources(data: BuildingData, wall_transform: Transform3D) -> Array[ResourceBase]:
	var result: Array[ResourceBase] = []
	var wall: Node3D = data.building_scene.instantiate() as Node3D
	var collision: CollisionShape3D = wall.get_node("StaticBody3D/CollisionShape3D") as CollisionShape3D
	var transform: Transform3D = wall_transform * wall.transform * (collision.get_parent() as Node3D).transform * collision.transform
	var bounds: AABB = collision.shape.get_debug_mesh().get_aabb()
	# 只在水平面外扩，给施工站位及居民身体留出空间。
	bounds.position -= Vector3(0.5, 0.0, 0.5)
	bounds.size += Vector3(1.0, 0.0, 1.0)
	for node: Node in get_tree().get_nodes_in_group("resources"):
		var resource: ResourceBase = node as ResourceBase
		if resource != null and not resource.is_queued_for_deletion() and resource.overlaps_clearance_box(bounds, transform):
			result.append(resource)
	wall.free()
	return result


func cancel_preview() -> void:

	print("BuildingGhost 取消")
	if get_tree().paused:
		placement_cancelled_during_pause = true
	start_preview = false
	visible = false
	moving_building = null
	moving_existing_building = false
	relocation_cost_label.hide()

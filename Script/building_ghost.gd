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


func _ready() -> void:

	build_grid = get_parent().get_node("BuildGrid") as BuildGrid
	visible = false
	_create_preview_mesh()
	if start_preview:
		_update_preview()


func select_building(data: BuildingData) -> void:
	if data == null:
		return

	building_data = data
	rotation_step = 0
	mirrored = false
	start_preview = true
	if is_instance_valid(preview_model):
		preview_model.free()
	preview_model = null
	_create_preview_mesh()
	_update_preview()


func is_placement_active() -> bool:
	return start_preview


func _process(_delta: float) -> void:

	if not start_preview:
		return

	_update_preview()


func _unhandled_input(event: InputEvent) -> void:

	if not start_preview:
		return

	if event is InputEventKey and event.pressed and not event.echo:

		var key_event := event as InputEventKey

		if key_event.keycode == KEY_R:
			_rotate_preview()
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

	var source_root: Node3D = (
		building_data.building_scene.instantiate()
		as Node3D
	)
	preview_model.transform = source_root.transform
	base_preview_scale = source_root.scale
	_copy_visual_tree(source_root, preview_model)
	source_root.free()


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


func _update_preview() -> void:

	if building_data == null or build_grid == null:
		visible = false
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		visible = false
		return

	var world_position: Vector3 = _get_mouse_world_position(camera)
	if world_position == Vector3.INF:
		visible = false
		return

	grid_position = build_grid.world_to_grid(world_position)
	is_valid_position = build_grid.is_area_free(
		grid_position,
		building_data.grid_size,
		rotation_step
	)

	var rotated_size := build_grid.get_rotated_size(
		building_data.grid_size,
		rotation_step
	)
	var first_cell_center := build_grid.grid_to_world(grid_position)

	global_position = first_cell_center + Vector3(
		float(rotated_size.x - 1) * build_grid.cell_size * 0.5,
		0.0,
		float(rotated_size.y - 1) * build_grid.cell_size * 0.5
	)

	rotation.y = float(rotation_step) * PI * 0.5
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

	visible = true


func _get_mouse_world_position(camera: Camera3D) -> Vector3:

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)

	if absf(ray_direction.y) < 0.001:
		return Vector3.INF

	var distance: float = -ray_origin.y / ray_direction.y
	if distance < 0.0:
		return Vector3.INF

	return ray_origin + ray_direction * distance


func _rotate_preview() -> void:

	if building_data.allow_rotation:
		rotation_step = posmod(rotation_step + 1, 4)
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
	var placed_data: BuildingData = building_data
	var placed_grid_position: Vector2i = grid_position
	var placed_rotation_step: int = rotation_step
	var placed_mirrored: bool = mirrored
	var placed_transform: Transform3D = global_transform

	if get_tree().paused:
		_create_construction_site(
			placed_data,
			placed_grid_position,
			placed_rotation_step,
			placed_mirrored,
			placed_transform,
			false,
			true
		)
		print("BuildingGhost 暂停期间记录放置：", placed_data.id)
		start_preview = false
		visible = false
		return

	_create_construction_site(
		placed_data,
		placed_grid_position,
		placed_rotation_step,
		placed_mirrored,
		placed_transform,
		false,
		false
	)
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
) -> void:
	if placed_data == null:
		return
	if (
		not area_already_occupied
		and not build_grid.occupy_area(
			placed_grid_position,
			placed_data.grid_size,
			placed_rotation_step
		)
	):
		print("BuildingGhost 放置时网格已被占用：", placed_grid_position)
		return

	var site: ConstructionSite = (
		CONSTRUCTION_SITE_SCENE.instantiate()
		as ConstructionSite
	)
	site.setup(
		placed_data,
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


func cancel_preview() -> void:

	print("BuildingGhost 取消")
	start_preview = false
	visible = false

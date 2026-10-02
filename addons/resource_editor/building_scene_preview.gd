@tool
extends AspectRatioContainer

var viewport: SubViewport
var model: Node3D
var camera: Camera3D
var bounds: AABB
var mesh_count: int = 0
var tint: Color = Color.WHITE

func _init() -> void:
	ratio = 1.0
	custom_minimum_size = Vector2(220, 220)
	var container := SubViewportContainer.new()
	container.stretch = true
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	model = Node3D.new()
	viewport.add_child(model)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.14, 0.18)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	viewport.add_child(light)

func show_scene(scene: PackedScene, color: Color = Color.WHITE) -> void:
	tint = color
	for child: Node in model.get_children():
		model.remove_child(child)
		child.queue_free()
	mesh_count = 0
	bounds = AABB()
	if scene == null: return
	# 外部更新模型后，已打开的编辑器可能仍持有旧 PackedScene。
	if not scene.resource_path.is_empty():
		scene = ResourceLoader.load(scene.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	# 只复制网格，不把建筑脚本放进预览场景树。
	var source: Node = scene.instantiate()
	_copy_meshes(source, Transform3D.IDENTITY)
	source.free()
	if mesh_count == 0: return
	var radius: float = maxf(bounds.size.length() * 0.5, 0.5)
	var center: Vector3 = bounds.get_center()
	camera.position = center + Vector3(1.0, 0.8, 1.3).normalized() * radius * 3.0
	camera.look_at_from_position(camera.position, center)
	camera.size = radius * 2.3
	camera.near = 0.01
	camera.far = radius * 10.0 + 10.0

func _copy_meshes(node: Node, parent_transform: Transform3D) -> void:
	if node.name in [&"HealthBar3D", &"HealthBar2D"]: return
	var transform: Transform3D = parent_transform
	if node is Node3D:
		if not node.visible: return
		transform *= node.transform
	if node is MeshInstance3D and node.mesh != null:
		var copy := MeshInstance3D.new()
		copy.mesh = node.mesh
		copy.material_override = node.material_override
		for index: int in range(node.mesh.get_surface_count()):
			copy.set_surface_override_material(index, node.get_surface_override_material(index))
		if tint != Color.WHITE:
			copy.material_override = null
			for index: int in range(node.mesh.get_surface_count()):
				var material: Material = node.get_active_material(index)
				if material == null: continue
				var tinted: Material = material.duplicate()
				if tinted is StandardMaterial3D: tinted.albedo_color *= tint
				copy.set_surface_override_material(index, tinted)
		copy.transform = transform
		model.add_child(copy)
		var box: AABB = transform * node.mesh.get_aabb()
		bounds = box if mesh_count == 0 else bounds.merge(box)
		mesh_count += 1
	for child: Node in node.get_children():
		_copy_meshes(child, transform)

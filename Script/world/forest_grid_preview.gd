extends Node3D

# 独立占格实验，不接入正式关卡资源与导航逻辑。
@export var 关卡配置: LevelFlowData = preload("res://data/levels/LevelFlow_40min_Hard.tres")
@export var 随机种子: int = 42
@export_range(0.0, 0.35, 0.01) var 格内偏移比例: float = 0.22

var selected_object: Node3D
var _forest := Node3D.new()
var _grid := MeshInstance3D.new()
var _label: Label
var _entry: MapResourceEntry
var _rng := RandomNumberGenerator.new()
var _cell_size: float
var _map_size: Vector2i
var _occupied: Dictionary = {}


func _ready() -> void:
	_cell_size = 关卡配置.map_config.cell_size_m
	_map_size = 关卡配置.map_config.map_size
	for entry: MapResourceEntry in 关卡配置.map_resources:
		if entry.enabled and entry.distribution == 0:
			_entry = entry
			break
	_forest.name = "Forest"
	add_child(_forest)
	_create_ground()
	_create_grid()
	_create_ui()
	_generate()
	var camera: Camera3D = $Camera3D
	camera.focus_on_position(Vector3.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_grid.visible = not _grid.visible
		elif event.keycode == KEY_R:
			随机种子 += 1
			_generate()


func _center(cell: Vector2i) -> Vector3:
	return Vector3((float(cell.x) + 0.5 - _map_size.x * 0.5) * _cell_size, 0.0, (float(cell.y) + 0.5 - _map_size.y * 0.5) * _cell_size)


func _generate() -> void:
	for child: Node in _forest.get_children():
		_forest.remove_child(child)
		child.queue_free()
	_occupied.clear()
	_rng.seed = 随机种子
	var noise := FastNoiseLite.new()
	noise.seed = 随机种子
	noise.frequency = 0.09
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	var near_centers: Array[Vector3] = []
	var angle: float = _rng.randf_range(0.0, TAU)
	for index: int in range(3):
		var direction: float = angle + index * TAU / 3.0 + _rng.randf_range(-0.2, 0.2)
		near_centers.append(Vector3(cos(direction), 0, sin(direction)) * _rng.randf_range(_entry.near_distance_min, _entry.near_distance_max))
	var far_centers: Array[Vector3] = []
	for index: int in range(4):
		var direction: float = angle + index * TAU / 4.0
		far_centers.append(Vector3(cos(direction), 0, sin(direction)) * _rng.randf_range(_entry.far_distance_min, _cell_size * mini(_map_size.x, _map_size.y) * 0.4))
	var template: ResourceBase = _entry.scene.instantiate()
	var candidates: Array[Node] = template.get_node("meshs").get_children()
	var near_count: int = ceili(_entry.count * _entry.nearby_ratio)
	_plant(near_centers, noise, near_count, true, candidates, template)
	_plant(far_centers, noise, _entry.count - _occupied.size(), false, candidates, template)
	template.free()
	_label.text = "森林占格预览  |  %d 棵树  |  1格 = %.1f米  |  种子 %d\nWASD 移动 · Q/E 转向 · 中键拖动旋转 · Shift+中键平移 · 滚轮缩放\nG 显示/隐藏格线 · R 换种子生成\n每格最多一棵树，整格阻挡；模型在格内随机偏移、旋转和缩放。" % [_occupied.size(), _cell_size, 随机种子]
	print("森林占格预览：", _occupied.size(), "棵树，", _map_size, "，单格", _cell_size)


func _plant(centers: Array[Vector3], noise: FastNoiseLite, count: int, nearby: bool, candidates: Array[Node], template: ResourceBase) -> void:
	var cells: Array[Dictionary] = []
	var clear_radius: float = 关卡配置.map_config.center_clear_size * _cell_size * 0.5
	for x: int in range(_map_size.x):
		for z: int in range(_map_size.y):
			var cell := Vector2i(x, z)
			var position: Vector3 = _center(cell)
			var distance: float = position.length()
			if _occupied.has(cell) or distance < clear_radius:
				continue
			if nearby and distance > _entry.near_distance_max + _entry.cluster_radius:
				continue
			if not nearby and distance < _entry.far_distance_min:
				continue
			var density: float = 0.0
			for center: Vector3 in centers:
				density = maxf(density, pow(maxf(0.0, 1.0 - position.distance_to(center) / _entry.cluster_radius), 1.5))
			var variation: float = (noise.get_noise_2d(position.x, position.z) + 1.0) * 0.5
			var weight: float = _entry.base_weight * (_entry.scattered_weight + density * (0.6 + variation * 1.4))
			# 加权无放回抽取：林区密集、外围稀疏，每个资源格只用一次。
			cells.append({"cell": cell, "score": log(maxf(_rng.randf(), 0.000001)) / maxf(weight, 0.000001)})
	cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	for index: int in range(mini(count, cells.size())):
		var cell: Vector2i = cells[index].cell
		_occupied[cell] = true
		var tree := StaticBody3D.new()
		_forest.add_child(tree)
		tree.position = _center(cell)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE * _cell_size
		collision.shape = shape
		collision.position.y = _cell_size * 0.5
		tree.add_child(collision)
		var visual := Node3D.new()
		tree.add_child(visual)
		visual.position = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * _cell_size * 格内偏移比例
		visual.rotation.y = _rng.randf_range(0, TAU)
		visual.scale = Vector3.ONE * _rng.randf_range(template.visual_scale_min, template.visual_scale_max)
		visual.add_child(candidates[_rng.randi_range(0, candidates.size() - 1)].duplicate())


func _create_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_map_size) * _cell_size
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.49, 0.23)
	material.roughness = 1.0
	ground.material_override = material
	add_child(ground)


func _create_grid() -> void:
	var vertices := PackedVector3Array()
	var half: Vector2 = Vector2(_map_size) * _cell_size * 0.5
	for x: int in range(_map_size.x + 1):
		var line_x: float = x * _cell_size - half.x
		vertices.append(Vector3(line_x, 0.015, -half.y))
		vertices.append(Vector3(line_x, 0.015, half.y))
	for z: int in range(_map_size.y + 1):
		var line_z: float = z * _cell_size - half.y
		vertices.append(Vector3(-half.x, 0.015, line_z))
		vertices.append(Vector3(half.x, 0.015, line_z))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	_grid.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.21, 0.32, 0.15)
	_grid.material_override = material
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.visible = false
	add_child(_grid)


func _create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(14, 12)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_label)

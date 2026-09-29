extends SceneTree

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	scene.level_preset = scene.level_preset.duplicate(true)
	scene.level_preset.fog_of_war_enabled = true
	scene.level_preset.map_resources.clear()
	scene.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	root.add_child(scene)
	current_scene = scene
	for frame: int in range(10):
		await process_frame
	var fog: Node = scene.get_node("FogOfWar")
	var units: Array[Node] = get_nodes_in_group("villagers")
	var base: Node3D = get_first_node_in_group("bases") as Node3D
	var start: Vector3 = base.global_position
	for unit: Node3D in units:
		unit.set_physics_process(false)
		unit.global_position = start
	var far: Vector3 = start + Vector3(25, 0, 0)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate() as EnemyBase
	scene.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.global_position = far
	var migrant: Node3D = load("res://Scene/unit/migrant.tscn").instantiate() as Node3D
	scene.add_child(migrant)
	migrant.global_position = far
	var tree: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate() as ResourceBase
	tree.visual_scale_min = 1.0
	tree.visual_scale_max = 1.0
	scene.add_child(tree)
	tree.global_position = far + Vector3(2, 0, 0)
	var stone: ResourceBase = load("res://Scene/resource/stone.tscn").instantiate() as ResourceBase
	scene.add_child(stone)
	stone.global_position = far + Vector3(0, 0, 4)
	fog.refresh_visibility()
	_expect(fog.is_visible_at(start), "己方单位未提供视野")
	_expect(not fog.is_visible_at(far), "敌人或移民提供了视野")
	_expect(enemy.is_visible_in_tree() and enemy.get_meta("fog_hidden"), "隐藏干扰了AI节点可见性")
	_expect(not enemy.get_node("ClickArea").input_ray_pickable, "迷雾中敌人仍可点击")
	for mesh: Node in migrant.find_children("*", "GeometryInstance3D", true, false):
		_expect(mesh.layers == 0, "视野外移民未隐藏")
	for mesh: Node in tree.find_children("*", "GeometryInstance3D", true, false):
		_expect(mesh.layers != 0, "迷雾中树木被隐藏")
	for mesh: Node in stone.find_children("*", "GeometryInstance3D", true, false):
		_expect(mesh.layers == 0, "迷雾中石头仍显示")
	units[0].global_position = far
	fog.refresh_visibility()
	_expect(fog.is_visible_at(far) and not enemy.get_meta("fog_hidden"), "己方到达后没有显露敌人")
	_expect(enemy.get_node("ClickArea").input_ray_pickable, "显露后不能点击")
	for mesh: Node in stone.find_children("*", "GeometryInstance3D", true, false):
		_expect(mesh.layers != 0, "进入视野后石头未恢复显示")
	_expect(fog.is_visible_at(far + Vector3(1, 0, 0)), "树前方错误遮挡视野")
	_expect(fog.is_visible_at(tree.global_position), "可见树木的中心被自身挡住")
	_expect(not fog.is_visible_at(far + Vector3(8, 0, 0)), "树后方没有形成阴影")
	var angular_limits: PackedFloat32Array = fog._tree_sight_limits(Vector2(far.x, far.z))
	var smooth_limits: PackedFloat32Array = fog._smooth_sight_limits(angular_limits)
	var largest_step: float = 0.0
	for angle: int in range(fog.ANGLE_SAMPLES):
		largest_step = maxf(largest_step, absf(smooth_limits[angle] - smooth_limits[(angle + 1) % fog.ANGLE_SAMPLES]))
	_expect(largest_step < 1.0, "树后相邻视线角度出现明显台阶")
	var soft_shadow: float = fog.visual_map.get_pixelv(fog._pixel(far + Vector3(2.7, 0, 0))).r
	_expect(soft_shadow > 0.05 and soft_shadow < 0.95, "树后阴影未形成连续的视觉过渡")
	_expect(not fog.is_visible_at(tree.global_position + Vector3(1.2, 0, 0)), "树后方实际视野被树冠修补错误扩张")
	var crown_pixel: Color = fog.visual_map.get_pixelv(fog._pixel(tree.global_position + Vector3(1.2, 0, 0)))
	_expect(crown_pixel.b > 0.9 and crown_pixel.r < 0.1, "可见树冠与树后地面未分开处理")
	_expect(crown_pixel.g * 32.0 > tree.global_position.y, "树冠修补错误覆盖地面高度")
	_expect(fog.visual_map.get_pixelv(fog._pixel(far + Vector3(8, 0, 0))).r < 0.05, "树后方的迷雾画面没有变暗")
	_expect(fog.is_visible_at(far + Vector3(8, 0, 5)), "树侧方错误遮挡视野")
	units[1].global_position = far + Vector3(8, 0, 5)
	fog.refresh_visibility()
	_expect(fog.is_visible_at(far + Vector3(8, 0, 0)), "第二名居民未从侧面照亮树后区域")
	units[1].global_position = start
	fog.refresh_visibility()
	_expect(not fog.is_visible_at(far + Vector3(8, 0, 0)), "第二名居民离开后阴影未恢复")
	if "--preview" in OS.get_cmdline_user_args():
		var camera: GameCameraController = root.get_camera_3d() as GameCameraController
		camera.focus_on_position(far)
		for frame: int in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/fog_tree_edge_preview.png")
	tree.gather(tree.resource_amount)
	fog.refresh_visibility()
	_expect(fog.is_visible_at(far + Vector3(8, 0, 0)), "树被砍除后阴影未消失")
	units[0].global_position = start
	fog.refresh_visibility()
	_expect(not fog.is_visible_at(far) and enemy.get_meta("fog_hidden"), "离开后没有隐藏敌人")
	_expect(fog.explored.get_pixelv(fog._pixel(far)).r > 0.0, "探索记录丢失")
	for unit: Node3D in units:
		unit.global_position = far
	fog.refresh_visibility()
	_expect(fog.is_visible_at(start), "单位离开后据点未保留视野")
	var wall: Node3D = load("res://Scene/building/game/wall.tscn").instantiate() as Node3D
	scene.add_child(wall)
	wall.global_position = start + Vector3(-25, 0, 0)
	fog.refresh_visibility()
	_expect(fog.is_visible_at(wall.global_position), "已建成城墙未提供视野")
	var wall_position: Vector3 = wall.global_position
	wall.queue_free()
	fog.refresh_visibility()
	_expect(not fog.is_visible_at(wall_position), "已删除建筑仍提供视野")
	var site: ConstructionSite = load("res://Scene/building/construction_site.tscn").instantiate() as ConstructionSite
	site.setup(load("res://data/buildings/WallData.tres"), Vector2i(100, 100), 0, false)
	scene.add_child(site)
	site.global_position = wall_position
	fog.refresh_visibility()
	_expect(not fog.is_visible_at(wall_position), "未完工工地错误提供视野")
	for mesh: Node in site.find_children("*", "GeometryInstance3D", true, false):
		_expect(mesh.layers == 0, "迷雾中工地仍显示")
	site.queue_free()
	for unit: Node3D in units:
		unit.global_position = start
	fog.refresh_visibility()
	var edge: Vector2i = fog._pixel(start + Vector3(11, 0, 0))
	_expect(fog.visual_map.get_pixelv(edge).r > 0.1 and fog.visual_map.get_pixelv(edge).r < 0.9, "视野边缘没有柔和过渡")
	if "--preview" in OS.get_cmdline_user_args():
		for frame: int in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/fog_preview.png")
	var preset: LevelFlowData = scene.level_preset.duplicate(true)
	preset.fog_of_war_enabled = false
	ResourceSaver.save(preset, "res://.godot/fog_preset_test.tres")
	var reloaded: LevelFlowData = ResourceLoader.load("res://.godot/fog_preset_test.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as LevelFlowData
	_expect(not reloaded.fog_of_war_enabled, "关卡开关保存失败")
	scene.queue_free()
	await process_frame
	var disabled: Node = load("res://Scene/main.tscn").instantiate()
	disabled.level_preset = reloaded
	root.add_child(disabled)
	current_scene = disabled
	await process_frame
	await process_frame
	_expect(not disabled.has_node("FogOfWar"), "关闭开关后仍生成迷雾")
	disabled.queue_free()
	await process_frame
	print("战争迷雾测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

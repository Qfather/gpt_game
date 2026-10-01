extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var legacy: bool = "--legacy" in OS.get_cmdline_user_args()
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 5, 12)
	camera.look_at(Vector3.ZERO)
	var fog: Node = load("res://Script/world/fog_of_war.gd").new()
	world.add_child(fog)
	fog.set_process(false)
	fog.extent = Vector2(256, 256)
	fog.explored = Image.create(256, 256, false, Image.FORMAT_L8)
	fog.visibility_map = Image.create(256, 256, false, Image.FORMAT_L8)
	fog.visual_map = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	fog.mask_texture = ImageTexture.create_from_image(fog.visual_map)
	fog.initialized = true
	for round_index: int in range(12):
		var light := OmniLight3D.new()
		light.omni_range = 15.0
		light.light_cull_mask = 1
		light.shadow_enabled = true
		world.add_child(light)
		light.position = Vector3(0, 2, 0)
		var target := Node3D.new()
		target.add_to_group("enemies")
		world.add_child(target)
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.layers = 1
		target.add_child(mesh)
		var hidden := MeshInstance3D.new()
		hidden.mesh = SphereMesh.new()
		hidden.visible = false
		target.add_child(hidden)
		var aggro := AggroRange3D.new()
		target.add_child(aggro)
		for index: int in range(6):
			var reveal: bool = index % 2 == 0
			if legacy:
				mesh.layers = 1 if reveal else 0
			else:
				fog.explored.fill(Color.WHITE if reveal else Color(0.35, 0.35, 0.35))
				fog.refresh_visibility()
				_expect(mesh.layers == 1, "迷雾不修改模型渲染层")
				_expect(mesh.visible == reveal, "迷雾正确隐藏与恢复模型")
				_expect(not hidden.visible, "原本隐藏的备用模型不会被显示")
				_expect(target.is_visible_in_tree(), "迷雾保留根节点与AI运行")
				_expect(aggro.visible == reveal, "仇恨范围随迷雾隐藏并在发现后恢复")
			await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
		# 在隐藏状态释放模型和附近灯光，覆盖实际死亡清理的渲染索引路径。
		target.queue_free()
		await process_frame
		light.queue_free()
		await process_frame
	print("迷雾灯光解绑测试", "失败" if failed else "通过", "，模式=", "旧渲染层切换" if legacy else "模型显隐", "，轮数=12")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("失败：" + message)

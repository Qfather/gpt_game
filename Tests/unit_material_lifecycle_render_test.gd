extends SceneTree
var failed: bool = false

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.events.clear()
	main.level_preset.map_resources.clear()
	main.level_preset.camp_config.enabled = false
	main.level_preset.fog_of_war_enabled = false
	root.add_child(main)
	current_scene = main
	for i in range(8): await process_frame
	paused = true
	var base = get_first_node_in_group("bases")
	var camera = root.get_camera_3d()
	camera.focus_on_position(base.global_position)
	for round_index in range(3):
		for folder in ["res://data/enemies/raid", "res://data/enemies/rift"]:
			for file in DirAccess.get_files_at(folder):
				if not file.ends_with("Data.tres"): continue
				print("MATERIAL_START ", round_index, " ", file)
				var enemy = load("res://Scene/unit/enemy_base.tscn").instantiate()
				enemy.enemy_data = load(folder.path_join(file))
				main.add_child(enemy)
				enemy.global_position = base.global_position + Vector3(3, 0.6, 0)
				var original: Node = enemy.enemy_data.visual_scene.instantiate()
				var original_meshes: Array[Node] = original.find_children("*", "MeshInstance3D", true, false)
				var colored_meshes: Array[Node] = enemy.visual_root.get_child(-1).find_children("*", "MeshInstance3D", true, false)
				_expect(original_meshes.size() == colored_meshes.size(), "染色改变模型结构")
				for index: int in range(original_meshes.size()):
					var source: Material = original_meshes[index].get_active_material(0)
					var colored: Material = colored_meshes[index].get_active_material(0)
					if source is StandardMaterial3D:
						_expect(colored is StandardMaterial3D and colored.albedo_color.is_equal_approx(source.albedo_color * enemy.enemy_data.visual_tint), "敌人染色不一致：" + folder + "/" + file)
						if enemy.enemy_data.visual_tint != Color.WHITE:
							_expect(colored_meshes[index].material_override == colored and colored_meshes[index].get_surface_override_material(0) == null, "染色仍使用表面覆盖：" + file)
							_expect(colored != source, "染色修改共享原材质：" + file)
				original.free()
				main._select_world_object(enemy)
				await process_frame
				await RenderingServer.frame_post_draw
				main._clear_selection_highlight()
				if round_index == 1:
					for mesh: Node in enemy.visual_root.find_children("*", "GeometryInstance3D", true, false): mesh.hide()
				if round_index == 0 and enemy.enemy_data.visual_tint != Color.WHITE:
					# 覆盖真实死亡计时清理，而非仅直接释放。
					enemy.take_damage(100000.0)
					await create_timer(0.5).timeout
					_expect(not is_instance_valid(enemy), "敌人死亡没有释放")
				else:
					enemy.queue_free()
				await process_frame
				await RenderingServer.frame_post_draw
				print("MATERIAL_END ", file)
		for role in [0, 1, 2]:
			print("MATERIAL_START resident role ", role)
			var villager = load("res://Scene/unit/villager.tscn").instantiate()
			main.add_child(villager)
			villager.global_position = base.global_position + Vector3(3, 0, 0)
			villager.set_combat_role(role)
			main._select_world_object(villager)
			await process_frame
			await RenderingServer.frame_post_draw
			villager.job = villager.Job.LUMBERJACK
			villager.job = villager.Job.MINER
			main._clear_selection_highlight()
			villager.queue_free()
			await process_frame
			await RenderingServer.frame_post_draw
			print("MATERIAL_END resident role ", role)
	paused = false
	main.queue_free()
	await process_frame
	print("单位材质释放渲染测试", "失败" if failed else "通过", "：全部敌人3轮创建、染色、选中、隐藏、释放；染色敌人真实死亡；居民转职、岗位换色与释放")
	quit(1 if failed else 0)

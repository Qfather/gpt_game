extends SceneTree

const VILLAGER_SCRIPT: Script = preload("res://Script/unit/game/villager.gd")
var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("失败：" + message)


func _run() -> void:
	var scene: Node = load("res://Scene/main.tscn").instantiate()
	scene.level_preset = scene.level_preset.duplicate(true)
	scene.level_preset.map_resources.clear()
	scene.get_node("Systems/MapGenerateRuntime").settlement_seed = 42
	root.add_child(scene)
	current_scene = scene
	for frame: int in range(10):
		await process_frame
	var villager: UnitBase = get_nodes_in_group("villagers")[0] as UnitBase
	villager.set_physics_process(false)
	var site := Node3D.new()
	scene.add_child(site)
	villager.task_site = site
	villager.state = VILLAGER_SCRIPT.State.MOVE_TO_TASK_SITE
	villager.navigation_agent.target_position = villager.global_position + Vector3(20, 0, 0)
	villager._update_unreachable_warning(0.1)
	_expect(not villager.has_unreachable_warning(), "首次寻路就误报无法到达")
	villager._update_unreachable_warning(5.1)
	_expect(villager.has_unreachable_warning() and villager.unreachable_marker.visible, "持续无法前进没有显示头顶提示")
	villager.global_position.x += 0.25
	villager._update_unreachable_warning(0.1)
	_expect(not villager.has_unreachable_warning(), "重新前进后告警没有清除")
	villager._update_unreachable_warning(5.1)
	var hud: GameHUD = scene.get_node("UI/HUD") as GameHUD
	hud._refresh_unreachable_icons()
	_expect(hud.unreachable_buttons.size() == 1, "左下角没有角色告警色块")
	var button: Button = hud.unreachable_buttons[villager.get_instance_id()]
	if "--preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/unreachable_villager_preview.png")
	button.pressed.emit()
	await process_frame
	_expect(scene.selected_object == villager, "点击告警色块没有选中居民")
	var camera: GameCameraController = root.get_camera_3d() as GameCameraController
	_expect(camera.focus_target.is_equal_approx(villager.global_position), "点击告警色块没有聚焦居民")
	var panel: VillagerPanel = scene.get_node("UI/VillagerPanel") as VillagerPanel
	_expect(panel.remove_button.text == "放弃现在工作", "角色面板仍显示移除居民")
	var population: PopulationManager = get_first_node_in_group("population_manager") as PopulationManager
	var count_before: int = population.get_population()
	var manager: TaskManager = get_first_node_in_group("task_manager") as TaskManager
	var task: GameTask = manager.create_task(GameTask.TaskType.PICKUP_LOOT, site, site)
	task.assigned_worker = villager
	task.state = GameTask.State.IN_PROGRESS
	villager.current_task = task
	villager.carried_resource_id = &"wood"
	villager.carried_amount = 5.0
	panel._on_remove_pressed()
	_expect(population.get_population() == count_before, "放弃工作错误删除居民")
	_expect(task.state == GameTask.State.CANCELLED, "放弃工作没有取消现有任务")
	_expect(villager.state == VILLAGER_SCRIPT.State.MOVE_TO_BASE, "携带材料时没有返回据点")
	_expect(villager.current_task == null and villager.task_site == null, "放弃工作后任务引用未清理")
	_expect(not villager.has_unreachable_warning(), "放弃工作后头顶告警未清除")
	_expect(not villager.can_work_at(site), "放弃工作后仍可立即重回原工地")
	hud._refresh_unreachable_icons()
	_expect(hud.unreachable_buttons.is_empty(), "放弃工作后左下角告警未消失")
	scene.queue_free()
	await process_frame
	print("居民不可达提醒测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

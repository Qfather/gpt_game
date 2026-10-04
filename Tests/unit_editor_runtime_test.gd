extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var data: UnitData = load("res://.godot/unit_editor_swordsman.tres")
	var main: Node3D = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for i: int in range(20):
		await physics_frame
		await process_frame
	var unit: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	unit.unit_data = data
	unit.combat_role = CombatRole.Type.SWORDSMAN
	var preference_entry := UnitTrait.new()
	preference_entry.trait_data = load("res://data/traits/likes_meat.tres")
	unit.traits.append(preference_entry)
	main.add_child(unit)
	unit.set_physics_process(false)
	unit.set_process(false)
	unit.global_position = get_first_node_in_group("bases").global_position + Vector3(3, 0, 3)
	assert(unit.get_display_name() == "配置剑士")
	var panel: VillagerPanel = main.get_node("UI/VillagerPanel")
	panel.open_unit(unit)
	assert(panel.unit_name.text == unit.character_name and panel.unit_name.tooltip_text.contains("配置剑士"))
	if DisplayServer.get_name() != "headless":
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/named_unit_preview.png")
	assert(unit.get_max_health() == 175.0 and unit.get_health() == 175.0)
	assert(is_equal_approx(unit.get_move_speed(), 4.4) and unit.carry_capacity == 8.0)
	assert(unit.combat_damage == 17.0 and unit.hunger_rate == 0.25)
	assert(unit.visual_instance != null and not unit.body_mesh.visible)
	assert(unit.visual_instance.get_node("模型").material_override.albedo_color == Color.BLUE)
	assert(unit.get_node("NavigationAgent3D") != null and unit.get_node("ClickArea") != null)
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://.godot/unit_editor_enemy.tres")
	main.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.global_position = unit.global_position + Vector3(1, 0, 0)
	assert(enemy.current_health == 75.0 and enemy.damage == 7.0)
	unit.combat_target = enemy
	assert(unit._process_combat(0.1))
	assert(enemy.current_health == 58.0)
	unit.take_damage(35.0)
	unit.set_combat_role(CombatRole.Type.NONE)
	assert(unit.get_max_health() == 100.0 and unit.get_health() == 80.0)
	assert(unit.traits.size() == 1 and unit.traits[0] == preference_entry)
	assert(unit.unit_data.id == &"resident" and not unit.has_combat_role() and not unit.body_mesh.visible)
	assert(unit.visual_instance != null and unit.visual_instance.has_node("Head"))
	unit.set_combat_role(CombatRole.Type.SWORDSMAN)
	assert(unit.unit_data.id == &"swordsman" and unit.combat_damage == 10.0 and unit.get_health() == 80.0)
	assert(unit.visual_instance.has_node("SwordBlade") and unit.visual_instance.has_node("Shield"))
	assert(unit.visual_instance.get_node("SwordBlade").material_override == null)
	main.queue_free()
	await process_frame
	print("单位配置运行测试通过：保存的生命移动携带伤害生效、外观保留材质与导航点击、敌人读取配置、转职保留生命比例")
	quit()

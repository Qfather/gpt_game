extends SceneTree

var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config: CampSpawnConfig = load("res://data/camps/camp_spawn_v0.tres")
	_expect(config.validation_error().is_empty(), "示例配置合法")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var early: TreasureCampData = config.draw_camp(599.0, rng)
	var late: TreasureCampData = config.draw_camp(600.0, rng)
	_expect(early.display_name == "史莱姆宝箱营地" and late.display_name == "狼群物资营地", "时间段在600秒正确切换")
	rng.seed = 314
	var first: Dictionary = early.roll(rng)
	rng.seed = 314
	var second: Dictionary = early.roll(rng)
	_expect(first == second, "相同种子可复现奖励和守卫")
	var zero: CampGuardEntry = early.guard_pool[0].duplicate(false)
	zero.enemy = late.guard_pool[0].enemy
	zero.weight = 0.0
	var copy: TreasureCampData = early.duplicate(false)
	copy.guard_pool = early.guard_pool.duplicate()
	copy.guard_pool.append(zero)
	for index: int in range(50):
		var plan: Dictionary = copy.roll(rng)
		_expect(plan.guards.size() >= copy.minimum_guards and plan.guards.size() <= copy.maximum_guards, "守卫数量在范围内")
		_expect(not plan.guards.has(zero.enemy), "零权重守卫不会抽中")
	var invalid: CampSpawnConfig = config.duplicate(false)
	invalid.interval_min = invalid.interval_max + 1.0
	_expect(not invalid.validation_error().is_empty(), "拦截反向刷新间隔")
	var saved := LevelFlowData.new()
	saved.camp_config = config.duplicate(true)
	_expect(ResourceSaver.save(saved, "res://.godot/test_camp_preset.tres") == OK, "关卡营地配置可保存")
	var restored: LevelFlowData = ResourceLoader.load("res://.godot/test_camp_preset.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	_expect(restored.camp_config.camp_pool.size() == 2 and restored.camp_config.enabled, "关卡营地配置可读回")
	var fog: Node = load("res://Script/world/fog_of_war.gd").new()
	fog.extent = Vector2(256, 256)
	fog.visibility_map = Image.create(256, 256, false, Image.FORMAT_L8)
	fog.initialized = true
	fog.visibility_map.fill(Color(0.35, 0.35, 0.35))
	_expect(not fog.is_area_visible(Vector3.ZERO, 4.5), "已探索但无视野区域允许刷新")
	fog.visibility_map.set_pixel(131, 128, Color.WHITE)
	_expect(not fog.is_visible_at(Vector3.ZERO) and fog.is_area_visible(Vector3.ZERO, 4.5), "中心隐藏但营地边缘可见时拒绝刷新")
	fog.free()
	print("营地配置测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("失败：" + message)

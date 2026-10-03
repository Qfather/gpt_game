extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	failed = failed or not value

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var region := NavigationRegion3D.new()
	world.add_child(region)
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-20,0,-20),Vector3(-20,0,20),Vector3(20,0,20),Vector3(20,0,-20)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	var base: Node3D = load("res://Scene/building/base.tscn").instantiate()
	world.add_child(base)
	base.position = Vector3(-8,0,0)
	var farm: Farm = load("res://Scene/building/game/farm.tscn").instantiate()
	world.add_child(farm)
	farm.set_process(false)
	var panel: ResourceBuildingPanel = load("res://Scene/ui/resource_building_panel.tscn").instantiate()
	world.add_child(panel)
	var removed: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	var live: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(removed)
	world.add_child(live)
	removed.set_physics_process(false)
	live.set_physics_process(false)
	for i in range(10): await physics_frame
	assert(farm.add_worker(removed))
	removed.find_field_work()
	var removed_field: FarmField = removed.target_field
	assert(removed_field != null)
	removed.queue_free()
	for i in range(2): await process_frame
	_expect(farm.get_worker_count() == 0 and farm.has_free_slot(), "已释放的农民不计入工人数或占用岗位")
	_expect(removed_field.can_claim(), "农民被移除后原田块可重新预约")
	assert(farm.add_worker(live))
	live.find_field_work()
	var field: FarmField = live.target_field
	panel.current_building = farm
	# 延迟触发真实解雇按钮，让旧引用导致的脚本异常也能记录到日志。
	panel.fire_button.call_deferred("emit_signal", "pressed")
	for i in range(3): await process_frame
	_expect(farm.get_worker_count() == 0 and live.job == live.Job.NONE and live.workplace == null, "名单含旧引用时点击解雇仍能解雇有效农民")
	_expect(live.target_field == null and field.can_claim(), "正常解雇释放正在工作的田块")
	assert(farm.add_worker(live))
	live.find_field_work()
	live.carried_resource_id = &"grain"
	live.carried_amount = 2.0
	var carried_field: FarmField = live.target_field
	panel.fire_button.call_deferred("emit_signal", "pressed")
	for i in range(3): await process_frame
	_expect(live.is_quitting_job and live.carried_amount == 2.0 and live.state == live.State.MOVE_TO_WORKPLACE and carried_field.can_claim(), "带谷物解雇保留携带物并先返回农场，释放田块")
	live.deposit_to_workplace()
	_expect(live.carried_amount == 0.0 and live.job == live.Job.NONE and farm.get_resource_amount(&"grain") == 2.0, "离职前谷物入库，没有丢失")
	panel.fire_button.call_deferred("emit_signal", "pressed")
	for i in range(2): await process_frame
	_expect(farm.get_worker_count() == 0, "无人时重复点击解雇不报错")
	assert(farm.add_worker(live))
	live.find_field_work()
	var death_field: FarmField = live.target_field
	live.take_damage(100000.0)
	_expect(farm.get_worker_count() == 0 and death_field.can_claim(), "农民死亡后立即释放岗位与田块")
	await create_timer(0.4).timeout
	panel.fire_button.call_deferred("emit_signal", "pressed")
	for i in range(2): await process_frame
	_expect(farm.get_worker_count() == 0, "死亡居民被清理后点击解雇不报错")
	world.queue_free()
	await process_frame
	print("农场解雇测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

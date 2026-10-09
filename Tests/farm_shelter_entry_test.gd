extends SceneTree
var failed := false
func _initialize(): call_deferred("_run")
func _run():
	var main = load("res://Scene/main.tscn").instantiate()
	main.level_preset = main.level_preset.duplicate(true)
	main.level_preset.layout_seed = 418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled = false
	root.add_child(main)
	current_scene = main
	for i in range(90): await physics_frame
	main.get_node("Systems/PopulationManager").set_process(false)
	for unit in get_nodes_in_group("villagers"): unit.set_physics_process(false)
	var base = get_first_node_in_group("bases")
	var farm: Farm = load("res://Scene/building/game/farm.tscn").instantiate()
	farm.building_data = load("res://data/buildings/FarmData.tres")
	main.add_child(farm)
	farm.position = base.position + Vector3(5,0,0)
	var worker = load("res://Scene/unit/villager.tscn").instantiate()
	main.add_child(worker)
	worker.set_physics_process(false)
	for i in range(20): await physics_frame
	worker.position = farm.position + Vector3(1,0,4)
	worker.job = worker.Job.FARMER
	worker.workplace = farm
	farm.workers.append(worker)
	var enemy = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres")
	main.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position = worker.position + Vector3(0,0,3)
	worker._begin_civilian_retreat(enemy)
	worker.shelter_target = farm
	worker.retreat_safe_at_msec = Time.get_ticks_msec() + 20000
	farm.reserve_shelter(worker)
	worker.navigation_agent.target_position = worker._get_reachable_workplace_position()
	for i in range(600):
		worker._process_civilian_retreat(1.0/60)
		await physics_frame
		if worker.state == worker.State.SHELTERED and not worker.passing_door: break
	print("FARM_RESULT state=",worker.state," pos=",worker.position," door=",farm.get_entrance_position()," target=",worker.navigation_agent.target_position," bounds=",farm._get_entrance_front_bounds()," indoor=",worker.indoor_building)
	failed = worker.state != worker.State.SHELTERED or worker.indoor_building != farm
	var edge_worker = load("res://Scene/unit/villager.tscn").instantiate()
	main.add_child(edge_worker)
	edge_worker.set_physics_process(false)
	for i in range(5): await physics_frame
	var front: AABB = farm._get_entrance_front_bounds()
	edge_worker.position = farm.to_global(Vector3(front.get_center().x,0,front.position.z-0.15))
	edge_worker.job = edge_worker.Job.FARMER
	edge_worker.workplace = farm
	farm.workers.append(edge_worker)
	edge_worker.shelter_target = farm
	edge_worker.retreat_safe_at_msec = Time.get_ticks_msec() + 20000
	farm.reserve_shelter(edge_worker)
	edge_worker.state = edge_worker.State.RETREAT_TO_BASE
	edge_worker.navigation_agent.target_position = farm.to_global(Vector3(front.get_center().x,0,front.position.z+0.05))
	print("[通过] " if not farm.is_at_entrance_front(edge_worker.position) else "[失败] ","复现导航距入口目标0.2米，但严格入口判定拒绝")
	edge_worker._process_civilian_retreat(0.016)
	for i in range(180):
		await physics_frame
		if not edge_worker.passing_door: break
	var entered: bool = edge_worker.state==edge_worker.State.SHELTERED and edge_worker.indoor_building==farm
	print("[通过] " if entered else "[失败] ","农民在入口导航容差内能完成入屋避难")
	failed = failed or not entered
	quit(1 if failed else 0)

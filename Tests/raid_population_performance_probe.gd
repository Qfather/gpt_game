extends SceneTree
class UncachedFog extends "res://Script/world/fog_of_war.gd":
	func _get_visibility_children(object: Node) -> Dictionary:
		return {"meshes": object.find_children("*", "GeometryInstance3D", true, false), "colliders": object.find_children("*", "CollisionObject3D", true, false)}
func _initialize(): call_deferred("_run")
func _sample(label):
	for i in range(20): await process_frame
	var samples: Array[float] = []
	var last = Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now = Time.get_ticks_usec()
		samples.append((now-last)/1000.0)
		last=now
	samples.sort()
	print("PROFILE ",label," P50=",samples[90]," P95=",samples[171]," max=",samples.back())
func _run():
	seed(418)
	var main=load("res://Scene/main.tscn").instantiate()
	main.level_preset=main.level_preset.duplicate(true)
	main.level_preset.layout_seed=418
	main.level_preset.events.clear()
	main.level_preset.camp_config.enabled=false
	root.add_child(main)
	current_scene=main
	for i in range(90): await physics_frame
	if "--uncached" in OS.get_cmdline_user_args():
		get_first_node_in_group("fog_of_war").free()
		main.add_child(UncachedFog.new())
	Engine.time_scale = 3.0 if "--triple" in OS.get_cmdline_user_args() else 1.0
	print("PROFILE speed=",Engine.time_scale," uncached=","--uncached" in OS.get_cmdline_user_args())
	main.get_node("Systems/PopulationManager").set_process(false)
	main.get_node("Systems/EncounterDirector").elapsed_time=1140
	var base=get_first_node_in_group("bases")
	while get_nodes_in_group("villagers").size()<11:
		var unit=load("res://Scene/unit/villager.tscn").instantiate()
		main.add_child(unit)
		unit.position=base.position+Vector3(randf_range(-3,3),0,3)
	var farm=load("res://Scene/building/game/farm.tscn").instantiate()
	farm.building_data=load("res://data/buildings/FarmData.tres")
	main.add_child(farm)
	farm.position=base.position+Vector3(5,0,0)
	for i in range(60): await physics_frame
	for i in range(3): farm.add_worker(get_nodes_in_group("villagers")[i])
	await _sample("11人无敌人")
	for i in range(5):
		var enemy=load("res://Scene/unit/enemy_base.tscn").instantiate()
		enemy.enemy_data=load("res://data/enemies/raid/SlimeData.tres").duplicate()
		enemy.enemy_data.damage=0
		main.add_child(enemy)
		enemy.position=base.position+Vector3(i-2,0,6)
		main.register_enemy(enemy)
	await _sample("11人5敌人")
	var fog=get_first_node_in_group("fog_of_war")
	var start=Time.get_ticks_usec()
	for i in range(5): fog.refresh_visibility()
	print("PROFILE fog_avg_ms=",(Time.get_ticks_usec()-start)/5000.0)
	fog.set_process(false)
	await _sample("仅诊断停用迷雾刷新")
	quit()

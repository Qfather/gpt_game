extends SceneTree

class TestAgent extends RefCounted:
	var assignments: int = 0
	var target_position: Vector3:
		set(value):
			target_position = value
			assignments += 1
	var navigation_map: RID
	func get_navigation_map() -> RID:
		return navigation_map

class TestHunter extends Node3D:
	enum State { HUNTING }
	var state: int = State.HUNTING
	var workplace: Node3D
	var navigation_agent := TestAgent.new()
	var combat_attack_cooldown: float = 0.0
	var velocity: Vector3 = Vector3.ZERO
	var is_quitting_job: bool = false
	func move_along_navigation() -> void:
		pass

class TestHouse extends Node3D:
	var processing_min: float = 1.0
	var processing_max: float = 1.0
	var meat: float = 0.0
	func get_interaction_position(_worker: Node) -> Vector3:
		return Vector3(10, 0, 0)
	func deposit_resource(_resource: StringName, amount: float) -> float:
		meat += amount
		return amount
	func is_storage_full() -> bool:
		return false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(map, true)
	var region: RID = NavigationServer3D.region_create()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-5, 0, -5), Vector3(-5, 0, 5), Vector3(5, 0, 5), Vector3(5, 0, -5)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	NavigationServer3D.region_set_navigation_mesh(region, mesh)
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.map_force_update(map)
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await physics_frame
	for i in range(5): await physics_frame
	var hunter := TestHunter.new()
	var house := TestHouse.new()
	root.add_child(hunter)
	root.add_child(house)
	hunter.workplace = house
	hunter.navigation_agent.navigation_map = map
	var hunting = load("res://Script/unit/hunting_behavior.gd").new()
	for i in range(60): hunting.move(hunter, Vector3(4, 0, 0))
	var no_repeated_path: bool = hunter.navigation_agent.assignments == 1
	hunter.global_position = Vector3(5, 0, 0)
	hunting.prey_count = 1
	hunting.raw_meat = 1.0
	hunting.request_return(hunter)
	for i in range(120):
		hunting.process(hunter, 1.0 / 60.0)
		if house.meat > 0.0: break
	var processed: bool = house.meat == 1.0 and hunting.prey_count == 0
	if not no_repeated_path: push_error("猎户固定目标重复设置导航路径")
	if not processed: push_error("猎户到达可行走边缘后无法处理导航区外的交互点")
	hunter.free()
	house.free()
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	if no_repeated_path and processed: print("猎户返程导航测试通过：固定目标不重复寻路，交互点在导航外也能到达并处理")
	quit(0 if no_repeated_path and processed else 1)

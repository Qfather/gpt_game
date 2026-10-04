extends SceneTree

class CountedFog extends "res://Script/world/fog_of_war.gd":
	var reveal_calls: int = 0
	func _reveal_at(point: Vector3, radius: float = SIGHT_RADIUS, trees: Array[Vector3] = []) -> void:
		reveal_calls += 1
		super._reveal_at(point, radius, trees)

class ReferenceFog extends "res://Script/world/fog_of_war.gd":
	func refresh_visibility() -> void:
		refresh_queued = false
		visibility_map.copy_from(explored)
		visual_map.fill(Color(0.0, 1.0, 0.0, 0.0))
		fully_visible_pixels.resize(RESOLUTION * RESOLUTION)
		fully_visible_pixels.fill(0)
		merging_visibility = true
		var tree_occluders: Array[Vector3] = _collect_tree_occluders()
		for unit: Node in get_tree().get_nodes_in_group("villagers"):
			if not unit is Node3D or not unit.is_visible_in_tree() or (unit.has_method("is_dead") and unit.is_dead()):
				continue
			if not unit.has_method("get_faction") or unit.get_faction() != EnemyData.Faction.SETTLEMENT:
				continue
			_reveal_at(unit.global_position, SIGHT_RADIUS, tree_occluders)
		for building: Node in get_tree().get_nodes_in_group("buildings"):
			if not building is Node3D or building is ConstructionSite or building.is_queued_for_deletion() or not building.is_visible_in_tree():
				continue
			if building.has_method("get_health") and building.get_health() <= 0.0:
				continue
			var radius: float = building.get_sight_radius() if building.has_method("get_sight_radius") else SIGHT_RADIUS
			_reveal_at(building.global_position, radius, tree_occluders)
		for camp: Node in get_tree().get_nodes_in_group("treasure_camps"):
			if camp is TreasureCamp and camp.cleared and not camp.is_queued_for_deletion():
				_reveal_at(camp.global_position, SIGHT_RADIUS, tree_occluders)
		merging_visibility = false
		_reveal_visible_tree_canopies()
		mask_texture.update(visual_map)
		_refresh_object_visibility()

class Resident extends Node3D:
	var dead: bool = false
	func get_faction() -> int: return EnemyData.Faction.SETTLEMENT
	func is_dead() -> bool: return dead

class Building extends Node3D:
	var health: float = 100.0
	var radius: float = 12.0
	func get_health() -> float: return health
	func get_sight_radius() -> float: return radius

var failed: bool = false
var actual: Node
var reference: Node
var actors: Array[Node3D] = []
var buildings: Array[Node3D] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _compare(message: String) -> void:
	actual.refresh_visibility()
	reference.refresh_visibility()
	for key: String in ["visibility_map", "visual_map", "explored"]:
		_expect(actual.get(key).get_data() == reference.get(key).get_data(), message + "：" + key + " 像素不一致")

func _run() -> void:
	actual = CountedFog.new()
	reference = ReferenceFog.new()
	for fog: Node in [actual, reference]:
		root.add_child(fog)
		fog.set_process(false)
		fog.extent = Vector2(80, 64)
		fog.explored = Image.create(256, 256, false, Image.FORMAT_L8)
		fog.visibility_map = Image.create(256, 256, false, Image.FORMAT_L8)
		fog.visual_map = Image.create(256, 256, false, Image.FORMAT_RGBA8)
		fog.mask_texture = ImageTexture.create_from_image(fog.visual_map)
		fog.initialized = true
	for index: int in range(22):
		var actor := Resident.new()
		root.add_child(actor)
		actor.add_to_group("villagers")
		actor.position = Vector3(index % 6 - 3, 0, index / 6 - 2)
		actors.append(actor)
	for index: int in range(15):
		var building := Building.new()
		root.add_child(building)
		building.add_to_group("buildings")
		building.position = Vector3(index % 5 * 5 - 12, 0, index / 5 * 6 - 8)
		buildings.append(building)
	var tree: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate()
	tree.visual_scale_min = 1.0
	tree.visual_scale_max = 1.0
	root.add_child(tree)
	tree.position = Vector3(5, 0, 0)
	var prey := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	prey.add_child(mesh)
	root.add_child(prey)
	prey.add_to_group("wildlife")
	prey.position = Vector3(35, 0, 25)
	_compare("初次刷新")
	var calls: int = actual.reveal_calls
	_compare("静止复用")
	_expect(actual.reveal_calls == calls, "静止视野仍重复计算")
	paused = true
	for index: int in range(3): _compare("暂停复用")
	_expect(actual.reveal_calls == calls, "暂停仍重复计算视野")
	paused = false
	prey.position = actors[0].position
	actual.refresh_visibility()
	_expect(mesh.visible and not prey.get_meta("fog_hidden"), "贴图复用时移动猎物没有显露")
	prey.position = Vector3(35, 0, 25)
	actual.refresh_visibility()
	_expect(not mesh.visible and prey.get_meta("fog_hidden"), "贴图复用时离开视野的猎物没有隐藏")
	_expect(actual.reveal_calls == calls, "只有猎物移动也重算视野")
	actors[0].position = Vector3(30, 0, 0)
	_compare("居民移动")
	_expect(actual.reveal_calls - calls == 22, "居民移动没有复用15个固定视野")
	actors[0].dead = true
	_compare("居民死亡")
	actors[1].hide()
	_compare("居民进建筑隐藏")
	actors[1].show()
	_compare("居民离开建筑")
	buildings[0].radius *= 1.5
	_compare("箭塔视野变化")
	buildings[1].position += Vector3(7, 0, 0)
	_compare("建筑搬迁")
	buildings[2].health = 0.0
	_compare("建筑摧毁")
	buildings[3].queue_free()
	_compare("建筑等待释放")
	await process_frame
	_compare("建筑释放")
	for multiplier: float in [0.6, 1.0, 1.5]:
		actual._on_night_visibility_changed(multiplier)
		reference._on_night_visibility_changed(multiplier)
		_compare("昼夜倍率")
	tree.get_node("meshs").scale *= 0.5
	_compare("树木生长缩放")
	tree.position += Vector3(1, 2, 0)
	_compare("树木位置高度变化")
	tree.queue_free()
	_compare("砍树等待释放")
	await process_frame
	_compare("砍树释放")
	var started: int = Time.get_ticks_usec()
	for index: int in range(10): reference.refresh_visibility()
	var old_usec: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for index: int in range(10): actual.refresh_visibility()
	var new_usec: int = Time.get_ticks_usec() - started
	print("同场景静止刷新平均毫秒：原版=", old_usec / 10000.0, " 缓存版=", new_usec / 10000.0)
	var elapsed: Array[float] = []
	for fog: Node in [reference, actual]:
		started = Time.get_ticks_usec()
		for index: int in range(10):
			actors[1].position.x = float(index % 2) + 3.0
			fog.refresh_visibility()
		elapsed.append((Time.get_ticks_usec() - started) / 10000.0)
	print("居民移动刷新平均毫秒：原版=", elapsed[0], " 缓存版=", elapsed[1])
	print("迷雾缓存测试", "失败" if failed else "通过", "：暂停、固定视野复用、移动对象显隐、居民死亡隐藏、建筑变化、昼夜、树木变化；三张图逐字节对照原版")
	for child: Node in root.get_children(): child.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)

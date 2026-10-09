extends SceneTree

const CONNECTIONS: Script = preload("res://Script/building/wall_connections.gd")
var failed: bool = false
var world: Node3D
var grid: BuildGrid
var ghost: BuildingGhost
var roads: Node

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

func _wall(cell: Vector2i, data: BuildingData) -> Wall:
	var wall: Wall = data.building_scene.instantiate() as Wall
	wall.building_data = data
	grid.occupy_area(cell, Vector2i.ONE, 0, false, true)
	world.add_child(wall)
	wall.position = grid.grid_to_world(cell)
	wall.set_build_grid_occupancy(cell, Vector2i.ONE, 0)
	return wall

func _site(cell: Vector2i) -> ConstructionSite:
	for node: Node in get_nodes_in_group("construction_sites"):
		if not node.is_queued_for_deletion() and node.grid_position == cell: return node as ConstructionSite
	return null

func _place(data: BuildingData, cell: Vector2i, turns: int = 0) -> bool:
	var size: Vector2i = grid.get_rotated_size(data.grid_size, turns)
	var position: Vector3 = grid.grid_to_world(cell) + Vector3(size.x - 1, 0, size.y - 1) * 0.5
	return ghost._create_construction_site(data, cell, turns, false, Transform3D(Basis(Vector3.UP, turns * PI * 0.5), position), false, true)

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var systems := Node3D.new()
	systems.name = "Systems"
	world.add_child(systems)
	grid = BuildGrid.new()
	grid.name = "BuildGrid"
	grid.grid_min = Vector2i(-30, -30)
	grid.grid_max = Vector2i(30, 30)
	systems.add_child(grid)
	roads = preload("res://Script/world/road_manager.gd").new()
	roads.grid = grid
	world.add_child(roads)
	ghost = BuildingGhost.new()
	systems.add_child(ghost)
	ghost.set_process(false)
	var input_camera := Camera3D.new()
	world.add_child(input_camera)
	input_camera.position = Vector3(0, 25, 16)
	input_camera.look_at(Vector3.ZERO)
	input_camera.current = true
	var stone: BuildingData = load("res://data/buildings/WallData.tres")
	var wood: BuildingData = load("res://data/buildings/WoodWallData.tres")
	var gate: BuildingData = load("res://data/buildings/GateData.tres")
	var tower: BuildingData = load("res://data/buildings/WallTowerData.tres")
	_expect(stone.grid_size == Vector2i.ONE and wood.grid_size == Vector2i.ONE and gate.grid_size == Vector2i(4, 1), "墙1×1、门4×1资源已接入")
	for data: BuildingData in [stone, wood]:
		for scene: PackedScene in data.wall_scenes():
			var model: Node3D = scene.instantiate() as Node3D
			_expect(model != null and model.find_children("*", "MeshInstance3D", true, false).size() > 0, "正式墙资源引用基本体模型：" + scene.resource_path)
			model.free()
	# 实际墙节点验证16种邻接形态，切换模型不重置血量。
	var center: Wall = _wall(Vector2i(-20, -20), stone)
	center.take_damage(30)
	var health: float = center.get_health()
	for mask: int in range(16):
		var neighbors: Array[Wall] = []
		for index: int in range(4):
			if mask & (1 << index): neighbors.append(_wall(center.build_grid_position + CONNECTIONS.DIRECTIONS[index], wood))
		CONNECTIONS.refresh(self)
		var shape: Vector2i = CONNECTIONS.shape_for_mask(mask)
		_expect(center.connection_mask == mask and center.connection_model.scene_file_path == stone.wall_scenes()[shape.x].resource_path and is_equal_approx(center.connection_model.rotation.y, -shape.y * PI * 0.5), "形态、实际场景和旋转正确：%d" % mask)
		_expect(center.get_health() == health, "连接更新保留墙血量：%d" % mask)
		for neighbor: Wall in neighbors: CONNECTIONS.remove_wall(neighbor)
		await process_frame
	CONNECTIONS.remove_wall(center)
	await process_frame
	# 连接臂之间不能留下可穿过的物理缝隙。
	var collision_wall: Wall = _wall(Vector2i(-15, -10), stone)
	var collision_neighbor: Wall = _wall(Vector2i(-14, -10), stone)
	var probe := CharacterBody3D.new()
	var probe_shape := CollisionShape3D.new()
	var probe_capsule := CapsuleShape3D.new()
	probe_capsule.radius = 0.1
	probe_capsule.height = 0.6
	probe_shape.shape = probe_capsule
	probe.add_child(probe_shape)
	world.add_child(probe)
	probe.position = grid.grid_to_world(Vector2i(-15, -10)) + Vector3(0.5, 0.75, -1)
	await physics_frame
	var wall_hit: KinematicCollision3D = probe.move_and_collide(Vector3(0, 0, 2))
	_expect(wall_hit != null, "实际角色不能穿过相邻完工墙段的连接处")
	probe.queue_free()
	CONNECTIONS.remove_wall(collision_wall)
	CONNECTIONS.remove_wall(collision_neighbor)
	await process_frame
	# 绕过建筑占地；资源允许先拍蓝图，预览／提交均不立即删除资源。
	ghost.building_data = stone
	grid.occupied_cells[Vector2i.ZERO] = true
	var resource: ResourceBase = load("res://Scene/resource/stone.tscn").instantiate()
	world.add_child(resource)
	resource.position = grid.grid_to_world(Vector2i(2, 0))
	await process_frame
	var path: Array[Vector2i] = ghost.plan_wall_stroke(Vector2i(-3, 0), Vector2i(5, 0))
	_expect(path.size() > 9 and not path.has(Vector2i.ZERO) and ghost.can_place_at(stone, Vector2i(2, 0), 0), "墙拖拽绕过建筑，资源所在格允许拍下蓝图")
	_expect(ghost.place_wall_stroke(path), "预览路线提交为逐格工地")
	_expect(not resource.is_queued_for_deletion() and resource.resource_amount > 0, "铺墙不清除资源")
	for cell: Vector2i in path:
		var site: ConstructionSite = _site(cell)
		_expect(site != null and site.building_data.construction_time == stone.construction_time, "路线工地沿用每格成本与施工时间")
	_expect(ghost.place_wall_stroke(path), "经过已标记墙段不重复施工")
	for cell: Vector2i in path: _site(cell).cancel_construction()
	resource.queue_free()
	grid.occupied_cells.erase(Vector2i.ZERO)
	await process_frame
	# 通过实际鼠标按下／松开处理函数提交路线。
	ghost.select_building(wood)
	var from := Vector2i(-8, -8)
	var to := Vector2i(-3, -8)
	var click_resource: ResourceBase = load("res://Scene/resource/tree.tscn").instantiate()
	world.add_child(click_resource)
	click_resource.position = grid.grid_to_world(from)
	await physics_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = input_camera.unproject_position(grid.grid_to_world(from))
	ghost._unhandled_input(down)
	_expect(ghost.wall_dragging, "鼠标按下启动木墙拖拽")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = input_camera.unproject_position(grid.grid_to_world(to))
	ghost._unhandled_input(up)
	_expect(not ghost.wall_dragging and _site(from) != null and _site(to) != null, "鼠标松开生成完整木墙工地路线")
	_expect(_site(from).get_blocking_resource() == click_resource and not click_resource.is_queued_for_deletion(), "资源所在格实际点击可放下蓝图，资源留待工人清理")
	ghost.cancel_preview()
	for x: int in range(from.x, to.x + 1): _site(Vector2i(x, from.y)).cancel_construction()
	click_resource.queue_free()
	await process_frame
	# 正常城门、四墙改建、半价与取消后空地。
	_expect(_place(gate, Vector2i(-10, 0)), "空地可建4×1门")
	var site: ConstructionSite = _site(Vector2i(-10, 0))
	_expect(site.required_resources == gate.construction_cost, "空地城门正常收费")
	var gate_end: Wall = _wall(Vector2i(-11, 0), stone)
	var gate_side: Wall = _wall(Vector2i(-9, 1), stone)
	site._complete_construction()
	await process_frame
	var finished_gate: Gate = CONNECTIONS.cells(self).get(Vector2i(-10, 0)) as Gate
	_expect(finished_gate != null and finished_gate.get_health() == gate.max_health and gate_end.connection_mask == 2 and gate_side.connection_mask == 0, "完工城门有正常血量，墙仅连接门的长轴两端")
	finished_gate.take_damage(10000)
	await process_frame
	_expect(not grid.occupied_cells.has(Vector2i(-10, 0)) and gate_end.connection_mask == 0, "摧毁城门释放占地并更新邻墙")
	CONNECTIONS.remove_wall(gate_end)
	CONNECTIONS.remove_wall(gate_side)
	await process_frame
	var replaced: Array[Wall] = []
	for x: int in range(3): replaced.append(_wall(Vector2i(10 + x, 0), stone))
	_expect(not ghost.can_place_at(gate, Vector2i(10, 0), 0), "城门不能覆盖三格墙与一格空地")
	replaced.append(_wall(Vector2i(13, 0), stone))
	var side_wall: Wall = _wall(Vector2i(11, 1), stone)
	_expect(not ghost.can_place_at(gate, Vector2i(10, 0), 0), "城门不能覆盖三通或拐角墙段")
	CONNECTIONS.remove_wall(side_wall)
	await process_frame
	_expect(_place(gate, Vector2i(10, 0)), "四段直墙上直接拍城门蓝图")
	site = _site(Vector2i(10, 0))
	_expect(site.get_required_amount(&"wood") == gate.construction_cost[&"wood"] * 0.5 and site.get_required_amount(&"stone") == gate.construction_cost[&"stone"] * 0.5, "四墙改建城门费用减半")
	_expect(gate.construction_cost[&"wood"] == 15, "改建不修改共享门配置")
	for wall: Wall in replaced: _expect(wall.is_queued_for_deletion() and wall.get_node("StaticBody3D").collision_layer == 0, "拍门蓝图立即移除原墙阻挡")
	site.state = ConstructionSite.State.BUILDING
	site.construction_progress = 1
	_expect(site.get_max_health() == 0 and site.take_damage(100) == 0 and not site.has_node("StaticBody3D"), "门施工期间无血量、不可攻击、没有实体阻挡")
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres")
	enemy.raid_active = true
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.update_targeting()
	_expect(enemy.target != site, "敌人不选中正在施工的城门")
	enemy.queue_free()
	var body := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = CapsuleShape3D.new()
	body.add_child(collision)
	world.add_child(body)
	body.position = Vector3(9, 1, 0.5)
	await physics_frame
	_expect(body.move_and_collide(Vector3(5, 0, 0)) == null, "实际物理角色可穿过四格城门工地")
	body.queue_free()
	site.construction_progress = 0
	site.cancel_construction()
	await process_frame
	for x: int in range(4): _expect(not grid.occupied_cells.has(Vector2i(10 + x, 0)), "取消城门留下空地")
	# 木门改建及旋转4格占地。
	var wood_gate: BuildingData = load("res://data/buildings/WoodGateData.tres")
	for y: int in range(4): _wall(Vector2i(18, y), wood)
	_expect(not ghost.can_place_at(gate, Vector2i(18, 0), 1), "不同材料的墙不能领取改建折扣")
	_expect(_place(wood_gate, Vector2i(18, 0), 1), "竖向四格木墙可改建木门")
	site = _site(Vector2i(18, 0))
	_expect(site.get_required_amount(&"wood") == wood_gate.construction_cost[&"wood"] * 0.5, "木门改建半价")
	site.cancel_construction()
	await process_frame
	# 塔楼只建在对应底墙上，施工／取消保留底墙。
	_expect(not ghost.can_place_at(tower, Vector2i(5, 5), 0), "塔楼不可建在空地")
	var foundation: Wall = _wall(Vector2i(5, 5), stone)
	_expect(_place(tower, Vector2i(5, 5)), "对应墙段可拍塔楼蓝图")
	site = _site(Vector2i(5, 5))
	_expect(not foundation.is_queued_for_deletion() and foundation.get_node("StaticBody3D").collision_layer != 0 and site.exterior_construction_started, "塔楼施工保留原墙防御，工人在外侧施工")
	_expect(not site.can_be_moved() and not ghost.can_place_at(tower, Vector2i(5, 5), 0), "塔楼工地不能搬离底墙或重复叠加")
	site.cancel_construction()
	await process_frame
	_expect(is_instance_valid(foundation) and foundation.tower_site == null and grid.occupied_cells.has(Vector2i(5, 5)), "取消塔楼保留底墙与占地")
	_expect(_place(tower, Vector2i(5, 5)), "取消后底墙仍可重建塔楼")
	site = _site(Vector2i(5, 5))
	site._complete_construction()
	await process_frame
	var completed: BuildingBase = CONNECTIONS.cells(self).get(Vector2i(5, 5))
	_expect(completed != null and completed.building_data.is_wall_tower() and completed.get_garrison_capacity() == 1 and completed.get_garrison_role() == CombatRole.Type.ARCHER and not is_instance_valid(foundation), "竣工替换底墙，塔楼仅驻守1弓箭手")
	_expect(completed.get_garrison_position(null) == completed.global_position + Vector3(0, 3, 0), "单个驻军站在塔楼平台中心")
	var tower_collision: CollisionShape3D = completed.get_node("StaticBody3D/CollisionShape3D")
	_expect(tower_collision.shape.size.x * tower_collision.scale.x == grid.cell_size and tower_collision.shape.size.z * tower_collision.scale.z == grid.cell_size, "塔楼实体覆盖底墙整格，不留下穿墙缝隙")
	var archer: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(archer)
	archer.set_process(false)
	archer.set_physics_process(false)
	archer.set_combat_role(CombatRole.Type.ARCHER)
	archer.state = archer.State.IDLE
	var second_archer: Node3D = load("res://Scene/unit/villager.tscn").instantiate()
	world.add_child(second_archer)
	second_archer.set_process(false)
	second_archer.set_physics_process(false)
	second_archer.set_combat_role(CombatRole.Type.ARCHER)
	second_archer.state = second_archer.State.IDLE
	_expect(archer.try_assign_to_barracks(completed) and not second_archer.try_assign_to_barracks(completed), "实际弓箭手预约塔楼，第二人被拒绝")
	completed.enter_garrison(archer)
	_expect(completed.get_garrison_count() == 1 and archer.state == archer.State.GARRISONED and archer.global_position == completed.get_garrison_position(archer), "实际弓箭手驻守平台，容量为一人")
	archer.leave_garrison()
	completed.unregister_garrison(archer)
	archer.queue_free()
	second_archer.queue_free()
	# 木塔楼同样限制底墙材料。
	var wood_tower: BuildingData = load("res://data/buildings/WoodWallTowerData.tres")
	var wood_foundation: Wall = _wall(Vector2i(10, 6), wood)
	_expect(not ghost.can_place_at(tower, Vector2i(10, 6), 0) and _place(wood_tower, Vector2i(10, 6)), "木墙可建木塔楼，不能直接建石塔楼")
	_site(Vector2i(10, 6)).cancel_construction()
	CONNECTIONS.remove_wall(wood_foundation)
	# 底墙被敌人摧毁时不能凭空完成塔楼。
	foundation = _wall(Vector2i(8, 5), stone)
	_place(tower, Vector2i(8, 5))
	site = _site(Vector2i(8, 5))
	foundation.take_damage(10000)
	await process_frame
	await process_frame
	_expect(not grid.occupied_cells.has(Vector2i(8, 5)) and not is_instance_valid(site), "底墙被摧毁时取消空材料塔楼工地，不残留占地")
	if DisplayServer.get_name() != "headless":
		await _screenshot(stone, wood)
	world.queue_free()
	await process_frame
	print("城墙、城门、塔楼系统测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _screenshot(stone: BuildingData, wood: BuildingData) -> void:
	for building: Node3D in get_nodes_in_group("buildings"): building.hide()
	# 将两套正式场景放到独立展示区，六种形态的朝向来自实际连接代码。
	for family: int in range(2):
		var data: BuildingData = stone if family == 0 else wood
		for shape: int in range(6):
			var cell := Vector2i(-12 + shape * 4, 12 + family * 6)
			_wall(cell, data)
			for index: int in range(4):
				if CONNECTIONS.SHAPE_MASKS[shape] & (1 << index): _wall(cell + CONNECTIONS.DIRECTIONS[index], data)
		for kind: String in ["gate", "tower"]:
			var prefix: String = "stone" if family == 0 else "wood"
			var model: Node3D = load("res://Scene/building/visual/fortifications/%s_%s.tscn" % [prefix, kind]).instantiate()
			world.add_child(model)
			model.position = Vector3(14 if kind == "gate" else 19, 0, 12.5 + family * 6)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3, 25, 32)
	camera.look_at(Vector3(3, 0, 15))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.current = true
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-65, -25, 0)
	root.size = Vector2i(1600, 900)
	for frame: int in range(12): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://.godot/fortifications_models.png")

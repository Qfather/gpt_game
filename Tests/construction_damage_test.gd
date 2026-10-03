extends SceneTree

var failed: bool = false

class WaitingWorker extends Node3D:
	var carried_amount: float = 0
	var released: bool = false
	var returned_cargo: bool = false
	var current_task: GameTask
	func return_to_idle() -> void:
		released = true
	func clear_current_task() -> void:
		current_task = null
	func return_carried_resource_to_base() -> bool:
		if carried_amount <= 0: return false
		go_to_base()
		return true
	func go_to_base() -> void:
		returned_cargo = true

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var systems := Node.new()
	systems.name = "Systems"
	world.add_child(systems)
	var grid := BuildGrid.new()
	grid.name = "BuildGrid"
	systems.add_child(grid)
	var manager := TaskManager.new()
	systems.add_child(manager)
	var data: BuildingData = load("res://data/buildings/HouseData.tres").duplicate(true)
	data.grid_size = Vector2i.ONE
	data.max_health = 10
	var cell := Vector2i(5, 5)
	_expect(grid.occupy_area(cell, data.grid_size), "工地占用网格")
	var site := ConstructionSite.new()
	site.setup(data, cell, 0, false)
	world.add_child(site)
	site.set_process(false)
	var worker := WaitingWorker.new()
	world.add_child(worker)
	site.register_construction_worker(worker)
	site.waiting_workers.append(worker)
	var carrier := WaitingWorker.new()
	world.add_child(carrier)
	carrier.carried_amount = 5
	site.construction_workers.append(carrier)
	site.delivery_workers.append(carrier)
	site.reserve_resource(&"wood", 5)
	var task: GameTask = manager.create_task(GameTask.TaskType.DELIVER_CONSTRUCTION_RESOURCE, site, site)
	task.data = {"resource_id": &"wood", "amount": 5.0}
	task.state = GameTask.State.IN_PROGRESS
	task.assigned_worker = carrier
	carrier.current_task = task
	var enemy: EnemyBase = load("res://Scene/unit/enemy_base.tscn").instantiate()
	enemy.enemy_data = load("res://data/enemies/raid/SlimeData.tres")
	enemy.raid_active = true
	world.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.update_targeting()
	_expect(enemy.target == null, "刚放下的蓝图不会被史莱姆选中")
	_expect(site.take_damage(1000, enemy) == 0 and site.get_health() == 10, "蓝图不接受伤害")
	site.state = ConstructionSite.State.READY_TO_BUILD
	enemy.update_targeting()
	_expect(enemy.target == null, "材料备齐但尚未施工的蓝图也不被攻击")
	site.state = ConstructionSite.State.BUILDING
	enemy.update_targeting()
	_expect(enemy.target == site and site.get_health() == 10, "开始施工后史莱姆能选中工地，血量来自建筑配置")
	enemy._physics_process(1.0)
	_expect(site.get_health() == 6, "史莱姆实际攻击工地并扣除护甲")
	site.construction_progress = 1.0
	site.state = ConstructionSite.State.READY_TO_BUILD
	enemy.update_targeting()
	_expect(enemy.target == site, "已开工的建筑即使工人暂时离开仍可受攻击")
	enemy._physics_process(1.0)
	enemy._physics_process(1.0)
	_expect(site.is_destroyed() and site.is_queued_for_deletion(), "工地归零后销毁")
	_expect(worker.released and site.construction_workers.is_empty(), "摧毁后释放候工居民")
	_expect(task.state == GameTask.State.CANCELLED and carrier.current_task == null, "摧毁后取消在途运输任务")
	_expect(carrier.returned_cargo and carrier.carried_amount == 5 and site.get_reserved_amount(&"wood") == 0, "在途材料保留并返库，预约清零")
	_expect(not grid.occupied_cells.has(cell), "摧毁后释放占地")
	await process_frame
	_expect(not is_instance_valid(site), "工地真正从场景移除")
	world.queue_free()
	await process_frame
	print("工地受攻击测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

func _expect(value: bool, message: String) -> void:
	print("[", "通过" if value else "失败", "] ", message)
	if not value:
		failed = true
		push_error(message)

extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	var site: ConstructionSite = ConstructionSite.new()
	var data: BuildingData = BuildingData.new()
	data.max_construction_workers = 2
	site.building_data = data
	site.construction_worker_limit = 2

	var first_worker: Node = Node.new()
	var second_worker: Node = Node.new()
	var third_worker: Node = Node.new()

	_expect(site.register_construction_worker(first_worker), "第一名居民占用施工名额")
	_expect(site.register_construction_worker(second_worker), "第二名居民占用施工名额")
	site.waiting_workers.append(first_worker)
	site.delivery_workers.append(first_worker)
	site.builders.append(second_worker)
	_expect(site.get_worker_count() == 2, "搬运、等待和施工身份不会重复计数")
	_expect(not site.register_construction_worker(third_worker), "达到 2 人上限后拒绝第三名居民")
	_expect(site.get_worker_count() == 2, "拒绝后施工人数仍保持 2/2")

	site.remove_construction_worker(first_worker)
	_expect(not site.waiting_workers.has(first_worker), "释放名额时同步清理等待身份")
	_expect(not site.delivery_workers.has(first_worker), "释放名额时同步清理搬运身份")
	_expect(site.register_construction_worker(third_worker), "释放名额后新居民可以补位")
	_expect(site.get_worker_count() == 2, "补位后施工人数仍保持 2/2")

	first_worker.free()
	second_worker.free()
	third_worker.free()
	site.free()

	if _failed:
		printerr("施工人数名额测试失败")
		quit(1)
		return

	print("施工人数名额测试通过")
	quit()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[通过] ", description)
		return

	_failed = true
	printerr("[失败] ", description)

class_name ResourceManager
extends Node

signal resources_changed

var refresh_queued: bool = false


func _ready() -> void:

	add_to_group("resource_manager")

	call_deferred(
		"_connect_resource_sources"
	)
func _connect_resource_sources() -> void:

	for storage: Node in get_tree().get_nodes_in_group(
		"resource_storages"
	):

		if storage.has_signal("resource_changed"):
			storage.resource_changed.connect(
				_on_storage_resource_changed
			)


	for villager: Node in get_tree().get_nodes_in_group(
		"villagers"
	):

		register_villager(villager)


func register_villager(villager: Node) -> void:

	if not villager.has_signal("carried_resource_changed"):
		return

	if villager.carried_resource_changed.is_connected(
		_on_villager_carried_resource_changed
	):
		return

	villager.carried_resource_changed.connect(
		_on_villager_carried_resource_changed
	)


func _on_storage_resource_changed(
	_resource_id: StringName,
	_new_amount: float
) -> void:

	request_refresh()


func _on_villager_carried_resource_changed() -> void:

	request_refresh()


func request_refresh() -> void:

	if refresh_queued:
		return

	refresh_queued = true
	call_deferred("_emit_resources_changed")


func _emit_resources_changed() -> void:

	refresh_queued = false
	resources_changed.emit()

# ============================================================
# 获取某种资源的全局总量
# ============================================================

func get_total(resource_type: ResourceType.Type) -> float:

	var total: float = 0.0

	total += get_storage_total(resource_type)
	total += get_carried_total(resource_type)

	return total


# ============================================================
# 所有 ResourceStorage 中的资源
# ============================================================

func get_storage_total(resource_type: ResourceType.Type) -> float:

	var total: float = 0.0

	var storages: Array[Node] = get_tree().get_nodes_in_group(
		"resource_storages"
	)

	for storage: Node in storages:

		if not storage.has_method("get_amount"):
			continue

		total += float(
			storage.get_amount(resource_type)
		)

	return total


# ============================================================
# 所有居民正在携带的资源
# ============================================================

func get_carried_total(resource_type: ResourceType.Type) -> float:

	var total: float = 0.0

	var villagers: Array[Node] = get_tree().get_nodes_in_group(
		"villagers"
	)

	for villager: Node in villagers:

		# 没有携带资源接口则跳过
		if not villager.has_method("get_carried_amount"):
			continue

		if not villager.has_method("get_carried_resource_type"):
			continue


		var carried_type: ResourceType.Type = (
			villager.get_carried_resource_type()
		)

		if carried_type != resource_type:
			continue


		total += float(
			villager.get_carried_amount()
		)

	return total


# ============================================================
# 获取所有库存节点
#
# 以后 ResourceDetailPanel 可以直接使用。
# ============================================================

func get_storages() -> Array[Node]:

	return get_tree().get_nodes_in_group(
		"resource_storages"
	)

class_name ResourceDatabase
extends Resource

@export var resources: Array[ResourceData] = []

var _resources_by_id: Dictionary[StringName, ResourceData] = {}
var _index_ready: bool = false


## 重建资源索引。存在空资源、空 ID 或重复 ID 时返回 false。
func rebuild_index() -> bool:
	_resources_by_id.clear()
	var is_valid: bool = true

	for resource_data: ResourceData in resources:
		if resource_data == null:
			push_warning("ResourceDatabase：发现空资源定义")
			is_valid = false
			continue

		if resource_data.id == &"":
			push_warning("ResourceDatabase：资源 ID 不能为空")
			is_valid = false
			continue

		if _resources_by_id.has(resource_data.id):
			push_warning("ResourceDatabase：资源 ID 重复：%s" % resource_data.id)
			is_valid = false
			continue

		_resources_by_id[resource_data.id] = resource_data

	_index_ready = true
	return is_valid


## 注册一个资源定义。无效或重复 ID 不会加入数据库。
func register_resource(resource_data: ResourceData) -> bool:
	if resource_data == null:
		push_warning("ResourceDatabase：不能注册空资源定义")
		return false

	if resource_data.id == &"":
		push_warning("ResourceDatabase：不能注册空资源 ID")
		return false

	_ensure_index()

	if _resources_by_id.has(resource_data.id):
		push_warning("ResourceDatabase：资源 ID 已存在：%s" % resource_data.id)
		return false

	resources.append(resource_data)
	_resources_by_id[resource_data.id] = resource_data
	return true


## 按稳定 ID 查询资源定义。无效或不存在的 ID 返回 null。
func get_resource_data(resource_id: StringName) -> ResourceData:
	if resource_id == &"":
		push_warning("ResourceDatabase：查询的资源 ID 不能为空")
		return null

	_ensure_index()

	if not _resources_by_id.has(resource_id):
		push_warning("ResourceDatabase：找不到资源 ID：%s" % resource_id)
		return null

	return _resources_by_id[resource_id]


func has_resource(resource_id: StringName) -> bool:
	if resource_id == &"":
		return false

	_ensure_index()
	return _resources_by_id.has(resource_id)


func invalidate_index() -> void:
	_index_ready = false


func _ensure_index() -> void:
	if not _index_ready:
		rebuild_index()

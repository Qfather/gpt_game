@tool
class_name ResourceEditorDataService
extends RefCounted

const RESOURCE_FOLDER: String = "res://data/resources/"
const DATABASE_PATH: String = RESOURCE_FOLDER + "resource_database.tres"


static func scan_resources() -> Array[ResourceData]:
	var result: Array[ResourceData] = []
	var directory: DirAccess = DirAccess.open(RESOURCE_FOLDER)
	if directory == null:
		push_error("Resource Editor：无法打开资源目录：%s" % RESOURCE_FOLDER)
		return result

	for file_name: String in directory.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var loaded_resource: Resource = ResourceLoader.load(RESOURCE_FOLDER + file_name)
		var resource_data: ResourceData = loaded_resource as ResourceData
		if resource_data != null:
			result.append(resource_data)

	result.sort_custom(_sort_resource_by_id)
	return result


static func normalize_id(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_")


static func is_valid_id(value: String) -> bool:
	if value.is_empty():
		return false

	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if not is_lower and not is_digit and not is_underscore:
			return false

	return true


static func resource_id_exists(
	resource_id: StringName,
	resources: Array[ResourceData]
) -> bool:
	for resource_data: ResourceData in resources:
		if resource_data != null and resource_data.id == resource_id:
			return true
	return false


static func register_in_database(resource_data: ResourceData) -> Error:
	var loaded_resource: Resource = ResourceLoader.load(
		DATABASE_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	var database: ResourceDatabase = loaded_resource as ResourceDatabase
	if database == null:
		return ERR_FILE_CORRUPT

	if not database.register_resource(resource_data):
		return ERR_ALREADY_EXISTS

	return ResourceSaver.save(database, DATABASE_PATH)


static func find_database_references(resource_data: ResourceData) -> PackedStringArray:
	var references: PackedStringArray = []
	if resource_data == null:
		return references

	var loaded_resource: Resource = ResourceLoader.load(
		DATABASE_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	var database: ResourceDatabase = loaded_resource as ResourceDatabase
	if database == null:
		return references

	for registered_data: ResourceData in database.resources:
		if registered_data == null:
			continue
		if (
			registered_data.resource_path == resource_data.resource_path
			or registered_data.id == resource_data.id
		):
			references.append(DATABASE_PATH)
			break

	return references


static func _sort_resource_by_id(a: ResourceData, b: ResourceData) -> bool:
	return str(a.id).naturalnocasecmp_to(str(b.id)) < 0

@tool
class_name RaidGroupDatabase
extends Resource

@export var groups: Array[RaidGroupData] = []

func get_group(group_id: StringName) -> RaidGroupData:
	for group: RaidGroupData in groups:
		if group != null and group.id == group_id:
			return group
	return null

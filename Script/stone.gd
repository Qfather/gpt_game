extends ResourceBase
func _ready():

	resource_type = ResourceType.STONE
	# 自动加入通用资源组
	add_to_group("resources")
	super._ready()

extends ResourceBase


func _ready():

	# 指定资源类型
	resource_type = ResourceType.WOOD

	# 自动加入通用资源组
	add_to_group("resources")

	# 执行父类初始化
	super._ready()


# 兼容旧的砍树接口
func chop(amount: int) -> int:
	return gather(amount)

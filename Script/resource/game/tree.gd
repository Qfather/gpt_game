extends ResourceBase


func _ready():

	resource_id = &"wood"

	# 自动加入通用资源组
	add_to_group("resources")

	# 执行父类初始化
	super._ready()


# 兼容旧的砍树接口
func chop(amount: int) -> int:
	return gather(amount)

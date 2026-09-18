extends Node3D


signal wood_changed(new_amount: int)


# 据点储存的木材
var wood: int = 0


# 无业居民待命范围
@export var idle_radius: float = 5.0


func deposit_wood(amount: int):
	wood += amount

	print(
		"🏠 据点收到木材：",
		amount,
		" 当前总木材：",
		wood
	)

	wood_changed.emit(wood)

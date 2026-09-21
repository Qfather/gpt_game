class_name UnitBase
extends CharacterBody3D

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float, source: Node)
signal died(source: Node)

# ============================================================
# 基础属性
# ============================================================

@export_category("生命")

@export var base_max_health: float = 100.0
@export var base_health_regen: float = 1.0

var health: float = 100.0

@onready var health_component: Node = get_node_or_null("HealthComponent")


@export_category("移动 / 生存")

# 基础移动速度
@export var base_move_speed: float = 3.0

@export_category("工作")

@export var base_work_speed: float = 1.0
@export var base_gather_speed: float = 1.0


@export_category("战斗")

@export var base_attack_damage: float = 10.0
@export var base_attack_speed: float = 1.0


# ============================================================
# Trait
# ============================================================

@export_category("Trait 标签")

@export var traits: Array[UnitTrait] = []


# ============================================================
# 初始化
# ============================================================
func _ready():
	if health_component != null:
		health_component.connect(
		"health_changed",
		_on_health_component_changed
	)
		health_component.connect("damaged", _on_health_component_damaged)
		health_component.connect("died", _on_health_component_died)
		health_component.call("setup", get_max_health())
		health = float(health_component.get("current_health"))
		health_changed.emit(health, get_max_health())
		return

	health = get_max_health()
	

# ============================================================
# 基础属性读取
# ============================================================

func get_base_stat(stat: StatModifier.StatType) -> float:

	match stat:

		StatModifier.StatType.MAX_HEALTH:
			return base_max_health

		StatModifier.StatType.HEALTH_REGEN:
			return base_health_regen

		StatModifier.StatType.MOVE_SPEED:
			return base_move_speed

		StatModifier.StatType.WORK_SPEED:
			return base_work_speed

		StatModifier.StatType.GATHER_SPEED:
			return base_gather_speed

		StatModifier.StatType.ATTACK_DAMAGE:
			return base_attack_damage

		StatModifier.StatType.ATTACK_SPEED:
			return base_attack_speed

	return 0.0


# ============================================================
# 最终属性
# ============================================================
func get_stat(stat: StatModifier.StatType) -> float:

	var base_value = get_base_stat(stat)

	# 固定值修改总和
	var add_total: float = 0.0

	# 百分比修改总和
	var percent_total: float = 0.0


	# ========================================================
	# 遍历单位拥有的所有 Trait
	# ========================================================

	for unit_trait in traits:

		if unit_trait == null:
			continue

		var level_data = unit_trait.get_level_data()

		if level_data == null:
			continue


		# ====================================================
		# 遍历当前 Trait 等级的所有属性效果
		# ====================================================

		for modifier in level_data.modifiers:

			if modifier == null:
				continue

			# 不是当前正在计算的属性
			if modifier.stat != stat:
				continue


			match modifier.modifier_type:

				StatModifier.ModifierType.ADD:
					add_total += modifier.value

				StatModifier.ModifierType.PERCENT:
					percent_total += modifier.value


	# ========================================================
	# 最终属性
	# ========================================================

	var result = (
		base_value + add_total
	)

	result *= (
		1.0 + percent_total / 100.0
	)

	return result


# ============================================================
# 常用属性快捷接口
# ============================================================

func get_max_health() -> float:
	return get_stat(StatModifier.StatType.MAX_HEALTH)


func get_health_regen() -> float:
	return get_stat(StatModifier.StatType.HEALTH_REGEN)


func get_move_speed() -> float:
	return get_stat(StatModifier.StatType.MOVE_SPEED)


func get_work_speed() -> float:
	return get_stat(StatModifier.StatType.WORK_SPEED)


func get_gather_speed() -> float:
	return get_stat(StatModifier.StatType.GATHER_SPEED)


func get_attack_damage() -> float:
	return get_stat(StatModifier.StatType.ATTACK_DAMAGE)


func get_attack_speed() -> float:
	return get_stat(StatModifier.StatType.ATTACK_SPEED)


# ============================================================
# 当前生命
# ============================================================

func get_health() -> float:
	return health


func get_faction() -> int:
	return 0


func take_damage(amount: float, source: Node = null) -> float:
	if health_component != null:
		return float(health_component.call("take_damage", amount, source))

	var actual_damage: float = minf(maxf(amount, 0.0), health)
	health = maxf(health - actual_damage, 0.0)
	health_changed.emit(health, get_max_health())
	if health <= 0.0:
		died.emit(source)
	return actual_damage


func is_dead() -> bool:
	if health_component != null:
		return bool(health_component.call("is_dead"))
	return health <= 0.0


func _on_health_component_changed(
	next_health: float,
	next_max_health: float
) -> void:
	health = next_health
	health_changed.emit(next_health, next_max_health)


func _on_health_component_damaged(amount: float, source: Node) -> void:
	damaged.emit(amount, source)


func _on_health_component_died(source: Node) -> void:
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if has_method("_on_unit_died"):
		call("_on_unit_died", source)
	var unit_name: String = str(name)
	if has_method("get_combat_role"):
		if int(call("get_combat_role")) == 1:
			unit_name = "剑士"
	print("⚔️ 战斗：%s 生命归零，单位死亡" % unit_name)
	died.emit(source)
	var death_timer: SceneTreeTimer = get_tree().create_timer(0.35)
	death_timer.timeout.connect(_finish_death_cleanup)


func _finish_death_cleanup() -> void:
	if not is_instance_valid(self):
		return
	hide()
	queue_free()

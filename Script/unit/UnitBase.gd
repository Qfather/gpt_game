class_name UnitBase
extends CharacterBody3D


# ============================================================
# 基础属性
# ============================================================

@export_category("生命")

@export var base_max_health: float = 100.0
@export var base_health_regen: float = 1.0

var health: float = 100.0


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

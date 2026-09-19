class_name StatModifier
extends Resource


# ============================================================
# 可以被修改的属性
# ============================================================

enum StatType {

	# ---------- 单位属性 ----------

	MAX_HEALTH,          # 最大生命
	HEALTH_REGEN,        # 生命恢复速度
	MOVE_SPEED,          # 移动速度

	# ---------- 生存 / 作息 ----------

	FOOD_CONSUMPTION,    # 每次吃饭消耗的食物
	WORK_DURATION,       # 连续工作多久后需要回据点
	REST_DURATION,       # 每次需要休息多久

	# ---------- 工作属性 ----------

	WORK_SPEED,          # 通用工作效率
	GATHER_SPEED,        # 采集速度

	# ---------- 战斗属性 ----------

	ATTACK_DAMAGE,       # 攻击力
	ATTACK_SPEED         # 攻击速度
}


# ============================================================
# 修改方式
# ============================================================

enum ModifierType {

	# 直接加减
	# 例如：
	# 最大生命 +20
	# 食物消耗 +3
	ADD,

	# 百分比修改
	# 例如：
	# 移动速度 +10%
	# 工作速度 -15%
	PERCENT
}


# ============================================================
# 修改的数据
# ============================================================

@export var stat: StatType = StatType.MOVE_SPEED

@export var modifier_type: ModifierType = ModifierType.PERCENT

@export var value: float = 0.0

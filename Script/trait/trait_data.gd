class_name TraitData
extends Resource


# ============================================================
# 标签品级
# ============================================================

enum TraitRarity {
	COMMON,			# 普通
	UNCOMMON,		# 优良
	RARE,			# 稀有
	EPIC,			# 史诗
	LEGENDARY		# 传奇
}


# ============================================================
# 标签性质
# ============================================================

enum TraitType {
	POSITIVE,		# 正面
	NEGATIVE,		# 负面
	MIXED			# 混合
}


# ============================================================
# 标签分类
# ============================================================

enum TraitCategory {
	GENERAL,		# 通用
	SWORDSMAN,		# 剑士
	ARCHER			# 弓手
}


# ============================================================
# 基础信息
# ============================================================

@export_group("基础信息")

## 标签在游戏中显示的名称
@export var trait_name: String = "未命名标签"

## 标签详细说明
@export_multiline var description: String = ""

## 标签图标，所有等级共用同一个图标
@export var icon: Texture2D


# ============================================================
# 标签属性
# ============================================================

@export_group("标签属性")

## 标签品级：普通 / 优良 / 稀有 / 史诗 / 传奇
@export var rarity: TraitRarity = TraitRarity.COMMON

## 标签性质：正面 / 负面 / 混合
@export var trait_type: TraitType = TraitType.POSITIVE

## 标签所属分类
@export var category: TraitCategory = TraitCategory.GENERAL


# ============================================================
# 随机生成
# ============================================================

@export_group("随机生成")

## 随机抽取权重。
## 数值越高越容易被抽中。
## 例如权重10的标签，大约是权重5标签的2倍。
@export_range(0.0, 1000.0, 0.1)
var weight: float = 10.0


# ============================================================
# 等级数据
# ============================================================

@export_group("等级数据")

## 标签各等级对应的数据
@export var levels: Array[TraitLevelData] = []


# ============================================================
# 根据等级获取数据
# ============================================================

func get_level_data(target_level: int) -> TraitLevelData:

	for level_data in levels:

		if level_data == null:
			continue

		if level_data.level == target_level:
			return level_data

	return null

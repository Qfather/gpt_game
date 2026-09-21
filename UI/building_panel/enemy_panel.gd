class_name EnemyPanel
extends BuildingPanelBase


@onready var enemy_type_label: Label = %EnemyTypeLabel
@onready var health_label: Label = %HealthLabel
@onready var damage_label: Label = %DamageLabel
@onready var movement_label: Label = %MovementLabel
@onready var combat_range_label: Label = %CombatRangeLabel
@onready var detection_label: Label = %DetectionLabel


func _ready() -> void:
	super._ready()


func refresh() -> void:
	var enemy: EnemyBase = current_building as EnemyBase
	if not is_instance_valid(enemy):
		close_panel_immediately()
		return

	building_name.text = enemy.get_display_name()
	enemy_type_label.text = "敌人 ID：%s" % str(enemy.get_enemy_id())
	health_label.text = "生命：%.0f / %.0f" % [
		enemy.current_health,
		enemy.max_health,
	]
	damage_label.text = "伤害：%.1f" % enemy.damage
	movement_label.text = "移动速度：%.1f" % enemy.move_speed
	combat_range_label.text = "攻击范围：%.1f　攻击间隔：%.1f 秒" % [
		enemy.attack_range,
		enemy.attack_interval,
	]
	detection_label.text = "检测范围：%.1f" % enemy.detection_range

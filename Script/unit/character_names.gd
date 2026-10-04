extends RefCounted

const HUMAN_POOL = preload("res://data/names/HumanNames.tres")
const ENEMY_POOL = preload("res://data/names/EnemyNames.tres")
const BOSS_POOL = preload("res://data/names/BossNames.tres")

static func assign(unit: Node, pool: Resource, fixed_name: String = "") -> String:
	var scope: Node = unit.get_tree().current_scene
	if scope == null: scope = unit.get_tree().root
	if not scope.has_meta("character_name_rng"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		scope.set_meta("character_name_rng", rng)
		scope.set_meta("used_character_names", {})
	var used: Dictionary = scope.get_meta("used_character_names")
	var result: String = fixed_name.strip_edges()
	if result.is_empty(): result = pool.generate(scope.get_meta("character_name_rng"), used)
	used[result] = true
	return result

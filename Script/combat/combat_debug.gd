class_name CombatDebug
extends RefCounted


static var enabled: bool = true
static var show_aggro_ranges: bool = true
static var print_combat_logs: bool = true


static func set_enabled(next_enabled: bool) -> void:
	enabled = next_enabled


static func should_show_aggro_ranges() -> bool:
	return enabled and show_aggro_ranges

class_name EncounterDirector
extends Node

@export var level_flow: LevelFlowData
var elapsed_time: float = 0.0
var initialized: bool = false

func _ready() -> void:
	add_to_group("encounter_director")
	_prepare_events()
	var rift_manager: RiftManager = get_tree().get_first_node_in_group("rift_manager") as RiftManager
	if rift_manager != null and not rift_manager.rift_event_completed.is_connected(_on_rift_event_completed):
		rift_manager.rift_event_completed.connect(_on_rift_event_completed)

func _process(delta: float) -> void:
	if level_flow == null:
		return
	elapsed_time += maxf(delta, 0.0)
	var raid_manager: RaidSpawnManager = get_tree().get_first_node_in_group("raid_spawn_manager") as RaidSpawnManager
	var rift_manager: RiftManager = get_tree().get_first_node_in_group("rift_manager") as RiftManager
	for event: LevelEventEntry in level_flow.events:
		if event == null or not event.should_trigger(elapsed_time):
			continue
		var group: RaidGroupData = event.get_monster_group()
		if group.group_type == RaidGroupData.GroupType.RIFT:
			if rift_manager != null and rift_manager.spawn_rift(event):
				event.mark_triggered(elapsed_time)
				print("🌀 主线裂缝事件触发：", group.display_name)
		elif raid_manager != null and raid_manager.spawn_monster_group(group, Vector3.INF, event.random_total_count):
			event.mark_triggered(elapsed_time)
			print("🟠 支线袭扰事件触发：", group.display_name)

func _prepare_events() -> void:
	if level_flow == null or initialized:
		return
	for event: LevelEventEntry in level_flow.events:
		if event != null:
			if event.monster_database == null:
				event.monster_database = level_flow.monster_database
			event.prepare(0.0)
	initialized = true


func _on_rift_event_completed(event: LevelEventEntry) -> void:
	if level_flow == null or event != level_flow.get_final_rift_boss_event():
		return
	var state: GameState = get_tree().get_first_node_in_group("game_state") as GameState
	if state == null or state.state != GameState.State.PLAYING:
		return
	state.set_state(GameState.State.VICTORY)
	get_tree().paused = true
	var scene: Node = get_tree().current_scene
	var hud: GameHUD = scene.get_node_or_null("UI/HUD") as GameHUD if scene != null else null
	if hud != null:
		hud.show_victory_screen()
	print("🏆 关底裂缝BOSS已击败，关卡胜利")

func get_next_raid_status() -> Dictionary:
	var result := {"active": false, "display_name": "暂无袭扰", "remaining": 0.0}
	if level_flow == null:
		return result
	var nearest_time: float = INF
	for event: LevelEventEntry in level_flow.events:
		var group: RaidGroupData = event.get_monster_group() if event != null else null
		if event == null or group == null or group.group_type != RaidGroupData.GroupType.RAID or event.triggered or event.next_trigger_time < 0.0:
			continue
		if event.next_trigger_time < nearest_time:
			nearest_time = event.next_trigger_time
			result["active"] = true
			result["display_name"] = group.display_name
	result["remaining"] = maxf(nearest_time - elapsed_time, 0.0) if nearest_time < INF else 0.0
	return result

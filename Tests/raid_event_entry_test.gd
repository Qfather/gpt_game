extends SceneTree

const RAID_GROUP_SCRIPT = preload("res://Script/enemy/raid_group_data.gd")
const RAID_EVENT_SCRIPT = preload("res://Script/enemy/raid_event_entry.gd")

func _init() -> void:
	var group = RAID_GROUP_SCRIPT.new()
	group.id = &"slime_raid"
	group.min_count = 1
	group.max_count = 2
	var entry = RAID_EVENT_SCRIPT.new()
	entry.raid_group = group
	entry.start_time = 10.0
	entry.random_offset = 0.0
	entry.prepare(0.0)
	_expect(not entry.should_trigger(9.9), "事件未到时间不触发")
	_expect(entry.should_trigger(10.0), "事件到时间触发")
	entry.mark_triggered(10.0)
	_expect(not entry.should_trigger(10.1), "一次性事件只触发一次")
	print("RaidEventEntry 配置测试通过")
	quit()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("失败：" + message)
		quit(1)

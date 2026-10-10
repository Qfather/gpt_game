extends Node3D

const IDLE_ANIMATIONS: Array[StringName] = [&"待机", &"待机2", &"待机3"]
const STANDING_ANIMATIONS: Array[StringName] = [&"锤子站立建造", &"锤子站立建造2"]
static var looping_library: AnimationLibrary

@onready var player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
var playback: AnimationNodeStateMachinePlayback
var state_machine: AnimationNodeStateMachine
var resident: Node3D
var previous_position: Vector3
var animation_mode: StringName = &""


func _ready() -> void:
	resident = get_parent().get_parent() as UnitBase
	process_physics_priority = 1
	if looping_library == null:
		looping_library = player.get_animation_library(&"村民动画").duplicate()
		var names: Array[StringName] = IDLE_ANIMATIONS + STANDING_ANIMATIONS
		names.append_array([&"走", &"搬运重物走", &"锤子下蹲建造"])
		for animation_name: StringName in names:
			var animation: Animation = looping_library.get_animation(animation_name).duplicate()
			animation.loop_mode = Animation.LOOP_LINEAR
			looping_library.remove_animation(animation_name)
			looping_library.add_animation(animation_name, animation)
	player.remove_animation_library(&"村民动画")
	player.add_animation_library(&"村民动画", looping_library)
	# 状态机有自己的动画库引用，必须同步运行时循环副本。
	animation_tree.remove_animation_library(&"村民动画")
	animation_tree.add_animation_library(&"村民动画", looping_library)
	state_machine = animation_tree.tree_root.duplicate(true)
	animation_tree.tree_root = state_machine
	playback = animation_tree.get("parameters/playback")
	if resident == null:
		playback.start(&"idle")
		set_physics_process(false)
		return
	previous_position = resident.global_position
	_update_animation(false)


func _physics_process(delta: float) -> void:
	var displacement: Vector3 = resident.global_position - previous_position
	previous_position = resident.global_position
	displacement.y = 0.0
	_update_animation(displacement.length() > delta * 0.05)


func _update_animation(moving: bool) -> void:
	var next_mode: StringName = &"idle"
	if moving:
		next_mode = &"carry_walk" if resident.get_carried_amount() > 0.0 else &"walk"
	elif resident.state == resident.State.BUILD_ROAD:
		next_mode = &"crouch"
	elif resident.state == resident.State.DEMOLISHING and is_instance_valid(resident.demolition_target):
		next_mode = &"standing"
	elif resident.state == resident.State.BUILDING and not resident.construction_repositioning and not resident.passing_door:
		if is_instance_valid(resident.task_site) and resident.task_site is ConstructionSite:
			var site: ConstructionSite = resident.task_site
			if site.state == ConstructionSite.State.BUILDING and site.get_blocking_resource() == null:
				next_mode = &"crouch" if site.get_construction_progress_ratio() < 0.7 else &"standing"
	if next_mode == animation_mode:
		return
	animation_mode = next_mode
	var animation_name: StringName
	match animation_mode:
		&"walk": animation_name = &"走"
		&"carry_walk": animation_name = &"搬运重物走"
		&"crouch": animation_name = &"锤子下蹲建造"
		&"standing": animation_name = STANDING_ANIMATIONS.pick_random()
		_: animation_name = IDLE_ANIMATIONS.pick_random()
	var node: AnimationRootNode = state_machine.get_node(animation_mode)
	if node is AnimationNodeBlendTree:
		node.get_node("Animation").animation = "村民动画/" + animation_name
	else:
		node.animation = "村民动画/" + animation_name
	if animation_mode in [&"crouch", &"standing"]:
		animation_tree.set("parameters/" + animation_mode + "/Seek/seek_request", randf() * player.get_animation("村民动画/" + animation_name).length)
	if playback.is_playing():
		playback.travel(animation_mode)
	else:
		playback.start(animation_mode)

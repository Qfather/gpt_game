extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var holder := Node3D.new()
	world.add_child(holder)
	var visual = load("res://Scene/unit/resident_visual.tscn").instantiate()
	holder.add_child(visual)
	var tree: AnimationTree = visual.animation_tree
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeleton: Skeleton3D = visual.get_node("角色/root/GeneralSkeleton")
	var actions := {
		&"idle": [&"待机", &"待机2", &"待机3"],
		&"walk": [&"走"],
		&"carry_walk": [&"搬运重物走"],
		&"crouch": [&"锤子下蹲建造"],
		&"standing": [&"锤子站立建造", &"锤子站立建造2"],
	}
	for mode: StringName in actions:
		var node = visual.state_machine.get_node(mode)
		var animation_node = node.get_node("Animation") if node is AnimationNodeBlendTree else node
		for action: StringName in actions[mode]:
			animation_node.animation = "村民动画/" + action
			var animation: Animation = tree.get_animation(animation_node.animation)
			assert(animation == visual.player.get_animation(animation_node.animation))
			assert(animation.loop_mode == Animation.LOOP_LINEAR)
			visual.playback.start(mode)
			if node is AnimationNodeBlendTree:
				tree.set("parameters/" + mode + "/Seek/seek_request", animation.length * 0.4)
			var wraps := 0
			var late_pose_changes := 0
			var previous_time := 0.0
			var previous_pose := skeleton.get_bone_pose_rotation(10)
			for frame in range(ceili(animation.length * 4.0 * 60.0)):
				tree.advance(1.0 / 60.0)
				var time: float = visual.playback.get_current_play_position()
				var pose := skeleton.get_bone_pose_rotation(10)
				if time < previous_time: wraps += 1
				if frame > animation.length * 2.0 * 60.0 and not pose.is_equal_approx(previous_pose):
					late_pose_changes += 1
				previous_time = time
				previous_pose = pose
			assert(wraps >= 3, "%s未持续循环" % action)
			assert(late_pose_changes > 10, "%s两周期后骨骼停住" % action)
			print("[通过] ", action, "：循环回绕", wraps, "次，后续骨骼变化", late_pose_changes, "帧")
	world.queue_free()
	await process_frame
	quit(0)

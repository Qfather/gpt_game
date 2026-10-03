extends SceneTree

class Target extends Node3D:
	var received_damage: float = 0.0
	var hit_count: int = 0
	var dead: bool = false
	func take_damage(amount: float, _source: Node) -> float:
		received_damage += amount
		hit_count += 1
		return amount
	func is_dead() -> bool:
		return dead

var failed := false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, text: String) -> void:
	print("[", "通过" if value else "失败", "] ", text)
	if not value:
		failed = true
		push_error(text)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var shooter := Node3D.new()
	world.add_child(shooter)
	var target := Target.new()
	world.add_child(target)
	target.position = Vector3(8,0,0)
	var arrow_script: Script = load("res://Script/combat/arrow.gd")
	var arrow: Node3D = arrow_script.launch(shooter, target, Vector3(0,1,0), 8.0, 18.0)
	arrow.set_physics_process(false)
	var duration: float = arrow.flight_duration
	arrow._physics_process(duration * 0.5)
	var linear_middle: Vector3 = Vector3(0,1,0).lerp(target.position + Vector3.UP * 0.6, 0.5)
	_expect(arrow.position.y > linear_middle.y + 0.4, "箭矢中段明显高于直线路径")
	_expect(is_equal_approx(arrow.position.y, linear_middle.y + arrow.GRAVITY * duration * duration / 8.0), "静止目标飞行位置符合抛物线方程")
	_expect(target.received_damage == 0.0, "飞行中尚未造成伤害")
	var before: Vector3 = arrow.position
	arrow._physics_process(duration * 0.1)
	var direction: Vector3 = arrow.position - before
	_expect((-arrow.global_basis.z).dot(direction.normalized()) > 0.999, "箭头沿实际飞行切线朝向")
	arrow._physics_process(duration * 0.4 + 0.001)
	_expect(target.hit_count == 1 and target.received_damage == 8.0 and arrow.is_queued_for_deletion(), "落到目标后只造成一次原有伤害并删除")
	await process_frame
	target.received_damage = 0.0
	target.hit_count = 0
	arrow = arrow_script.launch(shooter, target, Vector3(0,4,0), 4.0, 18.0)
	arrow.set_physics_process(false)
	arrow._physics_process(arrow.flight_duration * 0.25)
	target.position += Vector3(2,0,1)
	arrow._physics_process(arrow.flight_duration)
	_expect(target.hit_count == 1 and target.received_damage == 4.0 and arrow.position.distance_to(target.position + Vector3.UP * 0.6) < 0.001, "塔顶射击仍能命中移动目标且保留伤害")
	await process_frame
	arrow = arrow_script.launch(shooter, target, Vector3(0,1,0), 1.0, 18.0)
	arrow.set_physics_process(false)
	target.dead = true
	arrow._physics_process(0.1)
	_expect(arrow.is_queued_for_deletion() and target.hit_count == 1, "目标已死时箭矢清理且不重复伤害")
	await process_frame
	target.dead = false
	target.position = Vector3.ZERO
	arrow = arrow_script.launch(shooter, target, Vector3(0,4,0), 3.0, 18.0)
	arrow.set_physics_process(false)
	arrow._physics_process(arrow.flight_duration * 0.5)
	_expect((-arrow.global_basis.z).dot(Vector3.DOWN) > 0.999, "塔顶正下方目标也能正确转动箭头")
	arrow._physics_process(arrow.flight_duration)
	await process_frame
	if DisplayServer.get_name() != "headless":
		target.dead = false
		target.position = Vector3(8,0,0)
		var environment := WorldEnvironment.new()
		var settings := Environment.new()
		settings.background_mode = Environment.BG_COLOR
		settings.background_color = Color(0.08,0.10,0.14)
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		settings.ambient_light_color = Color.WHITE
		settings.ambient_light_energy = 1.0
		environment.environment = settings
		world.add_child(environment)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 11.0
		camera.position = Vector3(4,3,12)
		camera.look_at(Vector3(4,0.8,0))
		camera.current = true
		arrow = arrow_script.launch(shooter, target, Vector3(0,1,0), 8.0, 18.0)
		arrow.set_physics_process(false)
		for i in range(10):
			arrow._physics_process(arrow.flight_duration / 11.0)
			var sample: Node3D = load("res://Scene/unit/arrow.tscn").instantiate()
			world.add_child(sample)
			sample.set_physics_process(false)
			sample.global_transform = arrow.global_transform
		var canvas := CanvasLayer.new()
		world.add_child(canvas)
		var label := Label.new()
		label.position = Vector2(30,30)
		label.text = "箭矢抛物线轨迹（沿飞行过程采样，箭头跟随飞行方向）"
		label.add_theme_font_size_override("font_size", 24)
		canvas.add_child(label)
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/arrow_parabola_preview.png")
	world.queue_free()
	await process_frame
	print("箭矢抛物线与命中测试", "失败" if failed else "通过")
	quit(1 if failed else 0)

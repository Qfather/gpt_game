extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var factory := FlowNodesFactory.new()
	factory.registerNodeType("torus_volume_sampler", "torus_volume_sampler.gd")
	assert(factory.node_types.has("torus_volume_sampler"))
	assert(factory.node_types["torus_volume_sampler"].title == "环体采样")

	var anchor_data := FlowData.Data.new()
	anchor_data.addCommonStreams(2)
	var positions: PackedVector3Array = anchor_data.getVector3Container(FlowData.AttrPosition)
	var rotations: PackedVector3Array = anchor_data.getVector3Container(FlowData.AttrRotation)
	positions[0] = Vector3(3.0, 2.0, -4.0)
	positions[1] = Vector3(-6.0, 1.0, 5.0)
	rotations[1] = Vector3(0.0, 90.0, 0.0)

	var sampler: FlowNodeBase = factory.createNewNode("torus_volume_sampler", "torus_test")
	sampler.random_seed = 17
	sampler.major_radius = 5.0
	sampler.minor_radius = 1.5
	sampler.num_points = 128
	var ctx := FlowData.EvaluationContext.new()
	sampler.preExecute(ctx)
	ctx.setNodeInputs(sampler, [anchor_data])
	sampler.execute(ctx)

	var output: FlowData.Data = ctx.getOutput(sampler, 0, 0)
	assert(output.size() == 256)
	var output_positions: PackedVector3Array = output.getVector3Container(FlowData.AttrPosition)
	var output_rotations: PackedVector3Array = output.getVector3Container(FlowData.AttrRotation)
	var output_sizes: PackedVector3Array = output.getVector3Container(FlowData.AttrSize)
	for idx in range(output.size()):
		var anchor_idx: int = int(idx / sampler.num_points)
		var local_position := FlowData.eulerToBasis(rotations[anchor_idx]).inverse() * (output_positions[idx] - positions[anchor_idx])
		var radial_distance := Vector2(local_position.x, local_position.z).length()
		var tube_distance := Vector2(radial_distance - sampler.major_radius, local_position.y).length()
		assert(tube_distance <= sampler.minor_radius + 0.0001)
		var ring_angle := atan2(local_position.z, local_position.x)
		var expected_tangent := FlowData.eulerToBasis(rotations[anchor_idx]) * Vector3(-sin(ring_angle), 0.0, cos(ring_angle))
		var actual_tangent := FlowData.eulerToBasis(output_rotations[idx]) * Vector3.BACK
		assert(actual_tangent.dot(expected_tangent) > 0.999)
		assert(output_sizes[idx] == sampler.point_size)

	sampler.tangent_rotation_offset = Vector3(15.0, 20.0, 30.0)
	sampler.preExecute(ctx)
	ctx.setNodeInputs(sampler, [anchor_data])
	sampler.execute(ctx)
	output = ctx.getOutput(sampler, 0, 0)
	output_rotations = output.getVector3Container(FlowData.AttrRotation)
	var sample_local_position := FlowData.eulerToBasis(rotations[0]).inverse() * (output_positions[0] - positions[0])
	var sample_ring_angle := atan2(sample_local_position.z, sample_local_position.x)
	var base_rotation := FlowData.eulerToBasis(rotations[0]) * Basis(Vector3.UP, -sample_ring_angle)
	var expected_rotation := base_rotation * FlowData.eulerToBasis(sampler.tangent_rotation_offset)
	var actual_rotation := FlowData.eulerToBasis(output_rotations[0])
	assert(actual_rotation.x.dot(expected_rotation.x) > 0.999)
	assert(actual_rotation.y.dot(expected_rotation.y) > 0.999)
	assert(actual_rotation.z.dot(expected_rotation.z) > 0.999)

	sampler.tangent_rotation_enabled = false
	sampler.tangent_rotation_offset = Vector3.ZERO
	sampler.preExecute(ctx)
	ctx.setNodeInputs(sampler, [anchor_data])
	sampler.execute(ctx)
	output = ctx.getOutput(sampler, 0, 0)
	output_rotations = output.getVector3Container(FlowData.AttrRotation)
	assert(output_rotations[0].is_equal_approx(rotations[0]))

	print("环体采样测试通过：节点注册、采样数量、体积边界、切向旋转开关与 XYZ 偏移")
	quit()

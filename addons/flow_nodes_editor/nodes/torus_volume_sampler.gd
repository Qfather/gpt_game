@tool
extends FlowNodeBase

@export var major_radius: float = 10.0
@export var minor_radius: float = 1.0
@export var num_points: int = 200
@export var point_size: Vector3 = Vector3.ONE
@export var tangent_rotation_enabled: bool = true
@export var tangent_rotation_offset: Vector3 = Vector3.ZERO

func _init():
	meta_node = {
		"title": "Torus Volume Sampler",
		"category": "Sampler",
		"ins": [{"label": "Anchors"}],
		"outs": [{"label": "Out"}],
		"tooltip": "Uniformly samples points inside a torus volume around each input point.",
	}

func _sample_local_point(major: float, minor: float) -> Vector3:
	if major <= 0.0 and minor <= 0.0:
		return Vector3.ZERO

	var safe_minor := maxf(minor, 0.0)
	var safe_major := maxf(maxf(major, 0.0), safe_minor)
	while true:
		var tube_radius := safe_minor * sqrt(rng.randf())
		var tube_angle := rng.randf_range(0.0, TAU)
		var ring_angle := rng.randf_range(0.0, TAU)
		var radial_distance := safe_major + tube_radius * cos(tube_angle)
		var acceptance := radial_distance / (safe_major + tube_radius)
		if rng.randf() <= acceptance:
			return Vector3(
				radial_distance * cos(ring_angle),
				tube_radius * sin(tube_angle),
				radial_distance * sin(ring_angle)
			)
	return Vector3.ZERO

func execute(ctx: FlowData.EvaluationContext) -> void:
	var in_data: FlowData.Data = getInput(ctx, 0)
	if in_data == null or in_data.size() == 0:
		setOutput(ctx, 0, FlowData.Data.new())
		return

	var transforms: FlowData.TransformsStream = in_data.getTransformsStream()
	if transforms == null:
		setError(ctx, "输入点需要包含位置、旋转和尺寸数据流")
		return

	var out_data := FlowData.Data.new()
	out_data.addCommonStreams(0)
	var positions := out_data.getVector3Container(FlowData.AttrPosition)
	var rotations := out_data.getVector3Container(FlowData.AttrRotation)
	var sizes := out_data.getVector3Container(FlowData.AttrSize)
	var samples_per_anchor := maxi(num_points, 0)
	var rotation_offset: Vector3 = tangent_rotation_offset if typeof(tangent_rotation_offset) == TYPE_VECTOR3 else Vector3.ZERO

	for anchor_idx in range(transforms.size()):
		var basis_rotation := FlowData.eulerToBasis(transforms.eulers[anchor_idx])
		for _sample_idx in range(samples_per_anchor):
			var local_position := _sample_local_point(major_radius, minor_radius)
			var point_rotation := basis_rotation
			if tangent_rotation_enabled:
				var ring_angle := atan2(local_position.z, local_position.x)
				point_rotation *= Basis(Vector3.UP, -ring_angle)
			point_rotation *= FlowData.eulerToBasis(rotation_offset)
			positions.append(transforms.positions[anchor_idx] + basis_rotation * local_position)
			rotations.append(FlowData.basisToEuler(point_rotation))
			sizes.append(point_size)

	setOutput(ctx, 0, out_data)

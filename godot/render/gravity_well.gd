class_name GravityWell
extends MeshInstance3D

const SHADER := preload("res://render/shaders/gravity_well.gdshader")
const MAX_BODIES := 24
const EXTENT_PER_DISTANCE := 3.0
const MIN_HALF_WIDTH := 1.0
const SOFTENING_RADII := 1.5
const SOFTENING_CELLS := 1.5
const DEPTH_FRACTION := 0.17
const SCALE_RING_DISTANCE := 0.4
const SCALE_RING_FRACTION := 0.8
const MIN_SCALE_FRACTION := 0.001
const POTENTIAL_UNIT := 1.0e-3
const SUBDIVISIONS := [128, 192, 256]
const RIM_SAMPLES := 16

var half_width := 1.0
var edge_potential := 0.0
var potential_scale := 1.0
var body_ids: Array[String] = []

var _material := ShaderMaterial.new()
var _plane := PlaneMesh.new()
var _positions := PackedVector4Array()
var _softening := PackedFloat32Array()


func _init() -> void:
	_plane.size = Vector2(2.0, 2.0)
	mesh = _plane
	_material.shader = SHADER
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	visible = false
	apply_quality(Quality.Preset.MEDIUM)


func apply_quality(preset: int) -> void:
	var subdivisions: int = SUBDIVISIONS[clampi(preset, 0, SUBDIVISIONS.size() - 1)]
	_plane.subdivide_width = subdivisions
	_plane.subdivide_depth = subdivisions
	_material.set_shader_parameter("line_count", float(subdivisions) / 4.0)


func subdivisions() -> int:
	return _plane.subdivide_width


func update(
	camera_relative_center: Vector3, view_distance: float, ids: Array[String], offsets: Array[Vector3], gm: PackedFloat64Array, radii: PackedFloat64Array
) -> void:
	if not visible:
		return
	half_width = maxf(view_distance * EXTENT_PER_DISTANCE, MIN_HALF_WIDTH)
	var cell := 2.0 * half_width / float(_plane.subdivide_width)
	var candidates: Array = []
	for index in ids.size():
		var offset := offsets[index]
		var soft := maxf(radii[index] * SOFTENING_RADII, cell * SOFTENING_CELLS)
		var strength := gm[index] * POTENTIAL_UNIT
		candidates.append([strength / (offset.length() + soft), ids[index], offset, strength, soft])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	candidates.resize(mini(candidates.size(), MAX_BODIES))
	body_ids.clear()
	_positions.resize(candidates.size())
	_softening.resize(candidates.size())
	for index in candidates.size():
		var candidate: Array = candidates[index]
		body_ids.append(candidate[1])
		var offset: Vector3 = candidate[2]
		_positions[index] = Vector4(offset.x, offset.y, offset.z, candidate[3])
		_softening[index] = candidate[4]
	edge_potential = INF
	for sample in RIM_SAMPLES:
		var angle := TAU * float(sample) / float(RIM_SAMPLES)
		edge_potential = minf(edge_potential, potential(Vector2(cos(angle), sin(angle)) * half_width))
	var peak := edge_potential
	for index in _positions.size():
		var body := _positions[index]
		if absf(body.x) <= half_width and absf(body.z) <= half_width:
			peak = maxf(peak, potential(Vector2(body.x, body.z)))
	var ring := minf(view_distance * SCALE_RING_DISTANCE, half_width * SCALE_RING_FRACTION)
	var ring_excess := 0.0
	for sample in RIM_SAMPLES:
		var angle := TAU * float(sample) / float(RIM_SAMPLES)
		ring_excess += maxf(potential(Vector2(cos(angle), sin(angle)) * ring) - edge_potential, 0.0)
	ring_excess /= float(RIM_SAMPLES)
	potential_scale = maxf(maxf(ring_excess, (peak - edge_potential) * MIN_SCALE_FRACTION), 1.0e-12)
	transform = Transform3D(Basis.from_scale(Vector3.ONE * half_width), camera_relative_center)
	_material.set_shader_parameter("bodies", _positions)
	_material.set_shader_parameter("softening", _softening)
	_material.set_shader_parameter("body_count", _positions.size())
	_material.set_shader_parameter("half_width", half_width)
	_material.set_shader_parameter("edge_potential", edge_potential)
	_material.set_shader_parameter("potential_scale", potential_scale)
	_material.set_shader_parameter("depth", DEPTH_FRACTION)


func potential(point: Vector2) -> float:
	var total := 0.0
	for index in _positions.size():
		var body := _positions[index]
		var dx := point.x - body.x
		var dz := point.y - body.z
		total += body.w / sqrt(dx * dx + body.y * body.y + dz * dz + _softening[index] * _softening[index])
	return total


func depth_at(point: Vector2) -> float:
	var excess := maxf(potential(point) - edge_potential, 0.0) / potential_scale
	return excess / (1.0 + excess) * DEPTH_FRACTION * half_width

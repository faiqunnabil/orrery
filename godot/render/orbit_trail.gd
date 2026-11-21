class_name OrbitTrail
extends MeshInstance3D

const EMPTY_SLOT := 9223372036854775807
const HEAD_ALPHA := 0.95
const HIGH_ECCENTRICITY := 0.5

var definition: BodyDefinition
var trail_color: Color

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _point_count := 0
var _step_seconds := 1.0
var _length_fraction := 1.0
var _shell := 1.0e9
var _slot_indices := PackedInt64Array()
var _slot_points := PackedFloat64Array()
var _scratch := PackedFloat64Array([0.0, 0.0, 0.0])


func _init(body: BodyDefinition) -> void:
	definition = body
	trail_color = body.color
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func configure(point_count: int, length_fraction: float) -> void:
	_point_count = point_count
	_length_fraction = length_fraction
	_step_seconds = definition.orbit.period_seconds() * length_fraction / float(point_count)
	_slot_indices.resize(point_count)
	_slot_indices.fill(EMPTY_SLOT)
	_slot_points.resize(point_count * 3)


func update(
	simulation_seconds: float,
	current: DVec3,
	parent_camera_position: PackedFloat64Array,
	parent: BodyDefinition,
	mapper: ScaleMapper,
	shell: float
) -> void:
	_shell = shell
	var head := floori(simulation_seconds / _step_seconds)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
	_emit(Color(trail_color, HEAD_ALPHA), current.x, current.y, current.z, parent_camera_position, parent, mapper)
	if definition.orbit.elements[OrbitModel.ECCENTRICITY] > HIGH_ECCENTRICITY:
		_emit_by_anomaly(simulation_seconds, parent_camera_position, parent, mapper)
		_mesh.surface_end()
		return
	for k in _point_count:
		var index := head - k
		var slot := posmod(index, _point_count)
		if _slot_indices[slot] != index:
			var point := definition.orbit.position_km(float(index) * _step_seconds / Astro.SECONDS_PER_CENTURY)
			_slot_points[slot * 3] = point.x
			_slot_points[slot * 3 + 1] = point.y
			_slot_points[slot * 3 + 2] = point.z
			_slot_indices[slot] = index
		var fade := HEAD_ALPHA * (1.0 - float(k) / float(_point_count))
		_emit(
			Color(trail_color, fade),
			_slot_points[slot * 3],
			_slot_points[slot * 3 + 1],
			_slot_points[slot * 3 + 2],
			parent_camera_position,
			parent,
			mapper
		)
	_mesh.surface_end()


func _emit_by_anomaly(
	simulation_seconds: float, parent_camera_position: PackedFloat64Array, parent: BodyDefinition, mapper: ScaleMapper
) -> void:
	var orbit := definition.orbit
	var eccentricity := orbit.elements[OrbitModel.ECCENTRICITY]
	var period := orbit.period_seconds()
	var span := period * _length_fraction
	var eccentric_now := Kepler.eccentric_anomaly(orbit.mean_anomaly(simulation_seconds / Astro.SECONDS_PER_CENTURY), eccentricity)
	var mean_now := eccentric_now - eccentricity * sin(eccentric_now)
	var step := TAU / float(_point_count)
	for k in range(1, _point_count + 1):
		var eccentric := eccentric_now - step * float(k)
		var age := (mean_now - (eccentric - eccentricity * sin(eccentric))) / TAU * period
		if age > span:
			break
		var point := orbit.position_km((simulation_seconds - age) / Astro.SECONDS_PER_CENTURY)
		_emit(Color(trail_color, HEAD_ALPHA * (1.0 - age / span)), point.x, point.y, point.z, parent_camera_position, parent, mapper)


func _emit(
	color: Color,
	ox: float,
	oy: float,
	oz: float,
	parent_camera_position: PackedFloat64Array,
	parent: BodyDefinition,
	mapper: ScaleMapper
) -> void:
	mapper.offset_to_render(definition, parent, ox, oy, oz, _scratch)
	var vertex := Vector3(
		parent_camera_position[0] + _scratch[0],
		parent_camera_position[1] + _scratch[1],
		parent_camera_position[2] + _scratch[2]
	)
	var distance := vertex.length()
	if distance > _shell:
		vertex *= _shell / distance
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(vertex)

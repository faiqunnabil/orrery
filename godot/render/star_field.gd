class_name StarField
extends Node3D

const DATA_PATH := "res://data/stars.json"
const SHADER := preload("res://render/shaders/star_field.gdshader")
const SPHERE_FRACTION := 0.8
const REFERENCE_HEIGHT := 720.0
const BASE_SIZE := 1.9
const SIZE_EXPONENT := 0.22
const BASE_INTENSITY := 0.17
const INTENSITY_EXPONENT := 0.5
const MAX_INTENSITY := 2.2
const WHITE_MIX := 0.35
const DEFAULT_COLOR_INDEX := 0.6
const LINE_COLOR := Color(0.22, 0.36, 0.62)
const GALACTIC_ROWS := [
	[-0.0548755604, -0.8734370902, -0.4838350155],
	[0.4941094279, -0.4448296300, 0.7469822445],
	[-0.8676661490, -0.1980763734, 0.4559837762],
]

static var _data: Dictionary = {}

var star_count := 0
var segment_count := 0

var _stars := MeshInstance3D.new()
var _lines := MeshInstance3D.new()
var _material := ShaderMaterial.new()


func _ready() -> void:
	var data := load_data()
	_material.shader = SHADER
	_stars.mesh = _build_stars(data.get("stars", []), float(data.get("magnitude_limit", 6.5)))
	_stars.material_override = _material
	_lines.mesh = _build_lines(data.get("constellations", []))
	_lines.material_override = _line_material()
	for instance in [_stars, _lines]:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	Preferences.changed.connect(_sync_preferences)
	_sync_preferences()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	scale = Vector3.ONE * camera.far * SPHERE_FRACTION
	_material.set_shader_parameter("size_scale", get_viewport().size.y / REFERENCE_HEIGHT * Quality.render_scale)


func constellations_visible() -> bool:
	return _lines.visible


static func load_data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		if file == null:
			push_error("Cannot open star catalog: %s" % DATA_PATH)
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		_data = parsed if parsed is Dictionary else {}
	return _data


static func direction(right_ascension_deg: float, declination_deg: float) -> Vector3:
	var ra := deg_to_rad(right_ascension_deg)
	var dec := deg_to_rad(declination_deg)
	var ecliptic := Astro.equatorial_to_ecliptic(cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec))
	return Vector3(ecliptic[0], ecliptic[2], -ecliptic[1])


static func render_to_galactic() -> Basis:
	var equatorial_to_render := Basis(direction(0.0, 0.0), direction(90.0, 0.0), direction(0.0, 90.0))
	var rows: Array = GALACTIC_ROWS
	var equatorial_to_galactic := Basis(
		Vector3(rows[0][0], rows[1][0], rows[2][0]),
		Vector3(rows[0][1], rows[1][1], rows[2][1]),
		Vector3(rows[0][2], rows[1][2], rows[2][2])
	)
	return equatorial_to_galactic * equatorial_to_render.transposed()


static func star_color(color_index: float) -> Color:
	var temperature := 4600.0 * (1.0 / (0.92 * color_index + 1.7) + 1.0 / (0.92 * color_index + 0.62))
	var t := temperature / 100.0
	var red := 1.0 if t <= 66.0 else clampf(1.292936 * pow(t - 60.0, -0.1332048), 0.0, 1.0)
	var green := 0.0
	if t <= 66.0:
		green = clampf(0.3900816 * log(t) - 0.6318414, 0.0, 1.0)
	else:
		green = clampf(1.1298909 * pow(t - 60.0, -0.0755148), 0.0, 1.0)
	var blue := 1.0
	if t < 66.0:
		blue = 0.0 if t <= 19.0 else clampf(0.5432068 * log(t - 10.0) - 1.1962541, 0.0, 1.0)
	var peak := maxf(red, maxf(green, blue))
	var color := Color(red / peak, green / peak, blue / peak)
	return color.lerp(Color.WHITE, WHITE_MIX)


static func star_size(magnitude: float, limit: float) -> float:
	return BASE_SIZE * pow(_flux(magnitude, limit), SIZE_EXPONENT)


static func star_intensity(magnitude: float, limit: float) -> float:
	return minf(BASE_INTENSITY * pow(_flux(magnitude, limit), INTENSITY_EXPONENT), MAX_INTENSITY)


static func _flux(magnitude: float, limit: float) -> float:
	return pow(10.0, -0.4 * (magnitude - limit))


func _build_stars(stars: Array, limit: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for star: Array in stars:
		var magnitude := float(star[2])
		vertices.append(direction(star[0], star[1]))
		colors.append(star_color(float(star[3]) if star.size() > 3 else DEFAULT_COLOR_INDEX))
		uvs.append(Vector2(star_size(magnitude, limit), star_intensity(magnitude, limit)))
	star_count = vertices.size()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	return mesh


func _build_lines(constellations: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for constellation: Dictionary in constellations:
		for line: Array in constellation["lines"]:
			for index in range(1, line.size()):
				vertices.append(direction(line[index - 1][0], line[index - 1][1]))
				vertices.append(direction(line[index][0], line[index][1]))
	segment_count = vertices.size() / 2
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


func _line_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.disable_fog = true
	material.albedo_color = LINE_COLOR
	return material


func _sync_preferences() -> void:
	_lines.visible = Preferences.constellations_visible

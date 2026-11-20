class_name BodyVisual
extends Node3D

const SURFACE_SHADER := preload("res://render/shaders/body_surface.gdshader")
const SUN_SHADER := preload("res://render/shaders/sun_surface.gdshader")
const RING_SHADER := preload("res://render/shaders/planet_ring.gdshader")
const ATMOSPHERE_SHADER := preload("res://render/shaders/atmosphere.gdshader")
const CLOUD_SHADER := preload("res://render/shaders/cloud_layer.gdshader")
const RING_SEGMENTS := 128
const CLOUD_RENDER_PRIORITY := 0
const ATMOSPHERE_RENDER_PRIORITY := 1
const LOD_PIXEL_TOLERANCE := 0.5
const MIN_SEGMENTS := 16

static var _sphere_cache: Dictionary = {}

var _mesh_instance := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _sphere: SphereMesh
var _max_segments := 0
var _segments := 0
var _shells: Array[MeshInstance3D] = []
var _lit_materials: Array[ShaderMaterial] = []
var _detail_materials: Array[ShaderMaterial] = []
var _clouds: MeshInstance3D
var _full_effects := true
var _eclipse_materials: Array[ShaderMaterial] = []
var _eclipse_count := 0
var _texture_bindings: Array[Array] = []


func _init(texture_path: String, night_texture_path: String, emissive: bool, tint: Color = Color.WHITE) -> void:
	_material.shader = SUN_SHADER if emissive else SURFACE_SHADER
	_bind_texture(_material, "albedo_texture", texture_path)
	_material.set_shader_parameter("tint", tint)
	if night_texture_path != "":
		_material.set_shader_parameter("has_night_texture", true)
		_bind_texture(_material, "night_texture", night_texture_path)
	if not emissive:
		_lit_materials.append(_material)
		_detail_materials.append(_material)
		_eclipse_materials.append(_material)
	_mesh_instance.material_override = _material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)


func set_mesh_detail(radial_segments: int) -> void:
	_max_segments = radial_segments
	_use_segments(radial_segments)


func segments() -> int:
	return _segments


func update_level_of_detail(pixel_radius: float) -> void:
	var required := PI * sqrt(maxf(pixel_radius, 0.0) / (2.0 * LOD_PIXEL_TOLERANCE))
	var chosen := _max_segments
	while chosen / 2 >= MIN_SEGMENTS and float(chosen / 2) >= required:
		chosen /= 2
	_use_segments(chosen)


static func pixels_per_radian(viewport: Viewport) -> float:
	var camera := viewport.get_camera_3d()
	if camera == null:
		return 0.0
	var height := float(viewport.get_visible_rect().size.y)
	if viewport is Window:
		height = float((viewport as Window).size.y)
	return height * viewport.scaling_3d_scale / (2.0 * tan(deg_to_rad(camera.fov) * 0.5))


static func pixel_radius(camera_relative_position: Vector3, radius: float, pixels_per_radian: float) -> float:
	var distance := camera_relative_position.length()
	if distance <= radius:
		return INF
	return asin(radius / distance) * pixels_per_radian


func _use_segments(radial_segments: int) -> void:
	if radial_segments == _segments:
		return
	_segments = radial_segments
	_sphere = _cached_sphere(radial_segments)
	_mesh_instance.mesh = _sphere
	for shell in _shells:
		shell.mesh = _sphere


static func _cached_sphere(radial_segments: int) -> SphereMesh:
	if not _sphere_cache.has(radial_segments):
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = radial_segments
		sphere.rings = radial_segments / 2
		_sphere_cache[radial_segments] = sphere
	return _sphere_cache[radial_segments]


func set_effects_detail(full: bool) -> void:
	_full_effects = full
	for material in _detail_materials:
		material.set_shader_parameter("full_detail", full)
	if _clouds != null:
		_clouds.visible = full
	if not full:
		clear_eclipse()


func uses_eclipses() -> bool:
	return _full_effects and not _eclipse_materials.is_empty()


func set_eclipse(occluders: PackedVector4Array, glows: PackedFloat32Array, sun_angular_radius: float) -> void:
	var count := occluders.size()
	if count == 0 and _eclipse_count == 0:
		return
	_eclipse_count = count
	var padded := occluders.duplicate()
	var padded_glows := glows.duplicate()
	padded.resize(EclipseFinder.MAX_OCCLUDERS)
	padded_glows.resize(EclipseFinder.MAX_OCCLUDERS)
	for material in _eclipse_materials:
		material.set_shader_parameter("eclipse_count", count)
		if count > 0:
			material.set_shader_parameter("eclipse_occluders", padded)
			material.set_shader_parameter("eclipse_glow", padded_glows)
			material.set_shader_parameter("sun_angular_radius", sun_angular_radius)


func clear_eclipse() -> void:
	set_eclipse(PackedVector4Array(), PackedFloat32Array(), 0.0)


func refresh_textures() -> void:
	for binding in _texture_bindings:
		var material: ShaderMaterial = binding[0]
		material.set_shader_parameter(binding[1], TextureTiers.body_texture(binding[2]))


func _bind_texture(material: ShaderMaterial, parameter: String, path: String) -> void:
	_texture_bindings.append([material, parameter, path])
	material.set_shader_parameter(parameter, TextureTiers.body_texture(path))


func set_tint(tint: Color) -> void:
	_material.set_shader_parameter("tint", tint)


func place(
	camera_relative_position: Vector3,
	radius: float,
	orientation: Basis,
	sun_direction: Vector3,
	lit: bool = true
) -> void:
	transform = Transform3D(orientation.scaled(Vector3.ONE * radius), camera_relative_position)
	for material in _lit_materials:
		material.set_shader_parameter("sun_direction", sun_direction)
		material.set_shader_parameter("has_sun", lit)


func add_rings(inner_ratio: float, outer_ratio: float, texture_path: String) -> void:
	var ring_texture := load(texture_path)
	var material := ShaderMaterial.new()
	material.shader = RING_SHADER
	material.set_shader_parameter("ring_texture", ring_texture)
	material.set_shader_parameter("full_detail", _full_effects)
	_lit_materials.append(material)
	_detail_materials.append(material)
	var ring := MeshInstance3D.new()
	ring.mesh = _annulus(inner_ratio, outer_ratio)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_material.set_shader_parameter("has_ring_shadow", true)
	_material.set_shader_parameter("ring_texture", ring_texture)
	_material.set_shader_parameter("ring_inner", inner_ratio)
	_material.set_shader_parameter("ring_outer", outer_ratio)


func add_surface_detail(definition: BodyDefinition) -> void:
	_material.set_shader_parameter("relief_strength", definition.relief_strength)
	if definition.normal_texture_path != "":
		_material.set_shader_parameter("has_normal_texture", true)
		_bind_texture(_material, "normal_texture", definition.normal_texture_path)
	if definition.specular_texture_path != "":
		_material.set_shader_parameter("has_specular_texture", true)
		_bind_texture(_material, "specular_texture", definition.specular_texture_path)


func add_atmosphere_layers(definition: BodyDefinition) -> void:
	if definition.atmosphere_thickness > 0.0:
		add_atmosphere(definition.atmosphere_color, definition.atmosphere_thickness, definition.atmosphere_intensity)
	if definition.cloud_texture_path != "":
		add_clouds(definition.cloud_texture_path, definition.cloud_altitude, definition.cloud_opacity)


func add_atmosphere(color: Color, thickness: float, intensity: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = ATMOSPHERE_SHADER
	material.render_priority = ATMOSPHERE_RENDER_PRIORITY
	material.set_shader_parameter("atmosphere_color", color)
	material.set_shader_parameter("thickness", thickness)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("full_detail", _full_effects)
	_detail_materials.append(material)
	_add_shell(material, 1.0 + thickness)


func add_clouds(texture_path: String, altitude: float, opacity: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = CLOUD_SHADER
	material.render_priority = CLOUD_RENDER_PRIORITY
	_bind_texture(material, "cloud_texture", texture_path)
	material.set_shader_parameter("opacity", opacity)
	_clouds = _add_shell(material, 1.0 + altitude)
	_clouds.visible = _full_effects
	_eclipse_materials.append(material)


func _add_shell(material: ShaderMaterial, scale_factor: float) -> MeshInstance3D:
	var shell := MeshInstance3D.new()
	shell.mesh = _sphere
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.transform = Transform3D(Basis.from_scale(Vector3.ONE * scale_factor), Vector3.ZERO)
	add_child(shell)
	_shells.append(shell)
	_lit_materials.append(material)
	return shell


static func _annulus(inner_radius: float, outer_radius: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in RING_SEGMENTS + 1:
		var angle := TAU * float(index) / float(RING_SEGMENTS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(direction * inner_radius)
		vertices.append(direction * outer_radius)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, 0.5))
		uvs.append(Vector2(1.0, 0.5))
	for index in RING_SEGMENTS:
		var first := index * 2
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first + 1, first + 3, first + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

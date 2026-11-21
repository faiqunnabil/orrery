class_name CometTail
extends Node3D

const ACTIVE_DISTANCE_AU := 3.0
const PEAK_DISTANCE_AU := 0.6
const ION_LENGTH_AU := 0.2
const DUST_LENGTH_FRACTION := 0.6
const DUST_LAG := 0.35
const LIFETIME := 2.5
const COMA_FRACTION := 0.02
const MIN_COMA_RADII := 12.0
const ION_SPREAD := 2.5
const DUST_SPREAD := 9.0
const ION_SIZE := 0.018
const DUST_SIZE := 0.04
const AMOUNTS := [[300, 200], [600, 400], [1200, 800]]
const ION_COLOR := Color(0.45, 0.72, 1.0)
const DUST_COLOR := Color(1.0, 0.9, 0.74)
const COMA_COLOR := Color(0.75, 0.95, 1.0)
const COMA_ALPHA := 0.55

var activity := 0.0
var length := 0.0

var _ion := GPUParticles3D.new()
var _dust := GPUParticles3D.new()
var _coma := MeshInstance3D.new()
var _sprite := _sprite_texture()


func _init() -> void:
	_configure(_ion, ION_COLOR, ION_SPREAD, ION_SIZE)
	_configure(_dust, DUST_COLOR, DUST_SPREAD, DUST_SIZE)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_coma.mesh = quad
	_coma.material_override = _sprite_material(COMA_COLOR, BaseMaterial3D.BILLBOARD_ENABLED)
	_coma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_coma)
	visible = false
	apply_quality(Quality.Preset.MEDIUM)


func apply_quality(preset: int) -> void:
	var amounts: Array = AMOUNTS[clampi(preset, 0, AMOUNTS.size() - 1)]
	_ion.amount = amounts[0]
	_dust.amount = amounts[1]


func particle_count() -> int:
	return _ion.amount + _dust.amount


func ion_direction() -> Vector3:
	return _ion.transform.basis.z.normalized()


func dust_direction() -> Vector3:
	return _dust.transform.basis.z.normalized()


static func activity_at(distance_au: float) -> float:
	return clampf((ACTIVE_DISTANCE_AU - distance_au) / (ACTIVE_DISTANCE_AU - PEAK_DISTANCE_AU), 0.0, 1.0)


static func length_at(distance_au: float, units_per_km: float) -> float:
	return ION_LENGTH_AU * Astro.AU_KM * units_per_km * activity_at(distance_au)


func update(
	nucleus: Vector3, away_from_sun: Vector3, velocity: Vector3, distance_au: float, units_per_km: float, nucleus_radius: float
) -> void:
	activity = activity_at(distance_au)
	var active := activity > 0.0 and away_from_sun != Vector3.ZERO
	visible = active
	_ion.emitting = active
	_dust.emitting = active
	if not active:
		length = 0.0
		return
	var away := away_from_sun.normalized()
	length = length_at(distance_au, units_per_km)
	_ion.transform = Transform3D(_facing(away).scaled(Vector3.ONE * length), nucleus)
	var trailing := (away - velocity.normalized() * DUST_LAG).normalized() if velocity != Vector3.ZERO else away
	_dust.transform = Transform3D(_facing(trailing).scaled(Vector3.ONE * length * DUST_LENGTH_FRACTION), nucleus)
	var coma_radius := maxf(length * COMA_FRACTION, nucleus_radius * MIN_COMA_RADII)
	_coma.transform = Transform3D(Basis.from_scale(Vector3.ONE * coma_radius), nucleus)
	(_coma.material_override as StandardMaterial3D).albedo_color = Color(COMA_COLOR, activity * COMA_ALPHA)


func _configure(particles: GPUParticles3D, color: Color, spread: float, size: float) -> void:
	particles.local_coords = true
	particles.lifetime = LIFETIME
	particles.preprocess = LIFETIME
	particles.explosiveness = 0.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-0.6, -0.6, -0.2), Vector3(1.2, 1.2, 1.6))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.0, 1.0)
	process.spread = spread
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = 0.8 / LIFETIME
	process.initial_velocity_max = 1.2 / LIFETIME
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = size * 0.3
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.5))
	growth.add_point(Vector2(1.0, 2.0))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = growth
	process.scale_curve = scale_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.85))
	fade.set_color(1, Color(color, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _sprite_material(Color.WHITE, BaseMaterial3D.BILLBOARD_PARTICLES)
	particles.draw_pass_1 = quad
	add_child(particles)


func _sprite_material(color: Color, billboard: BaseMaterial3D.BillboardMode) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.billboard_mode = billboard
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = billboard == BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = color
	material.albedo_texture = _sprite
	material.disable_fog = true
	return material


static func _facing(direction: Vector3) -> Basis:
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(-direction, up)


static func _sprite_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.35))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture

extends SceneTree

const ORION := Vector2(83.8, 3.0)
const SOLSTICE := "2026-06-21T08:24:00"
const SOLSTICE_SUN := Vector2(90.0, 23.44)
const ORION_NIGHT := "2026-12-21T12:00:00"
const CASSIOPEIA := Vector2(14.0, 60.0)

var frame := 0
var step := 0
var wait := 90
var failures := 0
var out_dir := ""
var values := {}


func _initialize() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	var preferences := root.get_node("Preferences")
	preferences.set_onboarding_done(true)
	preferences.set_constellations_visible(false)
	change_scene_to_file("res://modes/explore/explore_mode.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame < wait:
		return false
	frame = 0
	wait = 15
	_run_step()
	step += 1
	return false


func _check(label: String, condition: bool) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		failures += 1


func _shot(name: String) -> void:
	if out_dir == "":
		return
	root.get_texture().get_image().save_jpg("%s/%s.jpg" % [out_dir, name], 0.85)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)


func _vector(scene, id: String) -> Vector3:
	var p: PackedFloat64Array = scene.renderer.render_position(id)
	return Vector3(p[0], p[1], p[2])


func _run_step() -> void:
	var scene := current_scene
	var stars = scene.star_field
	var preferences := root.get_node("Preferences")
	match step:
		0:
			_check("every naked-eye star is loaded", stars.star_count > 8500)
			_check("all 88 constellation figures are loaded", stars.segment_count > 650)
			_check("constellation figures start hidden", not stars.constellations_visible())
			var camera: Camera3D = scene.camera
			_check("the star sphere lies beyond every body and inside the far plane", stars.scale.x > camera.far * 0.5 and stars.scale.x < camera.far)
			scene.clock.paused = true
			scene._set_scale_mode(1)
			scene.clock.seconds = Time.get_unix_time_from_datetime_string(SOLSTICE) - 946728000.0
			scene.model.update(scene.clock.seconds)
			scene.renderer.compute_positions()
			var toward_sun: Vector3 = (_vector(scene, "sun") - _vector(scene, "earth")).normalized()
			var expected: Vector3 = stars.direction(SOLSTICE_SUN.x, SOLSTICE_SUN.y)
			_check("the June solstice Sun sits at RA 6h, Dec +23.4 on the star sphere", rad_to_deg(toward_sun.angle_to(expected)) < 0.5)
			scene._set_scale_mode(0)
			scene.clock.seconds = Time.get_unix_time_from_datetime_string(ORION_NIGHT) - 946728000.0
			_key(KEY_C)
		1:
			_check("C shows the constellation figures", preferences.constellations_visible and stars.constellations_visible())
			scene.camera.release_anchor(scene.camera.world_position(scene._anchor_position()))
			scene.camera.aim(stars.direction(ORION.x, ORION.y))
			wait = 60
		2:
			_shot("stars_orion")
			_key(KEY_C)
		3:
			_check("C hides them again", not preferences.constellations_visible and not stars.constellations_visible())
			_shot("stars_orion_plain")
			scene.camera.aim(stars.direction(CASSIOPEIA.x, CASSIOPEIA.y))
			wait = 60
		4:
			_shot("stars_milky_way")
			print("FAILURES: ", failures)
			quit()

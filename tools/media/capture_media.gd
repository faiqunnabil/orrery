extends SceneTree

const J2000_UNIX := 946728000.0
const SQUARE := 720
const ORION := Vector2(83.8, 3.0)
const NIGHT_SKY_STANDOFF := 6.0
const EARTH_VIEW_RADII := 2.6
const EARTH_TERMINATOR_TURN := -1.05
const INNER_SYSTEM_RADII := 8.0
const INNER_SYSTEM_TILT := 0.45
const SATURN_VIEW_RADII := 7.0
const PLUTO_VIEW_RADII := 3.8
const IO_VIEW_RADII := 5.5
const IO_VIEW_TURN := 0.3
const SOLAR_ECLIPSE_ZOOM := 0.7
const BINARY_PRESET := 1
const FIGURE_EIGHT_PRESET := 4
const WELL_ZOOM := 14.0
const FIGURE_EIGHT_HEIGHT := 520000.0
const FIGURE_EIGHT_BACK := 120000.0
const QUIZ_WRONG_CHOICE := 3

var out_dir := ""
var frame := 0
var index := 0
var steps: Array = []


func _initialize() -> void:
	out_dir = OS.get_environment("MEDIA_DIR")
	var preferences := root.get_node("Preferences")
	preferences.set_onboarding_done(true)
	preferences.set_language("en")
	preferences.set_depth_level(0)
	preferences.set_constellations_visible(false)
	preferences.set_gravity_well_visible(false)
	preferences.set_labels_visible(true)
	preferences.set_trail_length(2)
	root.get_node("Quality").set_preset(2)
	steps = [
		[func() -> void: change_scene_to_file("res://modes/menu/main_menu.tscn"), 150],
		[func() -> void: _save("main_menu"), 1],
		[func() -> void: change_scene_to_file("res://modes/explore/explore_mode.tscn"), 150],
		[_jupiter, 260],
		[func() -> void: _save("jupiter_system"), 1],
		[_earth, 260],
		[func() -> void: _save_clean("earth"), 1],
		[_inner_system, 260],
		[_tilt_inner_system, 90],
		[func() -> void: _save_clean("inner_system"), 1],
		[func() -> void: _close_up("saturn", SATURN_VIEW_RADII), 260],
		[func() -> void: _save("saturn"), 1],
		[func() -> void: _close_up("pluto", PLUTO_VIEW_RADII), 260],
		[func() -> void: _save("pluto"), 1],
		[_io_shadow, 200],
		[func() -> void: _save_clean("io_shadow", true), 1],
		[func() -> void: _eclipse_from("2026-04-01T00:00:00", -1), 300],
		[func() -> void: _save_clean("lunar_eclipse", true), 1],
		[func() -> void: _eclipse_from("2027-07-01T00:00:00", 1), 300],
		[func() -> void: current_scene.camera.zoom(SOLAR_ECLIPSE_ZOOM), 90],
		[func() -> void: _save_clean("solar_eclipse", true), 1],
		[_quiz, 200],
		[_answer_quiz, 60],
		[func() -> void: _save("quiz"), 1],
		[_tour, 300],
		[func() -> void: _save("tours"), 1],
		[_night_sky_position, 260],
		[_night_sky_aim, 120],
		[func() -> void: _save("night_sky"), 1],
		[_comet, 300],
		[func() -> void: _save("comet"), 1],
		[func() -> void: change_scene_to_file("res://modes/sandbox/sandbox_mode.tscn"), 150],
		[_sandbox_physics, 60],
		[func() -> void: _save("sandbox"), 1],
		[_gravity_well, 220],
		[_zoom_gravity_well, 90],
		[func() -> void: _save_clean("gravity_well"), 1],
		[_figure_eight, 400],
		[_frame_figure_eight, 60],
		[func() -> void: _save_clean("figure_eight", true), 1],
		[func() -> void: current_scene._start_challenge(0), 200],
		[_launch_challenge_planet, 400],
		[func() -> void: current_scene.clock.paused = true, 30],
		[func() -> void: _save("challenges"), 1],
		[quit, 1],
	]


func _process(_delta: float) -> bool:
	if index >= steps.size():
		return false
	frame += 1
	var step: Array = steps[index]
	if frame < (90 if index == 0 else steps[index - 1][1]):
		return false
	frame = 0
	index += 1
	(step[0] as Callable).call()
	return false


func _seconds(text: String) -> float:
	return Time.get_unix_time_from_datetime_string(text) - J2000_UNIX


func _save(name: String, square: bool = false) -> void:
	var image := root.get_texture().get_image()
	if square:
		var size := image.get_size()
		image = image.get_region(Rect2i((size.x - SQUARE) / 2, (size.y - SQUARE) / 2, SQUARE, SQUARE))
	image.save_jpg("%s/%s.jpg" % [out_dir, name], 0.88)
	print("saved ", name)


func _save_clean(name: String, square: bool = false) -> void:
	_save(name, square)
	current_scene.hud.set_root_visible(true)


func _hide_interface() -> void:
	current_scene.hud.set_root_visible(false)


func _set_date(text: String) -> void:
	var scene := current_scene
	scene.clock.paused = true
	scene.clock.seconds = _seconds(text)
	scene.model.update(scene.clock.seconds)
	scene.renderer.compute_positions()


func _jupiter() -> void:
	_set_date("2026-11-22T15:00:00")
	current_scene._focus_body("jupiter")


func _earth() -> void:
	var scene := current_scene
	scene._clear_selection()
	var toward: Vector3 = scene._toward_sun("earth").rotated(Vector3.UP, EARTH_TERMINATOR_TURN)
	scene.camera.focus_on("earth", scene.renderer.mapper.radius(scene.model.get_body("earth")), toward, EARTH_VIEW_RADII)
	_hide_interface()


func _inner_system() -> void:
	var scene := current_scene
	scene.hud.set_root_visible(true)
	scene._fly_to("sun", INNER_SYSTEM_RADII)


func _tilt_inner_system() -> void:
	current_scene.camera.orbit(0.0, INNER_SYSTEM_TILT)
	_hide_interface()


func _close_up(id: String, radii: float) -> void:
	var scene := current_scene
	root.get_node("Preferences").set_depth_level(1)
	scene._select(id)
	scene._fly_to(id, radii)


func _io_shadow() -> void:
	var scene := current_scene
	root.get_node("Preferences").set_depth_level(0)
	scene._clear_selection()
	scene.clock.seconds = _shadow_time(scene, "io", "jupiter", _seconds("2026-11-24T00:00:00"), 2.0 * 86400.0, 600.0)
	scene.model.update(scene.clock.seconds)
	scene.renderer.compute_positions()
	var jupiter = scene.model.get_body("jupiter")
	var toward: Vector3 = scene._toward_sun("jupiter").rotated(Vector3.UP, IO_VIEW_TURN)
	scene.camera.focus_on("jupiter", scene.renderer.mapper.radius(jupiter), toward, IO_VIEW_RADII)
	_hide_interface()


func _shadow_time(scene, occluder: String, receiver: String, center: float, span: float, step_seconds: float) -> float:
	var best_time := center
	var best_miss := INF
	var t := center - span
	while t <= center + span:
		scene.model.update(t)
		scene.renderer.compute_positions()
		var r: PackedFloat64Array = scene.renderer.render_position(receiver)
		var o: PackedFloat64Array = scene.renderer.render_position(occluder)
		var s: PackedFloat64Array = scene.renderer.render_position("sun")
		var light := Vector3(s[0] - r[0], s[1] - r[1], s[2] - r[2]).normalized()
		var offset := Vector3(o[0] - r[0], o[1] - r[1], o[2] - r[2])
		var along := offset.dot(light)
		if along > 0.0 and (offset - light * along).length() < best_miss:
			best_miss = (offset - light * along).length()
			best_time = t
		t += step_seconds
	return best_time


func _eclipse_from(date: String, direction: int) -> void:
	var scene := current_scene
	scene.hud.set_root_visible(true)
	_set_date(date)
	scene._go_to_eclipse(direction)
	scene.clock.paused = true
	_hide_interface()


func _quiz() -> void:
	var scene := current_scene
	scene._set_scale_mode(0)
	_set_date("2026-11-22T15:00:00")
	scene._focus_body("europa")
	scene._start_quiz("moons_and_dwarfs")


func _answer_quiz() -> void:
	current_scene._quiz_panel._answer(QUIZ_WRONG_CHOICE)


func _tour() -> void:
	var scene := current_scene
	scene._quiz_panel.close_quiz()
	scene._start_tour("eclipses_comets")


func _night_sky_position() -> void:
	var scene := current_scene
	scene._tour_player.stop()
	scene._set_scale_mode(0)
	_set_date("2026-12-21T12:00:00")
	scene._focus_body("earth")


func _night_sky_aim() -> void:
	var scene := current_scene
	root.get_node("Preferences").set_constellations_visible(true)
	scene._clear_selection()
	scene.camera.release_anchor(scene.camera.world_position(scene._anchor_position()))
	var toward: Vector3 = scene.star_field.direction(ORION.x, ORION.y)
	var earth: PackedFloat64Array = scene.renderer.render_position("earth")
	scene.camera.offset = PackedFloat64Array(
		[earth[0] + toward.x * NIGHT_SKY_STANDOFF, earth[1] + toward.y * NIGHT_SKY_STANDOFF, earth[2] + toward.z * NIGHT_SKY_STANDOFF]
	)
	scene.camera.aim(toward)


func _comet() -> void:
	var scene := current_scene
	root.get_node("Preferences").set_constellations_visible(false)
	_set_date("1986-03-01T00:00:00")
	scene._focus_body("halley")
	scene._clear_selection()


func _sandbox_physics() -> void:
	var scene := current_scene
	scene.clock.paused = true
	root.get_node("Preferences").set_depth_level(1)
	scene.panel.show_page(2)


func _gravity_well() -> void:
	var scene := current_scene
	var preferences := root.get_node("Preferences")
	preferences.set_depth_level(0)
	preferences.set_gravity_well_visible(true)
	scene._load_preset(BINARY_PRESET)
	scene._fly_to(scene.world.bodies[0].id)


func _zoom_gravity_well() -> void:
	current_scene.camera.zoom(WELL_ZOOM)
	_hide_interface()


func _figure_eight() -> void:
	var scene := current_scene
	root.get_node("Preferences").set_gravity_well_visible(false)
	scene._load_preset(FIGURE_EIGHT_PRESET)
	scene.clock.paused = false
	scene.clock.step_index = 5


func _frame_figure_eight() -> void:
	var scene := current_scene
	scene.clock.paused = true
	scene.camera.release_anchor(scene.camera.world_position(scene._anchor_position()))
	scene.camera.offset = PackedFloat64Array([0.0, FIGURE_EIGHT_HEIGHT, FIGURE_EIGHT_BACK])
	scene.camera.aim(Vector3(0.0, -FIGURE_EIGHT_HEIGHT, -FIGURE_EIGHT_BACK))
	_hide_interface()


func _launch_challenge_planet() -> void:
	var scene := current_scene
	var world = scene.world
	var simulation = world.simulation
	var star: int = world.index_of("star")
	var distance := 149597870.7
	var circular := sqrt(simulation.gm[star] / distance)
	world.add_custom_body(
		"Planet", "planet", Color.WHITE, "res://assets/textures/bodies/mars.jpg", false,
		simulation.position_of(star).plus(DVec3.new(distance, 0.0, 0.0)),
		simulation.velocity_of(star).plus(DVec3.new(0.0, circular, 0.0)),
		5.9722e24, 6371.0
	)
	scene.clock.step_index = 5

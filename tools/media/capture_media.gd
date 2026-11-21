extends SceneTree

const J2000_UNIX := 946728000.0
const SQUARE := 720
const ORION := Vector2(83.8, 3.0)
const NIGHT_SKY_STANDOFF := 6.0
const BINARY_PRESET := 1
const FIGURE_EIGHT_PRESET := 4
const WELL_ZOOM := 14.0
const FIGURE_EIGHT_HEIGHT := 520000.0
const FIGURE_EIGHT_BACK := 120000.0

var out_dir := ""
var frame := 0
var step := 0
var wait := 120


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
	change_scene_to_file("res://modes/explore/explore_mode.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame < wait:
		return false
	frame = 0
	wait = 30
	_run_step()
	step += 1
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


func _run_step() -> void:
	var scene := current_scene
	var preferences := root.get_node("Preferences")
	match step:
		0:
			scene._start_tour("eclipses_comets")
			wait = 300
		1:
			_save("tours")
			scene._tour_player.stop()
			scene.clock.paused = true
			scene.clock.seconds = _seconds("2026-07-01T00:00:00")
			scene._go_to_eclipse(1)
			scene.clock.paused = true
			scene.hud.set_root_visible(false)
			wait = 300
		2:
			_save("solar_eclipse", true)
			scene.hud.set_root_visible(true)
			scene._set_scale_mode(0)
			scene.clock.seconds = _seconds("2026-12-21T12:00:00")
			scene.model.update(scene.clock.seconds)
			scene.renderer.compute_positions()
			scene._focus_body("earth")
			wait = 260
		3:
			preferences.set_constellations_visible(true)
			scene._clear_selection()
			scene.camera.release_anchor(scene.camera.world_position(scene._anchor_position()))
			var toward_orion: Vector3 = scene.star_field.direction(ORION.x, ORION.y)
			var earth: PackedFloat64Array = scene.renderer.render_position("earth")
			scene.camera.offset = PackedFloat64Array(
				[earth[0] + toward_orion.x * NIGHT_SKY_STANDOFF, earth[1] + toward_orion.y * NIGHT_SKY_STANDOFF, earth[2] + toward_orion.z * NIGHT_SKY_STANDOFF]
			)
			scene.camera.aim(toward_orion)
			wait = 120
		4:
			_save("night_sky")
			preferences.set_constellations_visible(false)
			scene.clock.seconds = _seconds("1986-03-01T00:00:00")
			scene.model.update(scene.clock.seconds)
			scene.renderer.compute_positions()
			scene._focus_body("halley")
			scene._clear_selection()
			wait = 300
		5:
			_save("comet")
			change_scene_to_file("res://modes/sandbox/sandbox_mode.tscn")
			wait = 150
		6:
			scene.clock.paused = true
			preferences.set_depth_level(1)
			scene.panel.show_page(2)
			wait = 60
		7:
			_save("sandbox")
			preferences.set_depth_level(0)
			preferences.set_gravity_well_visible(true)
			scene._load_preset(BINARY_PRESET)
			var first: String = scene.world.bodies[0].id
			scene._fly_to(first)
			wait = 220
		8:
			scene.camera.zoom(WELL_ZOOM)
			scene.hud.set_root_visible(false)
			wait = 90
		9:
			_save("gravity_well")
			scene.hud.set_root_visible(true)
			preferences.set_gravity_well_visible(false)
			scene._load_preset(FIGURE_EIGHT_PRESET)
			scene.clock.paused = false
			scene.clock.step_index = 5
			wait = 400
		10:
			scene.clock.paused = true
			scene.camera.release_anchor(scene.camera.world_position(scene._anchor_position()))
			scene.camera.offset = PackedFloat64Array([0.0, FIGURE_EIGHT_HEIGHT, FIGURE_EIGHT_BACK])
			scene.camera.aim(Vector3(0.0, -FIGURE_EIGHT_HEIGHT, -FIGURE_EIGHT_BACK))
			scene.hud.set_root_visible(false)
			wait = 60
		11:
			_save("figure_eight", true)
			scene.hud.set_root_visible(true)
			scene._start_challenge(0)
			wait = 200
		12:
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
			wait = 400
		13:
			scene.clock.paused = true
			wait = 30
		14:
			_save("challenges")
			quit()

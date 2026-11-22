extends SceneTree

const J2000_UNIX := 946728000.0
const AU_KM := 149597870.7

var frame := 0
var step := 0
var wait := 90
var failures := 0
var saved := {}


func _initialize() -> void:
	var preferences := root.get_node("Preferences")
	preferences.set_onboarding_done(true)
	preferences.set_language("en")
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


func _check(label: String, condition: bool) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		failures += 1
		_save_failure()


func _save_failure() -> void:
	var directory := OS.get_environment("FAILURE_DIR")
	if directory == "":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var path := "%s/%s_failure_%d.jpg" % [directory, get_script().resource_path.get_file().get_basename(), failures]
	root.get_texture().get_image().save_jpg(path, 0.85)
	print("      screenshot ", path)



func _seconds(text: String) -> float:
	return Time.get_unix_time_from_datetime_string(text) - J2000_UNIX


func _settings():
	return current_scene.pause_menu._menu._settings


func _run_step() -> void:
	var scene := current_scene
	var preferences := root.get_node("Preferences")
	match step:
		0:
			scene.clock.paused = true
			scene.clock.step_index = 6
			scene.clock.reversed = true
			scene.clock.seconds = _seconds("1986-02-09T00:00:00")
			scene._set_scale_mode(1)
			scene._focus_body("mars")
			wait = 200
		1:
			saved["seconds"] = scene.clock.seconds
			saved["offset"] = scene.camera.offset.duplicate()
			scene._open_pause_menu()
			scene.pause_menu._menu.open_settings()
			_settings()._choose_language(1)
			wait = 120
		2:
			_check("the language changed", preferences.language == "id")
			_check("Explore keeps the date after the reload", absf(scene.clock.seconds - saved["seconds"]) < 1.0)
			_check("Explore keeps the time speed, direction, and pause", scene.clock.step_index == 6 and scene.clock.reversed and scene.clock.paused)
			_check("Explore keeps the true scale", scene.renderer.mapper.mode == 1)
			_check("Explore keeps the camera on Mars", scene.camera.anchor_id == "mars" and Vector3(scene.camera.offset[0], scene.camera.offset[1], scene.camera.offset[2]).is_equal_approx(Vector3(saved["offset"][0], saved["offset"][1], saved["offset"][2])))
			_check("Explore keeps Mars selected", scene._selected_id == "mars")
			scene._open_pause_menu()
			scene.pause_menu._menu.open_settings()
			_settings()._choose_language(0)
			wait = 120
		3:
			_check("switching back keeps the date again", absf(scene.clock.seconds - saved["seconds"]) < 1.0 and preferences.language == "en")
			scene._set_scale_mode(0)
			scene.clock.step_index = 3
			scene.clock.reversed = false
			scene.clock.paused = true
			scene.clock.seconds = _seconds("2026-05-01T00:00:00")
			saved["before_tour"] = scene.clock.seconds
			scene._start_tour("eclipses_comets")
			wait = 150
		4:
			for _index in 3:
				scene._tour_player.next()
			wait = 150
		5:
			_check("the tour has moved the clock to 1986", scene.clock.seconds < _seconds("1990-01-01T00:00:00"))
			scene._tour_player.stop()
			wait = 30
		6:
			_check("leaving the tour restores the date", absf(scene.clock.seconds - saved["before_tour"]) < 1.0)
			_check("leaving the tour restores the speed, direction, and pause", scene.clock.step_index == 3 and not scene.clock.reversed and scene.clock.paused)
			_check("leaving the tour restores the compressed scale", scene.renderer.mapper.mode == 0)
			scene._start_tour("eclipses_comets")
			wait = 150
		7:
			scene._open_pause_menu()
			scene.pause_menu._menu.open_settings()
			_settings()._choose_language(1)
			wait = 120
		8:
			_check("a reload during a tour keeps the time from before the tour", absf(scene.clock.seconds - saved["before_tour"]) < 1.0 and scene.renderer.mapper.mode == 0)
			scene._open_pause_menu()
			scene.pause_menu._menu.open_settings()
			_settings()._choose_language(0)
			wait = 120
		9:
			change_scene_to_file("res://modes/sandbox/sandbox_mode.tscn")
			wait = 150
		10:
			scene._start_challenge(0)
			wait = 60
		11:
			var world = scene.world
			var simulation = world.simulation
			var star: int = world.index_of("star")
			var circular := sqrt(simulation.gm[star] / AU_KM)
			world.add_custom_body("Probe", "planet", Color.WHITE, "res://assets/textures/bodies/mars.jpg", false, simulation.position_of(star).plus(DVec3.new(AU_KM, 0.0, 0.0)), simulation.velocity_of(star).plus(DVec3.new(0.0, circular, 0.0)), 5.9722e24, 6371.0)
			scene.clock.step_index = 5
			wait = 150
		12:
			scene.clock.paused = true
			saved["bodies"] = scene.world.bodies.size()
			saved["progress"] = scene._judge.progress
			saved["target"] = scene._judge.target_id
			saved["world_seconds"] = scene.world.seconds
			_check("the challenge is under way before the reset", saved["progress"] > 0.05 and saved["target"] != "")
			scene._open_pause_menu()
			scene.pause_menu._menu.open_settings()
			_settings().reset_all_settings()
			wait = 120
		13:
			_check("the Sandbox keeps its bodies after a reload", scene.world.bodies.size() == saved["bodies"] and scene.world.index_of(saved["target"]) >= 0)
			_check("the Sandbox keeps its simulation time", absf(scene.world.seconds - saved["world_seconds"]) < 1.0)
			_check("the challenge continues with its progress", scene._judge.is_active() and scene._judge.target_id == saved["target"] and absf(scene._judge.progress - saved["progress"]) < 0.01)
			_check("the challenge panel is shown again", scene.panel.is_showing_challenge() and scene.panel._page == 3)
			_check("new bodies are numbered after the restored ones", scene._spawn_counter >= 1)
			scene._leave_challenge()
			scene._start_challenge(0)
			wait = 60
		14:
			scene._select("star")
			scene._remove_selected()
			root.get_node("Preferences").set_depth_level(0)
			scene.panel.show_page(2)
			_check("the Physics page stays hidden at the Explorer level", scene.panel._page != 2 and not scene.panel._pages[2].visible)
			wait = 30
		15:
			_check("removing the central star is reported at once", scene._judge.status.begins_with("The central body is gone"))
			scene._leave_challenge()
			print("FAILURES: ", failures)
			quit()

extends SceneTree

var frame := 0
var step := 0
var wait := 90
var failures := 0


func _initialize() -> void:
	var preferences := root.get_node("Preferences")
	preferences.set_onboarding_done(true)
	preferences.mark_challenge_complete("orbit")
	change_scene_to_file("res://modes/explore/explore_mode.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame < wait:
		return false
	frame = 0
	wait = 20
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



func _run_step() -> void:
	var scene := current_scene
	var preferences := root.get_node("Preferences")
	var quality := root.get_node("Quality")
	var audio := root.get_node("Audio")
	var bindings := root.get_node("InputBindings")
	match step:
		0:
			preferences.set_labels_visible(false)
			preferences.set_constellations_visible(true)
			preferences.set_language("id")
			quality.set_preset(2)
			audio.set_music_volume(0.1)
			bindings.rebind("toggle_labels", KEY_K)
			scene._open_pause_menu()
		1:
			var menu = scene.pause_menu._menu
			menu.open_settings()
			menu._settings._show_page(3)
		2:
			var settings = scene.pause_menu._menu._settings
			_check("the controls page offers a log folder and a reset", settings._reset_all_button != null and settings._reset_all_button.is_visible_in_tree())
			_check("the log folder exists", DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(settings.LOG_FOLDER)))
			settings._reset_all_button.pressed.emit()
		3:
			var settings = scene.pause_menu._menu._settings
			_check("the first press only asks for confirmation", settings._reset_armed and not preferences.labels_visible and quality.preset == 2)
			settings._reset_all_button.pressed.emit()
			wait = 90
		4:
			_check("the second press restores the interface settings", preferences.labels_visible and not preferences.constellations_visible)
			_check("the language follows the system again", preferences.language == "")
			_check("graphics return to the Medium preset", quality.preset == 1)
			_check("audio volumes return to their defaults", is_equal_approx(audio.music_volume, audio.DEFAULT_MUSIC_VOLUME))
			_check("key bindings return to their defaults", bindings.keys_text("toggle_labels") == "L")
			_check("progress is kept", preferences.onboarding_done and preferences.is_challenge_complete("orbit"))
			_check("the screen reloads unpaused", current_scene != null and not paused and current_scene.name != "")
			print("FAILURES: ", failures)
			quit()

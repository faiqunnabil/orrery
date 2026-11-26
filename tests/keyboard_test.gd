extends SceneTree

const MAX_TABS := 120

var frame := 0
var step := 0
var wait := 90
var failures := 0


func _initialize() -> void:
	var preferences := root.get_node("Preferences")
	preferences.set_onboarding_done(true)
	preferences.set_constellations_visible(false)
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



func _key(code: Key, shift: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		root.push_input(event)


func _tab_to(matches: Callable) -> Control:
	for _index in MAX_TABS:
		var owner := root.gui_get_focus_owner()
		if owner != null and matches.call(owner):
			return owner
		_key(KEY_TAB)
	return null


func _button_named(text: String) -> Callable:
	return func(control: Control) -> bool: return control is Button and (control as Button).text == text


func _seconds(text: String) -> float:
	return Time.get_unix_time_from_datetime_string(text) - 946728000.0


func _run_step() -> void:
	var scene := current_scene
	var preferences := root.get_node("Preferences")
	match step:
		0:
			scene.clock.paused = true
			_key(KEY_F6)
		1:
			var toggle := _tab_to(_button_named("Constellations"))
			_check("Tab reaches the Constellations toggle", toggle != null)
			_key(KEY_ENTER)
		2:
			_check("Enter on the toggle shows the constellation figures", preferences.constellations_visible)
			_key(KEY_ESCAPE)
		3:
			scene.clock.seconds = _seconds("2026-07-01T00:00:00")
			_key(KEY_J)
		4:
			var next := _tab_to(func(control: Control) -> bool: return scene.hud.date_panel.is_ancestor_of(control) and control is Button and (control as Button).text == "Next")
			_check("Tab reaches the next eclipse button in the date panel", next != null)
			_key(KEY_ENTER)
			wait = 120
		5:
			_check("Enter on it jumps to the August 2026 eclipse", absf(scene.clock.seconds - _seconds("2026-08-12T17:46:00")) < 300.0)
			change_scene_to_file("res://modes/sandbox/sandbox_mode.tscn")
			wait = 150
		6:
			scene.clock.paused = true
			_key(KEY_F6)
		7:
			var tab := _tab_to(_button_named("Challenges"))
			_check("Tab reaches the Challenges tab of the Sandbox panel", tab != null)
			_key(KEY_ENTER)
		8:
			_check("Enter opens the Challenges tab", scene.panel._page == 3)
			var start := _tab_to(_button_named("Start"))
			_check("Tab reaches a Start button", start != null)
			_key(KEY_ENTER)
			wait = 90
		9:
			_check("Enter starts the challenge", scene._judge.is_active() and scene.panel.is_showing_challenge())
			_key(KEY_F6)
		10:
			var place := _tab_to(func(control: Control) -> bool: return control == scene.panel._challenge_place)
			_check("Tab reaches the challenge's place button", place != null)
			var leave := _tab_to(_button_named("Leave"))
			_check("Tab reaches the Leave button", leave != null)
			_key(KEY_ENTER)
		11:
			_check("Enter leaves the challenge", not scene._judge.is_active())
			preferences.set_constellations_visible(false)
			print("FAILURES: ", failures)
			quit()

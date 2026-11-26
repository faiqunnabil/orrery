extends SceneTree

var frame := 0
var step := 0
var wait := 60
var failures := 0
var out_dir := ""
var before_speed := 0


func _initialize() -> void:
	root.get_node("Preferences").set_onboarding_done(true)
	out_dir = OS.get_environment("SHOT_DIR")
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
		_save_failure()


func _save_failure() -> void:
	var directory := OS.get_environment("FAILURE_DIR")
	if directory == "":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var path := "%s/%s_failure_%d.jpg" % [directory, get_script().resource_path.get_file().get_basename(), failures]
	root.get_texture().get_image().save_jpg(path, 0.85)
	print("      screenshot ", path)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


func _click_button(text: String) -> bool:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree():
			var center := button.get_global_rect().get_center()
			for pressed in [true, false]:
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				event.position = center
				event.global_position = center
				root.push_input(event)
			return true
	print("  (button not found: ", text, ")")
	return false


func _label_visible(fragment: String) -> bool:
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.contains(fragment):
			return true
	return false


func _run_step() -> void:
	var bindings := root.get_node("InputBindings")
	var scene := current_scene
	match step:
		0:
			_check("G conflicts with distance rings", bindings.conflict_for("move_forward", KEY_G) == "Distance rings")
			_check("number keys are reserved for focus", bindings.conflict_for("move_forward", KEY_3) == "Focus a body")
			_check("Esc is reserved", bindings.conflict_for("move_forward", KEY_ESCAPE) == "Cancel and menu")
			_check("P conflicts with pause", bindings.conflict_for("toggle_labels", KEY_P) == "Pause time")
			_check("rebinding to a used key is refused", not bindings.rebind("move_forward", KEY_G) and bindings.keys_text("move_forward") == "W")
			_check("help text reflects bindings", scene.hud.help_text().begins_with("W/A/S/D Move"))
			_click_button("Menu")
		1:
			_click_button("Settings")
		2:
			_click_button("Controls")
		3:
			_click_button("W")
		4:
			_key(KEY_G)
		5:
			_check("conflict message shown", _label_visible("G is already used for Distance rings"))
			_check("binding unchanged after conflict", bindings.keys_text("move_forward") == "W")
			if out_dir != "":
				root.get_texture().get_image().save_jpg("%s/binding_conflict.jpg" % out_dir, 0.85)
			_key(KEY_I)
		6:
			_check("free key is accepted", bindings.keys_text("move_forward") == "I")
			_check("message cleared", not _label_visible("already used"))
			_check("help text follows the new key", scene.hud.help_text().begins_with("I/A/S/D Move"))
			_click_button("Reset to defaults")
		7:
			_check("reset restores W", bindings.keys_text("move_forward") == "W")
			_check("] matches faster time", _physical_event(KEY_BRACKETRIGHT).is_action("time_faster"))
			_check("Wayland ] (reported as }) matches faster time", _physical_event(KEY_BRACERIGHT).is_action("time_faster"))
			_check("Wayland [ (reported as {) matches slower time", _physical_event(KEY_BRACELEFT).is_action("time_slower"))
			_check("brace codes map back to brackets", bindings.canonical_key(KEY_BRACELEFT) == KEY_BRACKETLEFT and bindings.canonical_key(KEY_R) == KEY_R)
			_click_button("W")
		8:
			_key(KEY_BRACELEFT)
		9:
			_check("captured Wayland [ is treated as [", _label_visible("is already used for Slower time"))
			_check("binding unchanged after bracket conflict", bindings.keys_text("move_forward") == "W")
			_key(KEY_ESCAPE)
		10:
			for node in root.find_children("*", "", true, false):
				var script: Script = node.get_script()
				if script != null and script.resource_path.ends_with("pause_menu.gd"):
					node.close()
		11:
			_check("menu closed and time running", not paused)
			before_speed = scene.clock.step_index
			_key(KEY_BRACERIGHT)
		12:
			_check("Wayland ] speeds time up", scene.clock.step_index == before_speed + 1)
			_key(KEY_BRACELEFT)
		13:
			_check("Wayland [ slows time down", scene.clock.step_index == before_speed)
			print("FAILURES: ", failures)
			quit()


func _physical_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event

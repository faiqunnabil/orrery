extends SceneTree

var frame := 0
var step := 0
var wait := 60
var failures := 0
var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	change_scene_to_file("res://modes/sandbox/sandbox_mode.tscn")


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


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


func _visible_button(text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree():
			return button
	return null


func _click_button(text: String) -> bool:
	var button := _visible_button(text)
	if button == null:
		print("  (button not found: ", text, ")")
		return false
	var center := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = center
		event.global_position = center
		root.push_input(event)
	return true


func _shot(name: String) -> void:
	if out_dir == "":
		return
	root.get_texture().get_image().save_jpg("%s/%s.jpg" % [out_dir, name], 0.85)


func _within_screen(text: String) -> bool:
	var button := _visible_button(text)
	return button != null and button.get_global_rect().end.y <= root.get_visible_rect().size.y


func _run_step() -> void:
	var scene := current_scene
	var preferences := root.get_node("Preferences")
	match step:
		0:
			if preferences.is_scientist():
				_key(KEY_M)
		1:
			_check("Physics tab hidden at Explorer level", _visible_button("Physics") == null)
			_shot("panel_bodies_explorer")
			_click_button("World")
		2:
			_check("World tab shows presets and snapshots on screen", _within_screen("Load") and _within_screen("Restore snapshot"))
			_shot("panel_world")
			_key(KEY_M)
		3:
			_check("Physics tab appears at Scientist level", _visible_button("Physics") != null)
			_click_button("Physics")
			wait = 90
		4:
			_check("time step buttons fit on screen at 720p", _within_screen("1 day") and _within_screen("Reset baseline"))
			var values: Array = scene.panel._conservation_values
			print("  energy ", values[0].text, "  drift ", values[1].text, "  L ", values[2].text, "  drift ", values[3].text)
			_check("conservation readouts are filled", values[0].text.ends_with(" J") and values[2].text.ends_with("kg m2/s"))
			_shot("panel_physics")
			_click_button("RK4")
		5:
			_check("RK4 selected from Physics tab", scene.world.simulation.integrator == 1)
			_click_button("1 day")
			wait = 120
		6:
			_check("fixed step selected", is_equal_approx(scene.world.simulation.fixed_step_seconds, 86400.0))
			print("  drift after 1-day RK4 steps: ", scene.panel._conservation_values[1].text)
			_click_button("Reset baseline")
		7:
			print("  drift after reset: ", scene.panel._conservation_values[1].text)
			_click_button("Bodies")
		8:
			_check("Bodies tab shows Place body", _within_screen("Place body"))
			_key(KEY_ESCAPE)
			_key(KEY_M)
		9:
			print("FAILURES: ", failures)
			quit()

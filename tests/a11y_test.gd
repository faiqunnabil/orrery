extends SceneTree

var frame := 0
var step := 0
var wait := 60
var failures := 0
var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
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


func _click_button(text: String) -> bool:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree():
			var center := root.get_final_transform() * button.get_global_rect().get_center()
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


func _shot(name: String) -> void:
	if out_dir == "":
		return
	root.get_texture().get_image().save_jpg("%s/%s.jpg" % [out_dir, name], 0.85)


func _run_step() -> void:
	var quality := root.get_node("Quality")
	var preferences := root.get_node("Preferences")
	var scene := current_scene
	match step:
		0:
			_click_button("Menu")
		1:
			_click_button("Settings")
		2:
			_click_button("130%")
		3:
			_check("interface size applied", is_equal_approx(root.content_scale_factor, 1.3) and is_equal_approx(quality.ui_scale, 1.3))
			_shot("a11y_settings_130")
			_click_button("Graphics")
		4:
			_click_button("Colorblind-safe")
		5:
			_check("palette preference set", preferences.orbit_palette == 1)
			var trail = scene.renderer._trails["earth"]
			_check("earth trail uses palette color", trail.trail_color != trail.definition.color)
			_click_button("Back")
		6:
			_click_button("Resume")
			scene._fly_to("sun", 120.0)
			wait = 150
		7:
			_shot("a11y_overview_130")
			scene._select("jupiter")
		8:
			_shot("a11y_info_130")
			quality.set_ui_scale(1.0)
			preferences.set_orbit_palette(0)
		9:
			_check("defaults restored", is_equal_approx(root.content_scale_factor, 1.0))
			print("FAILURES: ", failures)
			quit()

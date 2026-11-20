extends SceneTree

var frame := 0
var step := 0
var wait := 90
var failures := 0
var saved := {}


func _initialize() -> void:
	root.get_node("Preferences").set_onboarding_done(true)
	change_scene_to_file("res://modes/explore/explore_mode.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame < wait:
		return false
	frame = 0
	wait = 12
	_run_step()
	step += 1
	return false


func _check(label: String, condition: bool) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		failures += 1


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)


func _type(text: String) -> void:
	for character in text:
		for pressed in [true, false]:
			var event := InputEventKey.new()
			event.unicode = character.unicode_at(0)
			event.pressed = pressed
			root.push_input(event)


func _click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event)


func _button(text: String) -> Button:
	for node in current_scene.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree():
			return button
	return null


func _offset(camera) -> Vector3:
	var o: PackedFloat64Array = camera.offset
	return Vector3(o[0], o[1], o[2])


func _run_step() -> void:
	var scene := current_scene
	var hud = scene.hud
	var preferences := root.get_node("Preferences")
	match step:
		0:
			scene.clock.paused = true
			_key(KEY_SLASH)
		1:
			_check("/ opens the body search", hud.search_panel.is_open())
			_type("eur")
			saved["offset"] = _offset(scene.camera)
			Input.action_press("move_forward")
			wait = 20
		2:
			Input.action_release("move_forward")
			_check("typing in the search does not move the camera", _offset(scene.camera).is_equal_approx(saved["offset"]))
			_check("the best match for 'eur' is Europa", hud.search_panel._matches.size() > 0 and hud.search_panel._matches[0] == "europa")
			_key(KEY_ENTER)
			wait = 200
		3:
			_check("Enter closes the search", not hud.search_panel.is_open())
			_check("Enter selects and flies to Europa", scene._selected_id == "europa" and scene.camera.anchor_id == "europa")
			_key(KEY_SLASH)
		4:
			_type("zzz")
		5:
			_check("an unknown name shows no results", hud.search_panel._matches.is_empty())
			_key(KEY_ESCAPE)
		6:
			_check("Esc closes the search", not hud.search_panel.is_open())
			_check("Esc in the search does not open the pause menu", not scene.pause_menu.visible)
			_key(KEY_J)
		7:
			_check("J opens the date panel", hud.date_panel.is_open())
			hud.date_panel._field.clear()
			_type("2100-01-01")
			_key(KEY_ENTER)
		8:
			_check("a date outside 1800-2050 is refused", hud.date_panel.is_open() and hud.date_panel._error.visible)
			hud.date_panel._field.clear()
			_type("1969-07-20 20:17")
			_key(KEY_ENTER)
		9:
			var expected: float = Time.get_unix_time_from_datetime_string("1969-07-20T20:17:00") - hud.utc_offset_minutes() * 60.0
			_check("a typed local date moves the clock there", absf(scene.clock.seconds - Astro.unix_to_simulation_seconds(expected)) < 1.0)
			_check("Enter closes the date panel", not hud.date_panel.is_open())
			scene._open_date_panel()
		10:
			var event := _button("Apollo 11 lands on the Moon")
			_click(event.get_global_rect().get_center())
		11:
			var landing := Time.get_unix_time_from_datetime_string("1969-07-20T20:17:00")
			_check("a historic moment sets its exact UTC time", absf(scene.clock.seconds - Astro.unix_to_simulation_seconds(landing)) < 1.0)
			preferences.set_onboarding_done(false)
			scene._start_onboarding()
		12:
			_check("the introduction starts when it has not been seen", hud.onboarding.is_running())
			_key(KEY_RIGHT)
		13:
			_check("Right moves to the next tip", hud.onboarding._index == 1)
			_key(KEY_ESCAPE)
		14:
			_check("Esc closes the introduction", not hud.onboarding.is_running())
			_check("closing the introduction remembers it", preferences.onboarding_done)
			_check("Esc on the introduction does not open the pause menu", not scene.pause_menu.visible)
			_key(KEY_F6)
		15:
			_check("F6 moves keyboard focus to the interface", hud.has_keyboard_focus())
			saved["first"] = root.gui_get_focus_owner()
			_key(KEY_TAB)
		16:
			var owner := root.gui_get_focus_owner()
			_check("Tab moves between interface controls", owner != null and owner != saved["first"])
			_check("Tab does not switch the focused body while the interface has focus", scene.camera.anchor_id == "europa")
			saved["paused"] = scene.clock.paused
			_key(KEY_SPACE)
		17:
			_check("Space presses the focused control instead of pausing", scene.clock.paused == saved["paused"] or root.gui_get_focus_owner() == hud._pause_button)
			_key(KEY_ESCAPE)
		18:
			_check("Esc returns focus to the scene", not hud.has_keyboard_focus())
			_check("Esc with interface focus does not open the pause menu", not scene.pause_menu.visible)
			var now := _button("Now")
			_click(now.get_global_rect().get_center())
		19:
			_check("clicking a button with the mouse leaves no keyboard focus", not hud.has_keyboard_focus())
			print("FAILURES: ", failures)
			quit()

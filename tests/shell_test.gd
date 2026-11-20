extends SceneTree

var frame := 0
var step := 0
var wait := 40
var failures := 0


func _initialize() -> void:
	change_scene_to_file("res://modes/menu/main_menu.tscn")


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


func _mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event)


func _click_button(text: String) -> bool:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree():
			var center := button.get_global_rect().get_center()
			_mouse_button(center, true)
			_mouse_button(center, false)
			return true
	print("  (button not found: ", text, ")")
	return false


func _visible_text_contains(needle: String) -> bool:
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.contains(needle):
			return true
	return false


func _name() -> String:
	return current_scene.get_script().get_global_name() if current_scene != null else ""


func _run_step() -> void:
	var scene := current_scene
	var audio := root.get_node("Audio")
	match step:
		0:
			_check("main menu is the first scene", _name() == "MainMenu")
			for entry in ["Explore", "Sandbox", "Settings", "Credits", "Quit"]:
				var found := false
				for node in root.find_children("*", "Button", true, false):
					if (node as Button).text == entry and (node as Button).is_visible_in_tree():
						found = true
				_check("main menu has " + entry, found)
			_check("music is playing", audio._music_player.playing)
			_click_button("Credits")
		1:
			var all_nims := true
			for nim in ["245150207111046", "245150201111002", "245150201111031", "245150200111044"]:
				all_nims = all_nims and _visible_text_contains(nim)
			_check("credits list every NIM", all_nims)
			_check("credits disclose synthesized narration", _visible_text_contains("synthesized"))
			_check("credits include CC BY attribution", _visible_text_contains("CC BY 4.0"))
			_key(KEY_ESCAPE)
		2:
			_check("Esc returns from credits", not _visible_text_contains("245150207111046"))
			_click_button("Settings")
		3:
			_check("settings opens", _visible_text_contains("Window mode"))
			_click_button("Audio")
		4:
			_check("audio page shows volume rows", _visible_text_contains("Narration"))
			_click_button("Back")
		5:
			_click_button("Sandbox")
			wait = 60
		6:
			_check("Sandbox button opens the sandbox", _name() == "SandboxMode")
			if not root.get_node("Preferences").is_scientist():
				_key(KEY_M)
		7:
			if not has_meta("p7"):
				set_meta("p7", true)
				scene.panel.show_page(1)
				step = 6
				return
			_check("physics tab available at Scientist level", scene.panel._tabs._buttons[2].visible)
			scene.panel._preset_option.select(1)
			_click_button("Load")
		8:
			if not has_meta("p8"):
				set_meta("p8", true)
				scene.panel.show_page(2)
				step = 7
				return
			_check("binary star preset loads three bodies", scene.world.bodies.size() == 3 and scene.world.index_of("star_a") >= 0)
			_click_button("RK4")
		9:
			_check("RK4 button selects RK4", scene.world.simulation.integrator == NBodySimulation.Integrator.RK4)
			var day_button: Control = null
			for node in scene.panel.find_children("*", "Button", true, false):
				if (node as Button).text == "1 day":
					day_button = node
			print("  1 day rect=", day_button.get_global_rect(), " scroll rect=", scene.panel._scroll.get_global_rect())

		10:
			if not has_meta("day_clicked"):
				set_meta("day_clicked", true)
				_click_button("1 day")
				step = 9
				return
			_check("1 day button sets a fixed step", is_equal_approx(scene.world.simulation.fixed_step_seconds, 86400.0))
			if not has_meta("p10"):
				set_meta("p10", true)
				scene.panel.show_page(1)
				step = 9
				return
			_click_button("Save snapshot")
		11:
			_check("snapshot file written", FileAccess.file_exists("user://sandbox_snapshot.json"))
			scene.panel._preset_option.select(0)
			_click_button("Load")
		12:
			set_meta("solar_count", scene.world.bodies.size())
			_check("solar system preset reloads", scene.world.index_of("earth") >= 0)
			_check("integrator choice survives a preset load", scene.world.simulation.integrator == NBodySimulation.Integrator.RK4)
			_click_button("Restore snapshot")
		13:
			_check("snapshot restores the binary star", scene.world.bodies.size() == 3 and scene.world.index_of("star_b") >= 0)
			var world: SandboxWorld = scene.world
			world.remove_body("circumbinary_planet")
			var merged_events := []
			world.bodies_merged.connect(func(a: String, b: String) -> void: merged_events.append([a, b]))
			var pa := world.simulation.position_of(0)
			var pb := world.simulation.position_of(1)
			var va := world.simulation.velocity_of(0)
			var vb := world.simulation.velocity_of(1)
			var m0 := world.simulation.mass_kg(0)
			var m1 := world.simulation.mass_kg(1)
			var px := m0 * va.x + m1 * vb.x
			var py := m0 * va.y + m1 * vb.y
			world.simulation.positions[3] = pa.x + 1000000.0
			world.simulation.positions[4] = pa.y
			world.simulation.positions[5] = pa.z
			world.simulation.set_frozen(0, false)
			world.advance(2.0 * 86400.0, 100000)
			var survivor_v := world.simulation.velocity_of(0)
			var total := world.simulation.mass_kg(0)
			_check("touching stars merge into one body", world.bodies.size() == 1 and merged_events.size() == 1)
			_check("merge conserves momentum", Vector2(total * survivor_v.x - px, total * survivor_v.y - py).length() <= 1e-9 * (absf(m0 * va.y) + absf(m1 * vb.y)))
			_key(KEY_ESCAPE)
		14:
			if scene._selected_id != "":
				_key(KEY_ESCAPE)
		15:
			_check("Esc opens the pause menu", scene.pause_menu.visible and paused)
			set_meta("paused_seconds", scene.world.seconds)
			wait = 30
		16:
			_check("simulation frozen while paused", is_equal_approx(scene.world.seconds, get_meta("paused_seconds")))
			_click_button("Resume")
		17:
			_check("Resume closes the pause menu", not scene.pause_menu.visible and not paused)
			_key(KEY_ESCAPE)
		18:
			_click_button("Main menu")
			wait = 60
		19:
			_check("pause menu returns to the main menu", _name() == "MainMenu")
			_click_button("Explore")
			wait = 90
		20:
			_check("Explore button opens explore", _name() == "ExploreMode")
			_check("welcome narration plays", audio._narration_player.playing)
			_click_button("Guided tours")
		21:
			_click_button("Start tour")
			wait = 30
		22:
			var stream: AudioStream = audio._narration_player.stream
			var path := stream.resource_path if stream != null else ""
			print("  narration stream: ", path)
			_check("tour step narration plays", audio._narration_player.playing and path.contains("_01_"))
			_check("music ducks during narration", audio._duck_db < -1.0)
			_click_button("Voice")
		23:
			_check("Voice toggle stops narration", not audio._narration_player.playing and not audio.narration_enabled)
			_check("caption still visible", scene._tour_panel.visible)
			_click_button("Voice")
		24:
			print("FAILURES: ", failures)
			quit()

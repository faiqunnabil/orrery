extends SceneTree

var frame := 0
var step := 0
var wait := 30
var failures := 0
var placed_count := 0
var sandbox_seconds := 0.0


func _initialize() -> void:
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


func _mouse_motion(position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)


func _click(position: Vector2) -> void:
	_mouse_button(position, true)
	_mouse_button(position, false)


func _button_center(root_node: Node, text: String) -> Vector2:
	for node in root_node.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree():
			return button.get_global_rect().get_center()
	return Vector2(-1, -1)


func _screen_of(scene: Node, id: String) -> Vector2:
	return scene.camera.unproject_position(scene.renderer.camera_relative_position(id))


func _empty_point(scene) -> Vector2:
	for point in [Vector2(640, 700), Vector2(200, 600), Vector2(1000, 660), Vector2(420, 420), Vector2(860, 520)]:
		if scene.renderer.pick(scene.camera.project_ray_normal(point), scene.pick_tolerance_angle()) == "":
			return point
	return Vector2(640, 700)


func _run_step() -> void:
	var scene := current_scene
	match step:
		0:
			_check("explore scene loaded", scene.get_script().get_global_name() == "ExploreMode")
			_key(KEY_2)
		1:
			wait = 180
		2:
			_check("key 2 focuses Mercury", scene.camera.anchor_id == "mercury")
			_check("key 2 opens the Mercury info panel", scene._info_panel.visible and scene._info_panel.body_id == "mercury")
			set_meta("scientist_before", root.get_node("Preferences").is_scientist())
			_key(KEY_M)
		3:
			_check("key M switches the depth level", root.get_node("Preferences").is_scientist() != get_meta("scientist_before"))
			_key(KEY_M)
			_click(_button_center(scene, "Guided tours"))
		4:
			_check("Guided tours button opens the menu", scene._tour_menu.visible)
			_click(_button_center(scene, "Start tour"))
		5:
			_check("Start tour button starts a tour", scene._tour_player.active)
			_key(KEY_RIGHT)
		6:
			_check("Right arrow advances the tour", scene._current_step.get("target", "") == "mercury")
			_key(KEY_ESCAPE)
		7:
			_check("Esc exits the tour", not scene._tour_player.active)
			scene.clock.paused = true
			scene.camera.aim(scene.renderer.camera_relative_position("earth"))
			wait = 180
		8:
			var earth_body = scene.model.get_body("earth")
			scene.camera.focus_on("earth", scene.renderer.mapper.radius(earth_body), scene._toward_sun("earth"), 6.0)
			scene.camera.reset_idle()
			wait = 5
		9:
			_click(_screen_of(scene, "earth"))
		10:
			_check("clicking Earth selects it", scene._selected_id == "earth")
			_click(_empty_point(scene))
		11:
			_check("clicking empty space clears the selection", scene._selected_id == "")
			_key(KEY_T)
		12:
			_check("key T switches to true scale", scene.renderer.mapper.mode == 1)
			_key(KEY_T)
			_key(KEY_F2)
			wait = 40
		13:
			_check("F2 opens the sandbox", scene.get_script().get_global_name() == "SandboxMode")
			_check("Now button hidden in sandbox", _button_center(scene, "Now") == Vector2(-1, -1))
			placed_count = scene.world.bodies.size()
			sandbox_seconds = scene.world.seconds
			_key(KEY_N)
		14:
			_check("key N does not reset the sandbox", scene.world.seconds >= sandbox_seconds)
			scene.camera.reanchor("sun", PackedFloat64Array([0.0, 500000.0, 1.0]))
			scene.camera.aim(Vector3(0.0, -1.0, -0.000002))
			_click(_button_center(scene, "Place body"))
		15:
			_check("Place body button enters placement", scene._placing)
			_mouse_button(Vector2(820, 360), true)
		16:
			_check("pressing on the plane starts a drag", scene._dragging)
			_mouse_motion(Vector2(820, 300), Vector2(0, -60))
		17:
			_check("dragging updates the launch readout", scene._launch_status.begins_with("Launch"))
			_mouse_button(Vector2(820, 300), false)
		18:
			_check("releasing launches a new body", scene.world.bodies.size() == placed_count + 1)
			_check("new body is selected", scene._selected_id.begins_with("body_"))
			_key(KEY_ESCAPE)
		19:
			_check("Esc leaves placement", not scene._placing)
			_key(KEY_DELETE)
		20:
			_check("Delete removes the selected body", scene.world.bodies.size() == placed_count)
			var rings_before: bool = root.get_node("Preferences").rings_visible
			_key(KEY_G)
			wait = 10
			set_meta("rings_before", rings_before)
		21:
			_check("key G toggles distance rings", root.get_node("Preferences").rings_visible != get_meta("rings_before"))
			_key(KEY_G)
			_key(KEY_F1)
			wait = 40
		22:
			_check("F1 returns to explore", scene.get_script().get_global_name() == "ExploreMode")
			print("FAILURES: ", failures)
			quit()

extends SceneTree

var frame := 0
var step := 0
var wait := 90
var failures := 0
var before := {}
var shots_before := []


func _initialize() -> void:
	change_scene_to_file("res://modes/explore/explore_mode.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame < wait:
		return false
	frame = 0
	wait = 10
	_run_step()
	step += 1
	return false


func _check(label: String, condition: bool) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		failures += 1


func _button(index: MouseButton, pressed: bool, position := Vector2(640, 600), factor := 1.0, ctrl := false, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.factor = factor
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	if index == MOUSE_BUTTON_LEFT and pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)


func _wheel(index: MouseButton, factor := 1.0, ctrl := false, shift := false) -> void:
	_button(index, true, Vector2(640, 600), factor, ctrl, shift)
	_button(index, false, Vector2(640, 600), factor, ctrl, shift)


func _motion(position: Vector2, relative: Vector2, mask := MOUSE_BUTTON_MASK_LEFT) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = mask
	root.push_input(event)


func _pan(delta: Vector2) -> void:
	var event := InputEventPanGesture.new()
	event.delta = delta
	event.position = Vector2(640, 600)
	root.push_input(event)


func _magnify(factor: float) -> void:
	var event := InputEventMagnifyGesture.new()
	event.factor = factor
	event.position = Vector2(640, 600)
	root.push_input(event)


func _action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	root.push_input(event)
	var release := InputEventAction.new()
	release.action = name
	release.pressed = false
	root.push_input(release)


func _state(camera) -> Dictionary:
	var o: PackedFloat64Array = camera.offset
	var distance := sqrt(o[0] * o[0] + o[1] * o[1] + o[2] * o[2])
	return {
		"distance": distance,
		"azimuth": atan2(o[0], o[2]),
		"elevation": asin(o[1] / distance),
		"speed": camera.speed_scale,
		"offset": o.duplicate(),
		"basis": camera.basis,
	}


func _moved(a: Dictionary, b: Dictionary) -> Vector3:
	var x: PackedFloat64Array = a["offset"]
	var y: PackedFloat64Array = b["offset"]
	return Vector3(x[0] - y[0], x[1] - y[1], x[2] - y[2])


func _center_error(scene) -> float:
	var anchor: Vector3 = scene.renderer.camera_relative_position(scene.camera.anchor_id)
	return scene.camera.unproject_position(anchor).distance_to(root.get_visible_rect().size * 0.5)


func _shot_directory() -> String:
	return ProjectSettings.globalize_path("res://../screenshots").simplify_path()


func _shots() -> Array:
	if not DirAccess.dir_exists_absolute(_shot_directory()):
		return []
	return Array(DirAccess.get_files_at(_shot_directory()))


func _run_step() -> void:
	var scene := current_scene
	var camera = scene.camera
	var preferences := root.get_node("Preferences")
	match step:
		0:
			preferences.set_scroll_mode(0)
			scene.clock.paused = true
			camera.aim(-Vector3(camera.offset[0], camera.offset[1], camera.offset[2]))
			before = _state(camera)
			_check("starts focused on Earth", camera.anchor_id == "earth")
			_button(MOUSE_BUTTON_LEFT, true)
			for i in 10:
				_motion(Vector2(640 + 12 * (i + 1), 600), Vector2(12, 0))
			_button(MOUSE_BUTTON_LEFT, false, Vector2(760, 600))
		1:
			var now: Dictionary = _state(camera)
			_check("left drag orbits horizontally", absf(now["azimuth"] - before["azimuth"]) > 0.3)
			_check("drag keeps the distance", absf(now["distance"] - before["distance"]) < 1e-6 * before["distance"])
			_check("drag keeps Earth centered", _center_error(scene) < 2.0)
			_check("drag does not select", scene._selected_id == "")
			before = now
			_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0)
		2:
			var now: Dictionary = _state(camera)
			_check("mouse wheel step zooms in", now["distance"] < before["distance"] * 0.95 and absf(now["elevation"] - before["elevation"]) < 1e-6)
			before = now
			for i in 5:
				_wheel(MOUSE_BUTTON_WHEEL_UP, 0.4)
		3:
			var now: Dictionary = _state(camera)
			_check("touchpad scroll orbits the focused body upward", now["elevation"] > before["elevation"] + 0.05 and absf(now["distance"] - before["distance"]) < 1e-6 * before["distance"])
			_check("touchpad orbit keeps Earth centered", _center_error(scene) < 2.0)
			before = now
			for i in 5:
				_wheel(MOUSE_BUTTON_WHEEL_RIGHT, 0.4)
		4:
			var now: Dictionary = _state(camera)
			_check("horizontal touchpad scroll orbits sideways", absf(now["azimuth"] - before["azimuth"]) > 0.05)
			before = now
			_wheel(MOUSE_BUTTON_WHEEL_DOWN, 0.4, true)
		5:
			var now: Dictionary = _state(camera)
			_check("Ctrl + scroll (pinch on Windows) zooms out", now["distance"] > before["distance"])
			before = now
			_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0, false, true)
		6:
			var now: Dictionary = _state(camera)
			_check("Shift + scroll changes flight speed only", now["speed"] > before["speed"] and absf(now["distance"] - before["distance"]) < 1e-9)
			before = now
			_pan(Vector2(8, 0))
		7:
			var now: Dictionary = _state(camera)
			_check("pan gesture orbits the focused body", absf(now["azimuth"] - before["azimuth"]) > 0.05)
			_check("pan gesture keeps the distance", absf(now["distance"] - before["distance"]) < 1e-6 * before["distance"])
			before = now
			_magnify(1.5)
			_pan(Vector2(8, 0))
		8:
			var now: Dictionary = _state(camera)
			var ratio: float = now["distance"] / before["distance"]
			_check("magnify gesture zooms in", ratio < 1.0)
			_check("magnify factor is clamped", ratio > 0.85)
			_check("pan during a pinch is ignored", absf(now["azimuth"] - before["azimuth"]) < 1e-9)
			preferences.set_scroll_mode(3)
			before = _state(camera)
			_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0)
		9:
			var now: Dictionary = _state(camera)
			_check("Move mode: wheel moves the camera", _moved(now, before).length() > 0.0)
			_check("Move mode keeps the orientation", now["basis"].is_equal_approx(before["basis"]))
			preferences.set_scroll_mode(1)
			before = now
			_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0)
		10:
			var now: Dictionary = _state(camera)
			_check("Orbit mode: mouse wheel orbits", now["elevation"] > before["elevation"] and absf(now["distance"] - before["distance"]) < 1e-6 * before["distance"])
			preferences.set_scroll_mode(2)
			before = now
			_wheel(MOUSE_BUTTON_WHEEL_DOWN, 0.4)
		11:
			_check("Zoom mode: touchpad scroll zooms", _state(camera)["distance"] > before["distance"])
			preferences.set_scroll_mode(0)
			before = _state(camera)
			_action("toggle_auto_orbit")
			wait = 30
		12:
			var now: Dictionary = _state(camera)
			_check("F9 starts the auto-orbit", camera.is_auto_orbiting() and absf(now["azimuth"] - before["azimuth"]) > 1e-4)
			_action("toggle_auto_orbit")
		13:
			_check("F9 again stops the auto-orbit", not camera.is_auto_orbiting())
			camera._idle_seconds = 25.0
			_check("idle focus starts the auto-orbit", camera.is_auto_orbiting())
			_motion(Vector2(500, 400), Vector2(3, 0), 0)
		14:
			_check("pointer input stops the idle auto-orbit", not camera.is_auto_orbiting())
			_action("toggle_diagnostics")
		15:
			_check("F4 shows the performance overlay", scene.hud.is_diagnostics_visible())
			_action("toggle_diagnostics")
			shots_before = _shots()
			_action("take_screenshot")
			wait = 30
		16:
			_check("F4 again hides the overlay", not scene.hud.is_diagnostics_visible())
			var created := _shots().filter(func(name: String) -> bool: return not shots_before.has(name))
			_check("F12 saves a screenshot", created.size() == 1)
			_check("interface is restored after the screenshot", scene.hud.is_root_visible())
			for name in created:
				DirAccess.remove_absolute(_shot_directory().path_join(name))
			if DirAccess.dir_exists_absolute(_shot_directory()) and _shots().is_empty():
				DirAccess.remove_absolute(_shot_directory())
			_action("focus_release")
		17:
			_check("F releases the focus", camera.anchor_id == "")
			before = _state(camera)
			for i in 5:
				_wheel(MOUSE_BUTTON_WHEEL_UP, 0.4)
		18:
			var now: Dictionary = _state(camera)
			_check("free flight: touchpad scroll moves the camera", _moved(now, before).length() > 0.0)
			_check("free flight: touchpad scroll keeps the orientation", now["basis"].is_equal_approx(before["basis"]))
			wait = 40
		19:
			before = _state(camera)
			_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0)
		20:
			var now: Dictionary = _state(camera)
			var forward: Vector3 = -before["basis"].z
			_check("free flight: mouse wheel moves forward", _moved(now, before).dot(forward) > 0.0)
			_action("focus_next")
			wait = 200
		21:
			_check("Tab focuses a body again", camera.anchor_id != "")
			for i in 60:
				_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0)
		22:
			var body = scene.model.get_body(camera.anchor_id)
			var radius: float = scene.renderer.mapper.radius(body)
			_check("zoom stops above the surface", _state(camera)["distance"] > radius)
			print("FAILURES: ", failures)
			quit()

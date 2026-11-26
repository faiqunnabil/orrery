extends SceneTree

const BINARY_PRESET := 1
const VIEW_ZOOM := 14.0

var frame := 0
var step := 0
var wait := 90
var failures := 0
var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	var preferences := root.get_node("Preferences")
	preferences.set_onboarding_done(true)
	preferences.set_gravity_well_visible(false)
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
		_save_failure()


func _save_failure() -> void:
	var directory := OS.get_environment("FAILURE_DIR")
	if directory == "":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var path := "%s/%s_failure_%d.jpg" % [directory, get_script().resource_path.get_file().get_basename(), failures]
	root.get_texture().get_image().save_jpg(path, 0.85)
	print("      screenshot ", path)


func _shot(name: String) -> void:
	if out_dir == "":
		return
	root.get_texture().get_image().save_jpg("%s/%s.jpg" % [out_dir, name], 0.85)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)


func _plane_point(scene, id: String) -> Vector2:
	var well = scene.renderer.gravity_well
	var body: PackedFloat64Array = scene.renderer.render_position(id)
	var center: PackedFloat64Array = scene._well_center()
	return Vector2(body[0] - center[0], body[2] - center[2])


func _run_step() -> void:
	var scene := current_scene
	var well = scene.renderer.gravity_well
	var preferences := root.get_node("Preferences")
	match step:
		0:
			_check("the gravity well starts hidden", not well.visible)
			scene.clock.paused = true
			_key(KEY_V)
		1:
			_check("V shows the gravity well", preferences.gravity_well_visible and well.visible)
			_check("the panel toggle follows the key", scene.panel._gravity_well_toggle.button_pressed)
			_check("the grid uses the preset's subdivisions", well.subdivisions() in [128, 192, 256])
			scene._select("sun")
			scene._fly_to("sun")
			wait = 200
		2:
			var sun := _plane_point(scene, "sun")
			var rim := Vector2(well.half_width * 0.9, 0.0)
			_check("the Sun's well is included", well.body_ids.has("sun"))
			_check("the grid dips under the Sun", well.depth_at(sun) > well.depth_at(rim) + well.half_width * 0.05)
			scene.camera.zoom(VIEW_ZOOM)
			wait = 60
		3:
			_shot("gravity_well_sun")
			scene._load_preset(BINARY_PRESET)
		4:
			var ids: Array = scene.world.bodies.map(func(body) -> String: return body.id)
			scene._select(ids[0])
			scene._fly_to(ids[0])
			wait = 200
		5:
			var ids: Array = scene.world.bodies.map(func(body) -> String: return body.id)
			var first := _plane_point(scene, ids[0])
			var second := _plane_point(scene, ids[1])
			var between := (first + second) * 0.5 + (second - first).orthogonal().normalized() * first.distance_to(second)
			_check("both stars of the binary dig a well", well.body_ids.has(ids[0]) and well.body_ids.has(ids[1]))
			_check("each star sits in a deeper spot than the grid beside them", well.depth_at(first) > well.depth_at(between) and well.depth_at(second) > well.depth_at(between))
			scene.camera.zoom(VIEW_ZOOM)
			wait = 60
		6:
			_shot("gravity_well_binary")
			_key(KEY_V)
		7:
			_check("V hides the gravity well again", not preferences.gravity_well_visible and not well.visible)
			print("FAILURES: ", failures)
			quit()

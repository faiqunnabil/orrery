extends SceneTree

var frame := 0
var step := 0
var wait := 90
var failures := 0
var values := {}


func _initialize() -> void:
	root.get_node("Preferences").set_onboarding_done(true)
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


func _snap(scene, id: String, radii: float) -> void:
	var body = scene.model.get_body(id)
	scene.camera.focus_on(id, scene.renderer.mapper.radius(body), scene._toward_sun(id), radii)


func _eclipse_time(scene, occluder: String, receiver: String, center: float, span: float, step_seconds: float) -> float:
	var best_t := center
	var best := INF
	var t := center - span
	while t <= center + span:
		scene.model.update(t)
		scene.renderer.compute_positions()
		var r: PackedFloat64Array = scene.renderer.render_position(receiver)
		var o: PackedFloat64Array = scene.renderer.render_position(occluder)
		var s: PackedFloat64Array = scene.renderer.render_position("sun")
		var light := Vector3(s[0] - r[0], s[1] - r[1], s[2] - r[2]).normalized()
		var offset := Vector3(o[0] - r[0], o[1] - r[1], o[2] - r[2])
		var along := offset.dot(light)
		if along > 0.0:
			var miss := (offset - light * along).length()
			if miss < best:
				best = miss
				best_t = t
		t += step_seconds
	return best_t


func _run_step() -> void:
	var scene := current_scene
	var quality := root.get_node("Quality")
	var visual = scene.renderer._visuals
	match step:
		0:
			quality.set_preset(2)
			scene.clock.paused = true
			_snap(scene, "earth", 1.08)
		1:
			values["near"] = scene.renderer.mesh_segments("earth")
			_check("High preset: Earth up close uses 128 segments", values["near"] == 128)
			_snap(scene, "earth", 4.0)
		2:
			values["mid"] = scene.renderer.mesh_segments("earth")
			_check("Earth at 4 radii uses fewer segments", values["mid"] < values["near"] and values["mid"] >= 32)
			_check("distant Neptune uses the minimum mesh", scene.renderer.mesh_segments("neptune") == 16)
			_check("the Moon is lit with its elevation normal map", visual["moon"]._material.get_shader_parameter("has_normal_texture"))
			_check("Mercury keeps the albedo bump fallback", not visual["mercury"]._material.get_shader_parameter("has_normal_texture"))
			_check("focus mesh is shown in the overlay summary", scene._focus_mesh_summary().begins_with(str(values["mid"])))
			quality.set_preset(0)
		3:
			_check("Low preset caps the mesh at 40 segments", scene.renderer.mesh_segments("earth") <= 40)
			quality.set_preset(1)
			scene._set_scale_mode(ScaleMapper.Mode.COMPRESSED)
			var center := Astro.unix_to_simulation_seconds(Time.get_unix_time_from_datetime_string("2026-11-19T00:00:00"))
			scene.clock.seconds = _eclipse_time(scene, "io", "jupiter", center + 2.0 * 86400.0, 2.0 * 86400.0, 600.0)
			_snap(scene, "jupiter", 3.2)
		4:
			_check("Io casts a shadow on Jupiter", visual["jupiter"]._eclipse_count >= 1)
			scene.clock.seconds += 0.5 * 86400.0
		5:
			_check("the shadow leaves Jupiter half a day later", visual["jupiter"]._eclipse_count == 0)
			scene._set_scale_mode(ScaleMapper.Mode.TRUE_SCALE)
			var center := Astro.unix_to_simulation_seconds(Time.get_unix_time_from_datetime_string("2026-03-03T11:33:00"))
			scene.clock.seconds = _eclipse_time(scene, "earth", "moon", center, 86400.0, 120.0)
			_snap(scene, "moon", 5.0)
		6:
			_check("Earth's shadow falls on the Moon during the March 2026 lunar eclipse", visual["moon"]._eclipse_count == 1)
			quality.set_preset(0)
		7:
			_check("Low preset turns eclipse shadows off", visual["moon"]._eclipse_count == 0)
			quality.set_preset(1)
			scene._set_scale_mode(ScaleMapper.Mode.COMPRESSED)
			print("FAILURES: ", failures)
			quit()

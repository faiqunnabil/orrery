extends SceneTree

const PERIHELION := "1986-02-09T00:00:00"
const FAR_AWAY := "2026-01-01T00:00:00"
const PAST_PERIHELIA := ["1835-11-16T10:33:00", "1910-04-20T04:17:00"]
const PERIHELION_TOLERANCE_DAYS := 1.0
const J2000_UNIX := 946728000.0

var frame := 0
var step := 0
var wait := 90
var failures := 0
var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	root.get_node("Preferences").set_onboarding_done(true)
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


func _shot(name: String) -> void:
	if out_dir == "":
		return
	root.get_texture().get_image().save_jpg("%s/%s.jpg" % [out_dir, name], 0.85)


func _vector(scene, id: String) -> Vector3:
	var p: PackedFloat64Array = scene.renderer.render_position(id)
	return Vector3(p[0], p[1], p[2])


func _seconds(text: String) -> float:
	return Time.get_unix_time_from_datetime_string(text) - J2000_UNIX


func _run_step() -> void:
	var scene := current_scene
	var tail = scene.renderer.comet_tail("halley")
	match step:
		0:
			var halley = scene.model.get_body("halley")
			_check("Halley's Comet is in the catalog with a tail", halley != null and tail != null)
			_check("the orbit has a JPL solution for each return", halley.orbit.segment_count() == 3)
			var on_time := true
			for date: String in PAST_PERIHELIA:
				on_time = on_time and _days_from_perihelion(halley.orbit, _seconds(date)) < PERIHELION_TOLERANCE_DAYS
			_check("the 1835 and 1910 perihelia fall within a day of their real dates", on_time)
			_check("the nucleus is stretched to its 15 by 8 km shape", halley.shape.x / halley.shape.y > 1.8)
			scene.clock.paused = true
			scene.clock.seconds = _seconds(PERIHELION)
		1:
			var distance_au: float = scene.model.relative_km["halley"].length() / Astro.AU_KM
			_check("the comet is 0.575 AU from the Sun at its 1986 perihelion", absf(distance_au - 0.575) < 0.02)
			_check("the tail is fully active near the Sun", tail.visible and tail.activity > 0.95 and tail.length > 0.0)
			_check("the quality preset sets the particle count", tail.particle_count() >= 500)
			var away: Vector3 = (_vector(scene, "halley") - _vector(scene, "sun")).normalized()
			_check("the ion tail points straight away from the Sun", rad_to_deg(tail.ion_direction().angle_to(away)) < 1.0)
			var lag: float = rad_to_deg(tail.dust_direction().angle_to(tail.ion_direction()))
			_check("the dust tail curves back from the ion tail", lag > 5.0 and lag < 45.0)
			var world = load("res://core/sandbox_world.gd").from_solar_system(scene.model, scene.clock.seconds)
			_check("the Sandbox solar system includes the comet", world.index_of("halley") >= 0 and world.index_of("pluto") >= 0)
			scene._focus_body("halley")
			wait = 220
		2:
			_check("focusing the comet frames its whole tail", scene.camera.anchor_id == "halley" and _camera_distance(scene) > tail.length)
			_shot("comet_halley")
			scene.clock.seconds = _seconds(FAR_AWAY)
		3:
			_check("the tail disappears far from the Sun", not tail.visible and tail.length == 0.0)
			scene._fly_to("halley", 3.0)
			wait = 200
		4:
			_shot("comet_nucleus")
			change_scene_to_file("res://modes/sandbox/sandbox_mode.tscn")
			wait = 150
		5:
			scene.clock.paused = true
			scene._install_world(load("res://core/sandbox_world.gd").from_solar_system(scene.model, _seconds(PERIHELION)))
			scene._select("halley")
			scene._fly_to("halley")
			wait = 200
		6:
			var sandbox_tail = scene.renderer.comet_tail("halley")
			_check("the Sandbox draws Halley's tails near perihelion", sandbox_tail != null and sandbox_tail.visible and sandbox_tail.activity > 0.9)
			var star: PackedFloat64Array = scene.renderer.render_position("sun")
			var comet: PackedFloat64Array = scene.renderer.render_position("halley")
			var away := Vector3(comet[0] - star[0], comet[1] - star[1], comet[2] - star[2]).normalized()
			_check("the Sandbox ion tail points away from the Sun", rad_to_deg(sandbox_tail.ion_direction().angle_to(away)) < 1.0)
			_check("the Sandbox lists the comet by type", scene._search_items().any(func(item: Dictionary) -> bool: return item["id"] == "halley" and item["detail"] == "Comet"))
			print("FAILURES: ", failures)
			quit()


func _days_from_perihelion(orbit, seconds: float) -> float:
	var best := INF
	var best_distance := INF
	for hours in range(-24 * 20, 24 * 20 + 1, 2):
		var t := seconds + hours * 3600.0
		var distance: float = orbit.position_km(t / Astro.SECONDS_PER_CENTURY).length()
		if distance < best_distance:
			best_distance = distance
			best = absf(hours / 24.0)
	return best


func _camera_distance(scene) -> float:
	var offset: PackedFloat64Array = scene.camera.offset
	return Vector3(offset[0], offset[1], offset[2]).length()

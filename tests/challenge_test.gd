extends SceneTree

const AU_KM := 149597870.7
const FAST_STEP := 6
const MOON_DISTANCE_KM := 1.5e6
const SLINGSHOT_DISTANCE_AU := 0.6
const SLINGSHOT_ANGLE_DEG := -44.0
const SLINGSHOT_SPEED_RATIO := 1.26
const FIGURE_EIGHT_PRESET := 4
const FIGURE_EIGHT_PERIOD_DAYS := 367.735

var frame := 0
var step := 0
var wait := 90
var failures := 0
var out_dir := ""
var deadline := 0
var saved := {}


func _initialize() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	var preferences := root.get_node("Preferences")
	preferences.set_onboarding_done(true)
	preferences.completed_challenges = PackedStringArray()
	change_scene_to_file("res://modes/sandbox/sandbox_mode.tscn")


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


func _shot(name: String) -> void:
	if out_dir == "":
		return
	root.get_texture().get_image().save_jpg("%s/%s.jpg" % [out_dir, name], 0.85)


func _index(id: String) -> int:
	for index in current_scene._challenges.size():
		if current_scene._challenges[index]["id"] == id:
			return index
	return -1


func _launch(center_id: String, distance_km: float, speed_ratio: float) -> void:
	var world = current_scene.world
	var simulation = world.simulation
	var center: int = world.index_of(center_id)
	var origin = simulation.position_of(center)
	var drift = simulation.velocity_of(center)
	var circular := sqrt(simulation.gm[center] / distance_km)
	var position = origin.plus(DVec3.new(distance_km, 0.0, 0.0))
	var velocity = drift.plus(DVec3.new(0.0, circular * speed_ratio, 0.0))
	world.add_custom_body("Probe", "planet", Color.WHITE, "res://assets/textures/bodies/mars.jpg", false, position, velocity, 5.9722e24, 6371.0)


func _launch_at_angle(center_id: String, distance_km: float, angle_deg: float, speed_ratio: float) -> void:
	var world = current_scene.world
	var simulation = world.simulation
	var center: int = world.index_of(center_id)
	var angle := deg_to_rad(angle_deg)
	var circular := sqrt(simulation.gm[center] / distance_km)
	var position = simulation.position_of(center).plus(DVec3.new(cos(angle) * distance_km, sin(angle) * distance_km, 0.0))
	var velocity = simulation.velocity_of(center).plus(DVec3.new(-sin(angle) * circular * speed_ratio, cos(angle) * circular * speed_ratio, 0.0))
	world.add_custom_body("Probe", "asteroid", Color.WHITE, "res://assets/textures/bodies/moon.jpg", false, position, velocity, 1.0e15, 10.0)


func _star_positions() -> Array:
	var positions: Array = []
	for id in ["star_a", "star_b", "star_c"]:
		var point = current_scene.world.simulation.position_of(current_scene.world.index_of(id))
		positions.append(Vector3(point.x, point.y, point.z))
	return positions


func _fast() -> void:
	current_scene.clock.step_index = FAST_STEP


func _judge():
	return current_scene._judge


func _run_step() -> void:
	var scene := current_scene
	var preferences := root.get_node("Preferences")
	match step:
		0:
			_check("five challenges are offered", scene._challenges.size() == 5)
			scene.panel.show_page(3)
		1:
			_shot("challenge_list")
			scene._start_challenge(_index("orbit"))
			wait = 120
		2:
			_check("starting a challenge sets up its single star", scene.world.bodies.size() == 1 and scene.world.index_of("star") >= 0)
			_check("the panel shows the active challenge", scene.panel.is_showing_challenge())
			_check("the judge waits for a launch", _judge().state == 0 and _judge().status == "Launch a body to begin.")
			_launch("star", AU_KM, 0.0)
			_fast()
			wait = 120
		3:
			_check("a body that falls into the star is reported as a crash", _judge().state == 0 and _judge().status.begins_with("That body crashed"))
			_launch("star", AU_KM, 1.0)
			deadline = 40
		4:
			if _judge().state != 2 and deadline > 0:
				deadline -= 1
				step -= 1
				return
			_check("a circular orbit completes the round trip", _judge().state == 2)
			_check("completing it is remembered", preferences.is_challenge_complete("orbit"))
			_check("the toast congratulates the player", scene.hud._toast_label.text.contains("Round trip"))
			scene._select("star")
			_check("selecting a body keeps the challenge on screen", scene.panel._page == 3 and scene.panel.is_showing_challenge())
			_shot("challenge_complete")
			scene._start_challenge(_index("ellipse"))
		5:
			_launch("star", AU_KM, 1.0)
			_fast()
			wait = 30
		6:
			_check("a circle is rejected with its eccentricity", _judge().state == 0 and _judge().status.begins_with("Eccentricity"))
			_launch("star", AU_KM, 1.3)
			deadline = 60
		7:
			if _judge().state != 2 and deadline > 0:
				deadline -= 1
				step -= 1
				return
			_check("an orbit with eccentricity 0.69 completes the stretched orbit", _judge().state == 2)
			scene._start_challenge(_index("escape"))
		8:
			_launch("star", AU_KM, 1.2)
			_fast()
			wait = 30
		9:
			_check("a bound launch is told to go faster", _judge().state == 0 and _judge().status.begins_with("That body is still bound"))
			_launch("star", AU_KM, 1.6)
			deadline = 60
		10:
			if _judge().state != 2 and deadline > 0:
				deadline -= 1
				step -= 1
				return
			_check("an escape launch breaks free", _judge().state == 2)
			scene._start_challenge(_index("moon"))
			wait = 120
		11:
			_check("the moon challenge sets up a star and a giant planet", scene.world.bodies.size() == 2 and scene.world.index_of("giant") >= 0)
			_check("the camera frames the giant planet", scene.camera.anchor_id == "giant")
			_launch("giant", MOON_DISTANCE_KM, 1.0)
			scene.clock.step_index = 4
			deadline = 60
		12:
			if _judge().state != 2 and deadline > 0:
				deadline -= 1
				step -= 1
				return
			_check("a moon on a circular orbit around the planet completes the challenge", _judge().state == 2)
			scene._start_challenge(_index("slingshot"))
			_check("the gravity assist starts with time paused for aiming", scene.clock.paused)
			wait = 60
		13:
			_launch_at_angle("star", SLINGSHOT_DISTANCE_AU * AU_KM, SLINGSHOT_ANGLE_DEG, SLINGSHOT_SPEED_RATIO)
			scene.clock.paused = false
			_fast()
			deadline = 80
		14:
			if _judge().state != 2 and deadline > 0:
				deadline -= 1
				step -= 1
				return
			_check("passing just behind the giant planet completes the gravity assist", _judge().state == 2)
			_check("all five challenges are remembered", preferences.completed_challenges.size() == 5)
			scene._leave_challenge()
		15:
			_check("leaving returns to the challenge list", not scene.panel.is_showing_challenge() and not _judge().is_active())
			scene._load_preset(FIGURE_EIGHT_PRESET)
			scene.clock.paused = true
			wait = 30
		16:
			_check("the figure-eight preset loads three equal stars", scene.world.bodies.size() == 3 and scene.world.index_of("star_c") >= 0)
			saved["start"] = _star_positions()
			saved["seconds"] = scene.world.seconds
			scene.clock.paused = false
			scene.clock.step_index = FAST_STEP - 1
			deadline = 120
		17:
			if scene.world.seconds - saved["seconds"] < FIGURE_EIGHT_PERIOD_DAYS * 86400.0 and deadline > 0:
				deadline -= 1
				step -= 1
				return
			scene.clock.paused = true
			scene.world.advance(saved["seconds"] + FIGURE_EIGHT_PERIOD_DAYS * 86400.0 - scene.world.seconds, 1000000000)
			var drift := 0.0
			var now: Array = _star_positions()
			for index in 3:
				drift = maxf(drift, now[index].distance_to(saved["start"][index]))
			_check("after one period every star returns within 0.05 AU of its start", drift < 0.05 * AU_KM)
			print("FAILURES: ", failures)
			quit()

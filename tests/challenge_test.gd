extends SceneTree

const AU_KM := 149597870.7
const FAST_STEP := 6
const MOON_DISTANCE_KM := 1.5e6

var frame := 0
var step := 0
var wait := 90
var failures := 0
var out_dir := ""
var deadline := 0


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


func _fast() -> void:
	current_scene.clock.step_index = FAST_STEP


func _judge():
	return current_scene._judge


func _run_step() -> void:
	var scene := current_scene
	var preferences := root.get_node("Preferences")
	match step:
		0:
			_check("four challenges are offered", scene._challenges.size() == 4)
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
			_check("all four challenges are remembered", preferences.completed_challenges.size() == 4)
			scene._leave_challenge()
		13:
			_check("leaving returns to the challenge list", not scene.panel.is_showing_challenge() and not _judge().is_active())
			print("FAILURES: ", failures)
			quit()

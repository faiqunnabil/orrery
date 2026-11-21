class_name ChallengeJudge
extends RefCounted

signal completed(challenge_id: String)

enum State { WAITING, TRACKING, COMPLETE }

const DATA_PATH := "res://data/challenges.json"
const DEFAULT_DISTANCE_FACTOR := 3.0

var challenge: Dictionary = {}
var state := State.WAITING
var target_id := ""
var progress := 0.0
var status := ""
var status_args: Array = []

var _known: Dictionary = {}
var _angle := 0.0
var _last_angle := 0.0
var _start_distance := 0.0


static func load_challenges() -> Array[Dictionary]:
	var challenges: Array[Dictionary] = []
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open challenges: %s" % DATA_PATH)
		return challenges
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for entry: Variant in parsed:
			if entry is Dictionary:
				challenges.append(entry)
	return challenges


static func orbit_eccentricity(position: DVec3, velocity: DVec3, mu: float) -> float:
	var radius := position.length()
	var speed_squared := velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z
	var radial := position.x * velocity.x + position.y * velocity.y + position.z * velocity.z
	var vector := position.scaled(speed_squared - mu / radius).minus(velocity.scaled(radial)).scaled(1.0 / mu)
	return vector.length()


func is_active() -> bool:
	return not challenge.is_empty()


func start(value: Dictionary, world: SandboxWorld) -> void:
	challenge = value
	state = State.WAITING
	target_id = ""
	progress = 0.0
	_known.clear()
	for body in world.bodies:
		_known[body.id] = true
	_set_status("Launch a body to begin.")


func stop() -> void:
	challenge = {}
	state = State.WAITING
	target_id = ""
	progress = 0.0


func update(world: SandboxWorld) -> void:
	if challenge.is_empty() or state == State.COMPLETE:
		return
	for body in world.bodies:
		if not _known.has(body.id):
			_known[body.id] = true
			_track(world, body.id)
	if target_id == "":
		return
	var simulation := world.simulation
	var center := world.index_of(str(challenge.get("center", "")))
	if center < 0:
		_wait("The central body is gone. Restart the challenge.")
		return
	var target := world.index_of(target_id)
	if target < 0:
		_wait("That body crashed. Launch another one.")
		return
	var position := simulation.position_of(target).minus(simulation.position_of(center))
	var velocity := simulation.velocity_of(target).minus(simulation.velocity_of(center))
	var mu: float = simulation.gm[center] + simulation.gm[target]
	var distance := position.length()
	var energy := 0.5 * (velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z) - mu / distance
	if challenge.get("type", "") == "escape":
		_judge_escape(energy, distance)
		return
	if energy >= 0.0:
		_wait("That body is escaping. Launch it slower.")
		return
	if challenge.get("type", "") == "moon" and distance > _hill_radius(world, center):
		_wait("That body is outside the planet's pull. Launch it closer and slower.")
		return
	if challenge.get("type", "") == "ellipse":
		var eccentricity := orbit_eccentricity(position, velocity, mu)
		if eccentricity < float(challenge.get("min_eccentricity", 0.0)) or eccentricity > float(challenge.get("max_eccentricity", 1.0)):
			_wait(
				"Eccentricity %s. Aim for %s to %s.",
				[
					BodyFacts.format_number(eccentricity, 2),
					BodyFacts.format_number(float(challenge.get("min_eccentricity", 0.0)), 1),
					BodyFacts.format_number(float(challenge.get("max_eccentricity", 1.0)), 1)
				]
			)
			return
	var angle := atan2(position.y, position.x)
	_angle += wrapf(angle - _last_angle, -PI, PI)
	_last_angle = angle
	progress = clampf(absf(_angle) / TAU, 0.0, 1.0)
	if progress >= 1.0:
		_complete()
	else:
		_set_status("Orbit progress: %d%%", [int(progress * 100.0)])


func _judge_escape(energy: float, distance: float) -> void:
	if energy < 0.0:
		_wait("That body is still bound to the star. Launch it faster.")
		return
	var goal := _start_distance * float(challenge.get("distance_factor", DEFAULT_DISTANCE_FACTOR))
	progress = clampf((distance - _start_distance) / maxf(goal - _start_distance, 1.0), 0.0, 1.0)
	if distance >= goal:
		_complete()
	else:
		_set_status("Escaping: %d%% of the way", [int(progress * 100.0)])


func _track(world: SandboxWorld, id: String) -> void:
	var center := world.index_of(str(challenge.get("center", "")))
	var target := world.index_of(id)
	if center < 0 or target < 0:
		return
	var offset := world.simulation.position_of(target).minus(world.simulation.position_of(center))
	target_id = id
	state = State.TRACKING
	progress = 0.0
	_angle = 0.0
	_last_angle = atan2(offset.y, offset.x)
	_start_distance = offset.length()
	_set_status("Tracking the new body.")


func _hill_radius(world: SandboxWorld, center: int) -> float:
	var primary := world.index_of(str(challenge.get("primary", "")))
	if primary < 0:
		return INF
	var simulation := world.simulation
	var separation := simulation.position_of(center).minus(simulation.position_of(primary)).length()
	return separation * pow(simulation.gm[center] / (3.0 * simulation.gm[primary]), 1.0 / 3.0)


func _wait(message: String, args: Array = []) -> void:
	target_id = ""
	state = State.WAITING
	progress = 0.0
	_set_status(message, args)


func _complete() -> void:
	state = State.COMPLETE
	progress = 1.0
	_set_status("Challenge complete!")
	completed.emit(str(challenge.get("id", "")))


func _set_status(message: String, args: Array = []) -> void:
	status = message
	status_args = args

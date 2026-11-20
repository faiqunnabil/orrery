extends SceneTree

const START := 8.4e8
const SPAN_SECONDS := 30.0 * 86400.0
const REFERENCE_STEP := 60.0
const UNLIMITED_BUDGET := 1 << 40
const FRAME_BUDGET_USEC := 5000
const FRAMES := 60
const MAX_ENERGY_DRIFT := 1.0e-6

var failures := 0


func _initialize() -> void:
	var model := SolarSystemModel.new(BodyCatalog.load_bodies())
	model.update(START)
	var split_world := SandboxWorld.from_solar_system(model, START)
	var split = split_world.simulation
	var reference = SandboxWorld.from_solar_system(model, START).simulation
	var global = SandboxWorld.from_solar_system(model, START).simulation
	global.set_fixed_step_seconds(global.timestep_limit())
	_advance_all(global, SPAN_SECONDS)
	var energy_start: float = split.total_energy_joules()
	_advance_all(split, SPAN_SECONDS)
	_check("split stepping is used for moons", split.uses_split_steps())
	reference.set_fixed_step_seconds(REFERENCE_STEP)
	_advance_all(reference, SPAN_SECONDS)
	var split_error := _worst_error(split, reference)
	var global_error := _worst_error(global, reference)
	print("  largest difference from a 60 s reference after 30 days: split %.0f km, single step %.0f km" % [split_error, global_error])
	_check("split stepping is at least as accurate as single-step Verlet", split_error <= global_error)
	var drift := absf(split.total_energy_joules() / energy_start - 1.0)
	print("  relative energy drift after 30 days: " + String.num_scientific(drift))
	_check("energy drift stays below " + String.num_scientific(MAX_ENERGY_DRIFT), drift < MAX_ENERGY_DRIFT)
	var fast_world := SandboxWorld.from_solar_system(model, START)
	var advanced := 0.0
	for frame in FRAMES:
		advanced += fast_world.simulation.advance(1.0e9, FRAME_BUDGET_USEC)
	var days_per_second := advanced / 86400.0 / (FRAMES / 60.0)
	print("  simulated speed with a 5 ms budget at 60 FPS: %.0f days per second" % days_per_second)
	_check("the solar system with moons runs faster than 50 days per second", days_per_second > 50.0)
	var collision := NBodySimulation.new()
	collision.add_body(DVec3.new(0, 0, 0), DVec3.new(0, 0, 0), 1.989e30, 695700.0)
	collision.add_body(DVec3.new(5.0e7, 0, 0), DVec3.new(0, 51.5, 0), 5.97e24, 6371.0)
	collision.add_body(DVec3.new(5.0e7 + 384400.0, 0, 0), DVec3.new(0, 52.5, 0), 7.35e22, 1737.0)
	collision.add_body(DVec3.new(5.0e7 + 60000.0, 0, 0), DVec3.new(0, 51.5, 0), 1.0e20, 300.0)
	_advance_all(collision, 2.0 * 86400.0)
	_check("a small body falling into Earth merges", collision.count == 3)
	print("FAILURES: ", failures)
	quit()


func _worst_error(simulation, reference) -> float:
	var worst := 0.0
	for index in simulation.count:
		worst = maxf(worst, simulation.position_of(index).minus(reference.position_of(index)).length())
	return worst


func _advance_all(simulation, seconds: float) -> void:
	var remaining := seconds
	while remaining > 1.0e-6:
		remaining -= simulation.advance(remaining, UNLIMITED_BUDGET)


func _check(label: String, condition: bool) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		failures += 1

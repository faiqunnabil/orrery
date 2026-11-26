class_name EclipseSearch
extends RefCounted

enum Kind { SOLAR, LUNAR }
enum Type { PARTIAL, TOTAL, ANNULAR }

const SYNODIC_SECONDS := 29.530589 * Astro.SECONDS_PER_DAY
const MEAN_PHASE_RATE := TAU / SYNODIC_SECONDS
const SYZYGY_TOLERANCE_SECONDS := 5.0
const SYZYGY_ITERATIONS := 12
const GREATEST_WINDOW_SECONDS := 6.0 * 3600.0
const GREATEST_TOLERANCE_SECONDS := 20.0
const MIN_GAP_SECONDS := 2.0 * 3600.0
const MAX_SYZYGIES := 60
const SHADOW_ENLARGEMENT := 1.02
const GOLDEN := 0.6180339887498949

var _sun: BodyDefinition
var _earth: BodyDefinition
var _moon: BodyDefinition


func _init(model: SolarSystemModel) -> void:
	_sun = model.get_body("sun")
	_earth = model.get_body("earth")
	_moon = model.get_body("moon")


static func describe(eclipse: Dictionary) -> String:
	if eclipse.is_empty():
		return ""
	var lunar: bool = eclipse.get("kind") == Kind.LUNAR
	var type: int = eclipse.get("type")
	if lunar:
		return "Total lunar eclipse" if type == Type.TOTAL else "Partial lunar eclipse"
	match type:
		Type.TOTAL:
			return "Total solar eclipse"
		Type.ANNULAR:
			return "Annular solar eclipse"
	return "Partial solar eclipse"


func find(from_seconds: float, direction: int, min_seconds: float, max_seconds: float) -> Dictionary:
	var step := 1 if direction >= 0 else -1
	var phase := _phase(from_seconds)
	var remaining := fposmod(-phase, PI) if step > 0 else fposmod(phase, PI)
	var guess := from_seconds + step * remaining / MEAN_PHASE_RATE
	for _index in MAX_SYZYGIES:
		var syzygy := _refine_syzygy(guess)
		if syzygy < min_seconds or syzygy > max_seconds:
			return {}
		var full := absf(_phase(syzygy)) > PI * 0.5
		var eclipse := _eclipse_near(syzygy, full)
		if not eclipse.is_empty() and step * (eclipse["seconds"] - from_seconds) > MIN_GAP_SECONDS:
			return eclipse
		guess = syzygy + step * SYNODIC_SECONDS * 0.5
	return {}


func _positions(seconds: float) -> Array[Vector3]:
	var centuries := seconds / Astro.SECONDS_PER_CENTURY
	var earth := _earth.orbit.position_km(centuries)
	var moon := _moon.orbit.position_km(centuries)
	return [Vector3(earth.x, earth.y, earth.z), Vector3(moon.x, moon.y, moon.z)]


func _phase(seconds: float) -> float:
	var positions := _positions(seconds)
	var sun := -positions[0]
	var moon := positions[1]
	return atan2(sun.x * moon.y - sun.y * moon.x, sun.x * moon.x + sun.y * moon.y)


func _refine_syzygy(guess: float) -> float:
	var seconds := guess
	var goal := PI if absf(_phase(guess)) > PI * 0.5 else 0.0
	for _index in SYZYGY_ITERATIONS:
		var correction := wrapf(goal - _phase(seconds), -PI, PI) / MEAN_PHASE_RATE
		seconds += correction
		if absf(correction) < SYZYGY_TOLERANCE_SECONDS:
			break
	return seconds


func _eclipse_near(syzygy: float, full: bool) -> Dictionary:
	var low := syzygy - GREATEST_WINDOW_SECONDS
	var high := syzygy + GREATEST_WINDOW_SECONDS
	var left := high - GOLDEN * (high - low)
	var right := low + GOLDEN * (high - low)
	var left_miss: float = _shadow(left, full)["miss"]
	var right_miss: float = _shadow(right, full)["miss"]
	while high - low > GREATEST_TOLERANCE_SECONDS:
		if left_miss < right_miss:
			high = right
			right = left
			right_miss = left_miss
			left = high - GOLDEN * (high - low)
			left_miss = _shadow(left, full)["miss"]
		else:
			low = left
			left = right
			left_miss = right_miss
			right = low + GOLDEN * (high - low)
			right_miss = _shadow(right, full)["miss"]
	var greatest := (low + high) * 0.5
	var shadow := _shadow(greatest, full)
	if shadow["type"] < 0:
		return {}
	return {"kind": Kind.LUNAR if full else Kind.SOLAR, "type": shadow["type"], "seconds": greatest}


func _shadow(seconds: float, full: bool) -> Dictionary:
	var positions := _positions(seconds)
	var earth := positions[0]
	var moon := positions[1]
	var sun_radius := _sun.radius_km
	var earth_radius := _earth.radius_km
	var moon_radius := _moon.radius_km
	if full:
		var axis := earth.normalized()
		var along := moon.dot(axis)
		var miss := (moon - axis * along).length()
		var distance := earth.length()
		var umbra := (earth_radius - along * (sun_radius - earth_radius) / distance) * SHADOW_ENLARGEMENT
		var type := -1
		if along > 0.0 and miss + moon_radius <= umbra:
			type = Type.TOTAL
		elif along > 0.0 and miss - moon_radius < umbra:
			type = Type.PARTIAL
		return {"miss": miss if along > 0.0 else INF, "type": type}
	var moon_absolute := earth + moon
	var axis := moon_absolute.normalized()
	var along := -moon.dot(axis)
	var miss := (-moon - axis * along).length()
	var distance := moon_absolute.length()
	var umbra := moon_radius - along * (sun_radius - moon_radius) / distance
	var penumbra := moon_radius + along * (sun_radius + moon_radius) / distance
	var type := -1
	if along > 0.0 and miss < earth_radius + absf(umbra):
		type = Type.TOTAL if umbra > 0.0 else Type.ANNULAR
	elif along > 0.0 and miss < earth_radius + penumbra:
		type = Type.PARTIAL
	return {"miss": miss if along > 0.0 else INF, "type": type}

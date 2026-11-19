class_name EclipseFinder
extends RefCounted

const MAX_OCCLUDERS := 4
const MIN_RECEIVER_ANGLE := 0.004
const ATMOSPHERE_GLOW := 1.0

var centers := PackedFloat64Array()
var radii := PackedFloat64Array()
var glows := PackedFloat32Array()
var casts := PackedByteArray()

var occluders := PackedVector4Array()
var occluder_glows := PackedFloat32Array()


func resize(count: int) -> void:
	centers.resize(count * 3)
	radii.resize(count)
	glows.resize(count)
	casts.resize(count)


func set_body(index: int, center: PackedFloat64Array, radius: float, can_cast: bool, glow: float) -> void:
	centers[index * 3] = center[0]
	centers[index * 3 + 1] = center[1]
	centers[index * 3 + 2] = center[2]
	radii[index] = radius
	casts[index] = 1 if can_cast else 0
	glows[index] = glow


static func is_visible_enough(camera_relative: Vector3, placed_radius: float) -> bool:
	var distance := camera_relative.length()
	return distance > placed_radius and placed_radius / distance >= MIN_RECEIVER_ANGLE


func find(receiver: int, light: Vector3, sun_angular_radius: float) -> int:
	occluders.clear()
	occluder_glows.clear()
	var receiver_radius := radii[receiver]
	if receiver_radius <= 0.0 or light == Vector3.ZERO:
		return 0
	var spread := tan(sun_angular_radius)
	var candidates: Array = []
	var rx := centers[receiver * 3]
	var ry := centers[receiver * 3 + 1]
	var rz := centers[receiver * 3 + 2]
	for index in radii.size():
		if index == receiver or casts[index] == 0:
			continue
		var offset := Vector3(
			(centers[index * 3] - rx) / receiver_radius,
			(centers[index * 3 + 1] - ry) / receiver_radius,
			(centers[index * 3 + 2] - rz) / receiver_radius
		)
		var along := offset.dot(light)
		if along <= 0.0:
			continue
		var occluder_radius := radii[index] / receiver_radius
		var miss := (offset - light * along).length()
		if miss >= 1.0 + occluder_radius + along * spread:
			continue
		candidates.append([miss, Vector4(offset.x, offset.y, offset.z, occluder_radius), glows[index]])
	if candidates.size() > MAX_OCCLUDERS:
		candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		candidates.resize(MAX_OCCLUDERS)
	for candidate: Array in candidates:
		occluders.append(candidate[1])
		occluder_glows.append(candidate[2])
	return occluders.size()

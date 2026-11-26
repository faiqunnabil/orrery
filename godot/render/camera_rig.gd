class_name CameraRig
extends Camera3D

signal flight_finished

const DEFAULT_FOV := 55.0
const LOOK_SENSITIVITY := 0.0025
const MAX_PITCH := 1.5533
const SPEED_PER_DISTANCE := 1.2
const BOOST_FACTOR := 6.0
const MIN_SPEED := 0.0005
const SPEED_SCALE_STEP := 1.2
const MIN_SPEED_SCALE := 0.01
const MAX_SPEED_SCALE := 100.0
const FOCUS_DISTANCE_RADII := 4.0
const FOCUS_ELEVATION := 0.25
const FLIGHT_DURATION := 2.4
const DRAG_THRESHOLD := 6.0
const DRAG_ORBIT_SENSITIVITY := 0.006
const WHEEL_ORBIT_STEP := 0.06
const PAN_GESTURE_STEPS := 0.2
const PAN_MOVE_SENSITIVITY := 0.0055
const WHEEL_PAN_UNITS := 5.0
const ZOOM_STEP := 1.15
const MAX_ELEVATION := 1.48
const MIN_SURFACE_GAP := 0.05
const MAX_ORBIT_DISTANCE := 5.0e7
const FREE_ZOOM_FRACTION := 0.2
const TOUCHPAD_HOLD_MSEC := 400
const PINCH_HOLD_MSEC := 150
const PINCH_SENSITIVITY := 0.6
const PINCH_FACTOR_MIN := 0.8
const PINCH_FACTOR_MAX := 1.25
const WAYLAND_PAN_SCALE := 0.35
const IDLE_ORBIT_DELAY := 20.0
const AUTO_ORBIT_SPEED := 0.045

var anchor_id := ""
var offset := PackedFloat64Array([0.0, 0.0, 30.0])
var speed_scale := 1.0
var drag_orbit_enabled := true
var auto_orbit_allowed := true

var _yaw := 0.0
var _pitch := 0.0
var _looking := false
var _dragging := false
var _drag_travel := 0.0
var _surface_distance := 1.0
var _touchpad_until_msec := 0
var _pinch_until_msec := 0
var _pan_scale := 1.0
var _manual_auto_orbit := false
var _idle_seconds := 0.0
var _flying := false
var _flight_elapsed := 0.0
var _flight_duration := FLIGHT_DURATION
var _flight_start_offset := PackedFloat64Array([0.0, 0.0, 0.0])
var _flight_target_offset := PackedFloat64Array([0.0, 0.0, 0.0])
var _flight_start_rotation := Quaternion.IDENTITY
var _flight_target_rotation := Quaternion.IDENTITY


func _ready() -> void:
	fov = DEFAULT_FOV
	if DisplayServer.get_name() == "Wayland":
		_pan_scale = WAYLAND_PAN_SCALE


func is_flying() -> bool:
	return _flying


func is_auto_orbiting() -> bool:
	if _flying or _dragging or _looking or not drag_orbit_enabled or not auto_orbit_allowed:
		return false
	if _manual_auto_orbit:
		return true
	return anchor_id != "" and _idle_seconds >= IDLE_ORBIT_DELAY


func toggle_auto_orbit() -> bool:
	_manual_auto_orbit = not _manual_auto_orbit
	if not _manual_auto_orbit:
		_idle_seconds = 0.0
	return _manual_auto_orbit


func reset_idle() -> void:
	_idle_seconds = 0.0


func world_position(anchor_position: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array(
		[anchor_position[0] + offset[0], anchor_position[1] + offset[1], anchor_position[2] + offset[2]]
	)


func update(delta: float, nearest_surface_distance: float) -> void:
	_surface_distance = nearest_surface_distance
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	var input := Vector3.ZERO if typing else Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up"),
		Input.get_axis("move_forward", "move_back")
	)
	if input != Vector3.ZERO:
		_cancel_flight()
		_manual_auto_orbit = false
		_idle_seconds = 0.0
		var speed := maxf(nearest_surface_distance * SPEED_PER_DISTANCE, MIN_SPEED) * speed_scale
		if Input.is_action_pressed("boost"):
			speed *= BOOST_FACTOR
		var direction := (basis * input).normalized()
		offset[0] += direction.x * speed * delta
		offset[1] += direction.y * speed * delta
		offset[2] += direction.z * speed * delta
	elif not _flying and not _dragging and not _looking and drag_orbit_enabled and auto_orbit_allowed:
		_idle_seconds += delta
	if _flying:
		_advance_flight(delta)
	elif is_auto_orbiting():
		orbit(AUTO_ORBIT_SPEED * delta, 0.0)


func set_clip_range(near_plane: float, far_plane: float) -> void:
	near = near_plane
	far = far_plane


func focus_on(body_id: String, radius: float, toward_sun: Vector3, radii: float = FOCUS_DISTANCE_RADII) -> void:
	_cancel_flight()
	anchor_id = body_id
	var target := _focus_pose(radius, toward_sun, radii)
	offset = target["offset"]
	_look_toward(target["look"])


func fly_to(
	body_id: String,
	target_anchor_position: PackedFloat64Array,
	current_world_position: PackedFloat64Array,
	radius: float,
	toward_sun: Vector3,
	radii: float = FOCUS_DISTANCE_RADII,
	duration: float = FLIGHT_DURATION
) -> void:
	var target := _focus_pose(radius, toward_sun, radii)
	anchor_id = body_id
	_flight_start_offset = PackedFloat64Array(
		[
			current_world_position[0] - target_anchor_position[0],
			current_world_position[1] - target_anchor_position[1],
			current_world_position[2] - target_anchor_position[2]
		]
	)
	_flight_target_offset = target["offset"]
	_flight_start_rotation = Quaternion(basis.orthonormalized())
	_flight_target_rotation = Quaternion(_basis_looking(target["look"]))
	_flight_duration = duration
	_flight_elapsed = 0.0
	offset = _flight_start_offset.duplicate()
	_flying = true


func aim(direction: Vector3) -> void:
	_cancel_flight()
	_look_toward(direction.normalized())


func set_orientation(value: Basis) -> void:
	_cancel_flight()
	basis = value.orthonormalized()
	_sync_angles_from_basis()


func release_anchor(current_world_position: PackedFloat64Array) -> void:
	_cancel_flight()
	_manual_auto_orbit = false
	_idle_seconds = 0.0
	anchor_id = ""
	offset = current_world_position.duplicate()


func reanchor(body_id: String, new_offset: PackedFloat64Array) -> void:
	_cancel_flight()
	anchor_id = body_id
	offset = new_offset.duplicate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_looking = false
		_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventPanGesture:
		_handle_pan_gesture(event)
	elif event is InputEventMagnifyGesture:
		_pinch_until_msec = Time.get_ticks_msec() + PINCH_HOLD_MSEC
		_manual_auto_orbit = false
		_idle_seconds = 0.0
		var factor := clampf(event.factor, PINCH_FACTOR_MIN, PINCH_FACTOR_MAX)
		zoom(pow(1.0 / factor, PINCH_SENSITIVITY))


func orbit(azimuth_delta: float, elevation_delta: float) -> void:
	_cancel_flight()
	if anchor_id == "":
		_yaw -= azimuth_delta
		_pitch = clampf(_pitch + elevation_delta, -MAX_PITCH, MAX_PITCH)
		_apply_orientation()
		return
	var distance := sqrt(offset[0] * offset[0] + offset[1] * offset[1] + offset[2] * offset[2])
	if distance <= 0.0:
		return
	var elevation := asin(clampf(offset[1] / distance, -1.0, 1.0))
	var azimuth := atan2(offset[0], offset[2])
	var new_elevation := clampf(elevation + elevation_delta, -MAX_ELEVATION, MAX_ELEVATION)
	var new_azimuth := azimuth + azimuth_delta
	offset[0] = distance * cos(new_elevation) * sin(new_azimuth)
	offset[1] = distance * sin(new_elevation)
	offset[2] = distance * cos(new_elevation) * cos(new_azimuth)
	_yaw += azimuth_delta
	_pitch = clampf(_pitch - (new_elevation - elevation), -MAX_PITCH, MAX_PITCH)
	_apply_orientation()


func zoom(factor: float) -> void:
	_cancel_flight()
	if anchor_id == "":
		var step := _surface_distance * FREE_ZOOM_FRACTION * (1.0 - factor) / (ZOOM_STEP - 1.0)
		var forward := -basis.z
		offset[0] += forward.x * step
		offset[1] += forward.y * step
		offset[2] += forward.z * step
		return
	var distance := sqrt(offset[0] * offset[0] + offset[1] * offset[1] + offset[2] * offset[2])
	if distance <= 0.0:
		return
	var body_radius := maxf(distance - _surface_distance, 0.0)
	var closest := minf(distance, body_radius * (1.0 + MIN_SURFACE_GAP))
	var target := clampf(distance * factor, closest, maxf(distance, MAX_ORBIT_DISTANCE))
	for axis in 3:
		offset[axis] *= target / distance
	_surface_distance += target - distance


func pan(right_delta: float, up_delta: float) -> void:
	_cancel_flight()
	var step := maxf(_surface_distance, MIN_SPEED) * speed_scale * PAN_MOVE_SENSITIVITY
	var move := (basis.x * right_delta + basis.y * up_delta) * step
	offset[0] += move.x
	offset[1] += move.y
	offset[2] += move.z


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_looking = event.pressed
			if _looking:
				_manual_auto_orbit = false
				_idle_seconds = 0.0
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		MOUSE_BUTTON_LEFT:
			_dragging = event.pressed and drag_orbit_enabled
			_drag_travel = 0.0
			if event.pressed:
				_idle_seconds = 0.0
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
			if event.pressed:
				_manual_auto_orbit = false
				_idle_seconds = 0.0
				_handle_wheel(event)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _looking:
		_cancel_flight()
		_manual_auto_orbit = false
		_idle_seconds = 0.0
		_yaw -= event.relative.x * LOOK_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY, -MAX_PITCH, MAX_PITCH)
		_apply_orientation()
	elif _dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_drag_travel += event.relative.length()
		if _drag_travel > DRAG_THRESHOLD:
			_manual_auto_orbit = false
			_idle_seconds = 0.0
			orbit(-event.relative.x * DRAG_ORBIT_SENSITIVITY, event.relative.y * DRAG_ORBIT_SENSITIVITY)


func _handle_wheel(event: InputEventMouseButton) -> void:
	var amount := event.factor if event.factor > 0.0 else 1.0
	var now := Time.get_ticks_msec()
	if event.factor > 0.0 and not is_equal_approx(event.factor, roundf(event.factor)):
		_touchpad_until_msec = now + TOUCHPAD_HOLD_MSEC
	var steps := Vector2.ZERO
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			steps.y = amount
		MOUSE_BUTTON_WHEEL_DOWN:
			steps.y = -amount
		MOUSE_BUTTON_WHEEL_RIGHT:
			steps.x = amount
		MOUSE_BUTTON_WHEEL_LEFT:
			steps.x = -amount
	_apply_scroll(steps, now < _touchpad_until_msec, event.shift_pressed, event.ctrl_pressed)


func _handle_pan_gesture(event: InputEventPanGesture) -> void:
	if Time.get_ticks_msec() < _pinch_until_msec:
		return
	_touchpad_until_msec = Time.get_ticks_msec() + TOUCHPAD_HOLD_MSEC
	_manual_auto_orbit = false
	_idle_seconds = 0.0
	var steps := Vector2(event.delta.x, -event.delta.y) * _pan_scale * PAN_GESTURE_STEPS
	_apply_scroll(steps, true, event.shift_pressed, event.ctrl_pressed)


func scroll_action(from_touchpad: bool) -> Preferences.ScrollMode:
	if Preferences.scroll_mode != Preferences.ScrollMode.AUTO:
		return Preferences.scroll_mode
	if not from_touchpad:
		return Preferences.ScrollMode.ZOOM
	return Preferences.ScrollMode.ORBIT if anchor_id != "" else Preferences.ScrollMode.MOVE


func _apply_scroll(steps: Vector2, from_touchpad: bool, shift: bool, ctrl: bool) -> void:
	if shift:
		speed_scale = clampf(speed_scale * pow(SPEED_SCALE_STEP, steps.y), MIN_SPEED_SCALE, MAX_SPEED_SCALE)
		return
	if ctrl:
		zoom(pow(ZOOM_STEP, -steps.y))
		return
	match scroll_action(from_touchpad):
		Preferences.ScrollMode.ZOOM:
			if steps.y != 0.0:
				zoom(pow(ZOOM_STEP, -steps.y))
			if steps.x != 0.0:
				orbit(steps.x * WHEEL_ORBIT_STEP, 0.0)
		Preferences.ScrollMode.ORBIT:
			orbit(steps.x * WHEEL_ORBIT_STEP, steps.y * WHEEL_ORBIT_STEP)
		Preferences.ScrollMode.MOVE:
			pan(steps.x * WHEEL_PAN_UNITS, steps.y * WHEEL_PAN_UNITS)


func _focus_pose(radius: float, toward_sun: Vector3, radii: float) -> Dictionary:
	var direction := toward_sun
	if direction.length() < 0.001:
		direction = Vector3(0.3, 0.0, 1.0)
	direction = (direction.normalized() + Vector3.UP * FOCUS_ELEVATION).normalized()
	var distance := radius * radii
	var pose_offset := PackedFloat64Array([direction.x * distance, direction.y * distance, direction.z * distance])
	return {"offset": pose_offset, "look": -direction}


func _advance_flight(delta: float) -> void:
	_flight_elapsed += delta
	var progress := clampf(_flight_elapsed / _flight_duration, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	for axis in 3:
		offset[axis] = lerpf(_flight_start_offset[axis], _flight_target_offset[axis], eased)
	basis = Basis(_flight_start_rotation.slerp(_flight_target_rotation, eased))
	if progress >= 1.0:
		_flying = false
		_sync_angles_from_basis()
		flight_finished.emit()


func _cancel_flight() -> void:
	if not _flying:
		return
	_flying = false
	_sync_angles_from_basis()


func _sync_angles_from_basis() -> void:
	var euler := basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
	_pitch = clampf(euler.x, -MAX_PITCH, MAX_PITCH)
	_yaw = euler.y


func _basis_looking(direction: Vector3) -> Basis:
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := asin(clampf(direction.y, -1.0, 1.0))
	return Basis.from_euler(Vector3(pitch, yaw, 0.0), EULER_ORDER_YXZ)


func _look_toward(direction: Vector3) -> void:
	_yaw = atan2(-direction.x, -direction.z)
	_pitch = asin(clampf(direction.y, -1.0, 1.0))
	_apply_orientation()


func _apply_orientation() -> void:
	basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0), EULER_ORDER_YXZ)

class_name ExploreMode
extends SpaceScene

const DEFAULT_FOCUS_ID := "earth"
const INFO_REFRESH_SECONDS := 0.25
const CLICK_MOVE_TOLERANCE := 6.0
const MOON_LABEL_HIDE_DISTANCE := 40.0
const SCREEN_MARGIN := 40.0
const SCALE_NAMES: Array[String] = ["Compressed", "True scale"]
const HELP_GROUPS := [
	[
		"Camera",
		[
			["{move_forward}|{move_left}|{move_back}|{move_right}", "Move"],
			["{move_down}|{move_up}", "Down / up"],
			["{boost}", "Boost"],
			["Drag|Swipe", "Orbit"],
			["Pinch|Ctrl+Scroll", "Zoom"],
			["Shift+Scroll", "Flight speed"],
			["Right drag", "Look around"],
		],
	],
	[
		"Bodies",
		[
			["Click", "Select"],
			["Double-click", "Focus"],
			["1-0", "Focus a body"],
			["{focus_next}", "Next body"],
			["{focus_release}", "Free flight"],
			["{search}", "Find a body"],
			["{toggle_auto_orbit}", "Auto-orbit"],
		],
	],
	[
		"Time",
		[
			["{time_pause}", "Pause"],
			["{time_reverse}", "Reverse"],
			["{time_slower}|{time_faster}", "Slower / faster"],
			["{time_now}", "Now"],
			["{jump_to_date}", "Go to a date"],
		],
	],
	[
		"View",
		[
			["{scale_toggle}", "Scale"],
			["{toggle_labels}", "Labels"],
			["{toggle_trails}", "Orbit lines"],
			["{toggle_grid}", "Distance rings"],
			["{toggle_constellations}", "Constellations"],
			["{toggle_level}", "Depth level"],
		],
	],
	[
		"App",
		[
			["{mode_sandbox}", "Sandbox"],
			["{toggle_help}", "Controls"],
			["{focus_interface}", "Keyboard navigation"],
			["{toggle_diagnostics}", "Performance"],
			["{toggle_hud}", "Hide interface"],
			["{toggle_fullscreen}", "Fullscreen"],
			["{take_screenshot}", "Screenshot"],
			["Esc", "Menu"],
		],
	],
]
const ONBOARDING_DELAY_SECONDS := 1.0
const ECLIPSE_SPEED_STEP := 1
const LUNAR_ECLIPSE_VIEW_RADII := 5.0
const SOLAR_ECLIPSE_VIEW_RADII := 3.2
const ECLIPSE_TOAST_SECONDS := 6.0
const COMET_SIDE_VIEW := 0.35
const COMET_TAIL_FRAMING := 1.3
const MODE_SWITCH_LABEL := "Sandbox"
const MODE_SWITCH_TEXT := "Open Sandbox ({mode_sandbox})"
const MODE_SWITCH_ICON := "atom"

var model: SolarSystemModel
var renderer := SolarSystemRenderer.new()

var _info_catalog: BodyInfoCatalog
var _quiz_catalog: QuizCatalog
var _quiz_panel := QuizPanel.new()
var _labels := BodyLabels.new()
var _info_panel := InfoPanel.new()
var _tour_panel := TourPanel.new()
var _tour_menu := TourMenu.new()
var _tour_player := TourPlayer.new()
var _tours: Array[Dictionary] = []
var _scale_control := SegmentedControl.new(SCALE_NAMES, "Distance and size scale (T)")
var _tours_button: Button
var _selected_id := ""
var _info_timer := 0.0
var _press_position := Vector2.ZERO
var _current_step: Dictionary = {}
var _focus_actions: Array[StringName] = []
var _eclipse_search: EclipseSearch
var _before_tour: Dictionary = {}


func _build_world() -> void:
	model = SolarSystemModel.new(BodyCatalog.load_bodies())
	_eclipse_search = EclipseSearch.new(model)
	_info_catalog = BodyInfoCatalog.load_catalog()
	_tours = TourCatalog.load_tours()
	_quiz_catalog = QuizCatalog.load_catalog()
	add_child(renderer)
	renderer.setup(model)
	hud.add_overlay(_labels)
	hud.right_column.add_child(_info_panel)
	hud.left_column.add_child(_tour_menu)
	hud.bottom_center.add_child(_tour_panel)
	hud.bottom_center.add_child(_quiz_panel)
	_tour_menu.populate(_tours, _quiz_tour_ids())
	hud.add_setting(HSeparator.new())
	hud.add_setting(Hud.section_label("Scale"))
	hud.add_setting(_scale_control)
	_scale_control.selected.connect(func(index: int) -> void: _set_scale_mode(index as ScaleMapper.Mode))
	_tours_button = Hud.make_button("Guided tours", _toggle_tour_menu, "Choose a guided tour", "route")
	_tours_button.theme_type_variation = "ToggleButton"
	_tours_button.toggle_mode = true
	hud.toolbar.add_child(_tours_button)
	hud.toolbar.move_child(_tours_button, 0)
	set_key_help(HELP_GROUPS, MODE_SWITCH_LABEL, MODE_SWITCH_TEXT, MODE_SWITCH_ICON)
	for index in mini(model.bodies.size(), InputBindings.FOCUS_KEYS.size()):
		_focus_actions.append(StringName("focus_body_%d" % index))
	_info_panel.focus_requested.connect(_fly_to)
	_info_panel.close_requested.connect(_clear_selection)
	_tour_menu.tour_selected.connect(_start_tour)
	_tour_menu.quiz_selected.connect(_start_quiz)
	_tour_menu.close_requested.connect(_toggle_tour_menu)
	_tour_player.step_changed.connect(_on_tour_step)
	_tour_player.stopped.connect(_on_tour_stopped)
	_tour_player.finished.connect(_on_tour_finished)
	_tour_panel.previous_pressed.connect(_tour_player.previous)
	_tour_panel.next_pressed.connect(_tour_player.next)
	_tour_panel.exit_pressed.connect(_tour_player.stop)
	_tour_panel.replay_pressed.connect(_tour_player.replay)
	hud.date_requested.connect(_open_date_panel)
	hud.date_panel.date_chosen.connect(_jump_to_unix)
	hud.date_panel.eclipse_requested.connect(_go_to_eclipse)
	model.update(clock.seconds)
	renderer.compute_positions()
	camera.focus_on(DEFAULT_FOCUS_ID, renderer.mapper.radius(model.get_body(DEFAULT_FOCUS_ID)), _toward_sun(DEFAULT_FOCUS_ID))
	Audio.play_narration_once("welcome")
	if not Preferences.onboarding_done:
		get_tree().create_timer(ONBOARDING_DELAY_SECONDS).timeout.connect(_start_onboarding)


func _process(delta: float) -> void:
	camera.auto_orbit_allowed = not _quiz_panel.is_open()
	super(delta)
	clock.advance(delta)
	model.update(clock.seconds)
	renderer.compute_positions()
	camera.update(delta, renderer.nearest_surface_distance)
	renderer.update(camera.world_position(_anchor_position()), clock.seconds)
	camera.set_clip_range(renderer.near_plane, renderer.far_plane)
	_update_labels()
	_info_timer += delta
	if _info_timer >= INFO_REFRESH_SECONDS:
		_info_timer = 0.0
		_refresh_info_values()
	hud.refresh(clock)
	hud.set_status(tr("Focus: %s") % _focus_name())
	_scale_control.select(renderer.mapper.mode)
	_tours_button.set_pressed_no_signal(_tour_menu.visible)


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if get_viewport().is_input_handled():
		return
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(event)
	elif event.is_action_pressed("scale_toggle"):
		_set_scale_mode(_other_scale_mode())
	elif event.is_action_pressed("focus_next"):
		_focus_next()
	elif event.is_action_pressed("jump_to_date"):
		get_viewport().set_input_as_handled()
		_open_date_panel()
	elif event.is_action_pressed("focus_release"):
		camera.release_anchor(camera.world_position(_anchor_position()))
	elif event.is_action_pressed("tour_next"):
		if _quiz_panel.is_open():
			_quiz_panel.advance()
		else:
			_tour_player.next()
	elif event.is_action_pressed("tour_previous"):
		_tour_player.previous()
	elif event.is_action_pressed("cancel"):
		_cancel()
	else:
		for index in _focus_actions.size():
			if event.is_action_pressed(_focus_actions[index]):
				_focus_body(model.bodies[index].id)
				return


func _on_quality_changed() -> void:
	renderer.apply_quality()


func _focus_mesh_summary() -> String:
	return mesh_summary(renderer.mesh_segments(camera.anchor_id))


func _diagnostics_summary() -> String:
	return tr("%d bodies, %s rocks") % [model.bodies.size(), Hud.format_count(Quality.profile()["asteroid_count"])]


func _on_preferences_changed() -> void:
	renderer.set_trails_visible(Preferences.trails_visible)
	renderer.apply_trail_colors()
	renderer.set_rings_visible(Preferences.rings_visible)
	_refresh_selection_content()
	if _tour_player.active and not _current_step.is_empty():
		_tour_panel.refresh_text(_current_step)
	_tour_player.sync_narration()


func _handle_left_click(event: InputEventMouseButton) -> void:
	if event.pressed:
		_press_position = event.position
		if event.double_click:
			var double_id := _pick(event.position)
			if double_id != "":
				_focus_body(double_id)
		return
	if event.position.distance_to(_press_position) > CLICK_MOVE_TOLERANCE:
		return
	var picked := _pick(event.position)
	if picked == "":
		_clear_selection()
	else:
		_select(picked)


func _pick(screen_position: Vector2) -> String:
	return renderer.pick(camera.project_ray_normal(screen_position), pick_tolerance_angle())


func _select(body_id: String) -> void:
	_selected_id = body_id
	_info_timer = 0.0
	_refresh_selection_content()


func _clear_selection() -> void:
	_selected_id = ""
	_info_panel.dismiss()


func _refresh_selection_content() -> void:
	if _selected_id == "" or _tour_player.active:
		_info_panel.dismiss()
		return
	var body := model.get_body(_selected_id)
	_info_panel.present(body, model.get_parent_body(body), _current_distance(body), model.relative_speed_km_s(body, clock.seconds), _info_catalog)


func _refresh_info_values() -> void:
	if _selected_id == "" or _tour_player.active:
		return
	var body := model.get_body(_selected_id)
	_info_panel.refresh_values(body, model.get_parent_body(body), _current_distance(body), model.relative_speed_km_s(body, clock.seconds))


func _current_distance(body: BodyDefinition) -> float:
	if body.orbit == null:
		return 0.0
	var relative: DVec3 = model.relative_km[body.id]
	return relative.length()


func _anchor_position() -> PackedFloat64Array:
	if camera.anchor_id == "":
		return PackedFloat64Array([0.0, 0.0, 0.0])
	return renderer.render_position(camera.anchor_id)


func _focus_name() -> String:
	if camera.anchor_id == "":
		return tr("Free flight")
	return tr(model.get_body(camera.anchor_id).display_name)


func _toward_sun(body_id: String) -> Vector3:
	var position := renderer.render_position(body_id)
	var sun_position := renderer.render_position(model.bodies[0].id)
	var toward := Vector3(sun_position[0] - position[0], sun_position[1] - position[1], sun_position[2] - position[2])
	if model.get_body(body_id).kind != "comet" or toward == Vector3.ZERO:
		return toward
	var side := toward.cross(Vector3.UP).normalized()
	return (toward.normalized() * COMET_SIDE_VIEW + side).normalized()


func _focus_radii(body_id: String) -> float:
	if renderer.comet_tail(body_id) == null:
		return CameraRig.FOCUS_DISTANCE_RADII
	var distance_km: float = model.relative_km[body_id].length()
	var length := CometTail.length_at(distance_km / Astro.AU_KM, renderer.mapper.heliocentric_scale(distance_km))
	var radius := renderer.mapper.radius(model.get_body(body_id))
	return maxf(CameraRig.FOCUS_DISTANCE_RADII, length * COMET_TAIL_FRAMING / radius)


func _focus_body(body_id: String) -> void:
	_select(body_id)
	_fly_to(body_id)


func _fly_to(body_id: String, radii: float = -1.0) -> void:
	var body := model.get_body(body_id)
	if radii < 0.0:
		radii = _focus_radii(body_id)
	camera.fly_to(
		body_id,
		renderer.render_position(body_id),
		camera.world_position(_anchor_position()),
		renderer.mapper.radius(body),
		_toward_sun(body_id),
		radii
	)


func _focus_next() -> void:
	var order := model.cycle_order()
	_focus_body(order[(order.find(camera.anchor_id) + 1) % order.size()])


func _other_scale_mode() -> ScaleMapper.Mode:
	if renderer.mapper.mode == ScaleMapper.Mode.COMPRESSED:
		return ScaleMapper.Mode.TRUE_SCALE
	return ScaleMapper.Mode.COMPRESSED


func _set_scale_mode(mode: ScaleMapper.Mode) -> void:
	var mapper := renderer.mapper
	if mapper.mode == mode:
		return
	var camera_position := camera.world_position(_anchor_position())
	var nearest_id := renderer.nearest_body_id(camera_position)
	var nearest := model.get_body(nearest_id)
	var body_position := renderer.render_position(nearest_id)
	var old_radius := mapper.radius(nearest)
	var ratio := PackedFloat64Array(
		[
			(camera_position[0] - body_position[0]) / old_radius,
			(camera_position[1] - body_position[1]) / old_radius,
			(camera_position[2] - body_position[2]) / old_radius
		]
	)
	mapper.mode = mode
	renderer.compute_positions()
	var new_radius := mapper.radius(nearest)
	camera.reanchor(nearest_id, PackedFloat64Array([ratio[0] * new_radius, ratio[1] * new_radius, ratio[2] * new_radius]))


func _update_labels() -> void:
	var entries: Array = []
	append_constellation_labels(entries)
	if Preferences.labels_visible:
		append_ring_labels(entries, renderer.ring_label_entries())
	if not Preferences.labels_visible and _selected_id == "":
		_labels.set_entries(entries)
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var pixels := pixels_per_radian()
	var screen_positions: Dictionary = {}
	for body in model.bodies:
		var position := renderer.camera_relative_position(body.id)
		if camera.is_position_behind(position):
			continue
		var screen := camera.unproject_position(position)
		if screen.x < -SCREEN_MARGIN or screen.y < -SCREEN_MARGIN:
			continue
		if screen.x > viewport_size.x + SCREEN_MARGIN or screen.y > viewport_size.y + SCREEN_MARGIN:
			continue
		screen_positions[body.id] = screen
		var distance := maxf(position.length(), 1.0e-9)
		var radius_pixels := asin(clampf(renderer.camera_relative_radius(body.id) / distance, 0.0, 1.0)) * pixels
		var labeled := Preferences.labels_visible and not renderer.is_occluded(body.id)
		if labeled and body.kind == "moon" and screen_positions.has(body.parent_id):
			var parent_screen: Vector2 = screen_positions[body.parent_id]
			labeled = screen.distance_to(parent_screen) > MOON_LABEL_HIDE_DISTANCE
		entries.append(
			{
				"name": tr(body.display_name),
				"position": screen,
				"radius": minf(radius_pixels, viewport_size.y),
				"labeled": labeled,
				"selected": body.id == _selected_id
			}
		)
	_labels.set_entries(entries)


func _start_onboarding() -> void:
	if Preferences.onboarding_done or _tour_player.active:
		return
	hud.onboarding.finished.connect(func() -> void: Preferences.set_onboarding_done(true), CONNECT_ONE_SHOT)
	hud.onboarding.start(_onboarding_steps())


func _onboarding_steps() -> Array[Dictionary]:
	return [
		{
			"title": "Welcome to Orrery",
			"text": "Here is a quick look at the controls. It takes about a minute, and you can skip it at any time.",
		},
		{
			"title": "Look around",
			"text": "Drag with the mouse, or swipe with two fingers, to orbit the body in view. Scroll or pinch to zoom, and move freely with W, A, S, and D.",
		},
		{
			"title": "Meet the bodies",
			"text": "Click a planet or moon to read about it, and double-click to fly to it. This button finds any body by name.",
			"target": hud.search_button,
		},
		{
			"title": "Control time",
			"text": "Play, pause, reverse, or speed up time here. The calendar jumps to any date between 1800 and 2050, or straight to the next eclipse.",
			"target": hud.time_panel,
		},
		{
			"title": "Take a guided tour",
			"text": "Tours show the highlights with narration, and each one ends with a short quiz.",
			"target": func() -> Control: return _tours_button,
		},
		{
			"title": "Choose what you see",
			"text": "Explorer keeps the facts simple and Scientist shows full data. Labels, orbits, rings, constellations, and the scale can be switched here.",
			"target": hud.view_panel,
		},
		{
			"title": "Try the Sandbox",
			"text": "In the Sandbox you launch your own planets, watch them bend a gravity well, and take on five challenges.",
			"target": hud.mode_button,
		},
		{
			"title": "You are ready",
			"text": "Press F3 at any time to see every control. Enjoy the solar system.",
		},
	]


func _open_date_panel() -> void:
	hud.date_panel.open(clock.seconds + Astro.J2000_UNIX_SECONDS, hud.utc_offset_minutes())


func _jump_to_unix(unix_seconds: float) -> void:
	clock.seconds = Astro.unix_to_simulation_seconds(unix_seconds)
	clock.changed.emit()


func _go_to_eclipse(direction: int) -> void:
	var first := Astro.unix_to_simulation_seconds(DatePanel.first_unix())
	var last := Astro.unix_to_simulation_seconds(DatePanel.last_unix())
	var eclipse := _eclipse_search.find(clock.seconds, direction, first, last)
	if eclipse.is_empty():
		hud.show_toast(tr("No eclipse found between %d and %d in that direction") % [DatePanel.MIN_YEAR, DatePanel.MAX_YEAR])
		return
	if _tour_player.active:
		_tour_player.stop()
	_set_time(eclipse["seconds"], ECLIPSE_SPEED_STEP)
	var lunar: bool = eclipse["kind"] == EclipseSearch.Kind.LUNAR
	_select("moon" if lunar else "earth")
	_show_eclipse(lunar)
	var when := Astro.format_date(eclipse["seconds"], hud.utc_offset_minutes())
	hud.show_toast(tr("%s, greatest at %s") % [tr(EclipseSearch.describe(eclipse)), when], ECLIPSE_TOAST_SECONDS)


func _set_time(seconds: float, speed_step: int) -> void:
	clock.seconds = seconds
	clock.reversed = false
	clock.step_index = clampi(speed_step, 0, SimulationClock.SPEED_STEPS.size() - 1)
	clock.changed.emit()
	model.update(clock.seconds)
	renderer.compute_positions()


func _show_eclipse(lunar: bool) -> void:
	_set_scale_mode(ScaleMapper.Mode.TRUE_SCALE)
	model.update(clock.seconds)
	renderer.compute_positions()
	var target := "moon" if lunar else "earth"
	var body := model.get_body(target)
	camera.fly_to(
		target,
		renderer.render_position(target),
		camera.world_position(_anchor_position()),
		renderer.mapper.radius(body),
		_toward_sun(target) if lunar else _toward_moon_shadow(),
		LUNAR_ECLIPSE_VIEW_RADII if lunar else SOLAR_ECLIPSE_VIEW_RADII
	)


func _toward_moon_shadow() -> Vector3:
	var earth := _render_vector("earth")
	var moon := _render_vector("moon")
	var axis := (moon - _render_vector("sun")).normalized()
	var to_axis := moon + axis * (earth - moon).dot(axis) - earth
	var radius := renderer.mapper.radius(model.get_body("earth"))
	var depth := sqrt(maxf(radius * radius - to_axis.length_squared(), 0.0))
	return to_axis - axis * depth


func _render_vector(body_id: String) -> Vector3:
	var position := renderer.render_position(body_id)
	return Vector3(position[0], position[1], position[2])


func capture_session() -> Dictionary:
	var state := super()
	state["scale"] = renderer.mapper.mode
	state["selected"] = _selected_id
	if _tour_player.active and not _before_tour.is_empty():
		state.merge(_before_tour, true)
	return state


func _restore_session(state: Dictionary) -> void:
	super(state)
	_set_scale_mode(state["scale"])
	model.update(clock.seconds)
	renderer.compute_positions()
	var anchor: String = state["anchor"]
	_restore_camera(state, anchor != "" and model.get_body(anchor) != null)
	var selected: String = state["selected"]
	if selected != "" and model.get_body(selected) != null:
		_select(selected)


func _search_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for body in model.bodies:
		var name := tr(body.display_name)
		items.append({"id": body.id, "name": name, "detail": tr(_info_catalog.type_label(body.id)), "keywords": [name, body.display_name]})
	return items


func _on_search_chosen(id: String) -> void:
	if _tour_player.active:
		_tour_player.stop()
	_focus_body(id)


func _toggle_tour_menu() -> void:
	_tour_menu.visible = not _tour_menu.visible


func _start_tour(tour_id: String) -> void:
	for tour in _tours:
		if tour["id"] == tour_id:
			_tour_menu.visible = false
			_quiz_panel.close_quiz()
			_clear_selection()
			_before_tour = {}
			if tour["steps"].any(func(step: Dictionary) -> bool: return step.has("date")):
				_before_tour = {
					"seconds": clock.seconds,
					"step_index": clock.step_index,
					"paused": clock.paused,
					"reversed": clock.reversed,
					"scale": renderer.mapper.mode,
				}
			_tour_player.start(tour)
			return


func _on_tour_step(tour_title: String, step: Dictionary, index: int, count: int) -> void:
	_current_step = step
	hud.set_help_visible(false)
	_info_panel.dismiss()
	_tour_panel.show_step(tour_title, step, index, count)
	if step.has("date"):
		var unix := Time.get_unix_time_from_datetime_string(str(step["date"]))
		_set_time(Astro.unix_to_simulation_seconds(unix), int(step.get("speed_step", clock.step_index)))
	if step.has("scale"):
		_set_scale_mode(ScaleMapper.Mode.TRUE_SCALE if step["scale"] == "true" else ScaleMapper.Mode.COMPRESSED)
	_selected_id = step["target"]
	if step.has("eclipse"):
		_show_eclipse(step["eclipse"] == "lunar")
		return
	_fly_to(step["target"], step.get("distance_radii", -1.0))


func _on_tour_stopped() -> void:
	_current_step = {}
	_tour_panel.dismiss()
	_refresh_selection_content()
	if not _before_tour.is_empty():
		var saved := _before_tour
		_before_tour = {}
		_set_time(saved["seconds"], saved["step_index"])
		clock.paused = saved["paused"]
		clock.reversed = saved["reversed"]
		clock.changed.emit()
		_set_scale_mode(saved["scale"])


func _cancel() -> void:
	if hud.onboarding.is_running():
		hud.onboarding.finish()
	elif _quiz_panel.is_open():
		_quiz_panel.close_quiz()
	elif _tour_player.active:
		_tour_player.stop()
	elif _tour_menu.visible:
		_tour_menu.visible = false
	elif _selected_id != "":
		_clear_selection()
	else:
		_open_pause_menu()


func _quiz_tour_ids() -> Array[String]:
	var ids: Array[String] = []
	for tour in _tours:
		if _quiz_catalog.has_quiz(tour["id"]):
			ids.append(tour["id"])
	return ids


func _start_quiz(tour_id: String) -> void:
	for tour in _tours:
		if tour["id"] == tour_id:
			_tour_menu.visible = false
			_tour_player.stop()
			hud.set_help_visible(false)
			_quiz_panel.start(tour["title"], _quiz_catalog.questions(tour_id, Preferences.is_scientist()))
			return


func _on_tour_finished(tour: Dictionary) -> void:
	if _quiz_catalog.has_quiz(tour["id"]):
		_quiz_panel.offer(tour["title"], _quiz_catalog.questions(tour["id"], Preferences.is_scientist()))

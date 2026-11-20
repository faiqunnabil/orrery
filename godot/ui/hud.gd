class_name Hud
extends CanvasLayer

signal reverse_pressed
signal pause_pressed
signal slower_pressed
signal faster_pressed
signal now_pressed
signal quality_selected(preset: int)
signal mode_switch_pressed
signal menu_pressed
signal search_requested
signal date_requested

const OUTER_MARGIN := 14
const SIDE_PANEL_WIDTH := 340
const HELP_HINT := "   |   %s controls"
const AUTO_ORBIT_HINT := "   |   Auto-orbit"
const SPEED_LABEL_WIDTH := 92
const BOTTOM_RESERVE := 60.0
const BOTTOM_CENTER_MARGIN := 58
const ICON_BUTTON_WIDTH := 34
const SCROLLBAR_GUTTER := 12
const DIAGNOSTICS_WIDTH := 240
const TOAST_SECONDS := 2.5
const HELP_COLUMN_WIDTH := 168
const KEY_SEPARATOR := "|"

var left_column := VBoxContainer.new()
var right_column := VBoxContainer.new()
var top_center := VBoxContainer.new()
var bottom_center := VBoxContainer.new()
var toolbar := HBoxContainer.new()
var search_panel := SearchPanel.new()
var date_panel := DatePanel.new()
var onboarding := Onboarding.new()

var _root := Control.new()
var _date_label := Label.new()
var _speed_label := Label.new()
var _reverse_button := Button.new()
var _pause_button := Button.new()
var _now_button: Button
var _now_separator := VSeparator.new()
var _fps_label := Label.new()
var _status_label := Label.new()
var _help_panel := PanelContainer.new()
var _help_flow := HFlowContainer.new()
var _help_entries: Array = []
var _diagnostics_panel := PanelContainer.new()
var _diag_values: Dictionary[String, Label] = {}
var _toast_panel := PanelContainer.new()
var _toast_label := Label.new()
var _toast_timer := 0.0
var _frame_ms := 16.7
var _cpu_ms := 1.0
var _auto_orbit_active := false
var _utc_offset_minutes := Astro.local_offset_minutes()
var _quality_option := OptionButton.new()
var _depth_control := SegmentedControl.new(Preferences.DEPTH_NAMES, "Information depth (M)")
var _labels_toggle: Button
var _trails_toggle: Button
var _rings_toggle: Button
var _mode_button := Button.new()
var _settings_extras := VBoxContainer.new()
var _view_body := VBoxContainer.new()
var _collapse_button: Button
var _search_button: Button
var _date_button: Button
var _time_panel: Control
var _view_panel: Control


static func make_panel(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box


static func make_button(label: String, pressed_callback: Callable, tooltip: String = "", icon_name: String = "") -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed_callback)
	if icon_name != "":
		button.icon = OrreryTheme.icon(icon_name)
	return button


static func make_accent_button(label: String, pressed_callback: Callable, tooltip: String = "", icon_name: String = "") -> Button:
	var button := make_button(label, pressed_callback, tooltip, icon_name)
	button.theme_type_variation = "AccentButton"
	return button


static func make_icon_button(icon_name: String, pressed_callback: Callable, tooltip: String, variation: String = "IconButton") -> Button:
	var button := make_button("", pressed_callback, tooltip, icon_name)
	button.theme_type_variation = variation
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(ICON_BUTTON_WIDTH, 0)
	return button


static func make_close_button(pressed_callback: Callable, tooltip: String = "Close (Esc)") -> Button:
	return make_icon_button("x", pressed_callback, tooltip, "IconFlatButton")


static func make_label(text: String, variation: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


static func make_wrapped_label(text: String, width: float, variation: String = "") -> Label:
	var label := make_label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label


static func section_label(text: String) -> Label:
	return make_label(text.to_upper(), "SectionLabel")


static func make_toggle(label: String, tooltip: String, toggled_callback: Callable, icon_name: String = "") -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.theme_type_variation = "ToggleButton"
	if icon_name != "":
		button.icon = OrreryTheme.icon(icon_name)
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggled.connect(toggled_callback)
	return button


static func scroll_content(scroll: ScrollContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", SCROLLBAR_GUTTER)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	return content


static func fit_scroll(panel: Control, scroll: ScrollContainer, minimum: float, maximum: float) -> void:
	var viewport_height := panel.get_viewport_rect().size.y
	var chrome := panel.size.y - scroll.size.y
	var available := viewport_height - panel.global_position.y - chrome - BOTTOM_RESERVE
	var target := clampf(available, minimum, maximum)
	if absf(scroll.custom_minimum_size.y - target) > 1.0:
		scroll.custom_minimum_size.y = target


func _ready() -> void:
	_root.theme = OrreryTheme.build()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_place_column(left_column, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	_place_column(right_column, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	_place_column(top_center, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	_place_bottom_center()
	_build_time_panel()
	left_column.add_child(date_panel)
	_build_toolbar()
	_build_settings_panel()
	_build_top_center()
	_build_footer()
	_root.add_child(onboarding)
	_depth_control.selected.connect(func(index: int) -> void: Preferences.set_depth_level(index as Preferences.DepthLevel))
	Preferences.changed.connect(_sync_preferences)
	_sync_preferences()


func _process(delta: float) -> void:
	_frame_ms = lerpf(_frame_ms, delta * 1000.0, 0.15)
	_cpu_ms = lerpf(_cpu_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.15)
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_panel.visible = false


func is_root_visible() -> bool:
	return _root.visible


func set_root_visible(value: bool) -> void:
	_root.visible = value


func toggle_visibility() -> void:
	_root.visible = not _root.visible


func add_overlay(control: Control) -> void:
	_root.add_child(control)
	_root.move_child(control, 0)


func add_setting(control: Control) -> void:
	_settings_extras.add_child(control)


func set_mode_switch(label: String, tooltip: String = "", icon_name: String = "") -> void:
	_mode_button.text = label
	_mode_button.tooltip_text = tooltip
	_mode_button.icon = OrreryTheme.icon(icon_name) if icon_name != "" else null
	_mode_button.visible = label != ""


func set_depth_visible(value: bool) -> void:
	_depth_control.visible = value


func set_now_visible(value: bool) -> void:
	_now_button.visible = value
	_now_separator.visible = value
	_date_button.visible = value


func time_panel() -> Control:
	return _time_panel


func view_panel() -> Control:
	return _view_panel


func search_button() -> Control:
	return _search_button


func utc_offset_minutes() -> int:
	return _utc_offset_minutes


func set_auto_orbit_active(value: bool) -> void:
	_auto_orbit_active = value


func set_status(text: String) -> void:
	var full := text + (AUTO_ORBIT_HINT if _auto_orbit_active else "")
	_status_label.text = full if _help_panel.visible else full + HELP_HINT % InputBindings.keys_text("toggle_help")


func set_help(groups: Array) -> void:
	_help_entries.clear()
	for child in _help_flow.get_children():
		_help_flow.remove_child(child)
		child.queue_free()
	for group: Array in groups:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(HELP_COLUMN_WIDTH, 0)
		column.add_theme_constant_override("separation", OrreryTheme.SPACE_XS)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_help_flow.add_child(column)
		column.add_child(section_label(group[0]))
		for entry: Array in group[1]:
			column.add_child(_help_row(entry[0], entry[1]))
			_help_entries.append("%s %s" % [entry[0].replace(KEY_SEPARATOR, "/"), entry[1]])


func help_text() -> String:
	return "   ".join(_help_entries)


func _help_row(keys: String, description: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in keys.split(KEY_SEPARATOR):
		var cap := PanelContainer.new()
		cap.theme_type_variation = "KeyCap"
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_child(make_label(key, "KeyLabel"))
		row.add_child(cap)
	var label := make_label(description, "DimLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	return row


func toggle_help() -> void:
	_help_panel.visible = not _help_panel.visible
	_fit_help()


func set_help_visible(value: bool) -> void:
	_help_panel.visible = value
	_fit_help()


func _fit_help() -> void:
	var columns := maxi(_help_flow.get_child_count(), 1)
	var chrome := 2.0 * OrreryTheme.SPACE_L
	var full := columns * HELP_COLUMN_WIDTH + (columns - 1) * OrreryTheme.SPACE_L + chrome
	var available := _root.get_viewport_rect().size.x - 2.0 * OUTER_MARGIN
	_help_panel.custom_minimum_size.x = minf(full, available)


func toggle_diagnostics() -> bool:
	_diagnostics_panel.visible = not _diagnostics_panel.visible
	return _diagnostics_panel.visible


func is_diagnostics_visible() -> bool:
	return _diagnostics_panel.visible


func refresh_diagnostics(scene_summary: String, focus_mesh: String) -> void:
	var fps := Engine.get_frames_per_second()
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var vram_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	_diag_values["fps"].text = "%d" % fps
	_diag_values["frame"].text = "%.1f / %.1f ms" % [_frame_ms, _cpu_ms]
	_diag_values["draws"].text = format_count(draws)
	_diag_values["primitives"].text = format_count(primitives)
	_diag_values["vram"].text = "%.1f MB" % vram_mb
	_diag_values["scene"].text = scene_summary
	_diag_values["mesh"].text = focus_mesh


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_timer = TOAST_SECONDS


func refresh(clock: SimulationClock) -> void:
	_date_label.text = Astro.format_date(clock.seconds, _utc_offset_minutes)
	_speed_label.text = clock.speed_label()
	_reverse_button.set_pressed_no_signal(clock.reversed)
	_pause_button.icon = OrreryTheme.icon("play" if clock.paused else "pause")
	_pause_button.tooltip_text = ("Resume" if clock.paused else "Pause") + " time (Space)"
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func sync_quality(preset: int) -> void:
	_quality_option.select(preset)


func _place_column(
	column: VBoxContainer, preset: Control.LayoutPreset, horizontal: Control.GrowDirection, vertical: Control.GrowDirection
) -> void:
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", OUTER_MARGIN - 4)
	_root.add_child(column)
	column.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, OUTER_MARGIN)
	column.grow_horizontal = horizontal
	column.grow_vertical = vertical


func _build_time_panel() -> void:
	var box := make_panel(left_column)
	_time_panel = box.get_parent()
	var header := HBoxContainer.new()
	box.add_child(header)
	_date_label.theme_type_variation = "HeaderLabel"
	_date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_date_label)
	_date_button = make_icon_button("calendar", func() -> void: date_requested.emit(), "", "IconFlatButton")
	header.add_child(_date_button)
	var zone := make_label(Astro.utc_offset_label(_utc_offset_minutes), "DimLabel")
	zone.tooltip_text = "Times are shown in this computer's time zone"
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	header.add_child(zone)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", OrreryTheme.SPACE_XS)
	box.add_child(row)
	_reverse_button.theme_type_variation = "ToggleIconButton"
	_reverse_button.icon = OrreryTheme.icon("rewind")
	_reverse_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reverse_button.custom_minimum_size = Vector2(ICON_BUTTON_WIDTH, 0)
	_reverse_button.toggle_mode = true
	_reverse_button.focus_mode = Control.FOCUS_NONE
	_reverse_button.tooltip_text = "Run time backwards (R)"
	_reverse_button.pressed.connect(func() -> void: reverse_pressed.emit())
	row.add_child(_reverse_button)
	_pause_button.theme_type_variation = "IconButton"
	_pause_button.icon = OrreryTheme.icon("pause")
	_pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_button.custom_minimum_size = Vector2(ICON_BUTTON_WIDTH, 0)
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.tooltip_text = "Pause time (Space)"
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	row.add_child(_pause_button)
	row.add_child(VSeparator.new())
	row.add_child(make_icon_button("minus", func() -> void: slower_pressed.emit(), "Slower ([)"))
	_speed_label.custom_minimum_size = Vector2(SPEED_LABEL_WIDTH, 0)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_speed_label)
	row.add_child(make_icon_button("plus", func() -> void: faster_pressed.emit(), "Faster (])"))
	row.add_child(_now_separator)
	_now_button = make_button("Now", func() -> void: now_pressed.emit(), "Jump to the current date (N)")
	row.add_child(_now_button)


func _build_toolbar() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ToolbarPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_column.add_child(panel)
	toolbar.add_theme_constant_override("separation", OrreryTheme.SPACE_XS)
	panel.add_child(toolbar)
	var search := make_icon_button("search", func() -> void: search_requested.emit(), "")
	toolbar.add_child(search)
	_search_button = search


func refresh_binding_tooltips() -> void:
	_search_button.tooltip_text = tr("Find a body (%s)") % InputBindings.keys_text("search")
	_date_button.tooltip_text = tr("Go to a date (%s)") % InputBindings.keys_text("jump_to_date")


func _build_settings_panel() -> void:
	var box := make_panel(right_column)
	_view_panel = box.get_parent()
	box.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH, 0)
	var header := HBoxContainer.new()
	box.add_child(header)
	var view_label := section_label("View")
	view_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(view_label)
	_fps_label.theme_type_variation = "DimLabel"
	header.add_child(_fps_label)
	_collapse_button = make_icon_button(
		"chevron_up", func() -> void: Preferences.set_view_panel_collapsed(not Preferences.view_panel_collapsed), "", "IconFlatButton"
	)
	_collapse_button.custom_minimum_size = Vector2(26, 0)
	header.add_child(_collapse_button)
	box.add_child(_view_body)
	_view_body.add_child(_depth_control)
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", OrreryTheme.SPACE_XS)
	_view_body.add_child(toggles)
	_labels_toggle = make_toggle("Labels", "Show body names (L)", Preferences.set_labels_visible, "tag")
	_trails_toggle = make_toggle("Orbits", "Show orbit lines (O)", Preferences.set_trails_visible, "orbit")
	_rings_toggle = make_toggle("Rings", "Show distance rings around the Sun (G)", Preferences.set_rings_visible, "circle_dot_dashed")
	toggles.add_child(_labels_toggle)
	toggles.add_child(_trails_toggle)
	toggles.add_child(_rings_toggle)
	_view_body.add_child(_settings_extras)
	_view_body.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", OrreryTheme.SPACE_XS)
	box.add_child(actions)
	for preset_name in Quality.PRESET_NAMES:
		_quality_option.add_item(preset_name)
	_quality_option.focus_mode = Control.FOCUS_NONE
	_quality_option.tooltip_text = "Graphics quality. Lower quality runs faster on older devices"
	_quality_option.icon = OrreryTheme.icon("gauge")
	_quality_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quality_option.item_selected.connect(func(index: int) -> void: quality_selected.emit(index))
	actions.add_child(_quality_option)
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.visible = false
	_mode_button.pressed.connect(func() -> void: mode_switch_pressed.emit())
	actions.add_child(_mode_button)
	actions.add_child(make_button("Menu", func() -> void: menu_pressed.emit(), "Pause menu, settings and credits (Esc)", "menu"))


func _place_bottom_center() -> void:
	bottom_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_theme_constant_override("separation", OUTER_MARGIN - 4)
	bottom_center.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(bottom_center)
	bottom_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_center.offset_left = OUTER_MARGIN
	bottom_center.offset_right = -(SIDE_PANEL_WIDTH + 2 * OUTER_MARGIN)
	bottom_center.offset_bottom = -BOTTOM_CENTER_MARGIN
	bottom_center.offset_top = -BOTTOM_CENTER_MARGIN
	bottom_center.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_top_center() -> void:
	top_center.add_child(search_panel)
	_diagnostics_panel.custom_minimum_size = Vector2(DIAGNOSTICS_WIDTH, 0)
	_diagnostics_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_diagnostics_panel.visible = false
	_diagnostics_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.add_child(_diagnostics_panel)
	var diag_box := VBoxContainer.new()
	diag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diagnostics_panel.add_child(diag_box)
	diag_box.add_child(section_label("Performance"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diag_box.add_child(grid)
	for entry in [
		["fps", "FPS"],
		["frame", "Frame / CPU"],
		["draws", "Draw calls"],
		["primitives", "Primitives"],
		["vram", "VRAM"],
		["scene", "Scene"],
		["mesh", "Focus mesh"],
	]:
		var key_label := make_label(entry[1], "DimLabel")
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(key_label)
		var value_label := Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(value_label)
		_diag_values[entry[0]] = value_label
	_toast_panel.theme_type_variation = "ChipPanel"
	_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_child(_toast_panel)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_label)


static func format_count(value: int) -> String:
	if value >= 1000000:
		return "%.2fM" % (float(value) / 1000000.0)
	if value >= 10000:
		return "%.1fk" % (float(value) / 1000.0)
	var text := str(value)
	var out := ""
	var count := 0
	for index in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = text[index] + out
		count += 1
	return out


func _build_footer() -> void:
	var footer := VBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, OUTER_MARGIN)
	footer.grow_horizontal = Control.GROW_DIRECTION_END
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var chip := PanelContainer.new()
	chip.theme_type_variation = "ChipPanel"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	footer.add_child(chip)
	_status_label.theme_type_variation = "DimLabel"
	chip.add_child(_status_label)
	_help_panel.visible = false
	_help_panel.theme_type_variation = "OverlayPanel"
	var help_center := CenterContainer.new()
	help_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(help_center)
	help_center.add_child(_help_panel)
	get_viewport().size_changed.connect(_fit_help)
	var help_box := VBoxContainer.new()
	help_box.add_theme_constant_override("separation", OrreryTheme.SPACE_S)
	_help_panel.add_child(help_box)
	var header := HBoxContainer.new()
	help_box.add_child(header)
	var title := make_label("Controls", "HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(make_close_button(toggle_help, "Close (%s)" % InputBindings.keys_text("toggle_help")))
	_help_flow.add_theme_constant_override("h_separation", OrreryTheme.SPACE_L)
	_help_flow.add_theme_constant_override("v_separation", OrreryTheme.SPACE_M)
	help_box.add_child(_help_flow)


func _sync_preferences() -> void:
	_depth_control.select(Preferences.depth_level)
	_labels_toggle.set_pressed_no_signal(Preferences.labels_visible)
	_trails_toggle.set_pressed_no_signal(Preferences.trails_visible)
	_rings_toggle.set_pressed_no_signal(Preferences.rings_visible)
	var collapsed := Preferences.view_panel_collapsed
	_view_body.visible = not collapsed
	_collapse_button.icon = OrreryTheme.icon("chevron_down" if collapsed else "chevron_up")
	_collapse_button.tooltip_text = "Show view options" if collapsed else "Hide view options to make room for body information"


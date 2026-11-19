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

const OUTER_MARGIN := 14
const SIDE_PANEL_WIDTH := 340
const HELP_HINT := "   |   %s controls"
const AUTO_ORBIT_HINT := "   |   Auto-orbit"
const SPEED_LABEL_WIDTH := 92
const BOTTOM_RESERVE := 60.0
const SCROLLBAR_GUTTER := 12
const DIAGNOSTICS_WIDTH := 240
const TOAST_SECONDS := 2.5

var left_column := VBoxContainer.new()
var right_column := VBoxContainer.new()
var top_center := VBoxContainer.new()
var bottom_center := VBoxContainer.new()

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
var _help_label := Label.new()
var _diagnostics_panel := PanelContainer.new()
var _diag_values: Dictionary[String, Label] = {}
var _toast_panel := PanelContainer.new()
var _toast_label := Label.new()
var _toast_timer := 0.0
var _frame_ms := 16.7
var _cpu_ms := 1.0
var _auto_orbit_active := false
var _quality_option := OptionButton.new()
var _depth_control := SegmentedControl.new(Preferences.DEPTH_NAMES, "Information depth (M)")
var _labels_toggle: Button
var _trails_toggle: Button
var _rings_toggle: Button
var _mode_button := Button.new()
var _settings_extras := VBoxContainer.new()


static func make_panel(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box


static func make_button(label: String, pressed_callback: Callable, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed_callback)
	return button


static func make_accent_button(label: String, pressed_callback: Callable, tooltip: String = "") -> Button:
	var button := make_button(label, pressed_callback, tooltip)
	button.theme_type_variation = "AccentButton"
	return button


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


static func make_toggle(label: String, tooltip: String, toggled_callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
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
	_place_column(bottom_center, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	_build_time_panel()
	_build_settings_panel()
	_build_top_center()
	_build_footer()
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


func set_mode_switch(label: String) -> void:
	_mode_button.text = label
	_mode_button.visible = label != ""


func set_depth_visible(value: bool) -> void:
	_depth_control.visible = value


func set_now_visible(value: bool) -> void:
	_now_button.visible = value
	_now_separator.visible = value


func set_auto_orbit_active(value: bool) -> void:
	_auto_orbit_active = value


func set_status(text: String) -> void:
	var full := text + (AUTO_ORBIT_HINT if _auto_orbit_active else "")
	_status_label.text = full if _help_panel.visible else full + HELP_HINT % InputBindings.keys_text("toggle_help")


func set_help(text: String) -> void:
	_help_label.text = text


func toggle_help() -> void:
	_help_panel.visible = not _help_panel.visible


func set_help_visible(value: bool) -> void:
	_help_panel.visible = value


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
	_date_label.text = Astro.format_date(clock.seconds)
	_speed_label.text = clock.speed_label()
	_reverse_button.set_pressed_no_signal(clock.reversed)
	_pause_button.text = "Play" if clock.paused else "Pause"
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
	var header := HBoxContainer.new()
	box.add_child(header)
	_date_label.theme_type_variation = "HeaderLabel"
	_date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_date_label)
	header.add_child(make_label("UTC", "DimLabel"))
	var row := HBoxContainer.new()
	box.add_child(row)
	_reverse_button.text = "Reverse"
	_reverse_button.toggle_mode = true
	_reverse_button.focus_mode = Control.FOCUS_NONE
	_reverse_button.tooltip_text = "Run time backwards (R)"
	_reverse_button.pressed.connect(func() -> void: reverse_pressed.emit())
	row.add_child(_reverse_button)
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.tooltip_text = "Pause or resume time (Space)"
	_pause_button.custom_minimum_size = Vector2(64, 0)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	row.add_child(_pause_button)
	row.add_child(VSeparator.new())
	row.add_child(make_button("−", func() -> void: slower_pressed.emit(), "Slower ([)"))
	_speed_label.custom_minimum_size = Vector2(SPEED_LABEL_WIDTH, 0)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_speed_label)
	row.add_child(make_button("+", func() -> void: faster_pressed.emit(), "Faster (])"))
	row.add_child(_now_separator)
	_now_button = make_button("Now", func() -> void: now_pressed.emit(), "Jump to the current date (N)")
	row.add_child(_now_button)


func _build_settings_panel() -> void:
	var box := make_panel(right_column)
	box.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH, 0)
	var header := HBoxContainer.new()
	box.add_child(header)
	var view_label := section_label("View")
	view_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(view_label)
	_fps_label.theme_type_variation = "DimLabel"
	header.add_child(_fps_label)
	box.add_child(_depth_control)
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 2)
	box.add_child(toggles)
	_labels_toggle = make_toggle("Labels", "Show body names (L)", Preferences.set_labels_visible)
	_trails_toggle = make_toggle("Orbits", "Show orbit lines (O)", Preferences.set_trails_visible)
	_rings_toggle = make_toggle("Rings", "Show distance rings around the Sun (G)", Preferences.set_rings_visible)
	toggles.add_child(_labels_toggle)
	toggles.add_child(_trails_toggle)
	toggles.add_child(_rings_toggle)
	box.add_child(_settings_extras)
	box.add_child(HSeparator.new())
	var quality_row := HBoxContainer.new()
	box.add_child(quality_row)
	var quality_label := section_label("Graphics")
	quality_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_row.add_child(quality_label)
	quality_row.add_child(_quality_option)
	for preset_name in Quality.PRESET_NAMES:
		_quality_option.add_item(preset_name)
	_quality_option.focus_mode = Control.FOCUS_NONE
	_quality_option.tooltip_text = "Lower quality runs faster on older devices"
	_quality_option.item_selected.connect(func(index: int) -> void: quality_selected.emit(index))
	_quality_option.custom_minimum_size = Vector2(120, 0)
	box.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_mode_button.theme_type_variation = "AccentButton"
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.visible = false
	_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_button.pressed.connect(func() -> void: mode_switch_pressed.emit())
	actions.add_child(_mode_button)
	actions.add_child(make_button("Menu", func() -> void: menu_pressed.emit(), "Pause menu, settings and credits (Esc)"))


func _build_top_center() -> void:
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
	footer.add_theme_constant_override("separation", OUTER_MARGIN - 4)
	_root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, OUTER_MARGIN)
	footer.grow_horizontal = Control.GROW_DIRECTION_END
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.add_child(_help_panel)
	_help_panel.visible = false
	var help_box := VBoxContainer.new()
	_help_panel.add_child(help_box)
	help_box.add_child(section_label("Controls"))
	_help_label.theme_type_variation = "DimLabel"
	help_box.add_child(_help_label)
	var chip := PanelContainer.new()
	chip.theme_type_variation = "ChipPanel"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	footer.add_child(chip)
	chip.add_child(_status_label)


func _sync_preferences() -> void:
	_depth_control.select(Preferences.depth_level)
	_labels_toggle.set_pressed_no_signal(Preferences.labels_visible)
	_trails_toggle.set_pressed_no_signal(Preferences.trails_visible)
	_rings_toggle.set_pressed_no_signal(Preferences.rings_visible)


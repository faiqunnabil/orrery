class_name Onboarding
extends Control

signal finished

const PANEL_WIDTH := 330
const TEXT_WIDTH := 298
const GAP := 14.0
const HIGHLIGHT_PADDING := 6.0
const HIGHLIGHT_WIDTH := 2.0
const SCREEN_MARGIN := 16.0

var _steps: Array[Dictionary] = []
var _index := 0
var _panel := PanelContainer.new()
var _title := Label.new()
var _text: Label
var _counter := Label.new()
var _back: Button
var _next: Button
var _target := Rect2()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel.theme_type_variation = "OverlayPanel"
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", OrreryTheme.SPACE_S)
	_panel.add_child(box)
	_title.theme_type_variation = "HeaderLabel"
	box.add_child(_title)
	_text = Hud.make_wrapped_label("", TEXT_WIDTH)
	box.add_child(_text)
	var footer := HBoxContainer.new()
	box.add_child(footer)
	_counter.theme_type_variation = "DimLabel"
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_counter)
	var skip := Hud.make_button("Skip", finish, "Close the introduction (Esc)")
	skip.theme_type_variation = "FlatButton"
	footer.add_child(skip)
	_back = Hud.make_icon_button("chevron_left", back, "Previous tip (Left)")
	footer.add_child(_back)
	_next = Hud.make_accent_button("Next", advance, "Next tip (Right or Enter)", "chevron_right")
	_next.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(_next)


func start(steps: Array[Dictionary]) -> void:
	_steps = steps
	_index = 0
	visible = true
	_show_step()


func is_running() -> bool:
	return visible


func advance() -> void:
	if _index + 1 >= _steps.size():
		finish()
		return
	_index += 1
	_show_step()


func back() -> void:
	if _index > 0:
		_index -= 1
		_show_step()


func finish() -> void:
	if not visible:
		return
	visible = false
	finished.emit()


func _show_step() -> void:
	var step := _steps[_index]
	_title.text = step["title"]
	_text.text = step["text"]
	_counter.text = tr("%d of %d") % [_index + 1, _steps.size()]
	_back.disabled = _index == 0
	_next.text = "Start exploring" if _index + 1 == _steps.size() else "Next"
	_place()


func _process(_delta: float) -> void:
	if visible:
		_place()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("cancel"):
		finish()
	elif event.is_action_pressed("tour_next"):
		advance()
	elif event.is_action_pressed("tour_previous"):
		back()
	else:
		return
	get_viewport().set_input_as_handled()


func _place() -> void:
	var step := _steps[_index]
	var target_callable: Callable = step.get("target", Callable())
	var target: Control = target_callable.call() if target_callable.is_valid() else null
	var viewport := get_viewport_rect().size
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	if target == null or not target.is_visible_in_tree():
		_target = Rect2()
		_panel.position = ((viewport - panel_size) * 0.5).round()
		queue_redraw()
		return
	_target = target.get_global_rect().grow(HIGHLIGHT_PADDING)
	var position := Vector2(_target.end.x + GAP, _target.position.y)
	if position.x + panel_size.x > viewport.x - SCREEN_MARGIN:
		position = Vector2(_target.position.x - GAP - panel_size.x, _target.position.y)
	if position.x < SCREEN_MARGIN:
		position = Vector2(_target.position.x, _target.end.y + GAP)
	position.x = clampf(position.x, SCREEN_MARGIN, viewport.x - panel_size.x - SCREEN_MARGIN)
	position.y = clampf(position.y, SCREEN_MARGIN, viewport.y - panel_size.y - SCREEN_MARGIN)
	_panel.position = position.round()
	queue_redraw()


func _draw() -> void:
	if _target.size == Vector2.ZERO:
		return
	var style := OrreryTheme.focus_ring(OrreryTheme.PANEL_RADIUS)
	style.set_border_width_all(int(HIGHLIGHT_WIDTH))
	style.set_expand_margin_all(0.0)
	draw_style_box(style, _target)

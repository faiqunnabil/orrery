class_name DatePanel
extends PanelContainer

signal date_chosen(unix_seconds: float)
signal eclipse_requested(direction: int)
signal closed

const PANEL_WIDTH := 330
const MIN_YEAR := 1800
const MAX_YEAR := 2050
const EVENTS := [
	["Apollo 11 lands on the Moon", "1969-07-20T20:17:00"],
	["Jupiter and Saturn meet in the sky", "2020-12-21T18:00:00"],
	["Total solar eclipse over North Africa", "2027-08-02T10:07:00"],
]

var _field := LineEdit.new()
var _error := Label.new()
var _offset_minutes := 0


func _init() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", OrreryTheme.SPACE_S)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Hud.make_label("Go to a date", "HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(Hud.make_close_button(close))
	var row := HBoxContainer.new()
	box.add_child(row)
	_field.placeholder_text = "YYYY-MM-DD HH:MM"
	_field.keep_editing_on_text_submit = true
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.text_submitted.connect(func(_text: String) -> void: _submit())
	_field.gui_input.connect(_on_field_input)
	row.add_child(_field)
	row.add_child(Hud.make_accent_button("Go", _submit, "Jump to this date (Enter)", "corner_down_left"))
	_error.theme_type_variation = "DangerLabel"
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.visible = false
	box.add_child(_error)
	var note := Hud.make_label(tr("Dates from %d to %d, in this computer's time zone.") % [MIN_YEAR, MAX_YEAR], "DimLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	box.add_child(HSeparator.new())
	box.add_child(Hud.section_label("Moments to visit"))
	for event: Array in EVENTS:
		var unix := Time.get_unix_time_from_datetime_string(event[1])
		var button := Hud.make_button(event[0], func() -> void: _choose(unix), "", "calendar")
		button.theme_type_variation = "FlatButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(button)
	box.add_child(HSeparator.new())
	box.add_child(Hud.section_label("Eclipses"))
	var eclipse_row := HBoxContainer.new()
	eclipse_row.add_theme_constant_override("separation", OrreryTheme.SPACE_S)
	box.add_child(eclipse_row)
	var previous := Hud.make_button("Previous", func() -> void: _request_eclipse(-1), "Go to the previous solar or lunar eclipse", "chevron_left")
	var next := Hud.make_button("Next", func() -> void: _request_eclipse(1), "Go to the next solar or lunar eclipse", "chevron_right")
	next.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for button in [previous, next]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eclipse_row.add_child(button)
	var eclipse_note := Hud.make_label("Shows the moment of greatest eclipse at true scale.", "DimLabel")
	eclipse_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(eclipse_note)


func open(current_unix: float, offset_minutes: int) -> void:
	_offset_minutes = offset_minutes
	_field.text = _format(current_unix)
	_error.visible = false
	visible = true
	_field.grab_focus()
	_field.select_all()


func close() -> void:
	if not visible:
		return
	visible = false
	_field.release_focus()
	closed.emit()


func is_open() -> bool:
	return visible


static func parse_local(text: String, offset_minutes: int) -> Variant:
	var cleaned := text.strip_edges().replace("T", " ")
	var regex := RegEx.create_from_string("^(\\d{4})-(\\d{1,2})-(\\d{1,2})(?:\\s+(\\d{1,2}):(\\d{2}))?$")
	var found := regex.search(cleaned)
	if found == null:
		return null
	var year := int(found.get_string(1))
	var month := int(found.get_string(2))
	var day := int(found.get_string(3))
	var hour := int(found.get_string(4)) if found.get_string(4) != "" else 0
	var minute := int(found.get_string(5)) if found.get_string(5) != "" else 0
	if month < 1 or month > 12 or day < 1 or day > _days_in_month(year, month) or hour > 23 or minute > 59:
		return null
	var dictionary := {"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}
	return float(Time.get_unix_time_from_datetime_dict(dictionary)) - offset_minutes * 60.0


static func first_unix() -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": MIN_YEAR, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0}))


static func last_unix() -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": MAX_YEAR, "month": 12, "day": 31, "hour": 23, "minute": 59, "second": 59}))


static func _days_in_month(year: int, month: int) -> int:
	if month == 2:
		var leap := (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
		return 29 if leap else 28
	return 30 if month in [4, 6, 9, 11] else 31


func _format(unix: float) -> String:
	var local := Time.get_datetime_dict_from_unix_time(int(unix) + _offset_minutes * 60)
	return "%04d-%02d-%02d %02d:%02d" % [local["year"], local["month"], local["day"], local["hour"], local["minute"]]


func _submit() -> void:
	var parsed: Variant = parse_local(_field.text, _offset_minutes)
	if parsed == null:
		_show_error(tr("Write the date as YYYY-MM-DD, optionally followed by HH:MM."))
		return
	var year := int(_field.text.strip_edges().substr(0, 4))
	if year < MIN_YEAR or year > MAX_YEAR:
		_show_error(tr("The orbits are accurate from %d to %d. Choose a date in that range.") % [MIN_YEAR, MAX_YEAR])
		return
	_choose(parsed)


func _choose(unix: float) -> void:
	close()
	date_chosen.emit(unix)


func _request_eclipse(direction: int) -> void:
	close()
	eclipse_requested.emit(direction)


func _show_error(message: String) -> void:
	_error.text = message
	_error.visible = true


func _on_field_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		accept_event()

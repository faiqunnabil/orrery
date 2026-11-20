class_name TourPanel
extends PanelContainer

signal previous_pressed
signal next_pressed
signal exit_pressed
signal replay_pressed

const PANEL_WIDTH := 560
const CONTENT_WIDTH := 528

var _tour_title: Label
var _counter: Label
var _step_title := Label.new()
var _text: Label
var _progress := ProgressBar.new()
var _previous_button: Button
var _next_button: Button
var _voice_toggle: Button
var _replay_button: Button


func _init() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_tour_title = Hud.section_label("")
	_tour_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_tour_title)
	_counter = Hud.make_label("", "DimLabel")
	header.add_child(_counter)
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 3)
	box.add_child(_progress)
	_step_title.theme_type_variation = "TitleLabel"
	box.add_child(_step_title)
	_text = Hud.make_wrapped_label("", CONTENT_WIDTH)
	box.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	var exit := Hud.make_button("Exit tour", func() -> void: exit_pressed.emit(), "Leave the tour (Esc)", "log_out")
	exit.theme_type_variation = "FlatButton"
	buttons.add_child(exit)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_voice_toggle = Hud.make_toggle("Voice", "Play the voice-over (captions always stay visible)", Audio.set_narration_enabled, "volume_2")
	_voice_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	buttons.add_child(_voice_toggle)
	_replay_button = Hud.make_icon_button(
		"rotate_ccw", func() -> void: replay_pressed.emit(), "Replay the voice-over for this step", "IconFlatButton"
	)
	buttons.add_child(_replay_button)
	_previous_button = Hud.make_icon_button("chevron_left", func() -> void: previous_pressed.emit(), "Previous step (Left)")
	_next_button = Hud.make_accent_button("Next", func() -> void: next_pressed.emit(), "Next step (Right or Enter)", "chevron_right")
	_next_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buttons.add_child(_previous_button)
	buttons.add_child(_next_button)


func _ready() -> void:
	Audio.changed.connect(_sync_voice)
	_sync_voice()


func show_step(tour_title: String, step: Dictionary, index: int, count: int) -> void:
	visible = true
	_tour_title.text = tr(tour_title).to_upper()
	_counter.text = tr("Step %d of %d") % [index + 1, count]
	_progress.max_value = count
	_progress.value = index + 1
	_step_title.text = step["title"]
	_text.text = _text_for(step)
	_previous_button.disabled = index == 0
	_next_button.text = "Finish" if index == count - 1 else "Next"


func refresh_text(step: Dictionary) -> void:
	_text.text = _text_for(step)


func dismiss() -> void:
	visible = false


func _text_for(step: Dictionary) -> String:
	if Preferences.is_scientist() and step.has("text_scientist"):
		return step["text_scientist"]
	return step["text"]


func _sync_voice() -> void:
	_voice_toggle.set_pressed_no_signal(Audio.narration_enabled)
	_replay_button.disabled = not Audio.narration_enabled

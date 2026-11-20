class_name QuizPanel
extends PanelContainer

signal closed

enum Stage { INTRO, QUESTION, ANSWERED, RESULTS }

const PANEL_WIDTH := 560
const CONTENT_WIDTH := 528
const OPTION_LETTERS := "ABCDEFGH"
const PASS_RATIO := 0.6

var _title: Label
var _counter: Label
var _progress := ProgressBar.new()
var _heading := Label.new()
var _body: Label
var _options := VBoxContainer.new()
var _feedback: Label
var _feedback_panel := PanelContainer.new()
var _secondary_button: Button
var _primary_button: Button
var _tour_title := ""
var _questions: Array[Dictionary] = []
var _index := 0
var _score := 0
var _stage := Stage.INTRO


func _init() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_title = Hud.section_label("")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_counter = Hud.make_label("", "DimLabel")
	header.add_child(_counter)
	header.add_child(Hud.make_close_button(close_quiz, "Close the quiz (Esc)"))
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 3)
	box.add_child(_progress)
	_heading.theme_type_variation = "HeaderLabel"
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)
	box.add_child(_heading)
	_body = Hud.make_wrapped_label("", CONTENT_WIDTH, "DimLabel")
	box.add_child(_body)
	_options.add_theme_constant_override("separation", 6)
	box.add_child(_options)
	_feedback = Hud.make_wrapped_label("", CONTENT_WIDTH - 2 * OrreryTheme.SPACE_M - 3, "InfoLabel")
	_feedback_panel.add_child(_feedback)
	box.add_child(_feedback_panel)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	_secondary_button = Hud.make_button("", _on_secondary)
	_secondary_button.theme_type_variation = "FlatButton"
	buttons.add_child(_secondary_button)
	_primary_button = Hud.make_accent_button("", advance, "Continue (Enter)", "chevron_right")
	_primary_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buttons.add_child(_primary_button)


func offer(tour_title: String, questions: Array[Dictionary]) -> void:
	_prepare(tour_title, questions)
	_stage = Stage.INTRO
	_counter.text = ""
	_progress.value = 0
	_heading.text = "Ready for a quick quiz?"
	_body.text = tr("Answer %d questions about the %s tour.") % [_questions.size(), tr(tour_title)]
	_body.visible = true
	_set_options([])
	_feedback_panel.visible = false
	_show_buttons("Not now", "Start quiz")


func start(tour_title: String, questions: Array[Dictionary]) -> void:
	_prepare(tour_title, questions)
	_show_question()


func advance() -> void:
	match _stage:
		Stage.INTRO:
			_show_question()
		Stage.ANSWERED:
			_index += 1
			if _index < _questions.size():
				_show_question()
			else:
				_show_results()
		Stage.RESULTS:
			close_quiz()


func close_quiz() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _prepare(tour_title: String, questions: Array[Dictionary]) -> void:
	_tour_title = tour_title
	_questions = questions
	_index = 0
	_score = 0
	_title.text = (tr("Quiz: %s") % tr(tour_title)).to_upper()
	_progress.max_value = maxi(_questions.size(), 1)
	visible = true


func _show_question() -> void:
	_stage = Stage.QUESTION
	var question := _questions[_index]
	_counter.text = tr("Question %d of %d") % [_index + 1, _questions.size()]
	_progress.value = _index
	_heading.text = question["question"]
	_body.visible = false
	var labels: Array[String] = []
	for option: Variant in question["options"]:
		labels.append(str(option))
	_set_options(labels)
	_feedback_panel.visible = false
	_primary_button.visible = false
	_secondary_button.visible = false


func _answer(choice: int) -> void:
	if _stage != Stage.QUESTION:
		return
	_stage = Stage.ANSWERED
	var question := _questions[_index]
	var correct := int(question["answer"])
	var right := choice == correct
	if right:
		_score += 1
	Audio.play_effect(&"place" if right else &"remove")
	var buttons := _options.get_children()
	for index in buttons.size():
		var button := buttons[index] as Button
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if index == correct:
			button.theme_type_variation = "SuccessButton"
			button.icon = OrreryTheme.icon("check")
			button.tooltip_text = "Correct answer"
		elif index == choice:
			button.theme_type_variation = "DangerButton"
			button.icon = OrreryTheme.icon("x")
			button.tooltip_text = "Your answer"
		else:
			button.theme_type_variation = "FlatButton"
			button.modulate = Color(1, 1, 1, 0.6)
	var verdict := tr("Correct.") if right else tr("Not quite. The correct answer is %s.") % OPTION_LETTERS[correct]
	_feedback.text = verdict + " " + tr(str(question.get("explanation", "")))
	_feedback_panel.theme_type_variation = "SuccessCallout" if right else "DangerCallout"
	_feedback_panel.visible = true
	_progress.value = _index + 1
	_show_buttons("", "See results" if _index + 1 >= _questions.size() else "Next question")


func _show_results() -> void:
	_stage = Stage.RESULTS
	_counter.text = ""
	_heading.text = tr("You answered %d of %d correctly.") % [_score, _questions.size()]
	var ratio := float(_score) / float(maxi(_questions.size(), 1))
	if _score == _questions.size():
		_body.text = "A perfect score. You know this tour inside out."
	elif ratio >= PASS_RATIO:
		_body.text = "Well done. Replay the tour to review the questions you missed."
	else:
		_body.text = "Replay the tour, then try again. Switching the information level changes the questions."
	_body.visible = true
	_set_options([])
	_feedback_panel.visible = false
	_show_buttons("Try again", "Close")


func _on_secondary() -> void:
	match _stage:
		Stage.INTRO:
			close_quiz()
		Stage.RESULTS:
			_index = 0
			_score = 0
			_show_question()


func _set_options(labels: Array[String]) -> void:
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for index in labels.size():
		var button := Hud.make_button("%s.   %s" % [OPTION_LETTERS[index], tr(labels[index])], _answer.bind(index))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)
		_options.add_child(button)
	_options.visible = not labels.is_empty()


func _show_buttons(secondary: String, primary: String) -> void:
	_secondary_button.text = secondary
	_secondary_button.visible = secondary != ""
	_primary_button.text = primary
	_primary_button.visible = primary != ""

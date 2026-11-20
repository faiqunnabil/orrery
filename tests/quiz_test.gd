extends SceneTree

var frame := 0
var step := 0
var wait := 60
var failures := 0
var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	change_scene_to_file("res://modes/explore/explore_mode.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame < wait:
		return false
	frame = 0
	wait = 15
	_run_step()
	step += 1
	return false


func _check(label: String, condition: bool) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		failures += 1


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


func _click_button(text: String, index: int = 0) -> bool:
	var found := 0
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with(text) and button.is_visible_in_tree():
			if found == index:
				var center := button.get_global_rect().get_center()
				for pressed in [true, false]:
					var event := InputEventMouseButton.new()
					event.button_index = MOUSE_BUTTON_LEFT
					event.pressed = pressed
					event.position = center
					event.global_position = center
					root.push_input(event)
				return true
			found += 1
	print("  (button not found: ", text, ")")
	return false


func _shot(name: String) -> void:
	if out_dir == "":
		return
	root.get_texture().get_image().save_jpg("%s/%s.jpg" % [out_dir, name], 0.85)


func _run_step() -> void:
	var scene := current_scene
	var quiz = scene._quiz_panel
	match step:
		0:
			if root.get_node("Preferences").is_scientist():
				_key(KEY_M)
			_click_button("Guided tours")
		1:
			_shot("tour_menu")
			_check("tour menu lists four quiz buttons", scene._tour_menu.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Quiz").size() == 4)
			_click_button("Quiz", 0)
		2:
			_check("quiz opens from the tour menu", quiz.is_open() and quiz._stage == 1)
			_click_button("B.")
		3:
			_check("correct answer scores", quiz._score == 1 and quiz._stage == 2)
			_shot("quiz_correct")
			_key(KEY_ENTER)
		4:
			_check("Enter moves to the next question", quiz._index == 1 and quiz._stage == 1)
			_click_button("A.")
		5:
			_check("wrong answer does not score", quiz._score == 1)
			_shot("quiz_wrong")
			for i in 3:
				pass
			_click_button("Next question")
		6:
			_click_button("A.")
		7:
			_click_button("Next question")
		8:
			_click_button("A.")
		9:
			_click_button("Next question")
		10:
			_click_button("C.")
		11:
			_click_button("See results")
		12:
			_check("results stage reached", quiz._stage == 3)
			_shot("quiz_results")
			_key(KEY_ESCAPE)
		13:
			_check("Esc closes the quiz", not quiz.is_open())
			var tour: Dictionary = scene._tours[1]
			scene._tour_player.start(tour)
			wait = 30
		14:
			for i in scene._tours[1]["steps"].size():
				scene._tour_player.next()
		15:
			_check("finishing a tour offers its quiz", quiz.is_open() and quiz._stage == 0)
			_shot("quiz_offer")
			_click_button("Not now")
		16:
			_check("Not now closes the offer", not quiz.is_open())
			print("FAILURES: ", failures)
			quit()

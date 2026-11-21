extends SceneTree

const KNOWN_2026 := [
	["2026-02-17T12:12:00", 0, 2],
	["2026-03-03T11:33:00", 1, 1],
	["2026-08-12T17:46:00", 0, 1],
	["2026-08-28T04:13:00", 1, 0],
]
const TOLERANCE_SECONDS := 300.0

var frame := 0
var step := 0
var wait := 90
var failures := 0
var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	root.get_node("Preferences").set_onboarding_done(true)
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


func _shot(name: String) -> void:
	if out_dir == "":
		return
	root.get_texture().get_image().save_jpg("%s/%s.jpg" % [out_dir, name], 0.85)


func _seconds(text: String) -> float:
	return Time.get_unix_time_from_datetime_string(text) - 946728000.0


func _click_button(text: String) -> bool:
	for node in current_scene.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text and button.is_visible_in_tree():
			button.pressed.emit()
			return true
	return false


func _narrated(tour_id: String, steps: int) -> bool:
	for index in steps:
		for level in ["explorer", "scientist"]:
			if not ResourceLoader.exists("res://assets/audio/narration/%s_%02d_%s.ogg" % [tour_id, index + 1, level]):
				return false
	return true


func _run_step() -> void:
	var scene := current_scene
	var visual = scene.renderer._visuals
	match step:
		0:
			var search = scene._eclipse_search
			var t := _seconds("2026-01-01T00:00:00")
			var matched := 0
			for known: Array in KNOWN_2026:
				var eclipse: Dictionary = search.find(t, 1, t - 1.0, t + 400.0 * 86400.0)
				if eclipse.is_empty():
					break
				var close_enough := absf(eclipse["seconds"] - _seconds(known[0])) < TOLERANCE_SECONDS
				if close_enough and eclipse["kind"] == known[1] and eclipse["type"] == known[2]:
					matched += 1
				else:
					print("  got ", eclipse, " expected ", known)
				t = eclipse["seconds"]
			_check("the 2026 eclipses match NASA's times and types within 5 minutes", matched == KNOWN_2026.size())
			var back: Dictionary = search.find(_seconds("2027-08-02T12:00:00"), -1, _seconds("2026-01-01T00:00:00"), _seconds("2028-01-01T00:00:00"))
			_check("searching backwards finds the February 2027 annular eclipse", not back.is_empty() and absf(back["seconds"] - _seconds("2027-02-06T16:00:00")) < TOLERANCE_SECONDS)
			scene.clock.paused = true
			scene.clock.seconds = _seconds("2026-07-01T00:00:00")
			scene._open_date_panel()
		1:
			_shot("eclipse_date_panel")
			_check("the date panel offers the next eclipse", _click_button("Next"))
			wait = 240
		2:
			_check("Next jumps to the August 2026 total solar eclipse", absf(scene.clock.seconds - _seconds("2026-08-12T17:46:00")) < TOLERANCE_SECONDS)
			_check("the eclipse is shown at true scale", scene.renderer.mapper.mode == ScaleMapper.Mode.TRUE_SCALE)
			_check("a solar eclipse focuses Earth", scene.camera.anchor_id == "earth" and scene._selected_id == "earth")
			_check("time slows to one minute per second", scene.clock.step_index == 1 and not scene.clock.reversed)
			_check("the toast names the eclipse", scene.hud._toast_label.text.contains("Total solar eclipse"))
			_check("the Moon's shadow falls on Earth", visual["earth"]._eclipse_count >= 1)
			_shot("eclipse_solar")
			scene._open_date_panel()
		3:
			_check("the date panel offers the previous eclipse", _click_button("Previous"))
			wait = 240
		4:
			_check("Previous jumps to the March 2026 total lunar eclipse", absf(scene.clock.seconds - _seconds("2026-03-03T11:33:00")) < TOLERANCE_SECONDS)
			_check("a lunar eclipse focuses the Moon", scene.camera.anchor_id == "moon")
			_check("Earth's shadow falls on the Moon", visual["moon"]._eclipse_count == 1)
			_shot("eclipse_lunar")
			scene._set_scale_mode(ScaleMapper.Mode.COMPRESSED)
			scene._start_tour("eclipses_comets")
			wait = 240
		5:
			_check("the eclipse tour opens on the March 2026 lunar eclipse", absf(scene.clock.seconds - _seconds("2026-03-03T11:33:00")) < TOLERANCE_SECONDS)
			_check("the tour shows the red Moon at true scale", scene.camera.anchor_id == "moon" and scene.renderer.mapper.mode == ScaleMapper.Mode.TRUE_SCALE)
			_check("the tour step has its narration", _narrated("eclipses_comets", 5))
			scene._tour_player.next()
			wait = 240
		6:
			_check("the second stop frames the Moon's shadow on Earth", scene.camera.anchor_id == "earth" and visual["earth"]._eclipse_count >= 1)
			scene._tour_player.next()
			wait = 240
		7:
			_check("the third stop shows a full moon outside Earth's shadow", scene.camera.anchor_id == "moon" and visual["moon"]._eclipse_count == 0)
			scene._tour_player.next()
			wait = 240
		8:
			var tail = scene.renderer.comet_tail("halley")
			_check("the fourth stop visits Halley's Comet in 1986 with its tails", scene.camera.anchor_id == "halley" and tail.visible)
			var offset: PackedFloat64Array = scene.camera.offset
			_check("the tour frames the whole comet tail", Vector3(offset[0], offset[1], offset[2]).length() > tail.length)
			_check("comets switch the tour back to the compressed scale", scene.renderer.mapper.mode == ScaleMapper.Mode.COMPRESSED)
			_shot("tour_comet")
			scene._tour_player.next()
			wait = 60
		9:
			scene._tour_player.next()
			wait = 30
		10:
			_check("finishing the tour offers its quiz", scene._quiz_panel.visible)
			_check("the quiz has five questions at each level", scene._quiz_catalog.questions("eclipses_comets", false).size() == 5 and scene._quiz_catalog.questions("eclipses_comets", true).size() == 5)
			print("FAILURES: ", failures)
			quit()

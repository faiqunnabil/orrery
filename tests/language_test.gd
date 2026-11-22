extends SceneTree

var frame := 0
var step := 0
var wait := 90
var failures := 0
var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	var preferences := root.get_node("Preferences")
	preferences.set_onboarding_done(true)
	preferences.set_language("id")
	change_scene_to_file("res://modes/menu/main_menu.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame < wait:
		return false
	frame = 0
	wait = 20
	_run_step()
	step += 1
	return false


func _check(label: String, condition: bool) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		failures += 1
		_save_failure()


func _save_failure() -> void:
	var directory := OS.get_environment("FAILURE_DIR")
	if directory == "":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var path := "%s/%s_failure_%d.jpg" % [directory, get_script().resource_path.get_file().get_basename(), failures]
	root.get_texture().get_image().save_jpg(path, 0.85)
	print("      screenshot ", path)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)


func _type(text: String) -> void:
	for character in text:
		for pressed in [true, false]:
			var event := InputEventKey.new()
			event.unicode = character.unicode_at(0)
			event.pressed = pressed
			root.push_input(event)


func _shot(name: String) -> void:
	if out_dir == "":
		return
	root.get_texture().get_image().save_jpg("%s/%s.jpg" % [out_dir, name], 0.85)


func _info_rows(scene) -> String:
	var rows: Array[String] = []
	for label in scene._info_panel._row_labels:
		rows.append(label.text)
	return " | ".join(rows)


func _run_step() -> void:
	var scene := current_scene
	match step:
		0:
			_check("choosing Indonesian sets the locale", TranslationServer.get_locale().begins_with("id"))
			_check("the main menu text is translated", root.tr("Explore") == "Jelajah" and root.tr("Settings") == "Pengaturan")
			_check("body names are translated", root.tr("Earth") == "Bumi" and root.tr("Sun") == "Matahari")
			_check("tour and quiz text is translated", root.tr("Grand Tour") == "Tur Besar" and root.tr("Start quiz") == "Mulai kuis")
			_shot("language_menu")
			change_scene_to_file("res://modes/explore/explore_mode.tscn")
			wait = 120
		1:
			scene.clock.paused = true
			root.get_node("Preferences").set_depth_level(0)
			scene._select("earth")
		2:
			var rows := _info_rows(scene)
			_check("composed body facts are translated", rows.contains("x Bumi") and rows.contains("hari Bumi"))
			_check("thousands use a dot in Indonesian", rows.contains("12.742 km"))
			_shot("language_explore")
			root.get_node("Preferences").set_depth_level(1)
			scene._select("earth")
		3:
			var rows := _info_rows(scene)
			_check("decimals use a comma in Indonesian", rows.contains("23,44") and rows.contains("9,82"))
			_check("degrees use a language-neutral symbol", rows.contains("°") and not rows.contains(" deg"))
			_shot("language_scientist")
			_key(KEY_SLASH)
		4:
			_type("bum")
		5:
			var matches: Array = scene.hud.search_panel._matches
			_check("search finds bodies by their Indonesian name", matches.size() > 0 and matches[0] == "earth")
			_shot("language_search")
			_key(KEY_ESCAPE)
		6:
			scene._open_pause_menu()
		7:
			var menu = scene.pause_menu._menu
			menu.open_settings()
			menu._settings._show_page(2)
		8:
			var settings = scene.pause_menu._menu._settings
			_check("the voice-over toggle is disabled for Indonesian", settings._voice_over_toggle.disabled)
			_check("the settings explain that the voice is English only", settings._voice_note.visible)
			_shot("language_settings")
			root.get_node("Preferences").set_depth_level(0)
			root.get_node("Preferences").set_language("en")
		9:
			_check("switching back restores English", TranslationServer.get_locale().begins_with("en") and root.tr("Explore") == "Explore")
			print("FAILURES: ", failures)
			quit()

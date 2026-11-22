extends SceneTree

var frame := 0
var failures := 0


func _initialize() -> void:
	root.get_node("Preferences").set_onboarding_done(true)
	change_scene_to_file("res://modes/explore/explore_mode.tscn")


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


func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node
	for child in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 60:
		current_scene.clock.paused = true
		current_scene.clock.jump_to_now()
	if frame == 70:
		var zone: Dictionary = Time.get_time_zone_from_system()
		print("system zone: ", zone)
		var local := Time.get_datetime_string_from_system(false, true).substr(0, 16)
		var shown: String = current_scene.hud._date_label.text
		print("local ", local, " | shown ", shown)
		_check("date label shows local time after Now", shown == local)
		var expected := Astro.utc_offset_label(int(zone["bias"]))
		_check("zone label %s is shown in the HUD" % expected, _find_label(current_scene.hud, expected) != null)
		_check("UTC+7 label", Astro.utc_offset_label(420) == "UTC+7")
		_check("UTC+5:30 label", Astro.utc_offset_label(330) == "UTC+5:30")
		_check("UTC-3 label", Astro.utc_offset_label(-180) == "UTC-3")
		_check("UTC-9:30 label", Astro.utc_offset_label(-570) == "UTC-9:30")
		_check("UTC label", Astro.utc_offset_label(0) == "UTC")
		_check("offset crosses midnight", Astro.format_date(0.0, 720) == "2000-01-02 00:00")
		_check("UTC formatting unchanged", Astro.format_date(0.0) == "2000-01-01 12:00")
		print("FAILURES: ", failures)
		quit()
	return false

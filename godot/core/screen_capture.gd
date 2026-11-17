class_name ScreenCapture
extends RefCounted

const DEV_DIR := "res://../screenshots"
const USER_DIR := "user://screenshots"
const MAX_SUFFIX := 99

static var _capturing := false


static func is_capturing() -> bool:
	return _capturing


static func save_frame(viewport: Viewport) -> String:
	if _capturing:
		return ""
	_capturing = true
	await RenderingServer.frame_post_draw
	var saved := capture_viewport(viewport)
	_capturing = false
	return saved


static func capture_viewport(viewport: Viewport) -> String:
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return ""
	var directory := _target_directory()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return ""
	var path := _unique_path(directory)
	if image.save_png(path) != OK:
		return ""
	return _display_path(path)


static func _target_directory() -> String:
	var base := DEV_DIR if OS.has_feature("editor") else USER_DIR
	return ProjectSettings.globalize_path(base).simplify_path()


static func _unique_path(directory: String) -> String:
	var now := Time.get_datetime_dict_from_system()
	var stem := "orrery_%04d%02d%02d_%02d%02d%02d" % [
		now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"]
	]
	var candidate := directory.path_join(stem + ".png")
	if not FileAccess.file_exists(candidate):
		return candidate
	for index in range(1, MAX_SUFFIX + 1):
		candidate = directory.path_join("%s_%02d.png" % [stem, index])
		if not FileAccess.file_exists(candidate):
			return candidate
	return directory.path_join("%s_%d.png" % [stem, Time.get_ticks_msec()])


static func _display_path(path: String) -> String:
	var prefix := "screenshots/" if OS.has_feature("editor") else "user://screenshots/"
	return prefix + path.get_file()

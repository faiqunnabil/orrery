class_name SessionState
extends RefCounted

static var _scene_path := ""
static var _state: Dictionary = {}


static func store(scene_path: String, state: Dictionary) -> void:
	_scene_path = scene_path
	_state = state


static func take(scene_path: String) -> Dictionary:
	var state := _state if scene_path == _scene_path else {}
	_scene_path = ""
	_state = {}
	return state

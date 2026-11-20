class_name BodyLabels
extends Control

const FONT_SIZE := 13
const OUTLINE_SIZE := 4
const LABEL_OFFSET := Vector2(8, 5)
const LABEL_PADDING := 3.0
const SELECTION_PADDING := 7.0
const MIN_SELECTION_RADIUS := 12.0
const TEXT_COLOR := Color(1, 1, 1, 0.92)
const OUTLINE_COLOR := Color(0, 0, 0, 0.85)
const DIM_TEXT_COLOR := Color(0.72, 0.8, 0.92, 0.72)

var _entries: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_entries(entries: Array) -> void:
	_entries = entries
	queue_redraw()


func _draw() -> void:
	var font := OrreryTheme.font("medium")
	var placed: Array[Rect2] = []
	for index in _priority_order():
		var entry: Dictionary = _entries[index]
		var position: Vector2 = entry["position"]
		var radius: float = entry["radius"]
		if entry["selected"]:
			draw_arc(position, maxf(radius + SELECTION_PADDING, MIN_SELECTION_RADIUS), 0.0, TAU, 48, OrreryTheme.SELECTION, 2.0, true)
		if not entry["labeled"]:
			continue
		var text: String = entry["name"]
		var origin := position + Vector2(radius, 0.0) + LABEL_OFFSET
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var rect := Rect2(origin - Vector2(0.0, font.get_ascent(FONT_SIZE)), text_size).grow(LABEL_PADDING)
		if not entry["selected"] and placed.any(func(other: Rect2) -> bool: return other.intersects(rect)):
			continue
		placed.append(rect)
		var color := DIM_TEXT_COLOR if entry.get("dim", false) else TEXT_COLOR
		draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, OUTLINE_COLOR)
		draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _priority_order() -> Array[int]:
	var order: Array[int] = []
	for index in _entries.size():
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return _priority(_entries[a]) > _priority(_entries[b]))
	return order


func _priority(entry: Dictionary) -> float:
	var score: float = entry["radius"]
	if entry["selected"]:
		score += 1.0e6
	if entry.get("dim", false):
		score -= 1.0e3
	return score

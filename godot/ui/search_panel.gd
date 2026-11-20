class_name SearchPanel
extends PanelContainer

signal chosen(id: String)
signal closed

const PANEL_WIDTH := 380
const MAX_RESULTS := 8
const NAME_PREFIX_SCORE := 0
const WORD_PREFIX_SCORE := 1
const NAME_CONTAINS_SCORE := 2
const DETAIL_SCORE := 3

var _field := LineEdit.new()
var _results := ItemList.new()
var _empty := Label.new()
var _items: Array[Dictionary] = []
var _matches: Array[String] = []
var _query := ""


func _init() -> void:
	theme_type_variation = "OverlayPanel"
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", OrreryTheme.SPACE_S)
	add_child(box)
	_field.placeholder_text = "Find a body, such as Saturn or Europa"
	_field.right_icon = OrreryTheme.icon("search")
	_field.clear_button_enabled = true
	_field.keep_editing_on_text_submit = true
	_field.text_changed.connect(func(_text: String) -> void: _refresh())
	_field.text_submitted.connect(func(_text: String) -> void: _choose_selected())
	_field.gui_input.connect(_on_field_input)
	box.add_child(_field)
	_results.auto_height = true
	_results.focus_mode = Control.FOCUS_NONE
	_results.item_clicked.connect(func(index: int, _position: Vector2, _button: int) -> void: _choose(index))
	box.add_child(_results)
	_empty.text = "No body matches that name"
	_empty.theme_type_variation = "DimLabel"
	box.add_child(_empty)
	box.add_child(Hud.make_label("Arrow keys to choose, Enter to fly there, Esc to close", "DimLabel"))


func open(items: Array[Dictionary]) -> void:
	_items = items
	visible = true
	_field.text = ""
	_refresh()
	_field.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_field.release_focus()
	closed.emit()


func is_open() -> bool:
	return visible


func _process(_delta: float) -> void:
	if visible and _field.text != _query:
		_refresh()


func _refresh() -> void:
	_query = _field.text
	var query := _query.strip_edges().to_lower()
	var scored: Array = []
	for item in _items:
		var score := _score(item, query)
		if score >= 0:
			scored.append([score, item])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_results.clear()
	_matches.clear()
	for entry: Array in scored.slice(0, MAX_RESULTS):
		var item: Dictionary = entry[1]
		_results.add_item("%s   ·   %s" % [item["name"], item["detail"]])
		_matches.append(item["id"])
	_results.visible = not _matches.is_empty()
	_empty.visible = _matches.is_empty()
	if not _matches.is_empty():
		_results.select(0)


static func _score(item: Dictionary, query: String) -> int:
	if query == "":
		return DETAIL_SCORE
	var best := -1
	for name: String in item.get("keywords", [item["name"]]):
		var lowered := name.to_lower()
		var score := -1
		if lowered.begins_with(query):
			score = NAME_PREFIX_SCORE
		elif (" " + lowered).contains(" " + query):
			score = WORD_PREFIX_SCORE
		elif lowered.contains(query):
			score = NAME_CONTAINS_SCORE
		if score >= 0 and (best < 0 or score < best):
			best = score
	if best < 0 and (" " + str(item["detail"]).to_lower()).contains(" " + query):
		best = DETAIL_SCORE
	return best


func _on_field_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		accept_event()
	elif event.is_action_pressed("ui_down", true):
		_move_selection(1)
		accept_event()
	elif event.is_action_pressed("ui_up", true):
		_move_selection(-1)
		accept_event()


func _move_selection(step: int) -> void:
	if _matches.is_empty():
		return
	var selected := _results.get_selected_items()
	var current := selected[0] if not selected.is_empty() else 0
	_results.select(wrapi(current + step, 0, _matches.size()))


func _choose_selected() -> void:
	var selected := _results.get_selected_items()
	if not selected.is_empty():
		_choose(selected[0])


func _choose(index: int) -> void:
	if index < 0 or index >= _matches.size():
		return
	var id := _matches[index]
	close()
	chosen.emit(id)

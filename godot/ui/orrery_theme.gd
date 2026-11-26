class_name OrreryTheme
extends RefCounted

const ACCENT := Color("#2b63d1")
const ACCENT_HOVER := Color("#3a72e0")
const ACCENT_PRESSED := Color("#2455b5")
const ACCENT_TEXT := Color("#7caeff")
const TEXT := Color("#e6ebf5")
const TEXT_DIM := Color("#9aa6bc")
const TEXT_DISABLED := Color("#7a869c")
const SUCCESS := Color("#5ad08c")
const WARNING := Color("#f2b84b")
const DANGER := Color("#ff7b7b")
const SURFACE := Color(0.039, 0.059, 0.11, 0.9)
const SURFACE_RAISED := Color(0.06, 0.085, 0.15, 0.97)
const BORDER := Color(1.0, 1.0, 1.0, 0.08)
const CONTROL := Color(1.0, 1.0, 1.0, 0.07)
const CONTROL_HOVER := Color(1.0, 1.0, 1.0, 0.11)
const CONTROL_PRESSED := Color(1.0, 1.0, 1.0, 0.15)
const CONTROL_DISABLED := Color(1.0, 1.0, 1.0, 0.035)
const TRACK := Color(0.0, 0.0, 0.0, 0.32)
const SEGMENT_SELECTED := Color(1.0, 1.0, 1.0, 0.15)
const TINT_ALPHA := 0.16
const SELECTION := ACCENT_TEXT

const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 12
const SPACE_L := 16
const PANEL_RADIUS := 12
const CONTROL_RADIUS := 8
const FOCUS_WIDTH := 2

const FONT_SIZE := 14
const SMALL_FONT_SIZE := 13
const SECTION_FONT_SIZE := 11
const HEADER_FONT_SIZE := 17
const TITLE_FONT_SIZE := 22
const ICON_SIZE := 16

const FONT_PATHS := {
	"regular": "res://assets/fonts/inter_regular.ttf",
	"medium": "res://assets/fonts/inter_medium.ttf",
	"semibold": "res://assets/fonts/inter_semibold.ttf",
}
const ICON_PATH := "res://assets/icons/%s.svg"

const BUTTON_TYPES := [
	"Button", "AccentButton", "FlatButton", "DangerButton", "SuccessButton", "ToggleButton", "SegmentButton",
	"IconButton", "IconFlatButton", "ToggleIconButton", "OptionButton", "MenuButton",
]

static func build() -> Theme:
	var theme := Theme.new()
	var fonts := {}
	for weight: String in FONT_PATHS:
		fonts[weight] = font(weight)
	theme.default_font = fonts["regular"]
	theme.default_font_size = FONT_SIZE
	_add_containers(theme)
	_add_buttons(theme, fonts)
	_add_labels(theme, fonts)
	_add_ranges(theme)
	_add_scrollbars(theme)
	_add_popups(theme, fonts)
	_add_inputs(theme, fonts)
	return theme


static func font(weight: String) -> Font:
	var variation := FontVariation.new()
	variation.base_font = load(FONT_PATHS[weight])
	var tags := {}
	tags[TextServerManager.get_primary_interface().name_to_tag("tnum")] = 1
	variation.opentype_features = tags
	return variation


static func icon(name: String) -> Texture2D:
	return load(ICON_PATH % name)


static func tint(color: Color, alpha: float = TINT_ALPHA) -> Color:
	return Color(color, alpha)


static func box(color: Color, radius: int, horizontal: float, vertical: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	style.anti_aliasing = true
	return style


static func bordered(color: Color, radius: int, horizontal: float, vertical: float, border: Color) -> StyleBoxFlat:
	var style := box(color, radius, horizontal, vertical)
	style.border_color = border
	style.set_border_width_all(1)
	return style


static func focus_ring(radius: int = CONTROL_RADIUS) -> StyleBoxFlat:
	var style := box(Color(0, 0, 0, 0), radius + FOCUS_WIDTH, 0.0, 0.0)
	style.draw_center = false
	style.border_color = ACCENT_TEXT
	style.set_border_width_all(FOCUS_WIDTH)
	style.set_expand_margin_all(FOCUS_WIDTH)
	return style


static func _add_containers(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", bordered(SURFACE, PANEL_RADIUS, SPACE_L, SPACE_M, BORDER))
	theme.set_type_variation("ChipPanel", "PanelContainer")
	theme.set_stylebox("panel", "ChipPanel", bordered(SURFACE, 999, SPACE_M, 6.0, BORDER))
	theme.set_type_variation("OverlayPanel", "PanelContainer")
	theme.set_stylebox("panel", "OverlayPanel", bordered(SURFACE_RAISED, PANEL_RADIUS, SPACE_L, SPACE_M, Color(1, 1, 1, 0.12)))
	theme.set_type_variation("ToolbarPanel", "PanelContainer")
	theme.set_stylebox("panel", "ToolbarPanel", bordered(SURFACE, PANEL_RADIUS, 5.0, 5.0, BORDER))
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", box(Color(1, 1, 1, 0.035), CONTROL_RADIUS, SPACE_M, SPACE_M - 2))
	theme.set_type_variation("SegmentTrack", "PanelContainer")
	theme.set_stylebox("panel", "SegmentTrack", box(TRACK, CONTROL_RADIUS + 2, 3.0, 3.0))
	theme.set_type_variation("KeyCap", "PanelContainer")
	var key := bordered(CONTROL, 5, 6.0, 1.0, Color(1, 1, 1, 0.14))
	key.border_width_bottom = 2
	theme.set_stylebox("panel", "KeyCap", key)
	for kind in [["InfoCallout", ACCENT_TEXT], ["WarningCallout", WARNING], ["SuccessCallout", SUCCESS], ["DangerCallout", DANGER]]:
		theme.set_type_variation(kind[0], "PanelContainer")
		var callout := box(tint(kind[1], 0.1), CONTROL_RADIUS, SPACE_M, SPACE_S + 2)
		callout.border_color = tint(kind[1], 0.7)
		callout.border_width_left = 3
		theme.set_stylebox("panel", kind[0], callout)
	theme.set_constant("separation", "VBoxContainer", SPACE_S - 2)
	theme.set_constant("separation", "HBoxContainer", SPACE_S - 2)
	theme.set_constant("h_separation", "GridContainer", SPACE_L)
	theme.set_constant("v_separation", "GridContainer", SPACE_XS)
	var line := StyleBoxLine.new()
	line.color = BORDER
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", SPACE_M)
	var vertical_line := StyleBoxLine.new()
	vertical_line.color = BORDER
	vertical_line.thickness = 1
	vertical_line.vertical = true
	theme.set_stylebox("separator", "VSeparator", vertical_line)
	theme.set_constant("separation", "VSeparator", SPACE_S)


static func _add_buttons(theme: Theme, fonts: Dictionary) -> void:
	for variation in BUTTON_TYPES:
		if not ["Button", "OptionButton", "MenuButton"].has(variation):
			theme.set_type_variation(variation, "Button")
	_style_button(theme, "Button", CONTROL, CONTROL_HOVER, CONTROL_PRESSED, TEXT)
	_style_button(theme, "OptionButton", CONTROL, CONTROL_HOVER, CONTROL_PRESSED, TEXT)
	_style_button(theme, "MenuButton", CONTROL, CONTROL_HOVER, CONTROL_PRESSED, TEXT)
	_style_button(theme, "AccentButton", ACCENT, ACCENT_HOVER, ACCENT_PRESSED, Color.WHITE)
	_style_button(theme, "FlatButton", Color(0, 0, 0, 0), CONTROL_HOVER, CONTROL_PRESSED, TEXT_DIM)
	theme.set_color("font_hover_color", "FlatButton", TEXT)
	theme.set_color("icon_hover_color", "FlatButton", TEXT)
	_style_button(theme, "DangerButton", tint(DANGER, 0.12), tint(DANGER, 0.2), tint(DANGER, 0.28), DANGER)
	_style_button(theme, "SuccessButton", tint(SUCCESS, TINT_ALPHA), tint(SUCCESS, TINT_ALPHA), tint(SUCCESS, TINT_ALPHA), SUCCESS)
	_style_button(theme, "ToggleButton", CONTROL, CONTROL_HOVER, tint(ACCENT_TEXT, 0.2), TEXT_DIM)
	var toggle_on := bordered(tint(ACCENT_TEXT, 0.18), CONTROL_RADIUS, SPACE_M, 6.0, tint(ACCENT_TEXT, 0.55))
	theme.set_stylebox("pressed", "ToggleButton", toggle_on)
	var toggle_on_hover := toggle_on.duplicate() as StyleBoxFlat
	toggle_on_hover.bg_color = tint(ACCENT_TEXT, 0.26)
	theme.set_stylebox("hover_pressed", "ToggleButton", toggle_on_hover)
	for state in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		theme.set_color(state, "ToggleButton", TEXT)
	theme.set_color("font_hover_color", "ToggleButton", TEXT)
	theme.set_color("icon_hover_color", "ToggleButton", TEXT)
	_style_button(theme, "IconButton", CONTROL, CONTROL_HOVER, CONTROL_PRESSED, TEXT, SPACE_S)
	_style_button(theme, "IconFlatButton", Color(0, 0, 0, 0), CONTROL_HOVER, CONTROL_PRESSED, TEXT_DIM, SPACE_S)
	theme.set_color("icon_hover_color", "IconFlatButton", TEXT)
	_style_button(theme, "ToggleIconButton", CONTROL, CONTROL_HOVER, tint(ACCENT_TEXT, 0.2), TEXT, SPACE_S)
	var icon_on := bordered(tint(ACCENT_TEXT, 0.18), CONTROL_RADIUS, SPACE_S, 6.0, tint(ACCENT_TEXT, 0.55))
	theme.set_stylebox("pressed", "ToggleIconButton", icon_on)
	theme.set_stylebox("hover_pressed", "ToggleIconButton", icon_on)
	theme.set_color("icon_pressed_color", "ToggleIconButton", ACCENT_TEXT)
	theme.set_color("icon_hover_pressed_color", "ToggleIconButton", ACCENT_TEXT)
	_style_button(theme, "SegmentButton", Color(0, 0, 0, 0), Color(1, 1, 1, 0.06), SEGMENT_SELECTED, TEXT_DIM)
	theme.set_stylebox("hover_pressed", "SegmentButton", box(SEGMENT_SELECTED, CONTROL_RADIUS - 1, SPACE_M, 5.0))
	theme.set_stylebox("pressed", "SegmentButton", bordered(SEGMENT_SELECTED, CONTROL_RADIUS - 1, SPACE_M, 5.0, Color(1, 1, 1, 0.1)))
	for state in ["font_pressed_color", "font_hover_pressed_color", "font_hover_color"]:
		theme.set_color(state, "SegmentButton", TEXT)
	for variation in BUTTON_TYPES:
		theme.set_font("font", variation, fonts["medium"])
		theme.set_constant("icon_max_width", variation, ICON_SIZE)
		theme.set_constant("h_separation", variation, SPACE_S - 2)
		theme.set_stylebox("focus", variation, focus_ring())
	theme.set_font_size("font_size", "SegmentButton", SMALL_FONT_SIZE)
	for type in ["CheckButton", "CheckBox"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 2.0
		empty.content_margin_right = 2.0
		empty.content_margin_top = 3.0
		empty.content_margin_bottom = 3.0
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			theme.set_stylebox(state, type, empty)
		theme.set_stylebox("focus", type, focus_ring(4))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, TEXT)


static func _style_button(
	theme: Theme, type: String, normal: Color, hover: Color, pressed: Color, text: Color, horizontal: float = SPACE_M
) -> void:
	theme.set_stylebox("normal", type, box(normal, CONTROL_RADIUS, horizontal, 6.0))
	theme.set_stylebox("hover", type, box(hover, CONTROL_RADIUS, horizontal, 6.0))
	theme.set_stylebox("pressed", type, box(pressed, CONTROL_RADIUS, horizontal, 6.0))
	theme.set_stylebox("hover_pressed", type, box(pressed.lightened(0.06), CONTROL_RADIUS, horizontal, 6.0))
	theme.set_stylebox("disabled", type, box(CONTROL_DISABLED, CONTROL_RADIUS, horizontal, 6.0))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, text)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		theme.set_color(state, type, text)
	theme.set_color("font_disabled_color", type, TEXT_DISABLED)
	theme.set_color("icon_disabled_color", type, TEXT_DISABLED)


static func _add_labels(theme: Theme, fonts: Dictionary) -> void:
	theme.set_color("font_color", "Label", TEXT)
	_label_variation(theme, "TitleLabel", TITLE_FONT_SIZE, TEXT, fonts["semibold"])
	_label_variation(theme, "HeaderLabel", HEADER_FONT_SIZE, TEXT, fonts["semibold"])
	_label_variation(theme, "SectionLabel", SECTION_FONT_SIZE, TEXT_DIM, fonts["semibold"])
	_label_variation(theme, "DimLabel", SMALL_FONT_SIZE, TEXT_DIM, fonts["regular"])
	_label_variation(theme, "WarningLabel", SMALL_FONT_SIZE, WARNING, fonts["regular"])
	_label_variation(theme, "SuccessLabel", SMALL_FONT_SIZE, SUCCESS, fonts["regular"])
	_label_variation(theme, "DangerLabel", SMALL_FONT_SIZE, DANGER, fonts["regular"])
	_label_variation(theme, "InfoLabel", SMALL_FONT_SIZE, TEXT, fonts["regular"])
	_label_variation(theme, "KeyLabel", 12, TEXT, fonts["semibold"])
	theme.set_constant("line_spacing", "Label", 2)
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", SMALL_FONT_SIZE)
	theme.set_stylebox("panel", "TooltipPanel", bordered(SURFACE_RAISED, 6, 10.0, 6.0, BORDER))


static func _label_variation(theme: Theme, name: String, size: int, color: Color, label_font: Font) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)
	theme.set_font("font", name, label_font)


static func _add_ranges(theme: Theme) -> void:
	theme.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.12), 2, 0.0, 2.0))
	theme.set_stylebox("grabber_area", "HSlider", box(ACCENT_TEXT, 2, 0.0, 2.0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT_TEXT.lightened(0.15), 2, 0.0, 2.0))
	theme.set_stylebox("focus", "HSlider", focus_ring(4))
	theme.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.08), 2, 0.0, 0.0))
	theme.set_stylebox("fill", "ProgressBar", box(ACCENT_TEXT, 2, 0.0, 0.0))


static func _add_scrollbars(theme: Theme) -> void:
	var track := box(Color(0, 0, 0, 0), 3, 3.0, 0.0)
	theme.set_stylebox("scroll", "VScrollBar", track)
	theme.set_stylebox("scroll_focus", "VScrollBar", track)
	theme.set_stylebox("grabber", "VScrollBar", box(Color(1, 1, 1, 0.16), 3, 3.0, 0.0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(Color(1, 1, 1, 0.28), 3, 3.0, 0.0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", box(Color(1, 1, 1, 0.38), 3, 3.0, 0.0))


static func _add_popups(theme: Theme, fonts: Dictionary) -> void:
	var panel := bordered(SURFACE_RAISED, CONTROL_RADIUS, 6.0, 6.0, BORDER)
	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_stylebox("hover", "PopupMenu", box(CONTROL_HOVER, 5, 8.0, 4.0))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_font("font", "PopupMenu", fonts["regular"])
	theme.set_stylebox("panel", "PopupPanel", panel)


static func _add_inputs(theme: Theme, fonts: Dictionary) -> void:
	var field := bordered(Color(0, 0, 0, 0.32), CONTROL_RADIUS, SPACE_M, SPACE_S, Color(1, 1, 1, 0.14))
	theme.set_stylebox("normal", "LineEdit", field)
	var focused := bordered(Color(0, 0, 0, 0.32), CONTROL_RADIUS, SPACE_M, SPACE_S, ACCENT_TEXT)
	focused.set_border_width_all(FOCUS_WIDTH)
	theme.set_stylebox("focus", "LineEdit", focused)
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_font("font", "LineEdit", fonts["regular"])
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_DISABLED)
	theme.set_color("caret_color", "LineEdit", ACCENT_TEXT)
	theme.set_color("selection_color", "LineEdit", tint(ACCENT_TEXT, 0.35))
	theme.set_color("clear_button_color", "LineEdit", TEXT_DIM)
	theme.set_stylebox("panel", "ItemList", box(Color(0, 0, 0, 0), CONTROL_RADIUS, 0.0, 0.0))
	theme.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("hovered", "ItemList", box(CONTROL_HOVER, CONTROL_RADIUS - 2, SPACE_S, 4.0))
	theme.set_stylebox("selected", "ItemList", box(tint(ACCENT_TEXT, 0.2), CONTROL_RADIUS - 2, SPACE_S, 4.0))
	theme.set_stylebox("selected_focus", "ItemList", box(tint(ACCENT_TEXT, 0.24), CONTROL_RADIUS - 2, SPACE_S, 4.0))
	theme.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	theme.set_font("font", "ItemList", fonts["regular"])
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_color("font_hovered_color", "ItemList", TEXT)
	theme.set_color("font_selected_color", "ItemList", TEXT)
	theme.set_constant("v_separation", "ItemList", 2)
	theme.set_constant("line_separation", "ItemList", 0)

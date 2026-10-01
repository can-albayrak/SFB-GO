extends Node
## The look of every menu and the HUD (GDD "Görsel referans"): neutral dark grey panels,
## white text, the selected row is a white bar, no colour theme. HUD text is PS2-era: plain,
## bold, with a hard 1 px black shadow. Built once and merged into the default theme, so
## every Control picks it up. Fonts come from the system (Arimo / Arial family, Cousine / Courier New
## for small mono labels): nothing is bundled.
## Variations: TitleLabel, HeaderLabel, MonoLabel, DimLabel, HudLabel, HudSmallLabel,
## FrameButton, PrimaryButton, RowButton, HeaderPanel, InsetPanel.

const BG: Color = Color("111214")
const PANEL: Color = Color("151618")
const PANEL_HEADER: Color = Color("1f2023")
const BORDER: Color = Color("2c2f34")
const FIELD: Color = Color("0a0a0b")
const FIELD_BORDER: Color = Color("3a3d42")
const TEXT: Color = Color("e8e9eb")
const TEXT_BRIGHT: Color = Color("f0f1f2")
const TEXT_SOFT: Color = Color("c4c7cc")
const TEXT_DIM: Color = Color("7c8087")
const TEXT_FAINT: Color = Color("55585e")
const ACCENT: Color = Color("e8e9eb") ## Selected row / primary button bar.
const ON_ACCENT: Color = Color("0b0b0c")
const GOOD: Color = Color("8fae7e")
const BAD: Color = Color("c4554a")
const HEAD: Color = Color("d24a3c")
const HUD_TEXT: Color = Color("d6dbe2")
const HUD_DIM: Color = Color("9aa5b4")
const SHADOW: Color = Color(0.0, 0.0, 0.0, 1.0)

const SANS: PackedStringArray = ["Arimo", "Arial", "Liberation Sans", "DejaVu Sans"]
const MONO: PackedStringArray = ["Cousine", "Courier New", "Liberation Mono", "DejaVu Sans Mono"]
const BASE_FONT_SIZE: int = 18

var regular: Font
var bold: Font
var title: Font ## Bold italic, for big screen titles.
var mono: Font
var theme: Theme


func _ready() -> void:
	regular = _system_font(SANS, 400, false)
	bold = _system_font(SANS, 700, false)
	title = _system_font(SANS, 700, true)
	mono = _system_font(MONO, 400, false)
	theme = _build_theme()
	# Merged into the engine's default theme, not set on the root window: theme inheritance stops
	# at non-Control parents (the HUD's CanvasLayer, test scenes), the default theme does not.
	ThemeDB.get_default_theme().merge_with(theme)
	get_tree().root.add_child.call_deferred(ScreenFx.new()) # PS2 screen filter over everything.


## A label in one of the theme's variations.
func label(text: String, variation: StringName = &"", font_size: int = 0) -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = variation
	if font_size > 0:
		result.add_theme_font_size_override(&"font_size", font_size)
	return result


## A left-aligned menu row button (white bar on hover / when toggled on).
func menu_button(text: String, font_size: int = 20) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"RowButton"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.add_theme_font_size_override(&"font_size", font_size)
	return button


func _system_font(names: PackedStringArray, weight: int, italic: bool) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = names
	font.font_weight = weight
	font.font_italic = italic
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return font


func _flat(color: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, margin_h: float = 12.0,
		margin_v: float = 6.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(border_width)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	box.anti_aliasing = false
	return box


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = regular
	t.default_font_size = BASE_FONT_SIZE

	t.set_color(&"font_color", &"Label", TEXT)

	_label_variation(t, &"TitleLabel", title, 84, TEXT_BRIGHT, Vector2i(2, 3))
	_label_variation(t, &"HeaderLabel", bold, 12, TEXT_DIM, Vector2i.ZERO)
	_label_variation(t, &"MonoLabel", mono, 12, TEXT_DIM, Vector2i.ZERO)
	_label_variation(t, &"DimLabel", regular, 14, TEXT_DIM, Vector2i.ZERO)
	_label_variation(t, &"HudLabel", bold, 18, HUD_TEXT, Vector2i(1, 1))
	_label_variation(t, &"HudSmallLabel", regular, 14, HUD_DIM, Vector2i(1, 1))

	# Buttons: plain text, a white bar when hovered or toggled on.
	var none := _flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 16.0, 8.0)
	var bar := _flat(ACCENT, Color.TRANSPARENT, 0, 16.0, 8.0)
	var bar_hover := _flat(TEXT_BRIGHT, Color.TRANSPARENT, 0, 16.0, 8.0)
	var framed := _flat(Color.TRANSPARENT, FIELD_BORDER, 1, 16.0, 8.0)
	t.set_font(&"font", &"Button", bold)
	t.set_font_size(&"font_size", &"Button", 18)
	t.set_stylebox(&"normal", &"Button", framed)
	t.set_stylebox(&"hover", &"Button", bar)
	t.set_stylebox(&"pressed", &"Button", bar)
	t.set_stylebox(&"hover_pressed", &"Button", bar_hover)
	t.set_stylebox(&"disabled", &"Button", _flat(Color.TRANSPARENT, BORDER, 1, 16.0, 8.0))
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	for state: StringName in [&"font_color", &"font_focus_color"]:
		t.set_color(state, &"Button", TEXT_SOFT)
	for state: StringName in [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		t.set_color(state, &"Button", ON_ACCENT)
	t.set_color(&"font_disabled_color", &"Button", TEXT_FAINT)

	t.set_type_variation(&"RowButton", &"Button")
	t.set_stylebox(&"normal", &"RowButton", none)
	t.set_stylebox(&"disabled", &"RowButton", none)
	t.set_type_variation(&"FrameButton", &"Button")
	t.set_type_variation(&"PrimaryButton", &"Button")
	t.set_stylebox(&"normal", &"PrimaryButton", bar)
	t.set_stylebox(&"hover", &"PrimaryButton", bar_hover)
	t.set_color(&"font_color", &"PrimaryButton", ON_ACCENT)
	t.set_color(&"font_focus_color", &"PrimaryButton", ON_ACCENT)

	# Panels.
	var panel := _flat(PANEL, BORDER, 1, 14.0, 12.0)
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	t.set_stylebox(&"panel", &"Panel", panel)
	t.set_type_variation(&"HeaderPanel", &"PanelContainer")
	var header := _flat(PANEL_HEADER, BORDER, 0, 14.0, 7.0)
	header.border_width_bottom = 1
	t.set_stylebox(&"panel", &"HeaderPanel", header)
	t.set_type_variation(&"InsetPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"InsetPanel", _flat(FIELD, FIELD_BORDER, 1, 0.0, 0.0))

	# Text fields (SpinBox uses a LineEdit inside).
	var field := _flat(FIELD, FIELD_BORDER, 1, 10.0, 6.0)
	var field_focus := _flat(FIELD, TEXT_DIM, 1, 10.0, 6.0)
	t.set_stylebox(&"normal", &"LineEdit", field)
	t.set_stylebox(&"focus", &"LineEdit", field_focus)
	t.set_stylebox(&"read_only", &"LineEdit", field)
	t.set_font(&"font", &"LineEdit", bold)
	t.set_color(&"font_color", &"LineEdit", TEXT_BRIGHT)
	t.set_color(&"font_placeholder_color", &"LineEdit", TEXT_FAINT)
	t.set_color(&"caret_color", &"LineEdit", TEXT_BRIGHT)
	t.set_color(&"selection_color", &"LineEdit", Color(TEXT_DIM, 0.5))

	# Drop-downs.
	t.set_stylebox(&"normal", &"OptionButton", field)
	t.set_stylebox(&"hover", &"OptionButton", field_focus)
	t.set_stylebox(&"pressed", &"OptionButton", field_focus)
	t.set_stylebox(&"focus", &"OptionButton", StyleBoxEmpty.new())
	t.set_color(&"font_color", &"OptionButton", TEXT_BRIGHT)
	t.set_color(&"font_hover_color", &"OptionButton", TEXT_BRIGHT)
	t.set_color(&"font_pressed_color", &"OptionButton", TEXT_BRIGHT)
	t.set_stylebox(&"panel", &"PopupMenu", _flat(PANEL, FIELD_BORDER, 1, 4.0, 4.0))
	t.set_stylebox(&"hover", &"PopupMenu", _flat(ACCENT))
	t.set_color(&"font_color", &"PopupMenu", TEXT)
	t.set_color(&"font_hover_color", &"PopupMenu", ON_ACCENT)

	# Check boxes and sliders.
	t.set_color(&"font_color", &"CheckBox", TEXT)
	t.set_color(&"font_hover_color", &"CheckBox", TEXT_BRIGHT)
	t.set_color(&"font_pressed_color", &"CheckBox", TEXT)
	t.set_color(&"font_hover_pressed_color", &"CheckBox", TEXT_BRIGHT)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		t.set_stylebox(state, &"CheckBox", _flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4.0, 4.0))
	var track := _flat(FIELD, FIELD_BORDER, 1, 0.0, 3.0)
	t.set_stylebox(&"slider", &"HSlider", track)
	t.set_stylebox(&"grabber_area", &"HSlider", _flat(TEXT_DIM, Color.TRANSPARENT, 0, 0.0, 3.0))
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", _flat(TEXT_SOFT, Color.TRANSPARENT, 0, 0.0, 3.0))

	# Scroll bars.
	t.set_stylebox(&"scroll", &"VScrollBar", _flat(FIELD, Color.TRANSPARENT, 0, 4.0, 0.0))
	t.set_stylebox(&"grabber", &"VScrollBar", _flat(FIELD_BORDER, Color.TRANSPARENT, 0, 4.0, 0.0))
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", _flat(TEXT_DIM, Color.TRANSPARENT, 0, 4.0, 0.0))
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", _flat(TEXT_SOFT, Color.TRANSPARENT, 0, 4.0, 0.0))
	return t


func _label_variation(t: Theme, type_name: StringName, font: Font, font_size: int, color: Color,
		shadow: Vector2i) -> void:
	t.set_type_variation(type_name, &"Label")
	t.set_font(&"font", type_name, font)
	t.set_font_size(&"font_size", type_name, font_size)
	t.set_color(&"font_color", type_name, color)
	if shadow != Vector2i.ZERO:
		t.set_color(&"font_shadow_color", type_name, SHADOW)
		t.set_constant(&"shadow_offset_x", type_name, shadow.x)
		t.set_constant(&"shadow_offset_y", type_name, shadow.y)
		t.set_constant(&"shadow_outline_size", type_name, 0)

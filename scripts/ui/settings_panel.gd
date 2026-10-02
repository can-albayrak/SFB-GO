class_name SettingsPanel
extends Control
## Settings window, opened from the main menu and the in-game Esc menu: view, crosshair
## and camera feel. Changes apply at once (Settings.changed); the file is written on close.

signal closed

const PANEL_SIZE: Vector2 = Vector2(640.0, 520.0)
const LABEL_WIDTH: float = 230.0
const SLIDER_WIDTH: float = 260.0
const VALUE_WIDTH: float = 80.0
const FONT_SIZE: int = 18
const TITLE_SIZE: int = 12
const HEADER_SIZE: int = 40
const TITLE_COLOR: Color = Color("7c8087")
const DIM_COLOR: Color = Color(0.04, 0.04, 0.045, 0.85)

var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # In the tree already: offsets must follow too.
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 12)
	panel.add_child(root)

	var header := Style.label("SETTINGS", &"TitleLabel", HEADER_SIZE)
	root.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = PANEL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", 8)
	scroll.add_child(_rows)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.theme_type_variation = &"PrimaryButton"
	close_button.custom_minimum_size = Vector2(0.0, 48.0)
	close_button.add_theme_font_size_override(&"font_size", 22)
	close_button.pressed.connect(close)
	root.add_child(close_button)
	visible = false


func open() -> void:
	_rebuild()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	Settings.save_settings()
	closed.emit()


func _rebuild() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	_add_section("VIEW")
	_add_slider("Field of view", 80.0, 110.0, 1.0, Settings.fov, "%.0f",
		func(v: float) -> void: Settings.fov = v)
	_add_slider("Mouse sensitivity", 0.1, 8.0, 0.05, Settings.mouse_sensitivity, "%.2f",
		func(v: float) -> void: Settings.mouse_sensitivity = v)

	_add_section("CROSSHAIR")
	_add_color("Color", Settings.crosshair_color,
		func(c: Color) -> void: Settings.crosshair_color = c)
	_add_slider("Length", 2.0, 20.0, 1.0, Settings.crosshair_length, "%.0f",
		func(v: float) -> void: Settings.crosshair_length = v)
	_add_slider("Gap", 0.0, 15.0, 1.0, Settings.crosshair_gap, "%.0f",
		func(v: float) -> void: Settings.crosshair_gap = v)
	_add_slider("Thickness", 1.0, 6.0, 1.0, Settings.crosshair_thickness, "%.0f",
		func(v: float) -> void: Settings.crosshair_thickness = v)
	_add_toggle("Center dot", Settings.crosshair_dot,
		func(on: bool) -> void: Settings.crosshair_dot = on)
	_add_toggle("Hit marker", Settings.hit_marker_enabled,
		func(on: bool) -> void: Settings.hit_marker_enabled = on)

	_add_section("CAMERA")
	_add_percent("Speed FOV shift", Settings.camera_fov_shift,
		func(v: float) -> void: Settings.camera_fov_shift = v)
	_add_percent("Head bob", Settings.camera_head_bob,
		func(v: float) -> void: Settings.camera_head_bob = v)
	_add_percent("Landing dip", Settings.camera_landing,
		func(v: float) -> void: Settings.camera_landing = v)
	_add_percent("Slide camera", Settings.camera_slide,
		func(v: float) -> void: Settings.camera_slide = v)
	_add_percent("Damage shake", Settings.camera_damage_shake,
		func(v: float) -> void: Settings.camera_damage_shake = v)

	_add_section("GRAPHICS")
	_add_toggle("Fullscreen (Alt+Enter)", Settings.fullscreen,
		func(on: bool) -> void:
			Settings.fullscreen = on
			Settings.apply_window_mode())
	_add_toggle("Screen filter (grain, PS2 colour)", Settings.post_process,
		func(on: bool) -> void: Settings.post_process = on)
	_add_slider("Render scale %", 50.0, 100.0, 5.0, Settings.render_scale * 100.0, "%.0f",
		func(v: float) -> void: Settings.render_scale = v / 100.0)


func _add_section(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"HeaderLabel"
	label.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	label.add_theme_color_override(&"font_color", TITLE_COLOR)
	_rows.add_child(label)


func _add_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	row.add_child(label)
	_rows.add_child(row)
	return row


func _add_slider(text: String, min_value: float, max_value: float, step: float, value: float,
		format: String, on_change: Callable) -> void:
	var row: HBoxContainer = _add_row(text)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(VALUE_WIDTH, 0.0)
	value_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	value_label.text = format % value
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = format % v
		on_change.call(v)
		Settings.changed.emit())


## 0..1 setting shown as 0..100 %.
func _add_percent(text: String, value: float, on_change: Callable) -> void:
	var row: HBoxContainer = _add_row(text)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(VALUE_WIDTH, 0.0)
	value_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	value_label.text = "%d %%" % roundi(value * 100.0)
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d %%" % roundi(v * 100.0)
		on_change.call(v)
		Settings.changed.emit())


func _add_toggle(text: String, value: bool, on_change: Callable) -> void:
	var row: HBoxContainer = _add_row(text)
	var box := CheckBox.new()
	box.button_pressed = value
	row.add_child(box)
	box.toggled.connect(func(on: bool) -> void:
		on_change.call(on)
		Settings.changed.emit())


func _add_color(text: String, value: Color, on_change: Callable) -> void:
	var row: HBoxContainer = _add_row(text)
	var picker := ColorPickerButton.new()
	picker.color = value
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(SLIDER_WIDTH * 0.5, 32.0)
	row.add_child(picker)
	picker.color_changed.connect(func(c: Color) -> void:
		on_change.call(c)
		Settings.changed.emit())

class_name LoadoutMenu
extends PanelContainer
## Three-step loadout picker (GDD): class -> primary weapon -> ability, then Deploy.
## Built from the roster, so new classes appear without UI changes. Look: Style (the
## selected row of each column is a white bar; a summary line and DEPLOY at the bottom).

signal confirmed(code: PackedInt32Array)

const MENU_WIDTH: float = 1000.0
const ROW_HEIGHT: float = 40.0
const ROW_FONT_SIZE: int = 17
const COLUMN_TITLES: Array[String] = ["1  ·  CLASS", "2  ·  WEAPON", "3  ·  ABILITY  [Q]"]
const DIVIDER: Color = Color("222428")
const FOOTER: Color = Color("111214")

var _class_index: int = 0
var _primary_index: int = 0
var _ability_index: int = 0

var _class_column: VBoxContainer
var _weapon_column: VBoxContainer
var _ability_column: VBoxContainer
var _sum_class: Label
var _sum_stats: Label
var _sum_weapon: Label
var _sum_secondary: Label
var _sum_ability: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = MENU_WIDTH
	add_theme_stylebox_override(&"panel", _box(Style.PANEL, Style.BORDER, [1, 1, 1, 1]))
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 0)
	add_child(root)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 0)
	root.add_child(columns)
	_class_column = _add_column(columns, COLUMN_TITLES[0], false)
	_weapon_column = _add_column(columns, COLUMN_TITLES[1], true)
	_ability_column = _add_column(columns, COLUMN_TITLES[2], true)

	var footer := PanelContainer.new()
	var footer_style := _box(FOOTER, Style.BORDER, [0, 1, 0, 0])
	footer_style.content_margin_left = 14.0
	footer_style.content_margin_right = 10.0
	footer_style.content_margin_top = 10.0
	footer_style.content_margin_bottom = 10.0
	footer.add_theme_stylebox_override(&"panel", footer_style)
	root.add_child(footer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	footer.add_child(row)
	_sum_class = _summary_label(20, true, Color.WHITE)
	_sum_stats = _summary_label(13, false, Style.TEXT_DIM)
	_sum_weapon = _summary_label(16, true, Style.TEXT)
	_sum_secondary = _summary_label(13, false, Style.TEXT_DIM)
	_sum_ability = _summary_label(16, true, Style.TEXT)
	for part: Control in [_sum_class, _sum_stats, _divider_label(), _sum_weapon, _sum_secondary, _divider_label(), _sum_ability]:
		row.add_child(part)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var deploy := Button.new()
	deploy.text = "DEPLOY"
	deploy.theme_type_variation = &"PrimaryButton"
	deploy.custom_minimum_size = Vector2(180.0, 48.0)
	deploy.add_theme_font_size_override(&"font_size", 18)
	deploy.pressed.connect(func() -> void: confirmed.emit(Loadout.make(_class_index, _primary_index, _ability_index)))
	row.add_child(deploy)
	visible = false


func open(current: PackedInt32Array) -> void:
	var code: PackedInt32Array = current if Loadout.is_valid(current) else Loadout.default_code()
	_class_index = code[Loadout.CLASS]
	_primary_index = code[Loadout.PRIMARY]
	_ability_index = code[Loadout.ABILITY]
	_rebuild()
	visible = true


func _add_column(parent: Container, title: String, divided: bool) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 0)
	parent.add_child(column)
	var head := PanelContainer.new()
	var head_style := _box(Style.PANEL_HEADER, Style.BORDER, [1 if divided else 0, 0, 0, 1])
	head_style.content_margin_left = 14.0
	head_style.content_margin_top = 7.0
	head_style.content_margin_bottom = 7.0
	head.add_theme_stylebox_override(&"panel", head_style)
	head.add_child(Style.label(title, &"HeaderLabel"))
	column.add_child(head)
	var body := PanelContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body_style := _box(Color.TRANSPARENT, DIVIDER, [1 if divided else 0, 0, 0, 0])
	body_style.set_content_margin_all(8.0)
	body.add_theme_stylebox_override(&"panel", body_style)
	column.add_child(body)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 0)
	body.add_child(list)
	return list


func _rebuild() -> void:
	var class_def: ClassDef = Loadout.roster().classes[_class_index]
	var class_names: Array[String] = []
	for def: ClassDef in Loadout.roster().classes:
		class_names.append(def.display_name)
	var weapon_names: Array[String] = []
	for def: WeaponDef in class_def.primary_weapons:
		weapon_names.append(def.display_name)
	var ability_names: Array[String] = []
	for def: AbilityDef in class_def.abilities:
		ability_names.append("%s   %d s" % [def.display_name, roundi(def.cooldown)])

	_fill(_class_column, class_names, _class_index, _on_class_picked)
	_fill(_weapon_column, weapon_names, _primary_index, _on_weapon_picked)
	_fill(_ability_column, ability_names, _ability_index, _on_ability_picked)

	var code: PackedInt32Array = Loadout.make(_class_index, _primary_index, _ability_index)
	var ability: AbilityDef = Loadout.get_ability(code)
	_sum_class.text = class_def.display_name.to_upper()
	_sum_stats.text = "%d HP  ·  %.1f m/s" % [class_def.max_health, class_def.move_speed]
	_sum_weapon.text = Loadout.get_primary(code).display_name
	_sum_secondary.text = "+ %s" % class_def.secondary_weapon.display_name
	_sum_ability.text = "[Q]  %s" % ability.display_name if ability != null else ""


func _on_class_picked(index: int) -> void:
	if index != _class_index:
		_class_index = index
		_primary_index = 0
		_ability_index = 0
	_rebuild()


func _on_weapon_picked(index: int) -> void:
	_primary_index = index
	_rebuild()


func _on_ability_picked(index: int) -> void:
	_ability_index = index
	_rebuild()


func _fill(list: VBoxContainer, names: Array[String], selected: int, on_pick: Callable) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for i: int in names.size():
		var button := Style.menu_button(names[i], ROW_FONT_SIZE)
		button.custom_minimum_size.y = ROW_HEIGHT
		button.toggle_mode = true
		button.button_pressed = i == selected
		button.add_theme_color_override(&"font_color", Color("9a9ea5"))
		button.pressed.connect(on_pick.bind(i))
		list.add_child(button)


func _summary_label(font_size: int, is_bold: bool, color: Color) -> Label:
	var result := Style.label("", &"", font_size)
	if is_bold:
		result.add_theme_font_override(&"font", Style.bold)
	result.add_theme_color_override(&"font_color", color)
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return result


func _divider_label() -> Label:
	var result := _summary_label(16, false, Style.FIELD_BORDER)
	result.text = "|"
	return result


## Flat box; `borders` = [left, top, right, bottom] widths.
func _box(color: Color, border: Color, borders: Array[int]) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.border_width_left = borders[0]
	box.border_width_top = borders[1]
	box.border_width_right = borders[2]
	box.border_width_bottom = borders[3]
	return box

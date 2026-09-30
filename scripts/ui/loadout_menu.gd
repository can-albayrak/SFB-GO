class_name LoadoutMenu
extends PanelContainer
## Three-step loadout picker (GDD): class -> primary weapon -> ability, then Deploy.
## Built from the roster, so new classes appear without UI changes.

signal confirmed(code: PackedInt32Array)

const BUTTON_HEIGHT: float = 44.0
const COLUMN_WIDTH: float = 250.0
const FONT_SIZE: int = 20
const TITLE_SIZE: int = 16
const TITLE_COLOR: Color = Color(1.0, 0.6, 0.3)

var _class_index: int = 0
var _primary_index: int = 0
var _ability_index: int = 0

var _class_column: VBoxContainer
var _weapon_column: VBoxContainer
var _ability_column: VBoxContainer
var _stats_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 14)
	add_child(root)

	var header := Label.new()
	header.text = "SELECT LOADOUT"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override(&"font_size", 28)
	root.add_child(header)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 24)
	root.add_child(columns)
	_class_column = _add_column(columns, "1  CLASS")
	_weapon_column = _add_column(columns, "2  WEAPON")
	_ability_column = _add_column(columns, "3  ABILITY")

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override(&"font_size", 18)
	root.add_child(_stats_label)

	var deploy := Button.new()
	deploy.text = "DEPLOY"
	deploy.custom_minimum_size = Vector2(0.0, 52.0)
	deploy.add_theme_font_size_override(&"font_size", 24)
	deploy.pressed.connect(func() -> void: confirmed.emit(Loadout.make(_class_index, _primary_index, _ability_index)))
	root.add_child(deploy)
	visible = false


func open(current: PackedInt32Array) -> void:
	var code: PackedInt32Array = current if Loadout.is_valid(current) else Loadout.default_code()
	_class_index = code[Loadout.CLASS]
	_primary_index = code[Loadout.PRIMARY]
	_ability_index = code[Loadout.ABILITY]
	_rebuild()
	visible = true


func _add_column(parent: Container, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	column.add_theme_constant_override(&"separation", 8)
	parent.add_child(column)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	label.add_theme_color_override(&"font_color", TITLE_COLOR)
	column.add_child(label)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 6)
	column.add_child(list)
	return list


func _rebuild() -> void:
	var class_def: ClassDef = Loadout.ROSTER.classes[_class_index]
	var class_names: Array[String] = []
	for def: ClassDef in Loadout.ROSTER.classes:
		class_names.append(def.display_name)
	var weapon_names: Array[String] = []
	for def: WeaponDef in class_def.primary_weapons:
		weapon_names.append(def.display_name)
	var ability_names: Array[String] = []
	for def: AbilityDef in class_def.abilities:
		ability_names.append("%s  (%ds)" % [def.display_name, roundi(def.cooldown)])

	_fill(_class_column, class_names, _class_index, _on_class_picked)
	_fill(_weapon_column, weapon_names, _primary_index, _on_weapon_picked)
	_fill(_ability_column, ability_names, _ability_index, _on_ability_picked)
	_stats_label.text = "%s   ·   %d HP   ·   speed %.1f m/s   ·   secondary: %s" % [
		class_def.display_name, class_def.max_health, class_def.move_speed, class_def.secondary_weapon.display_name]


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
		child.queue_free()
	for i: int in names.size():
		var button := Button.new()
		button.text = names[i]
		button.toggle_mode = true
		button.button_pressed = i == selected
		button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
		button.add_theme_font_size_override(&"font_size", FONT_SIZE)
		button.pressed.connect(on_pick.bind(i))
		list.add_child(button)

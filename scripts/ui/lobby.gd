extends Control
## Lobby (GDD "Lobi"): player list with names, ready flags and an empty face slot (faces
## come in stage 8). Everyone picks the loadout for their first spawn here (saved in
## Settings, used by Game on spawn). The host sets kill target / minutes / map and presses
## Start; clients toggle Ready. No chat or teams. Late joiners pick on joining instead.

const BACKGROUND_COLOR: Color = Color(0.12, 0.06, 0.04, 1.0)
const TITLE_COLOR: Color = Color(1.0, 0.55, 0.25)
const SECTION_COLOR: Color = Color(1.0, 0.6, 0.3)
const READY_COLOR: Color = Color(0.4, 1.0, 0.5)
const WAITING_COLOR: Color = Color(0.75, 0.75, 0.75)
const HOST_COLOR: Color = Color(1.0, 0.8, 0.3)
const FACE_COLOR: Color = Color(0.5, 0.5, 0.5)
const TITLE_SIZE: int = 64
const FONT_SIZE: int = 22
const SMALL_SIZE: int = 18
const PANEL_WIDTH: float = 640.0
const NAME_WIDTH: float = 300.0
const FACE_WIDTH: float = 150.0
const BUTTON_HEIGHT: float = 52.0
const MIN_KILLS: float = 5.0
const MAX_KILLS: float = 100.0
const MIN_MINUTES: float = 1.0
const MAX_MINUTES: float = 60.0

var _list: VBoxContainer
var _rules_label: Label
var _ready_button: Button
var _start_button: Button
var _kills_spin: SpinBox
var _minutes_spin: SpinBox
var _map_option: OptionButton
var _loadout_label: Label
var _loadout_overlay: CenterContainer
var _loadout_menu: LoadoutMenu


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	Net.players_changed.connect(_refresh)
	Net.lobby_changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	box.add_theme_constant_override(&"separation", 14)
	center.add_child(box)

	var title := _label("LOBBY", TITLE_SIZE, TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if multiplayer.is_server():
		var addresses: String = ", ".join(_shareable_addresses())
		var hint := _label("Friends join with: %s" % addresses if not addresses.is_empty() else "", SMALL_SIZE, WAITING_COLOR)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hint)

	box.add_child(_label("PLAYERS", SMALL_SIZE, SECTION_COLOR))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 6)
	box.add_child(_list)

	box.add_child(_label("YOUR LOADOUT", SMALL_SIZE, SECTION_COLOR))
	var loadout_row := HBoxContainer.new()
	loadout_row.add_theme_constant_override(&"separation", 12)
	box.add_child(loadout_row)
	_loadout_label = _label(Loadout.describe(Loadout.from_settings()), FONT_SIZE, Color.WHITE)
	_loadout_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_row.add_child(_loadout_label)
	var change := _button("Change")
	change.pressed.connect(_open_loadout)
	loadout_row.add_child(change)

	box.add_child(_label("MATCH", SMALL_SIZE, SECTION_COLOR))
	if multiplayer.is_server():
		_build_host_controls(box)
	else:
		_rules_label = _label("", FONT_SIZE, Color.WHITE)
		box.add_child(_rules_label)
		_ready_button = _button("Ready")
		_ready_button.toggle_mode = true
		_ready_button.toggled.connect(_on_ready_toggled)
		box.add_child(_ready_button)

	var leave := _button("Leave")
	leave.pressed.connect(func() -> void: Net.leave())
	box.add_child(leave)

	# Loadout picker drawn over everything (same three-step menu as in game).
	_loadout_overlay = CenterContainer.new()
	_loadout_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loadout_overlay.visible = false
	add_child(_loadout_overlay)
	_loadout_menu = LoadoutMenu.new()
	_loadout_overlay.add_child(_loadout_menu)
	_loadout_menu.confirmed.connect(_on_loadout_confirmed)


func _build_host_controls(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	box.add_child(row)
	row.add_child(_label("Kills", SMALL_SIZE, Color.WHITE))
	_kills_spin = SpinBox.new()
	_kills_spin.min_value = MIN_KILLS
	_kills_spin.max_value = MAX_KILLS
	_kills_spin.value = Net.lobby_kill_target
	_kills_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_kills_spin)
	row.add_child(_label("Minutes", SMALL_SIZE, Color.WHITE))
	_minutes_spin = SpinBox.new()
	_minutes_spin.min_value = MIN_MINUTES
	_minutes_spin.max_value = MAX_MINUTES
	_minutes_spin.value = Net.lobby_minutes
	_minutes_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_minutes_spin)
	row.add_child(_label("Map", SMALL_SIZE, Color.WHITE))
	_map_option = OptionButton.new()
	for map_name: String in Net.MAP_NAMES:
		_map_option.add_item(map_name)
	_map_option.selected = clampi(Net.lobby_map_index, 0, Net.MAP_NAMES.size() - 1)
	_map_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_map_option)
	_kills_spin.value_changed.connect(_on_rules_changed.unbind(1))
	_minutes_spin.value_changed.connect(_on_rules_changed.unbind(1))
	_map_option.item_selected.connect(_on_rules_changed.unbind(1))

	_start_button = _button("Start")
	_start_button.pressed.connect(_on_start_pressed)
	box.add_child(_start_button)


func _refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids: Array[int] = []
	ids.assign(Net.player_names.keys())
	ids.sort()
	var my_id: int = multiplayer.get_unique_id()
	for peer_id: int in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		var shown_name: String = Net.get_player_name(peer_id) + ("  (you)" if peer_id == my_id else "")
		var name_label := _label(shown_name, FONT_SIZE, Color.WHITE)
		name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
		row.add_child(name_label)
		var face_label := _label("Face: -", SMALL_SIZE, FACE_COLOR) # Empty slot until stage 8.
		face_label.custom_minimum_size = Vector2(FACE_WIDTH, 0.0)
		row.add_child(face_label)
		if peer_id == 1:
			row.add_child(_label("HOST", FONT_SIZE, HOST_COLOR))
		elif Net.ready_peers.get(peer_id, false):
			row.add_child(_label("READY", FONT_SIZE, READY_COLOR))
		else:
			row.add_child(_label("NOT READY", FONT_SIZE, WAITING_COLOR))
		_list.add_child(row)

	if _rules_label != null:
		var map_name: String = Net.MAP_NAMES[clampi(Net.lobby_map_index, 0, Net.MAP_NAMES.size() - 1)]
		_rules_label.text = "%d kills  ·  %d min  ·  %s  ·  waiting for the host" % [
			Net.lobby_kill_target, roundi(Net.lobby_minutes), map_name]


func _open_loadout() -> void:
	_loadout_overlay.visible = true
	_loadout_menu.open(Loadout.from_settings())


## The first spawn uses the saved loadout (Game sends Loadout.from_settings()).
func _on_loadout_confirmed(code: PackedInt32Array) -> void:
	Loadout.save_to_settings(code)
	_loadout_label.text = Loadout.describe(code)
	_loadout_overlay.visible = false


func _on_rules_changed() -> void:
	Net.server_set_lobby_settings(int(_kills_spin.value), _minutes_spin.value, _map_option.selected)


func _on_ready_toggled(on: bool) -> void:
	Net.request_lobby_ready(on)


func _on_start_pressed() -> void:
	_start_button.disabled = true
	Net.server_start_match(int(_kills_spin.value), _minutes_spin.value, _map_option.selected)


## IPv4 addresses friends can type (Tailscale's 100.x first); loopback and link-local skipped.
func _shareable_addresses() -> Array[String]:
	var tailscale: Array[String] = []
	var others: Array[String] = []
	for address: String in IP.get_local_addresses():
		if not address.contains(".") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.begins_with("100."):
			tailscale.append(address)
		else:
			others.append(address)
	tailscale.append_array(others)
	return tailscale


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.add_theme_font_size_override(&"font_size", FONT_SIZE)
	return button

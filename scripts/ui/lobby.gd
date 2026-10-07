extends Control
## Lobby (GDD "Lobi"): player table with an empty face slot (faces come in stage 8) and
## ready flags, your loadout for the first spawn (saved in Settings, used by Game on spawn),
## match settings (the host edits them, everyone sees them), Start / Ready and Leave.
## No chat or teams. Late joiners pick on joining instead. Look: Style (neutral grey panels).

const MIN_KILLS: float = 5.0
const MAX_KILLS: float = 100.0
const MIN_MINUTES: float = 1.0
const MAX_MINUTES: float = 60.0
const MIN_RESPAWN: float = 1.0
const MAX_RESPAWN: float = 15.0
const MARGIN: float = 64.0
const SIDE_WIDTH: float = 470.0
const COLUMN_GAP: float = 40.0 ## Between the player table and the right column.
const CONTENT_TOP: float = 120.0
const FACE_SIZE: float = 64.0
const ROW_HIGHLIGHT: Color = Color("1b1c1f")

var _list: VBoxContainer
var _info_label: Label
var _class_label: Label
var _class_stats: Label
var _weapon_label: Label
var _secondary_label: Label
var _ability_label: Label
var _kills_value: Label
var _minutes_value: Label
var _respawn_value: Label
var _map_value: Label
var _ready_button: Button
var _start_button: Button
var _kills_spin: SpinBox
var _minutes_spin: SpinBox
var _respawn_spin: SpinBox
var _map_option: OptionButton
var _loadout_overlay: Control
var _loadout_menu: LoadoutMenu


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	Net.players_changed.connect(_refresh)
	Net.lobby_changed.connect(_refresh)
	_show_loadout(Loadout.from_settings())
	_refresh()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Style.BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Header: title left, session facts right, a thin rule under both.
	var header := HBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = MARGIN
	header.offset_right = -MARGIN
	header.offset_top = 36.0
	header.offset_bottom = 92.0
	add_child(header)
	header.add_child(Style.label("LOBBY", &"TitleLabel", 44))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_info_label = Style.label("", &"MonoLabel")
	_info_label.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(_info_label)
	var rule := ColorRect.new()
	rule.color = Style.BORDER
	rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rule.offset_left = MARGIN
	rule.offset_right = -MARGIN
	rule.offset_top = 100.0
	rule.offset_bottom = 101.0
	add_child(rule)

	# Player table.
	var table := _panel()
	table.set_anchors_preset(Control.PRESET_TOP_WIDE) # Whatever the right column leaves.
	table.offset_left = MARGIN
	table.offset_right = -MARGIN - SIDE_WIDTH - COLUMN_GAP
	table.offset_top = CONTENT_TOP
	add_child(table)
	var table_box := VBoxContainer.new()
	table_box.add_theme_constant_override(&"separation", 0)
	table.add_child(table_box)
	table_box.add_child(_header_row(["FACE", "PLAYER", "STATUS"], [FACE_SIZE + 20.0, 0.0, 140.0]))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 0)
	table_box.add_child(_list)

	# Right column: loadout, match settings, buttons.
	var side := VBoxContainer.new()
	side.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side.offset_left = -MARGIN - SIDE_WIDTH
	side.offset_right = -MARGIN
	side.offset_top = CONTENT_TOP
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN # Wider content grows left, never off screen.
	side.add_theme_constant_override(&"separation", 12)
	add_child(side)
	side.add_child(_build_loadout_panel())
	side.add_child(_build_settings_panel())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	side.add_child(buttons)
	if multiplayer.is_server():
		_start_button = _button("START", &"PrimaryButton", 20)
		_start_button.pressed.connect(_on_start_pressed)
		_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(_start_button)
	else:
		_ready_button = _button("READY", &"FrameButton", 20)
		_ready_button.toggle_mode = true
		_ready_button.toggled.connect(_on_ready_toggled)
		_ready_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(_ready_button)
	if SteamLink.lobby_id != 0:
		# Steam game: friends get the invite in Steam (or find it under FIND STEAM GAMES).
		var invite := _button("INVITE", &"FrameButton", 16)
		invite.custom_minimum_size.x = 120.0
		invite.pressed.connect(SteamLink.invite_friends)
		buttons.add_child(invite)
	var leave := _button("LEAVE", &"FrameButton", 16)
	leave.custom_minimum_size.x = 120.0
	leave.pressed.connect(func() -> void: Net.leave())
	buttons.add_child(leave)

	# Loadout picker drawn over everything (same three-step menu as in game).
	_loadout_overlay = ColorRect.new()
	(_loadout_overlay as ColorRect).color = Color(0.0, 0.0, 0.0, 0.6)
	_loadout_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loadout_overlay.visible = false
	add_child(_loadout_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loadout_overlay.add_child(center)
	_loadout_menu = LoadoutMenu.new()
	center.add_child(_loadout_menu)
	_loadout_menu.confirmed.connect(_on_loadout_confirmed)


func _build_loadout_panel() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	panel.add_child(box)
	var head := PanelContainer.new()
	head.theme_type_variation = &"HeaderPanel"
	box.add_child(head)
	var head_row := HBoxContainer.new()
	head.add_child(head_row)
	var head_label := Style.label("YOUR LOADOUT", &"HeaderLabel")
	head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(head_label)
	var change := _button("CHANGE", &"FrameButton", 13)
	change.custom_minimum_size = Vector2(0.0, 36.0)
	change.pressed.connect(_open_loadout)
	head_row.add_child(change)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 10)
	var body := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		body.add_theme_constant_override(side, 14)
	body.add_child(grid)
	box.add_child(body)
	_class_label = Style.label("", &"", 22)
	_class_label.add_theme_font_override(&"font", Style.bold)
	_class_stats = Style.label("", &"DimLabel", 13)
	grid.add_child(_key("CLASS"))
	grid.add_child(_pair(_class_label, _class_stats))
	_weapon_label = Style.label("", &"", 18)
	_weapon_label.add_theme_font_override(&"font", Style.bold)
	_secondary_label = Style.label("", &"DimLabel", 13)
	grid.add_child(_key("WEAPON"))
	grid.add_child(_pair(_weapon_label, _secondary_label))
	_ability_label = Style.label("", &"", 18)
	_ability_label.add_theme_font_override(&"font", Style.bold)
	grid.add_child(_key("ABILITY"))
	grid.add_child(_ability_label)
	return panel


func _build_settings_panel() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	panel.add_child(box)
	var head := PanelContainer.new()
	head.theme_type_variation = &"HeaderPanel"
	head.add_child(Style.label("MATCH SETTINGS", &"HeaderLabel"))
	box.add_child(head)
	var body := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		body.add_theme_constant_override(side, 14)
	box.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	body.add_child(row)

	if multiplayer.is_server():
		_kills_spin = SpinBox.new()
		_kills_spin.min_value = MIN_KILLS
		_kills_spin.max_value = MAX_KILLS
		_kills_spin.value = Net.lobby_kill_target
		_minutes_spin = SpinBox.new()
		_minutes_spin.min_value = MIN_MINUTES
		_minutes_spin.max_value = MAX_MINUTES
		_minutes_spin.value = Net.lobby_minutes
		_respawn_spin = SpinBox.new()
		_respawn_spin.min_value = MIN_RESPAWN
		_respawn_spin.max_value = MAX_RESPAWN
		_respawn_spin.step = 0.5
		_respawn_spin.value = Net.lobby_respawn
		_map_option = OptionButton.new()
		for map_def: MapDef in Net.MAP_LIST.maps:
			_map_option.add_item(_map_label(map_def))
		_map_option.selected = clampi(Net.lobby_map_index, 0, Net.MAP_LIST.maps.size() - 1)
		row.add_child(_field("KILLS", _kills_spin))
		row.add_child(_field("MINUTES", _minutes_spin))
		row.add_child(_field("RESPAWN S", _respawn_spin))
		row.add_child(_field("MAP", _map_option))
		_kills_spin.value_changed.connect(_on_rules_changed.unbind(1))
		_minutes_spin.value_changed.connect(_on_rules_changed.unbind(1))
		_respawn_spin.value_changed.connect(_on_rules_changed.unbind(1))
		_map_option.item_selected.connect(_on_rules_changed.unbind(1))
	else:
		_kills_value = _value_label()
		_minutes_value = _value_label()
		_respawn_value = _value_label()
		_map_value = _value_label()
		row.add_child(_field("KILLS", _kills_value))
		row.add_child(_field("MINUTES", _minutes_value))
		row.add_child(_field("RESPAWN S", _respawn_value))
		row.add_child(_field("MAP", _map_value))
	return panel


func _refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids: Array[int] = []
	ids.assign(Net.player_names.keys())
	ids.sort()
	var my_id: int = multiplayer.get_unique_id()
	for i: int in ids.size():
		_list.add_child(_player_row(ids[i], ids[i] == my_id, i == ids.size() - 1))

	var facts: Array[String] = ["HOST  ·  %s" % Net.get_player_name(1).to_upper(),
		"%d / %d PLAYERS" % [ids.size(), Net.MAX_PLAYERS]]
	if SteamLink.lobby_id != 0:
		facts.append("STEAM LOBBY")
	elif multiplayer.is_server():
		var addresses: Array[String] = _shareable_addresses()
		if not addresses.is_empty():
			facts.append("JOIN  ·  %s" % addresses[0])
	_info_label.text = "      ".join(facts)

	if _kills_value != null:
		_kills_value.text = str(Net.lobby_kill_target)
		_minutes_value.text = str(roundi(Net.lobby_minutes))
		_respawn_value.text = "%g" % Net.lobby_respawn
		_map_value.text = _map_label(Net.MAP_LIST.get_map(Net.lobby_map_index))


func _map_label(map_def: MapDef) -> String:
	if map_def.players_hint.is_empty():
		return map_def.display_name
	return "%s  (%s)" % [map_def.display_name, map_def.players_hint]


func _player_row(peer_id: int, is_me: bool, is_last: bool) -> Control:
	var row_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_HIGHLIGHT if is_me else Color.TRANSPARENT
	style.border_color = Color("222428")
	style.border_width_bottom = 0 if is_last else 1
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	row_panel.add_theme_stylebox_override(&"panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row_panel.add_child(row)

	row.add_child(_face_slot())
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 4.0
	row.add_child(spacer)
	var name_label := Style.label(Net.get_player_name(peer_id), &"", 22)
	name_label.add_theme_font_override(&"font", Style.bold)
	var you := Style.label("(you)" if is_me else "", &"DimLabel")
	var name_box := _pair(name_label, you)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_box)

	var status: String = "NOT READY"
	var color: Color = Color("6a6e75")
	if peer_id == 1:
		status = "HOST"
		color = Style.TEXT
	elif Net.ready_peers.get(peer_id, false):
		status = "READY"
		color = Style.GOOD
	var status_label := Style.label(status, &"", 14)
	status_label.add_theme_font_override(&"font", Style.bold)
	status_label.add_theme_color_override(&"font_color", color)
	status_label.custom_minimum_size.x = 140.0
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status_label)
	return row_panel


## Empty face slot (faces come in stage 8): a grey bust in a dark square.
func _face_slot() -> Control:
	var slot := PanelContainer.new()
	slot.theme_type_variation = &"InsetPanel"
	slot.custom_minimum_size = Vector2(FACE_SIZE, FACE_SIZE)
	var bust := Control.new()
	bust.clip_contents = true
	slot.add_child(bust)
	var head := Panel.new()
	head.add_theme_stylebox_override(&"panel", _round(Style.FIELD_BORDER, 12))
	head.position = Vector2(21.0, 10.0)
	head.size = Vector2(22.0, 24.0)
	bust.add_child(head)
	var shoulders := Panel.new()
	var shoulder_style := _round(Style.FIELD_BORDER, 22)
	shoulder_style.corner_radius_bottom_left = 0
	shoulder_style.corner_radius_bottom_right = 0
	shoulders.add_theme_stylebox_override(&"panel", shoulder_style)
	shoulders.position = Vector2(10.0, 38.0)
	shoulders.size = Vector2(44.0, 36.0)
	bust.add_child(shoulders)
	return slot


func _show_loadout(code: PackedInt32Array) -> void:
	var class_def: ClassDef = Loadout.get_class_def(code)
	var ability: AbilityDef = Loadout.get_ability(code)
	_class_label.text = class_def.display_name.to_upper()
	_class_stats.text = "%d HP  ·  %.1f m/s" % [class_def.max_health, class_def.move_speed]
	_weapon_label.text = Loadout.get_primary(code).display_name
	_secondary_label.text = "+ %s" % class_def.secondary_weapon.display_name
	_ability_label.text = "[Q]  %s  %ds" % [ability.display_name, roundi(ability.cooldown)] if ability != null else "-"


func _open_loadout() -> void:
	_loadout_overlay.visible = true
	_loadout_menu.open(Loadout.from_settings())


## The first spawn uses the saved loadout (Game sends Loadout.from_settings()).
func _on_loadout_confirmed(code: PackedInt32Array) -> void:
	Loadout.save_to_settings(code)
	_show_loadout(code)
	_loadout_overlay.visible = false


func _on_rules_changed() -> void:
	Net.server_set_lobby_settings(int(_kills_spin.value), _minutes_spin.value, _map_option.selected, _respawn_spin.value)


func _on_ready_toggled(on: bool) -> void:
	Net.request_lobby_ready(on)


func _on_start_pressed() -> void:
	_start_button.disabled = true
	Net.server_start_match(int(_kills_spin.value), _minutes_spin.value, _map_option.selected, _respawn_spin.value)


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


# --- Small builders ------------------------------------------------------------

func _panel() -> PanelContainer:
	var panel := PanelContainer.new() # No inner padding: header bars and rows run edge to edge.
	var style := StyleBoxFlat.new()
	style.bg_color = Style.PANEL
	style.border_color = Style.BORDER
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override(&"panel", style)
	return panel


func _header_row(titles: Array[String], widths: Array[float]) -> Control:
	var head := PanelContainer.new()
	head.theme_type_variation = &"HeaderPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	head.add_child(row)
	for i: int in titles.size():
		var title := Style.label(titles[i], &"HeaderLabel")
		if widths[i] > 0.0:
			title.custom_minimum_size.x = widths[i]
		else:
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
	return head


func _key(text: String) -> Label:
	var key := Style.label(text, &"MonoLabel", 11)
	key.custom_minimum_size.x = 64.0
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return key


func _pair(main: Label, extra: Label) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(main)
	box.add_child(extra)
	return box


func _field(title: String, control: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 4)
	box.add_child(Style.label(title, &"MonoLabel", 11))
	control.custom_minimum_size.y = 40.0
	box.add_child(control)
	return box


func _value_label() -> Label:
	var value := Style.label("", &"", 18)
	value.add_theme_font_override(&"font", Style.bold)
	return value


func _button(text: String, variation: StringName, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0.0, 50.0)
	button.add_theme_font_size_override(&"font_size", font_size)
	return button


func _round(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

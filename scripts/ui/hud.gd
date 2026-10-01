extends CanvasLayer
## In-game HUD for the local player, Red Faction / TimeSplitters era (GDD "Görsel referans"):
## bottom left bevelled health and ability bars with the class, bottom right weapon
## silhouettes with rounds, top centre timer and leader score, kill feed, Tab scoreboard,
## spawn protection, death screen ("FLATLINED" + loadout menu), end of match, flashbang
## white-out and the Esc panel (resume / settings / leave). Built in code from Style; the
## scene holds only the crosshair, kill feed, scoreboard, flash overlay and loadout menu.
## The small speed readout is a tuning aid for bunny hop / slide.

## Flash white-out stays solid for this share of its duration, then fades.
const FLASH_HOLD_SHARE: float = 0.4
const EDGE: float = 14.0
const HEALTH_BAR_SIZE: Vector2 = Vector2(210.0, 20.0)
const ABILITY_BAR_SIZE: Vector2 = Vector2(160.0, 16.0)
const LOW_HEALTH_SHARE: float = 0.3
const CURRENT_ICON_SIZE: Vector2 = Vector2(150.0, 44.0)
const OTHER_ICON_SIZE: Vector2 = Vector2(74.0, 38.0)
const OTHER_WEAPON_ALPHA: float = 0.55
const DIM_COLOR: Color = Color(0.04, 0.04, 0.045, 0.82)
const PAUSE_DIM: Color = Color(0.0, 0.0, 0.0, 0.55)
const DEATH_TINT: Color = Color(0.43, 0.08, 0.06, 0.35)

var _player: Player
## The loadout menu was opened by dying (closes itself on respawn).
var _menu_opened_by_death: bool = false
var _flash_left: float = 0.0
var _flash_total: float = 0.0
var _stun_left: float = 0.0
var _respawn_left: float = 0.0
var _scope_overlay: ScopeOverlay
var _settings_panel: SettingsPanel

# Built in code.
var _health_bar: HudBar
var _health_label: Label
var _ability_bar: HudBar
var _ability_label: Label
var _class_label: Label
var _weapon_name_label: Label
var _current_icon: HudWeaponIcon
var _ammo_label: Label
var _magazine_label: Label
var _other_row: Control
var _other_icon: HudWeaponIcon
var _other_ammo_label: Label
var _top_bar: HBoxContainer
var _time_label: Label
var _time_divider: Label
var _leader_label: Label
var _protected_label: Label
var _stun_label: Label
var _next_spawn_label: Label
var _speed_label: Label
var _dim: ColorRect
var _death_tint: TextureRect
var _screen_title: Label
var _death_line: RichTextLabel
var _respawn_label: Label
var _end_panel: VBoxContainer
var _winner_label: Label
var _awards_label: Label
var _next_label: Label
var _pause_panel: Control

@onready var crosshair: Crosshair = $Crosshair
@onready var scoreboard: Scoreboard = $Scoreboard
@onready var loadout_menu: LoadoutMenu = $LoadoutMenu
@onready var flash_overlay: ColorRect = $FlashOverlay


func _ready() -> void:
	_scope_overlay = ScopeOverlay.new()
	add_child(_scope_overlay)
	move_child(_scope_overlay, 0) # Under everything, so health/ammo stay readable while scoped.
	var hud_root: Control = _build_hud()
	add_child(hud_root)
	move_child(hud_root, 1)
	_build_death_screen()
	_build_end_panel()
	_build_pause_panel()
	_settings_panel = SettingsPanel.new()
	add_child(_settings_panel) # Last child: drawn over the pause panel.

	Events.local_stunned.connect(_on_local_stunned)
	Events.local_player_spawned.connect(_on_local_player_spawned)
	Events.hit_confirmed.connect(crosshair.show_hit)
	Events.player_died.connect(_on_player_died)
	Events.match_ended.connect(_on_match_ended)
	Events.match_started.connect(_on_match_started)
	Events.local_flashed.connect(_on_local_flashed)
	loadout_menu.confirmed.connect(_on_loadout_confirmed)
	scoreboard.visible = false
	_pause_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel.visible and event.is_action_pressed(&"pause_menu"):
		_settings_panel.close()
		get_viewport().set_input_as_handled()
		return
	if not is_instance_valid(_player):
		# Late joiner still picking a loadout (no player yet): Esc leaves the game.
		if event.is_action_pressed(&"pause_menu") and loadout_menu.visible:
			get_viewport().set_input_as_handled()
			Net.leave()
		return
	if event.is_action_pressed(&"class_menu"):
		if loadout_menu.visible:
			_close_loadout_menu()
		else:
			_open_loadout_menu(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause_menu") and loadout_menu.visible:
		_close_loadout_menu()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_top_bar()
	_update_flash(delta)
	var ended: bool = Match.state == Match.State.ENDED
	scoreboard.visible = (ended or Input.is_action_pressed(&"scoreboard")) and not loadout_menu.visible
	if ended:
		_next_label.text = "Next match in %d" % ceili(Match.end_screen_left)
	var dead: bool = is_instance_valid(_player) and not _player.is_alive
	_dim.visible = loadout_menu.visible or dead
	_death_tint.visible = dead
	_death_line.visible = dead
	_respawn_label.visible = dead
	_screen_title.visible = _dim.visible
	_screen_title.text = "FLATLINED" if dead else "LOADOUT"
	if dead:
		_respawn_left = maxf(_respawn_left - delta, 0.0)
		_respawn_label.text = "Respawn in %d" % ceili(_respawn_left)
	if not is_instance_valid(_player):
		return
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if loadout_menu.visible and captured:
		_close_loadout_menu() # Mouse was recaptured by clicking the game.
	if _settings_panel.visible and captured:
		_settings_panel.close()
	_pause_panel.visible = not captured and not loadout_menu.visible and not _settings_panel.visible
	_speed_label.text = "%.1f m/s" % _player.movement.get_horizontal_speed()
	_scope_overlay.active = _player.is_scoped
	crosshair.visible = _player.is_alive and not _player.is_scoped
	_update_health()
	_update_ability()
	_update_weapons()
	_update_next_spawn_label()


# --- Building --------------------------------------------------------------------

func _build_hud() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Bottom left: health, ability, class.
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = EDGE
	left.offset_bottom = -EDGE - 2.0
	left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	left.add_theme_constant_override(&"separation", 6)
	root.add_child(left)
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override(&"separation", 8)
	left.add_child(health_row)
	_health_bar = HudBar.new()
	_health_bar.custom_minimum_size = HEALTH_BAR_SIZE
	health_row.add_child(_health_bar)
	_health_label = _centered(Style.label("100", &"HudLabel", 16))
	health_row.add_child(_health_label)
	var ability_row := HBoxContainer.new()
	ability_row.add_theme_constant_override(&"separation", 8)
	left.add_child(ability_row)
	_ability_bar = HudBar.new()
	_ability_bar.custom_minimum_size = ABILITY_BAR_SIZE
	_ability_bar.set_colors(Color("b6c9e6"), Color("6c86b0"), Color("46597c"))
	ability_row.add_child(_ability_bar)
	_ability_label = _centered(Style.label("", &"HudSmallLabel", 12))
	ability_row.add_child(_ability_label)
	_class_label = Style.label("", &"MonoLabel", 11)
	left.add_child(_class_label)

	# Bottom right: weapon in hand (big) and the other one (dim), with rounds.
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.offset_right = -EDGE
	right.offset_bottom = -EDGE
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override(&"separation", 4)
	root.add_child(right)
	_weapon_name_label = Style.label("", &"HudSmallLabel", 12)
	_weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_weapon_name_label)
	var current_row := HBoxContainer.new()
	current_row.alignment = BoxContainer.ALIGNMENT_END
	current_row.add_theme_constant_override(&"separation", 10)
	right.add_child(current_row)
	_current_icon = HudWeaponIcon.new()
	_current_icon.custom_minimum_size = CURRENT_ICON_SIZE
	current_row.add_child(_current_icon)
	var ammo_box := HBoxContainer.new()
	ammo_box.add_theme_constant_override(&"separation", 4)
	current_row.add_child(ammo_box)
	_ammo_label = _centered(Style.label("", &"HudLabel", 22))
	ammo_box.add_child(_ammo_label)
	_magazine_label = _centered(Style.label("", &"HudSmallLabel", 15))
	ammo_box.add_child(_magazine_label)
	var other_row := HBoxContainer.new()
	other_row.alignment = BoxContainer.ALIGNMENT_END
	other_row.add_theme_constant_override(&"separation", 10)
	other_row.modulate.a = OTHER_WEAPON_ALPHA
	right.add_child(other_row)
	_other_row = other_row
	_other_icon = HudWeaponIcon.new()
	_other_icon.custom_minimum_size = OTHER_ICON_SIZE
	other_row.add_child(_other_icon)
	_other_ammo_label = _centered(Style.label("", &"HudLabel", 15))
	other_row.add_child(_other_ammo_label)

	# Top centre: time | LEADER kills / target.
	_top_bar = HBoxContainer.new()
	_top_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_top_bar.offset_top = 14.0
	_top_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_top_bar.add_theme_constant_override(&"separation", 14)
	root.add_child(_top_bar)
	_time_label = Style.label("", &"HudLabel")
	_time_divider = Style.label("|", &"HudSmallLabel", 18)
	_leader_label = Style.label("", &"HudLabel")
	for part: Label in [_time_label, _time_divider, _leader_label]:
		_top_bar.add_child(part)

	_protected_label = _center_label("SPAWN PROTECTION", &"HudSmallLabel", 14, 44.0)
	root.add_child(_protected_label)
	_stun_label = _center_label("STUNNED", &"HudLabel", 28, -170.0)
	root.add_child(_stun_label)
	_next_spawn_label = Style.label("", &"HudSmallLabel", 14)
	_next_spawn_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_next_spawn_label.offset_top = -64.0
	_next_spawn_label.offset_bottom = -44.0
	_next_spawn_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_next_spawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_next_spawn_label)
	_speed_label = Style.label("", &"MonoLabel", 11)
	_speed_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_label.offset_top = -26.0
	_speed_label.offset_bottom = -10.0
	_speed_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_speed_label)
	_protected_label.visible = false
	_stun_label.visible = false
	_next_spawn_label.visible = false
	return root


## Death / loadout backdrop, drawn under the loadout menu.
func _build_death_screen() -> void:
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	move_child(_dim, loadout_menu.get_index())

	_death_tint = TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([DEATH_TINT, Color(DEATH_TINT, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	_death_tint.texture = texture
	_death_tint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_death_tint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_death_tint.offset_bottom = 220.0
	_dim.add_child(_death_tint)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_TOP_WIDE)
	column.offset_top = 52.0
	column.add_theme_constant_override(&"separation", 8)
	_dim.add_child(column)
	_screen_title = Style.label("FLATLINED", &"TitleLabel", 72)
	_screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_screen_title)
	_death_line = RichTextLabel.new()
	_death_line.bbcode_enabled = true
	_death_line.fit_content = true
	_death_line.scroll_active = false
	_death_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_line.add_theme_font_size_override(&"normal_font_size", 17)
	_death_line.add_theme_font_size_override(&"bold_font_size", 17)
	_death_line.add_theme_font_override(&"bold_font", Style.bold)
	_death_line.add_theme_color_override(&"default_color", Color("a6aab0"))
	column.add_child(_death_line)
	_respawn_label = Style.label("", &"MonoLabel", 13)
	_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_respawn_label)
	_dim.visible = false


func _build_end_panel() -> void:
	_end_panel = VBoxContainer.new()
	_end_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_end_panel.offset_top = 40.0
	_end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_panel.add_theme_constant_override(&"separation", 6)
	add_child(_end_panel)
	move_child(_end_panel, flash_overlay.get_index())
	_winner_label = Style.label("", &"TitleLabel", 56)
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_panel.add_child(_winner_label)
	_awards_label = Style.label("", &"HudSmallLabel", 16)
	_awards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_panel.add_child(_awards_label)
	_next_label = Style.label("", &"MonoLabel", 13)
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_panel.add_child(_next_label)
	_end_panel.visible = false


func _build_pause_panel() -> void:
	var dim := ColorRect.new()
	dim.color = PAUSE_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_pause_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 300.0
	box.add_theme_constant_override(&"separation", 2)
	panel.add_child(box)
	var title := Style.label("PAUSED", &"HeaderLabel")
	title.custom_minimum_size.y = 28.0
	box.add_child(title)
	var resume := Style.menu_button("RESUME")
	resume.pressed.connect(func() -> void: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	box.add_child(resume)
	var settings := Style.menu_button("SETTINGS")
	settings.pressed.connect(func() -> void: _settings_panel.open())
	box.add_child(settings)
	var leave := Style.menu_button("LEAVE GAME")
	leave.add_theme_color_override(&"font_color", Style.TEXT_DIM)
	leave.pressed.connect(func() -> void: Net.leave())
	box.add_child(leave)


func _centered(label: Label) -> Label:
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _center_label(text: String, variation: StringName, font_size: int, offset_y: float) -> Label:
	var result := Style.label(text, variation, font_size)
	result.set_anchors_preset(Control.PRESET_CENTER)
	result.offset_top = offset_y
	result.offset_bottom = offset_y + font_size + 8.0
	result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return result


# --- Updating --------------------------------------------------------------------

func _update_health() -> void:
	var max_health: int = maxi(_player.class_def.max_health, 1)
	var share: float = float(_player.health) / max_health
	_health_bar.value = share
	if share <= LOW_HEALTH_SHARE:
		_health_bar.set_colors(Color("e6b0a8"), Color("b0564a"), Color("7a3028"))
	else:
		_health_bar.set_colors(Color("b8dcb0"), Color("6f9f68"), Color("4a7546"))
	_health_label.text = str(_player.health)
	_class_label.text = _player.class_def.display_name.to_upper()


func _update_ability() -> void:
	var ability: Ability = _player.ability
	_ability_bar.visible = ability != null
	if ability == null:
		_ability_label.text = ""
		return
	var name_text: String = ability.def.display_name.to_upper()
	var buff_left: float = _player.status.get_buff_left()
	if buff_left > 0.0:
		_ability_bar.value = buff_left / maxf(ability.def.duration, 0.001)
		_ability_label.text = "Q  %s  ACTIVE" % name_text
	elif ability.is_ready():
		_ability_bar.value = 1.0
		_ability_label.text = "Q  %s  READY" % name_text
	else:
		_ability_bar.value = 1.0 - ability.cooldown_left / maxf(ability.def.cooldown, 0.001)
		_ability_label.text = "Q  %s  %d" % [name_text, ceili(ability.cooldown_left)]


func _update_weapons() -> void:
	var weapon: Weapon = _player.current_weapon
	if weapon == null:
		return
	var slot: int = _player.weapons.find(weapon)
	_weapon_name_label.text = weapon.def.display_name.to_upper()
	_current_icon.shape = HudWeaponIcon.shape_for(weapon.def, slot)
	if not weapon.def.uses_ammo:
		_ammo_label.text = ""
		_magazine_label.text = ""
	elif weapon.is_reloading:
		_ammo_label.text = "RELOADING"
		_magazine_label.text = ""
	else:
		_ammo_label.text = str(weapon.ammo)
		_magazine_label.text = "/ %d" % weapon.def.magazine_size
	var other_slot: int = 1 - slot if slot >= 0 and _player.weapons.size() == 2 else -1
	_other_row.visible = other_slot >= 0
	if other_slot >= 0:
		var other: Weapon = _player.weapons[other_slot]
		_other_icon.shape = HudWeaponIcon.shape_for(other.def, other_slot)
		_other_ammo_label.text = str(other.ammo) if other.def.uses_ammo else ""


func _update_top_bar() -> void:
	_top_bar.visible = Match.active
	var has_time: bool = Match.has_time_limit()
	var has_target: bool = Match.rules.kill_target > 0
	_time_label.visible = has_time
	_time_divider.visible = has_time and has_target
	_leader_label.visible = has_target
	if has_time:
		var seconds: int = ceili(Match.time_left)
		_time_label.text = "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	if has_target:
		var leader_kills: int = 0
		var ranking: Array[int] = Match.get_ranking()
		if not ranking.is_empty():
			leader_kills = Match.get_kills(ranking[0])
		_leader_label.text = "LEADER  %d / %d" % [leader_kills, Match.rules.kill_target]


func _update_next_spawn_label() -> void:
	var requested: PackedInt32Array = _player.requested_loadout
	_next_spawn_label.visible = not requested.is_empty() and requested != _player.loadout
	if _next_spawn_label.visible:
		_next_spawn_label.text = "Next spawn: %s" % Loadout.describe(requested)


func _on_local_stunned(seconds: float) -> void:
	_stun_left = seconds
	_stun_label.visible = true


func _update_flash(delta: float) -> void:
	if _stun_left > 0.0:
		_stun_left -= delta
		_stun_label.visible = _stun_left > 0.0
	if _flash_left <= 0.0:
		flash_overlay.color.a = 0.0
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	var fade_time: float = _flash_total * (1.0 - FLASH_HOLD_SHARE)
	flash_overlay.color.a = 1.0 if _flash_left > fade_time else _flash_left / maxf(fade_time, 0.001)


func _on_local_flashed(seconds: float) -> void:
	# A stronger flash replaces a weaker one; a weaker one never shortens the current one.
	if seconds > _flash_left:
		_flash_left = seconds
		_flash_total = seconds


func _open_loadout_menu(by_death: bool) -> void:
	_menu_opened_by_death = by_death
	var current: PackedInt32Array = _player.requested_loadout if not _player.requested_loadout.is_empty() else _player.loadout
	loadout_menu.open(current)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_loadout_menu() -> void:
	loadout_menu.visible = false
	_menu_opened_by_death = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_loadout_confirmed(code: PackedInt32Array) -> void:
	if is_instance_valid(_player):
		_player.request_loadout(code)
	_close_loadout_menu()


func _on_local_player_spawned(player: Player) -> void:
	if is_instance_valid(_player):
		_player.alive_changed.disconnect(_on_alive_changed)
		_player.protection_changed.disconnect(_on_protection_changed)
	_player = player
	player.alive_changed.connect(_on_alive_changed)
	player.protection_changed.connect(_on_protection_changed)
	_on_alive_changed(player.is_alive)
	_on_protection_changed(player.is_protected)


func _on_alive_changed(is_alive: bool) -> void:
	crosshair.visible = is_alive
	_stun_left = 0.0 # A stun never outlives the life it hit.
	_stun_label.visible = false
	if is_alive and loadout_menu.visible and _menu_opened_by_death:
		_close_loadout_menu()


func _on_protection_changed(is_protected: bool) -> void:
	_protected_label.visible = is_protected


func _on_player_died(victim: Player, killer_id: int, weapon_name: String, killer_health: int) -> void:
	if victim != _player:
		return
	_respawn_left = Match.rules.respawn_delay
	if killer_id == victim.get_multiplayer_authority():
		_death_line.text = "You died  ·  %s" % weapon_name
	else:
		_death_line.text = "Killed by [b][color=#ffffff]%s[/color][/b]  ·  %s  ·  [color=#c4554a]%d HP left[/color]" % [
			_escape(Net.get_player_name(killer_id)), weapon_name, killer_health]
	if not loadout_menu.visible:
		_open_loadout_menu(true) # GDD: the class menu opens on the death screen.


func _on_match_ended(winner_id: int, awards: Array) -> void:
	_winner_label.text = "%s WINS" % Net.get_player_name(winner_id).to_upper() if winner_id != -1 else "DRAW"
	var lines: Array[String] = []
	for award: Array in awards:
		lines.append("%s:  %s  (%s)" % [award[0], Net.get_player_name(award[1]), award[2]])
	_awards_label.text = "\n".join(lines)
	_end_panel.visible = true


func _on_match_started() -> void:
	_end_panel.visible = false


## Player names go into BBCode: keep their brackets literal.
func _escape(text: String) -> String:
	return text.replace("[", "[lb]")

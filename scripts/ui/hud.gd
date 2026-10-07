extends CanvasLayer
## In-game HUD for the local player, Red Faction / TimeSplitters era (GDD "Görsel referans"):
## bottom left bevelled health and ability bars with the class, bottom right weapon
## silhouettes with rounds, top centre timer and leader score, kill feed, Tab scoreboard,
## spawn protection, pickup boosts, airdrop announcements and the crate opening bar,
## death screen ("FLATLINED" + loadout menu), end of match, flashbang
## white-out and the Esc panel (resume / settings / leave). Built in code from Style; the
## scene holds only the crosshair, kill feed, scoreboard, flash overlay and loadout menu.
## The small speed readout is a tuning aid for bunny hop / slide.

## Flash white-out stays solid for this share of its duration, then fades.
const FLASH_HOLD_SHARE: float = 0.4
const EDGE: float = 14.0
const HEALTH_BAR_SIZE: Vector2 = Vector2(210.0, 20.0)
const ABILITY_BAR_SIZE: Vector2 = Vector2(160.0, 16.0)
const LOW_HEALTH_SHARE: float = 0.3
const CURRENT_ICON_SIZE: Vector2 = Vector2(150.0, 46.0)
const OTHER_ICON_SIZE: Vector2 = Vector2(112.0, 32.0)
const OTHER_WEAPON_ALPHA: float = 0.45
## The weapon in hand: brighter than white-on-white (modulate above 1) on a faint light plate.
const CURRENT_WEAPON_GLOW: Color = Color(1.2, 1.2, 1.25, 1.0)
const CURRENT_PLATE: Color = Color(1.0, 1.0, 1.0, 0.12)
const AMMO_FONT_CURRENT: int = 22
const AMMO_FONT_OTHER: int = 15
const DIM_COLOR: Color = Color(0.04, 0.04, 0.045, 0.82)
const PAUSE_DIM: Color = Color(0.0, 0.0, 0.0, 0.55)
const DEATH_TINT: Color = Color(0.43, 0.08, 0.06, 0.35)
const WEAPON_ROWS: int = 4 ## One fixed row per weapon slot: primary, secondary, knife, airdrop.
const BANNER_TIME: float = 3.0
const OPEN_BAR_SIZE: Vector2 = Vector2(220.0, 16.0)
const BOOST_DEFS: Array[PickupDef] = [preload("res://data/pickups/speed.tres"), preload("res://data/pickups/double_jump.tres")]

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
var _weapon_rows: Array[PanelContainer] = []
var _weapon_icons: Array[HudWeaponIcon] = []
var _ammo_labels: Array[Label] = []
var _magazine_labels: Array[Label] = []
var _boost_labels: Array[Label] = []
var _open_box: VBoxContainer
var _open_bar: HudBar
var _banner: Label
var _banner_left: float = 0.0
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
var _damage_overlay: DamageOverlay

@onready var loadout_menu: LoadoutMenu = $LoadoutMenu
@onready var flash_overlay: ColorRect = $FlashOverlay


func _ready() -> void:
	_scope_overlay = ScopeOverlay.new()
	add_child(_scope_overlay)
	move_child(_scope_overlay, 0) # Under everything, so health/ammo stay readable while scoped.
	_damage_overlay = DamageOverlay.new()
	add_child(_damage_overlay) # Its own canvas layer, above the screen filter.
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
	Events.hit_confirmed.connect(func(zone: Hitbox.Zone, killed: bool, _amount: float) -> void:
		Sfx.hit_confirm(self, zone, killed))
	Events.player_died.connect(_on_player_died)
	Events.match_ended.connect(_on_match_ended)
	Events.match_started.connect(_on_match_started)
	Events.local_flashed.connect(_on_local_flashed)
	Events.airdrop_incoming.connect(func(_point: Vector3) -> void:
		_show_banner("AIRDROP INCOMING")
		Sfx.play_ui(self, Sfx.WARNING))
	Events.airdrop_opened.connect(func(peer_id: int, weapon_name: String) -> void:
		_show_banner("%s GOT THE %s" % [Net.get_player_name(peer_id).to_upper(), weapon_name.to_upper()]))
	loadout_menu.confirmed.connect(_on_loadout_confirmed)
	scoreboard.visible = false
	_pause_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel.visible and event.is_action_pressed(&"pause_menu"):
		_settings_panel.close()
		get_viewport().set_input_as_handled()
		return
	if not is_instance_valid(_player):
		# Late joiner still picking a loadout (no player yet): Esc swaps the loadout menu and
		# the pause panel (Resume goes back to the loadout, Leave Game leaves).
		if event.is_action_pressed(&"pause_menu") and (loadout_menu.visible or _pause_panel.visible):
			get_viewport().set_input_as_handled()
			set_join_paused(loadout_menu.visible)
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
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.visible = _banner_left > 0.0
	var ended: bool = Match.state == Match.State.ENDED
	scoreboard.visible = (ended or Input.is_action_pressed(&"scoreboard")) and not loadout_menu.visible
	if ended:
		_next_label.text = "%s in %d" % ["Back to lobby" if Match.returns_to_lobby else "Next match", ceili(Match.end_screen_left)]
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
	if _player.is_scoped:
		_scope_overlay.set_motion(_player.velocity.length())
	var weapon: Weapon = _player.current_weapon
	var hip_crosshair: bool = weapon == null or weapon.def.hip_crosshair
	crosshair.visible = _player.is_alive and not _player.is_scoped and hip_crosshair
	_update_health()
	_update_ability()
	_update_weapons()
	_update_boosts()
	_update_open_bar()
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
	for def: PickupDef in BOOST_DEFS:
		var boost := Style.label("", &"HudSmallLabel", 13)
		boost.add_theme_color_override(&"font_color", def.color)
		boost.visible = false
		left.add_child(boost)
		_boost_labels.append(boost)
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
	for slot: int in WEAPON_ROWS: # Fixed order, like the number keys; the one in hand lights up.
		var plate := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = CURRENT_PLATE
		style.content_margin_left = 6.0
		style.content_margin_right = 4.0
		plate.add_theme_stylebox_override(&"panel", style)
		right.add_child(plate)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override(&"separation", 10)
		plate.add_child(row)
		var icon := HudWeaponIcon.new()
		row.add_child(icon)
		var ammo_box := HBoxContainer.new()
		ammo_box.add_theme_constant_override(&"separation", 4)
		ammo_box.custom_minimum_size.x = 92.0
		ammo_box.alignment = BoxContainer.ALIGNMENT_END
		row.add_child(ammo_box)
		var ammo := _centered(Style.label("", &"HudLabel", AMMO_FONT_OTHER))
		ammo_box.add_child(ammo)
		var magazine := _centered(Style.label("", &"HudSmallLabel", 15))
		ammo_box.add_child(magazine)
		_weapon_rows.append(plate)
		_weapon_icons.append(icon)
		_ammo_labels.append(ammo)
		_magazine_labels.append(magazine)

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
	# Crate opening bar under the crosshair, and the big announcement line.
	_open_box = VBoxContainer.new()
	_open_box.set_anchors_preset(Control.PRESET_CENTER)
	_open_box.offset_left = -OPEN_BAR_SIZE.x * 0.5
	_open_box.offset_right = OPEN_BAR_SIZE.x * 0.5
	_open_box.offset_top = 70.0
	_open_box.offset_bottom = 110.0
	_open_box.add_theme_constant_override(&"separation", 4)
	var open_label := Style.label("OPENING CRATE", &"HudSmallLabel", 12)
	open_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_open_box.add_child(open_label)
	_open_bar = HudBar.new()
	_open_bar.custom_minimum_size = OPEN_BAR_SIZE
	_open_bar.set_colors(Color("f0c8a0"), Color("c8784a"), Color("8a4a2a"))
	_open_box.add_child(_open_bar)
	_open_box.visible = false
	root.add_child(_open_box)
	_banner = _center_label("", &"TitleLabel", 34, -250.0)
	_banner.visible = false
	root.add_child(_banner)

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
	resume.pressed.connect(_on_resume_pressed)
	box.add_child(resume)
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer: # Test Range practice switch.
		var unlimited := Style.menu_button(_unlimited_abilities_text())
		unlimited.pressed.connect(_on_unlimited_abilities_pressed.bind(unlimited))
		box.add_child(unlimited)
	var settings := Style.menu_button("SETTINGS")
	settings.pressed.connect(func() -> void: _settings_panel.open())
	box.add_child(settings)
	var leave := Style.menu_button("LEAVE GAME")
	leave.add_theme_color_override(&"font_color", Style.TEXT_DIM)
	leave.pressed.connect(func() -> void: Net.leave())
	box.add_child(leave)


func _unlimited_abilities_text() -> String:
	return "UNLIMITED ABILITIES: %s" % ("ON" if Settings.practice_unlimited_abilities else "OFF")


## Test Range only (offline, we are the host): abilities without a cooldown, remembered.
func _on_unlimited_abilities_pressed(button: Button) -> void:
	Settings.practice_unlimited_abilities = not Settings.practice_unlimited_abilities
	Settings.save_settings()
	Match.rules.ability_cooldowns = not Settings.practice_unlimited_abilities
	button.text = _unlimited_abilities_text()
	if Settings.practice_unlimited_abilities and is_instance_valid(_player) and _player.ability != null:
		_player.ability.cooldown_left = 0.0
		_player.ability.host_ready_at = -INF


func _on_resume_pressed() -> void:
	if not is_instance_valid(_player):
		set_join_paused(false) # Late joiner: back to picking a loadout.
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Late joiner without a player yet: the pause panel stands in for the loadout menu.
func set_join_paused(paused: bool) -> void:
	loadout_menu.visible = not paused
	_pause_panel.visible = paused


func is_join_paused() -> bool:
	return _pause_panel.visible and not is_instance_valid(_player)


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
	var window: Array = ability.get_hud_window()
	_ability_bar.striped = not window.is_empty() and bool(window[3])
	if not window.is_empty():
		_ability_bar.value = float(window[0]) / maxf(float(window[1]), 0.001)
		_ability_label.text = "Q  %s  %d" % [window[2], ceili(float(window[0]))]
	elif buff_left > 0.0:
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
	_weapon_name_label.text = weapon.def.display_name.to_upper()
	for slot: int in WEAPON_ROWS:
		var row: PanelContainer = _weapon_rows[slot]
		row.visible = slot < _player.weapons.size()
		if not row.visible:
			continue
		var shown: Weapon = _player.weapons[slot]
		var in_hand: bool = shown == weapon
		var icon: HudWeaponIcon = _weapon_icons[slot]
		icon.show_weapon(shown.def, slot)
		icon.custom_minimum_size = CURRENT_ICON_SIZE if in_hand else OTHER_ICON_SIZE
		row.modulate = CURRENT_WEAPON_GLOW if in_hand else Color(1.0, 1.0, 1.0, OTHER_WEAPON_ALPHA)
		row.self_modulate.a = 1.0 if in_hand else 0.0 # The light plate behind the weapon in hand.
		var ammo: Label = _ammo_labels[slot]
		var magazine: Label = _magazine_labels[slot]
		ammo.add_theme_font_size_override(&"font_size", AMMO_FONT_CURRENT if in_hand else AMMO_FONT_OTHER)
		magazine.visible = in_hand
		if not shown.def.uses_ammo:
			ammo.text = ""
			magazine.text = ""
		elif in_hand and shown.is_reloading:
			ammo.text = "RELOADING"
			magazine.text = ""
		else:
			ammo.text = str(shown.ammo)
			magazine.text = "/ %d" % shown.def.magazine_size


func _update_boosts() -> void:
	for i: int in BOOST_DEFS.size():
		var left: float = _player.status.get_pickup_left(BOOST_DEFS[i].kind)
		_boost_labels[i].visible = left > 0.0
		if left > 0.0:
			_boost_labels[i].text = "%s  %d" % [BOOST_DEFS[i].display_name.to_upper(), ceili(left)]


func _update_open_bar() -> void:
	var airdrops: AirdropManager = AirdropManager.find(get_tree())
	var progress: float = airdrops.local_progress if airdrops != null and _player.is_alive else -1.0
	_open_box.visible = progress >= 0.0
	if progress >= 0.0:
		_open_bar.value = progress


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	_banner_left = BANNER_TIME


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
	_damage_overlay.watch(player)


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

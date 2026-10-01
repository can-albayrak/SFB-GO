extends CanvasLayer
## In-game HUD for the local player: health, ammo, weapon, crosshair, hit marker,
## match timer, kill feed, Tab scoreboard, spawn protection, death and end-of-match
## screens, loadout menu (B / on death), ability cooldown, flashbang white-out,
## and the Esc panel (resume / settings / leave).
## The speed readout is a tuning aid for bunny hop / slide.

## Flash white-out stays solid for this share of its duration, then fades.
const FLASH_HOLD_SHARE: float = 0.4

var _player: Player
var _weapon: Weapon
## The loadout menu was opened by dying (closes itself on respawn).
var _menu_opened_by_death: bool = false
var _flash_left: float = 0.0
var _flash_total: float = 0.0
var _scope_overlay: ScopeOverlay
var _stun_label: Label
var _stun_left: float = 0.0
var _settings_panel: SettingsPanel

@onready var crosshair: Crosshair = $Crosshair
@onready var health_label: Label = $HealthLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var speed_label: Label = $SpeedLabel
@onready var death_label: Label = $DeathLabel
@onready var top_bar: Label = $TopBar
@onready var protected_label: Label = $ProtectedLabel
@onready var scoreboard: Scoreboard = $Scoreboard
@onready var end_panel: Control = $EndPanel
@onready var winner_label: Label = $EndPanel/WinnerLabel
@onready var awards_label: Label = $EndPanel/AwardsLabel
@onready var next_label: Label = $EndPanel/NextLabel
@onready var pause_panel: Control = $PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var leave_button: Button = %LeaveButton
@onready var settings_button: Button = %SettingsButton
@onready var loadout_menu: LoadoutMenu = $LoadoutMenu
@onready var ability_label: Label = $AbilityLabel
@onready var next_spawn_label: Label = $NextSpawnLabel
@onready var flash_overlay: ColorRect = $FlashOverlay


func _ready() -> void:
	_scope_overlay = ScopeOverlay.new()
	add_child(_scope_overlay)
	move_child(_scope_overlay, 0) # Under every label, so health/ammo stay readable while scoped.
	_stun_label = Label.new()
	_stun_label.text = "STUNNED"
	_stun_label.add_theme_font_size_override(&"font_size", 40)
	_stun_label.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.2))
	_stun_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_stun_label.position.y = 140.0
	_stun_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stun_label.visible = false
	add_child(_stun_label)
	Events.local_stunned.connect(_on_local_stunned)
	Events.local_player_spawned.connect(_on_local_player_spawned)
	Events.hit_confirmed.connect(crosshair.show_hit)
	Events.player_died.connect(_on_player_died)
	Events.match_ended.connect(_on_match_ended)
	Events.match_started.connect(_on_match_started)
	Events.local_flashed.connect(_on_local_flashed)
	resume_button.pressed.connect(_on_resume_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	_settings_panel = SettingsPanel.new()
	add_child(_settings_panel) # Last child: drawn over the pause panel.
	settings_button.pressed.connect(_settings_panel.open)
	loadout_menu.confirmed.connect(_on_loadout_confirmed)
	death_label.visible = false
	protected_label.visible = false
	end_panel.visible = false
	scoreboard.visible = false
	pause_panel.visible = false
	next_spawn_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel.visible and event.is_action_pressed(&"pause_menu"):
		_settings_panel.close()
		get_viewport().set_input_as_handled()
		return
	if not is_instance_valid(_player):
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
		next_label.text = "Next match in %d" % ceili(Match.end_screen_left)
	if not is_instance_valid(_player):
		return
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if loadout_menu.visible and captured:
		_close_loadout_menu() # Mouse was recaptured by clicking the game.
	if _settings_panel.visible and captured:
		_settings_panel.close()
	pause_panel.visible = not captured and not loadout_menu.visible and not _settings_panel.visible
	speed_label.text = "%.1f m/s" % _player.movement.get_horizontal_speed()
	_scope_overlay.active = _player.is_scoped
	crosshair.visible = _player.is_alive and not _player.is_scoped
	_update_ability_label()
	_update_next_spawn_label()


func _update_ability_label() -> void:
	var ability: Ability = _player.ability
	if ability == null:
		ability_label.text = ""
	elif _player.get_buff_left() > 0.0:
		ability_label.text = "Q  %s  ACTIVE %.1f" % [ability.def.display_name, _player.get_buff_left()]
	elif ability.is_ready():
		ability_label.text = "Q  %s  READY" % ability.def.display_name
	else:
		ability_label.text = "Q  %s  %d" % [ability.def.display_name, ceili(ability.cooldown_left)]


func _update_next_spawn_label() -> void:
	var requested: PackedInt32Array = _player.requested_loadout
	next_spawn_label.visible = not requested.is_empty() and requested != _player.loadout
	if next_spawn_label.visible:
		next_spawn_label.text = "Next spawn: %s" % Loadout.describe(requested)


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


func _update_top_bar() -> void:
	top_bar.visible = Match.active
	var parts: Array[String] = []
	if Match.has_time_limit():
		var seconds: int = ceili(Match.time_left)
		parts.append("%d:%02d" % [floori(seconds / 60.0), seconds % 60])
	if Match.rules.kill_target > 0:
		var leader_kills: int = 0
		var ranking: Array[int] = Match.get_ranking()
		if not ranking.is_empty():
			leader_kills = Match.get_kills(ranking[0])
		parts.append("%d / %d" % [leader_kills, Match.rules.kill_target])
	top_bar.text = "   ·   ".join(parts)


func _on_local_player_spawned(player: Player) -> void:
	if is_instance_valid(_player):
		_player.health_changed.disconnect(_on_health_changed)
		_player.weapon_changed.disconnect(_on_weapon_changed)
		_player.alive_changed.disconnect(_on_alive_changed)
		_player.protection_changed.disconnect(_on_protection_changed)
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.alive_changed.connect(_on_alive_changed)
	player.protection_changed.connect(_on_protection_changed)
	_on_health_changed(player.health, player.class_def.max_health)
	_on_weapon_changed(player.current_weapon)
	_on_alive_changed(player.is_alive)
	_on_protection_changed(player.is_protected)


func _on_health_changed(health: int, _max_health: int) -> void:
	health_label.text = "+ %d" % health


func _on_alive_changed(is_alive: bool) -> void:
	crosshair.visible = is_alive
	if is_alive:
		death_label.visible = false
		if loadout_menu.visible and _menu_opened_by_death:
			_close_loadout_menu()


func _on_protection_changed(is_protected: bool) -> void:
	protected_label.visible = is_protected


func _on_player_died(victim: Player, killer_id: int, weapon_name: String, killer_health: int) -> void:
	if victim != _player:
		return
	if killer_id == victim.get_multiplayer_authority():
		death_label.text = "YOU DIED  ·  %s" % weapon_name
	else:
		death_label.text = "KILLED BY %s\n%s  ·  %d HP left" % [
			Net.get_player_name(killer_id), weapon_name, killer_health]
	death_label.visible = true
	if not loadout_menu.visible:
		_open_loadout_menu(true) # GDD: the class menu opens on the death screen.


func _on_match_ended(winner_id: int, awards: Array) -> void:
	winner_label.text = "%s WINS" % Net.get_player_name(winner_id) if winner_id != -1 else "DRAW"
	var lines: Array[String] = []
	for award: Array in awards:
		lines.append("%s:  %s  (%s)" % [award[0], Net.get_player_name(award[1]), award[2]])
	awards_label.text = "\n".join(lines)
	end_panel.visible = true


func _on_match_started() -> void:
	end_panel.visible = false


func _on_weapon_changed(weapon: Weapon) -> void:
	if is_instance_valid(_weapon):
		_weapon.ammo_changed.disconnect(_on_ammo_changed)
		_weapon.reload_changed.disconnect(_on_reload_changed)
	_weapon = weapon
	_weapon.ammo_changed.connect(_on_ammo_changed)
	_weapon.reload_changed.connect(_on_reload_changed)
	weapon_label.text = _weapon.def.display_name
	_refresh_ammo()


func _on_ammo_changed(_ammo: int, _magazine_size: int) -> void:
	_refresh_ammo()


func _on_reload_changed(_is_reloading: bool) -> void:
	_refresh_ammo()


func _refresh_ammo() -> void:
	if not _weapon.def.uses_ammo:
		ammo_label.text = ""
	elif _weapon.is_reloading:
		ammo_label.text = "RELOADING"
	else:
		ammo_label.text = "%d / %d" % [_weapon.ammo, _weapon.def.magazine_size]


func _on_resume_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_leave_pressed() -> void:
	Net.leave()

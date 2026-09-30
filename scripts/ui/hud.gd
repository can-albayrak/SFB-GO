extends CanvasLayer
## In-game HUD for the local player: health, ammo, weapon, crosshair, hit marker,
## match timer, kill feed, Tab scoreboard, spawn protection, death and end-of-match
## screens, and the Esc panel (resume / leave).
## The speed readout is a tuning aid for bunny hop / slide.

var _player: Player
var _weapon: Weapon
var _next_match_at: float = 0.0

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


func _ready() -> void:
	Events.local_player_spawned.connect(_on_local_player_spawned)
	Events.hit_confirmed.connect(crosshair.show_hit)
	Events.player_died.connect(_on_player_died)
	Events.match_ended.connect(_on_match_ended)
	Events.match_started.connect(_on_match_started)
	resume_button.pressed.connect(_on_resume_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	death_label.visible = false
	protected_label.visible = false
	end_panel.visible = false
	scoreboard.visible = false
	pause_panel.visible = false


func _process(_delta: float) -> void:
	_update_top_bar()
	var ended: bool = Match.state == Match.State.ENDED
	scoreboard.visible = ended or Input.is_action_pressed(&"scoreboard")
	if ended:
		next_label.text = "Next match in %d" % ceili(maxf(_next_match_at - _now(), 0.0))
	if not is_instance_valid(_player):
		return
	speed_label.text = "%.1f m/s" % _player.movement.get_horizontal_speed()
	pause_panel.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED


func _update_top_bar() -> void:
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


func _on_match_ended(winner_id: int, awards: Array) -> void:
	_next_match_at = _now() + Match.rules.end_screen_time
	winner_label.text = "%s WINS" % Net.get_player_name(winner_id) if winner_id != -1 else "MATCH OVER"
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
	if _weapon.is_reloading:
		ammo_label.text = "RELOADING"
	else:
		ammo_label.text = "%d / %d" % [_weapon.ammo, _weapon.def.magazine_size]


func _on_resume_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_leave_pressed() -> void:
	Net.leave()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

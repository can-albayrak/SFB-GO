extends CanvasLayer
## In-game HUD for the local player: health, ammo, weapon name, crosshair, hit marker,
## death message and the Esc panel (resume / leave).
## The speed readout is a tuning aid for bunny hop / slide.

var _player: Player
var _weapon: Weapon

@onready var crosshair: Crosshair = $Crosshair
@onready var health_label: Label = $HealthLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var speed_label: Label = $SpeedLabel
@onready var death_label: Label = $DeathLabel
@onready var pause_panel: Control = $PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var leave_button: Button = %LeaveButton


func _ready() -> void:
	Events.local_player_spawned.connect(_on_local_player_spawned)
	Events.hit_confirmed.connect(crosshair.show_hit)
	Events.player_died.connect(_on_player_died)
	resume_button.pressed.connect(_on_resume_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	death_label.visible = false
	pause_panel.visible = false


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	speed_label.text = "%.1f m/s" % _player.movement.get_horizontal_speed()
	pause_panel.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED


func _on_local_player_spawned(player: Player) -> void:
	if is_instance_valid(_player):
		_player.health_changed.disconnect(_on_health_changed)
		_player.weapon_changed.disconnect(_on_weapon_changed)
		_player.alive_changed.disconnect(_on_alive_changed)
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.alive_changed.connect(_on_alive_changed)
	_on_health_changed(player.health, player.class_def.max_health)
	_on_weapon_changed(player.current_weapon)
	_on_alive_changed(player.is_alive)


func _on_health_changed(health: int, _max_health: int) -> void:
	health_label.text = "+ %d" % health


func _on_alive_changed(is_alive: bool) -> void:
	crosshair.visible = is_alive
	if is_alive:
		death_label.visible = false


func _on_player_died(victim: Player, killer_id: int) -> void:
	if victim != _player:
		return
	if killer_id == victim.get_multiplayer_authority():
		death_label.text = "YOU DIED"
	else:
		death_label.text = "KILLED BY %s" % Net.get_player_name(killer_id)
	death_label.visible = true


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

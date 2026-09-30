extends CanvasLayer
## In-game HUD for the local player: health, ammo, weapon name, crosshair, hit marker.
## The speed readout is a stage 1 tuning aid for bunny hop / slide.

var _player: Player
var _weapon: Weapon

@onready var crosshair: Crosshair = $Crosshair
@onready var health_label: Label = $HealthLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var speed_label: Label = $SpeedLabel


func _ready() -> void:
	Events.local_player_spawned.connect(_on_local_player_spawned)
	Events.hit_confirmed.connect(crosshair.show_hit)


func _process(_delta: float) -> void:
	if _player != null:
		speed_label.text = "%.1f m/s" % _player.movement.get_horizontal_speed()


func _on_local_player_spawned(player: Player) -> void:
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	_on_health_changed(player.health, player.class_def.max_health)
	_on_weapon_changed(player.current_weapon)


func _on_health_changed(health: int, _max_health: int) -> void:
	health_label.text = "+ %d" % health


func _on_weapon_changed(weapon: Weapon) -> void:
	if _weapon != null:
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

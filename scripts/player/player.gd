class_name Player
extends CharacterBody3D
## Player root: owns state and wires the components together.
## Multiplayer authority = owning peer: input, movement and weapon handling run there only.
## health / is_alive belong to the host and are replicated by StateSync (authority 1).
## Child components (scene nodes, so their RPC paths match on every peer):
## NetSync (movement replication), Requests (owner -> host requests), Status (shield, stun,
## boost, kill reward), Effects (visuals everyone sees).

signal health_changed(health: int, max_health: int)
signal weapon_changed(weapon: Weapon)
signal alive_changed(is_alive: bool)
signal protection_changed(is_protected: bool)
signal loadout_changed
## Host only. Game registers the kill and schedules the respawn.
signal died(killer_id: int, weapon_name: String, headshot: bool, is_melee: bool)

const MAX_PITCH: float = deg_to_rad(89.0)
const FALL_DEATH_Y: float = -30.0
const SCOPE_FOV_LERP: float = 25.0 ## Per second; how fast the zoom eases in and out.
const INTERP_DELAY: float = 0.1 ## Remote players are drawn this far in the past.
const PROTECTION_BLINK_PERIOD: float = 0.25
const STEP_DISTANCE: float = 2.3 ## Metres between footstep sounds.
const STEP_MIN_SPEED: float = 3.5 ## m/s: slower (walk key, crouch) is silent.
const STEP_TELEPORT_DISTANCE: float = 3.0 ## A jump this big in one frame is a respawn, not a step.
const LAND_SOUND_SPEED: float = 4.0 ## m/s of fall speed before landing makes a thud.
const FALL_WEAPON_NAME: String = "Fall"
# Throws (get_throw_launch): hand offset from the eye as (right, up, forward) metres.
const THROW_HAND_OFFSET: Vector3 = Vector3(0.18, -0.15, 0.4)
const THROW_WALL_MARGIN: float = 0.1
const THROW_AIM_RANGE: float = 80.0
const THROW_MIN_AIM_DISTANCE: float = 2.0 ## Closer than this the throw just follows the view.
const THROW_INHERIT: float = 1.0 ## Share of the thrower's horizontal run speed the throw keeps.
const THROW_WORLD_MASK: int = 1
const THROW_AIM_MASK: int = 1 | 2 # world | player bodies
## Weapon slots: 0 / 1 the loadout's guns, the class's knife (key 3, CS style), then a
## carried airdrop weapon (key 4).
const KNIFE_SLOT: int = 2
const SPECIAL_SLOT: int = 3

# Hitbox poses: x = centre height above feet, y = box height (0 = keep shape).
const HEAD_POSE_STAND: Vector2 = Vector2(1.62, 0.0)
const HEAD_POSE_CROUCH: Vector2 = Vector2(0.98, 0.0)
const BODY_POSE_STAND: Vector2 = Vector2(1.1, 0.75)
const BODY_POSE_CROUCH: Vector2 = Vector2(0.62, 0.45)
const LEG_POSE_STAND: Vector2 = Vector2(0.37, 0.74)
const LEG_POSE_CROUCH: Vector2 = Vector2(0.2, 0.4)

## Replicated by StateSync (host-owned). Changing it rebuilds class, weapons, knife and ability.
var loadout: PackedInt32Array = Loadout.default_code(): set = _set_loadout
var class_def: ClassDef
var health: int = 0: set = _set_health
var is_alive: bool = true: set = _set_alive
## Spawn protection (host-owned, replicated): no damage taken; firing ends it.
var is_protected: bool = false: set = _set_protected
## Host-owned, replicated (late joiners get it too): scope up -> others see the glint.
var scope_glint: bool = false: set = _set_scope_glint
## Host-owned, replicated: Bear's shield panel is up.
var shield_up: bool = false: set = _set_shield_up
## Ghost Cloak (host sets, StateSync replicates): nearly invisible to everyone else.
var cloaked: bool = false: set = _set_cloaked
## Host-owned, replicated: weapon slot in hand, so everyone sees the right model.
var held_slot: int = 0: set = _set_held_slot
## Host-owned, replicated: bit per active pickup boost (1 << PickupDef.Kind); others see a glow.
var powerups: int = 0: set = _set_powerups
## Host-owned, replicated: carried airdrop weapon (index into AirdropWeapons, -1 = none).
var special_weapon: int = -1: set = _set_special_weapon
## Host-owned, replicated: rounds left in it (the host counts airdrop ammo).
var special_ammo: int = 0: set = _set_special_ammo
## Host: host-clock time this player last lost health (cancels opening a crate).
var last_hurt_time: float = -INF
## Vertical look angle in radians. Yaw is the body's own rotation.y.
var look_pitch: float = 0.0
var weapons: Array[Weapon] = []
var current_weapon: Weapon = null
var melee_weapon: MeleeWeapon = null
var ability: Ability = null
var is_local: bool = false
## Owner: right mouse held with a scoped weapon (zoom, slow, sway, no sprint).
var is_scoped: bool = false
## Owner: 0 -> 1 over the gun's scope_in_time while scoped (zoom and accuracy), 0 when not.
var scope_blend: float = 0.0
## Owner: the loadout last sent to the host (drives "Next spawn" on the HUD).
var requested_loadout: PackedInt32Array = PackedInt32Array()
## Host: health removed by the last take_hit (0 when blocked by a shield or not allowed).
var last_damage_dealt: float = 0.0
## Host: the owner's Rocket Launcher laser is on (sent by PlayerRequests.send_guided).
var rocket_guided: bool = true

## Increments on every respawn; stale state packets from a previous life are dropped.
var _life: int = 0
var _pose_crouched: bool = false
var _fall_reported: bool = false
# Host-side state.
var _protected_until: float = 0.0
var _last_hit_weapon: String = ""
var _last_hit_melee: bool = false
var _last_hit_zone: Hitbox.Zone = Hitbox.Zone.BODY
var _pending_loadout: PackedInt32Array = PackedInt32Array()
## Host: took damage this life (a loadout swap then never refills health).
var _hurt_since_spawn: bool = false
var _cloak_until: float = 0.0 ## Host clock.
var _spawned_at: float = 0.0
## Owner only: FOV shift, head bob, landing dip, slide tilt, damage shake (visual only).
var _camera_feel: CameraFeel
## Animated third-person body under Model (every peer; hidden on your own screen).
var rig: SoldierRig
var _step_distance: float = 0.0 ## Metres walked on the ground since the last footstep sound.
var _last_step_position: Vector3 = Vector3.ZERO
var _was_grounded: bool = true ## Remote players: on the ground last frame (landing sound).
var _air_fall_speed: float = 0.0 ## Remote players: fastest fall since leaving the ground.

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Camera3D
@onready var weapon_holder: Node3D = $Camera3D/WeaponHolder
@onready var head_hitbox: Hitbox = $Hitboxes/HeadHitbox
@onready var body_hitbox: Hitbox = $Hitboxes/BodyHitbox
@onready var leg_hitbox: Hitbox = $Hitboxes/LegHitbox
@onready var model: Node3D = $Model
@onready var crown: Node3D = $Model/Crown
@onready var hand: Node3D = $Model/Hand
@onready var remote_muzzle: Marker3D = $Model/Hand/Muzzle
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var movement: Movement = $Movement
@onready var player_input: PlayerInput = $PlayerInput
@onready var net_sync: PlayerNetSync = $NetSync
@onready var requests: PlayerRequests = $Requests
@onready var status: PlayerStatus = $Status
@onready var effects: PlayerEffects = $Effects


## Called by the spawner before the node enters the tree, on every peer.
func setup_authority(peer_id: int) -> void:
	set_multiplayer_authority(peer_id)
	$StateSync.set_multiplayer_authority(1)


func _ready() -> void:
	is_local = is_multiplayer_authority()
	crown.visible = false
	rig = SoldierRig.create()
	model.add_child(rig)
	model.move_child(rig, 0)
	rig.setup(self)
	effects.setup()
	effects.show_glint(scope_glint)
	effects.show_shield(shield_up)
	effects.show_powerups(powerups)
	_apply_loadout()
	if multiplayer.is_server():
		health = class_def.max_health # Clients already got the real value from StateSync's spawn state.
		_spawned_at = _now()
		_grant_protection()

	if is_local:
		# Camera is top-level and placed every frame, so mouse look never waits for a physics tick.
		camera.top_level = true
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera.fov = Settings.get_vertical_fov()
		camera.current = true
		_camera_feel = CameraFeel.new()
		movement.landed.connect(_camera_feel.on_landed)
		movement.landed.connect(func(fall_speed: float) -> void:
			if fall_speed >= LAND_SOUND_SPEED:
				Sfx.land(get_parent(), global_position))
		# Your own body in view: legs on the body, arms with the view model (visual only).
		add_child(FirstPersonLegs.create(self))
		weapon_holder.add_child(FirstPersonArms.create(self))
		Events.local_player_spawned.emit(self)
	else:
		# Remote players are placed in _process from snapshots.
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_apply_alive_state()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		if is_protected and _now() >= _protected_until:
			is_protected = false
		if cloaked and (_now() >= _cloak_until or not is_alive):
			cloaked = false
		status.server_tick()
	if not is_local or not is_alive:
		is_scoped = false
		scope_blend = 0.0
		if is_local:
			effects.report_scoped(false) # Re-sends on the next scope after a respawn.
		return
	var cmd: PlayerCommand = player_input.gather()
	var stunned: bool = status.is_stunned_local()
	status.tick_local(delta)
	if stunned:
		cmd = PlayerCommand.new() # Stunned: no moving, firing or abilities.
	if cmd.weapon_slot >= 0:
		equip(cmd.weapon_slot)

	var weapon_def: WeaponDef = current_weapon.def
	var was_scoped: bool = is_scoped
	is_scoped = cmd.secondary and weapon_def.scope_zoom > 0.0 and not current_weapon.is_reloading and not movement.is_sliding
	if is_scoped and not was_scoped:
		Sfx.play_ui(self, Sfx.SCOPE_IN)
	weapon_holder.visible = not is_scoped
	if is_scoped:
		cmd.sprint = false
		var scope_rate: float = 1.0 / weapon_def.scope_in_time if weapon_def.scope_in_time > 0.0 else INF
		scope_blend = minf(scope_blend + delta * scope_rate, 1.0)
	else:
		scope_blend = 0.0
	effects.report_scoped(is_scoped) # Others see the glint.
	var scope_mult: float = weapon_def.scope_move_mult if is_scoped else 1.0
	# GDD: carrying an airdrop weapon slows you down, in hand or not.
	var carry_mult: float = weapons[SPECIAL_SLOT].def.carry_speed_mult if weapons.size() > SPECIAL_SLOT else 1.0
	movement.base_speed = class_def.move_speed * weapon_def.move_speed_mult * status.get_speed_mult() * scope_mult * carry_mult
	movement.air_jumps = 1 if status.has_double_jump() else 0
	movement.look_pitch = look_pitch
	movement.physics_step(delta, cmd)

	if melee_weapon != null:
		melee_weapon.tick_melee(delta)
		if cmd.melee and not current_weapon.is_busy() and melee_weapon.swing():
			requests.send_melee(get_aim_origin(), -get_aim_basis().z)
	var swinging: bool = melee_weapon != null and melee_weapon.is_swinging()
	current_weapon.visible = not swinging
	# While the knife is out the gun keeps its timers but cannot fire.
	current_weapon.tick(delta, PlayerCommand.new() if swinging else cmd)

	if ability != null:
		ability.tick(delta)
		if cmd.ability and ability.try_use(get_aim_origin(), -get_aim_basis().z):
			requests.send_ability(get_aim_origin(), -get_aim_basis().z)
			if ability is GrenadeAbility:
				effects.report_action(SoldierRig.Action.THROW, 0.0) # Others see the throw.
	var airdrops: AirdropManager = AirdropManager.find(get_tree())
	if airdrops != null:
		airdrops.tick_local(self, cmd.interact)
	apply_pose(movement.is_crouched)
	net_sync.tick_send()

	if global_position.y < FALL_DEATH_Y and not _fall_reported:
		_fall_reported = true
		requests.send_fall_death()


func _process(delta: float) -> void:
	if is_local:
		_camera_feel.update(delta, movement, is_scoped)
		var eye: Vector3 = head.get_global_transform_interpolated().origin
		eye += Vector3.UP * _camera_feel.vertical + global_basis.x * _camera_feel.lateral
		var recoil: Vector2 = current_weapon.get_view_recoil()
		var punch := Vector2(0.0, _camera_feel.kick * CameraFeel.DEF.kick_view_share)
		var view: Basis = _look_basis(recoil * CameraFeel.DEF.recoil_view_share + _get_scope_sway() + _camera_feel.shake + punch)
		camera.global_transform = Transform3D(view * Basis(Vector3.BACK, _camera_feel.roll), eye)
		_kick_view_model(recoil * (1.0 - CameraFeel.DEF.recoil_view_share))
		camera.fov = lerpf(camera.fov, _get_target_fov(), minf(SCOPE_FOV_LERP * delta, 1.0))
	else:
		net_sync.interpolate(delta)
		if is_alive and is_protected:
			model.visible = fmod(Time.get_ticks_msec() / 1000.0, PROTECTION_BLINK_PERIOD) < PROTECTION_BLINK_PERIOD * 0.6
	_update_footsteps()


## Footstep sounds on every peer: one every STEP_DISTANCE metres while moving on the ground
## faster than a careful walk (crouch-walking and slow walking stay silent, like CS).
func _update_footsteps() -> void:
	var moved: Vector3 = global_position - _last_step_position
	_last_step_position = global_position
	var velocity_now: Vector3 = get_move_velocity()
	var grounded: bool = is_on_floor() if is_local else rig.grounded
	if not is_local:
		# Others hear remote players land too (the owner's own landing comes from Movement.landed).
		if grounded and not _was_grounded and _air_fall_speed >= LAND_SOUND_SPEED and is_alive:
			Sfx.land(get_parent(), global_position)
		_air_fall_speed = 0.0 if grounded else maxf(_air_fall_speed, -velocity_now.y)
		_was_grounded = grounded
	var horizontal_speed: float = Vector2(velocity_now.x, velocity_now.z).length()
	if not is_alive or not grounded or horizontal_speed < STEP_MIN_SPEED or moved.length() > STEP_TELEPORT_DISTANCE:
		_step_distance = 0.0
		return
	if (is_local and movement.is_sliding) or (class_def != null and class_def.silent_steps):
		return
	_step_distance += Vector2(moved.x, moved.z).length()
	if _step_distance >= STEP_DISTANCE:
		_step_distance = 0.0
		Sfx.step(get_parent(), global_position)


## Owner: the recoil the view does not follow tips the gun in view up and back instead.
func _kick_view_model(recoil: Vector2) -> void:
	var feel: CameraFeelDef = CameraFeel.DEF
	var kick: float = _camera_feel.kick
	var back: float = minf(recoil.length() * feel.recoil_model_back, feel.recoil_model_max_back) + kick * feel.kick_back
	var roll: float = deg_to_rad(kick * feel.kick_roll * _camera_feel.kick_roll_sign)
	var tip := Basis.from_euler(Vector3(deg_to_rad(recoil.y * feel.recoil_model_pitch + kick), -deg_to_rad(recoil.x * feel.recoil_model_pitch), roll))
	weapon_holder.transform = Transform3D(tip, Vector3(0.0, 0.0, back))


func equip(slot: int) -> void:
	if slot < 0 or slot >= weapons.size() or weapons[slot] == current_weapon:
		return
	if current_weapon != null:
		current_weapon.holster()
	current_weapon = weapons[slot]
	current_weapon.draw()
	weapon_changed.emit(current_weapon)
	if is_local and requests != null:
		requests.send_equip(slot) # Others see the weapon in hand.


## Eye position at the current physics tick (not interpolated). Shots start here.
func get_aim_origin() -> Vector3:
	return head.global_position


## Look direction including weapon recoil.
func get_aim_basis() -> Basis:
	return _look_basis(current_weapon.recoil_offset + _get_scope_sway())


## View direction without recoil (host uses it for flashbangs).
func get_look_forward() -> Vector3:
	return -_look_basis(Vector2.ZERO).z


## Flat direction the body faces (knife backstabs; on the host this is the rewound yaw).
func get_facing() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))


## Zoom factor of the active scope (1 when not scoped, rising while it comes up).
## Mouse sensitivity is divided by it.
func get_zoom() -> float:
	if not is_scoped or current_weapon == null:
		return 1.0
	var eased: float = scope_blend * scope_blend * (3.0 - 2.0 * scope_blend)
	return lerpf(1.0, current_weapon.def.scope_zoom, eased)


## Host: start point and velocity of a throw (grenades, sticky bombs, throwing knives).
## It leaves the right hand (not the middle of the screen), flies through the crosshair point
## from there, and carries the thrower's own run speed.
## Returns [spawn: Vector3, velocity: Vector3].
func get_throw_launch(origin: Vector3, dir: Vector3, speed: float, lift: float) -> Array:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var right: Vector3 = dir.cross(Vector3.UP).normalized() if absf(dir.y) < 0.99 else global_basis.x
	var up: Vector3 = right.cross(dir).normalized()
	var spawn: Vector3 = origin + dir * THROW_HAND_OFFSET.z + right * THROW_HAND_OFFSET.x + up * THROW_HAND_OFFSET.y
	# Never spawn on the far side of a thin wall the thrower is hugging.
	var wall: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, spawn, THROW_WORLD_MASK))
	if not wall.is_empty():
		spawn = (wall["position"] as Vector3) - (spawn - origin).normalized() * THROW_WALL_MARGIN
	# Aim at what the crosshair is on, so a flat throw lands where you look.
	var aim_query := PhysicsRayQueryParameters3D.create(origin, origin + dir * THROW_AIM_RANGE, THROW_AIM_MASK, get_hit_exclusions())
	var aim_hit: Dictionary = space.intersect_ray(aim_query)
	var target: Vector3 = aim_hit["position"] if not aim_hit.is_empty() else origin + dir * THROW_AIM_RANGE
	var throw_dir: Vector3 = (target - spawn).normalized() if spawn.distance_to(target) > THROW_MIN_AIM_DISTANCE else dir
	var carried: Vector3 = get_move_velocity()
	carried.y = 0.0
	return [spawn, throw_dir * speed + Vector3.UP * lift + carried * THROW_INHERIT]


## Current movement velocity: simulated for our own player, estimated from snapshots otherwise.
func get_move_velocity() -> Vector3:
	return velocity if is_local else net_sync.get_latest_velocity()


## Own body and hitboxes, so our rays never hit ourselves.
func get_hit_exclusions() -> Array[RID]:
	return [get_rid(), head_hitbox.get_rid(), body_hitbox.get_rid(), leg_hitbox.get_rid()]


## Owning client: asks the host to resolve a shot (weapons call this).
func send_fire(origin: Vector3, dir: Vector3, slot: int) -> void:
	requests.send_fire(origin, dir, slot)
	if _camera_feel != null and slot >= 0 and slot < weapons.size() and weapons[slot].def.view_kick > 0.0:
		_camera_feel.add_kick(weapons[slot].def.view_kick)


## Owner: choose a loadout. The host applies it now (first seconds after spawning)
## or at the next spawn (GDD). Also remembered for the next session.
func request_loadout(code: PackedInt32Array) -> void:
	if not Loadout.is_valid(code):
		return
	requested_loadout = code
	Loadout.save_to_settings(code)
	requests.send_loadout(code)


## Host only: false while spawn-protected, dead or between matches (no hit marker then).
func can_take_damage() -> bool:
	return is_alive and not is_protected and Match.state == Match.State.PLAYING


## Host only. Returns true if this hit killed. `bypass_shield`: damage from under the feet
## (landmine) that a raised shield cannot stop.
func take_hit(amount: float, zone: Hitbox.Zone, attacker_id: int, weapon_name: String, is_melee: bool = false,
		bypass_shield: bool = false) -> bool:
	assert(multiplayer.is_server(), "take_hit is host-only")
	last_damage_dealt = 0.0
	if not can_take_damage() or (not bypass_shield and status.shield_blocks(attacker_id)):
		return false
	_last_hit_weapon = weapon_name
	_last_hit_melee = is_melee
	_last_hit_zone = zone
	var before: int = health
	health = maxi(health - roundi(amount), 0)
	last_damage_dealt = before - health
	if health < before:
		server_break_cloak() # Getting hit shows a Ghost.
		_hurt_since_spawn = true
		last_hurt_time = _now()
		var attacker := get_parent().get_node_or_null(str(attacker_id)) as Player
		var from_other: bool = attacker != null and attacker != self
		_on_hurt.rpc_id(get_multiplayer_authority(), before - health, from_other,
			attacker.global_position if from_other else Vector3.ZERO)
	if health > 0:
		return false
	_die(attacker_id)
	return true


## Host only (Ghost Cloak): nearly invisible for `seconds`, until firing or being hit.
func server_cloak(seconds: float) -> void:
	assert(multiplayer.is_server(), "server_cloak is host-only")
	_cloak_until = _now() + seconds
	cloaked = true


## Host only: firing, stabbing or taking damage ends a cloak at once.
func server_break_cloak() -> void:
	if cloaked:
		cloaked = false


## Host only (Trickster Swap Dart, Phantom Recall): moves a living player on every peer.
## Same path as a respawn: a new life number, so the host's speed check takes the jump and
## older movement packets from before it are ignored.
func server_teleport(target: Vector3) -> void:
	assert(multiplayer.is_server(), "server_teleport is host-only")
	if not is_alive:
		return
	_life += 1
	net_sync.reset_validation()
	var compensator: LagCompensator = LagCompensator.find(get_tree())
	if compensator != null:
		compensator.forget(self) # No rewinding a shot across the jump.
	Net.broadcast(self, &"_teleport_to", [target, _life])
	Net.broadcast(effects, &"_show_teleport", [target])


## Host only. Restores health and moves the player on every peer.
func server_respawn(spawn_position: Vector3, yaw: float) -> void:
	assert(multiplayer.is_server(), "server_respawn is host-only")
	_life += 1
	net_sync.reset_validation()
	special_weapon = -1 # Only a match restart respawns a carrier; a death already dropped it.
	var compensator: LagCompensator = LagCompensator.find(get_tree())
	if compensator != null:
		compensator.forget(self) # No rewinding into the previous life.
	if not _pending_loadout.is_empty():
		loadout = _pending_loadout
		_pending_loadout = PackedInt32Array()
	_spawned_at = _now()
	_hurt_since_spawn = false
	status.reset_host()
	health = class_def.max_health
	is_alive = true
	_grant_protection()
	Net.broadcast(self, &"_respawn_at", [spawn_position, yaw, _life])


## Host: hands this player an airdrop weapon with `ammo` rounds (crate or dropped gun).
func give_special_weapon(index: int, ammo: int) -> void:
	assert(multiplayer.is_server(), "give_special_weapon is host-only")
	special_ammo = ammo # First, so the new gun is built with it.
	special_weapon = index


## Host: one airdrop round fired; the gun is gone when empty (Test Range: endless).
func server_use_special_round() -> void:
	assert(multiplayer.is_server(), "server_use_special_round is host-only")
	if Match.rules.infinite_ammo:
		return
	special_ammo -= 1
	if special_ammo <= 0:
		special_weapon = -1


## Host: a validated loadout request. Within the first seconds after spawning it switches at
## once (GDD), otherwise it waits for the next spawn. Test Range: always at once.
func server_choose_loadout(code: PackedInt32Array) -> void:
	assert(multiplayer.is_server(), "server_choose_loadout is host-only")
	var in_window: bool = _now() - _spawned_at <= Match.rules.loadout_swap_window or Match.rules.loadout_swap_anytime
	if is_alive and in_window and Match.state == Match.State.PLAYING:
		# Only a player unhurt this life gets the new class's full health (no heal-by-swapping,
		# also not by passing through a class whose maximum is the current health).
		_pending_loadout = PackedInt32Array()
		loadout = code
		health = class_def.max_health if not _hurt_since_spawn else mini(health, class_def.max_health)
	else:
		_pending_loadout = code


## Host: fell off the map (counts as a self-kill).
func server_fall_death() -> void:
	assert(multiplayer.is_server(), "server_fall_death is host-only")
	_last_hit_weapon = FALL_WEAPON_NAME
	_last_hit_melee = false
	_last_hit_zone = Hitbox.Zone.BODY
	health = 0
	_die(get_multiplayer_authority())


## Respawn counter, used to discard stale respawn timers and state packets.
func get_life() -> int:
	return _life


## A newer life seen in a state packet (remote peers).
func adopt_life(life: int) -> void:
	_life = maxi(_life, life)


func is_pose_crouched() -> bool:
	return _pose_crouched


## Host lag compensation: moves the body and hitboxes and pushes the hitbox
## transforms to the physics server at once (transform notifications are deferred).
func set_hit_pose(pos: Vector3, yaw: float, crouched: bool) -> void:
	global_position = pos
	rotation.y = yaw
	apply_pose(crouched)
	for hitbox: Hitbox in [head_hitbox, body_hitbox, leg_hitbox]:
		PhysicsServer3D.area_set_transform(hitbox.get_rid(), hitbox.global_transform)


## Every peer: crown over the current leader (never drawn on yourself).
func set_leader(is_leader: bool) -> void:
	crown.visible = is_leader


## Crouched or standing hitboxes, model squash and (remote) capsule.
func apply_pose(crouched: bool) -> void:
	if crouched == _pose_crouched:
		return
	_pose_crouched = crouched
	head_hitbox.set_pose(HEAD_POSE_CROUCH if crouched else HEAD_POSE_STAND)
	body_hitbox.set_pose(BODY_POSE_CROUCH if crouched else BODY_POSE_STAND)
	leg_hitbox.set_pose(LEG_POSE_CROUCH if crouched else LEG_POSE_STAND)
	model.scale.y = SoldierRig.CROUCH_SCALE if crouched else 1.0
	if not is_local:
		movement.set_crouch_shape(crouched)
		head.position.y = Movement.CROUCH_EYE if crouched else Movement.STAND_EYE


func _grant_protection() -> void:
	_protected_until = _now() + Match.rules.spawn_protection
	is_protected = true


func _die(killer_id: int) -> void:
	is_alive = false
	is_protected = false
	scope_glint = false
	status.reset_host()
	if special_weapon >= 0:
		# GDD: the airdrop weapon falls where its carrier died, with the rounds left.
		var airdrops: AirdropManager = AirdropManager.find(get_tree())
		if airdrops != null:
			airdrops.server_drop_weapon(special_weapon, special_ammo, global_position)
		special_weapon = -1
	var killer_health: int = 0
	var killer := get_parent().get_node_or_null(str(killer_id)) as Player
	if killer != null:
		killer_health = killer.health
	var headshot: bool = _last_hit_zone == Hitbox.Zone.HEAD and killer_id != get_multiplayer_authority()
	Net.broadcast(self, &"_announce_death", [killer_id, _last_hit_weapon, killer_health])
	died.emit(killer_id, _last_hit_weapon, headshot, _last_hit_melee)


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


func _look_basis(recoil: Vector2) -> Basis:
	var pitch: float = clampf(look_pitch + deg_to_rad(recoil.y), -MAX_PITCH, MAX_PITCH)
	return Basis.from_euler(Vector3(pitch, rotation.y - deg_to_rad(recoil.x), 0.0))


## Degrees of scope sway (x = right, y = up); zero when not scoped.
func _get_scope_sway() -> Vector2:
	if not is_scoped:
		return Vector2.ZERO
	var t: float = Time.get_ticks_msec() / 1000.0
	var amplitude: float = current_weapon.def.scope_sway * (0.5 if movement.is_crouched else 1.0)
	return Vector2(sin(t * 1.1) + 0.5 * sin(t * 2.3), cos(t * 0.9) + 0.5 * cos(t * 1.9)) * amplitude


func _get_target_fov() -> float:
	if not is_scoped:
		return Settings.get_vertical_fov(_camera_feel.fov_extra if _camera_feel != null else 0.0)
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(Settings.get_vertical_fov()) * 0.5) / get_zoom()))


## Rebuilds class stats, weapons, knife and ability from `loadout`. Every peer runs this,
## so the host (damage), the owner (handling) and viewers agree.
func _apply_loadout() -> void:
	class_def = Loadout.get_class_def(loadout)
	status.clear_buffs() # A boost belongs to the class that used it.
	movement.def = class_def.movement

	for weapon: Weapon in weapons:
		weapon_holder.remove_child(weapon)
		weapon.queue_free()
	weapons.clear()
	current_weapon = null
	for def: WeaponDef in [Loadout.get_primary(loadout), class_def.secondary_weapon, class_def.knife]:
		weapons.append(_add_weapon(def))

	if melee_weapon != null:
		melee_weapon.queue_free()
		melee_weapon = null
	if class_def.quick_melee != null:
		melee_weapon = _add_weapon(class_def.quick_melee) as MeleeWeapon

	# The cooldown belongs to the player, not the ability: swapping must not reset it.
	var carried_cooldown: float = 0.0
	var carried_host_ready: float = -INF
	if ability != null:
		carried_cooldown = ability.cooldown_left
		carried_host_ready = ability.host_ready_at
		ability.queue_free()
		ability = null
	var ability_def: AbilityDef = Loadout.get_ability(loadout)
	if ability_def != null:
		ability = ability_def.scene.instantiate()
		ability.setup(ability_def, self)
		ability.cooldown_left = carried_cooldown
		ability.host_ready_at = carried_host_ready
		add_child(ability)

	equip(0)
	if multiplayer.is_server():
		held_slot = 0
	_apply_special(false) # A carried airdrop weapon survives a loadout swap.
	effects.show_held_weapon(held_slot)
	loadout_changed.emit()


## Adds or removes the airdrop weapon in SPECIAL_SLOT to match `special_weapon` (every peer).
## `take_in_hand`: the owner switches to a newly gained one at once.
func _apply_special(take_in_hand: bool) -> void:
	if weapons.size() > SPECIAL_SLOT:
		var old: Weapon = weapons.pop_back()
		if current_weapon == old:
			current_weapon = null
		weapon_holder.remove_child(old)
		old.queue_free()
	var def: WeaponDef = AirdropWeapons.get_def(special_weapon)
	if def != null:
		var weapon: Weapon = _add_weapon(def)
		weapon.ammo = special_ammo
		weapons.append(weapon)
		if is_local and take_in_hand:
			equip(SPECIAL_SLOT)
	if current_weapon == null:
		equip(0)
	if multiplayer.is_server() and held_slot >= weapons.size():
		held_slot = 0
	effects.show_carrier(def.display_name if def != null else "")


func _add_weapon(def: WeaponDef) -> Weapon:
	var weapon: Weapon = def.scene.instantiate()
	weapon.setup(def, self)
	weapon.visible = false
	weapon.scale = Vector3.ONE * CameraFeel.DEF.view_model_scale # Grips and muzzle scale with it.
	weapon_holder.add_child(weapon)
	return weapon


func _set_loadout(value: PackedInt32Array) -> void:
	if not Loadout.is_valid(value) or value == loadout and class_def != null:
		return
	loadout = value
	if is_node_ready():
		_apply_loadout()


func _apply_alive_state() -> void:
	collision.set_deferred(&"disabled", not is_alive)
	for hitbox: Hitbox in [head_hitbox, body_hitbox, leg_hitbox]:
		hitbox.set_enabled(is_alive)
	model.visible = is_alive and not is_local
	weapon_holder.visible = is_alive and is_local
	effects.show_glint(scope_glint)


func _set_health(value: int) -> void:
	health = value
	# StateSync can deliver health before _ready has built the class.
	health_changed.emit(health, class_def.max_health if class_def != null else health)


func _set_alive(value: bool) -> void:
	var was_alive: bool = is_alive
	is_alive = value
	if is_node_ready():
		if not value:
			status.reset_local()
			if was_alive and not is_local: # Others see the body fall; your own view stays clean.
				get_parent().add_child(Corpse.create(model))
		else:
			rig.reset_motion()
		_apply_alive_state()
	alive_changed.emit(value)


func _set_scope_glint(value: bool) -> void:
	scope_glint = value
	if is_node_ready():
		effects.show_glint(value)


func _set_cloaked(value: bool) -> void:
	cloaked = value
	if is_node_ready():
		effects.show_cloak(value)


func _set_shield_up(value: bool) -> void:
	shield_up = value
	if is_node_ready():
		effects.show_shield(value)


func _set_special_weapon(value: int) -> void:
	if value == special_weapon and class_def != null:
		return
	special_weapon = value
	if is_node_ready():
		_apply_special(true)
		effects.show_held_weapon(held_slot)


func _set_special_ammo(value: int) -> void:
	special_ammo = value
	if weapons.size() > SPECIAL_SLOT:
		var weapon: Weapon = weapons[SPECIAL_SLOT]
		# The owner counts ahead of the host (shots in flight): never push its count back up.
		weapon.ammo = mini(weapon.ammo, value) if is_local else value
		weapon.ammo_changed.emit(weapon.ammo, weapon.def.magazine_size)


func _set_powerups(value: int) -> void:
	powerups = value
	if is_node_ready():
		effects.show_powerups(value)


func _set_held_slot(value: int) -> void:
	held_slot = value
	if is_node_ready():
		effects.show_held_weapon(value)


func _set_protected(value: bool) -> void:
	is_protected = value
	if is_node_ready() and not value:
		_apply_alive_state() # Stop blinking with the model shown.
	protection_changed.emit(value)


func _sender_is_host() -> bool:
	var sender: int = multiplayer.get_remote_sender_id()
	return (sender if sender != 0 else multiplayer.get_unique_id()) == 1


# --- Host -> peer events -----------------------------------------------------

## Host -> victim: blind for `seconds` (flashbang).
@rpc("any_peer", "call_local", "reliable")
func flash(seconds: float) -> void:
	if not _sender_is_host() or not is_local:
		return
	Events.local_flashed.emit(seconds)


## Host -> victim's owner: damage taken. Drives the camera shake (visual only, aim unchanged)
## and, when another player did it, the hit direction indicator toward `source`.
@rpc("any_peer", "call_local", "unreliable")
func _on_hurt(amount: int, from_other: bool, source: Vector3) -> void:
	if not _sender_is_host() or not is_local or _camera_feel == null:
		return
	_camera_feel.add_shake(amount)
	if from_other:
		Events.local_hurt_from.emit(source)


## Host -> shooter only: a hit landed. Hit marker + damage number at `point` (shooter's screen only).
@rpc("any_peer", "call_local", "reliable")
func confirm_hit(zone: Hitbox.Zone, killed: bool, amount: float, point: Vector3) -> void:
	if not _sender_is_host():
		return
	Events.hit_confirmed.emit(zone, killed, amount)
	DamageNumber.spawn(get_parent(), point, amount, zone)


@rpc("any_peer", "call_local", "reliable")
func _announce_death(killer_id: int, weapon_name: String, killer_health: int) -> void:
	if not _sender_is_host():
		return
	Events.player_died.emit(self, killer_id, weapon_name, killer_health)


@rpc("any_peer", "call_local", "reliable")
func _teleport_to(target: Vector3, life: int) -> void:
	if not _sender_is_host():
		return
	adopt_life(life)
	global_position = target
	net_sync.clear_snapshots()
	if is_local:
		velocity = Vector3.ZERO
		movement.reset()
	reset_physics_interpolation()
	if rig != null:
		rig.reset_motion()


@rpc("any_peer", "call_local", "reliable")
func _respawn_at(spawn_position: Vector3, yaw: float, life: int) -> void:
	if not _sender_is_host():
		return
	adopt_life(life)
	global_position = spawn_position
	rotation.y = yaw
	net_sync.clear_snapshots()
	if is_local:
		velocity = Vector3.ZERO
		look_pitch = 0.0
		movement.reset()
		_fall_reported = false
		status.reset_local()
		for weapon: Weapon in weapons:
			weapon.refill()
	apply_pose(false)
	reset_physics_interpolation()

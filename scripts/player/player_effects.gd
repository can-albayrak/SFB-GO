class_name PlayerEffects
extends Node
## Visuals of one Player that everyone sees: Bear's shield panel and Hawk's scope glint
## (both driven by replicated Player state, so late joiners see them too), grapple rope,
## decoy copy and remote tracers (host broadcasts). Never affects gameplay.
## Child node "Effects" of the player scene, so its RPC path is the same everywhere.

const SHIELD_SIZE: Vector3 = Vector3(1.3, 1.7, 0.06)
const SHIELD_OFFSET: Vector3 = Vector3(0.0, 1.0, -0.8)
const SHIELD_COLOR: Color = Color(0.35, 0.8, 1.0, 0.4)
## Scope glint (GDD Hawk): shown to others while scoped, same screen size at any distance.
const GLINT_OFFSET: Vector3 = Vector3(0.15, 1.5, -0.45)
const GLINT_SIZE: float = 0.04
## Name over every other player's head; an airdrop carrier's shows through walls (GDD).
const NAME_HEIGHT: float = 2.05
const NAME_PIXEL_SIZE: float = 0.0008
const NAME_FONT_SIZE: int = 18
const NAME_SIGHT_INTERVAL: float = 0.1 ## Seconds between line-of-sight checks for a nick.
const NAME_SIGHT_POINTS: Array[float] = [1.6, 1.1, 0.4] ## Heights checked: head, chest, legs.
const SIGHT_MASK: int = 1 ## World only.
const NAME_COLOR: Color = Color(0.92, 0.94, 0.96)
const CARRIER_COLOR: Color = Color(1.0, 0.45, 0.35)
## Pickup glow (GDD: a player under a boost glows in its colour).
const POWERUP_LIGHT_ENERGY: float = 2.5
const POWERUP_LIGHT_RANGE: float = 2.8
const POWERUP_DEFS: Array[PickupDef] = [preload("res://data/pickups/speed.tres"), preload("res://data/pickups/double_jump.tres")]
const GLINT_COLOR: Color = Color(0.6, 0.57, 0.48) ## Additive: lower = dimmer.

var _shield_visual: MeshInstance3D
var _glint: MeshInstance3D
var _sent_scoped: bool = false ## Owner: scope state last told to the host.
var _held_model: Node3D
var _powerup_light: OmniLight3D
var _name_label: Label3D
var _carrying: bool = false
var _held_length: float = 0.0 ## Length of the world model in hand (0 = none).

@onready var player: Player = get_parent()


## Player._ready: builds the shield panel and the glint (children must not be added to the
## player while it is still readying its own children, so this is not done in our _ready).
func setup() -> void:
	_build_shield_visual()
	_build_glint()
	_powerup_light = OmniLight3D.new()
	_powerup_light.light_energy = POWERUP_LIGHT_ENERGY
	_powerup_light.omni_range = POWERUP_LIGHT_RANGE
	_powerup_light.position.y = 1.1
	_powerup_light.visible = false
	player.model.add_child(_powerup_light) # Hidden with the body (dead, own view).
	_name_label = Label3D.new()
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.fixed_size = true
	_name_label.pixel_size = NAME_PIXEL_SIZE
	_name_label.font_size = NAME_FONT_SIZE
	_name_label.outline_size = 4
	_name_label.position.y = NAME_HEIGHT
	player.model.add_child(_name_label) # Hidden with the body (dead, own view).
	Net.players_changed.connect(_refresh_name)
	_refresh_name()


## Owner, every tick: tells the host when the scope goes up or down (others see the glint).
func report_scoped(scoped: bool) -> void:
	if scoped == _sent_scoped:
		return
	_sent_scoped = scoped
	_request_scope.rpc_id(1, scoped)


## Player.scope_glint changed (every peer). Never on your own view or a dead body.
func show_glint(scoped: bool) -> void:
	if _glint != null:
		_glint.visible = scoped and not player.is_local and player.is_alive


## Player.shield_up changed (every peer). The owner looks through their own shield.
func show_shield(active: bool) -> void:
	if _shield_visual != null:
		_shield_visual.visible = active and not player.is_local


## Player.special_weapon changed (every peer): a carrier's name shows through walls.
func show_carrier(weapon_name: String) -> void:
	_carrying = not weapon_name.is_empty()
	_refresh_name()


func _refresh_name() -> void:
	if _name_label == null:
		return
	_name_label.text = Net.player_names.get(player.get_multiplayer_authority(), "")
	_name_label.no_depth_test = _carrying # GDD: an airdrop carrier is visible to everyone, walls or not.
	_name_label.modulate = CARRIER_COLOR if _carrying else NAME_COLOR


## Length of the weapon model in hand (SoldierRig: how the hands hold it). 0 = none.
func get_held_length() -> float:
	return _held_length


## Player.powerups changed (every peer): glow in the colour of an active boost.
func show_powerups(mask: int) -> void:
	if _powerup_light == null:
		return
	_powerup_light.visible = false
	for def: PickupDef in POWERUP_DEFS:
		if mask & (1 << def.kind):
			_powerup_light.light_color = def.color
			_powerup_light.visible = true


## Player.held_slot or the loadout changed (every peer): the world model in the body's hand.
## Hidden on the owner with the rest of the body.
func show_held_weapon(slot: int) -> void:
	_held_length = 0.0
	if _held_model != null:
		_held_model.queue_free()
		_held_model = null
	if slot < 0 or slot >= player.weapons.size():
		return
	var def: WeaponDef = player.weapons[slot].def
	if def.world_model == null:
		return
	_held_model = def.world_model.instantiate() as Node3D
	_held_model.scale = Vector3.ONE * def.world_model_scale
	player.hand.add_child(_held_model)
	_held_length = _model_length(_held_model) * def.world_model_scale
	player.remote_muzzle.position = def.world_muzzle * def.world_model_scale


## Host: other peers draw this player's tracer (`beam`: a railgun beam instead).
func server_show_shot(origin: Vector3, end_point: Vector3, beam: bool = false) -> void:
	assert(multiplayer.is_server(), "server_show_shot is host-only")
	Net.broadcast(self, &"_show_shot", [origin, end_point, beam])


## Host: other peers draw one tracer per shotgun pellet.
func server_show_pellets(ends: PackedVector3Array) -> void:
	assert(multiplayer.is_server(), "server_show_pellets is host-only")
	Net.broadcast(self, &"_on_pellets_fired", [ends])


## Host: everyone sees the rope of a Hawk grapple.
func show_grapple(point: Vector3, seconds: float) -> void:
	assert(multiplayer.is_server(), "show_grapple is host-only")
	Net.broadcast(self, &"_show_grapple", [point, seconds])


## Host: everyone sees a copy of this player where they stand now, carrying their momentum.
func show_decoy(seconds: float) -> void:
	assert(multiplayer.is_server(), "show_decoy is host-only")
	Net.broadcast(self, &"_show_decoy", [player.global_position, player.rotation.y, seconds, player.get_move_velocity()])


## Bright dot on the remote body's scope; a fixed-size billboard, so it reads at any distance
## (walls still hide it).
func _build_glint() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(GLINT_SIZE, GLINT_SIZE)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.fixed_size = true
	material.albedo_color = GLINT_COLOR
	material.albedo_texture = ShotEffects.get_glow_texture()
	quad.material = material
	_glint = MeshInstance3D.new()
	_glint.name = "Glint"
	_glint.mesh = quad
	_glint.position = GLINT_OFFSET
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glint.visible = false
	player.model.add_child(_glint) # Hidden with the body (dead, own view).


func _build_shield_visual() -> void:
	_shield_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SHIELD_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = SHIELD_COLOR
	box.material = material
	_shield_visual.mesh = box
	_shield_visual.position = SHIELD_OFFSET
	_shield_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield_visual.visible = false
	player.add_child(_shield_visual)


func _sender_id() -> int:
	var sender: int = multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()


## Owner -> host: scoped in or out. The host sets the replicated Player.scope_glint.
@rpc("any_peer", "call_local", "reliable")
func _request_scope(scoped: bool) -> void:
	if not multiplayer.is_server() or _sender_id() != player.get_multiplayer_authority():
		return
	player.scope_glint = scoped and player.is_alive


@rpc("any_peer", "call_local", "reliable")
func _show_grapple(point: Vector3, seconds: float) -> void:
	if _sender_id() != 1:
		return
	player.get_parent().add_child(GrappleBeam.create(player, point, seconds))
	Sfx.play_at(player.get_parent(), Sfx.GRAPPLE_SHOT, player.global_position + Vector3.UP * 1.4, Sfx.STEP_DB + 4.0)
	Sfx.play_at(player.get_parent(), Sfx.GRAPPLE_HOOK, point, Sfx.STEP_DB + 4.0)


@rpc("any_peer", "call_local", "reliable")
func _show_decoy(at: Vector3, yaw: float, seconds: float, start_velocity: Vector3) -> void:
	if _sender_id() != 1:
		return
	player.get_parent().add_child(Decoy.create(player.model, at, yaw, seconds, start_velocity, player.movement.def)) # The copy keeps the crouch squash.


@rpc("any_peer", "call_local", "unreliable")
func _show_shot(_from: Vector3, to: Vector3, beam: bool) -> void:
	if _sender_id() != 1 or player.is_local:
		return
	player.rig.play_fire()
	_play_remote_shot()
	_whiz_past([to])
	if _held_suppressed():
		return
	ShotEffects.spawn_muzzle_flash(player.remote_muzzle)
	if beam:
		ShotEffects.spawn_beam(player.get_parent(), player.remote_muzzle.global_position, to)
	else:
		ShotEffects.spawn_tracer(player.get_parent(), player.remote_muzzle.global_position, to)


@rpc("any_peer", "call_local", "unreliable")
func _on_pellets_fired(ends: PackedVector3Array) -> void:
	if _sender_id() != 1 or player.is_local:
		return
	player.rig.play_fire()
	ShotEffects.spawn_muzzle_flash(player.remote_muzzle)
	_play_remote_shot()
	_whiz_past(ends)
	for end_point: Vector3 in ends:
		ShotEffects.spawn_tracer(player.get_parent(), player.remote_muzzle.global_position, end_point)


## Someone else's shot (or a pellet volley) passed close to our camera: one whiz where the nearest
## line came closest. Shots from right next to us and shots that end at us (hits) stay quiet.
func _whiz_past(ends: Array) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var ear: Vector3 = camera.global_position
	var from: Vector3 = player.remote_muzzle.global_position
	if from.distance_to(ear) < WHIZ_MIN_SHOOTER_DISTANCE:
		return
	var best: float = WHIZ_RADIUS
	var best_point: Vector3 = Vector3.ZERO
	for end_point: Vector3 in ends:
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(ear, from, end_point)
		if closest.distance_to(end_point) < WHIZ_END_MARGIN:
			continue # Hit something right by us: the impact says enough.
		var distance: float = closest.distance_to(ear)
		if distance < best:
			best = distance
			best_point = closest
	if best < WHIZ_RADIUS:
		Sfx.whiz(player.get_parent(), best_point)


## Gunshot of the weapon this remote player holds, at their gun.
func _held_suppressed() -> bool:
	var slot: int = player.held_slot
	return slot >= 0 and slot < player.weapons.size() and player.weapons[slot].def.suppressed


func _play_remote_shot() -> void:
	var slot: int = player.held_slot
	if slot < 0 or slot >= player.weapons.size():
		return
	Sfx.shot(player.get_parent(), player.weapons[slot].def, player.remote_muzzle.global_position)


static func _model_length(model: Node3D) -> float:
	var length: float = 0.0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = mesh.get_aabb()
		if mesh.is_inside_tree():
			box = (model.global_transform.affine_inverse() * mesh.global_transform) * box
		length = maxf(length, box.size.z)
	return length


## Owner: something others should see the body do (reload, throw, knife swing).
func report_action(action: SoldierRig.Action, seconds: float) -> void:
	_request_action.rpc_id(1, action, seconds)


## Owner -> host -> everyone else: SoldierRig.play_action. Cosmetic only.
@rpc("any_peer", "call_local", "unreliable_ordered")
func _request_action(action: int, seconds: float) -> void:
	if not multiplayer.is_server() or _sender_id() != player.get_multiplayer_authority():
		return
	for peer_id: int in Net.ingame_peers:
		if peer_id != player.get_multiplayer_authority():
			_show_action.rpc_id(peer_id, action, clampf(seconds, 0.0, 10.0))


@rpc("any_peer", "call_local", "unreliable_ordered")
func _show_action(action: int, seconds: float) -> void:
	if _sender_id() != 1 or player.is_local or player.rig == null:
		return
	player.rig.play_action(action as SoldierRig.Action, seconds)
	var slot: int = player.held_slot
	if action == SoldierRig.Action.RELOAD and slot >= 0 and slot < player.weapons.size():
		Sfx.reload(player.get_parent(), player.weapons[slot].def, player.global_position)


# --- Hound, Ghost, Trickster, Phantom -------------------------------------------------

const CLOAK_HIDE: float = 0.94 ## Transparency of a fully cloaked body for others (a faint shimmer stays).
const CLOAK_OWN: float = 0.55 ## The cloaked owner's own gun and arms, so they know it is on.
const CLOAK_DEFAULT_FADE: float = 0.5
const SONAR_COLOR: Color = Color(1.0, 0.18, 0.12, 0.8)
const MARK_COLOR: Color = Color(0.65, 0.35, 1.0, 0.35)
const MARK_HEIGHT: float = 2.4
const MARK_RADIUS: float = 0.35
const DART_LENGTH: float = 0.25
const WHIZ_RADIUS: float = 1.6 ## A bullet passing this close to your head whizzes.
const WHIZ_MIN_SHOOTER_DISTANCE: float = 4.0 ## Not for someone shooting right beside you.
const WHIZ_END_MARGIN: float = 0.6 ## Not when the shot ended (hit) right next to you.

static var _sonar_material: StandardMaterial3D

var _cloak_value: float = 0.0 ## 0 = visible, 1 = fully cloaked (eased on every peer).
var _mark_node: Node3D
var _name_in_sight: bool = false
var _name_check_left: float = 0.0


func _process(delta: float) -> void:
	_update_name_visibility(delta)
	var target: float = 1.0 if player.cloaked and player.is_alive else 0.0
	if is_equal_approx(_cloak_value, target):
		return
	_cloak_value = move_toward(_cloak_value, target, delta / _cloak_fade_time())
	_apply_cloak()


## Player.cloaked changed (every peer): the body fades out (or back in) in _process.
func show_cloak(on: bool) -> void:
	Sfx.play_at(player.get_parent(), Sfx.CLOAK, player.global_position + Vector3.UP, Sfx.STEP_DB)
	if not on and player.is_local:
		_cloak_value = minf(_cloak_value, 0.5)


func _cloak_fade_time() -> float:
	var cloak := player.ability as CloakAbility
	return maxf(cloak.def.fade_time if cloak != null else CLOAK_DEFAULT_FADE, 0.05)


func _apply_cloak() -> void:
	if DisplayServer.get_name() == "headless":
		return # Nothing is drawn (and the dummy renderer has no materials to copy).
	var root: Node = player.weapon_holder if player.is_local else player.model
	var hide: float = _cloak_value * (CLOAK_OWN if player.is_local else CLOAK_HIDE)
	_fade_meshes(root, 1.0 - hide)


## Others' nicks show only while some part of the body is in plain sight (a nick over a low wall
## gave hidden players away); an airdrop carrier's shows through walls (GDD). Never when cloaked.
func _update_name_visibility(delta: float) -> void:
	if player.is_local or _name_label == null:
		return
	_name_check_left -= delta
	if _name_check_left <= 0.0:
		_name_check_left = NAME_SIGHT_INTERVAL
		_name_in_sight = _in_sight()
	_name_label.visible = (_carrying or _name_in_sight) and _cloak_value < 0.5


func _in_sight() -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or not player.is_inside_tree():
		return false
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	for height: float in NAME_SIGHT_POINTS:
		var query := PhysicsRayQueryParameters3D.create(from, player.global_position + Vector3.UP * height, SIGHT_MASK)
		if space.intersect_ray(query).is_empty():
			return true
	return false


## Fades every mesh under `root` to `alpha` with see-through copies of its materials (works on
## every renderer); alpha 1 puts the real materials back.
static func _fade_meshes(root: Node, alpha: float) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			if alpha >= 0.999:
				mesh.set_surface_override_material(surface, null)
				continue
			var faded := mesh.get_surface_override_material(surface) as StandardMaterial3D
			if faded == null or not faded.has_meta(&"cloak"):
				var original := mesh.get_active_material(surface) as StandardMaterial3D
				if original == null:
					continue # Custom shaders (own arms) keep their look.
				faded = original.duplicate() as StandardMaterial3D
				faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				faded.set_meta(&"cloak", original.albedo_color.a)
				mesh.set_surface_override_material(surface, faded)
			var color: Color = faded.albedo_color
			color.a = float(faded.get_meta(&"cloak")) * alpha
			faded.albedo_color = color


## Host: the Hound's Sonar found these peers; only the Hound's screen shows them.
func server_show_sonar(peer_ids: PackedInt32Array, seconds: float) -> void:
	assert(multiplayer.is_server(), "server_show_sonar is host-only")
	var owner_id: int = player.get_multiplayer_authority()
	if owner_id == multiplayer.get_unique_id() or owner_id in multiplayer.get_peers():
		_show_sonar.rpc_id(owner_id, peer_ids, seconds)


@rpc("any_peer", "call_local", "reliable")
func _show_sonar(peer_ids: PackedInt32Array, seconds: float) -> void:
	if _sender_id() != 1:
		return
	for node: Node in player.get_parent().get_children():
		var other := node as Player
		if other != null and other.get_multiplayer_authority() in peer_ids and other.rig != null:
			other.rig.reveal(get_sonar_material(), seconds)
	var sonar := player.ability as SonarAbility
	if sonar != null: # Not the Gambler's All In: that one has its own dice banner.
		var count: int = peer_ids.size() + sonar.dummies_found
		Events.local_notice.emit("SONAR: %d FOUND" % count if count > 0 else "SONAR: NOBODY IN %d M" % roundi(sonar.def.max_range))


## Shared see-through red of Sonar reveals (players and Test Range dummies).
static func get_sonar_material() -> StandardMaterial3D:
	if _sonar_material == null:
		_sonar_material = StandardMaterial3D.new()
		_sonar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sonar_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sonar_material.no_depth_test = true # Through walls.
		_sonar_material.albedo_color = SONAR_COLOR
		_sonar_material.render_priority = 10
	return _sonar_material


## Host: tells this player's owner a Sonar found them (a ping from the Hound's side).
func server_sonar_ping(from_point: Vector3) -> void:
	assert(multiplayer.is_server(), "server_sonar_ping is host-only")
	var owner_id: int = player.get_multiplayer_authority()
	if owner_id == multiplayer.get_unique_id() or owner_id in multiplayer.get_peers():
		_sonar_ping.rpc_id(owner_id, from_point)


@rpc("any_peer", "call_local", "reliable")
func _sonar_ping(from_point: Vector3) -> void:
	if _sender_id() != 1:
		return
	Sfx.play_at(player.get_parent(), Sfx.SONAR, from_point + Vector3.UP * 1.5, Sfx.STEP_DB + 6.0)


## Host: every peer draws the Trickster's dart flying (cosmetic; the host's copy decides).
func server_show_dart(start: Vector3, velocity: Vector3, seconds: float) -> void:
	assert(multiplayer.is_server(), "server_show_dart is host-only")
	Net.broadcast(self, &"_show_dart", [start, velocity, seconds])


@rpc("any_peer", "call_local", "unreliable")
func _show_dart(start: Vector3, velocity: Vector3, seconds: float) -> void:
	if _sender_id() != 1:
		return
	player.get_parent().add_child(DartFx.create(start, velocity, seconds, player.get_hit_exclusions()))


@rpc("any_peer", "call_local", "reliable")
func _show_teleport(target: Vector3) -> void:
	if _sender_id() != 1:
		return
	Sfx.play_at(player.get_parent(), Sfx.TELEPORT, target + Vector3.UP, Sfx.STEP_DB + 2.0)


## Host: Phantom's mark appears for everyone (a light pillar) until recalled or timed out.
func server_show_mark(point: Vector3, seconds: float) -> void:
	assert(multiplayer.is_server(), "server_show_mark is host-only")
	Net.broadcast(self, &"_show_mark", [point, seconds])


func server_hide_mark() -> void:
	assert(multiplayer.is_server(), "server_hide_mark is host-only")
	Net.broadcast(self, &"_hide_mark")


@rpc("any_peer", "call_local", "reliable")
func _show_mark(point: Vector3, seconds: float) -> void:
	if _sender_id() != 1:
		return
	_hide_mark_now()
	_mark_node = _build_mark()
	player.get_parent().add_child(_mark_node)
	_mark_node.global_position = point
	get_tree().create_timer(seconds + 0.5).timeout.connect(_hide_mark_now) # Host message lost: still goes.


@rpc("any_peer", "call_local", "reliable")
func _hide_mark() -> void:
	if _sender_id() != 1:
		return
	_hide_mark_now()


func _hide_mark_now() -> void:
	if is_instance_valid(_mark_node):
		_mark_node.queue_free()
	_mark_node = null


func _exit_tree() -> void:
	_hide_mark_now()


func _build_mark() -> Node3D:
	var root := Node3D.new()
	root.name = "PhantomMark"
	var pillar := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = MARK_RADIUS * 0.6
	mesh.bottom_radius = MARK_RADIUS
	mesh.height = MARK_HEIGHT
	mesh.radial_segments = 12
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = MARK_COLOR
	mesh.material = material
	pillar.mesh = mesh
	pillar.position.y = MARK_HEIGHT * 0.5
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pillar)
	var light := OmniLight3D.new()
	light.light_color = Color(MARK_COLOR, 1.0)
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.position.y = 1.0
	root.add_child(light)
	return root

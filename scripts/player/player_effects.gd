class_name PlayerEffects
extends Node
## Visuals of one Player that everyone sees: Bear's shield panel and Hawk's scope glint
## (both driven by replicated Player state, so late joiners see them too), grapple rope,
## decoy hologram and remote tracers (host broadcasts). Never affects gameplay.
## Child node "Effects" of the player scene, so its RPC path is the same everywhere.

const SHIELD_SIZE: Vector3 = Vector3(1.3, 1.7, 0.06)
const SHIELD_OFFSET: Vector3 = Vector3(0.0, 1.0, -0.8)
const SHIELD_COLOR: Color = Color(0.35, 0.8, 1.0, 0.4)
## Scope glint (GDD Hawk): shown to others while scoped, same screen size at any distance.
const GLINT_OFFSET: Vector3 = Vector3(0.15, 1.5, -0.45)
const GLINT_SIZE: float = 0.04
const GLINT_COLOR: Color = Color(0.6, 0.57, 0.48) ## Additive: lower = dimmer.

var _shield_visual: MeshInstance3D
var _glint: MeshInstance3D
var _sent_scoped: bool = false ## Owner: scope state last told to the host.
var _held_model: Node3D

@onready var player: Player = get_parent()


## Player._ready: builds the shield panel and the glint (children must not be added to the
## player while it is still readying its own children, so this is not done in our _ready).
func setup() -> void:
	_build_shield_visual()
	_build_glint()


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


## Player.held_slot or the loadout changed (every peer): the world model in the body's hand.
## Hidden on the owner with the rest of the body.
func show_held_weapon(slot: int) -> void:
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
	player.remote_muzzle.position = def.world_muzzle * def.world_model_scale


## Host: other peers draw this player's tracer.
func server_show_shot(origin: Vector3, end_point: Vector3) -> void:
	assert(multiplayer.is_server(), "server_show_shot is host-only")
	Net.broadcast(self, &"_show_shot", [origin, end_point])


## Host: other peers draw one tracer per shotgun pellet.
func server_show_pellets(ends: PackedVector3Array) -> void:
	assert(multiplayer.is_server(), "server_show_pellets is host-only")
	Net.broadcast(self, &"_on_pellets_fired", [ends])


## Host: everyone sees the rope of a Hawk grapple.
func show_grapple(point: Vector3, seconds: float) -> void:
	assert(multiplayer.is_server(), "show_grapple is host-only")
	Net.broadcast(self, &"_show_grapple", [point, seconds])


## Host: everyone sees a hologram of this player where they stand now.
func show_decoy(seconds: float) -> void:
	assert(multiplayer.is_server(), "show_decoy is host-only")
	Net.broadcast(self, &"_show_decoy", [player.global_position, player.rotation.y, seconds])


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


@rpc("any_peer", "call_local", "reliable")
func _show_decoy(at: Vector3, yaw: float, seconds: float) -> void:
	if _sender_id() != 1:
		return
	player.get_parent().add_child(Decoy.create(player.model, at, yaw, seconds)) # The copy keeps the crouch squash.


@rpc("any_peer", "call_local", "unreliable")
func _show_shot(_from: Vector3, to: Vector3) -> void:
	if _sender_id() != 1 or player.is_local:
		return
	ShotEffects.spawn_muzzle_flash(player.remote_muzzle)
	ShotEffects.spawn_tracer(player.get_parent(), player.remote_muzzle.global_position, to)


@rpc("any_peer", "call_local", "unreliable")
func _on_pellets_fired(ends: PackedVector3Array) -> void:
	if _sender_id() != 1 or player.is_local:
		return
	ShotEffects.spawn_muzzle_flash(player.remote_muzzle)
	for end_point: Vector3 in ends:
		ShotEffects.spawn_tracer(player.get_parent(), player.remote_muzzle.global_position, end_point)

class_name LauncherWeapon
extends Weapon
## Volcano's Grenade Launcher and the airdrop Rocket Launcher: fires WeaponDef.grenade as a
## host-simulated physical round (same Grenade / Game.server_explode path as Wolf's frag).
## Guidable launchers (Rocket Launcher, Half-Life style): right click toggles the laser; the
## owner sees a red dot where they aim and the host steers live rockets towards that point.

const HAND_OFFSET: float = 0.5 ## Metres in front of the eye where the round appears.
const WALL_MARGIN: float = 0.1
const WORLD_MASK: int = 1
const LASER_MASK: int = 1 | 2 # world | players
const LASER_RANGE: float = 500.0
const LASER_DOT_SIZE: float = 0.12
const LASER_COLOR: Color = Color(1.0, 0.1, 0.05)

var guided: bool = true

var _dot: MeshInstance3D


func draw() -> void:
	super.draw()
	if def.guidable and player.is_local:
		player.requests.send_guided(guided) # The host's flag follows this weapon's state.
	_update_dot()


func holster() -> void:
	super.holster()
	if _dot != null:
		_dot.visible = false


func tick(delta: float, cmd: PlayerCommand) -> void:
	super.tick(delta, cmd)
	if def.guidable and cmd.secondary_pressed:
		guided = not guided
		player.requests.send_guided(guided)
	_update_dot()


func _exit_tree() -> void:
	if _dot != null:
		_dot.queue_free()
		_dot = null


## Owner: muzzle flash now; the host spawns the round.
func _fire() -> void:
	ShotEffects.spawn_muzzle_flash(muzzle)
	Sfx.shot(player.get_parent(), def, muzzle.global_position)
	player.send_fire(player.get_aim_origin(), -player.get_aim_basis().z, player.weapons.find(self))


func server_fire(origin: Vector3, dir: Vector3) -> Vector3:
	assert(multiplayer.is_server(), "server_fire is host-only")
	var game: Game = Game.find(get_tree())
	if game == null or def.grenade == null:
		return origin
	# Never spawn on the far side of a thin wall the shooter is hugging.
	var spawn: Vector3 = origin + dir * HAND_OFFSET
	var query := PhysicsRayQueryParameters3D.create(origin, spawn, WORLD_MASK)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spawn = (hit["position"] as Vector3) - dir * WALL_MARGIN
	var velocity: Vector3 = dir * def.grenade.throw_speed + Vector3.UP * def.grenade.throw_lift
	game.server_spawn_grenade(def.grenade, player.get_multiplayer_authority(), spawn, velocity)
	return spawn


## Owner only: red laser dot on whatever the aim ray hits while guidance is on.
func _update_dot() -> void:
	if not def.guidable or player == null or not player.is_local:
		return
	if _dot == null:
		_dot = _build_dot()
		player.get_parent().add_child(_dot)
	var origin: Vector3 = player.get_aim_origin()
	var forward: Vector3 = -player.get_aim_basis().z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * LASER_RANGE, LASER_MASK, player.get_hit_exclusions())
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_dot.visible = guided and visible and not hit.is_empty()
	if _dot.visible:
		_dot.global_position = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.02


func _build_dot() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(LASER_DOT_SIZE, LASER_DOT_SIZE)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.albedo_color = LASER_COLOR
	material.albedo_texture = ShotEffects.get_glow_texture()
	quad.material = material
	var dot := MeshInstance3D.new()
	dot.mesh = quad
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.top_level = true
	dot.visible = false
	return dot

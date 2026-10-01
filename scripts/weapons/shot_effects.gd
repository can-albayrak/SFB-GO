class_name ShotEffects
extends RefCounted
## Cosmetic-only shot visuals (tracer streak, muzzle flash, impact mark). Never affects gameplay.

const FLASH_TIME: float = 0.045
const FLASH_SIZE: float = 0.16
const FLASH_LIGHT_ENERGY: float = 2.5
const FLASH_LIGHT_RANGE: float = 4.0
const FLASH_COLOR: Color = Color(1.0, 0.75, 0.35)
const EXPLOSION_TIME: float = 0.5
const EXPLOSION_SIZE: float = 6.0 ## Final diameter scale of the glow sphere.
const EXPLOSION_LIGHT_ENERGY: float = 8.0
const EXPLOSION_LIGHT_RANGE: float = 12.0
const EXPLOSION_FRAG_COLOR: Color = Color(1.0, 0.55, 0.2, 0.9)
const EXPLOSION_FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const IMPACT_RADIUS: float = 0.025
const IMPACT_LIFETIME: float = 8.0

static var _flash_mesh: QuadMesh
static var _glow_texture: GradientTexture2D
static var _impact_mesh: SphereMesh


## `parent` must sit at the world origin (Players root); from/to are world positions.
static func spawn_tracer(parent: Node3D, from: Vector3, to: Vector3) -> void:
	if from.distance_to(to) <= Tracer.LENGTH:
		return
	parent.add_child(Tracer.create(from, to))


## Brief flash + light parented to the muzzle, so it follows the gun.
static func spawn_muzzle_flash(muzzle: Node3D) -> void:
	if _flash_mesh == null:
		_flash_mesh = QuadMesh.new()
		_flash_mesh.size = Vector2(FLASH_SIZE, FLASH_SIZE)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_color = FLASH_COLOR
		material.albedo_texture = _make_flash_texture()
		_flash_mesh.material = material
	var flash := MeshInstance3D.new()
	flash.mesh = _flash_mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.rotation.z = randf() * TAU
	var light := OmniLight3D.new()
	light.light_color = FLASH_COLOR
	light.light_energy = FLASH_LIGHT_ENERGY
	light.omni_range = FLASH_LIGHT_RANGE
	flash.add_child(light)
	muzzle.add_child(flash)
	muzzle.get_tree().create_timer(FLASH_TIME).timeout.connect(flash.queue_free)


## Shared soft round glow texture (muzzle flash, scope glint).
static func get_glow_texture() -> GradientTexture2D:
	if _glow_texture == null:
		_glow_texture = _make_flash_texture()
	return _glow_texture


## Soft round glow: bright core fading to transparent edges.
static func _make_flash_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.25, Color(1.0, 0.9, 0.6, 0.9))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture


## Grenade burst: an expanding, fading glow sphere plus a short strong light.
static func spawn_explosion(parent: Node3D, point: Vector3, is_flash: bool) -> void:
	var color: Color = EXPLOSION_FLASH_COLOR if is_flash else EXPLOSION_FRAG_COLOR
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	mesh.material = material
	var ball := MeshInstance3D.new()
	ball.mesh = mesh
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.position = point
	ball.scale = Vector3.ONE * 0.3
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = EXPLOSION_LIGHT_ENERGY
	light.omni_range = EXPLOSION_LIGHT_RANGE
	ball.add_child(light)
	parent.add_child(ball)

	var tween := ball.create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * EXPLOSION_SIZE, EXPLOSION_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, EXPLOSION_TIME)
	tween.tween_property(light, "light_energy", 0.0, EXPLOSION_TIME)
	tween.chain().tween_callback(ball.queue_free)


static func spawn_impact(parent: Node3D, point: Vector3) -> void:
	if _impact_mesh == null:
		_impact_mesh = SphereMesh.new()
		_impact_mesh.radius = IMPACT_RADIUS
		_impact_mesh.height = IMPACT_RADIUS * 2.0
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.BLACK
		_impact_mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = _impact_mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = point # Before add_child so interpolation never starts at the origin.
	parent.add_child(instance)
	parent.get_tree().create_timer(IMPACT_LIFETIME).timeout.connect(instance.queue_free)

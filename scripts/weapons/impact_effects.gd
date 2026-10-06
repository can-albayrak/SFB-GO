class_name ImpactEffects
extends RefCounted
## Cosmetic-only bullet impacts and blood: a bullet hole on the surface plus a short burst of
## particles that fits the surface (snow puff, ice chips, metal sparks, stone dust). Never
## affects gameplay. The surface is the map's (MapDef.impact_surface) unless the collider
## carries a "surface" meta (then that wins, so one map can mix materials).

const MAX_HOLES: int = 64
const HOLE_SIZE: float = 0.09
const HOLE_LIFETIME: float = 12.0
const HOLE_LIFT: float = 0.012 ## Metres off the wall, so the hole never z-fights with it.
const HOLE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.85)
const BURST_LIFETIME: float = 0.5
const BURST_SPREAD: float = 50.0 ## Degrees around the surface normal.
const BURST_LINGER: float = 0.3 ## Extra seconds before the emitter node is freed.
const DEFAULT_SURFACE: StringName = &"stone"
const BLOOD: StringName = &"blood"
## color, count, speed (m/s), size (m), gravity (m/s^2), bright (glows: sparks, ice).
const PROFILES: Dictionary = {
	&"stone": {"color": Color(0.72, 0.7, 0.64), "count": 7, "speed": 2.4, "size": 0.05, "gravity": 7.0, "bright": false},
	&"snow": {"color": Color(0.97, 0.99, 1.0), "count": 10, "speed": 1.6, "size": 0.07, "gravity": 3.0, "bright": false},
	&"ice": {"color": Color(0.7, 0.9, 1.0), "count": 9, "speed": 2.6, "size": 0.045, "gravity": 8.0, "bright": true},
	&"metal": {"color": Color(1.0, 0.8, 0.4), "count": 8, "speed": 4.5, "size": 0.025, "gravity": 12.0, "bright": true},
	&"blood": {"color": Color(0.6, 0.03, 0.03), "count": 9, "speed": 2.8, "size": 0.045, "gravity": 10.0, "bright": false},
}

static var _holes: Array[Node] = []
static var _hole_mesh: QuadMesh
static var _particle_mesh: SphereMesh
static var _particle_materials: Dictionary = {}
static var _fade_ramp: Gradient
static var _map_path: String = ""
static var _map_surface: StringName = DEFAULT_SURFACE


## A shot hit the world at `point` (`normal` points out of the surface). `parent` must sit at
## the world origin (Players root).
static func spawn(parent: Node3D, point: Vector3, normal: Vector3, collider: Object = null) -> void:
	if normal.length_squared() < 0.5:
		normal = Vector3.UP
	_spawn_hole(parent, point, normal)
	_spawn_burst(parent, point, normal, surface_of(collider))


## A player was hit at `point`; the spray flies back against the shot `direction`.
static func spawn_blood(parent: Node3D, point: Vector3, direction: Vector3) -> void:
	var back: Vector3 = -direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP
	_spawn_burst(parent, point, back, BLOOD)


static func surface_of(collider: Object) -> StringName:
	if collider != null and collider.has_meta(&"surface"):
		return collider.get_meta(&"surface")
	if Net.map_path != _map_path:
		_map_path = Net.map_path
		_map_surface = DEFAULT_SURFACE
		for map: MapDef in Net.MAP_LIST.maps:
			if map.scene_path == _map_path:
				_map_surface = map.impact_surface
	return _map_surface


static func _spawn_hole(parent: Node3D, point: Vector3, normal: Vector3) -> void:
	if _hole_mesh == null:
		var gradient := Gradient.new()
		gradient.set_color(0, HOLE_COLOR)
		gradient.set_color(1, Color(HOLE_COLOR, 0.0))
		gradient.add_point(0.55, HOLE_COLOR)
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 32
		texture.height = 32
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_texture = texture
		_hole_mesh = QuadMesh.new()
		_hole_mesh.size = Vector2(HOLE_SIZE, HOLE_SIZE)
		_hole_mesh.material = material
	var hole := MeshInstance3D.new()
	hole.mesh = _hole_mesh
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var up: Vector3 = Vector3.UP if absf(normal.y) < 0.99 else Vector3.RIGHT
	# The quad faces +Z, so look along -normal; a random roll keeps the holes from repeating.
	var facing: Basis = Basis.looking_at(-normal, up).rotated(normal, randf() * TAU)
	hole.transform = Transform3D(facing, point + normal * HOLE_LIFT) # Before add_child.
	parent.add_child(hole)
	_holes.append(hole)
	if _holes.size() > MAX_HOLES:
		var oldest: Node = _holes.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	parent.get_tree().create_timer(HOLE_LIFETIME).timeout.connect(func() -> void:
		if is_instance_valid(hole):
			hole.queue_free())


static func _spawn_burst(parent: Node3D, point: Vector3, normal: Vector3, surface: StringName) -> void:
	var profile: Dictionary = PROFILES.get(surface, PROFILES[DEFAULT_SURFACE])
	var speed: float = profile["speed"]
	var size: float = profile["size"]
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = profile["count"]
	burst.lifetime = BURST_LIFETIME
	burst.direction = normal
	burst.spread = BURST_SPREAD
	burst.initial_velocity_min = speed * 0.4
	burst.initial_velocity_max = speed
	burst.gravity = Vector3(0.0, -float(profile["gravity"]), 0.0)
	burst.scale_amount_min = size * 0.6
	burst.scale_amount_max = size
	burst.color = profile["color"]
	burst.color_ramp = _get_fade_ramp()
	burst.mesh = _get_particle_mesh()
	burst.material_override = _get_particle_material(profile["bright"])
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	burst.position = point # Before add_child.
	burst.emitting = false
	parent.add_child(burst)
	burst.emitting = true
	parent.get_tree().create_timer(BURST_LIFETIME + BURST_LINGER).timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free())


static func _get_particle_mesh() -> SphereMesh:
	if _particle_mesh == null:
		_particle_mesh = SphereMesh.new()
		_particle_mesh.radius = 0.5
		_particle_mesh.height = 1.0
		_particle_mesh.radial_segments = 4
		_particle_mesh.rings = 2
	return _particle_mesh


static func _get_particle_material(bright: bool) -> StandardMaterial3D:
	if not _particle_materials.has(bright):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		if bright:
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_particle_materials[bright] = material
	return _particle_materials[bright]


static func _get_fade_ramp() -> Gradient:
	if _fade_ramp == null:
		_fade_ramp = Gradient.new()
		_fade_ramp.set_color(0, Color.WHITE)
		_fade_ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	return _fade_ramp

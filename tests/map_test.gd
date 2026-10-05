extends Node
## Headless map test, every map in data/maps/map_list.tres:
##   godot --headless --path . res://tests/map_test.tscn
## Loads each map in an offline match and checks: spawn points stand on a floor and the
## player capsule fits there; pickups stand on a floor; airdrop points have a floor and room
## above for the falling crate (open sky, or AirdropCrate.MIN_FALL_HEIGHT under a roof);
## every spawn, pickup and airdrop point can be walked to
## from the first spawn (navmesh baked from the map's colliders: steps up to the step height,
## ramps, no jumps); high levels stay reachable with any one way up removed (ALTERNATE_ROUTES).
## Also prints the longest walk between two spawns (GDD: 15-20 s end to end).
## Prints PASS / FAIL lines and quits with exit code 1 when anything failed.

const GAME_SCENE: PackedScene = preload("res://scenes/game.tscn")
const WORLD_MASK: int = 1
const FLOOR_PROBE: float = 0.3 ## Metres below a marker where the floor must be.
const CAPSULE_RADIUS: float = 0.35
const CAPSULE_HEIGHT: float = 1.8
const AGENT_RADIUS: float = 0.4
const NAV_CELL_SIZE: float = 0.2
const NAV_CELL_HEIGHT: float = 0.1
const REACH_TOLERANCE: float = 0.75 ## Metres between a marker and where its path ends.
const RUN_SPEED: float = 6.6 ## Wolf's run speed, for the end-to-end time.
const MAX_END_TO_END: float = 25.0 ## Seconds; the GDD aims for 15-20.
const TIMEOUT: float = 300.0
## Per map id: high levels, their spawns and every way up. Each way is removed on its own
## and the spawns must stay reachable (GDD: at least two ways to every high point).
const ALTERNATE_ROUTES: Dictionary = {
	&"mall": {
		"roof": {
			"spawns": ["Spawn12"],
			"routes": ["Geometry/Upper/StairsRoof", "Geometry/Outside/FireEscapeHigh"],
		},
		"upper floor": {
			"spawns": ["Spawn8", "Spawn9", "Spawn10", "Spawn11"],
			"routes": ["Geometry/Ground/EscalatorW", "Geometry/Ground/EscalatorE", "Geometry/Ground/StairsWest",
				"Geometry/Ground/StairsEast", "Geometry/Outside/FireEscapeLow", "Geometry/Outside/BalconyStairs"],
		},
	},
}

var _passes: int = 0
var _failures: int = 0


func _ready() -> void:
	get_tree().create_timer(TIMEOUT).timeout.connect(_on_timeout)
	_run.call_deferred()


func _run() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Net.player_names[1] = "Tester"
	for map_def: MapDef in Net.MAP_LIST.maps:
		await _test_map(map_def)
	_finish()


func _test_map(map_def: MapDef) -> void:
	var label: String = map_def.display_name
	_check(ResourceLoader.exists(map_def.scene_path), "%s scene exists" % label)
	if not ResourceLoader.exists(map_def.scene_path):
		return
	Net.map_path = map_def.scene_path
	Match.configure(0, 0.0)
	var game := GAME_SCENE.instantiate() as Game
	add_child(game)
	await _frames(5)
	var map: Node3D = game.get_node("Map")
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state

	var spawns: Array[Node3D] = _children(map, "SpawnPoints")
	var pickups: Array[Node3D] = _children(map, "Pickups")
	var drops: Array[Node3D] = _children(map, "AirdropPoints")
	_check(spawns.size() >= 8, "%s has %d spawn points" % [label, spawns.size()])
	# The player node collides like any capsule; keep it out of the probes.
	var player := game.players_root.get_node_or_null("1") as Player
	var exclude: Array[RID] = []
	if player != null:
		exclude.append(player.get_rid())

	for spawn: Node3D in spawns:
		var pos: Vector3 = spawn.global_position
		_check(_floor_below(space, pos, exclude), "%s %s stands on a floor" % [label, spawn.name])
		_check(_capsule_fits(space, pos, exclude), "%s %s has room for a player" % [label, spawn.name])
	for pickup: Node3D in pickups:
		_check(_floor_below(space, pickup.global_position + Vector3.UP * 0.1, exclude), "%s pickup %s stands on a floor" % [label, pickup.name])
	for drop: Node3D in drops:
		var pos: Vector3 = drop.global_position
		_check(_floor_below(space, pos + Vector3.UP * 0.1, exclude), "%s airdrop %s stands on a floor" % [label, drop.name])
		_check(_room_above(space, pos, exclude), "%s airdrop %s has room for the falling crate" % [label, drop.name])

	await _test_reachability(label, map, spawns, pickups + drops)
	await _test_alternate_routes(map_def, map, spawns)
	game.queue_free()
	await _frames(3)


func _test_reachability(label: String, map: Node3D, spawns: Array[Node3D], others: Array[Node3D]) -> void:
	if spawns.is_empty():
		return
	var nav: Dictionary = await _bake(map, spawns[0].global_position)
	_check(nav.polygons > 0, "%s navmesh baked (%d polygons)" % [label, nav.polygons])
	if nav.polygons == 0:
		_free_nav(nav)
		return
	var nav_map: RID = nav.map
	var start: Vector3 = spawns[0].global_position
	var longest: float = 0.0
	var longest_pair: String = ""
	for target: Node3D in spawns + others:
		var length: float = _path_length(nav_map, start, target.global_position)
		_check(length >= 0.0, "%s %s can be walked to from %s" % [label, target.name, spawns[0].name])
	for a: int in spawns.size():
		for b: int in range(a + 1, spawns.size()):
			var length: float = _path_length(nav_map, spawns[a].global_position, spawns[b].global_position)
			if length > longest:
				longest = length
				longest_pair = "%s-%s" % [spawns[a].name, spawns[b].name]
	var seconds: float = longest / RUN_SPEED
	print("INFO %s longest walk between spawns: %.0f m, %.1f s (%s)" % [label, longest, seconds, longest_pair])
	_check(seconds <= MAX_END_TO_END, "%s end to end on foot within %d s" % [label, roundi(MAX_END_TO_END)])
	_free_nav(nav)


## GDD: every high point can be reached by at least two ways. Each way up is taken out on
## its own (node removed, navmesh rebaked); the level's spawns must stay reachable.
func _test_alternate_routes(map_def: MapDef, map: Node3D, spawns: Array[Node3D]) -> void:
	var levels: Dictionary = ALTERNATE_ROUTES.get(map_def.id, {})
	for level_name: String in levels:
		var level: Dictionary = levels[level_name]
		for route_path: String in level.routes:
			var route: Node = map.get_node_or_null(route_path)
			_check(route != null, "%s route %s exists" % [map_def.display_name, route_path])
			if route == null:
				continue
			var parent: Node = route.get_parent()
			parent.remove_child(route)
			await _frames(2)
			var nav: Dictionary = await _bake(map, spawns[0].global_position)
			for spawn_name: String in level.spawns:
				var target: Node3D = map.get_node("SpawnPoints/" + spawn_name)
				_check(_path_length(nav.map, spawns[0].global_position, target.global_position) >= 0.0,
					"%s %s (%s) reachable without %s" % [map_def.display_name, level_name, spawn_name, route.name])
			_free_nav(nav)
			parent.add_child(route)
			await _frames(2)
		# Sanity: with every way up removed the level must be cut off, or the test proves nothing.
		var removed: Array[Array] = []
		for route_path: String in level.routes:
			var route: Node = map.get_node_or_null(route_path)
			if route != null:
				removed.append([route, route.get_parent()])
				route.get_parent().remove_child(route)
		await _frames(2)
		var cut: Dictionary = await _bake(map, spawns[0].global_position)
		var first_target: Node3D = map.get_node("SpawnPoints/" + (level.spawns[0] as String))
		_check(_path_length(cut.map, spawns[0].global_position, first_target.global_position) < 0.0,
			"%s %s is cut off with every way up removed (test sanity)" % [map_def.display_name, level_name])
		_free_nav(cut)
		for pair: Array in removed:
			(pair[1] as Node).add_child(pair[0] as Node)
		await _frames(2)


## Bakes a navmesh from the map's colliders and waits until the server can answer queries.
## Returns {map, region, polygons}.
func _bake(map: Node3D, probe: Vector3) -> Dictionary:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = AGENT_RADIUS
	nav_mesh.agent_height = CAPSULE_HEIGHT
	nav_mesh.agent_max_climb = 0.4
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = NAV_CELL_SIZE
	nav_mesh.cell_height = NAV_CELL_HEIGHT
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = WORLD_MASK
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, map.get_node("Geometry"))
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	var nav_map: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(nav_map, NAV_CELL_SIZE)
	NavigationServer3D.map_set_cell_height(nav_map, NAV_CELL_HEIGHT)
	NavigationServer3D.map_set_active(nav_map, true)
	var region: RID = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, nav_map)
	NavigationServer3D.region_set_navigation_mesh(region, nav_mesh)
	# The server syncs maps between frames (a big region can take a few); queries before
	# that come back empty.
	for i: int in 120:
		await get_tree().process_frame
		if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
			continue
		if NavigationServer3D.map_get_closest_point(nav_map, probe).distance_to(probe) < REACH_TOLERANCE:
			break
	return {"map": nav_map, "region": region, "polygons": nav_mesh.get_polygon_count()}


func _free_nav(nav: Dictionary) -> void:
	NavigationServer3D.free_rid(nav.region)
	NavigationServer3D.free_rid(nav.map)


## Path length on foot, or -1 when the path does not reach `to`.
func _path_length(nav_map: RID, from: Vector3, to: Vector3) -> float:
	var goal: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, to)
	if goal.distance_to(to) > REACH_TOLERANCE:
		return -1.0
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, from, goal, true)
	if path.is_empty() or path[path.size() - 1].distance_to(goal) > REACH_TOLERANCE:
		return -1.0
	var length: float = 0.0
	for i: int in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


func _floor_below(space: PhysicsDirectSpaceState3D, pos: Vector3, exclude: Array[RID]) -> bool:
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.05, pos + Vector3.DOWN * FLOOR_PROBE, WORLD_MASK, exclude)
	return not space.intersect_ray(query).is_empty()


func _capsule_fits(space: PhysicsDirectSpaceState3D, feet: Vector3, exclude: Array[RID]) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (CAPSULE_HEIGHT * 0.5 + 0.05))
	query.collision_mask = WORLD_MASK
	query.exclude = exclude
	return space.intersect_shape(query, 1).is_empty()


func _room_above(space: PhysicsDirectSpaceState3D, pos: Vector3, _exclude: Array[RID]) -> bool:
	return AirdropCrate.fall_height_at(space, pos) >= AirdropCrate.MIN_FALL_HEIGHT


func _children(map: Node, group_name: String) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var group_node: Node = map.get_node_or_null(group_name)
	if group_node != null:
		for child: Node in group_node.get_children():
			if child is Node3D:
				result.append(child as Node3D)
	return result


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)


func _finish() -> void:
	print("MAP TEST: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _on_timeout() -> void:
	_check(false, "finished within %d s" % roundi(TIMEOUT))
	_finish()

extends Node
## Renders the HUD weapon icons from the weapon models (needs a window, not --headless):
##   godot --path . res://tests/render_weapon_icons.tscn
## Every WeaponDef in data/weapons with a world_model is drawn from its right side (muzzle to
## the right), orthographic, on a transparent background. The render becomes a flat light
## silhouette with a dark outline (PS2 HUD style, GDD), keeping a hint of the model's shading,
## then is cropped and saved to assets/ui/weapon_icons/<id>.png. Re-run after a model changes.

const OUT_DIR: String = "res://assets/ui/weapon_icons"
const WEAPONS_DIR: String = "res://data/weapons"
const RENDER_SIZE: Vector2i = Vector2i(768, 288)
const MARGIN: float = 1.08 ## Frame a little wider than the model.
const FILL: Color = Color(0.88, 0.9, 0.93)
const SHADE: float = 0.35 ## How much of the model's own light and dark shows in the fill.
const OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.9)
const OUTLINE_PX: int = 3
const PAD: int = 6


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = RENDER_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 60.0, 0.0)
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.rotation_degrees = Vector3(0.0, 90.0, 0.0) # From +X: the muzzle (-Z) points right.
	viewport.add_child(camera)

	for file: String in DirAccess.get_files_at(WEAPONS_DIR):
		if not file.ends_with(".tres"):
			continue
		var def := load(WEAPONS_DIR.path_join(file)) as WeaponDef
		if def == null or def.world_model == null:
			continue
		var model := def.world_model.instantiate() as Node3D
		viewport.add_child(model)
		var box: AABB = _bounds(model)
		var aspect: float = float(RENDER_SIZE.x) / RENDER_SIZE.y
		camera.size = maxf(box.size.z, box.size.y * aspect) * MARGIN
		camera.position = Vector3(box.end.x + 2.0, box.get_center().y, box.get_center().z)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var icon: Image = _stylise(viewport.get_texture().get_image())
		icon.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join("%s.png" % def.id)))
		print("icon ", def.id, " ", icon.get_size())
		model.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var part: AABB = mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Flat fill with a little of the render's shading, a dark outline, cropped with padding.
func _stylise(render: Image) -> Image:
	render.convert(Image.FORMAT_RGBA8)
	var w: int = render.get_width()
	var h: int = render.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y: int in h:
		for x: int in w:
			if render.get_pixel(x, y).a > 0.5:
				solid[y * w + x] = 1
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			if solid[y * w + x] == 1:
				var lum: float = render.get_pixel(x, y).get_luminance()
				var fill: Color = FILL * lerpf(1.0 - SHADE, 1.0 + SHADE * 0.3, clampf(lum * 2.0, 0.0, 1.0))
				fill.a = 1.0
				out.set_pixel(x, y, fill)
			elif _near_solid(solid, w, h, x, y):
				out.set_pixel(x, y, OUTLINE)
	var crop := Rect2i(lo - Vector2i(PAD, PAD), hi - lo + Vector2i(PAD * 2 + 1, PAD * 2 + 1)).intersection(Rect2i(0, 0, w, h))
	return out.get_region(crop)


func _near_solid(solid: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for dy: int in range(-OUTLINE_PX, OUTLINE_PX + 1):
		for dx: int in range(-OUTLINE_PX, OUTLINE_PX + 1):
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and ny >= 0 and nx < w and ny < h and solid[ny * w + nx] == 1:
				return true
	return false

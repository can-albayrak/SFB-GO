class_name ScreenFx
extends CanvasLayer
## Full-screen PS2-style filter over everything (game, HUD, menus), plus the 3D render
## scale. Both follow Settings (graphics section). Added to the root once by Style.

const LAYER: int = 120 ## Above the HUD and menus.
const MATERIAL: ShaderMaterial = preload("res://assets/shaders/ps2_screen.tres")

var _rect: ColorRect


func _ready() -> void:
	layer = LAYER
	_rect = ColorRect.new()
	_rect.material = MATERIAL
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	Settings.changed.connect(_apply)
	_apply()


func _apply() -> void:
	_rect.visible = Settings.post_process
	get_viewport().scaling_3d_scale = Settings.render_scale

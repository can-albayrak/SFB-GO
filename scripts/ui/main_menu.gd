extends Control
## Entry point. Host/Join arrive in stage 2; for now only the test range.

const TEST_RANGE_PATH: String = "res://scenes/maps/test_range.tscn"

@onready var test_range_button: Button = %TestRangeButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	test_range_button.pressed.connect(_on_test_range_pressed)
	quit_button.pressed.connect(get_tree().quit)
	test_range_button.grab_focus()


func _on_test_range_pressed() -> void:
	get_tree().change_scene_to_file(TEST_RANGE_PATH)

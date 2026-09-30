extends Control
## Entry point: name, Host / Join, offline Test Range.
## Command-line shortcuts for local testing (after `--`):
##   --name=Can  --host  --join=127.0.0.1

## Command-line shortcuts run once per launch, not every time the menu is shown.
static var _command_line_handled: bool = false

@onready var name_edit: LineEdit = %NameEdit
@onready var address_edit: LineEdit = %AddressEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var test_range_button: Button = %TestRangeButton
@onready var quit_button: Button = %QuitButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	name_edit.max_length = Net.MAX_NAME_LENGTH
	name_edit.text = Settings.player_name
	status_label.text = Net.last_message

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	test_range_button.pressed.connect(_on_test_range_pressed)
	quit_button.pressed.connect(get_tree().quit)
	_handle_command_line()


func _handle_command_line() -> void:
	if _command_line_handled:
		return
	_command_line_handled = true
	var host: bool = false
	var join_address: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--name="):
			name_edit.text = arg.trim_prefix("--name=")
		elif arg == "--host":
			host = true
		elif arg.begins_with("--join="):
			join_address = arg.trim_prefix("--join=")
	if host:
		_on_host_pressed.call_deferred()
	elif not join_address.is_empty():
		address_edit.text = join_address
		_on_join_pressed.call_deferred()


func _save_name() -> void:
	Settings.player_name = name_edit.text.strip_edges()


func _on_host_pressed() -> void:
	_save_name()
	var err: Error = Net.host_game(Settings.player_name)
	if err != OK:
		status_label.text = "Could not host (port %d busy?)" % Net.DEFAULT_PORT


func _on_join_pressed() -> void:
	_save_name()
	var address: String = address_edit.text.strip_edges()
	if address.is_empty():
		status_label.text = "Enter the host's IP"
		return
	var err: Error = Net.join_game(Settings.player_name, address)
	if err != OK:
		status_label.text = "Could not connect"
		return
	status_label.text = "Connecting to %s..." % address
	_set_buttons_disabled(true)


func _on_test_range_pressed() -> void:
	_save_name()
	Net.start_offline(Settings.player_name)


func _set_buttons_disabled(disabled: bool) -> void:
	for button: Button in [host_button, join_button, test_range_button]:
		button.disabled = disabled

extends Control
## Entry point: name, Host (opens the lobby) / Join / Last host, offline Test Range, Settings.
## Kill target, minutes and map are picked by the host in the lobby.
## Command-line shortcuts for local testing (after `--`):
##   --name=Can  --host  --join=127.0.0.1  --kills=5  --minutes=2
## --host skips the lobby and starts the match at once (headless tests rely on that).

## Command-line shortcuts run once per launch, not every time the menu is shown.
static var _command_line_handled: bool = false

var _cli_kills: int = Match.DEFAULT_RULES.kill_target
var _cli_minutes: float = Match.DEFAULT_RULES.time_limit / 60.0

@onready var name_edit: LineEdit = %NameEdit
@onready var address_edit: LineEdit = %AddressEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var last_host_button: Button = %LastHostButton
@onready var test_range_button: Button = %TestRangeButton
@onready var quit_button: Button = %QuitButton
@onready var settings_button: Button = %SettingsButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	name_edit.max_length = Net.MAX_NAME_LENGTH
	name_edit.text = Settings.player_name
	status_label.text = Net.last_message
	if not Settings.last_host.is_empty():
		address_edit.text = Settings.last_host
	last_host_button.visible = not Settings.last_host.is_empty()
	last_host_button.text = "Last host: %s" % Settings.last_host

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	last_host_button.pressed.connect(_on_last_host_pressed)
	test_range_button.pressed.connect(_on_test_range_pressed)
	quit_button.pressed.connect(get_tree().quit)
	var settings_panel := SettingsPanel.new()
	add_child(settings_panel)
	settings_button.pressed.connect(settings_panel.open)
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
		elif arg.begins_with("--kills="):
			_cli_kills = arg.trim_prefix("--kills=").to_int()
		elif arg.begins_with("--minutes="):
			_cli_minutes = arg.trim_prefix("--minutes=").to_float()
	if host:
		_host_without_lobby.call_deferred()
	elif not join_address.is_empty():
		address_edit.text = join_address
		_on_join_pressed.call_deferred()


func _save_name() -> void:
	Settings.player_name = name_edit.text.strip_edges()
	Settings.save_settings()


func _on_host_pressed() -> void:
	_save_name()
	var err: Error = Net.host_game(Settings.player_name)
	if err != OK:
		status_label.text = "Could not host (port %d busy?)" % Net.DEFAULT_PORT


## Command line --host: old flow, straight into the match with --kills / --minutes.
func _host_without_lobby() -> void:
	_save_name()
	Match.configure(_cli_kills, _cli_minutes)
	var err: Error = Net.host_game(Settings.player_name, Net.DEFAULT_PORT, false)
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


func _on_last_host_pressed() -> void:
	address_edit.text = Settings.last_host
	_on_join_pressed()


func _on_test_range_pressed() -> void:
	_save_name()
	Match.configure(0, 0.0) # Practice: no kill or time limit.
	Net.start_offline(Settings.player_name)


func _set_buttons_disabled(disabled: bool) -> void:
	for button: Button in [host_button, join_button, last_host_button, test_range_button]:
		button.disabled = disabled

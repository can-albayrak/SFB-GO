extends Control
## Entry point: name, Host (opens the lobby) / Join / Last host, offline Test Range, Settings.
## Kill target, minutes and map are picked by the host in the lobby.
## Right side: Steam panel (SteamLink): host a Steam lobby, find friends' games, join one.
## Command-line shortcuts for local testing (after `--`):
##   --name=Can  --host  --join=127.0.0.1  --kills=5  --minutes=2
## --host skips the lobby and starts the match at once (headless tests rely on that).

## Command-line shortcuts run once per launch, not every time the menu is shown.
static var _command_line_handled: bool = false

const STEAM_PANEL_WIDTH: float = 400.0
const STEAM_PANEL_MARGIN: float = 88.0
const STEAM_PANEL_TOP: float = 190.0

var _cli_kills: int = Match.DEFAULT_RULES.kill_target
var _cli_minutes: float = Match.DEFAULT_RULES.time_limit / 60.0
var _steam_host_button: Button
var _steam_find_button: Button
var _steam_list: VBoxContainer

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
	last_host_button.text = "Reconnect to last host  ·  %s" % Settings.last_host

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	last_host_button.pressed.connect(_on_last_host_pressed)
	test_range_button.pressed.connect(_on_test_range_pressed)
	quit_button.pressed.connect(get_tree().quit)
	_build_steam_panel()
	var settings_panel := SettingsPanel.new()
	add_child(settings_panel) # Last child: drawn over the Steam panel and takes its clicks.
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
		_join.call_deferred(false) # Scripted joins spawn at once (headless tests).


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
	_join(true)


## `ask_loadout`: a late joiner picks a loadout before entering the match.
func _join(ask_loadout: bool) -> void:
	_save_name()
	var address: String = address_edit.text.strip_edges()
	if address.is_empty():
		status_label.text = "Enter the host's IP"
		return
	var err: Error = Net.join_game(Settings.player_name, address)
	if err != OK:
		status_label.text = "Could not connect"
		return
	Net.ask_loadout_on_join = ask_loadout
	status_label.text = "Connecting to %s..." % address
	_set_buttons_disabled(true)


func _on_last_host_pressed() -> void:
	address_edit.text = Settings.last_host
	_join(true)


func _on_test_range_pressed() -> void:
	_save_name()
	Match.configure_test_range() # Practice: no limits, endless ammo, no cooldowns.
	Net.start_offline(Settings.player_name)


func _set_buttons_disabled(disabled: bool) -> void:
	for button: Button in [host_button, join_button, last_host_button, test_range_button]:
		button.disabled = disabled
	if _steam_host_button != null:
		_steam_host_button.disabled = disabled
		_steam_find_button.disabled = disabled
		for row: Node in _steam_list.get_children():
			(row as Button).disabled = disabled


# --- Steam ---------------------------------------------------------------------

func _build_steam_panel() -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -STEAM_PANEL_MARGIN - STEAM_PANEL_WIDTH
	panel.offset_right = -STEAM_PANEL_MARGIN
	panel.offset_top = STEAM_PANEL_TOP
	panel.add_theme_constant_override(&"separation", 6)
	add_child(panel)
	panel.add_child(Style.label("STEAM", &"HeaderLabel"))
	if not SteamLink.available:
		var reason: Label = Style.label(SteamLink.unavailable_reason, &"DimLabel")
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(reason)
		return
	panel.add_child(Style.label("Signed in as %s" % SteamLink.get_persona_name(), &"MonoLabel"))
	_steam_host_button = Style.menu_button("HOST ON STEAM")
	_steam_host_button.pressed.connect(_on_steam_host_pressed)
	panel.add_child(_steam_host_button)
	_steam_find_button = Style.menu_button("FIND STEAM GAMES")
	_steam_find_button.pressed.connect(SteamLink.find_lobbies.bind(true))
	panel.add_child(_steam_find_button)
	_steam_list = VBoxContainer.new()
	_steam_list.add_theme_constant_override(&"separation", 2)
	panel.add_child(_steam_list)
	SteamLink.lobbies_found.connect(_on_steam_lobbies_found)
	SteamLink.status_changed.connect(_on_steam_status)
	SteamLink.find_lobbies(false) # Friends' open games are listed right away.


func _on_steam_host_pressed() -> void:
	_save_name()
	if SteamLink.host_lobby(SteamLink.get_player_name()):
		_set_buttons_disabled(true)


func _on_steam_lobbies_found(lobbies: Array[Dictionary]) -> void:
	for child: Node in _steam_list.get_children():
		child.queue_free()
	if status_label.text == SteamLink.SEARCHING_TEXT:
		status_label.text = "No Steam games open" if lobbies.is_empty() else ""
	for lobby: Dictionary in lobbies:
		var host_name: String = str(lobby["host"]).to_upper() if not str(lobby["host"]).is_empty() else "GAME"
		var row: Button = Style.menu_button("JOIN  %s   %d / %d" % [host_name, lobby["players"], lobby["max"]], 16)
		row.pressed.connect(_on_steam_join_pressed.bind(int(lobby["id"])))
		_steam_list.add_child(row)


func _on_steam_join_pressed(lobby_id: int) -> void:
	_save_name()
	Net.ask_loadout_on_join = true
	SteamLink.join_lobby(lobby_id, SteamLink.get_player_name())
	_set_buttons_disabled(true)


func _on_steam_status(text: String, failed: bool) -> void:
	status_label.text = text
	if failed:
		_set_buttons_disabled(false)

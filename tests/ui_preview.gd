extends Node
## Opens one screen with made-up data, for looking at the UI (and capturing frames):
##   godot --path . res://tests/ui_preview.tscn -- --screen=lobby
##   godot --path . --write-movie shot.png --quit-after 30 res://tests/ui_preview.tscn -- --screen=range
## Screens: lobby, loadout, range (offline Test Range: HUD, view model, post-process),
## death (killed by a fall), scoreboard (Tab board shown), and frozen body poses for the
## first-person legs: down (look at your feet), walk, slide; drops (Test Range rules: pickups
## and a falling airdrop crate).
## range also takes --class=N --primary=N --slot=N (roster index, primary choice, weapon slot in
## hand: view model and arms), --special=N (airdrop weapon in slot 3 = key 4),
## --map=res://...tscn (another map), --at=x,y,z --yaw=deg --pitch=deg (camera placement) and
## --hud=off (view model only), --ability=seconds (the Q ability after that long), --fire=seconds (one shot, swing or throw after that long;
## with --alt=1 the right click instead, the knife's heavy stab).
## Nothing is saved: the settings file is left alone.

const FAKE_NAMES: Dictionary[int, String] = {1: "Can", 2: "Grizz", 3: "Volt"}


var _args: Dictionary[String, String] = {}


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			_args[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	_open.call_deferred(_args.get("screen", "lobby"))


func _open(screen: String) -> void:
	get_tree().current_scene = null # Net changes scenes; stay alive as a plain child of root.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	match screen:
		"lobby":
			Net.player_names.assign(FAKE_NAMES)
			Net.ready_peers.assign({2: true, 3: false})
			Net.lobby_kill_target = 20
			Net.lobby_minutes = 10.0
			get_tree().change_scene_to_file(Net.LOBBY_PATH)
		"loadout":
			var menu := LoadoutMenu.new()
			var center := CenterContainer.new()
			center.set_anchors_preset(Control.PRESET_FULL_RECT)
			var back := ColorRect.new()
			back.color = Style.BG
			back.set_anchors_preset(Control.PRESET_FULL_RECT)
			var root := Control.new()
			root.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(root)
			root.add_child(back)
			root.add_child(center)
			center.add_child(menu)
			menu.open(Loadout.make(2, 0, 0))
		"range", "death", "scoreboard", "down", "slide", "walk", "scope", "drops":
			if screen == "drops":
				Match.configure_test_range()
			else:
				Match.configure(20, 10.0)
			Net.player_names.assign({1: "Can"})
			Net.map_path = _args.get("map", Net.DEFAULT_MAP_PATH)
			get_tree().change_scene_to_file(Net.GAME_PATH)
			await get_tree().create_timer(0.5).timeout
			var game: Game = Game.find(get_tree())
			var player := game.players_root.get_node_or_null("1") as Player
			if player != null and screen == "range":
				_place_view(player)
			if screen == "death" and player != null:
				player.server_fall_death()
			elif screen == "drops" and player != null:
				# Pickups ahead, a crate coming down behind them.
				player.set_physics_process(false)
				player.global_position = Vector3(0.0, 0.1, 34.0)
				player.rotation.y = 0.0
				player.look_pitch = deg_to_rad(-4.0)
				var airdrops: AirdropManager = AirdropManager.find(get_tree())
				var id: int = airdrops.server_drop()
				var crate: AirdropCrate = airdrops._crates.get(id)
				if crate != null:
					var to_crate: Vector3 = crate.landing_point - player.global_position
					player.rotation.y = atan2(-to_crate.x, -to_crate.z)
					player.look_pitch = deg_to_rad(12.0)
			elif screen == "scoreboard":
				Input.action_press(&"scoreboard")
			elif player != null and screen in ["down", "slide", "walk", "scope"]:
				_pose_body(player, screen)


## Freezes the local player in a pose to look at the first-person body.
func _pose_body(player: Player, screen: String) -> void:
	player.set_physics_process(false)
	var forward: Vector3 = -player.global_basis.z
	match screen:
		"down":
			player.look_pitch = deg_to_rad(-70.0)
		"walk":
			player.look_pitch = deg_to_rad(-45.0)
			player.velocity = forward * 6.6
		"scope":
			player.loadout = Loadout.make(1, 0, 0)
			player.is_scoped = true
			player.weapon_holder.visible = false
			player.velocity = forward * 2.5 # Walking while scoped: the view blurs.
		"slide":
			player.look_pitch = deg_to_rad(-5.0)
			player.movement.is_sliding = true
			player.head.position.y = Movement.CROUCH_EYE
			player.velocity = forward * 9.0


## Range screen options: class, weapon in hand, camera placement.
func _place_view(player: Player) -> void:
	if _args.has("class"):
		player.loadout = Loadout.make(_args["class"].to_int(), _args.get("primary", "0").to_int(), 0)
	if _args.has("special"):
		player.special_weapon = _args["special"].to_int()
	if _args.has("slot"):
		player.equip(_args["slot"].to_int())
	if _args.has("at"):
		player.set_physics_process(false)
		var parts: PackedStringArray = _args["at"].split(",")
		player.global_position = Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	if _args.has("yaw"):
		player.rotation.y = deg_to_rad(_args["yaw"].to_float())
	if _args.has("pitch"):
		player.look_pitch = deg_to_rad(_args["pitch"].to_float())
	if _args.get("hud", "on") == "off":
		var hud := Game.find(get_tree()).get_node_or_null(^"HUD") as CanvasLayer
		if hud != null:
			hud.visible = false # View model shots: no pause panel when the window is not focused.
	if _args.has("ability"):
		# The Q ability this many seconds after opening (e.g. Sonar on the dummies).
		await get_tree().create_timer(_args["ability"].to_float()).timeout
		if player.ability != null and player.ability.try_use(player.get_aim_origin(), -player.get_aim_basis().z):
			player.requests.send_ability(player.get_aim_origin(), -player.get_aim_basis().z)
	if _args.has("fire"):
		# One shot / swing / throw this many seconds after opening (frames of the animation).
		await get_tree().create_timer(_args["fire"].to_float()).timeout
		if _args.get("alt", "0") == "1": # Right click: the knife's heavy stab.
			var stab := PlayerCommand.new()
			stab.secondary_pressed = true
			player.current_weapon.tick(0.0, stab)
		else:
			player.current_weapon.call(&"_shoot_once")

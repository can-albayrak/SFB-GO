class_name KillFeed
extends VBoxContainer
## Top-right kill feed: "Killer [Weapon] Victim", weapon dim, HS red, lines that involve you
## brighter. Plain PS2-era text with a hard shadow. Entries fade out after a few seconds.

const MAX_ENTRIES: int = 5
const ENTRY_TIME: float = 5.0
const FADE_TIME: float = 0.5
const FONT_SIZE: int = 14
const NORMAL_COLOR: String = "#d6dbe2"
const INVOLVED_COLOR: String = "#ffffff"
const WEAPON_COLOR: String = "#8a94a3"
const HEADSHOT_COLOR: String = "#d24a3c"


func _ready() -> void:
	Events.kill_registered.connect(_on_kill_registered)
	Events.match_started.connect(_clear)


func _on_kill_registered(killer_id: int, victim_id: int, weapon_name: String, headshot: bool) -> void:
	var weapon: String = "[color=%s][%s][/color]" % [WEAPON_COLOR, _escape(weapon_name)]
	var text: String
	if killer_id == victim_id:
		text = "%s  %s" % [_escape(Net.get_player_name(victim_id)), weapon]
	else:
		text = "%s  %s%s  %s" % [_escape(Net.get_player_name(killer_id)), weapon,
			"  [color=%s]HS[/color]" % HEADSHOT_COLOR if headshot else "", _escape(Net.get_player_name(victim_id))]
	var involved: bool = multiplayer.get_unique_id() in [killer_id, victim_id]
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override(&"normal_font_size", FONT_SIZE)
	label.add_theme_color_override(&"default_color", Color(INVOLVED_COLOR if involved else NORMAL_COLOR))
	label.add_theme_color_override(&"font_shadow_color", Style.SHADOW)
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	label.text = text
	add_child(label)
	while get_child_count() > MAX_ENTRIES:
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()

	var tween := label.create_tween()
	tween.tween_interval(ENTRY_TIME)
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(label.queue_free)


func _clear() -> void:
	for child: Node in get_children():
		child.queue_free()


## Names and weapons go into BBCode: keep their brackets literal.
func _escape(text: String) -> String:
	return text.replace("[", "[lb]")

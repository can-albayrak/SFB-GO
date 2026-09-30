class_name KillFeed
extends VBoxContainer
## Top-right kill feed: "Killer [Weapon] Victim". Entries fade out after a few seconds.

const MAX_ENTRIES: int = 5
const ENTRY_TIME: float = 5.0
const FADE_TIME: float = 0.5
const FONT_SIZE: int = 20
const NORMAL_COLOR: Color = Color(1.0, 1.0, 1.0)
const INVOLVED_COLOR: Color = Color(1.0, 0.85, 0.35)


func _ready() -> void:
	Events.kill_registered.connect(_on_kill_registered)
	Events.match_started.connect(_clear)


func _on_kill_registered(killer_id: int, victim_id: int, weapon_name: String, headshot: bool) -> void:
	var text: String
	if killer_id == victim_id:
		text = "%s  [%s]" % [Net.get_player_name(victim_id), weapon_name]
	else:
		text = "%s  [%s%s]  %s" % [
			Net.get_player_name(killer_id), weapon_name, " · HS" if headshot else "", Net.get_player_name(victim_id)]
	var local_id: int = multiplayer.get_unique_id()
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_color_override(&"font_color",
		INVOLVED_COLOR if local_id in [killer_id, victim_id] else NORMAL_COLOR)
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

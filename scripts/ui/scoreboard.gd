class_name Scoreboard
extends PanelContainer
## Tab scoreboard: rank, name, kills, deaths. Rebuilt whenever scores change.

const FONT_SIZE: int = 22
const LOCAL_COLOR: Color = Color(1.0, 0.85, 0.35)
const ROW_COLOR: Color = Color(1.0, 1.0, 1.0)
const HEADER_COLOR: Color = Color(0.7, 0.7, 0.7)

@onready var _title: Label = $VBox/Title
@onready var _grid: GridContainer = $VBox/Grid


func _ready() -> void:
	Events.scores_changed.connect(refresh)
	Net.players_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	var target_text: String = "First to %d" % Match.rules.kill_target if Match.rules.kill_target > 0 else "No kill limit"
	_title.text = "FREE FOR ALL  ·  %s" % target_text
	for child: Node in _grid.get_children():
		child.queue_free()
	for text: String in ["#", "PLAYER", "KILLS", "DEATHS"]:
		_add_cell(text, HEADER_COLOR)
	var rank: int = 1
	for peer_id: int in Match.get_ranking():
		var color: Color = LOCAL_COLOR if peer_id == multiplayer.get_unique_id() else ROW_COLOR
		_add_cell(str(rank), color)
		_add_cell(Net.get_player_name(peer_id), color)
		_add_cell(str(Match.get_kills(peer_id)), color)
		_add_cell(str(Match.get_deaths(peer_id)), color)
		rank += 1


func _add_cell(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_color_override(&"font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(label)

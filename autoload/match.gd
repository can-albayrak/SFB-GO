extends Node
## Free-for-all match rules and state: scores, kill target, timer, end of match, awards.
## The host owns all state and pushes every change to in-game peers; clients only mirror it.
## Game (the match scene) drives it: server_begin / server_add_player / server_register_kill.

enum State { PLAYING, ENDED }

const DEFAULT_RULES: MatchDef = preload("res://data/match/default.tres")

var rules: MatchDef = DEFAULT_RULES.duplicate()
var state: State = State.PLAYING
## Seconds left; counts down on every peer (the host re-sends it on join and restart).
var time_left: float = 0.0
## Seconds until the next match while ENDED; counts down on every peer.
var end_screen_left: float = 0.0
var kills: Dictionary[int, int] = {}
var deaths: Dictionary[int, int] = {}
## True while a Game scene is running.
var active: bool = false
## Last finished match (kept for late joiners during the end screen). -1 = draw.
var winner_id: int = -1
var awards: Array = []

# Host-only stats for end-of-match awards.
var _self_kills: Dictionary[int, int] = {}
var _longest_headshot: Dictionary[int, float] = {}
var _knife_kills: Dictionary[int, int] = {}
var _match_serial: int = 0


## Host menu: set rules for the next hosted game. 0 disables a limit (offline test range).
func configure(kill_target: int, time_limit_minutes: float) -> void:
	rules = DEFAULT_RULES.duplicate()
	rules.kill_target = kill_target
	rules.time_limit = time_limit_minutes * 60.0


func has_time_limit() -> bool:
	return rules.time_limit > 0.0


func get_kills(peer_id: int) -> int:
	return kills.get(peer_id, 0)


func get_deaths(peer_id: int) -> int:
	return deaths.get(peer_id, 0)


## Peer ids ordered by kills (desc), then deaths (asc), then peer id so every peer agrees.
func get_ranking() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(kills.keys())
	ids.sort_custom(func(a: int, b: int) -> bool:
		if get_kills(a) != get_kills(b):
			return get_kills(a) > get_kills(b)
		if get_deaths(a) != get_deaths(b):
			return get_deaths(a) < get_deaths(b)
		return a < b)
	return ids


## The current sole leader with at least one kill, or -1 (tie on kills or nobody scored).
func get_leader() -> int:
	var ranking: Array[int] = get_ranking()
	if ranking.is_empty() or get_kills(ranking[0]) == 0:
		return -1
	if ranking.size() > 1 and get_kills(ranking[1]) == get_kills(ranking[0]):
		return -1
	return ranking[0]


func _process(delta: float) -> void:
	if not active:
		return
	if state == State.ENDED:
		end_screen_left = maxf(end_screen_left - delta, 0.0)
		return
	if not has_time_limit():
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0 and multiplayer.is_server():
		_end_match()


# --- Host API (called by Game) ---------------------------------------------

func server_begin() -> void:
	assert(multiplayer.is_server(), "server_begin is host-only")
	active = true
	_match_serial += 1
	kills.clear()
	deaths.clear()
	_reset_scores()
	state = State.PLAYING
	time_left = rules.time_limit


## Every peer, when the match scene closes. Nothing leaks into the next session.
func end_session() -> void:
	active = false
	_match_serial += 1
	kills.clear()
	deaths.clear()
	state = State.PLAYING
	rules = DEFAULT_RULES.duplicate()
	time_left = 0.0
	end_screen_left = 0.0
	winner_id = -1
	awards = []


## Adds a peer to the scoreboard and sends it the full match state.
func server_add_player(peer_id: int) -> void:
	assert(multiplayer.is_server(), "server_add_player is host-only")
	kills[peer_id] = kills.get(peer_id, 0)
	deaths[peer_id] = deaths.get(peer_id, 0)
	if peer_id != 1:
		_sync_full.rpc_id(peer_id, _snapshot())
	Net.broadcast(self, &"_sync_scores", [kills, deaths])


func server_remove_player(peer_id: int) -> void:
	kills.erase(peer_id)
	deaths.erase(peer_id)
	_self_kills.erase(peer_id)
	_longest_headshot.erase(peer_id)
	_knife_kills.erase(peer_id)
	Net.broadcast(self, &"_sync_scores", [kills, deaths])


func server_register_kill(killer_id: int, victim_id: int, weapon_name: String, headshot: bool, distance: float, is_melee: bool) -> void:
	assert(multiplayer.is_server(), "server_register_kill is host-only")
	if state != State.PLAYING:
		return
	if killer_id not in kills:
		killer_id = victim_id # Killer left (e.g. their grenade outlived them): count as a self-kill.
	var self_kill: bool = killer_id == victim_id
	deaths[victim_id] = get_deaths(victim_id) + 1
	if self_kill:
		_self_kills[victim_id] = _self_kills.get(victim_id, 0) + 1
	else:
		kills[killer_id] = get_kills(killer_id) + 1
		if headshot:
			_longest_headshot[killer_id] = maxf(_longest_headshot.get(killer_id, 0.0), distance)
		if is_melee:
			_knife_kills[killer_id] = _knife_kills.get(killer_id, 0) + 1
	Net.broadcast(self, &"_on_kill", [killer_id, victim_id, weapon_name, headshot, get_kills(killer_id), get_deaths(victim_id)])
	if not self_kill and rules.kill_target > 0 and get_kills(killer_id) >= rules.kill_target:
		_end_match()


# --- Host internals --------------------------------------------------------

func _reset_scores() -> void:
	for peer_id: int in kills.keys():
		kills[peer_id] = 0
		deaths[peer_id] = 0
	_self_kills.clear()
	_longest_headshot.clear()
	_knife_kills.clear()


func _snapshot() -> Dictionary:
	return {
		"state": state,
		"time_left": time_left,
		"end_screen_left": end_screen_left,
		"kill_target": rules.kill_target,
		"time_limit": rules.time_limit,
		"kills": kills,
		"deaths": deaths,
		"winner_id": winner_id,
		"awards": awards,
	}


## Winner = sole top player with at least one kill; a full tie or no kills is a draw (-1).
func _pick_winner() -> int:
	var ranking: Array[int] = get_ranking()
	if ranking.is_empty() or get_kills(ranking[0]) == 0:
		return -1
	if ranking.size() > 1:
		var a: int = ranking[0]
		var b: int = ranking[1]
		if get_kills(a) == get_kills(b) and get_deaths(a) == get_deaths(b):
			return -1
	return ranking[0]


func _end_match() -> void:
	state = State.ENDED
	Net.broadcast(self, &"_on_match_ended", [_pick_winner(), _compute_awards(), rules.end_screen_time])
	var serial: int = _match_serial
	get_tree().create_timer(rules.end_screen_time).timeout.connect(_restart.bind(serial))


func _restart(serial: int) -> void:
	# The serial guards against a timer from a previous game session.
	if not active or serial != _match_serial or not multiplayer.is_server():
		return
	_reset_scores()
	state = State.PLAYING
	time_left = rules.time_limit
	Net.broadcast(self, &"_on_match_started", [time_left, kills, deaths])


## Array of [title, peer_id, detail].
func _compute_awards() -> Array:
	var result: Array = []
	var most_deaths: int = _best_key(deaths)
	if most_deaths != -1:
		result.append(["Most Deaths", most_deaths, "%d deaths" % get_deaths(most_deaths)])
	var knifer: int = _best_key(_knife_kills)
	if knifer != -1:
		result.append(["Most Knife Kills", knifer, "%d" % _knife_kills[knifer]])
	var longest: int = _best_key(_longest_headshot)
	if longest != -1:
		result.append(["Longest Headshot", longest, "%.0f m" % _longest_headshot[longest]])
	var self_killer: int = _best_key(_self_kills)
	if self_killer != -1:
		result.append(["Most Self-Kills", self_killer, "%d" % _self_kills[self_killer]])
	return result


## Key with the highest positive value, or -1.
func _best_key(values: Dictionary) -> int:
	var best_id: int = -1
	var best_value: float = 0.0
	for peer_id: int in values:
		var value: float = values[peer_id]
		if value > best_value:
			best_value = value
			best_id = peer_id
	return best_id


func _from_host() -> bool:
	return multiplayer.get_remote_sender_id() <= 1


# --- RPCs (host -> peers) --------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _sync_full(snapshot: Dictionary) -> void:
	if not _from_host():
		return
	active = true
	state = snapshot["state"]
	time_left = snapshot["time_left"]
	end_screen_left = snapshot["end_screen_left"]
	rules = DEFAULT_RULES.duplicate()
	rules.kill_target = snapshot["kill_target"]
	rules.time_limit = snapshot["time_limit"]
	kills.assign(snapshot["kills"])
	deaths.assign(snapshot["deaths"])
	winner_id = snapshot["winner_id"]
	awards = snapshot["awards"]
	Events.scores_changed.emit()
	if state == State.ENDED:
		Events.match_ended.emit(winner_id, awards)


@rpc("any_peer", "call_local", "reliable")
func _sync_scores(new_kills: Dictionary, new_deaths: Dictionary) -> void:
	if not _from_host():
		return
	kills.assign(new_kills)
	deaths.assign(new_deaths)
	Events.scores_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _on_kill(killer_id: int, victim_id: int, weapon_name: String, headshot: bool, killer_kills: int, victim_deaths: int) -> void:
	if not _from_host():
		return
	if killer_id != victim_id:
		kills[killer_id] = killer_kills
	deaths[victim_id] = victim_deaths
	Events.kill_registered.emit(killer_id, victim_id, weapon_name, headshot)
	Events.scores_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _on_match_ended(new_winner_id: int, new_awards: Array, end_time: float) -> void:
	if not _from_host():
		return
	state = State.ENDED
	winner_id = new_winner_id
	awards = new_awards
	end_screen_left = end_time
	Events.match_ended.emit(winner_id, awards)


@rpc("any_peer", "call_local", "reliable")
func _on_match_started(new_time_left: float, new_kills: Dictionary, new_deaths: Dictionary) -> void:
	if not _from_host():
		return
	state = State.PLAYING
	time_left = new_time_left
	kills.assign(new_kills)
	deaths.assign(new_deaths)
	winner_id = -1
	awards = []
	Events.match_started.emit()
	Events.scores_changed.emit()

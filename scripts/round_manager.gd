extends Node

## Server-side round manager for charades gameplay.
## Manages actor selection, round timing, word bank, and turn flow.

enum State { WAITING, CHOOSING_ACTOR, ACTOR_READY, IN_ROUND, ROUND_END }

signal round_started(actor_peer_id: int, prompt: String)
signal round_ended(winner_peer_id: int)
signal actor_changed(peer_id: int)
signal state_changed(new_state: State)
signal timer_updated(time_remaining: float)
signal reset_all_animations


@rpc("any_peer", "call_remote", "reliable")
func _rpc_reset_all_animations() -> void:
	reset_all_animations.emit()

@export var round_time: float = 90.0
@export var prep_time: float = 5.0
@export var end_pause: float = 3.0

var current_state: State = State.WAITING
var current_actor_peer_id: int = 0
var current_prompt: String = ""
var time_remaining: float = 0.0
var rounds_won: Dictionary = {}

var _actor_pool: Array[int] = []
var _used_prompts: Array[int] = []
var _all_peers: Array[int] = []

const WORD_BANK: Array[String] = [
	"Mario jumping on a Goomba",
	"Link opening a treasure chest",
	"Pac-Man eating pellets",
	"Angry Birds launching from a slingshot",
	"Minecraft mining a diamond ore",
	"Tetris clearing four lines at once",
	"Sonic collecting gold rings",
	"Street Fighter performing a Hadouken",
	"Portal placing a blue and orange portal",
	"Guitar Hero shredding a guitar solo",
	"The Matrix - dodging bullets in slow motion",
	"Jurassic Park - T-Rex breaking through the fence",
	"Titanic - \"I'm the king of the world\" pose on a ship",
	"The Lord of the Rings - throwing a ring into a volcano",
	"Star Wars - lightsaber duel",
	"Friends - the \"We were on a break!\" argument",
	"The Office - Dwight's martial arts moves",
	"Breaking Bad - putting on a hazmat suit",
	"The Lion King - Rafiki holding up Simba on Pride Rock",
	"Harry Potter - casting a spell with a wand",
]


func _ready() -> void:
	if not multiplayer.is_server():
		set_process(false)
		set_physics_process(false)
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


var _last_sync_time: float = 0.0


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	match current_state:
		State.ACTOR_READY:
			time_remaining -= delta
			time_remaining = maxf(time_remaining, 0.0)
			timer_updated.emit(time_remaining)
			_sync_timer_if_needed()
			if time_remaining <= 0.0:
				_begin_round()
		State.IN_ROUND:
			time_remaining -= delta
			time_remaining = maxf(time_remaining, 0.0)
			timer_updated.emit(time_remaining)
			_sync_timer_if_needed()
			if time_remaining <= 0.0:
				_end_round(0)
		State.ROUND_END:
			time_remaining -= delta
			time_remaining = maxf(time_remaining, 0.0)
			timer_updated.emit(time_remaining)
			_sync_timer_if_needed()
			if time_remaining <= 0.0:
				_choose_next_actor()


func _sync_timer_if_needed() -> void:
	var current_second: int = int(time_remaining)
	if current_second != int(_last_sync_time) or time_remaining <= 1.0:
		_sync_timer.rpc(time_remaining)
		_last_sync_time = time_remaining


func start_game() -> void:
	if not multiplayer.is_server():
		return
	_refresh_peer_list()
	_actor_pool = _all_peers.duplicate()
	_used_prompts.clear()
	rounds_won.clear()
	for peer_id in _all_peers:
		rounds_won[peer_id] = 0
	_choose_next_actor()


func set_round_time(time: float) -> void:
	round_time = maxf(time, 10.0)


func declare_winner(winner_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if current_state != State.IN_ROUND:
		return
	if winner_peer_id == current_actor_peer_id:
		return
	if not rounds_won.has(winner_peer_id):
		rounds_won[winner_peer_id] = 0
	rounds_won[winner_peer_id] += 1
	_end_round(winner_peer_id)


func _get_players_node() -> Node3D:
	var parent: Node = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("Players") as Node3D


func _get_spotlight() -> SpotLight3D:
	var parent: Node = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("CenterSpotlight") as SpotLight3D


func _refresh_peer_list() -> void:
	_all_peers.clear()
	_all_peers.append(1)
	for peer_id in multiplayer.get_peers():
		if peer_id != 1:
			_all_peers.append(peer_id)


func _choose_next_actor() -> void:
	current_state = State.CHOOSING_ACTOR
	state_changed.emit(current_state)

	if _actor_pool.is_empty():
		_actor_pool = _all_peers.duplicate()

	_actor_pool.shuffle()
	current_actor_peer_id = _actor_pool.pop_back()

	current_prompt = _pick_prompt()
	time_remaining = prep_time

	_apply_roles_on_all_peers()
	_sync_actor_info.rpc(current_actor_peer_id, current_prompt)
	actor_changed.emit(current_actor_peer_id)

	current_state = State.ACTOR_READY
	state_changed.emit(current_state)
	_last_sync_time = -1.0
	_sync_timer.rpc(time_remaining)


func _pick_prompt() -> String:
	if _used_prompts.size() >= WORD_BANK.size():
		_used_prompts.clear()

	var available: Array[int] = []
	for i in WORD_BANK.size():
		if i not in _used_prompts:
			available.append(i)

	available.shuffle()
	var idx: int = available[0]
	_used_prompts.append(idx)
	return WORD_BANK[idx]


func _begin_round() -> void:
	current_state = State.IN_ROUND
	time_remaining = round_time
	state_changed.emit(current_state)
	round_started.emit(current_actor_peer_id, current_prompt)
	_sync_state.rpc(State.IN_ROUND)
	_last_sync_time = -1.0
	_sync_timer.rpc(time_remaining)
	_set_spotlight_enabled(true)


func _end_round(winner_peer_id: int) -> void:
	current_state = State.ROUND_END
	time_remaining = end_pause
	state_changed.emit(current_state)
	round_ended.emit(winner_peer_id)
	_sync_state.rpc(State.ROUND_END)
	_last_sync_time = -1.0
	_sync_timer.rpc(time_remaining)
	_set_spotlight_enabled(false)
	_sync_winner.rpc(winner_peer_id)
	reset_all_animations.emit()
	_rpc_reset_all_animations.rpc()


func _apply_roles_on_all_peers() -> void:
	var players: Node3D = _get_players_node()
	if players == null:
		return
	for child in players.get_children():
		var pid: int = child.get_meta("peer_id", int(child.name))
		var is_actor: bool = (pid == current_actor_peer_id)
		child.set_meta("is_actor", is_actor)
		if child.has_method("set_role"):
			child.set_role(is_actor)


func _set_spotlight_enabled(enabled: bool) -> void:
	var spot: SpotLight3D = _get_spotlight()
	if spot != null:
		spot.visible = enabled
	_sync_spotlight.rpc(enabled)


func _on_peer_connected(id: int) -> void:
	_refresh_peer_list()
	if current_state == State.WAITING:
		return
	_sync_state.rpc_id(id, current_state)
	_sync_actor_info.rpc_id(id, current_actor_peer_id, current_prompt)
	_sync_timer.rpc_id(id, time_remaining)


func _on_peer_disconnected(id: int) -> void:
	_refresh_peer_list()
	_actor_pool = _actor_pool.filter(func(pid: int) -> bool: return pid != id)
	if id == current_actor_peer_id and current_state == State.IN_ROUND:
		_end_round(0)


@rpc("any_peer", "call_remote", "reliable")
func _sync_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(new_state)


@rpc("any_peer", "call_remote", "reliable")
func _sync_actor_info(peer_id: int, prompt: String) -> void:
	current_actor_peer_id = peer_id
	current_prompt = prompt
	actor_changed.emit(peer_id)
	_apply_roles_on_all_peers()


@rpc("any_peer", "call_remote", "reliable")
func _sync_timer(time: float) -> void:
	time_remaining = time
	timer_updated.emit(time)





@rpc("any_peer", "call_remote", "reliable")
func _sync_spotlight(enabled: bool) -> void:
	var spot: SpotLight3D = _get_spotlight()
	if spot != null:
		spot.visible = enabled


@rpc("any_peer", "call_remote", "reliable")
func _sync_winner(_winner_peer_id: int) -> void:
	pass

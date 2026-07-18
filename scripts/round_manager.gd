extends Node

## Server-side round manager for charades gameplay.
## Manages actor selection, round timing, word bank, and turn flow.

enum State { WAITING, CHOOSING_ACTOR, ACTOR_READY, IN_ROUND, ROUND_END }

signal round_started(actor_peer_id: int, prompt: String)
signal round_ended
signal actor_changed(peer_id: int)
signal state_changed(new_state: State)
signal timer_updated(time_remaining: float)
signal reset_all_animations
signal correct_answer(peer_id: int, display_name: String)
signal actor_options_received(options: Array[String])


@export var round_time: float = 30.0
@export var prep_time: float = 3.0
@export var end_pause: float = 3.0

var current_state: State = State.WAITING
var current_actor_peer_id: int = 0
var current_prompt: String = ""
var current_topic_id: String = ""
var time_remaining: float = 0.0
var winner_peer_id: int = 0
var winner_name: String = ""

var _actor_pool: Array[int] = []
var _used_prompts: Array[int] = []
var _all_peers: Array[int] = []
var _word_bank: Array[String] = []
var _last_offered_options: Array[String] = []
var _data_manager: Node = null


func _ready() -> void:
	add_to_group("round_manager")
	_data_manager = _find_data_manager()
	if not multiplayer.is_server():
		set_process(false)
		set_physics_process(false)
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if _data_manager != null:
		_data_manager.data_initialized.connect(_on_data_initialized)


func _find_data_manager() -> Node:
	return get_tree().get_first_node_in_group("guessing_data_manager")


func _on_data_initialized() -> void:
	if _data_manager != null:
		_word_bank = _data_manager.get_word_bank()
		if _word_bank.is_empty():
			push_warning("RoundManager: Word bank is empty!")


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	match current_state:
		State.ACTOR_READY:
			time_remaining -= delta
			time_remaining = maxf(time_remaining, 0.0)
			timer_updated.emit(time_remaining)
			if time_remaining <= 0.0:
				_begin_round()
		State.IN_ROUND:
			time_remaining -= delta
			time_remaining = maxf(time_remaining, 0.0)
			timer_updated.emit(time_remaining)
			if time_remaining <= 0.0:
				_end_round()
		State.ROUND_END:
			time_remaining -= delta
			time_remaining = maxf(time_remaining, 0.0)
			timer_updated.emit(time_remaining)
			if time_remaining <= 0.0:
				_choose_next_actor()


func begin_game() -> void:
	if not multiplayer.is_server():
		return
	if current_state != State.WAITING:
		return
	_refresh_peer_list()
	if _word_bank.is_empty() and _data_manager != null:
		_word_bank = _data_manager.get_word_bank()
	_choose_next_actor()


func set_round_time(time: float) -> void:
	round_time = maxf(time, 30.0)


func _get_spotlight() -> SpotLight3D:
	var parent: Node = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("CenterSpotlight") as SpotLight3D


func _refresh_peer_list() -> void:
	_all_peers.clear()
	_all_peers.append(1)
	for peer: int in multiplayer.get_peers():
		_all_peers.append(peer)


func _choose_next_actor() -> void:
	winner_peer_id = 0
	winner_name = ""
	current_state = State.CHOOSING_ACTOR
	state_changed.emit(current_state)

	if _actor_pool.is_empty():
		_actor_pool = _all_peers.duplicate()

	_actor_pool.shuffle()
	current_actor_peer_id = _actor_pool.pop_back()

	var options: Array[String] = _pick_three_prompts()
	_last_offered_options = options
	time_remaining = prep_time

	_sync_actor_options.rpc(current_actor_peer_id, options)

	current_state = State.ACTOR_READY
	state_changed.emit(current_state)
	_sync_state.rpc(State.ACTOR_READY)


func _pick_three_prompts() -> Array[String]:
	var options: Array[String] = []
	var attempts: int = 0
	while options.size() < 3 and attempts < 10:
		var prompt: String = _pick_prompt()
		if prompt not in options:
			options.append(prompt)
		attempts += 1
	return options


func _pick_prompt() -> String:
	if _word_bank.is_empty():
		return ""
	if _used_prompts.size() >= _word_bank.size():
		_used_prompts.clear()

	var available: Array[int] = []
	for i: int in _word_bank.size():
		if i not in _used_prompts:
			available.append(i)

	available.shuffle()
	var idx: int = available[0]
	_used_prompts.append(idx)
	return _word_bank[idx]


func _begin_round() -> void:
	if current_prompt.is_empty() and not _last_offered_options.is_empty():
		current_prompt = _last_offered_options.pick_random()
		_sync_actor_info.rpc(current_actor_peer_id, current_prompt)
	current_state = State.IN_ROUND
	time_remaining = round_time
	state_changed.emit(current_state)
	round_started.emit(current_actor_peer_id, current_prompt)
	_sync_state.rpc(State.IN_ROUND)
	_set_spotlight_enabled(true)


func _end_round() -> void:
	current_state = State.ROUND_END
	time_remaining = end_pause
	state_changed.emit(current_state)
	round_ended.emit()
	_sync_state.rpc(State.ROUND_END)
	_set_spotlight_enabled(false)
	_sync_actor_info.rpc(0, "")


func _set_spotlight_enabled(enabled: bool) -> void:
	var spot: SpotLight3D = _get_spotlight()
	if spot != null:
		spot.visible = enabled


func _on_peer_connected(id: int) -> void:
	_refresh_peer_list()
	if current_state == State.WAITING:
		return
	_sync_state.rpc_id(id, current_state)
	_sync_actor_info.rpc_id(id, current_actor_peer_id, current_prompt)


func _on_peer_disconnected(id: int) -> void:
	_refresh_peer_list()
	_actor_pool = _actor_pool.filter(func(pid: int) -> bool: return pid != id)
	if id == current_actor_peer_id and current_state == State.IN_ROUND:
		_end_round()


@rpc("any_peer", "call_local", "reliable")
func _sync_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(new_state)
	if new_state == State.ROUND_END:
		reset_all_animations.emit()


@rpc("any_peer", "call_local", "reliable")
func _sync_actor_info(peer_id: int, prompt: String) -> void:
	current_actor_peer_id = peer_id
	current_prompt = prompt
	actor_changed.emit(peer_id)


@rpc("authority", "call_local", "reliable")
func _sync_actor_options(peer_id: int, options: Array[String]) -> void:
	current_actor_peer_id = peer_id
	actor_changed.emit(peer_id)
	actor_options_received.emit(options)


@rpc("any_peer", "call_local", "reliable")
func actor_selected_prompt(prompt: String) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != current_actor_peer_id:
		return
	current_prompt = prompt
	_last_offered_options.clear()
	_sync_actor_info.rpc(current_actor_peer_id, current_prompt)
	time_remaining = prep_time


@rpc("any_peer", "call_local", "reliable")
func submit_guess(guess: String) -> void:
	if not multiplayer.is_server():
		return
	if current_state != State.IN_ROUND:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == current_actor_peer_id:
		return
	if sender_id == 0:
		return
	if guess.strip_edges().to_lower() == current_prompt.strip_edges().to_lower():
		winner_peer_id = sender_id
		var game_manager: Node = get_parent()
		var peer_list: Dictionary = game_manager._peer_list if game_manager else {}
		var winner_info: Dictionary = peer_list.get(sender_id, {})
		winner_name = winner_info.get("name", "Player %d" % sender_id)
		_sync_winner.rpc(sender_id, winner_name)
		_end_round()


@rpc("authority", "call_local", "reliable")
func _sync_winner(peer_id: int, display_name: String) -> void:
	winner_peer_id = peer_id
	winner_name = display_name
	correct_answer.emit(peer_id, display_name)

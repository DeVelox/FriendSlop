extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/proto_controller.tscn")

const ACTOR_POSITION: Vector3 = Vector3(0.0, 1.0, 23.0)
const STAGE_FORWARD: Vector3 = Vector3(0.0, 0.0, -1.0)

signal players_changed

@onready var players: Node3D = $Multiplayer/Players
@onready var round_manager: Node = $RoundManager
@onready var spotlight: SpotLight3D = $CenterSpotlight
@onready var camera: Camera3D = $StageCamera

var _audience_slots: Array[Vector3] = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	round_manager.actor_changed.connect(_on_actor_changed)
	round_manager.round_started.connect(_on_round_started)
	round_manager.round_ended.connect(_on_round_ended)

	_build_audience_slots()

	if multiplayer.is_server():
		#_spawn_all_current_players()
		_spawn_player(1)
		await get_tree().process_frame
		round_manager.start_game()
	else:
		_player_is_ready.rpc_id(1)


func _build_audience_slots() -> void:
	_audience_slots.clear()
	var max_players: int = 6
	if Steamworks.lobby_id > 0:
		var lobby_limit: int = Steam.getLobbyMemberLimit(Steamworks.lobby_id)
		if lobby_limit > 0:
			max_players = lobby_limit
	var slot_count: int = maxi(max_players - 1, 1)
	var spread_dir: Vector3 = STAGE_FORWARD.cross(Vector3.UP).normalized()
	var center: Vector3 = ACTOR_POSITION + STAGE_FORWARD * 10.0
	center.y = 0.5

	var front_row_count: int = mini(slot_count, 5)
	var back_row_count: int = slot_count - front_row_count

	var front_spread: float = float(front_row_count) * 2.5
	for i in front_row_count:
		var t: float = float(i) / maxf(front_row_count - 1, 1) - 0.5
		var pos: Vector3 = center + spread_dir * t * front_spread
		_audience_slots.append(pos)

	if back_row_count > 0:
		var back_spread: float = float(back_row_count) * 2.5
		var back_center: Vector3 = center + STAGE_FORWARD * 3.0
		for i in back_row_count:
			var t: float = float(i) / maxf(back_row_count - 1, 1) - 0.5
			var pos: Vector3 = back_center + spread_dir * t * back_spread
			_audience_slots.append(pos)


func _get_audience_position(index: int) -> Vector3:
	if index < _audience_slots.size():
		return _audience_slots[index]
	return Vector3(0.0, 0.5, 20.0)
	
func _get_audience_rotation() -> float:
	return STAGE_FORWARD.angle_to(Vector3.BACK)


func _get_actor_position() -> Vector3:
	return ACTOR_POSITION


func _get_actor_rotation() -> float:
	return STAGE_FORWARD.angle_to(Vector3.FORWARD)


func _get_all_peer_ids() -> Array[int]:
	var ids: Array[int] = [1]
	for pid in multiplayer.get_peers():
		if pid != 1:
			ids.append(pid)
	var local_id: int = multiplayer.get_unique_id()
	if local_id != 1 and local_id not in ids:
		ids.append(local_id)
	ids.sort()
	return ids


func _spawn_all_current_players() -> void:
	for pid in _get_all_peer_ids():
		if not players.has_node(str(pid)):
			_spawn_player(pid)
	players_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _player_is_ready() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	if not players.has_node(str(sender_id)):
		_spawn_player(sender_id)

	# Send existing peer list to the new client so they create local instances
	for pid in _get_all_peer_ids():
		if pid != sender_id and not players.has_node(str(pid)):
			_spawn_player(pid)
	players_changed.emit()


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if not players.has_node(str(id)):
		_spawn_player(id)
	players_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()
	players_changed.emit()


func _on_server_disconnected() -> void:
	printerr("Server disconnected, returning to lobby")
	if Engine.has_singleton("Steam") and Steamworks.lobby_id > 0:
		Steam.leaveLobby(Steamworks.lobby_id)
		Steamworks.lobby_id = 0
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file.call_deferred("res://addons/godotsteamkit/starters/lobbies/lobby_manager.tscn")


func _spawn_player(id: int) -> void:
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.name = str(id)

	var peer_ids: Array[int] = _get_all_peer_ids()

	var is_actor: bool = (id == round_manager.current_actor_peer_id)
	if is_actor:
		player.position = _get_actor_position()
		player.rotation.y = _get_actor_rotation()
	else:
		var audience_index: int = peer_ids.find(id)
		if audience_index == -1:
			audience_index = 0
		player.position = _get_audience_position(audience_index)
		player.rotation.y = _get_audience_rotation()

	player.set_meta("peer_id", id)
	players.add_child(player, true)


@rpc("any_peer", "call_remote", "reliable")
func declare_winner_rpc(winner_peer_id: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if sender != round_manager.current_actor_peer_id:
		return
	round_manager.declare_winner(winner_peer_id)


func _on_actor_changed(peer_id: int) -> void:
	var peer_ids: Array[int] = _get_all_peer_ids()
	for child in players.get_children():
		var pid: int = child.get_meta("peer_id", int(child.name))
		var is_child_actor: bool = (pid == peer_id)
		if child.has_method("set_role"):
			child.set_role(is_child_actor)
		if pid != peer_id:
			var idx: int = peer_ids.find(pid)
			if idx == -1:
				idx = 0
			child.position = _get_audience_position(idx)
			child.rotation.y = PI
		else:
			child.position = _get_actor_position()
			child.rotation.y = _get_actor_rotation()


func _on_round_started(_actor_peer_id: int, _prompt: String) -> void:
	spotlight.visible = true


func _on_round_ended(_winner_peer_id: int) -> void:
	spotlight.visible = false

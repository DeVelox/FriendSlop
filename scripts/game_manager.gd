extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/proto_controller.tscn")

const ACTOR_POSITION: Vector3 = Vector3(0.0, 1.0, 23.0)
const STAGE_FORWARD: Vector3 = Vector3(0.0, 0.0, -1.0)

@onready var players: Node3D = $Players
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
		_spawn_all_current_players()

		await get_tree().process_frame
		round_manager.start_game()
	else:
		_request_peer_list.rpc_id(1)


func _build_audience_slots() -> void:
	_audience_slots.clear()
	var slot_count: int = 11
	var z_start: float = 15.0
	var z_end: float = 25.0
	var z_step: float = (z_end - z_start) / maxf(slot_count - 1, 1)
	var x_spread: float = 6.0

	for i in slot_count:
		var z: float = z_start + (z_step * i)
		var x: float = sin(float(i) / float(slot_count - 1) * PI - PI / 2.0) * x_spread
		_audience_slots.append(Vector3(x, 0.5, z))


func _get_audience_position(index: int) -> Vector3:
	if index < _audience_slots.size():
		return _audience_slots[index]
	return Vector3(0.0, 0.5, 20.0)


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


func _on_peer_connected(id: int) -> void:
	if not players.has_node(str(id)):
		_spawn_player(id)
	if multiplayer.is_server():
		_receive_peer_list.rpc_id(id, _get_all_peer_ids(), round_manager.current_actor_peer_id)


func _on_peer_disconnected(id: int) -> void:
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()


func _on_server_disconnected() -> void:
	printerr("Server disconnected, returning to lobby")
	multiplayer.multiplayer_peer = null
	if Engine.has_singleton("Steam") and Steamworks.lobby_id > 0:
		Steam.leaveLobby(Steamworks.lobby_id)
		Steamworks.lobby_id = 0
	get_tree().change_scene_to_file("res://addons/godotsteamkit/starters/lobbies/lobby_manager.tscn")


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
		player.rotation.y = PI

	player.set_meta("peer_id", id)
	players.add_child(player, true)


@rpc("any_peer", "call_remote", "reliable")
func _request_peer_list() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_receive_peer_list.rpc_id(sender, _get_all_peer_ids(), round_manager.current_actor_peer_id)


@rpc("authority", "call_remote", "reliable")
func _receive_peer_list(peer_ids: Array, actor_id: int) -> void:
	round_manager.current_actor_peer_id = actor_id
	for pid in peer_ids:
		if not players.has_node(str(pid)):
			_spawn_player(pid)


func _on_actor_changed(peer_id: int) -> void:
	for child in players.get_children():
		var pid: int = child.get_meta("peer_id", int(child.name))
		var is_child_actor: bool = (pid == peer_id)
		if child.has_method("set_role"):
			child.set_role(is_child_actor)
		if pid != peer_id:
			var peer_ids: Array[int] = _get_all_peer_ids()
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

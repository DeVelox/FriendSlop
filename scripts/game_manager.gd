extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/proto_controller.tscn")

const ACTOR_POSITION: Vector3 = Vector3(0.0, 1.0, 23.0)
const STAGE_FORWARD: Vector3 = Vector3(0.0, 0.0, -1.0)

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var round_manager: Node = $RoundManager
@onready var spotlight: SpotLight3D = $CenterSpotlight
@onready var camera: Camera3D = $StageCamera

var _audience_slots: Array[Vector3] = []


func _ready() -> void:
	spawner.spawn_path = get_path_to(players)
	spawner.add_spawnable_scene("res://scenes/player/proto_controller.tscn")
	spawner.spawned.connect(_on_player_spawned)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		_build_audience_slots()
		_spawn_player(1)
		round_manager.actor_changed.connect(_on_actor_changed)
		round_manager.round_started.connect(_on_round_started)
		round_manager.round_ended.connect(_on_round_ended)

		await get_tree().process_frame
		round_manager.start_game()


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


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(id)


func _on_peer_disconnected(id: int) -> void:
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()


func _spawn_player(id: int) -> void:
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.name = str(id)

	var peer_ids: Array[int] = [1]
	for pid in multiplayer.get_peers():
		if pid != 1:
			peer_ids.append(pid)
	peer_ids.sort()

	var is_actor: bool = (id == round_manager.current_actor_peer_id)
	if is_actor:
		player.position = _get_actor_position()
		player.rotation.y = _get_actor_rotation()
	else:
		var audience_index: int = peer_ids.find(id)
		if audience_index == -1:
			audience_index = 0
		player.position = _get_audience_position(audience_index)

	player.set_meta("peer_id", id)
	players.add_child(player, true)


func _on_player_spawned(node: Node) -> void:
	if node.name == str(multiplayer.get_unique_id()):
		node.set_process(true)


func _on_actor_changed(peer_id: int) -> void:
	for child in players.get_children():
		var pid: int = child.get_meta("peer_id", int(child.name))
		var is_child_actor: bool = (pid == peer_id)
		if child.has_method("set_role"):
			child.set_role(is_child_actor)
		if pid != peer_id:
			var peer_ids: Array[int] = [1]
			for pid2 in multiplayer.get_peers():
				if pid2 != 1:
					peer_ids.append(pid2)
			peer_ids.sort()
			var idx: int = peer_ids.find(pid)
			if idx == -1:
				idx = 0
			child.position = _get_audience_position(idx)
		else:
			child.position = _get_actor_position()
			child.rotation.y = _get_actor_rotation()


func _on_round_started(_actor_peer_id: int, _prompt: String) -> void:
	spotlight.visible = true


func _on_round_ended(_winner_peer_id: int) -> void:
	spotlight.visible = false

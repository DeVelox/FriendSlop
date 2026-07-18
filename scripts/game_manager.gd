extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/proto_controller.tscn")

const ACTOR_POSITION: Vector3 = Vector3(0.0, 1.0, 23.0)
const STAGE_FORWARD: Vector3 = Vector3(0.0, 0.0, -1.0)

@onready var spawner: MultiplayerSpawner = $Multiplayer/MultiplayerSpawner
@onready var players: Node3D = $Multiplayer/Players
@onready var round_manager: Node = $RoundManager
@onready var spotlight: SpotLight3D = $CenterSpotlight
@onready var camera: Camera3D = $StageCamera

var _peer_list: Dictionary = {}
var _peer_info: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	round_manager.actor_changed.connect(_on_synced_actor_changed)

	_peer_info = {"name": _get_steam_username() if _get_steam_username() != "" else "Player 1"}
	spawner.set_spawn_function(_spawn_function)
	if multiplayer.is_server():
		_peer_list[1] = _peer_info
		_spawn_player(1)
	else:
		_player_is_ready.rpc_id(1, _get_steam_username())


func _get_actor_position() -> Vector3:
	return ACTOR_POSITION

func _get_actor_rotation() -> float:
	return STAGE_FORWARD.angle_to(Vector3.BACK)
	
func _get_audience_position(index: int) -> Vector3:
	var shifted_position = Vector3(-6.25, 0.0, 13.0)
	@warning_ignore("integer_division")
	var row = index / 5
	var col = index % 5
	shifted_position.x += col * 3
	shifted_position.z -= row
	return shifted_position
	
func _get_audience_rotation() -> float:
	return STAGE_FORWARD.angle_to(Vector3.FORWARD)


func _get_steam_username() -> String:
	if Engine.has_singleton("Steam") and Steam.isSteamRunning():
		return Steamworks.username
	return ""


@rpc("any_peer", "call_local", "reliable")
func _player_is_ready(username: String = "") -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	if multiplayer.is_server():
		if not _peer_list.has(sender_id):
			_peer_list[sender_id] = {"name": "Player %d" % sender_id}
		_peer_list[sender_id]["name"] = username if username != "" else "Player %d" % sender_id
	if not players.has_node(str(sender_id)):
		_spawn_player(sender_id)
	
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_peer_list[id] = {"name": "Player %d" % id}

func _on_peer_disconnected(id: int) -> void:
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()


func _on_server_disconnected() -> void:
	printerr("Server disconnected, returning to lobby")
	if Engine.has_singleton("Steam") and Steamworks.lobby_id > 0:
		Steam.leaveLobby(Steamworks.lobby_id)
		Steamworks.lobby_id = 0
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file.call_deferred("res://addons/godotsteamkit/starters/lobbies/lobby_manager.tscn")

	
func _spawn_player(id: int) -> void:
	var data: Dictionary = {}
	var audience_index: int = players.get_child_count()
	
	data.position = _get_audience_position(audience_index)
	data.rotation = _get_audience_rotation()
	data.peer_id = id
	
	spawner.spawn(data)

# TODO: update positions when somebody disconnects as well
func _spawn_function(data: Dictionary) -> CharacterBody3D:
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.name = str(data.peer_id)
	player.position = data.position
	player.rotation.y = data.rotation
	player.set_spawn_rotation(data.rotation)
	player.set_meta("position", data.position)
	player.set_meta("rotation", data.rotation)
	player.set_meta("peer_id", data.peer_id)
	return player

func _on_synced_actor_changed(peer_id: int) -> void:
	for child in players.get_children():
		var pid: int = child.get_meta("peer_id")
		if child.has_method("set_role"):
			child.set_role(peer_id)
		if pid == peer_id:
			child.position = _get_actor_position()
			child.rotation.y = _get_actor_rotation()
			child.set_spawn_rotation(_get_actor_rotation())
		else:
			child.position = child.get_meta("position")
			child.rotation.y = child.get_meta("rotation")
			child.set_spawn_rotation(child.get_meta("rotation"))

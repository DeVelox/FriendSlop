extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/proto_controller.tscn")

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner


func _ready() -> void:
	spawner.spawn_path = get_path_to(players)
	spawner.add_spawnable_scene("res://scenes/player/proto_controller.tscn")
	spawner.spawned.connect(_on_player_spawned)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		_spawn_player(1)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(id)


func _on_peer_disconnected(id: int) -> void:
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()


func _spawn_player(id: int) -> void:
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.position = Vector3(0, 0, 5)
	players.add_child(player, true)


func _on_player_spawned(node: Node) -> void:
	if node.name == str(multiplayer.get_unique_id()):
		node.set_process(true)

extends CanvasLayer

## In-game HUD: round timer, actor player buttons, audience emote buttons.

@export var font_size_timer: int = 32
@export var font_size_emote: int = 16
@export var font_size_player: int = 14
@export var panel_bg_color: Color = Color(0.0, 0.0, 0.0, 0.7)
@export var button_bg_color: Color = Color(0.2, 0.2, 0.3, 0.9)
@export var button_hover_color: Color = Color(0.3, 0.3, 0.5, 1.0)

@onready var timer_label: Label = $TimerLabel
@onready var actor_panel: MarginContainer = $ActorPanel
@onready var player_list: HBoxContainer = $ActorPanel/VBoxContainer/PlayerList
@onready var audience_panel: MarginContainer = $AudiencePanel

var _round_manager: Node = null
var _player_buttons: Dictionary = {}
var _current_state: int = -1
var _is_actor: bool = false

const EMOTE_KEYS: Dictionary = {
	KEY_1: "Human Armature|Punch",
	KEY_2: "Human Armature|Working",
	KEY_3: "Human Armature|Death",
	KEY_4: "Human Armature|ArmatureAction_002",
}

const EMOTE_NAMES: Dictionary = {
	"Human Armature|Punch": "Punch",
	"Human Armature|Working": "Working",
	"Human Armature|Death": "Death",
	"Human Armature|ArmatureAction_002": "Placeholder",
}


func _ready() -> void:
	await get_tree().process_frame
	_round_manager = _find_round_manager()
	if _round_manager == null:
		push_warning("GameHUD: RoundManager not found")
		return

	var game_manager: Node = get_parent()
	if game_manager != null:
		game_manager.players_changed.connect(_on_players_changed)

	_round_manager.timer_updated.connect(_on_timer_updated)
	_round_manager.state_changed.connect(_on_state_changed)
	_round_manager.actor_changed.connect(_on_actor_changed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_setup_timer_label()
	_build_emote_buttons()
	_build_player_buttons()

	_current_state = _round_manager.current_state
	_on_actor_changed(_round_manager.current_actor_peer_id)
	_refresh_display()


func _find_round_manager() -> Node:
	var stage: Node = get_parent()
	if stage == null:
		return null
	return stage.get_node_or_null("RoundManager")


func _setup_timer_label() -> void:
	timer_label.text = "Time: --"
	timer_label.add_theme_font_size_override("font_size", font_size_timer)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.visible = true


func _build_player_buttons() -> void:
	for child in player_list.get_children():
		child.queue_free()
	_player_buttons.clear()

	if not is_inside_tree():
		return

	var game_manager: Node = get_parent()
	if game_manager == null:
		return
	var players_node: Node3D = game_manager.get_node_or_null("Players")
	if players_node == null:
		return

	for player_node in players_node.get_children():
		var pid: int = player_node.get_meta("peer_id", int(player_node.name))
		if pid == multiplayer.get_unique_id():
			continue
		_create_player_button(pid)


func _create_player_button(peer_id: int) -> void:
	if _player_buttons.has(peer_id):
		return

	var btn: Button = Button.new()
	btn.name = "Player_%d" % peer_id
	btn.text = "Player %d" % peer_id
	btn.custom_minimum_size = Vector2(120, 40)
	btn.add_theme_font_size_override("font_size", font_size_player)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _make_stylebox(button_bg_color))
	btn.add_theme_stylebox_override("hover", _make_stylebox(button_hover_color))
	btn.pressed.connect(_on_player_button_pressed.bind(peer_id))
	player_list.add_child(btn)
	_player_buttons[peer_id] = btn


func _make_stylebox(bg_color: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	return sb


func _build_emote_buttons() -> void:
	for child in audience_panel.get_children():
		if child is HBoxContainer:
			for btn_child in child.get_children():
				btn_child.queue_free()
			child.queue_free()

	var container: HBoxContainer = HBoxContainer.new()
	container.name = "EmoteButtons"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 8)

	for anim_name in EMOTE_KEYS.values():
		var btn: Button = Button.new()
		var display_name: String = EMOTE_NAMES.get(anim_name, anim_name)
		btn.text = display_name
		btn.custom_minimum_size = Vector2(100, 40)
		btn.add_theme_font_size_override("font_size", font_size_emote)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_stylebox_override("normal", _make_stylebox(button_bg_color))
		btn.add_theme_stylebox_override("hover", _make_stylebox(button_hover_color))
		btn.pressed.connect(_on_emote_button_pressed.bind(anim_name))
		container.add_child(btn)

	audience_panel.add_child(container)


func _refresh_display() -> void:
	var in_round: bool = (_current_state == 1 or _current_state == 2 or _current_state == 3)
	timer_label.visible = true
	actor_panel.visible = in_round and _is_actor
	audience_panel.visible = in_round and not _is_actor


func _on_timer_updated(time_remaining: float) -> void:
	var minutes: int = int(time_remaining / 60.0)
	var seconds: int = int(time_remaining) % 60
	timer_label.text = "Time: %d:%02d" % [minutes, seconds]


func _on_state_changed(new_state: int) -> void:
	_current_state = new_state
	_refresh_display()


func _on_actor_changed(peer_id: int) -> void:
	_is_actor = (peer_id == multiplayer.get_unique_id())
	_build_player_buttons()
	_refresh_display()


func _on_peer_connected(_id: int) -> void:
	_build_player_buttons()


func _on_peer_disconnected(id: int) -> void:
	if _player_buttons.has(id):
		_player_buttons[id].queue_free()
		_player_buttons.erase(id)


func _on_players_changed() -> void:
	_build_player_buttons()


func _on_player_button_pressed(peer_id: int) -> void:
	if _round_manager == null:
		return
	var game_manager: Node = get_parent()
	if game_manager == null:
		return
	if multiplayer.is_server():
		game_manager.declare_winner_rpc(peer_id)
	else:
		game_manager.declare_winner_rpc.rpc_id(1, peer_id)


func _on_emote_button_pressed(anim_name: String) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("local_player")
	if players.size() > 0:
		var controller: Node = players[0]
		if controller.has_method("_play_emote"):
			controller._play_emote(anim_name)
			return

	var local_id: int = multiplayer.get_unique_id()
	var game_manager: Node = get_parent()
	if game_manager == null:
		return
	var players_node: Node3D = game_manager.get_node_or_null("Players")
	if players_node == null:
		return
	var player_node: Node = players_node.get_node_or_null(str(local_id))
	if player_node != null and player_node.has_method("_play_emote"):
		player_node._play_emote(anim_name)

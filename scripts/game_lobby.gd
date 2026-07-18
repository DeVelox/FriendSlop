extends Control
## Pre-game lobby scene for configuring game settings before starting.
## Shows current settings and allows host to configure topics, lists, packs.
## For local play: replaces direct transition to main_stage.
## For Steam play: can be instanced as overlay on top of addon lobby.
## Syncs settings from host to clients via RPCs.

const LOBBY_SETTINGS_SCENE: PackedScene = preload("res://scenes/lobby_settings.tscn")

const PANEL_BG_COLOR: Color = Color(0.08, 0.08, 0.12, 0.95)
const BUTTON_BG_COLOR: Color = Color(0.2, 0.2, 0.3, 0.9)
const BUTTON_HOVER_COLOR: Color = Color(0.3, 0.3, 0.5, 1.0)
const START_BG_COLOR: Color = Color(0.15, 0.4, 0.15, 0.9)
const START_HOVER_COLOR: Color = Color(0.2, 0.55, 0.2, 1.0)

var _data_manager: Node = null
var _settings_panel: Control = null
var _summary_label: Label = null
var _start_button: Button = null
var _is_host: bool = false
var _player_list_container: VBoxContainer = null


func _ready() -> void:
	_data_manager = _find_data_manager()
	if _data_manager == null:
		push_warning("GameLobby: GuessingDataManager not found")
		return

	_is_host = multiplayer.is_server()
	_build_ui()
	_data_manager.load_all_topics()
	_data_manager.load_all_lists()
	_data_manager.load_all_packs()

	if _is_host:
		_enable_defaults()
		_refresh_summary()
	else:
		_request_settings_from_host()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _find_data_manager() -> Node:
	return get_tree().get_first_node_in_group("guessing_data_manager")


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "Game Lobby"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var content: HBoxContainer = HBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 30)
	vbox.add_child(content)

	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 15)
	content.add_child(left_panel)

	var settings_label: Label = Label.new()
	settings_label.text = "Current Settings"
	settings_label.add_theme_font_size_override("font_size", 22)
	settings_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	left_panel.add_child(settings_label)

	var summary_bg: PanelContainer = PanelContainer.new()
	summary_bg.name = "SummaryBg"
	summary_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var summary_sb: StyleBoxFlat = StyleBoxFlat.new()
	summary_sb.bg_color = PANEL_BG_COLOR
	summary_sb.set_corner_radius_all(6)
	summary_sb.set_content_margin_all(12)
	summary_bg.add_theme_stylebox_override("panel", summary_sb)
	left_panel.add_child(summary_bg)

	var summary_scroll: ScrollContainer = ScrollContainer.new()
	summary_scroll.name = "SummaryScroll"
	summary_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_bg.add_child(summary_scroll)

	_summary_label = Label.new()
	_summary_label.name = "SummaryLabel"
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 16)
	_summary_label.add_theme_color_override("font_color", Color.WHITE)
	summary_scroll.add_child(_summary_label)

	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.name = "RightPanel"
	right_panel.custom_minimum_size = Vector2(250, 0)
	right_panel.add_theme_constant_override("separation", 10)
	content.add_child(right_panel)

	if _is_host:
		var settings_btn: Button = Button.new()
		settings_btn.name = "SettingsButton"
		settings_btn.text = "Game Settings"
		settings_btn.custom_minimum_size = Vector2(250, 50)
		settings_btn.add_theme_font_size_override("font_size", 18)
		settings_btn.add_theme_color_override("font_color", Color.WHITE)
		settings_btn.add_theme_stylebox_override("normal", _make_stylebox(BUTTON_BG_COLOR))
		settings_btn.add_theme_stylebox_override("hover", _make_stylebox(BUTTON_HOVER_COLOR))
		settings_btn.pressed.connect(_on_settings_pressed)
		right_panel.add_child(settings_btn)

	var player_list_label: Label = Label.new()
	player_list_label.text = "Players"
	player_list_label.add_theme_font_size_override("font_size", 18)
	player_list_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	right_panel.add_child(player_list_label)

	var player_list_bg: PanelContainer = PanelContainer.new()
	player_list_bg.name = "PlayerListBg"
	player_list_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var player_sb: StyleBoxFlat = StyleBoxFlat.new()
	player_sb.bg_color = PANEL_BG_COLOR
	player_sb.set_corner_radius_all(6)
	player_sb.set_content_margin_all(8)
	player_list_bg.add_theme_stylebox_override("panel", player_sb)
	right_panel.add_child(player_list_bg)

	var player_scroll: ScrollContainer = ScrollContainer.new()
	player_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_list_bg.add_child(player_scroll)

	var player_list: VBoxContainer = VBoxContainer.new()
	player_list.name = "PlayerList"
	player_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_scroll.add_child(player_list)

	_player_list_container = player_list
	_populate_player_list(player_list)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	if _is_host:
		_start_button = Button.new()
		_start_button.name = "StartButton"
		_start_button.text = "Start Game"
		_start_button.custom_minimum_size = Vector2(200, 50)
		_start_button.add_theme_font_size_override("font_size", 20)
		_start_button.add_theme_color_override("font_color", Color.WHITE)
		_start_button.add_theme_stylebox_override("normal", _make_stylebox(START_BG_COLOR))
		_start_button.add_theme_stylebox_override("hover", _make_stylebox(START_HOVER_COLOR))
		_start_button.pressed.connect(_on_start_pressed)
		btn_row.add_child(_start_button)

	var leave_btn: Button = Button.new()
	leave_btn.name = "LeaveButton"
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(150, 50)
	leave_btn.add_theme_font_size_override("font_size", 16)
	leave_btn.add_theme_color_override("font_color", Color.WHITE)
	leave_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.4, 0.2, 0.2, 0.9)))
	leave_btn.add_theme_stylebox_override("hover", _make_stylebox(Color(0.6, 0.2, 0.2, 1.0)))
	leave_btn.pressed.connect(_on_leave_pressed)
	btn_row.add_child(leave_btn)


func _make_stylebox(bg_color: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	return sb


func _enable_defaults() -> void:
	if _data_manager == null:
		return
	if _data_manager._enabled_topic_ids.is_empty():
		var topic_ids: Array[String] = []
		for topic: Dictionary in _data_manager._all_topics:
			topic_ids.append(topic.id)
		_data_manager.set_enabled_topics(topic_ids)
	if _data_manager._enabled_list_ids.is_empty():
		var list_ids: Array[String] = []
		for list: Dictionary in _data_manager._all_lists:
			list_ids.append(list.metadata.id)
		_data_manager.set_enabled_lists(list_ids)
	if _data_manager._enabled_pack_ids.is_empty():
		var pack_ids: Array[String] = []
		for pack: Dictionary in _data_manager._all_packs:
			pack_ids.append(pack.metadata.id)
		_data_manager.set_enabled_packs(pack_ids)


func _refresh_summary() -> void:
	if _summary_label == null or _data_manager == null:
		return

	var text: String = ""

	var topics: Array[Dictionary] = _data_manager.get_enabled_topics()
	text += "Topics (%d):\n" % topics.size()
	for topic: Dictionary in topics:
		text += "  - %s\n" % topic.name
	text += "\n"

	var lists_count: int = 0
	for topic: Dictionary in topics:
		var lists: Array[Dictionary] = _data_manager.get_lists_for_topic(topic.id)
		for list: Dictionary in lists:
			if list.metadata.id in _data_manager._enabled_list_ids:
				lists_count += 1
	text += "Guessing Lists: %d enabled\n" % lists_count

	var packs_count: int = 0
	for topic: Dictionary in topics:
		var packs: Array[Dictionary] = _data_manager.get_packs_for_topic(topic.id)
		for pack: Dictionary in packs:
			if pack.metadata.id in _data_manager._enabled_pack_ids:
				packs_count += 1
	text += "Guessing Packs: %d enabled\n" % packs_count

	var total_words: int = 0
	for pack_id: String in _data_manager._enabled_pack_ids:
		var pack: Dictionary = _data_manager._find_pack(pack_id)
		if not pack.is_empty():
			total_words += pack.entries.size()
	text += "\nTotal words in packs: %d" % total_words

	_summary_label.text = text


func _populate_player_list(container: VBoxContainer) -> void:
	var peers: Array[int] = []
	for peer_id: int in multiplayer.get_peers():
		peers.append(peer_id)
	peers.append(1)

	for peer_id: int in peers:
		var label: Label = Label.new()
		var peer_name: String = "Player %d" % peer_id
		if peer_id == 1:
			peer_name += " (Host)"
		label.text = peer_name
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color.WHITE)
		container.add_child(label)


func _on_settings_pressed() -> void:
	if LOBBY_SETTINGS_SCENE == null:
		return
	_settings_panel = LOBBY_SETTINGS_SCENE.instantiate()
	_settings_panel.settings_closed.connect(_on_settings_closed)
	add_child(_settings_panel)


func _on_settings_closed() -> void:
	_settings_panel = null
	_refresh_summary()
	if _is_host:
		_sync_settings_to_clients()


func _on_start_pressed() -> void:
	if _data_manager == null:
		push_warning("GameLobby: Cannot start, data manager not found")
		return

	_data_manager.initialize_game_data(
		_data_manager._enabled_topic_ids,
		_data_manager._enabled_list_ids,
		_data_manager._enabled_pack_ids
	)

	var word_bank: Array[String] = _data_manager.get_word_bank()
	if word_bank.is_empty():
		push_warning("GameLobby: Word bank is empty! No topics, lists, or packs are enabled.")

	_sync_settings_to_clients()
	_start_game_rpc.rpc(
		_data_manager._enabled_topic_ids,
		_data_manager._enabled_list_ids,
		_data_manager._enabled_pack_ids
	)


@rpc("authority", "call_local", "reliable")
func _start_game_rpc(
	topics: Array[String],
	lists: Array[String],
	packs: Array[String]
) -> void:
	if not multiplayer.is_server():
		if _data_manager != null:
			_data_manager.initialize_game_data(topics, lists, packs)
	get_tree().change_scene_to_file("res://scenes/main_stage.tscn")


func _on_leave_pressed() -> void:
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://addons/godotsteamkit/starters/lobbies/lobby_manager.tscn")


func _on_peer_connected(_id: int) -> void:
	if _is_host:
		_sync_settings_to_clients()
	_refresh_player_list()


func _on_peer_disconnected(_id: int) -> void:
	_refresh_player_list()


func _refresh_player_list() -> void:
	if _player_list_container == null:
		return
	for child in _player_list_container.get_children():
		child.queue_free()
	_populate_player_list(_player_list_container)


func _request_settings_from_host() -> void:
	_request_settings_rpc.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_settings_rpc() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return
	_sync_settings_rpc.rpc_id(
		sender_id,
		_data_manager._enabled_topic_ids,
		_data_manager._enabled_list_ids,
		_data_manager._enabled_pack_ids
	)


func _sync_settings_to_clients() -> void:
	if _data_manager == null:
		return
	_sync_settings_rpc(
		_data_manager._enabled_topic_ids,
		_data_manager._enabled_list_ids,
		_data_manager._enabled_pack_ids
	)


@rpc("authority", "call_local", "reliable")
func _sync_settings_rpc(
	topics: Array[String],
	lists: Array[String],
	packs: Array[String]
) -> void:
	if _data_manager == null:
		return
	_data_manager.set_enabled_topics(topics)
	_data_manager.set_enabled_lists(lists)
	_data_manager.set_enabled_packs(packs)
	_refresh_summary()
